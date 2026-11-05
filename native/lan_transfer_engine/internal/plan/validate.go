package plan

import (
	"encoding/hex"
	"fmt"
	"path/filepath"
	"sort"
	"strings"
	"unicode"

	"flsteamlua/lan_transfer_engine/internal/model"
	"flsteamlua/lan_transfer_engine/internal/protocol"
)

// SafeRelativePath validates paths received from manifests, network plans and
// persisted plans before they reach Windows filesystem operations.
func SafeRelativePath(value string) (string, error) {
	value = strings.ReplaceAll(value, `\`, "/")
	if value == "" || strings.HasPrefix(value, "/") || filepath.VolumeName(value) != "" {
		return "", fmt.Errorf("unsafe transfer path")
	}
	for _, component := range strings.Split(value, "/") {
		if component == "" || component == "." || component == ".." ||
			strings.TrimRight(component, ". ") != component ||
			strings.ContainsAny(component, `<>:"|?*`) || strings.IndexFunc(component, unicode.IsControl) >= 0 {
			return "", fmt.Errorf("unsafe transfer path")
		}
		base := strings.ToUpper(strings.SplitN(component, ".", 2)[0])
		deviceSuffix := ""
		if strings.HasPrefix(base, "COM") || strings.HasPrefix(base, "LPT") {
			deviceSuffix = base[3:]
		}
		if base == "CON" || base == "PRN" || base == "AUX" || base == "NUL" || base == "CONIN$" || base == "CONOUT$" ||
			(len(deviceSuffix) == 1 && deviceSuffix[0] >= '1' && deviceSuffix[0] <= '9') || deviceSuffix == "¹" || deviceSuffix == "²" || deviceSuffix == "³" {
			return "", fmt.Errorf("reserved Windows transfer path")
		}
	}
	return value, nil
}

func SafeName(value string) error {
	relative, err := SafeRelativePath(value)
	if err != nil || strings.Contains(relative, "/") {
		return fmt.Errorf("invalid transfer directory name")
	}
	return nil
}

// Validate is the shared boundary for network and persisted transfer plans.
func Validate(value *model.Plan) error {
	if value == nil || value.AppID == 0 || len(value.Files) == 0 || len(value.Files) > 2_000_000 || len(value.Chunks) > 10_000_000 {
		return fmt.Errorf("invalid transfer plan")
	}
	if err := SafeName(value.ID); err != nil {
		return fmt.Errorf("invalid transfer plan ID")
	}
	if err := SafeName(value.InstallDir); err != nil {
		return fmt.Errorf("invalid game install directory")
	}
	seenChunks := make(map[string]bool, len(value.Chunks))
	for _, chunk := range value.Chunks {
		if chunk.ID == "" || seenChunks[chunk.ID] || chunk.Size <= 0 || chunk.Size > protocol.MaxPayload-4 || !validDigest(chunk.SHA1, 20) {
			return fmt.Errorf("invalid transfer chunk")
		}
		seenChunks[chunk.ID] = true
	}
	seenFiles := make(map[string]bool, len(value.Files))
	seenPaths := make(map[string]bool, len(value.Files))
	used := make([]bool, len(value.Chunks))
	for _, file := range value.Files {
		if file.ID == "" || seenFiles[file.ID] || file.Size < 0 ||
			(file.SHA1 != "" && !validDigest(file.SHA1, 20)) || (file.SHA256 != "" && !validDigest(file.SHA256, 32)) {
			return fmt.Errorf("invalid transfer file")
		}
		seenFiles[file.ID] = true
		relative, err := SafeRelativePath(file.RelativePath)
		if err != nil {
			return err
		}
		category := file.Category
		if category != "official" && category != "extra" && category != "depotManifest" {
			return fmt.Errorf("invalid transfer file category")
		}
		if category == "depotManifest" {
			if !strings.HasPrefix(relative, "depotcache/") || strings.Count(relative, "/") != 1 || file.SHA256 == "" {
				return fmt.Errorf("invalid depot manifest path or checksum")
			}
		}
		key := strings.ToLower(category + "/" + relative)
		if category != "depotManifest" {
			key = strings.ToLower("game/" + relative)
		}
		if seenPaths[key] {
			return fmt.Errorf("duplicate transfer destination")
		}
		seenPaths[key] = true
		refs := append([]model.FileChunkRef(nil), file.Chunks...)
		sort.Slice(refs, func(i, j int) bool { return refs[i].Offset < refs[j].Offset })
		var end int64
		for _, ref := range refs {
			if uint64(ref.ChunkIndex) >= uint64(len(value.Chunks)) || ref.Offset != end || ref.Size <= 0 ||
				ref.Size > file.Size-end || ref.Size != value.Chunks[ref.ChunkIndex].Size {
				return fmt.Errorf("invalid transfer chunk reference")
			}
			end += ref.Size
			used[ref.ChunkIndex] = true
		}
		if end != file.Size {
			return fmt.Errorf("transfer chunks do not cover file")
		}
	}
	for _, present := range used {
		if !present {
			return fmt.Errorf("transfer plan contains an unreferenced chunk")
		}
	}
	return nil
}

func validDigest(value string, size int) bool {
	decoded, err := hex.DecodeString(value)
	return err == nil && len(decoded) == size
}
