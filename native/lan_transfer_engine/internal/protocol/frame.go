package protocol

import (
	"encoding/binary"
	"fmt"
	"hash/crc32"
	"io"
	"sync"
)

const (
	LANProtocol  = "flsteamlua-lan/5"
	FrameMagic   = 0x54534c46 // "FLST" little-endian.
	FrameVersion = 5
	HeaderSize   = 24
	MaxPayload   = 16 * 1024 * 1024
)

const (
	FrameHello uint16 = iota + 1
	FrameOffer
	FrameDecision
	FramePlanStart
	FramePlanFiles
	FramePlanChunks
	FramePlanEnd
	FramePlanReady
	FrameChunkData
	FrameChunkAck
	FrameCredit
	FrameFinish
	FrameFinishResult
	FrameCancel
	FrameError
	FrameProgress
)

var castagnoli = crc32.MakeTable(crc32.Castagnoli)

const coalescedPayloadLimit = 64 * 1024

type frameWriteBuffer [HeaderSize + 4 + coalescedPayloadLimit]byte

var frameWriteBuffers = sync.Pool{New: func() any { return new(frameWriteBuffer) }}

type Frame struct {
	Type     uint16
	Flags    uint32
	StreamID uint32
	Payload  []byte
}

func WriteFrame(writer io.Writer, frame Frame) error {
	if len(frame.Payload) > MaxPayload {
		return fmt.Errorf("frame payload exceeds %d bytes", MaxPayload)
	}
	checksum := crc32.Checksum(frame.Payload, castagnoli)
	if len(frame.Payload) <= coalescedPayloadLimit {
		buffer := frameWriteBuffers.Get().(*frameWriteBuffer)
		defer frameWriteBuffers.Put(buffer)
		packet := buffer[:HeaderSize+len(frame.Payload)]
		encodeFrameHeader(packet, frame.Type, frame.Flags, frame.StreamID, len(frame.Payload), checksum)
		copy(packet[HeaderSize:], frame.Payload)
		return writeBytes(writer, packet)
	}
	var header [HeaderSize]byte
	encodeFrameHeader(header[:], frame.Type, frame.Flags, frame.StreamID, len(frame.Payload), checksum)
	if err := writeBytes(writer, header[:]); err != nil {
		return err
	}
	return writeBytes(writer, frame.Payload)
}

func WriteChunkFrame(writer io.Writer, index uint32, data []byte) error {
	size := 4 + len(data)
	if size > MaxPayload {
		return fmt.Errorf("chunk frame exceeds payload limit")
	}
	if len(data) <= coalescedPayloadLimit {
		buffer := frameWriteBuffers.Get().(*frameWriteBuffer)
		defer frameWriteBuffers.Put(buffer)
		packet := buffer[:HeaderSize+size]
		encodeChunkHeader(packet, index, data)
		copy(packet[HeaderSize+4:], data)
		return writeBytes(writer, packet)
	}
	// Keep large payloads in their existing buffer; only combine the header and index.
	var header [HeaderSize + 4]byte
	encodeChunkHeader(header[:], index, data)
	if err := writeBytes(writer, header[:]); err != nil {
		return err
	}
	return writeBytes(writer, data)
}

func encodeFrameHeader(header []byte, frameType uint16, flags, streamID uint32, size int, checksum uint32) {
	binary.LittleEndian.PutUint32(header[0:4], FrameMagic)
	binary.LittleEndian.PutUint16(header[4:6], FrameVersion)
	binary.LittleEndian.PutUint16(header[6:8], frameType)
	binary.LittleEndian.PutUint32(header[8:12], flags)
	binary.LittleEndian.PutUint32(header[12:16], streamID)
	binary.LittleEndian.PutUint32(header[16:20], uint32(size))
	binary.LittleEndian.PutUint32(header[20:24], checksum)
}

func encodeChunkHeader(header []byte, index uint32, data []byte) {
	binary.LittleEndian.PutUint32(header[HeaderSize:HeaderSize+4], index)
	checksum := crc32.Update(0, castagnoli, header[HeaderSize:HeaderSize+4])
	checksum = crc32.Update(checksum, castagnoli, data)
	encodeFrameHeader(header, FrameChunkData, 0, 0, 4+len(data), checksum)
}

func writeBytes(writer io.Writer, data []byte) error {
	written, err := writer.Write(data)
	if err == nil && written != len(data) {
		return io.ErrShortWrite
	}
	return err
}

func ReadFrame(reader io.Reader) (Frame, error) {
	header := make([]byte, HeaderSize)
	if _, err := io.ReadFull(reader, header); err != nil {
		return Frame{}, err
	}
	if binary.LittleEndian.Uint32(header[0:4]) != FrameMagic {
		return Frame{}, fmt.Errorf("invalid frame magic")
	}
	if version := binary.LittleEndian.Uint16(header[4:6]); version != FrameVersion {
		return Frame{}, fmt.Errorf("unsupported frame version %d", version)
	}
	size := binary.LittleEndian.Uint32(header[16:20])
	if size > MaxPayload {
		return Frame{}, fmt.Errorf("frame payload exceeds limit")
	}
	payload := make([]byte, size)
	if _, err := io.ReadFull(reader, payload); err != nil {
		return Frame{}, err
	}
	if expected := binary.LittleEndian.Uint32(header[20:24]); crc32.Checksum(payload, castagnoli) != expected {
		return Frame{}, fmt.Errorf("frame checksum mismatch")
	}
	return Frame{
		Type:     binary.LittleEndian.Uint16(header[6:8]),
		Flags:    binary.LittleEndian.Uint32(header[8:12]),
		StreamID: binary.LittleEndian.Uint32(header[12:16]),
		Payload:  payload,
	}, nil
}
