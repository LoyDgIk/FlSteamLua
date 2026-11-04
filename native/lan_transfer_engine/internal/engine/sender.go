package engine

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"os"
	"sync"
	"time"

	"flsteamlua/lan_transfer_engine/internal/discovery"
	"flsteamlua/lan_transfer_engine/internal/identity"
	"flsteamlua/lan_transfer_engine/internal/model"
	"flsteamlua/lan_transfer_engine/internal/protocol"
)

type outboundChunkSource struct {
	Path   string
	Offset int64
	Size   int64
}

type outboundReader struct {
	mu      sync.Mutex
	sources map[uint32]outboundChunkSource
	files   map[string]*os.File
	pool    sync.Pool
}

func (e *Engine) runSend(sessionID string, peer model.Peer, transferPlan *model.Plan) {
	runtime := e.session(sessionID)
	if runtime == nil {
		return
	}
	id := e.currentIdentity()
	if id == nil {
		e.markSessionError(runtime, fmt.Errorf("engine is not configured"))
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	runtime.mu.Lock()
	if runtime.cancel != nil {
		runtime.cancel()
	}
	runtime.cancel = cancel
	runtime.plan = transferPlan
	runtime.peer = peer
	runtime.data.Status = "waitingForApproval"
	runtime.mu.Unlock()
	defer cancel()
	e.emitSession(runtime)
	config := e.currentConfig()
	address := net.JoinHostPort(peer.Address, fmt.Sprint(peer.Port))
	if peer.Port == 0 {
		address = net.JoinHostPort(peer.Address, fmt.Sprint(discovery.Port))
	}
	raw, err := tls.DialWithDialer(
		&net.Dialer{Timeout: 8 * time.Second},
		"tcp",
		address,
		id.ClientConfig(peer.Fingerprint),
	)
	if err != nil {
		e.markSessionError(runtime, err)
		return
	}
	conn := &peerConn{conn: raw, fingerprint: identity.PeerFingerprint(raw.ConnectionState())}
	runtime.mu.Lock()
	runtime.conn = conn
	runtime.mu.Unlock()
	defer func() {
		conn.close()
		runtime.mu.Lock()
		if runtime.conn == conn {
			runtime.conn = nil
		}
		runtime.mu.Unlock()
	}()
	if _, err := e.performClientHello(conn, peer.Address, config.DisplayName, id.Fingerprint); err != nil {
		e.markSessionError(runtime, err)
		return
	}
	offer := protocol.Offer{
		SessionID: runtime.data.ID, BundleID: runtime.data.BundleID,
		AppID: transferPlan.AppID, GameName: transferPlan.GameName,
		InstallDir: transferPlan.InstallDir, CoverURL: transferPlan.CoverURL,
		TotalBytes: runtime.data.TotalBytes, SelectedBytes: runtime.data.TotalBytes,
		FileCount: len(transferPlan.Files), ChunkCount: len(transferPlan.Chunks),
		LuaEnabled: transferPlan.LuaEnabled, ManifestAvailable: transferPlan.ManifestAvailable,
		Warnings: transferPlan.Warnings,
	}
	if err := conn.write(protocol.Frame{Type: protocol.FrameOffer, Payload: protocol.EncodeOffer(offer)}); err != nil {
		e.markSessionError(runtime, err)
		return
	}
	decisionFrame, err := conn.read()
	if err != nil {
		e.markSessionError(runtime, err)
		return
	}
	if decisionFrame.Type != protocol.FrameDecision {
		e.markSessionError(runtime, fmt.Errorf("peer returned an invalid offer decision"))
		return
	}
	decision, err := protocol.DecodeDecision(decisionFrame.Payload)
	if err != nil || !decision.Accepted {
		message := decision.Message
		if message == "" {
			message = "transfer rejected"
		}
		runtime.mu.Lock()
		runtime.data.Status = "cancelled"
		runtime.data.Message = message
		runtime.mu.Unlock()
		e.emitSession(runtime)
		return
	}
	if err := sendPlan(conn, transferPlan); err != nil {
		e.markSessionError(runtime, err)
		return
	}
	readyFrame, err := conn.read()
	if err != nil {
		e.markSessionError(runtime, err)
		return
	}
	if readyFrame.Type != protocol.FramePlanReady {
		e.markSessionError(runtime, fmt.Errorf("peer did not acknowledge the transfer plan"))
		return
	}
	ready, err := protocol.DecodePlanReady(readyFrame.Payload)
	if err != nil {
		e.markSessionError(runtime, err)
		return
	}
	missing, presentBytes, cachedChunks := missingChunks(transferPlan, ready.Bitmap)
	runtime.mu.Lock()
	runtime.data.Status = "transferring"
	runtime.data.CachedChunks = cachedChunks
	runtime.data.CompletedChunks = cachedChunks
	runtime.data.TransferredBytes = presentBytes
	runtime.mu.Unlock()
	e.emitSession(runtime)
	sources := outboundSources(transferPlan)
	reader := &outboundReader{
		sources: sources,
		files:   make(map[string]*os.File),
	}
	reader.pool.New = func() any { return make([]byte, 4*1024*1024) }
	defer reader.close()
	frames := make(chan protocol.Frame, 128)
	readErr := make(chan error, 1)
	go readPeerFrames(ctx, conn, frames, readErr)
	if err := sendMissingChunks(
		ctx, e, runtime, conn, transferPlan, missing, reader, int(ready.Window), frames, readErr,
	); err != nil {
		e.markSessionError(runtime, err)
		return
	}
	for {
		if err := conn.write(protocol.Frame{Type: protocol.FrameFinish, Payload: protocol.EncodeFinish(protocol.Finish{Status: "finish"})}); err != nil {
			e.markSessionError(runtime, err)
			return
		}
		select {
		case frame := <-frames:
			switch frame.Type {
			case protocol.FrameFinishResult:
				result, _ := protocol.DecodeFinish(frame.Payload)
				switch result.Status {
				case "completed":
					e.markSessionCompleted(runtime)
					return
				case "waitingForSteamExit":
					runtime.mu.Lock()
					runtime.data.Status = "waitingForSteamExit"
					runtime.data.Message = result.Message
					runtime.mu.Unlock()
					e.emitSession(runtime)
					time.Sleep(2 * time.Second)
				case "cancelled", "paused":
					runtime.mu.Lock()
					runtime.data.Status = result.Status
					runtime.data.Message = result.Message
					runtime.mu.Unlock()
					e.emitSession(runtime)
					return
				default:
					e.markSessionError(runtime, fmt.Errorf("%s", result.Message))
					return
				}
			case protocol.FrameError:
				e.markSessionError(runtime, fmt.Errorf("%s", protocol.DecodeError(frame.Payload)))
				return
			default:
				continue
			}
		case err := <-readErr:
			e.markSessionError(runtime, err)
			return
		case <-ctx.Done():
			_ = conn.write(protocol.Frame{Type: protocol.FrameCancel, Payload: protocol.EncodeError("cancelled")})
			return
		}
	}
}

func sendPlan(conn *peerConn, value *model.Plan) error {
	start := protocol.PlanStart{
		PlanID: value.ID, BundleID: value.ID, AppID: value.AppID,
		GameName: value.GameName, InstallDir: value.InstallDir, CoverURL: value.CoverURL,
		SourceAppManifest: value.SourceAppManifest, LuaContent: value.LuaContent,
		LuaEnabled: value.LuaEnabled, ManifestAvailable: value.ManifestAvailable,
		TotalBytes: selectedBytes(value), FileCount: len(value.Files),
		ChunkCount: len(value.Chunks), Warnings: value.Warnings,
	}
	if err := conn.write(protocol.Frame{Type: protocol.FramePlanStart, Payload: protocol.EncodePlanStart(start)}); err != nil {
		return err
	}
	for startIndex := 0; startIndex < len(value.Files); {
		end := startIndex
		size := 0
		for end < len(value.Files) {
			item := len(protocol.EncodePlanFile(value.Files[end]))
			if end > startIndex && size+item > 8*1024*1024 {
				break
			}
			size += item
			end++
		}
		if err := conn.write(protocol.Frame{
			Type:    protocol.FramePlanFiles,
			Payload: protocol.EncodePlanFiles(value.Files[startIndex:end]),
		}); err != nil {
			return err
		}
		startIndex = end
	}
	for startIndex := 0; startIndex < len(value.Chunks); {
		end := startIndex
		size := 0
		for end < len(value.Chunks) {
			item := len(protocol.EncodePlanChunk(value.Chunks[end]))
			if end > startIndex && size+item > 8*1024*1024 {
				break
			}
			size += item
			end++
		}
		if err := conn.write(protocol.Frame{
			Type:    protocol.FramePlanChunks,
			Payload: protocol.EncodePlanChunks(value.Chunks[startIndex:end]),
		}); err != nil {
			return err
		}
		startIndex = end
	}
	return conn.write(protocol.Frame{Type: protocol.FramePlanEnd})
}

func missingChunks(value *model.Plan, bitmap []byte) ([]uint32, int64, int) {
	var missing []uint32
	var presentBytes int64
	cached := 0
	for index, chunk := range value.Chunks {
		present := index/8 < len(bitmap) && bitmap[index/8]&(1<<uint(index%8)) != 0
		if present {
			presentBytes += chunk.Size
			cached++
		} else {
			missing = append(missing, uint32(index))
		}
	}
	return missing, presentBytes, cached
}

func outboundSources(value *model.Plan) map[uint32]outboundChunkSource {
	result := make(map[uint32]outboundChunkSource)
	for _, file := range value.Files {
		if file.SourcePath == "" {
			continue
		}
		for _, ref := range file.Chunks {
			result[ref.ChunkIndex] = outboundChunkSource{
				Path: file.SourcePath, Offset: ref.Offset, Size: ref.Size,
			}
		}
	}
	return result
}

func sendMissingChunks(
	ctx context.Context,
	engine *Engine,
	runtime *sessionRuntime,
	conn *peerConn,
	value *model.Plan,
	missing []uint32,
	reader *outboundReader,
	window int,
	frames <-chan protocol.Frame,
	readErr <-chan error,
) error {
	if window <= 0 {
		window = 16
	}
	if window > 32 {
		window = 32
	}
	if window > len(missing) {
		window = len(missing)
	}
	if window == 0 {
		return nil
	}
	next := 0
	inFlight := 0
	for next < len(missing) && inFlight < window {
		go sendChunkFrame(conn, value, missing[next], reader)
		next++
		inFlight++
	}
	completed := 0
	for completed < len(missing) {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case err := <-readErr:
			return err
		case frame := <-frames:
			if frame.Type == protocol.FrameError {
				return fmt.Errorf("%s", protocol.DecodeError(frame.Payload))
			}
			if frame.Type != protocol.FrameChunkAck {
				continue
			}
			ack, err := protocol.DecodeChunkAck(frame.Payload)
			if err != nil {
				return err
			}
			if !ack.OK {
				return fmt.Errorf("receiver rejected chunk %d: %s", ack.Index, ack.Message)
			}
			completed++
			inFlight--
			chunk := value.Chunks[ack.Index]
			engine.updateSession(runtime, func(data *model.Session) {
				data.TransferredBytes += chunk.Size
				data.CompletedChunks++
			})
			if next < len(missing) {
				go sendChunkFrame(conn, value, missing[next], reader)
				next++
				inFlight++
			}
		}
	}
	return nil
}

