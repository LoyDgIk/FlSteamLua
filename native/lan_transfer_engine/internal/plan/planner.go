package plan

import (
	"crypto/sha1"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"flsteamlua/lan_transfer_engine/internal/model"
)

const fixedChunkSize = 4 * 1024 * 1024

var manifestReferencePattern = regexp.MustCompile(`(?i)setManifestid\s*\(\s*(\d+)\s*,\s*["'](\d+)["']`)

type Builder struct {
	Config model.Config
	Keys   map[uint32][]byte
}

func (b *Builder) Build(game model.GameInput) (*model.Plan, error) {
	if game.AppID == 0 || strings.TrimSpace(game.InstallPath) == "" {
		return nil, fmt.Errorf("installed game and AppID are required")
	}
	acfPath := filepath.Join(game.LibraryPath, "steamapps", fmt.Sprintf("appmanifest_%d.acf", game.AppID))
	acfBytes, err := os.ReadFile(acfPath)
	if err != nil && !os.IsNotExist(err) {
		return nil, err
	}
	luaContent := ""
	if game.LuaPath != "" {
		if bytes, err := os.ReadFile(game.LuaPath); err == nil {
			luaContent = string(bytes)
		}
	}
	refs, err := manifestReferences(string(acfBytes), luaContent)
	if err != nil {
		return nil, err
	}
	loaded, missing, encrypted, err := b.loadManifests(game.LibraryPath, refs)
	if err != nil {
		return nil, err
	}
	officialByPath := make(map[string]ManifestFile)
	for _, manifest := range loaded {
		for _, file := range manifest.Files {
			relative := normalizeRelative(file.FileName)
			if relative == "" || file.Flags&(64|256) != 0 {
				continue
			}
			officialByPath[strings.ToLower(relative)] = file
		}
	}
	chunks := make([]model.Chunk, 0)
	chunkIndex := make(map[string]uint32)
	files, totalBytes, err := b.scanInstalledFiles(
		game.InstallPath,
		officialByPath,
		&chunks,
		chunkIndex,
	)
	if err != nil {
		return nil, err
	}
	var attachChunks func(file *model.PlanFile, manifestFile ManifestFile)
	attachChunks = func(file *model.PlanFile, manifestFile ManifestFile) {
		for _, chunk := range manifestFile.Chunks {
			if chunk.OriginalSize == 0 {
				continue
			}
			sha := hex.EncodeToString(chunk.SHA)
			id := "m-" + sha
			index, exists := chunkIndex[id]
			if !exists {
				index = uint32(len(chunks))
				chunkIndex[id] = index
				chunks = append(chunks, model.Chunk{
					ID: id, Size: int64(chunk.OriginalSize), SHA1: sha, CRC: chunk.CRC,
				})
			}
			file.Chunks = append(file.Chunks, model.FileChunkRef{
				ChunkIndex: index, Offset: int64(chunk.Offset), Size: int64(chunk.OriginalSize),
			})
		}
	}
	for index := range files {
		file := &files[index]
		if file.Category != "official" {
			continue
		}
		manifestFile, ok := officialByPath[strings.ToLower(file.RelativePath)]
		if !ok {
			continue
		}
		attachChunks(file, manifestFile)
	}
	manifestEntries, manifestBytes, err := b.manifestEntries(loaded, chunkIndex, &chunks)
	if err != nil {
		return nil, err
	}
	files = append(files, manifestEntries...)
	totalBytes += manifestBytes
	warnings := []string{}
	if len(acfBytes) == 0 {
		warnings = append(warnings, "Source app manifest is unavailable.")
	}
	if len(loaded) == 0 {
		warnings = append(warnings, "No local depot manifests were found; only local files are available.")
	}
	if encrypted > 0 {
		warnings = append(warnings, fmt.Sprintf("%d depot manifests could not be decrypted.", encrypted))
	}
	for _, value := range missing {
		warnings = append(warnings, "Missing depot manifest "+value+".")
	}
	plan := &model.Plan{
		AppID:               game.AppID,
		GameName:            game.Name,
		InstallDir:          filepath.Base(filepath.Clean(game.InstallPath)),
		CoverURL:            game.CoverURL,
		SourceAppManifest:   string(acfBytes),
		LuaContent:          luaContent,
		LuaEnabled:          luaContent != "",
		ManifestAvailable:   len(loaded) > 0 && encrypted == 0,
		TotalCandidateBytes: totalBytes,
		Warnings:            warnings,
		Files:               files,
		Chunks:              chunks,
		CreatedAt:           time.Now().Unix(),
	}
	plan.ID = planID(plan)
	return plan, nil
}

