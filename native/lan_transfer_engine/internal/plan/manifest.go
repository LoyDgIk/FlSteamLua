package plan

import (
	"archive/zip"
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"io"
	"path/filepath"
	"sort"
	"strings"

	"flsteamlua/lan_transfer_engine/internal/protocol"
)

const (
	manifestPayloadMagic   = 0x71f617d0
	manifestMetadataMagic  = 0x1f4812be
	manifestSignatureMagic = 0x1b81b817
	manifestEndMagic       = 0x32c415ab
)

type ManifestChunk struct {
	SHA            []byte
	CRC            uint32
	Offset         uint64
	OriginalSize   uint64
	CompressedSize uint64
}

type ManifestFile struct {
	FileName    string
	Size        uint64
	Flags       uint32
	FileNameSHA []byte
	SHA         []byte
	Chunks      []ManifestChunk
	LinkTarget  string
}

type Manifest struct {
	DepotID            uint32
	ManifestGID        uint64
	CreationTime       uint64
	FilenamesEncrypted bool
	OriginalSize       uint64
	CompressedSize     uint64
	EncryptedCRC       uint32
	Files              []ManifestFile
	SourcePath         string
}

func ParseManifest(input []byte, depotKey []byte) (*Manifest, error) {
	if len(input) > 128*1024*1024 {
		return nil, fmt.Errorf("depot manifest exceeds 128 MiB")
	}
	data := input
	if len(data) >= 2 && data[0] == 'P' && data[1] == 'K' {
		reader, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
		if err != nil {
			return nil, fmt.Errorf("read manifest zip: %w", err)
		}
		var entry *zip.File
		for _, file := range reader.File {
			if file.FileInfo().IsDir() {
				continue
			}
			if entry != nil {
				return nil, fmt.Errorf("manifest zip contains multiple files")
			}
			entry = file
		}
		if entry == nil {
			return nil, fmt.Errorf("manifest zip is empty")
		}
		if entry.UncompressedSize64 > 128*1024*1024 {
			return nil, fmt.Errorf("manifest zip entry exceeds limit")
		}
		opened, err := entry.Open()
		if err != nil {
			return nil, err
		}
		data, err = io.ReadAll(opened)
		closeErr := opened.Close()
		if err != nil {
			return nil, err
		}
		if closeErr != nil {
			return nil, closeErr
		}
	}
	var payload, metadata []byte
	hasSignature, hasEnd := false, false
	offset := 0
	for offset < len(data) {
		if len(data)-offset < 4 {
			return nil, fmt.Errorf("truncated manifest marker")
		}
		magic := binary.LittleEndian.Uint32(data[offset : offset+4])
		offset += 4
		if magic == manifestEndMagic {
			hasEnd = true
			break
		}
		if len(data)-offset < 4 {
			return nil, fmt.Errorf("truncated manifest section")
		}
		size := int(binary.LittleEndian.Uint32(data[offset : offset+4]))
		offset += 4
		if size < 0 || size > len(data)-offset {
			return nil, fmt.Errorf("truncated manifest section")
		}
		section := data[offset : offset+size]
		offset += size
		switch magic {
		case manifestPayloadMagic:
			if payload != nil {
				return nil, fmt.Errorf("duplicate manifest payload")
			}
			payload = section
		case manifestMetadataMagic:
			if metadata != nil {
				return nil, fmt.Errorf("duplicate manifest metadata")
			}
			metadata = section
		case manifestSignatureMagic:
			if hasSignature {
				return nil, fmt.Errorf("duplicate manifest signature")
			}
			hasSignature = true
		default:
			return nil, fmt.Errorf("unsupported manifest marker %#x", magic)
		}
	}
	if payload == nil || metadata == nil || !hasSignature || !hasEnd || offset != len(data) {
		return nil, fmt.Errorf("incomplete depot manifest")
	}
	info, err := protocol.ParseFields(metadata)
	if err != nil {
		return nil, err
	}
	manifest := &Manifest{
		DepotID:            uint32(info.Uint(1)),
		ManifestGID:        info.Uint(2),
		CreationTime:       info.Uint(3),
		FilenamesEncrypted: info.Uint(4) != 0,
		OriginalSize:       info.Uint(5),
		CompressedSize:     info.Uint(6),
		EncryptedCRC:       uint32(info.Uint(8)),
	}
	payloadFields, err := protocol.ParseFields(payload)
	if err != nil {
		return nil, err
	}
	for _, rawFile := range payloadFields.Messages(1) {
		fields, err := protocol.ParseFields(rawFile)
		if err != nil {
			return nil, err
		}
		file := ManifestFile{
			FileName:    fields.String(1),
			Size:        fields.Uint(2),
			Flags:       uint32(fields.Uint(3)),
			FileNameSHA: fields.Bytes(4),
			SHA:         fields.Bytes(5),
			LinkTarget:  fields.String(7),
		}
		for _, rawChunk := range fields.Messages(6) {
			chunkFields, err := protocol.ParseFields(rawChunk)
			if err != nil {
				return nil, err
			}
			file.Chunks = append(file.Chunks, ManifestChunk{
				SHA:            chunkFields.Bytes(1),
				CRC:            uint32(chunkFields.Uint(2)),
				Offset:         chunkFields.Uint(3),
				OriginalSize:   chunkFields.Uint(4),
				CompressedSize: chunkFields.Uint(5),
			})
		}
		manifest.Files = append(manifest.Files, file)
	}
	if depotKey != nil && manifest.FilenamesEncrypted {
		if len(depotKey) != 32 {
			return nil, fmt.Errorf("depot key must be 32 bytes")
		}
		for index := range manifest.Files {
			name, err := decryptManifestName(manifest.Files[index].FileName, depotKey)
			if err != nil {
				return nil, err
			}
			link := ""
			if manifest.Files[index].LinkTarget != "" {
				link, err = decryptManifestName(manifest.Files[index].LinkTarget, depotKey)
				if err != nil {
					return nil, err
				}
			}
			manifest.Files[index].FileName = name
			manifest.Files[index].LinkTarget = link
		}
		manifest.FilenamesEncrypted = false
		sort.Slice(manifest.Files, func(i, j int) bool {
			return strings.ToLower(manifest.Files[i].FileName) < strings.ToLower(manifest.Files[j].FileName)
		})
	}
	return manifest, nil
}

