package engine

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"flsteamlua/lan_transfer_engine/internal/discovery"
	"flsteamlua/lan_transfer_engine/internal/identity"
	"flsteamlua/lan_transfer_engine/internal/model"
	"flsteamlua/lan_transfer_engine/internal/plan"
	"flsteamlua/lan_transfer_engine/internal/protocol"
)

type Event struct {
	Name string
	Data any
}

type Engine struct {
	dataDir string

	mu        sync.Mutex
	events    chan Event
	config    model.Config
	identity  *identity.Identity
	discovery *discovery.Service
	server    *transferServer
	plans     map[string]*model.Plan
	peers     map[string]model.Peer
	trusted   map[string]model.TrustedPeer
	pending   map[string]*pendingOffer
	sessions  map[string]*sessionRuntime
	closed    bool
}

type sessionRuntime struct {
	mu        sync.Mutex
	data      model.Session
	cancel    context.CancelFunc
	conn      *peerConn
	lastEmit  time.Time
	lastBytes int64
	lastAt    time.Time
	speed     float64
	peakSpeed float64
	plan      *model.Plan
	peer      model.Peer
}

type pendingOffer struct {
	mu       sync.Mutex
	conn     *peerConn
	summary  model.OfferSummary
	decision chan acceptDecision
	target   string
	luaRoot  string
}

type acceptDecision struct {
	accepted bool
	target   string
	luaRoot  string
	remember bool
	message  string
}

func New(dataDir string) (*Engine, error) {
	if strings.TrimSpace(dataDir) == "" {
		return nil, fmt.Errorf("engine data directory is required")
	}
	if err := os.MkdirAll(dataDir, 0o700); err != nil {
		return nil, err
	}
	e := &Engine{
		dataDir:  dataDir,
		events:   make(chan Event, 256),
		plans:    make(map[string]*model.Plan),
		peers:    make(map[string]model.Peer),
		trusted:  make(map[string]model.TrustedPeer),
		pending:  make(map[string]*pendingOffer),
		sessions: make(map[string]*sessionRuntime),
	}
	e.discovery = discovery.New(e.onPeersChanged)
	if err := e.loadTrusted(); err != nil {
		return nil, err
	}
	return e, nil
}

func (e *Engine) Events() <-chan Event {
	return e.events
}

func (e *Engine) Emit(name string, data any) {
	e.mu.Lock()
	closed := e.closed
	e.mu.Unlock()
	if closed {
		return
	}
	select {
	case e.events <- Event{Name: name, Data: data}:
	default:
		log.Printf("event queue full, dropping %s", name)
	}
}

