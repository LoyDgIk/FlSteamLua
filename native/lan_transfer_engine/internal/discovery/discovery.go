package discovery

import (
	"encoding/json"
	"errors"
	"net"
	"sync"
	"time"

	"flsteamlua/lan_transfer_engine/internal/model"
	"flsteamlua/lan_transfer_engine/internal/protocol"
)

const (
	Port      = 47821
	Multicast = "239.255.42.99"
)

type announcer struct {
	Protocol    string `json:"protocol"`
	Kind        string `json:"kind"`
	Alias       string `json:"alias"`
	Fingerprint string `json:"fingerprint"`
	Port        int    `json:"port"`
	Receiving   bool   `json:"receiving"`
}

type Service struct {
	mu          sync.Mutex
	conn        *net.UDPConn
	done        chan struct{}
	alias       string
	fingerprint string
	receiving   bool
	trusted     map[string]bool
	peers       map[string]model.Peer
	onChanged   func([]model.Peer)
}

func New(onChanged func([]model.Peer)) *Service {
	return &Service{onChanged: onChanged, peers: make(map[string]model.Peer), trusted: make(map[string]bool)}
}

func (s *Service) Start(alias, fingerprint string, trusted map[string]bool) error {
	s.mu.Lock()
	if s.conn != nil {
		s.mu.Unlock()
		return nil
	}
	address := &net.UDPAddr{IP: net.IPv4zero, Port: Port}
	conn, err := net.ListenMulticastUDP("udp4", nil, &net.UDPAddr{
		IP: net.ParseIP(Multicast), Port: Port,
	})
	if err != nil {
		conn, err = net.ListenUDP("udp4", address)
	}
	if err != nil {
		s.mu.Unlock()
		return err
	}
	_ = conn.SetReadBuffer(256 * 1024)
	s.conn = conn
	s.alias = alias
	s.fingerprint = fingerprint
	s.trusted = trusted
	s.done = make(chan struct{})
	s.mu.Unlock()
	go s.readLoop(conn)
	go s.announceLoop()
	return nil
}

func (s *Service) Stop() {
	s.mu.Lock()
	conn := s.conn
	done := s.done
	s.conn = nil
	s.done = nil
	s.mu.Unlock()
	if done != nil {
		close(done)
	}
	if conn != nil {
		_ = conn.Close()
	}
	s.mu.Lock()
	s.peers = make(map[string]model.Peer)
	s.mu.Unlock()
	s.changed()
}

func (s *Service) SetReceiving(value bool) {
	s.mu.Lock()
	s.receiving = value
	s.mu.Unlock()
}

func (s *Service) SetTrusted(values map[string]bool) {
	s.mu.Lock()
	s.trusted = values
	for id, peer := range s.peers {
		peer.Trusted = values[peer.Fingerprint]
		s.peers[id] = peer
	}
	s.mu.Unlock()
	s.changed()
}

func (s *Service) Snapshot() []model.Peer {
	s.mu.Lock()
	defer s.mu.Unlock()
	result := make([]model.Peer, 0, len(s.peers))
	for _, peer := range s.peers {
		result = append(result, peer)
	}
	sortPeers(result)
	return result
}

func (s *Service) Upsert(peer model.Peer) {
	s.mu.Lock()
	s.peers[peer.Fingerprint] = peer
	s.mu.Unlock()
	s.changed()
}

func (s *Service) readLoop(conn *net.UDPConn) {
	buffer := make([]byte, 64*1024)
	for {
		_ = conn.SetReadDeadline(time.Now().Add(time.Second))
		size, address, err := conn.ReadFromUDP(buffer)
		if err != nil {
			var netErr net.Error
			if errors.As(err, &netErr) && netErr.Timeout() {
				s.prune()
				continue
			}
			return
		}
		var value announcer
		if json.Unmarshal(buffer[:size], &value) != nil ||
			value.Protocol != protocol.LANProtocol ||
			value.Kind != "announce" ||
			!value.Receiving ||
			value.Fingerprint == "" {
			continue
		}
		s.mu.Lock()
		if value.Fingerprint == s.fingerprint {
			s.mu.Unlock()
			continue
		}
		peer := model.Peer{
			ID: value.Fingerprint, Alias: value.Alias, Address: address.IP.String(),
			Port: value.Port, Fingerprint: value.Fingerprint,
			Trusted: s.trusted[value.Fingerprint], LastSeen: time.Now().UnixMilli(),
		}
		if peer.Alias == "" {
			peer.Alias = peer.Address
		}
		s.peers[peer.Fingerprint] = peer
		s.mu.Unlock()
		s.changed()
	}
}

func (s *Service) announceLoop() {
	ticker := time.NewTicker(3 * time.Second)
	defer ticker.Stop()
	s.send()
	for {
		s.mu.Lock()
		done := s.done
		s.mu.Unlock()
		if done == nil {
			return
		}
		select {
		case <-done:
			return
		case <-ticker.C:
			s.send()
		}
	}
}

func (s *Service) send() {
	s.mu.Lock()
	conn := s.conn
	alias := s.alias
	fingerprint := s.fingerprint
	receiving := s.receiving
	s.mu.Unlock()
	if conn == nil || !receiving {
		return
	}
	data, _ := json.Marshal(announcer{
		Protocol: protocol.LANProtocol, Kind: "announce", Alias: alias,
		Fingerprint: fingerprint, Port: Port, Receiving: true,
	})
	_, _ = conn.WriteToUDP(data, &net.UDPAddr{IP: net.ParseIP(Multicast), Port: Port})
	_, _ = conn.WriteToUDP(data, &net.UDPAddr{IP: net.IPv4bcast, Port: Port})
}

func (s *Service) prune() {
	cutoff := time.Now().Add(-18 * time.Second).UnixMilli()
	changed := false
	s.mu.Lock()
	for id, peer := range s.peers {
		if peer.LastSeen < cutoff {
			delete(s.peers, id)
			changed = true
		}
	}
	s.mu.Unlock()
	if changed {
		s.changed()
	}
}

func (s *Service) changed() {
	if s.onChanged != nil {
		s.onChanged(s.Snapshot())
	}
}

func sortPeers(values []model.Peer) {
	for i := 0; i < len(values); i++ {
		for j := i + 1; j < len(values); j++ {
			if values[j].Trusted && !values[i].Trusted ||
				values[j].Trusted == values[i].Trusted && values[j].Alias < values[i].Alias {
				values[i], values[j] = values[j], values[i]
			}
		}
	}
}
