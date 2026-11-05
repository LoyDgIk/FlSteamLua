package engine

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"

	"flsteamlua/lan_transfer_engine/internal/model"
	"flsteamlua/lan_transfer_engine/internal/plan"
	"flsteamlua/lan_transfer_engine/internal/protocol"
)

type incomingTransfer struct {
	engine        *Engine
	session       *sessionRuntime
	peer          *peerConn
	offer         model.OfferSummary
	targetLibrary string
	luaRoot       string
	plan          *model.Plan
	stagingRoot   string
	gameRoot      string
	files         map[string]*os.File
	fileOrder     []string
	filePaths     map[string]string
	targetPaths   map[string]string
	fileMap       map[string]model.PlanFile
	chunkRefs     map[uint32][]incomingChunkRef
	present       []byte
	presentCount  int
	lastStateSave time.Time
	committed     bool
}

type chunkSource struct {
	Path   string
	Offset int64
	Size   int64
}

type incomingChunkRef struct {
	FileID string
	Offset int64
	Size   int64
}

func (e *Engine) prepareIncoming(
	session *sessionRuntime,
	peer *peerConn,
	offer model.OfferSummary,
	targetLibrary, luaRoot string,
) (*incomingTransfer, error) {
	targetLibrary = strings.TrimSpace(targetLibrary)
	luaRoot = strings.TrimSpace(luaRoot)
	if targetLibrary == "" || luaRoot == "" || !filepath.IsAbs(targetLibrary) || !filepath.IsAbs(luaRoot) {
		return nil, fmt.Errorf("absolute target Steam library and Lua directories are required")
	}
	targetLibrary = filepath.Clean(targetLibrary)
	value := &incomingTransfer{
		engine: e, session: session, peer: peer, offer: offer,
		targetLibrary: targetLibrary, luaRoot: filepath.Clean(luaRoot),
		files: make(map[string]*os.File), filePaths: make(map[string]string),
		targetPaths: make(map[string]string), fileMap: make(map[string]model.PlanFile),
		chunkRefs: make(map[uint32][]incomingChunkRef),
	}
	if session != nil {
		session.mu.Lock()
		session.conn = peer
		session.mu.Unlock()
	}
	e.updateSession(session, func(data *model.Session) {
		data.Status = "preparing"
		data.TargetLibrary = targetLibrary
		data.TotalFiles = offer.FileCount
	})
	return value, nil
}