func (e *Engine) Execute(method string, params json.RawMessage) (any, error) {
	switch method {
	case "hello":
		return map[string]any{
			"engineProtocol": "flsteamlua-engine/1",
			"lanProtocol":    protocol.LANProtocol,
			"version":        "0.1.0",
		}, nil
	case "configure":
		var config model.Config
		if err := json.Unmarshal(params, &config); err != nil {
			return nil, fmt.Errorf("invalid configure parameters: %w", err)
		}
		return e.configure(config)
	case "discovery.start":
		return e.startDiscovery()
	case "discovery.stop":
		e.discovery.Stop()
		return map[string]any{"running": false}, nil
	case "peer.probe":
		var input struct {
			Address string `json:"address"`
			Port    int    `json:"port"`
		}
		if err := json.Unmarshal(params, &input); err != nil {
			return nil, err
		}
		return e.probePeer(input.Address, input.Port)
	case "plan.prepare":
		var input model.GameInput
		if err := json.Unmarshal(params, &input); err != nil {
			return nil, err
		}
		return e.preparePlan(input)
	case "plan.discard":
		var input struct {
			PlanID string `json:"planId"`
		}
		if err := json.Unmarshal(params, &input); err != nil {
			return nil, err
		}
		e.mu.Lock()
		delete(e.plans, input.PlanID)
		e.mu.Unlock()
		return map[string]any{"discarded": true}, nil
	case "send.start":
		var input struct {
			PlanID           string   `json:"planId"`
			PeerID           string   `json:"peerId"`
			SelectedOptional []string `json:"selectedOptionalIds"`
		}
		if err := json.Unmarshal(params, &input); err != nil {
			return nil, err
		}
		return e.startSend(input.PlanID, input.PeerID, input.SelectedOptional)
	case "offer.accept":
		var input struct {
			SessionID     string `json:"sessionId"`
			TargetLibrary string `json:"targetLibrary"`
			LuaRoot       string `json:"luaRoot"`
			Remember      bool   `json:"remember"`
		}
		if err := json.Unmarshal(params, &input); err != nil {
			return nil, err
		}
		return e.acceptOffer(input.SessionID, input.TargetLibrary, input.LuaRoot, input.Remember)
	case "offer.reject":
		var input struct {
			SessionID string `json:"sessionId"`
			Reason    string `json:"reason"`
		}
		if err := json.Unmarshal(params, &input); err != nil {
			return nil, err
		}
		return e.rejectOffer(input.SessionID, input.Reason)
	case "session.pause":
		return e.pauseSession(stringParam(params, "sessionId"))
	case "session.resume":
		return e.resumeSession(stringParam(params, "sessionId"))
	case "session.cancel":
		return e.cancelSession(stringParam(params, "sessionId"))
	case "trust.set":
		var input struct {
			Peer        model.TrustedPeer `json:"peer"`
			Remove      bool              `json:"remove"`
			Fingerprint string            `json:"fingerprint"`
		}
		if err := json.Unmarshal(params, &input); err != nil {
			return nil, err
		}
		return e.setTrusted(input.Peer, input.Remove, input.Fingerprint)
	case "cache.stats":
		return e.cacheStats()
	case "cache.clear":
		return e.clearCache()
	case "shutdown":
		go e.Close()
		return map[string]any{"stopping": true}, nil
	default:
		return nil, fmt.Errorf("unknown method %s", method)
	}
}

func stringParam(params json.RawMessage, key string) string {
	var value map[string]any
	_ = json.Unmarshal(params, &value)
	return fmt.Sprint(value[key])
}

func (e *Engine) configure(config model.Config) (any, error) {
	if strings.TrimSpace(config.DisplayName) == "" {
		config.DisplayName = "FlSteamLua"
	}
	id, err := identity.LoadOrCreate(filepath.Join(config.DataDir, "identity"), config.DisplayName)
	if err != nil {
		return nil, err
	}
	e.mu.Lock()
	e.config = config
	e.identity = id
	e.mu.Unlock()
	e.discovery.SetTrusted(e.trustedSnapshot())
	if config.ReceiveEnabled {
		if err := e.startServer(); err != nil {
			return nil, err
		}
	} else {
		if server := e.transferServer(); server != nil {
			server.stop()
		}
	}
	if _, err := e.startDiscovery(); err != nil {
		return nil, err
	}
	e.discovery.SetReceiving(config.ReceiveEnabled)
	return map[string]any{
		"displayName": config.DisplayName,
		"fingerprint": id.Fingerprint,
		"receiving":   config.ReceiveEnabled,
	}, nil
}

func (e *Engine) startDiscovery() (any, error) {
	e.mu.Lock()
	if e.identity == nil {
		e.mu.Unlock()
		return nil, fmt.Errorf("engine is not configured")
	}
	config := e.config
	id := e.identity
	e.mu.Unlock()
	if err := e.discovery.Start(config.DisplayName, id.Fingerprint, e.trustedSnapshot()); err != nil {
		return nil, err
	}
	e.discovery.SetReceiving(e.currentConfig().ReceiveEnabled)
	return map[string]any{"running": true}, nil
}

