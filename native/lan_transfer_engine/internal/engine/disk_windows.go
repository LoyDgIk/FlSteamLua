package engine

import (
	"fmt"
	"path/filepath"
	"syscall"
	"unsafe"
)

var (
	kernel32Disk = syscall.NewLazyDLL("kernel32.dll")
	getDiskFree  = kernel32Disk.NewProc("GetDiskFreeSpaceExW")
)

func freeDiskBytes(path string) (uint64, error) {
	absolute, err := filepath.Abs(path)
	if err != nil {
		return 0, err
	}
	ptr, err := syscall.UTF16PtrFromString(absolute)
	if err != nil {
		return 0, err
	}
	var available, total, totalFree uint64
	result, _, callErr := getDiskFree.Call(
		uintptr(unsafe.Pointer(ptr)),
		uintptr(unsafe.Pointer(&available)),
		uintptr(unsafe.Pointer(&total)),
		uintptr(unsafe.Pointer(&totalFree)),
	)
	if result == 0 {
		return 0, fmt.Errorf("GetDiskFreeSpaceExW: %w", callErr)
	}
	return available, nil
}