func (b *Builder) scanInstalledFiles(
	root string,
	official map[string]ManifestFile,
	chunks *[]model.Chunk,
	chunkIndex map[string]uint32,
) ([]model.PlanFile, int64, error) {
	var paths []string
	err := filepath.WalkDir(root, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if entry.Type()&os.ModeSymlink != 0 {
			return fmt.Errorf("linked game content is not supported: %s", path)
		}
		if entry.IsDir() {
			return nil
		}
		paths = append(paths, path)
		return nil
	})
	if err != nil {
		return nil, 0, err
	}
	sort.Slice(paths, func(i, j int) bool { return strings.ToLower(paths[i]) < strings.ToLower(paths[j]) })
	files := make([]model.PlanFile, 0, len(paths))
	var total int64
	for _, path := range paths {
		relative, err := filepath.Rel(root, path)
		if err != nil {
			return nil, 0, err
		}
		relative = normalizeRelative(relative)
		manifestFile, officialFile := official[strings.ToLower(relative)]
		size := manifestFile.Size
		sha1Text := hex.EncodeToString(manifestFile.SHA)
		sourceModified := int64(0)
		category := "official"
		selected := true
		if !officialFile {
			info, err := os.Stat(path)
			if err != nil {
				return nil, 0, err
			}
			size = uint64(info.Size())
			sha1Text = ""
			sourceModified = info.ModTime().UnixMilli()
			category = "extra"
			selected = false
		}
		id := fileID(relative)
		file := model.PlanFile{
			ID: id, RelativePath: relative, Size: int64(size), SHA1: sha1Text,
			Category: category, Selected: selected, SourceModified: sourceModified,
			SourcePath: path,
		}
		if !officialFile {
			appendFixedChunks(&file, chunks, chunkIndex)
		}
		files = append(files, file)
		total += int64(size)
	}
	return files, total, nil
}

func (b *Builder) manifestEntries(
	manifests []*Manifest,
	chunkIndex map[string]uint32,
	chunks *[]model.Chunk,
) ([]model.PlanFile, int64, error) {
	result := make([]model.PlanFile, 0, len(manifests))
	var total int64
	for _, manifest := range manifests {
		path := manifest.SourcePath
		if path == "" {
			continue
		}
		content, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		relative := filepath.ToSlash(filepath.Join("depotcache", filepath.Base(path)))
		id := "manifest-" + manifestFileNameID(manifest.DepotID, manifest.ManifestGID)
		sha1Bytes := sha1.Sum(content)
		sha256Bytes := sha256.Sum256(content)
		file := model.PlanFile{
			ID: id, RelativePath: relative, Size: int64(len(content)),
			SHA1: hex.EncodeToString(sha1Bytes[:]), SHA256: hex.EncodeToString(sha256Bytes[:]),
			Category: "depotManifest", Selected: true, SourcePath: path,
		}
		appendFixedChunks(&file, chunks, chunkIndex)
		result = append(result, file)
		total += file.Size
	}
	return result, total, nil
}

