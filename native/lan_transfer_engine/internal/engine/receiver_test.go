package engine

import (
	"bytes"
	"context"
	"crypto/sha1"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"testing"

	"flsteamlua/lan_transfer_engine/internal/model"
	"flsteamlua/lan_transfer_engine/internal/plan"
	"flsteamlua/lan_transfer_engine/internal/protocol"
)

type receiverFixture struct {
	root, steam, library, luaRoot, gameDir string
	engine                                 *Engine
	local                                  *model.Plan
}

type fixtureChunk struct {
	data   string
	offset uint64
}

func writeFixtureManifest(t *testing.T, target, expected string, parts []fixtureChunk) {
	t.Helper()
	sum := sha1.Sum([]byte(expected))
	var file protocol.PB
	file.String(1, "payload.bin")
	file.Uint(2, uint64(len(expected)))
	file.Bytes(5, sum[:])
	for _, part := range parts {
		partSum := sha1.Sum([]byte(part.data))
		var chunk protocol.PB
		chunk.Bytes(1, partSum[:])
		chunk.Uint(3, part.offset)
		chunk.Uint(4, uint64(len(part.data)))
		file.Message(6, chunk.Result())
	}
	var payload, metadata protocol.PB
	payload.Message(1, file.Result())
	metadata.Uint(1, 991)
	metadata.Uint(2, 123)
	var output []byte
	for _, section := range []struct {
		magic uint32
		data  []byte
	}{{0x71f617d0, payload.Result()}, {0x1f4812be, metadata.Result()}, {0x1b81b817, []byte{1}}} {
		output = binary.LittleEndian.AppendUint32(output, section.magic)
		output = binary.LittleEndian.AppendUint32(output, uint32(len(section.data)))
		output = append(output, section.data...)
	}
	output = binary.LittleEndian.AppendUint32(output, 0x32c415ab)
	if err := os.WriteFile(target, output, 0o600); err != nil {
		t.Fatal(err)
	}
}

func newReceiverFixture(t *testing.T, actual, expected string, parts []fixtureChunk, official bool) receiverFixture {
	t.Helper()
	root := t.TempDir()
	f := receiverFixture{root: root, steam: filepath.Join(root, "steam"), library: filepath.Join(root, "library")}
	f.luaRoot = filepath.Join(f.steam, "config", "stplug-in")
	f.gameDir = filepath.Join(f.library, "steamapps", "common", "Fixture")
	for _, dir := range []string{f.luaRoot, f.gameDir, filepath.Join(f.steam, "depotcache")} {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(f.gameDir, "payload.bin"), []byte(actual), 0o600); err != nil {
		t.Fatal(err)
	}
	depots := map[string]any{}
	if official {
		depots["991"] = map[string]any{"manifest": "123"}
		writeFixtureManifest(t, filepath.Join(f.steam, "depotcache", "991_123.manifest"), expected, parts)
	}
	acf := plan.StringifyVDF(plan.VDF{"appstate": map[string]any{
		"appid": "991", "name": "Fixture", "installdir": "Fixture", "installeddepots": depots,
	}})
	if err := os.WriteFile(filepath.Join(f.library, "steamapps", "appmanifest_991.acf"), []byte(acf), 0o600); err != nil {
		t.Fatal(err)
	}
	e, err := New(filepath.Join(root, "engine"))
	if err != nil {
		t.Fatal(err)
	}
	f.engine = e
	t.Cleanup(func() { e.Close() })
	e.config = model.Config{SteamPath: f.steam, LuaRoot: f.luaRoot, LibraryRoots: []string{f.library}, SkipSteamRunningCheck: true}
	builder := plan.Builder{Config: e.config}
	f.local, err = builder.Build(model.GameInput{AppID: 991, Name: "Fixture", InstallPath: f.gameDir, LibraryPath: f.library})
	if err != nil {
		t.Fatal(err)
	}
	return f
}

func prepareReceiverFixture(t *testing.T, f receiverFixture, value *model.Plan) *incomingTransfer {
	t.Helper()
	r, err := f.engine.prepareIncoming(&sessionRuntime{data: model.Session{ID: "fixture"}}, nil,
		model.OfferSummary{BundleID: value.ID}, f.library, f.luaRoot)
	if err != nil {
		t.Fatal(err)
	}
	r.plan = value
	if err := r.validatePlan(); err != nil {
		t.Fatal(err)
	}
	if err := r.prepareStaging(); err != nil {
		t.Fatal(err)
	}
	if _, err := r.buildPresent(context.Background()); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(r.closeFiles)
	return r
}

