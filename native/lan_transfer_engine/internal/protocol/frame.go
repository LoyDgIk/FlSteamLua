package protocol

import (
	"encoding/binary"
	"fmt"
	"hash/crc32"
	"io"
)

const (
	LANProtocol  = "flsteamlua-lan/4"
	FrameMagic   = 0x54534c46 // "FLST" little-endian.
	FrameVersion = 4
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
)

var castagnoli = crc32.MakeTable(crc32.Castagnoli)

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
	header := make([]byte, HeaderSize)
	binary.LittleEndian.PutUint32(header[0:4], FrameMagic)
	binary.LittleEndian.PutUint16(header[4:6], FrameVersion)
	binary.LittleEndian.PutUint16(header[6:8], frame.Type)
	binary.LittleEndian.PutUint32(header[8:12], frame.Flags)
	binary.LittleEndian.PutUint32(header[12:16], frame.StreamID)
	binary.LittleEndian.PutUint32(header[16:20], uint32(len(frame.Payload)))
	binary.LittleEndian.PutUint32(header[20:24], crc32.Checksum(frame.Payload, castagnoli))
	if _, err := writer.Write(header); err != nil {
		return err
	}
	if len(frame.Payload) == 0 {
		return nil
	}
	_, err := writer.Write(frame.Payload)
	return err
}

func WriteChunkFrame(writer io.Writer, index uint32, data []byte) error {
	size := 4 + len(data)
	if size > MaxPayload {
		return fmt.Errorf("chunk frame exceeds payload limit")
	}
	indexBytes := []byte{byte(index), byte(index >> 8), byte(index >> 16), byte(index >> 24)}
	checksum := crc32.Update(0, castagnoli, indexBytes)
	checksum = crc32.Update(checksum, castagnoli, data)
	header := make([]byte, HeaderSize)
	binary.LittleEndian.PutUint32(header[0:4], FrameMagic)
	binary.LittleEndian.PutUint16(header[4:6], FrameVersion)
	binary.LittleEndian.PutUint16(header[6:8], FrameChunkData)
	binary.LittleEndian.PutUint32(header[16:20], uint32(size))
	binary.LittleEndian.PutUint32(header[20:24], checksum)
	if _, err := writer.Write(header); err != nil {
		return err
	}
	if _, err := writer.Write(indexBytes); err != nil {
		return err
	}
	if len(data) == 0 {
		return nil
	}
	_, err := writer.Write(data)
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