func (e *Engine) onPeersChanged(peers []model.Peer) {
	e.mu.Lock()
	e.peers = make(map[string]model.Peer, len(peers))
	for _, peer := range peers {
		peer.Trusted = e.trusted[peer.Fingerprint].Fingerprint != ""
		e.peers[peer.ID] = peer
	}
	e.mu.Unlock()
	e.Emit("peers.changed", peers)
}

func (e *Engine) trustedSnapshot() map[string]bool {
	e.mu.Lock()
	defer e.mu.Unlock()
	result := make(map[string]bool, len(e.trusted))
	for fingerprint := range e.trusted {
		result[fingerprint] = true
	}
	return result
}

func (e *Engine) preparePlan(game model.GameInput) (model.PlanSummary, error) {
	keys, err := plan.LoadDepotKeys(e.currentConfig().KeyCacheRoot)
	if err != nil {
		return model.PlanSummary{}, err
	}
	builder := plan.Builder{Config: e.currentConfig(), Keys: keys}
	value, err := builder.Build(game)
	if err != nil {
		return model.PlanSummary{}, err
	}
	summary := plan.Summary(value)
	e.mu.Lock()
	e.plans[value.ID] = value
	e.mu.Unlock()
	e.Emit("plan.ready", summary)
	return summary, nil
}

func (e *Engine) startSend(planID, peerID string, selectedOptional []string) (any, error) {
	e.mu.Lock()
	base := e.plans[planID]
	peer, exists := e.peers[peerID]
	e.mu.Unlock()
	if base == nil {
		return nil, fmt.Errorf("unknown transfer plan")
	}
	if !exists {
		return nil, fmt.Errorf("unknown transfer peer")
	}
	selected := make(map[string]bool, len(selectedOptional))
	for _, id := range selectedOptional {
		selected[id] = true
	}
	filtered := plan.Filter(base, selected)
	sessionID := "send:" + filtered.ID
	session := &sessionRuntime{plan: filtered, peer: peer, data: model.Session{
		ID: sessionID, BundleID: filtered.ID, AppID: filtered.AppID,
		GameName: filtered.GameName, CoverURL: filtered.CoverURL,
		Direction: "send", PeerID: peer.ID, PeerAlias: peer.Alias,
		PeerAddress: peer.Address, PeerFingerprint: peer.Fingerprint,
		Status: "preparing", TotalBytes: selectedBytes(filtered),
		CanPause: true, TotalChunks: len(filtered.Chunks), CreatedAt: time.Now().Unix(),
	}}
	session.lastAt = time.Now()
	e.mu.Lock()
	e.sessions[sessionID] = session
	e.mu.Unlock()
	e.emitSession(session)
	go e.runSend(sessionID, peer, filtered)
	return e.sessionSnapshot(sessionID), nil
}

func selectedBytes(value *model.Plan) int64 {
	var total int64
	for _, file := range value.Files {
		if file.Selected {
			total += file.Size
		}
	}
	return total
}

func (e *Engine) acceptOffer(sessionID, target, luaRoot string, remember bool) (any, error) {
	e.mu.Lock()
	pending := e.pending[sessionID]
	peer := pendingPeer(pending)
	e.mu.Unlock()
	if pending == nil {
		return nil, fmt.Errorf("offer is no longer available")
	}
	decision := acceptDecision{accepted: true, target: target, luaRoot: luaRoot, remember: remember}
	select {
	case pending.decision <- decision:
	default:
		return nil, fmt.Errorf("offer decision already submitted")
	}
	if remember && peer.Fingerprint != "" {
		trusted := model.TrustedPeer{
			Fingerprint: peer.Fingerprint, Alias: peer.Alias,
			DefaultLibraryRoot: target, AutoAccept: true, LastSeen: time.Now().Unix(),
		}
		if _, err := e.setTrusted(trusted, false, ""); err != nil {
			log.Printf("save trusted peer: %v", err)
		}
	}
	return map[string]any{"accepted": true}, nil
}

func pendingPeer(value *pendingOffer) model.Peer {
	if value == nil {
		return model.Peer{}
	}
	return value.summary.Peer
}

