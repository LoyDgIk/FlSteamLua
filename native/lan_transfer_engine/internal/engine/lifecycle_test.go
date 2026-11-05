package engine

import (
	"bytes"
	"crypto/sha1"
	"crypto/tls"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"

	"flsteamlua/lan_transfer_engine/internal/identity"
	"flsteamlua/lan_transfer_engine/internal/model"
)

func newTransferPair(t *testing.T) (*Engine, *Engine, string, string) {
	t.Helper()
	root := t.TempDir()
	library := filepath.Join(root, "library")
	lua := filepath.Join(root, "lua")
	for _, dir := range []string{library, lua} {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			t.Fatal(err)
		}
	}
	create := func(name string) *Engine {
		instance, err := New(filepath.Join(root, name))
		if err != nil {
			t.Fatal(err)
		}
		instance.identity, err = identity.LoadOrCreate(filepath.Join(instance.dataDir, "identity"), name)
		if err != nil {
			t.Fatal(err)
		}
		instance.config = model.Config{DataDir: instance.dataDir, DisplayName: name,
			SteamPath: filepath.Join(root, "steam"), LuaRoot: lua,
			LibraryRoots: []string{library}, SkipSteamRunningCheck: true}
		return instance
	}
	sender, receiver := create("sender"), create("receiver")
	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	receiver.server = &transferServer{engine: receiver, listener: tls.NewListener(listener, receiver.identity.ServerConfig())}
	go receiver.server.acceptLoop()
	sender.peers["receiver"] = model.Peer{ID: "receiver", Alias: "Receiver", Address: "127.0.0.1",
		Port: listener.Addr().(*net.TCPAddr).Port, Fingerprint: receiver.identity.Fingerprint}
	t.Cleanup(func() { sender.Close(); receiver.Close() })
	return sender, receiver, library, lua
}