func (r *incomingTransfer) run(ctx context.Context) error {
	defer func() {
		if !r.committed && r.plan != nil && r.present != nil {
			if err := r.saveState(); err != nil {
				log.Printf("LAN transfer: save incoming state: %v", err)
			}
		}
		r.closeFiles()
	}()
	startFrame, err := r.readFrame(ctx)
	if err != nil {
		if ctx.Err() == nil {
			r.engine.markSessionError(r.session, err)
		}
		return err
	}
	if startFrame.Type != protocol.FramePlanStart {
		return fmt.Errorf("expected plan start")
	}
	start, err := protocol.DecodePlanStart(startFrame.Payload)
	if err != nil {
		return err
	}
	if start.FileCount <= 0 || start.FileCount > 2_000_000 ||
		start.ChunkCount < 0 || start.ChunkCount > 10_000_000 {
		return fmt.Errorf("transfer plan is too large")
	}
	if start.PlanID != r.offer.BundleID || start.BundleID != r.offer.BundleID || start.AppID != r.offer.AppID ||
		start.FileCount != r.offer.FileCount || start.ChunkCount != r.offer.ChunkCount {
		return fmt.Errorf("transfer plan does not match accepted offer")
	}
	files := make([]model.PlanFile, 0, start.FileCount)
	chunks := make([]model.Chunk, 0, start.ChunkCount)
	for {
		frame, err := r.readFrame(ctx)
		if err != nil {
			if ctx.Err() == nil {
				r.engine.markSessionError(r.session, err)
			}
			return err
		}
		switch frame.Type {
		case protocol.FramePlanFiles:
			batch, err := protocol.DecodePlanFiles(frame.Payload)
			if err != nil {
				return err
			}
			files = append(files, batch...)
			if len(files) > start.FileCount {
				return fmt.Errorf("transfer plan exceeds declared file count")
			}
		case protocol.FramePlanChunks:
			batch, err := protocol.DecodePlanChunks(frame.Payload)
			if err != nil {
				return err
			}
			chunks = append(chunks, batch...)
			if len(chunks) > start.ChunkCount {
				return fmt.Errorf("transfer plan exceeds declared chunk count")
			}
		case protocol.FramePlanEnd:
			goto planComplete
		case protocol.FrameCancel:
			return r.cancelled(protocol.DecodeError(frame.Payload))
		default:
			return fmt.Errorf("unexpected plan frame %d", frame.Type)
		}
	}
planComplete:
	if len(files) != start.FileCount || len(chunks) != start.ChunkCount {
		return fmt.Errorf("plan metadata count mismatch")
	}
	r.plan = &model.Plan{
		ID: start.PlanID, AppID: start.AppID, GameName: start.GameName,
		InstallDir: start.InstallDir, CoverURL: start.CoverURL,
		SourceAppManifest: start.SourceAppManifest, LuaContent: start.LuaContent,
		LuaEnabled: start.LuaEnabled, ManifestAvailable: start.ManifestAvailable,
		Warnings: start.Warnings, Files: files, Chunks: chunks, CreatedAt: time.Now().Unix(),
	}
	if err := r.validatePlan(); err != nil {
		return err
	}
	if err := r.prepareStaging(); err != nil {
		r.engine.markSessionError(r.session, err)
		return err
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	presentCount, err := r.buildPresent(ctx)
	if err != nil {
		r.engine.markSessionError(r.session, err)
		return err
	}
	r.presentCount = presentCount
	r.engine.updateSession(r.session, func(data *model.Session) {
		data.Status = "transferring"
		data.TotalChunks = len(r.plan.Chunks)
		data.CompletedChunks = presentCount
		data.CachedChunks = presentCount
		data.TransferredBytes = r.bytesForPresent()
	})
	if err := r.peer.write(protocol.Frame{
		Type: protocol.FramePlanReady,
		Payload: protocol.EncodePlanReady(protocol.PlanReady{
			Window: 16, Bitmap: r.present, PresentChunks: uint64(presentCount),
		}),
	}); err != nil {
		return err
	}
	r.session.mu.Lock()
	r.session.sendProgress = true
	r.session.mu.Unlock()
	r.engine.emitSession(r.session)
	return r.receiveData(ctx)
}

func (r *incomingTransfer) validatePlan() error {
	return plan.Validate(r.plan)
}

func (r *incomingTransfer) prepareStaging() error {
	if err := plan.SafeName(r.offer.BundleID); err != nil {
		return fmt.Errorf("invalid transfer bundle ID")
	}
	r.stagingRoot = filepath.Join(
		r.targetLibrary, "steamapps", ".flsteamlua", "incoming", r.offer.BundleID,
	)
	r.gameRoot = filepath.Join(r.stagingRoot, "game")
	if err := ensureContainedPath(r.targetLibrary, r.gameRoot); err != nil {
		return err
	}
	if err := os.MkdirAll(r.gameRoot, 0o755); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Join(r.stagingRoot, "depotcache"), 0o755); err != nil {
		return err
	}
	for _, file := range r.plan.Files {
		staged, err := r.stagedPath(file)
		if err != nil {
			return err
		}
		r.filePaths[file.ID] = staged
		r.targetPaths[file.ID] = r.installPath(file)
		if err := ensureContainedPath(r.targetLibrary, staged); err != nil {
			return err
		}
		if err := ensureContainedPath(r.targetLibrary, r.targetPaths[file.ID]); err != nil {
			return err
		}
		r.fileMap[file.ID] = file
		for _, ref := range file.Chunks {
			r.chunkRefs[ref.ChunkIndex] = append(r.chunkRefs[ref.ChunkIndex], incomingChunkRef{
				FileID: file.ID, Offset: ref.Offset, Size: ref.Size,
			})
		}
	}
	r.engine.updateSession(r.session, func(data *model.Session) {
		data.TotalFiles = len(r.plan.Files)
	})
	return nil
}