func (b *Builder) loadManifests(
	libraryPath string,
	refs map[uint32]string,
) ([]*Manifest, []string, int, error) {
	var manifests []*Manifest
	var missing []string
	encrypted := 0
	for _, depotID := range sortedKeys(refs) {
		manifestID := refs[depotID]
		name := fmt.Sprintf("%d_%s.manifest", depotID, manifestID)
		candidates := []string{
			filepath.Join(libraryPath, "steamapps", "depotcache", name),
			filepath.Join(b.Config.SteamPath, "depotcache", name),
		}
		var content []byte
		var sourcePath string
		var err error
		for _, candidate := range candidates {
			content, err = os.ReadFile(candidate)
			if err == nil {
				sourcePath = candidate
				break
			}
		}
		if err != nil {
			missing = append(missing, strings.TrimSuffix(name, ".manifest"))
			continue
		}
		manifest, err := ParseManifest(content, b.Keys[depotID])
		if err != nil {
			missing = append(missing, strings.TrimSuffix(name, ".manifest"))
			continue
		}
		manifest.SourcePath = sourcePath
		if manifest.FilenamesEncrypted {
			encrypted++
		}
		manifests = append(manifests, manifest)
	}
	return manifests, missing, encrypted, nil
}

func manifestReferences(acf, lua string) (map[uint32]string, error) {
	result := make(map[uint32]string)
	if strings.TrimSpace(acf) != "" {
		root, err := ParseVDF(acf)
		if err != nil {
			return nil, err
		}
		state := MapValue(root, "AppState")
		if state == nil {
			state = root
		}
		for _, key := range []string{"InstalledDepots", "MountedDepots"} {
			depots := MapValue(state, key)
			for idText, value := range depots {
				id, err := strconv.ParseUint(idText, 10, 32)
				if err != nil {
					continue
				}
				manifestID := ""
				if nested, ok := value.(map[string]any); ok {
					manifestID = StringValue(VDF(nested), "manifest")
					if manifestID == "" {
						manifestID = StringValue(VDF(nested), "gid")
					}
				} else {
					manifestID = fmt.Sprint(value)
				}
				if manifestID != "" && manifestID != "<nil>" {
					result[uint32(id)] = manifestID
				}
			}
		}
	}
	for _, match := range manifestReferencePattern.FindAllStringSubmatch(lua, -1) {
		id, err := strconv.ParseUint(match[1], 10, 32)
		if err != nil {
			continue
		}
		result[uint32(id)] = match[2]
	}
	return result, nil
}

func Filter(plan *model.Plan, selectedOptional map[string]bool) *model.Plan {
	files := make([]model.PlanFile, 0, len(plan.Files))
	for _, file := range plan.Files {
		switch file.Category {
		case "official", "depotManifest":
			file.Selected = true
		case "extra":
			file.Selected = selectedOptional[file.ID]
		default:
			file.Selected = false
		}
		if file.Selected {
			files = append(files, file)
		}
	}
	oldChunks := plan.Chunks
	newChunks := make([]model.Chunk, 0)
	indexMap := make(map[uint32]uint32)
	for fileIndex := range files {
		for refIndex := range files[fileIndex].Chunks {
			old := files[fileIndex].Chunks[refIndex].ChunkIndex
			index, ok := indexMap[old]
			if !ok {
				index = uint32(len(newChunks))
				indexMap[old] = index
				newChunks = append(newChunks, oldChunks[old])
			}
			files[fileIndex].Chunks[refIndex].ChunkIndex = index
		}
	}
	result := *plan
	result.Files = files
	result.Chunks = newChunks
	result.ID = planID(&result)
	return &result
}