func TestReceiverRejectsCorruptExistingChunk(t *testing.T) {
	f := newReceiverFixture(t, "BAD!!", "hello", []fixtureChunk{{"hello", 0}}, true)
	value := plan.Filter(f.local, nil)
	r := prepareReceiverFixture(t, f, value)
	if r.has(0) {
		t.Fatal("same-size corrupted official chunk was reused")
	}
}

func TestReceiverKeepsVerifiedUnchangedFileInPlace(t *testing.T) {
	f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
	r := prepareReceiverFixture(t, f, plan.Filter(f.local, nil))
	if !r.has(0) {
		t.Fatal("verified existing chunk was not reused")
	}
	if _, err := os.Stat(r.filePaths[r.plan.Files[0].ID]); !os.IsNotExist(err) {
		t.Fatal("unchanged official file was unnecessarily staged")
	}
	if err := r.install(context.Background()); err != nil {
		t.Fatal(err)
	}
	counts := receiverCounters(r)
	if counts.NetworkBytes != 0 || counts.DiskBytes != r.plan.Files[1].Size ||
		counts.InstalledBytes != selectedBytes(r.plan) || counts.InstalledFiles != len(r.plan.Files) || counts.TotalFiles != len(r.plan.Files) {
		t.Fatalf("reused game bytes were reported as network/disk writes: %+v", counts)
	}
}

func TestReceiverExtraSameSizeDifferentContent(t *testing.T) {
	f := newReceiverFixture(t, "LOCAL", "", nil, false)
	remoteDir := filepath.Join(f.root, "remote", "Fixture")
	if err := os.MkdirAll(remoteDir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(remoteDir, "payload.bin"), []byte("OTHER"), 0o600); err != nil {
		t.Fatal(err)
	}
	builder := plan.Builder{Config: f.engine.config}
	remote, err := builder.Build(model.GameInput{AppID: 991, Name: "Fixture", InstallPath: remoteDir, LibraryPath: filepath.Join(f.root, "remote")})
	if err != nil {
		t.Fatal(err)
	}
	r := prepareReceiverFixture(t, f, plan.Filter(remote, map[string]bool{remote.Files[0].ID: true}))
	if r.has(0) {
		t.Fatal("different extra bytes were marked cached")
	}
}

func TestReceiverRelocatesVerifiedChunk(t *testing.T) {
	f := newReceiverFixture(t, "aaaabbbb", "aaaabbbb", []fixtureChunk{{"aaaa", 0}, {"bbbb", 4}}, true)
	value := plan.Filter(f.local, nil)
	value.ID = "moved-plan"
	value.Files[0].Chunks[0].Offset = 4
	value.Files[0].Chunks[1].Offset = 0
	value.Files[0].Chunks[0], value.Files[0].Chunks[1] = value.Files[0].Chunks[1], value.Files[0].Chunks[0]
	sum := sha1.Sum([]byte("bbbbaaaa"))
	value.Files[0].SHA1 = hex.EncodeToString(sum[:])
	r := prepareReceiverFixture(t, f, value)
	if !r.complete() {
		t.Fatal("matching moved chunks were not reused")
	}
	if err := r.verifyFiles(context.Background()); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(r.filePaths[value.Files[0].ID])
	if err != nil || !bytes.Equal(got, []byte("bbbbaaaa")) {
		t.Fatalf("cached chunks were not moved to their new offsets: %q, %v", got, err)
	}
}

func TestReceiverMaterializesGlobalManifestCache(t *testing.T) {
	f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
	r := prepareReceiverFixture(t, f, plan.Filter(f.local, nil))
	if !r.complete() {
		t.Fatal("available manifest and official chunk were not reused")
	}
	if err := r.verifyFiles(context.Background()); err != nil {
		t.Fatalf("global manifest was not materialized: %v", err)
	}
}

