package engine

import (
	"crypto/tls"
	"fmt"
	"sync"
	"time"

	"flsteamlua/lan_transfer_engine/internal/identity"
	"flsteamlua/lan_transfer_engine/internal/protocol"
)

type peerConn struct {
	conn        *tls.Conn
	fingerprint string
	readMu      sync.Mutex
	writeMu     sync.Mutex
	readAhead   *peerFrameRead
}

type peerFrameRead struct {
	done  chan struct{}
	frame protocol.Frame
	err   error
}

func (c *peerConn) read() (protocol.Frame, error) {
	c.readMu.Lock()
	defer c.readMu.Unlock()
	if ahead := c.readAhead; ahead != nil {
		c.readAhead = nil
		<-ahead.done
		return ahead.frame, ahead.err
	}
	return protocol.ReadFrame(c.conn)
}

// Read one frame while an offer awaits a decision. The next read consumes the
// same result, so accepting an offer cannot lose its already-arriving PlanStart.
func (c *peerConn) prefetchFrame() *peerFrameRead {
	c.readMu.Lock()
	defer c.readMu.Unlock()
	ahead := &peerFrameRead{done: make(chan struct{})}
	c.readAhead = ahead
	go func() {
		ahead.frame, ahead.err = protocol.ReadFrame(c.conn)
		close(ahead.done)
	}()
	return ahead
}

func (c *peerConn) write(frame protocol.Frame) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	return protocol.WriteFrame(c.conn, frame)
}

func (c *peerConn) writeChunk(index uint32, data []byte) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	return protocol.WriteChunkFrame(c.conn, index, data)
}

func (c *peerConn) close() {
	_ = c.conn.Close()
}

func (c *peerConn) stop(reason string) {
	_ = c.conn.SetWriteDeadline(time.Now().Add(time.Second))
	_ = c.write(protocol.Frame{Type: protocol.FrameCancel, Payload: protocol.EncodeError(reason)})
	c.close()
}

func (e *Engine) performServerHello(conn *tls.Conn) (*peerConn, error) {
	peer := &peerConn{
		conn:        conn,
		fingerprint: identity.PeerFingerprint(conn.ConnectionState()),
	}
	frame, err := peer.read()
	if err != nil {
		return nil, err
	}
	if frame.Type != protocol.FrameHello {
		return nil, fmt.Errorf("peer did not start with hello")
	}
	hello, err := protocol.DecodeHello(frame.Payload)
	if err != nil || hello.Protocol != protocol.LANProtocol {
		return nil, fmt.Errorf("incompatible LAN transfer protocol")
	}
	if hello.Fingerprint != peer.fingerprint {
		return nil, fmt.Errorf("peer hello fingerprint mismatch")
	}
	identity := e.currentIdentity()
	config := e.currentConfig()
	if identity == nil {
		return nil, fmt.Errorf("engine identity is unavailable")
	}
	if err := peer.write(protocol.Frame{
		Type: protocol.FrameHello,
		Payload: protocol.EncodeHello(protocol.Hello{
			Protocol: protocol.LANProtocol, Alias: config.DisplayName,
			Fingerprint: identity.Fingerprint, Receiving: config.ReceiveEnabled,
		}),
	}); err != nil {
		return nil, err
	}
	return peer, nil
}

func (e *Engine) performClientHello(peer *peerConn, address, alias, fingerprint string) (protocol.Hello, error) {
	if err := peer.write(protocol.Frame{
		Type: protocol.FrameHello,
		Payload: protocol.EncodeHello(protocol.Hello{
			Protocol: protocol.LANProtocol, Alias: alias,
			Fingerprint: fingerprint, Receiving: true,
		}),
	}); err != nil {
		return protocol.Hello{}, err
	}
	frame, err := peer.read()
	if err != nil {
		return protocol.Hello{}, err
	}
	if frame.Type != protocol.FrameHello {
		return protocol.Hello{}, fmt.Errorf("peer did not acknowledge hello")
	}
	hello, err := protocol.DecodeHello(frame.Payload)
	if err != nil || hello.Protocol != protocol.LANProtocol {
		return protocol.Hello{}, fmt.Errorf("incompatible LAN transfer protocol")
	}
	if hello.Fingerprint != peer.fingerprint {
		return protocol.Hello{}, fmt.Errorf("peer certificate changed")
	}
	return hello, nil
}