func (e *Engine) rejectOffer(sessionID, reason string) (any, error) {
	e.mu.Lock()
	pending := e.pending[sessionID]
	e.mu.Unlock()
	if pending == nil {
		return nil, fmt.Errorf("offer is no longer available")
	}
	select {
	case pending.decision <- acceptDecision{accepted: false, message: reason}:
	default:
	}
	return map[string]any{"accepted": false}, nil
}

func (e *Engine) pauseSession(sessionID string) (any, error) {
	runtime := e.session(sessionID)
	if runtime == nil {
		return nil, fmt.Errorf("unknown session")
	}
	runtime.mu.Lock()
	if runtime.cancel != nil {
		runtime.cancel()
	}
	if runtime.conn != nil {
		_ = runtime.conn.write(protocol.Frame{
			Type: protocol.FrameCancel, Payload: protocol.EncodeError("paused"),
		})
		runtime.conn.close()
	}
	runtime.data.Status = "paused"
	runtime.data.Message = ""
	runtime.mu.Unlock()
	e.emitSession(runtime)
	return e.sessionSnapshot(sessionID), nil
}

func (e *Engine) resumeSession(sessionID string) (any, error) {
	runtime := e.session(sessionID)
	if runtime == nil {
		return nil, fmt.Errorf("unknown session")
	}
	runtime.mu.Lock()
	if runtime.data.Status != "paused" && runtime.data.Status != "failed" {
		runtime.mu.Unlock()
		return e.sessionSnapshot(sessionID), nil
	}
	runtime.data.Status = "preparing"
	runtime.data.Error = ""
	planValue := runtime.plan
	peer := runtime.peer
	runtime.mu.Unlock()
	e.emitSession(runtime)
	if planValue == nil || peer.ID == "" {
		return nil, fmt.Errorf("session cannot be resumed")
	}
	go e.runSend(sessionID, peer, planValue)
	return e.sessionSnapshot(sessionID), nil
}

func (e *Engine) cancelSession(sessionID string) (any, error) {
	runtime := e.session(sessionID)
	if runtime == nil {
		return nil, fmt.Errorf("unknown session")
	}
	runtime.mu.Lock()
	if runtime.cancel != nil {
		runtime.cancel()
	}
	if runtime.conn != nil {
		_ = runtime.conn.write(protocol.Frame{
			Type: protocol.FrameCancel, Payload: protocol.EncodeError("cancelled"),
		})
		runtime.conn.close()
	}
	runtime.data.Status = "cancelled"
	runtime.data.Speed = 0
	runtime.mu.Unlock()
	e.emitSession(runtime)
	return e.sessionSnapshot(sessionID), nil
}

func (e *Engine) setTrusted(peer model.TrustedPeer, remove bool, fingerprint string) (any, error) {
	e.mu.Lock()
	if remove {
		if fingerprint == "" {
			fingerprint = peer.Fingerprint
		}
		delete(e.trusted, fingerprint)
	} else {
		if peer.Fingerprint == "" {
			e.mu.Unlock()
			return nil, fmt.Errorf("trusted peer fingerprint is required")
		}
		if peer.LastSeen == 0 {
			peer.LastSeen = time.Now().Unix()
		}
		e.trusted[peer.Fingerprint] = peer
	}
	values := make([]model.TrustedPeer, 0, len(e.trusted))
	for _, value := range e.trusted {
		values = append(values, value)
	}
	e.mu.Unlock()
	sort.Slice(values, func(i, j int) bool { return values[i].Alias < values[j].Alias })
	if err := e.saveTrusted(values); err != nil {
		return nil, err
	}
	e.discovery.SetTrusted(e.trustedSnapshot())
	return map[string]any{"trusted": values}, nil
}

func (e *Engine) loadTrusted() error {
	path := filepath.Join(e.dataDir, "trusted.json")
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	var values []model.TrustedPeer
	if err := json.Unmarshal(data, &values); err != nil {
		return err
	}
	for _, value := range values {
		if value.Fingerprint != "" {
			e.trusted[value.Fingerprint] = value
		}
	}
	return nil
}

