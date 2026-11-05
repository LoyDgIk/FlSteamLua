package plan

import (
	"crypto/sha1"
	"encoding/hex"
	"testing"

	"flsteamlua/lan_transfer_engine/internal/model"
)

func validFixturePlan() *model.Plan {
	sum := sha1.Sum([]byte("hello"))
	sha := hex.EncodeToString(sum[:])
	return &model.Plan{ID: "fixture", AppID: 1, InstallDir: "Fixture", Files: []model.PlanFile{{
		ID: "payload", RelativePath: "dir/payload.bin", Size: 5, Category: "official", Selected: true,
		Chunks: []model.FileChunkRef{{ChunkIndex: 0, Offset: 0, Size: 5}},
	}}, Chunks: []model.Chunk{{ID: "m-" + sha, Size: 5, SHA1: sha}}}
}

func TestValidateRejectsUnsafeWindowsPaths(t *testing.T) {
	for _, path := range []string{"../outside", "/outside", `C:\outside`, `dir\..\outside`, "dir/file:stream", "NUL", "dir/COM1.bin", "dir/file.", "dir/file ", "dir//file"} {
		t.Run(path, func(t *testing.T) {
			value := validFixturePlan()
			value.Files[0].RelativePath = path
			if err := Validate(value); err == nil {
				t.Fatalf("accepted unsafe path %q", path)
			}
		})
	}
}

func TestValidateRequiresCompleteChunkCoverageAndDigests(t *testing.T) {
	for name, mutate := range map[string]func(*model.Plan){
		"missing hash":  func(value *model.Plan) { value.Chunks[0].SHA1 = "" },
		"invalid hash":  func(value *model.Plan) { value.Chunks[0].SHA1 = "not-a-hash" },
		"wrong size":    func(value *model.Plan) { value.Chunks[0].Size = 4 },
		"missing byte":  func(value *model.Plan) { value.Files[0].Size = 6 },
		"leading gap":   func(value *model.Plan) { value.Files[0].Chunks[0].Offset = 1 },
		"invalid index": func(value *model.Plan) { value.Files[0].Chunks[0].ChunkIndex = 1 },
	} {
		t.Run(name, func(t *testing.T) {
			value := validFixturePlan()
			mutate(value)
			if err := Validate(value); err == nil {
				t.Fatal("invalid plan was accepted")
			}
		})
	}
	if err := Validate(validFixturePlan()); err != nil {
		t.Fatal(err)
	}
}

func TestValidateRejectsAliasedWindowsDestinations(t *testing.T) {
	value := validFixturePlan()
	other := value.Files[0]
	other.ID = "another"
	other.Category = "extra"
	other.RelativePath = "DIR/PAYLOAD.BIN"
	value.Files = append(value.Files, other)
	if err := Validate(value); err == nil {
		t.Fatal("two files resolve to the same Windows destination")
	}
}
