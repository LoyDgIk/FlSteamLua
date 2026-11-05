package protocol

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"
	"hash/crc32"
	"io"
	"testing"
)

type recordingWriter struct {
	bytes.Buffer
	writes int
}

func (w *recordingWriter) Write(data []byte) (int, error) {
	w.writes++
	return w.Buffer.Write(data)
}

func TestChunkFrameCoalescesWritesWithoutChangingWireFormat(t *testing.T) {
	for _, size := range []int{0, 4096, 64 * 1024, 64*1024 + 1, 4 * 1024 * 1024} {
		t.Run(fmt.Sprint(size), func(t *testing.T) {
			const index = 0x12345678
			data := bytes.Repeat([]byte{0x91}, size)
			var output recordingWriter
			if err := WriteChunkFrame(&output, index, data); err != nil {
				t.Fatal(err)
			}
			wantWrites := 1
			if size > 64*1024 {
				wantWrites = 2
			}
			if output.writes != wantWrites {
				t.Fatalf("writes=%d, want %d", output.writes, wantWrites)
			}
			payload := EncodeChunkData(index, data)
			want := referenceFrame(Frame{Type: FrameChunkData, Payload: payload})
			if !bytes.Equal(output.Bytes(), want) {
				t.Fatal("chunk frame wire format changed")
			}
			decoded, err := ReadFrame(&output)
			if err != nil {
				t.Fatal(err)
			}
			gotIndex, gotData, err := DecodeChunkData(decoded.Payload)
			if err != nil || gotIndex != index || !bytes.Equal(gotData, data) {
				t.Fatalf("chunk round trip failed: index=%d, error=%v", gotIndex, err)
			}
		})
	}
}

func TestFrameCoalescesSmallPayload(t *testing.T) {
	for _, size := range []int{0, 1, 64 * 1024, 64*1024 + 1} {
		t.Run(fmt.Sprint(size), func(t *testing.T) {
			frame := Frame{Type: FramePlanFiles, Flags: 17, StreamID: 42, Payload: bytes.Repeat([]byte{0xa7}, size)}
			var output recordingWriter
			if err := WriteFrame(&output, frame); err != nil {
				t.Fatal(err)
			}
			wantWrites := 1
			if size > 64*1024 {
				wantWrites = 2
			}
			if output.writes != wantWrites {
				t.Fatalf("writes=%d, want %d", output.writes, wantWrites)
			}
			if !bytes.Equal(output.Bytes(), referenceFrame(frame)) {
				t.Fatal("frame wire format changed")
			}
		})
	}
}

type writerFunc func([]byte) (int, error)

func (f writerFunc) Write(data []byte) (int, error) { return f(data) }

func TestFrameReportsWriteFailures(t *testing.T) {
	for _, size := range []int{4, 64*1024 + 1} {
		for _, chunk := range []bool{false, true} {
			t.Run(fmt.Sprintf("size=%d/chunk=%v", size, chunk), func(t *testing.T) {
				payload := bytes.Repeat([]byte{1}, size)
				write := func(writer io.Writer) error {
					if chunk {
						return WriteChunkFrame(writer, 7, payload)
					}
					return WriteFrame(writer, Frame{Type: FramePlanFiles, Payload: payload})
				}
				if err := write(writerFunc(func(data []byte) (int, error) {
					return len(data) - 1, nil
				})); !errors.Is(err, io.ErrShortWrite) {
					t.Fatalf("short write error=%v, want %v", err, io.ErrShortWrite)
				}
				if err := write(writerFunc(func([]byte) (int, error) {
					return 0, io.ErrClosedPipe
				})); !errors.Is(err, io.ErrClosedPipe) {
					t.Fatalf("write error=%v, want %v", err, io.ErrClosedPipe)
				}
			})
		}
	}
}

func referenceFrame(frame Frame) []byte {
	packet := make([]byte, HeaderSize+len(frame.Payload))
	binary.LittleEndian.PutUint32(packet[0:4], FrameMagic)
	binary.LittleEndian.PutUint16(packet[4:6], FrameVersion)
	binary.LittleEndian.PutUint16(packet[6:8], frame.Type)
	binary.LittleEndian.PutUint32(packet[8:12], frame.Flags)
	binary.LittleEndian.PutUint32(packet[12:16], frame.StreamID)
	binary.LittleEndian.PutUint32(packet[16:20], uint32(len(frame.Payload)))
	binary.LittleEndian.PutUint32(packet[20:24], crc32.Checksum(frame.Payload, castagnoli))
	copy(packet[HeaderSize:], frame.Payload)
	return packet
}