func sendChunkFrame(conn *peerConn, value *model.Plan, index uint32, reader *outboundReader) {
	data, err := reader.read(index, value.Chunks[index])
	if err != nil {
		_ = conn.write(protocol.Frame{Type: protocol.FrameError, Payload: protocol.EncodeError(err.Error())})
		return
	}
	defer reader.release(data)
	if err := conn.writeChunk(index, data); err != nil {
		_ = conn.write(protocol.Frame{Type: protocol.FrameError, Payload: protocol.EncodeError(err.Error())})
	}
}

func (r *outboundReader) read(index uint32, chunk model.Chunk) ([]byte, error) {
	source, ok := r.sources[index]
	if !ok {
		return nil, fmt.Errorf("chunk source is unavailable")
	}
	data := r.pool.Get().([]byte)
	if int64(cap(data)) < source.Size {
		data = make([]byte, source.Size)
	} else {
		data = data[:source.Size]
	}
	file, err := r.file(source.Path)
	if err != nil {
		r.release(data)
		return nil, err
	}
	read, err := file.ReadAt(data, source.Offset)
	if err != nil || read != len(data) {
		r.release(data)
		if err != nil {
			return nil, err
		}
		return nil, fmt.Errorf("source chunk changed while transferring")
	}
	return data, nil
}

func (r *outboundReader) file(path string) (*os.File, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if existing := r.files[path]; existing != nil {
		return existing, nil
	}
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	r.files[path] = file
	return file, nil
}

func (r *outboundReader) release(data []byte) {
	if cap(data) == 4*1024*1024 {
		r.pool.Put(data[:4*1024*1024])
	}
}

func (r *outboundReader) close() {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, file := range r.files {
		_ = file.Close()
	}
	r.files = make(map[string]*os.File)
}

func readPeerFrames(ctx context.Context, conn *peerConn, output chan<- protocol.Frame, result chan<- error) {
	for {
		frame, err := conn.read()
		if err != nil {
			select {
			case result <- err:
			default:
			}
			return
		}
		select {
		case output <- frame:
		case <-ctx.Done():
			return
		}
	}
}
