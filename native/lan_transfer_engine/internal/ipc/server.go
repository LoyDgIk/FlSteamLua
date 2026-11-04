package ipc

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"sync"

	"flsteamlua/lan_transfer_engine/internal/engine"
)

type request struct {
	ID     json.RawMessage `json:"id"`
	Method string          `json:"method"`
	Params json.RawMessage `json:"params"`
}

type response struct {
	ID     json.RawMessage `json:"id,omitempty"`
	Result any             `json:"result,omitempty"`
	Error  *rpcError       `json:"error,omitempty"`
	Event  string          `json:"event,omitempty"`
	Data   any             `json:"data,omitempty"`
}

type rpcError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

type Server struct {
	engine *engine.Engine
	mu     sync.Mutex
	output io.Writer
	done   chan struct{}
	once   sync.Once
}

func New(engine *engine.Engine, output io.Writer) *Server {
	return &Server{engine: engine, output: output, done: make(chan struct{})}
}

func (s *Server) Run() error {
	go s.forwardEvents()
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 64*1024), 8*1024*1024)
	for scanner.Scan() {
		var value request
		if err := json.Unmarshal(scanner.Bytes(), &value); err != nil {
			s.write(response{Error: &rpcError{Code: "invalid_json", Message: err.Error()}})
			continue
		}
		result, err := s.engine.Execute(value.Method, value.Params)
		if err != nil {
			s.write(response{ID: value.ID, Error: &rpcError{Code: "engine_error", Message: err.Error()}})
			continue
		}
		s.write(response{ID: value.ID, Result: result})
	}
	s.once.Do(func() { close(s.done) })
	s.engine.Close()
	return scanner.Err()
}

func (s *Server) forwardEvents() {
	for {
		select {
		case event, ok := <-s.engine.Events():
			if !ok {
				return
			}
			s.write(response{Event: event.Name, Data: event.Data})
		case <-s.done:
			return
		}
	}
}

func (s *Server) write(value response) {
	s.mu.Lock()
	defer s.mu.Unlock()
	data, err := json.Marshal(value)
	if err != nil {
		data, _ = json.Marshal(response{Error: &rpcError{Code: "encode", Message: fmt.Sprint(err)}})
	}
	_, _ = s.output.Write(append(data, '\n'))
}
