package engine

import (
	"crypto/sha1"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"flsteamlua/lan_transfer_engine/internal/model"
	"flsteamlua/lan_transfer_engine/internal/plan"
)

func TestLoopbackTransfer(t *testing.T) {
	root := t.TempDir()
	steam := filepath.Join(root, "steam")
	library := filepath.Join(root, "library")
	luaRoot := filepath.Join(steam, "config", "stplug-in")
	for _, directory := range []string{
		filepath.Join(steam, "depotcache"),
		filepath.Join(library, "steamapps", "common"),
		luaRoot,
	} {
		if err := os.MkdirAll(directory, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	receiver, err := New(filepath.Join(root, "receiver"))
	if err != nil {
		t.Fatal(err)
	}
	sender, err := New(filepath.Join(root, "sender"))
	if err != nil {
		t.Fatal(err)
	}
	defer receiver.Close()
	defer sender.Close()
	if _, err := receiver.Execute("configure", mustJSON(t, model.Config{
		DataDir: filepath.Join(root, "receiver"), SteamPath: steam,
		LuaRoot: luaRoot, DisplayName: "Receiver", ReceiveEnabled: true,
		LibraryRoots: []string{library}, SkipSteamRunningCheck: true,
	})); err != nil {
		t.Fatal(err)
	}
	if _, err := sender.Execute("configure", mustJSON(t, model.Config{
		DataDir: filepath.Join(root, "sender"), SteamPath: steam,
		LuaRoot: luaRoot, DisplayName: "Sender", ReceiveEnabled: false,
		LibraryRoots: []string{library},
	})); err != nil {
		t.Fatal(err)
	}
	source := filepath.Join(root, "payload.bin")
	if err := os.WriteFile(source, []byte("hello-world"), 0o644); err != nil {
		t.Fatal(err)
	}
	acf := plan.StringifyVDF(plan.VDF{"appstate": map[string]any{
		"appid": "999", "name": "Fixture", "installdir": "Fixture",
		"stateflags": "4", "installeddepots": map[string]any{},
	}})
	firstChunk := []byte("hello")
	secondChunk := []byte("-world")
	firstHash := sha1.Sum(firstChunk)
	secondHash := sha1.Sum(secondChunk)
	transferPlan := &model.Plan{
		ID: "plan-999", AppID: 999, GameName: "Fixture", InstallDir: "Fixture",
		SourceAppManifest: acf, LuaContent: "addappid(999)", LuaEnabled: true,
		CreatedAt: time.Now().Unix(),
		Files: []model.PlanFile{{
			ID: "payload", RelativePath: "payload.bin", Size: 11,
			SHA1:     "fbb969117edfa916b86dfb67fd11decf1e336df0",
			Category: "official", Selected: true, SourcePath: source,
			Chunks: []model.FileChunkRef{
				{ChunkIndex: 0, Offset: 0, Size: 5},
				{ChunkIndex: 1, Offset: 5, Size: 6},
			},
		}},
		Chunks: []model.Chunk{
			{ID: "m-first", Size: 5, SHA1: hex.EncodeToString(firstHash[:])},
			{ID: "m-second", Size: 6, SHA1: hex.EncodeToString(secondHash[:])},
		},
	}
	sender.mu.Lock()
	sender.plans[transferPlan.ID] = transferPlan
	sender.peers["receiver"] = model.Peer{
		ID: "receiver", Alias: "Receiver", Address: "127.0.0.1", Port: 47821,
		Fingerprint: receiver.identity.Fingerprint,
	}
	sender.mu.Unlock()
	if _, err := sender.Execute("send.start", mustJSON(t, map[string]any{
		"planId": transferPlan.ID, "peerId": "receiver",
	})); err != nil {
		t.Fatal(err)
	}
	var offer model.OfferSummary
	deadline := time.After(10 * time.Second)
	for offer.SessionID == "" {
		select {
		case event := <-receiver.Events():
			if event.Name == "offer.received" {
				data, _ := json.Marshal(event.Data)
				_ = json.Unmarshal(data, &offer)
			}
		case <-deadline:
			t.Fatal("offer not received")
		}
	}
	if _, err := receiver.acceptOffer(offer.SessionID, library, luaRoot, false); err != nil {
		t.Fatal(err)
	}
	waitForSession(t, sender, "completed")
	waitForSession(t, receiver, "completed")
	data, err := os.ReadFile(filepath.Join(library, "steamapps", "common", "Fixture", "payload.bin"))
	if err != nil || string(data) != "hello-world" {
		t.Fatalf("payload mismatch: %q, %v", data, err)
	}
	if _, err := os.Stat(filepath.Join(library, "steamapps", "appmanifest_999.acf")); err != nil {
		t.Fatal(err)
	}
	metrics := receiver.sessionSnapshot(offer.SessionID)
	if metrics.NetworkBytes != 11 || metrics.DiskBytes != 11 || metrics.InstalledBytes != 11 || metrics.InstalledFiles != 1 || metrics.TotalFiles != 1 {
		t.Fatalf("new-install telemetry differs from actual TLS payload and file writes: %+v", metrics)
	}
}

func TestDeltaUsesExistingInstalledChunks(t *testing.T) {
	root := t.TempDir()
	steam := filepath.Join(root, "steam")
	library := filepath.Join(root, "library")
	luaRoot := filepath.Join(steam, "config", "stplug-in")
	gameDir := filepath.Join(library, "steamapps", "common", "Delta")
	for _, directory := range []string{luaRoot, gameDir, filepath.Join(steam, "depotcache")} {
		if err := os.MkdirAll(directory, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	payload := []byte("hello-world")
	target := filepath.Join(gameDir, "payload.bin")
	if err := os.WriteFile(target, payload, 0o644); err != nil {
		t.Fatal(err)
	}
	acf := plan.StringifyVDF(plan.VDF{"appstate": map[string]any{
		"appid": "998", "name": "Delta", "installdir": "Delta",
		"stateflags": "4", "installeddepots": map[string]any{},
	}})
	if err := os.WriteFile(
		filepath.Join(library, "steamapps", "appmanifest_998.acf"),
		[]byte(acf),
		0o644,
	); err != nil {
		t.Fatal(err)
	}
	receiver, err := New(filepath.Join(root, "receiver"))
	if err != nil {
		t.Fatal(err)
	}
	sender, err := New(filepath.Join(root, "sender"))
	if err != nil {
		t.Fatal(err)
	}
	defer receiver.Close()
	defer sender.Close()
	if _, err := receiver.Execute("configure", mustJSON(t, model.Config{
		DataDir: filepath.Join(root, "receiver"), SteamPath: steam,
		LuaRoot: luaRoot, DisplayName: "Receiver", ReceiveEnabled: true,
		LibraryRoots: []string{library}, SkipSteamRunningCheck: true,
	})); err != nil {
		t.Fatal(err)
	}
	if _, err := sender.Execute("configure", mustJSON(t, model.Config{
		DataDir: filepath.Join(root, "sender"), SteamPath: steam,
		LuaRoot: luaRoot, DisplayName: "Sender", ReceiveEnabled: false,
		LibraryRoots: []string{library}, SkipSteamRunningCheck: true,
	})); err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256([]byte("payload.bin"))
	fileID := hex.EncodeToString(sum[:])[:24]
	chunkSum := sha1.Sum(payload)
	chunkSHA := hex.EncodeToString(chunkSum[:])
	chunkID := "f-" + chunkSHA
	transferPlan := &model.Plan{
		ID: "delta-plan", AppID: 998, GameName: "Delta", InstallDir: "Delta",
		SourceAppManifest: acf, CreatedAt: time.Now().Unix(),
		Files: []model.PlanFile{{
			ID: fileID, RelativePath: "payload.bin", Size: 11,
			Category: "extra", Selected: true, SourcePath: target,
			Chunks: []model.FileChunkRef{{ChunkIndex: 0, Offset: 0, Size: 11}},
		}},
		Chunks: []model.Chunk{{ID: chunkID, Size: 11, SHA1: chunkSHA}},
	}
	sender.mu.Lock()
	sender.plans[transferPlan.ID] = transferPlan
	sender.peers["receiver"] = model.Peer{
		ID: "receiver", Alias: "Receiver", Address: "127.0.0.1", Port: 47821,
		Fingerprint: receiver.identity.Fingerprint,
	}
	sender.mu.Unlock()
	if _, err := sender.startSend(transferPlan.ID, "receiver", []string{fileID}); err != nil {
		t.Fatal(err)
	}
	offer := waitForOffer(t, receiver)
	if _, err := receiver.acceptOffer(offer.SessionID, library, luaRoot, false); err != nil {
		t.Fatal(err)
	}
	waitForSession(t, sender, "completed")
	waitForSession(t, receiver, "completed")
	receiver.mu.Lock()
	runtime := receiver.sessions[offer.SessionID]
	receiver.mu.Unlock()
	runtime.mu.Lock()
	cached := runtime.data.CachedChunks
	runtime.mu.Unlock()
	if cached != 1 {
		t.Fatalf("expected existing chunk to be reused, cached=%d", cached)
	}
	metrics := receiver.sessionSnapshot(offer.SessionID)
	if metrics.NetworkBytes != 0 || metrics.DiskBytes != 0 || metrics.InstalledBytes != 11 || metrics.InstalledFiles != 1 || metrics.TotalFiles != 1 {
		t.Fatalf("unchanged delta telemetry counted network or disk work: %+v", metrics)
	}
}

func waitForOffer(t *testing.T, instance *Engine) model.OfferSummary {
	t.Helper()
	deadline := time.After(10 * time.Second)
	for {
		select {
		case event := <-instance.Events():
			if event.Name != "offer.received" {
				continue
			}
			data, _ := json.Marshal(event.Data)
			var offer model.OfferSummary
			_ = json.Unmarshal(data, &offer)
			return offer
		case <-deadline:
			t.Fatal("offer not received")
		}
	}
}

func waitForSession(t *testing.T, instance *Engine, status string) {
	t.Helper()
	deadline := time.After(15 * time.Second)
	for {
		instance.mu.Lock()
		for _, runtime := range instance.sessions {
			runtime.mu.Lock()
			value := runtime.data.Status
			runtime.mu.Unlock()
			if value == status {
				instance.mu.Unlock()
				return
			}
		}
		instance.mu.Unlock()
		select {
		case <-instance.Events():
		case <-deadline:
			instance.mu.Lock()
			var sessions []model.Session
			for _, runtime := range instance.sessions {
				runtime.mu.Lock()
				sessions = append(sessions, runtime.data)
				runtime.mu.Unlock()
			}
			instance.mu.Unlock()
			t.Fatalf("session did not reach %s: %#v", status, sessions)
		}
	}
}

func mustJSON(t *testing.T, value any) json.RawMessage {
	t.Helper()
	data, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	return data
}
