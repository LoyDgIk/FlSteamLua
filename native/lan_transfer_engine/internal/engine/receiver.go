package engine

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
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
	filePaths     map[string]string
	targetPaths   map[string]string
	fileMap       map[string]model.PlanFile
	chunkRefs     map[uint32][]incomingChunkRef
	present       []byte
	presentCount  int
	lastStateSave time.Time
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
	targetLibrary = filepath.Clean(targetLibrary)
	if targetLibrary == "" || luaRoot == "" {
		return nil, fmt.Errorf("target Steam library and Lua root are required")
	}
	value := &incomingTransfer{
		engine: e, session: session, peer: peer, offer: offer,
		targetLibrary: targetLibrary, luaRoot: filepath.Clean(luaRoot),
		files: make(map[string]*os.File), filePaths: make(map[string]string),
		targetPaths: make(map[string]string), fileMap: make(map[string]model.PlanFile),
		chunkRefs: make(map[uint32][]incomingChunkRef),
	}
	e.updateSession(session, func(data *model.Session) {
		data.Status = "preparing"
		data.TargetLibrary = targetLibrary
	})
	return value, nil
}

func (r *incomingTransfer) run(ctx context.Context) error {
	defer r.closeFiles()
	startFrame, err := r.peer.read()
	if err != nil {
		r.engine.markSessionError(r.session, err)
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
	files := make([]model.PlanFile, 0, start.FileCount)
	chunks := make([]model.Chunk, 0, start.ChunkCount)
	for {
		frame, err := r.peer.read()
		if err != nil {
			r.engine.markSessionError(r.session, err)
			return err
		}
		switch frame.Type {
		case protocol.FramePlanFiles:
			batch, err := protocol.DecodePlanFiles(frame.Payload)
			if err != nil {
				return err
			}
			files = append(files, batch...)
		case protocol.FramePlanChunks:
			batch, err := protocol.DecodePlanChunks(frame.Payload)
			if err != nil {
				return err
			}
			chunks = append(chunks, batch...)
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
	return r.receiveData(ctx)
}

func (r *incomingTransfer) validatePlan() error {
	if r.plan.AppID == 0 || len(r.plan.Files) == 0 {
		return fmt.Errorf("invalid transfer plan")
	}
	seenFiles := make(map[string]bool, len(r.plan.Files))
	for _, file := range r.plan.Files {
		if file.ID == "" || seenFiles[file.ID] || file.Size < 0 {
			return fmt.Errorf("invalid transfer file")
		}
		if file.Size > 0 && len(file.Chunks) == 0 {
			return fmt.Errorf("non-empty file has no chunk references")
		}
		seenFiles[file.ID] = true
		for _, ref := range file.Chunks {
			if int(ref.ChunkIndex) >= len(r.plan.Chunks) ||
				ref.Size <= 0 ||
				ref.Offset < 0 ||
				ref.Offset+ref.Size > file.Size {
				return fmt.Errorf("invalid transfer chunk reference")
			}
		}
	}
	for _, chunk := range r.plan.Chunks {
		if chunk.ID == "" || chunk.Size < 0 || chunk.Size > protocol.MaxPayload-4 {
			return fmt.Errorf("invalid transfer chunk")
		}
	}
	return nil
}

func (r *incomingTransfer) prepareStaging() error {
	installDir := filepath.Base(strings.TrimSpace(r.plan.InstallDir))
	if installDir == "." || installDir == ".." || installDir == string(filepath.Separator) {
		return fmt.Errorf("invalid game install directory")
	}
	r.plan.InstallDir = installDir
	r.stagingRoot = filepath.Join(
		r.targetLibrary, "steamapps", ".flsteamlua", "incoming", r.offer.BundleID,
	)
	r.gameRoot = filepath.Join(r.stagingRoot, "game")
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
		r.fileMap[file.ID] = file
		for _, ref := range file.Chunks {
			r.chunkRefs[ref.ChunkIndex] = append(r.chunkRefs[ref.ChunkIndex], incomingChunkRef{
				FileID: file.ID, Offset: ref.Offset, Size: ref.Size,
			})
		}
	}
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
	} else {
		_ = os.WriteFile(idPath, []byte(r.plan.ID), 0o600)
	}
	r.present = bits
	sources, err := r.localChunkSources(ctx)
	if err != nil {
		log.Printf("local chunk index unavailable: %v", err)
	}
	for index, chunk := range r.plan.Chunks {
		if r.has(index) {
			continue
		}
		source, ok := sources[chunk.ID]
		if !ok || source.Size != chunk.Size {
			continue
		}
		r.set(index)
	}
	for _, file := range r.plan.Files {
		target := r.targetPaths[file.ID]
		if info, err := os.Stat(target); err == nil && info.Size() != file.Size {
			for _, ref := range file.Chunks {
				r.present[ref.ChunkIndex/8] &^= 1 << uint(ref.ChunkIndex%8)
			}
		}
	}
	_ = r.saveState()
	r.presentCount = r.countPresent()
	required := int64(0)
	for _, file := range r.plan.Files {
		if r.fileNeedsStaging(file) {
			required += file.Size
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
	builder := plan.Builder{Config: config, Keys: keys}
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

func (r *incomingTransfer) receiveData(ctx context.Context) error {
	for {
		_ = r.peer.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		frame, err := r.peer.read()
		if err != nil {
			r.engine.markSessionError(r.session, err)
			return err
		}
		switch frame.Type {
		case protocol.FrameChunkData:
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
			if chunk.SHA1 != "" {
				sum := sha1.Sum(data)
				if !strings.EqualFold(hex.EncodeToString(sum[:]), chunk.SHA1) {
					_ = r.peer.write(protocol.Frame{Type: protocol.FrameChunkAck, Payload: protocol.EncodeChunkAck(protocol.ChunkAck{
						Index: index, OK: false, Message: "chunk checksum mismatch",
					})})
					continue
				}
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
					data.TransferredBytes += chunk.Size
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
			finish, _ := protocol.DecodeFinish(frame.Payload)
			if !r.complete() {
				_ = r.peer.write(protocol.Frame{Type: protocol.FrameFinishResult, Payload: protocol.EncodeFinish(protocol.Finish{
					Status: "failed", Message: "transfer is incomplete",
				})})
				continue
			}
			if err := r.verifyFiles(); err != nil {
				_ = r.peer.write(protocol.Frame{Type: protocol.FrameFinishResult, Payload: protocol.EncodeFinish(protocol.Finish{
					Status: "failed", Message: err.Error(),
				})})
				return err
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
				data.Status = "committing"
			})
			if err := r.install(); err != nil {
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
		if _, err := handle.WriteAt(data, ref.Offset); err != nil {
			return err
		}
	}
	if len(refs) == 0 && chunk.Size > 0 {
		return fmt.Errorf("chunk has no file references")
	}
	return nil
}

func (r *incomingTransfer) stagedPath(file model.PlanFile) (string, error) {
	relative := strings.ReplaceAll(file.RelativePath, `\`, "/")
	relative = strings.TrimLeft(relative, "/")
	if relative == "" || strings.Contains(relative, "../") || strings.HasPrefix(relative, "..") {
		return "", fmt.Errorf("unsafe transfer path")
	}
	if file.Category == "depotManifest" {
		return filepath.Join(r.stagingRoot, "depotcache", filepath.Base(relative)), nil
	}
	return filepath.Join(r.gameRoot, filepath.FromSlash(relative)), nil
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
	if err := os.MkdirAll(filepath.Dir(staged), 0o755); err != nil {
		return nil, err
	}
	if _, err := os.Stat(staged); os.IsNotExist(err) {
		target := r.targetPaths[file.ID]
		if info, targetErr := os.Stat(target); targetErr == nil && !info.IsDir() {
			if err := copyFile(target, staged); err != nil {
				return nil, err
			}
		} else {
			handle, err := os.OpenFile(staged, os.O_CREATE|os.O_RDWR, 0o644)
			if err != nil {
				return nil, err
			}
			if err := handle.Truncate(file.Size); err != nil {
				_ = handle.Close()
				return nil, err
			}
			r.files[file.ID] = handle
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
	r.files[file.ID] = handle
	return handle, nil
}

func (r *incomingTransfer) fileNeedsStaging(file model.PlanFile) bool {
	for _, ref := range file.Chunks {
		if !r.has(int(ref.ChunkIndex)) {
			return true
		}
	}
	target := r.targetPaths[file.ID]
	if _, err := os.Stat(target); os.IsNotExist(err) {
		return true
	}
	return false
}

func (r *incomingTransfer) has(index int) bool {
	return r.present[index/8]&(1<<uint(index%8)) != 0
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

func (r *incomingTransfer) verifyFiles() error {
	for _, file := range r.plan.Files {
		if file.SHA256 == "" || file.Category == "official" {
			continue
		}
		path := r.filePaths[file.ID]
		if _, err := os.Stat(path); os.IsNotExist(err) {
			path = r.targetPaths[file.ID]
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

func (r *incomingTransfer) bytesForPresent() int64 {
	var total int64
	for index, chunk := range r.plan.Chunks {
		if r.has(index) {
			total += chunk.Size
		}
	}
	return total
}

func (r *incomingTransfer) saveState() error {
	if err := os.WriteFile(filepath.Join(r.stagingRoot, "state.id"), []byte(r.plan.ID), 0o600); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(r.stagingRoot, "state.bits"), r.present, 0o600)
}

func (r *incomingTransfer) closeFiles() {
	for _, handle := range r.files {
		_ = handle.Close()
	}
	r.files = make(map[string]*os.File)
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

func (r *incomingTransfer) install() error {
	r.closeFiles()
	commonTarget := filepath.Join(r.targetLibrary, "steamapps", "common", r.plan.InstallDir)
	for _, file := range r.plan.Files {
		staged := r.filePaths[file.ID]
		target := r.targetPaths[file.ID]
		if _, err := os.Stat(staged); os.IsNotExist(err) {
			if _, targetErr := os.Stat(target); targetErr == nil {
				continue
			}
			if file.Size != 0 {
				return fmt.Errorf("staged file is missing: %s", file.RelativePath)
			}
			if err := os.MkdirAll(filepath.Dir(staged), 0o755); err != nil {
				return err
			}
			handle, err := os.OpenFile(staged, os.O_CREATE|os.O_RDWR, 0o644)
			if err != nil {
				return err
			}
			if err := handle.Truncate(file.Size); err != nil {
				_ = handle.Close()
				return err
			}
			_ = handle.Close()
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return err
		}
		_ = os.Remove(target)
		if err := os.Rename(staged, target); err != nil {
			if err := copyFile(staged, target); err != nil {
				return err
			}
			_ = os.Remove(staged)
		}
	}
	if r.plan.LuaContent != "" {
		luaTarget := filepath.Join(r.luaRoot, fmt.Sprintf("%d.lua", r.plan.AppID))
		if err := os.MkdirAll(filepath.Dir(luaTarget), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(luaTarget, []byte(r.plan.LuaContent), 0o644); err != nil {
			return err
		}
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
	_ = os.RemoveAll(r.stagingRoot)
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

func writeReceiverDebug(value any) {
	data, _ := json.Marshal(value)
	log.Printf("receiver: %s", data)
}
