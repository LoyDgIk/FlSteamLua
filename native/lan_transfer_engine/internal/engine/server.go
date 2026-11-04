package engine

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"log"
	"net"
	"time"

	"flsteamlua/lan_transfer_engine/internal/discovery"
	"flsteamlua/lan_transfer_engine/internal/identity"
	"flsteamlua/lan_transfer_engine/internal/model"
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
		s.listener = nil
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
	if tcp, ok := raw.(*net.TCPConn); ok {
		_ = tcp.SetKeepAlive(true)
		_ = tcp.SetKeepAlivePeriod(15 * time.Second)
	}
	_ = conn.SetDeadline(time.Now().Add(15 * time.Second))
	if err := conn.Handshake(); err != nil {
		_ = conn.Close()
		return
	}
	_ = conn.SetDeadline(time.Time{})
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

func (s *transferServer) handleOffer(peer *peerConn, payload []byte) error {
	offer, err := protocol.DecodeOffer(payload)
	if err != nil {
		return err
	}
	if offer.SessionID == "" || offer.BundleID == "" {
		return fmt.Errorf("invalid transfer offer")
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
	session := s.engine.addIncomingSession(summary)
	s.engine.mu.Lock()
	s.engine.pending[summary.SessionID] = pending
	s.engine.mu.Unlock()
	s.engine.Emit("offer.received", summary)
	if trusted.Fingerprint != "" && trusted.AutoAccept && trusted.DefaultLibraryRoot != "" {
		select {
		case pending.decision <- acceptDecision{
			accepted: true, target: trusted.DefaultLibraryRoot,
			luaRoot: s.engine.currentConfig().LuaRoot,
		}:
		default:
		}
	}
	var decision acceptDecision
	select {
	case decision = <-pending.decision:
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
	return incoming.run(context.Background())
}

func (e *Engine) addIncomingSession(offer model.OfferSummary) *sessionRuntime {
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
	e.sessions[runtime.data.ID] = runtime
	e.mu.Unlock()
	e.emitSession(runtime)
	return runtime
}

func suppressClosed(err error) bool {
	return errors.Is(err, net.ErrClosed) || errors.Is(err, context.Canceled)
}

func logServerError(err error) {
	if err != nil && !suppressClosed(err) {
		log.Printf("LAN transfer server: %v", err)
	}
}
