package engine

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"log"
	"net"
	"strings"
	"time"

	"flsteamlua/lan_transfer_engine/internal/discovery"
	"flsteamlua/lan_transfer_engine/internal/identity"
	"flsteamlua/lan_transfer_engine/internal/model"
	"flsteamlua/lan_transfer_engine/internal/plan"
	"flsteamlua/lan_transfer_engine/internal/protocol"
)

type transferServer struct {
	engine   *Engine
	listener net.Listener
}

func (s *transferServer) start(id *identity.Identity) error {
	listener, err := net.Listen("tcp4", fmt.Sprintf("0.0.0.0:%d", discovery.Port))
	if err != nil {
		return err
	}
	s.listener = tls.NewListener(listener, id.ServerConfig())
	go s.acceptLoop()
	return nil
}

func (s *transferServer) stop() {
	s.engine.mu.Lock()
	if s.engine.server == s {
		s.engine.server = nil
	}
	s.engine.mu.Unlock()
	if s.listener != nil {
		_ = s.listener.Close()
	}
	s.engine.mu.Lock()
	for _, pending := range s.engine.pending {
		select {
		case pending.decision <- acceptDecision{accepted: false, message: "receiver stopped"}:
		default:
		}
	}
	s.engine.mu.Unlock()
}

func (s *transferServer) acceptLoop() {
	for {
		raw, err := s.listener.Accept()
		if err != nil {
			return
		}
		go s.handle(raw)
	}
}

func (s *transferServer) handle(raw net.Conn) {
	conn, ok := raw.(*tls.Conn)
	if !ok {
		_ = raw.Close()
		return
	}
	if tcp, ok := conn.NetConn().(*net.TCPConn); ok {
		_ = tcp.SetKeepAlive(true)
		_ = tcp.SetKeepAlivePeriod(15 * time.Second)
	}
	_ = conn.SetDeadline(time.Now().Add(15 * time.Second))
	if err := conn.Handshake(); err != nil {
		_ = conn.Close()
		return
	}
	peer, err := s.engine.performServerHello(conn)
	if err != nil {
		_ = conn.Close()
		return
	}
	defer peer.close()
	for {
		frame, err := peer.read()
		if err != nil {
			return
		}
		switch frame.Type {
		case protocol.FrameOffer:
			_ = conn.SetDeadline(time.Time{})
			if err := s.handleOffer(peer, frame.Payload); err != nil {
				_ = peer.write(protocol.Frame{Type: protocol.FrameError, Payload: protocol.EncodeError(err.Error())})
				return
			}
			return
		default:
			_ = peer.write(protocol.Frame{Type: protocol.FrameError, Payload: protocol.EncodeError("unexpected frame")})
			return
		}
	}
}