func Summary(plan *model.Plan) model.PlanSummary {
	summary := model.PlanSummary{
		ID: plan.ID, AppID: plan.AppID, GameName: plan.GameName,
		InstallDir: plan.InstallDir, CoverURL: plan.CoverURL,
		LuaEnabled: plan.LuaEnabled, ManifestAvailable: plan.ManifestAvailable,
		ChunkCount: len(plan.Chunks), Warnings: append([]string(nil), plan.Warnings...),
	}
	for _, file := range plan.Files {
		switch file.Category {
		case "official":
			summary.OfficialFiles++
			summary.OfficialBytes += file.Size
			summary.SelectedBytes += file.Size
		case "depotManifest":
			summary.ManifestFiles++
			summary.ManifestBytes += file.Size
			summary.SelectedBytes += file.Size
		case "extra":
			summary.OptionalBytes += file.Size
			summary.OptionalFiles = append(summary.OptionalFiles, model.FileSummary{
				ID: file.ID, RelativePath: file.RelativePath, Size: file.Size, Category: file.Category,
			})
		}
	}
	return summary
}

func appendFixedChunks(file *model.PlanFile, chunks *[]model.Chunk, indexMap map[string]uint32) {
	if file.Size <= 0 {
		return
	}
	for offset := int64(0); offset < file.Size; offset += fixedChunkSize {
		length := minInt64(fixedChunkSize, file.Size-offset)
		id := fmt.Sprintf("f-%s-%d-%d", file.ID, offset, length)
		index, exists := indexMap[id]
		if !exists {
			index = uint32(len(*chunks))
			indexMap[id] = index
			*chunks = append(*chunks, model.Chunk{ID: id, Size: length})
		}
		file.Chunks = append(file.Chunks, model.FileChunkRef{
			ChunkIndex: index, Offset: offset, Size: length,
		})
	}
}

func planID(plan *model.Plan) string {
	type idFile struct {
		ID           string               `json:"id"`
		RelativePath string               `json:"relativePath"`
		Size         int64                `json:"size"`
		SHA1         string               `json:"sha1"`
		SHA256       string               `json:"sha256"`
		Category     string               `json:"category"`
		Selected     bool                 `json:"selected"`
		Modified     int64                `json:"modified"`
		Chunks       []model.FileChunkRef `json:"chunks"`
	}
	files := make([]idFile, 0, len(plan.Files))
	for _, file := range plan.Files {
		if !file.Selected {
			continue
		}
		files = append(files, idFile{
			ID: file.ID, RelativePath: file.RelativePath, Size: file.Size,
			SHA1: file.SHA1, SHA256: file.SHA256, Category: file.Category,
			Selected: file.Selected, Modified: file.SourceModified, Chunks: file.Chunks,
		})
	}
	value := struct {
		AppID  uint32        `json:"appId"`
		ACF    string        `json:"acf"`
		Lua    string        `json:"lua"`
		Files  []idFile      `json:"files"`
		Chunks []model.Chunk `json:"chunks"`
	}{plan.AppID, plan.SourceAppManifest, plan.LuaContent, files, plan.Chunks}
	data, _ := json.Marshal(value)
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func fileID(path string) string {
	sum := sha256.Sum256([]byte(path))
	return hex.EncodeToString(sum[:])[:24]
}

func manifestFileNameID(depot uint32, manifest uint64) string {
	sum := sha256.Sum256([]byte(fmt.Sprintf("%d_%d", depot, manifest)))
	return hex.EncodeToString(sum[:])[:16]
}

func normalizeRelative(value string) string {
	value = strings.ReplaceAll(value, `\`, "/")
	value = strings.TrimLeft(value, "/")
	return filepath.ToSlash(filepath.Clean(value))
}

func sortedKeys(values map[uint32]string) []uint32 {
	keys := make([]uint32, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool { return keys[i] < keys[j] })
	return keys
}

func minInt64(a, b int64) int64 {
	if a < b {
		return a
	}
	return b
}

func HashFile(path string) (string, string, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", "", err
	}
	defer file.Close()
	h1 := sha1.New()
	h256 := sha256.New()
	if _, err := io.Copy(io.MultiWriter(h1, h256), file); err != nil {
		return "", "", err
	}
	return hex.EncodeToString(h1.Sum(nil)), hex.EncodeToString(h256.Sum(nil)), nil
}
