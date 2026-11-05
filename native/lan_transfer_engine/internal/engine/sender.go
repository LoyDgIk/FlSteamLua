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
	mu        sync.Mutex
	sources   map[uint32]outboundChunkSource
	files     map[string]*outboundFile
	remaining map[string]int
	pool      sync.Pool
}

type outboundFile struct {
	file   *os.File
	active int
}

type peerRead struct {
	frame protocol.Frame
	err   error
}

func (e *Engine) runSend(ctx context.Context, runtime *sessionRuntime, peer model.Peer, transferPlan *model.Plan) {
	if runtime == nil {
		return
	}
	id := e.currentIdentity()
	if id == nil {
		e.markSessionError(runtime, fmt.Errorf("engine is not configured"))
		return
	}
	if err := ctx.Err(); err != nil {
		e.markSessionError(runtime, err)
		return
	}
	runtime.mu.Lock()
	if ctx.Err() != nil {
		runtime.mu.Unlock()
		return
	}
	runtime.plan = transferPlan
	runtime.peer = peer
	runtime.data.Status = "waitingForApproval"
	runtime.mu.Unlock()
	defer func() {
		if ctx.Err() != nil {
			runtime.mu.Lock()
			status := runtime.data.Status
			runtime.mu.Unlock()
			if status != "paused" && status != "cancelled" && status != "completed" {
				e.markSessionError(runtime, ctx.Err())
			}
		}
	}()
	e.emitSession(runtime)
	config := e.currentConfig()
	address := net.JoinHostPort(peer.Address, fmt.Sprint(peer.Port))
	if peer.Port == 0 {
		address = net.JoinHostPort(peer.Address, fmt.Sprint(discovery.Port))
	}
	dialer := tls.Dialer{NetDialer: &net.Dialer{Timeout: 8 * time.Second}, Config: id.ClientConfig(peer.Fingerprint)}
	connection, err := dialer.DialContext(ctx, "tcp", address)
	if err != nil {
		e.markSessionError(runtime, err)
		return
	}
	raw := connection.(*tls.Conn)
	conn := &peerConn{conn: raw, fingerprint: identity.PeerFingerprint(raw.ConnectionState())}
	runtime.mu.Lock()
	runtime.conn = conn
	runtime.mu.Unlock()
	if ctx.Err() != nil {
		conn.close()
		e.markSessionError(runtime, ctx.Err())
		return
	}
	defer func() {
		conn.close()
		runtime.mu.Lock()
		if runtime.conn == conn {
			runtime.conn = nil
		}
		runtime.mu.Unlock()
	}()
	_ = raw.SetDeadline(time.Now().Add(15 * time.Second))
	if _, err := e.performClientHello(conn, peer.Address, config.DisplayName, id.Fingerprint); err != nil {
		e.markSessionError(runtime, err)
		return
	}
	_ = raw.SetDeadline(time.Time{})
	_ = raw.SetReadDeadline(time.Now().Add(5*time.Minute + 15*time.Second))
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
	// Receivers may hash a large installed game before reporting the bitmap.
	_ = raw.SetReadDeadline(time.Time{})
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
	if ctx.Err() != nil {
		runtime.mu.Unlock()
		return
	}
	runtime.data.Status = "transferring"
	runtime.data.CachedChunks = cachedChunks
	runtime.data.CompletedChunks = cachedChunks
	runtime.data.TransferredBytes = presentBytes
	runtime.data.NetworkBytes = 0
	runtime.lastBytes = 0
	runtime.lastAt = time.Now()
	runtime.mu.Unlock()
	e.emitSession(runtime)
	sources := outboundSources(transferPlan)
	reader := &outboundReader{
		sources:   sources,
		files:     make(map[string]*outboundFile),
		remaining: make(map[string]int),
	}
	for _, index := range missing {
		reader.remaining[sources[index].Path]++
	}
	reader.pool.New = func() any { return make([]byte, 4*1024*1024) }
	defer reader.close()
	frames := make(chan peerRead, 128)
	go readPeerFrames(ctx, conn, frames)
	if err := sendMissingChunks(
		ctx, e, runtime, conn, transferPlan, missing, reader, int(ready.Window), frames,
	); err != nil {
		e.markSessionError(runtime, err)
		return
	}
	finishRequested := false
	for {
		if !finishRequested {
			if err := conn.write(protocol.Frame{Type: protocol.FrameFinish, Payload: protocol.EncodeFinish(protocol.Finish{Status: "finish"})}); err != nil {
				e.markSessionError(runtime, err)
				return
			}
			finishRequested = true
		}
		select {
		case received := <-frames:
			if received.err != nil {
				e.markSessionError(runtime, received.err)
				return
			}
			frame := received.frame
			switch frame.Type {
			case protocol.FrameProgress:
				if err := e.applyPeerProgress(runtime, frame.Payload); err != nil {
					e.markSessionError(runtime, err)
					return
				}
			case protocol.FrameFinishResult:
				result, _ := protocol.DecodeFinish(frame.Payload)
				switch result.Status {
				case "completed":
					e.markSessionCompleted(runtime)
					return
				case "waitingForSteamExit":
					e.updateSession(runtime, func(data *model.Session) {
						data.Status = "waitingForSteamExit"
						data.Message = result.Message
					})
					select {
					case <-ctx.Done():
						return
					case <-time.After(2 * time.Second):
					}
					finishRequested = false
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
	for index := range value.Chunks {
		present := index/8 < len(bitmap) && bitmap[index/8]&(1<<uint(index%8)) != 0
		if present {
			cached++
		} else {
			missing = append(missing, uint32(index))
		}
	}
	for _, file := range value.Files {
		for _, ref := range file.Chunks {
			if int(ref.ChunkIndex)/8 < len(bitmap) && bitmap[ref.ChunkIndex/8]&(1<<uint(ref.ChunkIndex%8)) != 0 {
				presentBytes += ref.Size
			}
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
	frames <-chan peerRead,
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
	logicalBytes := make([]int64, len(value.Chunks))
	for _, file := range value.Files {
		for _, ref := range file.Chunks {
			logicalBytes[ref.ChunkIndex] += ref.Size
		}
	}
	workers := sync.WaitGroup{}
	sendErrors := make(chan error, window)
	inFlightChunks := make(map[uint32]bool, window)
	defer func() {
		// Unblock writers before closing their file handles on cancellation/error.
		if len(inFlightChunks) != 0 {
			conn.close()
		}
		workers.Wait()
	}()
	send := func(index uint32) {
		inFlightChunks[index] = true
		workers.Add(1)
		go func() {
			defer workers.Done()
			if err := sendChunkFrame(conn, value, index, reader); err != nil {
				select {
				case sendErrors <- err:
				default:
				}
			}
		}()
	}
	next := 0
	inFlight := 0
	for next < len(missing) && inFlight < window {
		send(missing[next])
		next++
		inFlight++
	}
	completed := 0
	for completed < len(missing) {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case err := <-sendErrors:
			return err
		case received := <-frames:
			if received.err != nil {
				return received.err
			}
			frame := received.frame
			if frame.Type == protocol.FrameProgress {
				if err := engine.applyPeerProgress(runtime, frame.Payload); err != nil {
					return err
				}
				continue
			}
			if frame.Type == protocol.FrameError {
				return fmt.Errorf("%s", protocol.DecodeError(frame.Payload))
			}
			if frame.Type != protocol.FrameChunkAck {
				if frame.Type == protocol.FrameCancel || frame.Type == protocol.FrameFinishResult {
					return fmt.Errorf("peer stopped the transfer")
				}
				continue
			}
			ack, err := protocol.DecodeChunkAck(frame.Payload)
			if err != nil {
				return err
			}
			if !ack.OK {
				return fmt.Errorf("receiver rejected chunk %d: %s", ack.Index, ack.Message)
			}
			if !inFlightChunks[ack.Index] {
				return fmt.Errorf("unexpected chunk acknowledgement %d", ack.Index)
			}
			delete(inFlightChunks, ack.Index)
			completed++
			inFlight--
			chunk := value.Chunks[ack.Index]
			engine.updateSession(runtime, func(data *model.Session) {
				data.TransferredBytes += logicalBytes[ack.Index]
				data.NetworkBytes += chunk.Size
				data.CompletedChunks++
			})
			if next < len(missing) {
				send(missing[next])
				next++
				inFlight++
			}
		}
	}
	return nil
}

func (e *Engine) applyPeerProgress(runtime *sessionRuntime, payload []byte) error {
	progress, err := protocol.DecodeProgress(payload)
	if err != nil {
		return err
	}
	runtime.mu.Lock()
	totalFiles, totalBytes := runtime.data.TotalFiles, runtime.data.TotalBytes
	runtime.mu.Unlock()
	if progress.TotalFiles != totalFiles || progress.InstalledFiles > totalFiles || progress.InstalledBytes > totalBytes {
		return fmt.Errorf("invalid peer installation progress")
	}
	switch progress.Status {
	case "preparing", "transferring", "verifying", "committing", "waitingForSteamExit", "completed", "failed", "cancelled", "paused":
	default:
		return fmt.Errorf("invalid peer transfer status")
	}
	e.updateSession(runtime, func(data *model.Session) {
		data.DiskBytes = progress.DiskBytes
		data.DiskSpeed = progress.DiskSpeed
		data.InstalledBytes = progress.InstalledBytes
		data.InstalledFiles = progress.InstalledFiles
		switch progress.Status {
		case "verifying", "committing", "waitingForSteamExit":
			data.Status = progress.Status
		}
	})
	return nil
}

func sendChunkFrame(conn *peerConn, value *model.Plan, index uint32, reader *outboundReader) error {
	data, err := reader.read(index, value.Chunks[index])
	if err != nil {
		return err
	}
	defer reader.release(data)
	return conn.writeChunk(index, data)
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
	read, err := file.file.ReadAt(data, source.Offset)
	r.releaseFile(source.Path, file)
	if err != nil || read != len(data) {
		r.release(data)
		if err != nil {
			return nil, err
		}
		return nil, fmt.Errorf("source chunk changed while transferring")
	}
	return data, nil
}

func (r *outboundReader) file(path string) (*outboundFile, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if existing := r.files[path]; existing != nil {
		existing.active++
		return existing, nil
	}
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	value := &outboundFile{file: file, active: 1}
	r.files[path] = value
	return value, nil
}

func (r *outboundReader) releaseFile(path string, value *outboundFile) {
	r.mu.Lock()
	defer r.mu.Unlock()
	value.active--
	r.remaining[path]--
	if value.active == 0 && (r.remaining[path] == 0 || len(r.files) > 64) {
		_ = value.file.Close()
		delete(r.files, path)
	}
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
		_ = file.file.Close()
	}
	r.files = make(map[string]*outboundFile)
}

func readPeerFrames(ctx context.Context, conn *peerConn, output chan<- peerRead) {
	for {
		frame, err := conn.read()
		select {
		case output <- peerRead{frame: frame, err: err}:
		case <-ctx.Done():
			return
		}
		if err != nil {
			return
		}
	}
}
