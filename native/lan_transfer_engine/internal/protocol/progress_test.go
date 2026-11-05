package protocol

import (
	"bytes"
	"fmt"
	"math"
	"testing"
)

func TestProgressFrameRoundTrip(t *testing.T) {
	value := Progress{
		Status: "committing", DiskBytes: 12 << 30, DiskSpeed: 123456789.6,
		InstalledBytes: 8 << 30, InstalledFiles: 1200, TotalFiles: 2000,
	}
	var wire bytes.Buffer
	if err := WriteFrame(&wire, Frame{Type: FrameProgress, Payload: EncodeProgress(value)}); err != nil {
		t.Fatal(err)
	}
	frame, err := ReadFrame(&wire)
	if err != nil {
		t.Fatal(err)
	}
	if frame.Type != FrameProgress || FrameError != 15 || FrameProgress != 16 {
		t.Fatal("existing frame types changed")
	}
	got, err := DecodeProgress(frame.Payload)
	if err != nil {
		t.Fatal(err)
	}
	value.DiskSpeed = math.Round(value.DiskSpeed)
	if got != value {
		t.Fatalf("progress mismatch: got %+v, want %+v", got, value)
	}
}

func TestProgressRejectsUnsignedOverflow(t *testing.T) {
	for field := 2; field <= 6; field++ {
		t.Run(fmt.Sprint(field), func(t *testing.T) {
			var p PB
			p.Uint(field, uint64(math.MaxInt64)+1)
			if _, err := DecodeProgress(p.Result()); err == nil {
				t.Fatal("accepted a progress value beyond int64")
			}
		})
	}
}

func TestProgressRejectsNegativeCounts(t *testing.T) {
	for name, value := range map[string]Progress{
		"disk bytes":      {DiskBytes: -1},
		"disk speed":      {DiskSpeed: -1},
		"installed bytes": {InstalledBytes: -1},
		"installed files": {InstalledFiles: -1},
		"total files":     {TotalFiles: -1},
	} {
		t.Run(name, func(t *testing.T) {
			if _, err := DecodeProgress(EncodeProgress(value)); err == nil {
				t.Fatal("accepted negative progress")
			}
		})
	}
}

func TestProgressRejectsWrongWireTypes(t *testing.T) {
	for field := 1; field <= 6; field++ {
		t.Run(fmt.Sprint(field), func(t *testing.T) {
			var p PB
			if field == 1 {
				p.Uint(field, 1)
			} else {
				p.String(field, "1")
			}
			if _, err := DecodeProgress(p.Result()); err == nil {
				t.Fatal("accepted progress with an invalid wire type")
			}
		})
	}
}