func (r *incomingTransfer) buildPresent(ctx context.Context) (int, error) {
	bits := make([]byte, (len(r.plan.Chunks)+7)/8)
	idPath := filepath.Join(r.stagingRoot, "state.id")
	bitsPath := filepath.Join(r.stagingRoot, "state.bits")
	if stateID, err := os.ReadFile(idPath); err == nil && strings.TrimSpace(string(stateID)) == r.plan.ID {
		if existing, err := os.ReadFile(bitsPath); err == nil && len(existing) == len(bits) {
			copy(bits, existing)
		}
	}
	r.present = bits
	// A persisted bit is only a hint. Re-read the referenced bytes before
	// trusting it; the target or staging file may have changed while paused.
	for index := range r.plan.Chunks {
		if err := ctx.Err(); err != nil {
			return 0, err
		}
		if !r.has(index) {
			continue
		}
		if err := r.verifyPresentChunk(index); err != nil {
			r.clear(index)
		}
	}
	sources, err := r.localChunkSources(ctx)
	if err != nil {
		log.Printf("local chunk index unavailable: %v", err)
	}
	for index, chunk := range r.plan.Chunks {
		if err := ctx.Err(); err != nil {
			return 0, err
		}
		if r.has(index) {
			continue
		}
		source, ok := sources[chunk.ID]
		if !ok || source.Size != chunk.Size {
			continue
		}
		data, err := readChunkSource(source)
		if err != nil || !chunkDigestMatches(chunk, data) {
			continue
		}
		if r.chunkNeedsStaging(index, source) {
			if err := r.writeChunk(index, data); err != nil {
				return 0, err
			}
		}
		r.set(index)
	}
	if err := r.saveState(); err != nil {
		return 0, err
	}
	r.presentCount = r.countPresent()
	required := int64(0)
	for _, file := range r.plan.Files {
		if file.Size == 0 {
			if info, err := os.Stat(r.targetPaths[file.ID]); err != nil || info.Size() != 0 {
				if _, err := r.ensureStagedFile(file); err != nil {
					return 0, err
				}
			}
		}
		if r.fileNeedsStaging(file) {
			allocated := int64(0)
			if info, err := os.Stat(r.filePaths[file.ID]); err == nil {
				allocated = info.Size()
			}
			if file.Size > allocated {
				required += file.Size - allocated
			}
		}
	}
	if free, err := freeDiskBytes(r.targetLibrary); err == nil && free < uint64(required+128*1024*1024) {
		return 0, fmt.Errorf("not enough free space in the selected Steam library")
	}
	return r.presentCount, nil
}

func (r *incomingTransfer) localChunkSources(ctx context.Context) (map[string]chunkSource, error) {
	result := make(map[string]chunkSource)
	common := filepath.Join(r.targetLibrary, "steamapps", "common", r.plan.InstallDir)
	if info, err := os.Stat(common); err != nil || !info.IsDir() {
		return result, nil
	}
	config := r.engine.currentConfig()
	keys, err := plan.LoadDepotKeys(config.KeyCacheRoot)
	if err != nil {
		return result, err
	}
	game := model.GameInput{
		AppID: r.plan.AppID, Name: r.plan.GameName, InstallPath: common,
		LibraryPath: r.targetLibrary,
		LuaPath:     filepath.Join(r.luaRoot, fmt.Sprintf("%d.lua", r.plan.AppID)),
	}
	builder := plan.Builder{Config: config, Keys: keys, AllowMissingOfficial: true, Context: ctx}
	local, err := builder.Build(game)
	if err != nil {
		return result, err
	}
	for _, file := range local.Files {
		for _, ref := range file.Chunks {
			if int(ref.ChunkIndex) >= len(local.Chunks) {
				continue
			}
			id := local.Chunks[ref.ChunkIndex].ID
			info, err := os.Stat(file.SourcePath)
			if err != nil || info.Size() < ref.Offset+ref.Size {
				continue
			}
			result[id] = chunkSource{Path: file.SourcePath, Offset: ref.Offset, Size: ref.Size}
		}
	}
	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	default:
	}
	return result, nil
}

func (r *incomingTransfer) readFrame(ctx context.Context) (protocol.Frame, error) {
	if err := ctx.Err(); err != nil {
		return protocol.Frame{}, err
	}
	_ = r.peer.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	frame, err := r.peer.read()
	if ctx.Err() != nil {
		return protocol.Frame{}, ctx.Err()
	}
	return frame, err
}

