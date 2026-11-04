package instance

import (
	"fmt"
	"os"
	"path/filepath"
	"syscall"
)

type Lock struct {
	handle syscall.Handle
}

func Acquire(dataDir string) (*Lock, error) {
	if err := os.MkdirAll(dataDir, 0o700); err != nil {
		return nil, err
	}
	path, err := syscall.UTF16PtrFromString(filepath.Join(dataDir, "engine.lock"))
	if err != nil {
		return nil, err
	}
	handle, err := syscall.CreateFile(
		path,
		syscall.GENERIC_READ|syscall.GENERIC_WRITE,
		0,
		nil,
		syscall.OPEN_ALWAYS,
		syscall.FILE_ATTRIBUTE_NORMAL,
		0,
	)
	if err != nil {
		return nil, fmt.Errorf("another LAN transfer engine is already running: %w", err)
	}
	return &Lock{handle: handle}, nil
}

func (l *Lock) Close() {
	if l != nil && l.handle != 0 {
		_ = syscall.CloseHandle(l.handle)
		l.handle = 0
	}
}