func decryptManifestName(encoded string, key []byte) (string, error) {
	cipherText, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return "", fmt.Errorf("decode encrypted manifest filename: %w", err)
	}
	if len(cipherText) < 32 || len(cipherText)%16 != 0 {
		return "", fmt.Errorf("invalid encrypted manifest filename")
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	iv := make([]byte, aes.BlockSize)
	block.Decrypt(iv, cipherText[:aes.BlockSize])
	clear := make([]byte, len(cipherText)-aes.BlockSize)
	cipher.NewCBCDecrypter(block, iv).CryptBlocks(clear, cipherText[aes.BlockSize:])
	clear, err = unpadPKCS7(clear, aes.BlockSize)
	if err != nil {
		return "", fmt.Errorf("decrypt manifest filename: %w", err)
	}
	if len(clear) > 0 && clear[len(clear)-1] == 0 {
		clear = clear[:len(clear)-1]
	}
	return strings.ReplaceAll(string(clear), `\`, "/"), nil
}

func unpadPKCS7(value []byte, blockSize int) ([]byte, error) {
	if len(value) == 0 || len(value)%blockSize != 0 {
		return nil, fmt.Errorf("invalid PKCS7 data")
	}
	padding := int(value[len(value)-1])
	if padding == 0 || padding > blockSize || padding > len(value) {
		return nil, fmt.Errorf("invalid PKCS7 padding")
	}
	for _, b := range value[len(value)-padding:] {
		if int(b) != padding {
			return nil, fmt.Errorf("invalid PKCS7 padding")
		}
	}
	return value[:len(value)-padding], nil
}

func ManifestFileName(path string) string {
	return filepath.Base(strings.ReplaceAll(path, `\`, "/"))
}
