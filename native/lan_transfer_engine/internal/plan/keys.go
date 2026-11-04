package plan

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"unsafe"
)

var (
	crypt32           = syscall.NewLazyDLL("crypt32.dll")
	kernel32          = syscall.NewLazyDLL("kernel32.dll")
	procUnprotectData = crypt32.NewProc("CryptUnprotectData")
	procLocalFree     = kernel32.NewProc("LocalFree")
)

type dataBlob struct {
	Size uint32
	Data *byte
}

func LoadDepotKeys(root string) (map[uint32][]byte, error) {
	keys := make(map[uint32][]byte)
	if strings.TrimSpace(root) == "" {
		return keys, nil
	}
	err := filepath.WalkDir(root, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if entry.IsDir() || entry.Name() != "keys.json.dpapi" {
			return nil
		}
		raw, err := os.ReadFile(path)
		if err != nil {
			return nil
		}
		encrypted, err := base64.StdEncoding.DecodeString(strings.TrimSpace(string(raw)))
		if err != nil {
			return nil
		}
		plain, err := unprotect(encrypted, []byte("FlSteamLua:key-cache"))
		if err != nil {
			return nil
		}
		var value struct {
			DepotKeys map[string]string `json:"depotKeys"`
		}
		if err := json.Unmarshal(plain, &value); err != nil {
			return nil
		}
		for text, keyText := range value.DepotKeys {
			id, err := strconv.ParseUint(text, 10, 32)
			if err != nil {
				continue
			}
			key, err := decodeHex(keyText)
			if err != nil || len(key) != 32 {
				continue
			}
			keys[uint32(id)] = key
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return keys, nil
}

func unprotect(data, entropy []byte) ([]byte, error) {
	if len(data) == 0 {
		return nil, fmt.Errorf("empty DPAPI payload")
	}
	input := dataBlob{Size: uint32(len(data)), Data: &data[0]}
	var entropyBlob *dataBlob
	if len(entropy) > 0 {
		value := dataBlob{Size: uint32(len(entropy)), Data: &entropy[0]}
		entropyBlob = &value
	}
	var output dataBlob
	result, _, callErr := procUnprotectData.Call(
		uintptr(unsafe.Pointer(&input)),
		0,
		uintptr(unsafe.Pointer(entropyBlob)),
		0,
		0,
		1,
		uintptr(unsafe.Pointer(&output)),
	)
	if result == 0 {
		return nil, fmt.Errorf("DPAPI decrypt failed: %v", callErr)
	}
	defer procLocalFree.Call(uintptr(unsafe.Pointer(output.Data)))
	if output.Data == nil || output.Size == 0 {
		return []byte{}, nil
	}
	return append([]byte(nil), unsafe.Slice(output.Data, output.Size)...), nil
}

func decodeHex(value string) ([]byte, error) {
	if len(value)%2 != 0 {
		return nil, fmt.Errorf("odd hex length")
	}
	result := make([]byte, len(value)/2)
	for index := 0; index < len(result); index++ {
		high, err := hexNibble(value[index*2])
		if err != nil {
			return nil, err
		}
		low, err := hexNibble(value[index*2+1])
		if err != nil {
			return nil, err
		}
		result[index] = high<<4 | low
	}
	return result, nil
}

func hexNibble(value byte) (byte, error) {
	switch {
	case value >= '0' && value <= '9':
		return value - '0', nil
	case value >= 'a' && value <= 'f':
		return value - 'a' + 10, nil
	case value >= 'A' && value <= 'F':
		return value - 'A' + 10, nil
	default:
		return 0, fmt.Errorf("invalid hex character")
	}
}
