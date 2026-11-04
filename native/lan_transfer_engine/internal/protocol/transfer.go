package protocol

import (
	"fmt"

	"flsteamlua/lan_transfer_engine/internal/model"
)

type Offer struct {
	SessionID         string
	BundleID          string
	AppID             uint32
	GameName          string
	InstallDir        string
	CoverURL          string
	TotalBytes        int64
	SelectedBytes     int64
	FileCount         int
	ChunkCount        int
	LuaEnabled        bool
	ManifestAvailable bool
	Warnings          []string
}

func EncodeOffer(value Offer) []byte {
	var p PB
	p.String(1, value.SessionID)
	p.String(2, value.BundleID)
	p.Uint(3, uint64(value.AppID))
	p.String(4, value.GameName)
	p.String(5, value.InstallDir)
	p.String(6, value.CoverURL)
	p.Uint(7, uint64(value.TotalBytes))
	p.Uint(8, uint64(value.FileCount))
	p.Uint(9, uint64(value.ChunkCount))
	p.Bool(10, value.LuaEnabled)
	p.Bool(11, value.ManifestAvailable)
	for _, warning := range value.Warnings {
		p.String(12, warning)
	}
	p.Uint(13, uint64(value.SelectedBytes))
	return p.Result()
}

func DecodeOffer(data []byte) (Offer, error) {
	f, err := ParseFields(data)
	if err != nil {
		return Offer{}, err
	}
	appID := f.Uint(3)
	if appID == 0 || appID > uint64(^uint32(0)) {
		return Offer{}, fmt.Errorf("invalid offer AppID")
	}
	var warnings []string
	for _, value := range f.Messages(12) {
		warnings = append(warnings, string(value))
	}
	return Offer{
		SessionID:         f.String(1),
		BundleID:          f.String(2),
		AppID:             uint32(appID),
		GameName:          f.String(4),
		InstallDir:        f.String(5),
		CoverURL:          f.String(6),
		TotalBytes:        int64(f.Uint(7)),
		FileCount:         int(f.Uint(8)),
		ChunkCount:        int(f.Uint(9)),
		LuaEnabled:        f.Bool(10),
		ManifestAvailable: f.Bool(11),
		Warnings:          warnings,
		SelectedBytes:     int64(f.Uint(13)),
	}, nil
}

type PlanStart struct {
	PlanID            string
	BundleID          string
	AppID             uint32
	GameName          string
	InstallDir        string
	CoverURL          string
	SourceAppManifest string
	LuaContent        string
	LuaEnabled        bool
	ManifestAvailable bool
	TotalBytes        int64
	FileCount         int
	ChunkCount        int
	Warnings          []string
}

func EncodePlanStart(value PlanStart) []byte {
	var p PB
	p.String(1, value.PlanID)
	p.String(2, value.BundleID)
	p.Uint(3, uint64(value.AppID))
	p.String(4, value.GameName)
	p.String(5, value.InstallDir)
	p.String(6, value.CoverURL)
	p.String(7, value.SourceAppManifest)
	p.String(8, value.LuaContent)
	p.Bool(9, value.LuaEnabled)
	p.Bool(10, value.ManifestAvailable)
	p.Uint(11, uint64(value.TotalBytes))
	p.Uint(12, uint64(value.FileCount))
	p.Uint(13, uint64(value.ChunkCount))
	for _, warning := range value.Warnings {
		p.String(14, warning)
	}
	return p.Result()
}

func DecodePlanStart(data []byte) (PlanStart, error) {
	f, err := ParseFields(data)
	if err != nil {
		return PlanStart{}, err
	}
	appID := f.Uint(3)
	if appID == 0 || appID > uint64(^uint32(0)) {
		return PlanStart{}, fmt.Errorf("invalid plan AppID")
	}
	var warnings []string
	for _, value := range f.Messages(14) {
		warnings = append(warnings, string(value))
	}
	return PlanStart{
		PlanID:            f.String(1),
		BundleID:          f.String(2),
		AppID:             uint32(appID),
		GameName:          f.String(4),
		InstallDir:        f.String(5),
		CoverURL:          f.String(6),
		SourceAppManifest: f.String(7),
		LuaContent:        f.String(8),
		LuaEnabled:        f.Bool(9),
		ManifestAvailable: f.Bool(10),
		TotalBytes:        int64(f.Uint(11)),
		FileCount:         int(f.Uint(12)),
		ChunkCount:        int(f.Uint(13)),
		Warnings:          warnings,
	}, nil
}