func TestReceiverRechecksResumeBitmap(t *testing.T) {
	f := newReceiverFixture(t, "BAD!!", "hello", []fixtureChunk{{"hello", 0}}, true)
	r := prepareReceiverFixture(t, f, plan.Filter(f.local, nil))
	if err := os.MkdirAll(filepath.Dir(r.filePaths[r.plan.Files[0].ID]), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(r.filePaths[r.plan.Files[0].ID], []byte("WRONG"), 0o600); err != nil {
		t.Fatal(err)
	}
	r.set(0)
	if err := r.saveState(); err != nil {
		t.Fatal(err)
	}
	r.closeFiles()
	if _, err := r.buildPresent(context.Background()); err != nil {
		t.Fatal(err)
	}
	if r.has(0) {
		t.Fatal("resume state bypassed verification of damaged staging bytes")
	}
}

func TestReceiverRejectsBundlePathTraversal(t *testing.T) {
	f := newReceiverFixture(t, "LOCAL", "", nil, false)
	value := plan.Filter(f.local, map[string]bool{f.local.Files[0].ID: true})
	r, err := f.engine.prepareIncoming(&sessionRuntime{}, nil, model.OfferSummary{BundleID: "../../../../escaped"}, f.library, f.luaRoot)
	if err == nil {
		r.plan = value
		err = r.prepareStaging()
	}
	if err == nil {
		t.Fatal("accepted a bundle path outside the selected library")
	}
}

func TestReceiverRelocatesChunkToAnotherFile(t *testing.T) {
	f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
	value := plan.Filter(f.local, nil)
	value.ID = "renamed-plan"
	value.Files[0].RelativePath = "renamed.bin"
	r := prepareReceiverFixture(t, f, value)
	if !r.complete() {
		t.Fatal("valid existing chunk was not reused for renamed file")
	}
	if err := r.install(context.Background()); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(filepath.Join(f.gameDir, "renamed.bin"))
	if err != nil || !bytes.Equal(got, []byte("hello")) {
		t.Fatalf("renamed chunk was not materialized: %q, %v", got, err)
	}
}

func TestReceiverTruncatesOversizedExistingFile(t *testing.T) {
	f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
	if err := os.WriteFile(filepath.Join(f.gameDir, "payload.bin"), []byte("hello-extra"), 0o600); err != nil {
		t.Fatal(err)
	}
	value := &model.Plan{ID: "shortened-plan", AppID: 991, InstallDir: "Fixture", Files: []model.PlanFile{{
		ID: "payload", RelativePath: "payload.bin", Size: 5, Category: "official", Selected: true,
		Chunks: []model.FileChunkRef{{ChunkIndex: 0, Offset: 0, Size: 5}},
	}}, Chunks: []model.Chunk{f.local.Chunks[0]}}
	r := prepareReceiverFixture(t, f, value)
	if !r.complete() {
		t.Fatal("valid prefix chunk was not reused")
	}
	if err := r.verifyFiles(context.Background()); err != nil {
		t.Fatal(err)
	}
	if err := r.install(context.Background()); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(filepath.Join(f.gameDir, "payload.bin"))
	if err != nil || string(got) != "hello" {
		t.Fatalf("oversized target was not truncated: %q, %v", got, err)
	}
}

func TestReceiverPreservesLuaEnabledState(t *testing.T) {
	for _, enabled := range []bool{false, true} {
		t.Run(map[bool]string{false: "disabled", true: "enabled"}[enabled], func(t *testing.T) {
			f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
			value := plan.Filter(f.local, nil)
			value.LuaContent = "addappid(991)"
			value.LuaEnabled = enabled
			active := filepath.Join(f.luaRoot, "991.lua")
			disabled := filepath.Join(f.luaRoot, "Disable", "991.lua")
			if err := os.MkdirAll(filepath.Dir(disabled), 0o700); err != nil {
				t.Fatal(err)
			}
			for _, target := range []string{active, disabled} {
				if err := os.WriteFile(target, []byte("old"), 0o600); err != nil {
					t.Fatal(err)
				}
			}
			r := prepareReceiverFixture(t, f, value)
			if err := r.install(context.Background()); err != nil {
				t.Fatal(err)
			}
			target, other := active, disabled
			if !enabled {
				target, other = other, target
			}
			if data, err := os.ReadFile(target); err != nil || string(data) != value.LuaContent {
				t.Fatalf("Lua state was not preserved: %q, %v", data, err)
			}
			if _, err := os.Stat(other); !os.IsNotExist(err) {
				t.Fatal("opposite Lua state remains")
			}
		})
	}
}

func TestReceiverDoesNotInstallAfterCancellation(t *testing.T) {
	f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
	value := plan.Filter(f.local, nil)
	value.LuaContent = "addappid(991)"
	value.LuaEnabled = true
	r := prepareReceiverFixture(t, f, value)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := r.install(ctx); err != context.Canceled {
		t.Fatalf("cancelled transfer started installation: %v", err)
	}
	if _, err := os.Stat(filepath.Join(f.luaRoot, "991.lua")); !os.IsNotExist(err) {
		t.Fatal("Lua was written after cancellation")
	}
}

func TestReceiverRejectsJunctionOutsideSelectedLibrary(t *testing.T) {
	f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
	outside := filepath.Join(f.root, "outside")
	if err := os.MkdirAll(outside, 0o700); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(f.gameDir, "linked")
	if output, err := exec.Command("cmd.exe", "/c", "mklink", "/J", link, outside).CombinedOutput(); err != nil {
		t.Fatalf("create fixture junction: %v: %s", err, output)
	}
	value := plan.Filter(f.local, nil)
	value.Files[0].RelativePath = "linked/payload.bin"
	r, err := f.engine.prepareIncoming(&sessionRuntime{}, nil, model.OfferSummary{BundleID: value.ID}, f.library, f.luaRoot)
	if err != nil {
		t.Fatal(err)
	}
	r.plan = value
	if err := r.prepareStaging(); err == nil {
		t.Fatal("junction redirected the transfer outside the selected library")
	}
}

func TestReceiverBoundsOpenStagingFiles(t *testing.T) {
	f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
	value := plan.Filter(f.local, nil)
	r := prepareReceiverFixture(t, f, value)
	for index := 0; index < 80; index++ {
		file := model.PlanFile{ID: fmt.Sprintf("small-%d", index), Size: 1}
		r.filePaths[file.ID] = filepath.Join(r.gameRoot, file.ID)
		r.targetPaths[file.ID] = filepath.Join(f.gameDir, file.ID)
		if _, err := r.ensureStagedFile(file); err != nil {
			t.Fatal(err)
		}
	}
	if len(r.files) > 64 {
		t.Fatalf("staging handles are unbounded: %d", len(r.files))
	}
}

func TestReceiverRejectsFileChangedAfterReuse(t *testing.T) {
	f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
	r := prepareReceiverFixture(t, f, plan.Filter(f.local, nil))
	if !r.complete() {
		t.Fatal("fixture should initially reuse all files")
	}
	if err := os.WriteFile(filepath.Join(f.gameDir, "payload.bin"), []byte("WRONG"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := r.verifyFiles(context.Background()); err == nil {
		t.Fatal("existing file changed during the Steam-exit wait but was accepted")
	}
}

func TestReceiverCreatesEmptyFile(t *testing.T) {
	for _, existing := range []bool{false, true} {
		t.Run(map[bool]string{false: "new", true: "truncate"}[existing], func(t *testing.T) {
			f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
			relative := "empty.bin"
			if existing {
				if err := os.WriteFile(filepath.Join(f.gameDir, relative), []byte("old-content"), 0o600); err != nil {
					t.Fatal(err)
				}
			}
			value := &model.Plan{ID: "empty-plan", AppID: 991, InstallDir: "Fixture", Files: []model.PlanFile{{
				ID: "empty", RelativePath: relative, Category: "official", Selected: true,
			}}}
			r := prepareReceiverFixture(t, f, value)
			if err := r.verifyFiles(context.Background()); err != nil {
				t.Fatalf("empty file was not prepared before verification: %v", err)
			}
			if err := r.install(context.Background()); err != nil {
				t.Fatal(err)
			}
			info, err := os.Stat(filepath.Join(f.gameDir, relative))
			if err != nil || info.Size() != 0 {
				t.Fatalf("empty file was not installed: %v, %v", info, err)
			}
		})
	}
}

func TestPrepareIncomingRequiresAbsoluteDirectories(t *testing.T) {
	f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
	for _, invalid := range []string{"", "   ", ".", "relative", `D:relative`, `\relative`} {
		t.Run(invalid, func(t *testing.T) {
			if _, err := f.engine.prepareIncoming(&sessionRuntime{}, nil, model.OfferSummary{}, invalid, f.luaRoot); err == nil {
				t.Fatalf("accepted invalid Steam library %q", invalid)
			}
			if _, err := f.engine.prepareIncoming(&sessionRuntime{}, nil, model.OfferSummary{}, f.library, invalid); err == nil {
				t.Fatalf("accepted invalid Lua directory %q", invalid)
			}
		})
	}
}

func TestReceiverInstallBatchCompletesAllFiles(t *testing.T) {
	f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
	value := &model.Plan{ID: "many-empty-plan", AppID: 991, InstallDir: "Fixture"}
	for index := 0; index < 32; index++ {
		value.Files = append(value.Files, model.PlanFile{
			ID: fmt.Sprintf("empty-%d", index), RelativePath: fmt.Sprintf("sub/empty-%d.bin", index), Category: "official", Selected: true,
		})
	}
	r := prepareReceiverFixture(t, f, value)
	if err := r.install(context.Background()); err != nil {
		t.Fatal(err)
	}
	for _, file := range value.Files {
		if info, err := os.Stat(r.targetPaths[file.ID]); err != nil || info.Size() != 0 {
			t.Fatalf("file not committed before install returned: %s, %v", file.RelativePath, err)
		}
	}
}

func TestReceiverInstallFailureKeepsMetadataUnpublished(t *testing.T) {
	f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
	value := plan.Filter(f.local, nil)
	value.LuaContent = "addappid(991)"
	value.LuaEnabled = true
	r := prepareReceiverFixture(t, f, value)
	r.closeFiles()
	acfPath := filepath.Join(f.library, "steamapps", "appmanifest_991.acf")
	before, err := os.ReadFile(acfPath)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(r.filePaths[value.Files[1].ID]); err != nil {
		t.Fatal(err)
	}
	if err := r.install(context.Background()); err == nil {
		t.Fatal("missing staged file was accepted")
	}
	after, err := os.ReadFile(acfPath)
	if err != nil || !bytes.Equal(before, after) {
		t.Fatal("ACF was changed despite a failed file commit")
	}
	if _, err := os.Stat(filepath.Join(f.luaRoot, "991.lua")); !os.IsNotExist(err) {
		t.Fatal("Lua was published despite a failed file commit")
	}
	if _, err := os.Stat(r.stagingRoot); err != nil {
		t.Fatal("staging was deleted after a failed file commit")
	}
}

func prepareNewInstallFixture(t *testing.T) (receiverFixture, *incomingTransfer) {
	t.Helper()
	f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
	value := plan.Filter(f.local, nil)
	value.InstallDir = "FreshFixture"
	r := prepareReceiverFixture(t, f, value)
	for index, source := range outboundSources(value) {
		data, err := readChunkSource(chunkSource{Path: source.Path, Offset: source.Offset, Size: source.Size})
		if err != nil {
			t.Fatal(err)
		}
		if err := r.writeChunk(int(index), data); err != nil {
			t.Fatal(err)
		}
		r.set(int(index))
	}
	if err := r.verifyFiles(context.Background()); err != nil {
		t.Fatal(err)
	}
	return f, r
}

func TestReceiverNewInstallRenamesGameDirectory(t *testing.T) {
	f, r := prepareNewInstallFixture(t)
	before := fixtureDirectoryID(t, r.gameRoot)
	if err := r.install(context.Background()); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(f.library, "steamapps", "common", "FreshFixture")
	after := fixtureDirectoryID(t, target)
	if before != after {
		t.Fatal("new install copied individual files instead of renaming the staged directory")
	}
	if content, err := os.ReadFile(filepath.Join(target, "payload.bin")); err != nil || string(content) != "hello" {
		t.Fatalf("bulk-installed game mismatch: %q, %v", content, err)
	}
	manifest := filepath.Join(f.library, "steamapps", "depotcache", "991_123.manifest")
	if _, err := os.Stat(manifest); err != nil {
		t.Fatalf("depot manifest was not installed separately: %v", err)
	}
	counts := receiverCounters(r)
	if counts.NetworkBytes != 0 || counts.DiskBytes != selectedBytes(r.plan) ||
		counts.InstalledBytes != selectedBytes(r.plan) || counts.InstalledFiles != len(r.plan.Files) || counts.TotalFiles != len(r.plan.Files) {
		t.Fatalf("bulk-install counters do not reflect actual writes and committed files: %+v", counts)
	}
}

func TestReceiverExistingInstallPreservesOtherFiles(t *testing.T) {
	f := newReceiverFixture(t, "hello", "hello", []fixtureChunk{{"hello", 0}}, true)
	r := prepareReceiverFixture(t, f, plan.Filter(f.local, nil))
	before := fixtureDirectoryID(t, f.gameDir)
	modPath := filepath.Join(f.gameDir, "local-mod.bin")
	if err := os.WriteFile(modPath, []byte("keep-mod"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := r.install(context.Background()); err != nil {
		t.Fatal(err)
	}
	after := fixtureDirectoryID(t, f.gameDir)
	if before != after {
		t.Fatal("existing installation directory was replaced")
	}
	if content, err := os.ReadFile(modPath); err != nil || string(content) != "keep-mod" {
		t.Fatalf("unplanned mod was changed: %q, %v", content, err)
	}
}

func fixtureDirectoryID(t *testing.T, path string) [3]uint32 {
	t.Helper()
	name, err := syscall.UTF16PtrFromString(path)
	if err != nil {
		t.Fatal(err)
	}
	handle, err := syscall.CreateFile(name, 0, syscall.FILE_SHARE_READ|syscall.FILE_SHARE_WRITE|syscall.FILE_SHARE_DELETE,
		nil, syscall.OPEN_EXISTING, syscall.FILE_FLAG_BACKUP_SEMANTICS, 0)
	if err != nil {
		t.Fatal(err)
	}
	defer syscall.CloseHandle(handle)
	var info syscall.ByHandleFileInformation
	if err := syscall.GetFileInformationByHandle(handle, &info); err != nil {
		t.Fatal(err)
	}
	return [3]uint32{info.VolumeSerialNumber, info.FileIndexHigh, info.FileIndexLow}
}

func TestReceiverNewInstallRenameFailureReturnsError(t *testing.T) {
	f, r := prepareNewInstallFixture(t)
	r.closeFiles()
	name, err := syscall.UTF16PtrFromString(r.gameRoot)
	if err != nil {
		t.Fatal(err)
	}
	handle, err := syscall.CreateFile(name, syscall.GENERIC_READ, syscall.FILE_SHARE_READ|syscall.FILE_SHARE_WRITE,
		nil, syscall.OPEN_EXISTING, syscall.FILE_FLAG_BACKUP_SEMANTICS, 0)
	if err != nil {
		t.Fatal(err)
	}
	defer syscall.CloseHandle(handle)
	if err := r.install(context.Background()); err == nil {
		t.Fatal("locked directory rename did not report an error")
	}
	if _, err := os.Stat(filepath.Join(f.library, "steamapps", "common", "FreshFixture")); !os.IsNotExist(err) {
		t.Fatal("failed directory rename fell back to publishing individual files")
	}
	if _, err := os.Stat(r.gameRoot); err != nil {
		t.Fatal("failed directory rename removed staging")
	}
}

func receiverCounters(r *incomingTransfer) model.Session {
	r.session.mu.Lock()
	defer r.session.mu.Unlock()
	return r.session.data
}

func TestReceiverDiskBytesIncludesCopyToStaging(t *testing.T) {
	f := newReceiverFixture(t, "aaaabbbb", "aaaabbbb", []fixtureChunk{{"aaaa", 0}, {"bbbb", 4}}, true)
	value := plan.Filter(f.local, nil)
	value.ID = "updated-plan"
	value.Files = value.Files[:1]
	value.Chunks = value.Chunks[:2]
	changed := sha1.Sum([]byte("AAAA"))
	value.Chunks[0].SHA1 = hex.EncodeToString(changed[:])
	value.Chunks[0].ID = "m-" + value.Chunks[0].SHA1
	whole := sha1.Sum([]byte("AAAAbbbb"))
	value.Files[0].SHA1 = hex.EncodeToString(whole[:])
	r := prepareReceiverFixture(t, f, value)
	if r.has(0) || !r.has(1) {
		t.Fatal("fixture should request one new chunk and reuse the other")
	}
	if err := r.writeChunk(0, []byte("AAAA")); err != nil {
		t.Fatal(err)
	}
	r.set(0)
	if err := r.verifyFiles(context.Background()); err != nil {
		t.Fatal(err)
	}
	if err := r.install(context.Background()); err != nil {
		t.Fatal(err)
	}
	counts := receiverCounters(r)
	if counts.NetworkBytes != 0 || counts.DiskBytes != 12 || counts.InstalledBytes != 8 || counts.InstalledFiles != 1 || counts.TotalFiles != 1 {
		t.Fatalf("expected 8 copied bytes plus 4 patched bytes and one installed file: %+v", counts)
	}
}