func (s *transferServer) handleOffer(peer *peerConn, payload []byte) (resultErr error) {
	offer, err := protocol.DecodeOffer(payload)
	if err != nil {
		return err
	}
	if offer.SessionID == "" || offer.BundleID == "" {
		return fmt.Errorf("invalid transfer offer")
	}
	if err := plan.SafeName(offer.BundleID); err != nil {
		return err
	}
	alias := "FlSteamLua"
	s.engine.mu.Lock()
	if known, ok := s.engine.peers[peer.fingerprint]; ok && known.Alias != "" {
		alias = known.Alias
	}
	trusted := s.engine.trusted[peer.fingerprint]
	s.engine.mu.Unlock()
	summary := model.OfferSummary{
		SessionID: offer.SessionID, BundleID: offer.BundleID, AppID: offer.AppID,
		GameName: offer.GameName, InstallDir: offer.InstallDir, CoverURL: offer.CoverURL,
		TotalBytes: offer.TotalBytes, SelectedBytes: offer.SelectedBytes,
		FileCount: offer.FileCount, ChunkCount: offer.ChunkCount,
		LuaEnabled: offer.LuaEnabled, ManifestAvailable: offer.ManifestAvailable,
		Warnings: offer.Warnings, Trusted: trusted.Fingerprint != "",
		ReceivedAt: time.Now().UnixMilli(),
		Peer: model.Peer{
			ID: peer.fingerprint, Alias: alias, Address: peer.conn.RemoteAddr().String(),
			Port: discovery.Port, Fingerprint: peer.fingerprint,
			Trusted: trusted.Fingerprint != "", LastSeen: time.Now().UnixMilli(),
		},
	}
	pending := &pendingOffer{
		conn: peer, summary: summary, decision: make(chan acceptDecision, 1),
	}
	session, err := s.engine.addIncomingSession(summary)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	session.mu.Lock()
	session.conn = peer
	session.cancel = cancel
	session.done = done
	session.mu.Unlock()
	defer func() {
		cancel()
		s.engine.mu.Lock()
		delete(s.engine.pending, summary.SessionID)
		s.engine.mu.Unlock()
		if resultErr != nil {
			s.engine.markSessionError(session, resultErr)
		}
		session.mu.Lock()
		if session.conn == peer {
			session.conn = nil
		}
		if session.cancel != nil {
			session.cancel = nil
		}
		session.done = nil
		session.mu.Unlock()
		_ = s.engine.persistSession(session)
		close(done)
	}()
	s.engine.mu.Lock()
	s.engine.pending[summary.SessionID] = pending
	s.engine.mu.Unlock()
	_ = s.engine.persistSession(session)
	s.engine.emitSession(session)
	s.engine.Emit("offer.received", summary)
	if s.engine.currentConfig().AutoAcceptTrusted && trusted.Fingerprint != "" && trusted.AutoAccept && trusted.DefaultLibraryRoot != "" {
		select {
		case pending.decision <- acceptDecision{
			accepted: true, target: trusted.DefaultLibraryRoot,
			luaRoot: s.engine.currentConfig().LuaRoot,
		}:
		default:
		}
	}
	firstRead := peer.prefetchFrame()
	var decision acceptDecision
	select {
	case decision = <-pending.decision:
	case <-firstRead.done:
		if firstRead.err != nil {
			return firstRead.err
		}
		if firstRead.frame.Type != protocol.FrameCancel {
			return fmt.Errorf("unexpected frame while awaiting transfer approval")
		}
		message := protocol.DecodeError(firstRead.frame.Payload)
		status := "cancelled"
		if strings.EqualFold(message, "paused") {
			status = "paused"
		}
		s.engine.updateSession(session, func(value *model.Session) {
			value.Status = status
			value.Message = message
		})
		return nil
	case <-ctx.Done():
		decision = acceptDecision{accepted: false, message: "cancelled"}
	case <-time.After(5 * time.Minute):
		decision = acceptDecision{accepted: false, message: "offer timed out"}
	}
	s.engine.mu.Lock()
	delete(s.engine.pending, summary.SessionID)
	s.engine.mu.Unlock()
	if !decision.accepted {
		_ = peer.write(protocol.Frame{
			Type: protocol.FrameDecision,
			Payload: protocol.EncodeDecision(protocol.Decision{
				Accepted: false, Message: decision.message,
			}),
		})
		s.engine.updateSession(session, func(value *model.Session) {
			value.Status = "cancelled"
			value.Message = decision.message
		})
		return nil
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	if err := peer.write(protocol.Frame{
		Type: protocol.FrameDecision,
		Payload: protocol.EncodeDecision(protocol.Decision{
			Accepted: true, TargetLibrary: decision.target,
			LuaRoot: decision.luaRoot, Remember: decision.remember,
		}),
	}); err != nil {
		return err
	}
	incoming, err := s.engine.prepareIncoming(
		session,
		peer,
		summary,
		decision.target,
		decision.luaRoot,
	)
	if err != nil {
		return err
	}
	return incoming.run(ctx)
}

func (e *Engine) addIncomingSession(offer model.OfferSummary) (*sessionRuntime, error) {
	address := ""
	if offer.Peer.Address != "" {
		address = offer.Peer.Address
	}
	runtime := &sessionRuntime{data: model.Session{
		ID: offer.SessionID, BundleID: offer.BundleID, AppID: offer.AppID,
		GameName: offer.GameName, CoverURL: offer.CoverURL, Direction: "receive",
		PeerID: offer.Peer.ID, PeerAlias: offer.Peer.Alias, PeerAddress: address,
		PeerFingerprint: offer.Peer.Fingerprint, Status: "waitingForApproval",
		TotalBytes: offer.SelectedBytes, TotalChunks: offer.ChunkCount,
		CanPause: false, CreatedAt: time.Now().Unix(),
	}}
	runtime.lastAt = time.Now()
	e.mu.Lock()
	for _, existing := range e.sessions {
		existing.mu.Lock()
		busy := existing.done != nil || existing.data.Status == "waitingForApproval"
		collision := existing.data.ID == runtime.data.ID ||
			(existing.data.Direction == "receive" && existing.data.AppID == runtime.data.AppID)
		existing.mu.Unlock()
		if busy && collision {
			e.mu.Unlock()
			return nil, fmt.Errorf("a transfer for this game is already active")
		}
	}
	e.sessions[runtime.data.ID] = runtime
	e.mu.Unlock()
	return runtime, nil
}

func suppressClosed(err error) bool {
	return errors.Is(err, net.ErrClosed) || errors.Is(err, context.Canceled)
}

func logServerError(err error) {
	if err != nil && !suppressClosed(err) {
		log.Printf("LAN transfer server: %v", err)
	}
}