func (e *Engine) saveTrusted(values []model.TrustedPeer) error {
	data, err := json.MarshalIndent(values, "", "  ")
	if err != nil {
		return err
	}
	path := filepath.Join(e.dataDir, "trusted.json")
	temp := path + ".tmp"
	if err := os.WriteFile(temp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(temp, path)
}

func (e *Engine) cacheStats() (model.CacheStats, error) {
	var stats model.CacheStats
	for _, root := range e.libraryRoots() {
		directory := filepath.Join(root, "steamapps", ".flsteamlua", "chunks")
		err := filepath.WalkDir(directory, func(path string, entry os.DirEntry, err error) error {
			if err != nil || entry.IsDir() {
				return nil
			}
			info, err := entry.Info()
			if err == nil {
				stats.Files++
				stats.Bytes += info.Size()
			}
			return nil
		})
		if err != nil && !os.IsNotExist(err) {
			return stats, err
		}
	}
	return stats, nil
}

func (e *Engine) clearCache() (any, error) {
	e.mu.Lock()
	for _, runtime := range e.sessions {
		runtime.mu.Lock()
		active := runtime.data.Status == "transferring" || runtime.data.Status == "verifying"
		runtime.mu.Unlock()
		if active {
			e.mu.Unlock()
			return nil, fmt.Errorf("finish or cancel active transfers before clearing cache")
		}
	}
	e.mu.Unlock()
	for _, root := range e.libraryRoots() {
		_ = os.RemoveAll(filepath.Join(root, "steamapps", ".flsteamlua", "chunks"))
	}
	return map[string]any{"cleared": true}, nil
}

func (e *Engine) currentConfig() model.Config {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.config
}

func (e *Engine) libraryRoots() []string {
	e.mu.Lock()
	defer e.mu.Unlock()
	return append([]string(nil), e.config.LibraryRoots...)
}

func (e *Engine) session(id string) *sessionRuntime {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.sessions[id]
}

func (e *Engine) sessionSnapshot(id string) model.Session {
	runtime := e.session(id)
	if runtime == nil {
		return model.Session{}
	}
	runtime.mu.Lock()
	defer runtime.mu.Unlock()
	return runtime.data
}

func (e *Engine) emitSession(runtime *sessionRuntime) {
	if runtime == nil {
		return
	}
	runtime.mu.Lock()
	now := time.Now()
	snapshot := runtime.data
	if snapshot.Direction == "send" || snapshot.Direction == "receive" {
		elapsed := now.Sub(runtime.lastAt).Seconds()
		if elapsed > 0 {
			runtime.speed = float64(snapshot.TransferredBytes-runtime.lastBytes) / elapsed
		}
		runtime.lastBytes = snapshot.TransferredBytes
		runtime.lastAt = now
		snapshot.Speed = runtime.speed
		if snapshot.Speed > runtime.peakSpeed {
			runtime.peakSpeed = snapshot.Speed
		}
		snapshot.PeakSpeed = runtime.peakSpeed
		runtime.data.Speed = snapshot.Speed
		runtime.data.PeakSpeed = snapshot.PeakSpeed
	}
	runtime.lastEmit = now
	runtime.mu.Unlock()
	e.Emit("session.updated", snapshot)
}

func (e *Engine) updateSession(runtime *sessionRuntime, update func(*model.Session)) {
	if runtime == nil {
		return
	}
	runtime.mu.Lock()
	update(&runtime.data)
	shouldEmit := time.Since(runtime.lastEmit) >= 200*time.Millisecond
	runtime.mu.Unlock()
	if shouldEmit {
		e.emitSession(runtime)
	}
}

func (e *Engine) transferServer() *transferServer {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.server
}

func (e *Engine) startServer() error {
	e.mu.Lock()
	if e.config.SteamPath == "" {
		e.mu.Unlock()
		return fmt.Errorf("Steam installation path is required")
	}
	if e.server != nil {
		e.mu.Unlock()
		return nil
	}
	id := e.identity
	e.mu.Unlock()
	server := &transferServer{engine: e}
	if err := server.start(id); err != nil {
		return err
	}
	e.mu.Lock()
	e.server = server
	e.mu.Unlock()
	return nil
}

func (e *Engine) Close() {
	e.mu.Lock()
	if e.closed {
		e.mu.Unlock()
		return
	}
	e.closed = true
	server := e.server
	e.server = nil
	sessions := make([]*sessionRuntime, 0, len(e.sessions))
	for _, runtime := range e.sessions {
		sessions = append(sessions, runtime)
	}
	e.mu.Unlock()
	e.discovery.Stop()
	for _, runtime := range sessions {
		runtime.mu.Lock()
		if runtime.cancel != nil {
			runtime.cancel()
		}
		if runtime.conn != nil {
			runtime.conn.close()
		}
		runtime.mu.Unlock()
	}
	if server != nil {
		server.stop()
	}
}

func (e *Engine) probePeer(address string, port int) (model.Peer, error) {
	if port == 0 {
		port = discovery.Port
	}
	id := e.currentIdentity()
	if id == nil {
		return model.Peer{}, fmt.Errorf("engine is not configured")
	}
	conn, err := tls.DialWithDialer(&net.Dialer{Timeout: 8 * time.Second}, "tcp",
		net.JoinHostPort(address, fmt.Sprint(port)), id.ClientConfig(""))
	if err != nil {
		return model.Peer{}, err
	}
	defer conn.Close()
	fingerprint := identity.PeerFingerprint(conn.ConnectionState())
	peerConn := &peerConn{conn: conn, fingerprint: fingerprint}
	if err := peerConn.write(protocol.Frame{Type: protocol.FrameHello, Payload: protocol.EncodeHello(protocol.Hello{
		Protocol: protocol.LANProtocol, Alias: e.currentConfig().DisplayName,
		Fingerprint: id.Fingerprint, Receiving: true,
	})}); err != nil {
		return model.Peer{}, err
	}
	frame, err := peerConn.read()
	if err != nil {
		return model.Peer{}, err
	}
	hello, err := protocol.DecodeHello(frame.Payload)
	if err != nil || hello.Protocol != protocol.LANProtocol || hello.Fingerprint != fingerprint {
		return model.Peer{}, fmt.Errorf("incompatible or unauthenticated LAN peer")
	}
	peer := model.Peer{
		ID: fingerprint, Alias: hello.Alias, Address: address, Port: port,
		Fingerprint: fingerprint, LastSeen: time.Now().UnixMilli(),
	}
	e.discovery.Upsert(peer)
	return peer, nil
}

func (e *Engine) currentIdentity() *identity.Identity {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.identity
}

func (e *Engine) markSessionError(runtime *sessionRuntime, err error) {
	if runtime == nil {
		return
	}
	runtime.mu.Lock()
	if runtime.data.Status == "paused" || runtime.data.Status == "cancelled" {
		runtime.data.Speed = 0
		runtime.mu.Unlock()
		e.emitSession(runtime)
		return
	}
	if !errors.Is(err, context.Canceled) {
		runtime.data.Status = "failed"
		runtime.data.Error = err.Error()
	} else if runtime.data.Status != "paused" && runtime.data.Status != "cancelled" {
		runtime.data.Status = "failed"
		runtime.data.Error = err.Error()
	}
	runtime.data.Speed = 0
	runtime.mu.Unlock()
	e.emitSession(runtime)
}

func (e *Engine) markSessionCompleted(runtime *sessionRuntime) {
	if runtime == nil {
		return
	}
	runtime.mu.Lock()
	runtime.data.Status = "completed"
	runtime.data.TransferredBytes = runtime.data.TotalBytes
	runtime.data.Speed = 0
	runtime.mu.Unlock()
	e.emitSession(runtime)
}