func readChunkSource(source chunkSource) ([]byte, error) {
	file, err := os.Open(source.Path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	data := make([]byte, source.Size)
	_, err = file.ReadAt(data, source.Offset)
	return data, err
}

func chunkDigestMatches(chunk model.Chunk, data []byte) bool {
	if int64(len(data)) != chunk.Size || chunk.SHA1 == "" {
		return false
	}
	sum := sha1.Sum(data)
	return strings.EqualFold(hex.EncodeToString(sum[:]), chunk.SHA1)
}

func (r *incomingTransfer) verifyPresentChunk(index int) error {
	chunk := r.plan.Chunks[index]
	for _, ref := range r.chunkRefs[uint32(index)] {
		path := r.filePaths[ref.FileID]
		if _, err := os.Stat(path); os.IsNotExist(err) {
			path = r.targetPaths[ref.FileID]
		}
		if info, err := os.Stat(path); err != nil || info.Size() != r.fileMap[ref.FileID].Size {
			return fmt.Errorf("cached file size mismatch")
		}
		data, err := readChunkSource(chunkSource{Path: path, Offset: ref.Offset, Size: ref.Size})
		if err != nil || !chunkDigestMatches(chunk, data) {
			return fmt.Errorf("cached chunk checksum mismatch")
		}
	}
	return nil
}

func (r *incomingTransfer) chunkNeedsStaging(index int, source chunkSource) bool {
	for _, ref := range r.chunkRefs[uint32(index)] {
		if info, err := os.Stat(r.targetPaths[ref.FileID]); err != nil || info.Size() != r.fileMap[ref.FileID].Size {
			return true
		}
		if _, err := os.Stat(r.filePaths[ref.FileID]); err == nil ||
			!strings.EqualFold(filepath.Clean(source.Path), filepath.Clean(r.targetPaths[ref.FileID])) || source.Offset != ref.Offset {
			return true
		}
	}
	return false
}

func (r *incomingTransfer) receiveData(ctx context.Context) error {
	for {
		frame, err := r.readFrame(ctx)
		if err != nil {
			if ctx.Err() == nil {
				r.engine.markSessionError(r.session, err)
			}
			return err
		}
		switch frame.Type {
		case protocol.FrameChunkData:
			if err := ctx.Err(); err != nil {
				return err
			}
			index, data, err := protocol.DecodeChunkData(frame.Payload)
			if err != nil {
				return err
			}
			if int(index) >= len(r.plan.Chunks) {
				return fmt.Errorf("chunk index out of range")
			}
			chunk := r.plan.Chunks[index]
			if int64(len(data)) != chunk.Size {
				return fmt.Errorf("chunk size mismatch")
			}
			r.engine.updateSession(r.session, func(session *model.Session) {
				session.NetworkBytes += chunk.Size
			})
			if chunk.SHA1 != "" {
				sum := sha1.Sum(data)
				if !strings.EqualFold(hex.EncodeToString(sum[:]), chunk.SHA1) {
					_ = r.peer.write(protocol.Frame{Type: protocol.FrameChunkAck, Payload: protocol.EncodeChunkAck(protocol.ChunkAck{
						Index: index, OK: false, Message: "chunk checksum mismatch",
					})})
					continue
				}
			}
			if err := ctx.Err(); err != nil {
				return err
			}
			if err := r.writeChunk(int(index), data); err != nil {
				_ = r.peer.write(protocol.Frame{Type: protocol.FrameChunkAck, Payload: protocol.EncodeChunkAck(protocol.ChunkAck{
					Index: index, OK: false, Message: err.Error(),
				})})
				continue
			}
			first := !r.has(int(index))
			r.set(int(index))
			if first {
				r.presentCount++
			}
			if time.Since(r.lastStateSave) > time.Second {
				_ = r.saveState()
				r.lastStateSave = time.Now()
			}
			if first {
				r.engine.updateSession(r.session, func(data *model.Session) {
					data.TransferredBytes += r.logicalBytesForChunk(int(index))
					data.CompletedChunks = r.presentCount
					data.Status = "transferring"
				})
			}
			if err := r.peer.write(protocol.Frame{Type: protocol.FrameChunkAck, Payload: protocol.EncodeChunkAck(protocol.ChunkAck{
				Index: index, OK: true,
			})}); err != nil {
				return err
			}
		case protocol.FrameCredit:
			continue
		case protocol.FrameCancel:
			return r.cancelled(protocol.DecodeError(frame.Payload))
		case protocol.FrameFinish:
			if err := ctx.Err(); err != nil {
				return err
			}
			finish, _ := protocol.DecodeFinish(frame.Payload)
			if !r.complete() {
				_ = r.peer.write(protocol.Frame{Type: protocol.FrameFinishResult, Payload: protocol.EncodeFinish(protocol.Finish{
					Status: "failed", Message: "transfer is incomplete",
				})})
				continue
			}
			if !r.engine.currentConfig().SkipSteamRunningCheck && steamRunning() {
				r.engine.updateSession(r.session, func(data *model.Session) {
					data.Status = "waitingForSteamExit"
					data.Message = ""
				})
				_ = r.peer.write(protocol.Frame{Type: protocol.FrameFinishResult, Payload: protocol.EncodeFinish(protocol.Finish{
					Status: "waitingForSteamExit",
				})})
				continue
			}
			r.engine.updateSession(r.session, func(data *model.Session) {
				data.Status = "verifying"
			})
			if err := r.verifyFiles(ctx); err != nil {
				_ = r.peer.write(protocol.Frame{Type: protocol.FrameFinishResult, Payload: protocol.EncodeFinish(protocol.Finish{
					Status: "failed", Message: err.Error(),
				})})
				return err
			}
			r.engine.updateSession(r.session, func(data *model.Session) {
				data.Status = "committing"
			})
			if err := ctx.Err(); err != nil {
				return err
			}
			if err := r.install(ctx); err != nil {
				r.engine.markSessionError(r.session, err)
				_ = r.peer.write(protocol.Frame{Type: protocol.FrameFinishResult, Payload: protocol.EncodeFinish(protocol.Finish{
					Status: "failed", Message: err.Error(),
				})})
				return err
			}
			r.engine.markSessionCompleted(r.session)
			_ = r.peer.write(protocol.Frame{Type: protocol.FrameFinishResult, Payload: protocol.EncodeFinish(protocol.Finish{
				Status: "completed", Message: finish.Message,
			})})
			return nil
		case protocol.FrameError:
			return fmt.Errorf("%s", protocol.DecodeError(frame.Payload))
		default:
			return fmt.Errorf("unexpected transfer frame %d", frame.Type)
		}
	}
}

func (r *incomingTransfer) writeChunk(index int, data []byte) error {
	chunk := r.plan.Chunks[index]
	refs := r.chunkRefs[uint32(index)]
	for _, ref := range refs {
		if int64(len(data)) != ref.Size {
			return fmt.Errorf("chunk reference size mismatch")
		}
		handle := r.files[ref.FileID]
		if handle == nil {
			var err error
			handle, err = r.ensureStagedFile(r.fileMap[ref.FileID])
			if err != nil {
				return err
			}
		}
		written, err := handle.WriteAt(data, ref.Offset)
		if written > 0 {
			r.recordDiskBytes(int64(written))
		}
		if err != nil {
			return err
		}
	}
	if len(refs) == 0 && chunk.Size > 0 {
		return fmt.Errorf("chunk has no file references")
	}
	return nil
}

func (r *incomingTransfer) stagedPath(file model.PlanFile) (string, error) {
	if file.Category == "depotManifest" {
		return filepath.Join(r.stagingRoot, "depotcache", filepath.Base(file.RelativePath)), nil
	}
	return filepath.Join(r.gameRoot, filepath.FromSlash(file.RelativePath)), nil
}

func (r *incomingTransfer) installPath(file model.PlanFile) string {
	if file.Category == "depotManifest" {
		return filepath.Join(r.targetLibrary, "steamapps", "depotcache", filepath.Base(file.RelativePath))
	}
	return filepath.Join(
		r.targetLibrary,
		"steamapps",
		"common",
		r.plan.InstallDir,
		filepath.FromSlash(strings.ReplaceAll(file.RelativePath, `\`, "/")),
	)
}

func (r *incomingTransfer) ensureStagedFile(file model.PlanFile) (*os.File, error) {
	if handle := r.files[file.ID]; handle != nil {
		return handle, nil
	}
	staged := r.filePaths[file.ID]
	if err := ensureContainedPath(r.targetLibrary, staged); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(filepath.Dir(staged), 0o755); err != nil {
		return nil, err
	}
	if _, err := os.Stat(staged); os.IsNotExist(err) {
		target := r.targetPaths[file.ID]
		if err := ensureContainedPath(r.targetLibrary, target); err != nil {
			return nil, err
		}
		if info, targetErr := os.Stat(target); targetErr == nil && !info.IsDir() {
			if err := copyFile(target, staged); err != nil {
				return nil, err
			}
			r.recordDiskBytes(info.Size())
		} else {
			handle, err := os.OpenFile(staged, os.O_CREATE|os.O_RDWR, 0o644)
			if err != nil {
				return nil, err
			}
			if err := handle.Truncate(file.Size); err != nil {
				_ = handle.Close()
				return nil, err
			}
			r.cacheFile(file.ID, handle)
			return handle, nil
		}
	}
	handle, err := os.OpenFile(staged, os.O_RDWR, 0o644)
	if err != nil {
		return nil, err
	}
	if err := handle.Truncate(file.Size); err != nil {
		_ = handle.Close()
		return nil, err
	}
	r.cacheFile(file.ID, handle)
	return handle, nil
}

func (r *incomingTransfer) cacheFile(id string, handle *os.File) {
	const maxOpenFiles = 64
	if len(r.fileOrder) == maxOpenFiles {
		oldest := r.fileOrder[0]
		_ = r.files[oldest].Close()
		delete(r.files, oldest)
		r.fileOrder = r.fileOrder[1:]
	}
	r.files[id] = handle
	r.fileOrder = append(r.fileOrder, id)
}

func (r *incomingTransfer) fileNeedsStaging(file model.PlanFile) bool {
	for _, ref := range file.Chunks {
		if !r.has(int(ref.ChunkIndex)) {
			return true
		}
	}
	target := r.targetPaths[file.ID]
	if info, err := os.Stat(target); err != nil || info.Size() != file.Size {
		return true
	}
	return false
}

func (r *incomingTransfer) has(index int) bool {
	return r.present[index/8]&(1<<uint(index%8)) != 0
}

func (r *incomingTransfer) clear(index int) {
	if index >= 0 && index/8 < len(r.present) {
		r.present[index/8] &^= 1 << uint(index%8)
	}
}

func (r *incomingTransfer) set(index int) {
	r.present[index/8] |= 1 << uint(index%8)
}

func (r *incomingTransfer) countPresent() int {
	count := 0
	for index := range r.plan.Chunks {
		if r.has(index) {
			count++
		}
	}
	return count
}

func (r *incomingTransfer) complete() bool {
	for _, file := range r.plan.Files {
		for _, ref := range file.Chunks {
			if !r.has(int(ref.ChunkIndex)) {
				return false
			}
		}
	}
	return true
}

func (r *incomingTransfer) verifyFiles(ctx context.Context) error {
	for _, file := range r.plan.Files {
		if err := ctx.Err(); err != nil {
			return err
		}
		path := r.filePaths[file.ID]
		staged := true
		if _, err := os.Stat(path); os.IsNotExist(err) {
			path = r.targetPaths[file.ID]
			staged = false
		}
		if info, err := os.Stat(path); err != nil || info.Size() != file.Size {
			return fmt.Errorf("file size mismatch: %s", file.RelativePath)
		}
		if file.SHA256 == "" {
			if !staged {
				if err := r.verifyUnchangedFile(ctx, path, file); err != nil {
					return err
				}
			}
			continue
		}
		_, sha256Text, err := plan.HashFile(path)
		if err != nil {
			return err
		}
		if !strings.EqualFold(sha256Text, file.SHA256) {
			return fmt.Errorf("file checksum mismatch: %s", file.RelativePath)
		}
	}
	return nil
}

func (r *incomingTransfer) verifyUnchangedFile(ctx context.Context, path string, file model.PlanFile) error {
	input, err := os.Open(path)
	if err != nil {
		return err
	}
	defer input.Close()
	if file.SHA1 != "" {
		hash := sha1.New()
		buffer := make([]byte, 1024*1024)
		for {
			if err := ctx.Err(); err != nil {
				return err
			}
			n, readErr := input.Read(buffer)
			_, _ = hash.Write(buffer[:n])
			if readErr == io.EOF {
				break
			}
			if readErr != nil {
				return readErr
			}
		}
		if !strings.EqualFold(hex.EncodeToString(hash.Sum(nil)), file.SHA1) {
			return fmt.Errorf("reused file changed before installation: %s", file.RelativePath)
		}
		return nil
	}
	for _, ref := range file.Chunks {
		if err := ctx.Err(); err != nil {
			return err
		}
		data := make([]byte, ref.Size)
		if _, err := input.ReadAt(data, ref.Offset); err != nil {
			return err
		}
		if !chunkDigestMatches(r.plan.Chunks[ref.ChunkIndex], data) {
			return fmt.Errorf("reused file changed before installation: %s", file.RelativePath)
		}
	}
	return nil
}

func (r *incomingTransfer) bytesForPresent() int64 {
	var total int64
	for _, file := range r.plan.Files {
		for _, ref := range file.Chunks {
			if r.has(int(ref.ChunkIndex)) {
				total += ref.Size
			}
		}
	}
	return total
}

func (r *incomingTransfer) logicalBytesForChunk(index int) int64 {
	var total int64
	for _, ref := range r.chunkRefs[uint32(index)] {
		total += ref.Size
	}
	return total
}

func (r *incomingTransfer) recordDiskBytes(bytes int64) {
	r.engine.updateSession(r.session, func(data *model.Session) {
		data.DiskBytes += bytes
	})
}

func (r *incomingTransfer) recordInstalledFile(file model.PlanFile) {
	r.engine.updateSession(r.session, func(data *model.Session) {
		data.InstalledBytes += file.Size
		data.InstalledFiles++
	})
}

func (r *incomingTransfer) saveState() error {
	idPath := filepath.Join(r.stagingRoot, "state.id")
	bitsPath := filepath.Join(r.stagingRoot, "state.bits")
	if err := ensureContainedPath(r.targetLibrary, idPath); err != nil {
		return err
	}
	if err := ensureContainedPath(r.targetLibrary, bitsPath); err != nil {
		return err
	}
	if err := os.WriteFile(idPath, []byte(r.plan.ID), 0o600); err != nil {
		return err
	}
	return os.WriteFile(bitsPath, r.present, 0o600)
}

func (r *incomingTransfer) closeFiles() {
	for _, handle := range r.files {
		_ = handle.Close()
	}
	r.files = make(map[string]*os.File)
	r.fileOrder = nil
}

func (r *incomingTransfer) cancelled(message string) error {
	r.closeFiles()
	status := "cancelled"
	if strings.EqualFold(message, "paused") {
		status = "paused"
	}
	r.engine.updateSession(r.session, func(data *model.Session) { data.Status = status })
	_ = r.peer.write(protocol.Frame{Type: protocol.FrameFinishResult, Payload: protocol.EncodeFinish(protocol.Finish{
		Status: status, Message: message,
	})})
	return nil
}

func (r *incomingTransfer) install(ctx context.Context) error {
	r.closeFiles()
	if err := ctx.Err(); err != nil {
		return err
	}
	commonTarget := filepath.Join(r.targetLibrary, "steamapps", "common", r.plan.InstallDir)
	if err := ensureContainedPath(r.targetLibrary, commonTarget); err != nil {
		return err
	}
	if info, err := os.Stat(commonTarget); os.IsNotExist(err) {
		// A new game is entirely contained in the verified same-volume staging
		// directory. Publish it with one rename instead of thousands of file moves.
		var manifests []model.PlanFile
		for _, file := range r.plan.Files {
			if file.Category == "depotManifest" {
				manifests = append(manifests, file)
			}
		}
		if err := r.installFiles(ctx, manifests); err != nil {
			return err
		}
		if err := ensureContainedPath(r.targetLibrary, r.gameRoot); err != nil {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(commonTarget), 0o755); err != nil {
			return err
		}
		if err := ctx.Err(); err != nil {
			return err
		}
		if err := os.Rename(r.gameRoot, commonTarget); err != nil {
			return err
		}
		var installedBytes int64
		installedFiles := 0
		for _, file := range r.plan.Files {
			if file.Category != "depotManifest" {
				installedBytes += file.Size
				installedFiles++
			}
		}
		r.engine.updateSession(r.session, func(data *model.Session) {
			data.InstalledBytes += installedBytes
			data.InstalledFiles += installedFiles
		})
	} else if err != nil {
		return err
	} else {
		if !info.IsDir() {
			return fmt.Errorf("game installation target is not a directory")
		}
		if err := r.installFiles(ctx, r.plan.Files); err != nil {
			return err
		}
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	if r.plan.LuaContent != "" {
		luaTarget := filepath.Join(r.luaRoot, fmt.Sprintf("%d.lua", r.plan.AppID))
		luaOther := filepath.Join(r.luaRoot, "Disable", fmt.Sprintf("%d.lua", r.plan.AppID))
		if !r.plan.LuaEnabled {
			luaTarget, luaOther = luaOther, luaTarget
		}
		if err := ensureContainedPath(r.luaRoot, luaTarget); err != nil {
			return err
		}
		if err := ensureContainedPath(r.luaRoot, luaOther); err != nil {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(luaTarget), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(luaTarget, []byte(r.plan.LuaContent), 0o644); err != nil {
			return err
		}
		if err := os.Remove(luaOther); err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	acf := sanitizedManifest(r.plan, commonTarget)
	acfTarget := filepath.Join(r.targetLibrary, "steamapps", fmt.Sprintf("appmanifest_%d.acf", r.plan.AppID))
	temp := acfTarget + ".tmp"
	if err := os.WriteFile(temp, []byte(acf), 0o644); err != nil {
		return err
	}
	if err := os.Rename(temp, acfTarget); err != nil {
		return err
	}
	r.committed = true
	if err := ensureContainedPath(r.targetLibrary, r.stagingRoot); err != nil {
		return err
	}
	_ = os.RemoveAll(r.stagingRoot)
	return nil
}

func (r *incomingTransfer) installFiles(ctx context.Context, files []model.PlanFile) error {
	workCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	jobs := make(chan model.PlanFile)
	failed := make(chan error, 1)
	var workers sync.WaitGroup
	for range min(4, len(files)) {
		workers.Add(1)
		go func() {
			defer workers.Done()
			for file := range jobs {
				if err := workCtx.Err(); err != nil {
					return
				}
				if err := r.installFile(workCtx, file); err != nil {
					select {
					case failed <- err:
					default:
					}
					cancel()
					return
				}
			}
		}()
	}
dispatch:
	for _, file := range files {
		select {
		case jobs <- file:
		case <-workCtx.Done():
			break dispatch
		}
	}
	close(jobs)
	workers.Wait()
	select {
	case err := <-failed:
		return err
	default:
		return ctx.Err()
	}
}

func (r *incomingTransfer) installFile(ctx context.Context, file model.PlanFile) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	staged := r.filePaths[file.ID]
	target := r.targetPaths[file.ID]
	if err := ensureContainedPath(r.targetLibrary, staged); err != nil {
		return err
	}
	if err := ensureContainedPath(r.targetLibrary, target); err != nil {
		return err
	}
	if _, err := os.Stat(staged); os.IsNotExist(err) {
		if _, targetErr := os.Stat(target); targetErr == nil {
			r.recordInstalledFile(file)
			return nil
		}
		return fmt.Errorf("staged file is missing: %s", file.RelativePath)
	} else if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return err
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	_ = os.Remove(target)
	if err := os.Rename(staged, target); err != nil {
		if err := copyFile(staged, target); err != nil {
			return err
		}
		r.recordDiskBytes(file.Size)
		_ = os.Remove(staged)
	}
	r.recordInstalledFile(file)
	return nil
}

// ensureContainedPath resolves existing parent links at the filesystem boundary.
// It accepts a user-selected root, while refusing child junctions or symlinks
// that redirect writes and cleanup outside that root.
func ensureContainedPath(root, target string) error {
	root, err := filepath.Abs(root)
	if err != nil {
		return err
	}
	target, err = filepath.Abs(target)
	if err != nil {
		return err
	}
	relative, err := filepath.Rel(root, target)
	if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
		return fmt.Errorf("transfer path escapes selected directory")
	}
	current := root
	for _, component := range strings.Split(relative, string(filepath.Separator)) {
		if component == "." {
			continue
		}
		current = filepath.Join(current, component)
		info, err := os.Lstat(current)
		if os.IsNotExist(err) {
			return nil
		}
		if err != nil {
			return err
		}
		attributes := info.Sys().(*syscall.Win32FileAttributeData).FileAttributes
		if attributes&syscall.FILE_ATTRIBUTE_REPARSE_POINT != 0 {
			return fmt.Errorf("linked transfer content is not supported")
		}
	}
	return nil
}

func sanitizedManifest(value *model.Plan, targetGame string) string {
	var state plan.VDF
	if root, err := plan.ParseVDF(value.SourceAppManifest); err == nil {
		state = plan.MapValue(root, "AppState")
	}
	if state == nil {
		state = plan.VDF{}
	}
	for _, key := range []string{
		"lastowner", "lastplayed", "lastupdated", "sharedconfig",
		"bytestodownload", "bytesdownloaded", "bytestostage", "bytesstaged",
		"stagingsize", "updateresult", "updateerror", "scheduledautoupdate",
		"autoupdatebehavior", "allowotherdownloadswhilerunning",
	} {
		delete(state, key)
	}
	state["appid"] = fmt.Sprint(value.AppID)
	state["name"] = value.GameName
	state["installdir"] = filepath.Base(targetGame)
	state["stateflags"] = "4"
	state["sizeondisk"] = fmt.Sprint(selectedBytes(value))
	state["stagingsize"] = "0"
	state["bytestodownload"] = "0"
	state["bytesdownloaded"] = "0"
	state["updateresult"] = "0"
	if _, ok := state["installeddepots"]; !ok {
		state["installeddepots"] = map[string]any{}
	}
	return plan.StringifyVDF(plan.VDF{"appstate": map[string]any(state)})
}

func steamRunning() bool {
	output, err := exec.Command("tasklist.exe", "/FI", "IMAGENAME eq steam.exe", "/FO", "CSV", "/NH").Output()
	return err == nil && strings.Contains(strings.ToLower(string(output)), "steam.exe")
}

func copyFile(source, target string) error {
	input, err := os.Open(source)
	if err != nil {
		return err
	}
	defer input.Close()
	output, err := os.Create(target)
	if err != nil {
		return err
	}
	if _, err := io.Copy(output, input); err != nil {
		_ = output.Close()
		return err
	}
	return output.Close()
}
