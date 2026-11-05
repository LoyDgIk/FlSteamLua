package plan

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"flsteamlua/lan_transfer_engine/internal/model"
)

func TestParseVDF(t *testing.T) {
	value, err := ParseVDF(`"AppState" { "appid" "42" "InstalledDepots" { "99" { "manifest" "123" } } }`)
	if err != nil {
		t.Fatal(err)
	}
	state := MapValue(value, "AppState")
	if StringValue(state, "appid") != "42" {
		t.Fatal("appid not parsed")
	}
	depots := MapValue(state, "InstalledDepots")
	if StringValue(MapValue(depots, "99"), "manifest") != "123" {
		t.Fatal("depot manifest not parsed")
	}
}

func TestNormalizeRelativeRejectsTraversal(t *testing.T) {
	if normalizeRelative(`game\file.bin`) != "game/file.bin" {
		t.Fatal("path was not normalized")
	}
}

func TestFilterKeepsSourceChunkReferences(t *testing.T) {
	original := &model.Plan{AppID: 1, Files: []model.PlanFile{
		{ID: "extra", RelativePath: "a", Size: 1, Category: "extra", Chunks: []model.FileChunkRef{{ChunkIndex: 0, Size: 1}}},
		{ID: "official", RelativePath: "b", Size: 1, Category: "official", Selected: true, Chunks: []model.FileChunkRef{{ChunkIndex: 1, Size: 1}}},
	}, Chunks: []model.Chunk{{ID: "extra", Size: 1}, {ID: "official", Size: 1}}}
	first := Filter(original, nil)
	if first.Files[0].Chunks[0].ChunkIndex != 0 {
		t.Fatal("filtered plan did not remap chunk")
	}
	if original.Files[1].Chunks[0].ChunkIndex != 1 {
		t.Fatal("filter modified the source plan")
	}
	second := Filter(original, map[string]bool{"extra": true})
	if second.Chunks[second.Files[1].Chunks[0].ChunkIndex].ID != "official" {
		t.Fatal("second selection points at the wrong chunk")
	}
}

func TestExtraChunksIdentifyContent(t *testing.T) {
	builder := Builder{}
	var plans []*model.Plan
	for _, content := range []string{"LOCAL", "OTHER"} {
		root := t.TempDir()
		game := filepath.Join(root, "Fixture")
		if err := os.MkdirAll(game, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(game, "payload.bin"), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
		value, err := builder.Build(model.GameInput{AppID: 1, Name: "Fixture", InstallPath: game, LibraryPath: root})
		if err != nil {
			t.Fatal(err)
		}
		plans = append(plans, value)
	}
	if plans[0].Chunks[0].ID == plans[1].Chunks[0].ID || plans[0].Chunks[0].SHA1 == "" {
		t.Fatal("same-size extra files need content-based chunk identities")
	}
}

func TestMissingOfficialFileRejectsPlan(t *testing.T) {
	builder := Builder{}
	var chunks []model.Chunk
	_, _, err := builder.scanInstalledFiles(t.TempDir(), map[string]ManifestFile{
		"missing.bin": {FileName: "missing.bin", Size: 5},
	}, &chunks, map[string]uint32{})
	if err == nil {
		t.Fatal("missing official file was omitted from the plan")
	}
}

func TestLocalIndexStopsWhenCancelled(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	builder := Builder{Context: ctx, AllowMissingOfficial: true}
	var chunks []model.Chunk
	_, _, err := builder.scanInstalledFiles(t.TempDir(), nil, &chunks, map[string]uint32{})
	if err != context.Canceled {
		t.Fatalf("cancelled local index continued: %v", err)
	}
}