func transferFixturePlan(t *testing.T, sender *Engine, count int) *model.Plan {
	t.Helper()
	path := filepath.Join(sender.dataDir, "payload.bin")
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	value := &model.Plan{ID: "fixture", AppID: 777, GameName: "Fixture", InstallDir: "Fixture"}
	entry := model.PlanFile{ID: "payload", RelativePath: "payload.bin", Category: "official",
		Selected: true, Size: int64(count) * 65536, SourcePath: path}
	whole := sha1.New()
	for i := 0; i < count; i++ {
		data := bytes.Repeat([]byte{byte(i), byte(i >> 8), 0x55, 0xaa}, 16384)
		if _, err := file.Write(data); err != nil {
			t.Fatal(err)
		}
		whole.Write(data)
		sum := sha1.Sum(data)
		value.Chunks = append(value.Chunks, model.Chunk{ID: fmt.Sprintf("chunk-%d", i), Size: int64(len(data)), SHA1: hex.EncodeToString(sum[:])})
		entry.Chunks = append(entry.Chunks, model.FileChunkRef{ChunkIndex: uint32(i), Offset: int64(i) * 65536, Size: 65536})
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	entry.SHA1 = hex.EncodeToString(whole.Sum(nil))
	value.Files = []model.PlanFile{entry}
	sender.plans[value.ID] = value
	return value
}

func startFixtureTransfer(t *testing.T, sender, receiver *Engine, library, lua string, value *model.Plan) string {
	t.Helper()
	if _, err := sender.Execute("send.start", mustJSON(t, map[string]any{"planId": value.ID, "peerId": "receiver"})); err != nil {
		t.Fatal(err)
	}
	offer := waitForOffer(t, receiver)
	if _, err := receiver.Execute("offer.accept", mustJSON(t, map[string]any{
		"sessionId": offer.SessionID, "targetLibrary": library, "luaRoot": lua,
	})); err != nil {
		t.Fatal(err)
	}
	return offer.SessionID
}

func awaitTransfer(t *testing.T, instance *Engine, id string, predicate func(model.Session) bool) model.Session {
	t.Helper()
	deadline := time.Now().Add(15 * time.Second)
	for time.Now().Before(deadline) {
		value := instance.sessionSnapshot(id)
		if predicate(value) {
			return value
		}
		time.Sleep(time.Millisecond)
	}
	t.Fatalf("transfer did not reach expected state: %+v", instance.sessionSnapshot(id))
	return model.Session{}
}

func TestReceiveCancelStopsDataAndInstallation(t *testing.T) {
	sender, receiver, library, lua := newTransferPair(t)
	value := transferFixturePlan(t, sender, 1024)
	id := startFixtureTransfer(t, sender, receiver, library, lua, value)
	awaitTransfer(t, receiver, id, func(s model.Session) bool { return s.CompletedChunks > 0 })
	if _, err := receiver.Execute("session.cancel", mustJSON(t, map[string]any{"sessionId": id})); err != nil {
		t.Fatal(err)
	}
	final := awaitTransfer(t, sender, id, func(s model.Session) bool {
		return s.Status == "failed" || s.Status == "cancelled" || s.Status == "completed"
	})
	if final.Status == "completed" || receiver.sessionSnapshot(id).Status != "cancelled" {
		t.Fatal("cancelled receive completed")
	}
	if _, err := os.Stat(filepath.Join(library, "steamapps", "common", "Fixture", "payload.bin")); !os.IsNotExist(err) {
		t.Fatal("cancelled data was installed")
	}
	if _, err := os.Stat(filepath.Join(library, "steamapps", ".flsteamlua", "incoming", final.BundleID, "state.bits")); err != nil {
		t.Fatal("cancel did not save resumable data:", err)
	}
}

func TestPausedSendSurvivesEngineRestartAndResumes(t *testing.T) {
	sender, receiver, library, lua := newTransferPair(t)
	value := transferFixturePlan(t, sender, 512)
	id := startFixtureTransfer(t, sender, receiver, library, lua, value)
	awaitTransfer(t, receiver, id, func(s model.Session) bool { return s.CompletedChunks > 0 })
	if _, err := sender.Execute("session.pause", mustJSON(t, map[string]any{"sessionId": id})); err != nil {
		t.Fatal(err)
	}
	awaitTransfer(t, receiver, id, func(s model.Session) bool { return s.Status == "paused" || s.Status == "failed" })
	sender.Close()
	restored, err := New(sender.dataDir)
	if err != nil {
		t.Fatal(err)
	}
	defer restored.Close()
	restored.identity, restored.config = sender.identity, sender.config
	listing, err := restored.Execute("session.list", json.RawMessage(`{}`))
	if err != nil {
		t.Fatal(err)
	}
	sessions := listing.(map[string]any)["sessions"].([]model.Session)
	if len(sessions) != 1 || sessions[0].Status != "paused" {
		t.Fatalf("paused task was not restored: %+v", sessions)
	}
	if _, err := restored.Execute("session.resume", mustJSON(t, map[string]any{"sessionId": id})); err != nil {
		t.Fatal(err)
	}
	offer := waitForOffer(t, receiver)
	if _, err := receiver.acceptOffer(offer.SessionID, library, lua, false); err != nil {
		t.Fatal(err)
	}
	final := awaitTransfer(t, restored, id, func(s model.Session) bool { return s.Status == "completed" || s.Status == "failed" })
	if final.Status != "completed" || final.CachedChunks == 0 {
		t.Fatalf("resume did not reuse staged data: %+v", final)
	}
	if final.InstalledFiles != 1 || final.TotalFiles != 1 || final.InstalledBytes != value.Files[0].Size || final.DiskBytes == 0 {
		t.Fatalf("sender did not receive actual receiver installation progress: %+v", final)
	}
	got, err := os.ReadFile(filepath.Join(library, "steamapps", "common", "Fixture", "payload.bin"))
	if err != nil {
		t.Fatal(err)
	}
	want, err := os.ReadFile(value.Files[0].SourcePath)
	if err != nil || !bytes.Equal(got, want) {
		t.Fatal("resumed output differs")
	}
}

func TestIncomingCacheIsCountedAndCleared(t *testing.T) {
	instance, err := New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	defer instance.Close()
	library := t.TempDir()
	instance.config.LibraryRoots = []string{library}
	staged := filepath.Join(library, "steamapps", ".flsteamlua", "incoming", "fixture", "game", "payload.bin")
	if err := os.MkdirAll(filepath.Dir(staged), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(staged, []byte("partial payload"), 0o600); err != nil {
		t.Fatal(err)
	}
	stats, err := instance.cacheStats()
	if err != nil || stats.Bytes != 15 || stats.Files != 1 {
		t.Fatalf("incorrect staging statistics: %+v %v", stats, err)
	}
	instance.sessions["receiving"] = &sessionRuntime{data: model.Session{Status: "preparing"}}
	if _, err := instance.clearCache(); err == nil {
		t.Fatal("cleared data during preparation")
	}
	delete(instance.sessions, "receiving")
	if _, err := instance.clearCache(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(staged); !os.IsNotExist(err) {
		t.Fatal("incoming data was not cleared")
	}
}

func TestSessionSpeedExcludesReusedBytes(t *testing.T) {
	instance, err := New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	defer instance.Close()
	runtime := &sessionRuntime{lastAt: time.Now().Add(-time.Second), data: model.Session{
		ID: "test", Direction: "receive", Status: "transferring", TotalBytes: 1 << 30, TransferredBytes: 1 << 30,
	}}
	instance.emitSession(runtime)
	if runtime.data.Speed != 0 || runtime.data.PeakSpeed != 0 {
		t.Fatal("local reused bytes counted as network speed")
	}
	runtime.lastAt = time.Now().Add(-time.Second)
	runtime.data.NetworkBytes = 1000
	instance.emitSession(runtime)
	if runtime.data.Speed < 900 || runtime.data.Speed > 1100 {
		t.Fatalf("network speed incorrect: %f", runtime.data.Speed)
	}
	instance.markSessionCompleted(runtime)
	if runtime.data.Speed != 0 {
		t.Fatal("completion created a speed spike")
	}
}

func TestSendCanBePausedImmediately(t *testing.T) {
	sender, _, _, _ := newTransferPair(t)
	value := transferFixturePlan(t, sender, 1)
	result, err := sender.Execute("send.start", mustJSON(t, map[string]any{"planId": value.ID, "peerId": "receiver"}))
	if err != nil {
		t.Fatal(err)
	}
	id := result.(model.Session).ID
	if _, err := sender.Execute("session.pause", mustJSON(t, map[string]any{"sessionId": id})); err != nil {
		t.Fatal(err)
	}
	if state := sender.sessionSnapshot(id).Status; state != "paused" {
		t.Fatalf("immediate pause was overwritten: %s", state)
	}
}

func TestCancelPendingReceiveRejectsOffer(t *testing.T) {
	sender, receiver, _, _ := newTransferPair(t)
	value := transferFixturePlan(t, sender, 1)
	if _, err := sender.Execute("send.start", mustJSON(t, map[string]any{"planId": value.ID, "peerId": "receiver"})); err != nil {
		t.Fatal(err)
	}
	offer := waitForOffer(t, receiver)
	if _, err := receiver.Execute("session.cancel", mustJSON(t, map[string]any{"sessionId": offer.SessionID})); err != nil {
		t.Fatal(err)
	}
	if state := receiver.sessionSnapshot(offer.SessionID).Status; state != "cancelled" {
		t.Fatalf("pending receive was not cancelled: %s", state)
	}
	awaitTransfer(t, sender, offer.SessionID, func(s model.Session) bool { return s.Status == "failed" || s.Status == "cancelled" })
}

func TestRejectConcurrentIncomingGame(t *testing.T) {
	instance, err := New(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	defer instance.Close()
	offer := model.OfferSummary{SessionID: "first", BundleID: "first", AppID: 1}
	if _, err := instance.addIncomingSession(offer); err != nil {
		t.Fatal(err)
	}
	offer.SessionID, offer.BundleID = "second", "second"
	if _, err := instance.addIncomingSession(offer); err == nil {
		t.Fatal("accepted concurrent writes to the same game")
	}
}