func EncodePlanFile(file model.PlanFile) []byte {
	var p PB
	p.String(1, file.ID)
	p.String(2, file.RelativePath)
	p.Uint(3, uint64(file.Size))
	p.String(4, file.SHA1)
	p.String(5, file.SHA256)
	p.String(6, file.Category)
	p.Bool(7, file.Selected)
	p.Uint(8, uint64(file.SourceModified))
	for _, ref := range file.Chunks {
		var nested PB
		nested.Uint(1, uint64(ref.ChunkIndex))
		nested.Uint(2, uint64(ref.Offset))
		nested.Uint(3, uint64(ref.Size))
		p.Message(9, nested.Result())
	}
	return p.Result()
}

func DecodePlanFile(data []byte) (model.PlanFile, error) {
	f, err := ParseFields(data)
	if err != nil {
		return model.PlanFile{}, err
	}
	file := model.PlanFile{
		ID:             f.String(1),
		RelativePath:   f.String(2),
		Size:           int64(f.Uint(3)),
		SHA1:           f.String(4),
		SHA256:         f.String(5),
		Category:       f.String(6),
		Selected:       f.Bool(7),
		SourceModified: int64(f.Uint(8)),
	}
	for _, raw := range f.Messages(9) {
		refFields, err := ParseFields(raw)
		if err != nil {
			return model.PlanFile{}, err
		}
		index := refFields.Uint(1)
		if index > uint64(^uint32(0)) {
			return model.PlanFile{}, fmt.Errorf("invalid chunk index")
		}
		file.Chunks = append(file.Chunks, model.FileChunkRef{
			ChunkIndex: uint32(index),
			Offset:     int64(refFields.Uint(2)),
			Size:       int64(refFields.Uint(3)),
		})
	}
	return file, nil
}

func EncodePlanFiles(files []model.PlanFile) []byte {
	var p PB
	for _, file := range files {
		p.Message(1, EncodePlanFile(file))
	}
	return p.Result()
}

func DecodePlanFiles(data []byte) ([]model.PlanFile, error) {
	f, err := ParseFields(data)
	if err != nil {
		return nil, err
	}
	rawFiles := f.Messages(1)
	files := make([]model.PlanFile, 0, len(rawFiles))
	for _, raw := range rawFiles {
		file, err := DecodePlanFile(raw)
		if err != nil {
			return nil, err
		}
		files = append(files, file)
	}
	return files, nil
}

func EncodePlanChunk(chunk model.Chunk) []byte {
	var p PB
	p.String(1, chunk.ID)
	p.Uint(2, uint64(chunk.Size))
	p.String(3, chunk.SHA1)
	p.Fixed32(4, chunk.CRC)
	return p.Result()
}

func DecodePlanChunk(data []byte) (model.Chunk, error) {
	f, err := ParseFields(data)
	if err != nil {
		return model.Chunk{}, err
	}
	return model.Chunk{
		ID:   f.String(1),
		Size: int64(f.Uint(2)),
		SHA1: f.String(3),
		CRC:  uint32(f.Uint(4)),
	}, nil
}

func EncodePlanChunks(chunks []model.Chunk) []byte {
	var p PB
	for _, chunk := range chunks {
		p.Message(1, EncodePlanChunk(chunk))
	}
	return p.Result()
}

func DecodePlanChunks(data []byte) ([]model.Chunk, error) {
	f, err := ParseFields(data)
	if err != nil {
		return nil, err
	}
	raw := f.Messages(1)
	chunks := make([]model.Chunk, 0, len(raw))
	for _, value := range raw {
		chunk, err := DecodePlanChunk(value)
		if err != nil {
			return nil, err
		}
		chunks = append(chunks, chunk)
	}
	return chunks, nil
}

func EncodeChunkData(index uint32, data []byte) []byte {
	payload := make([]byte, 4+len(data))
	payload[0] = byte(index)
	payload[1] = byte(index >> 8)
	payload[2] = byte(index >> 16)
	payload[3] = byte(index >> 24)
	copy(payload[4:], data)
	return payload
}

func DecodeChunkData(payload []byte) (uint32, []byte, error) {
	if len(payload) < 4 {
		return 0, nil, fmt.Errorf("truncated chunk frame")
	}
	index := uint32(payload[0]) | uint32(payload[1])<<8 | uint32(payload[2])<<16 | uint32(payload[3])<<24
	return index, payload[4:], nil
}
