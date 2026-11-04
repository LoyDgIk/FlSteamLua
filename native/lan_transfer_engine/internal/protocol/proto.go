package protocol

import (
	"encoding/binary"
	"fmt"
)

type PB struct {
	b []byte
}

func (p *PB) Uint(field int, value uint64) {
	p.tag(field, 0)
	p.b = binary.AppendUvarint(p.b, value)
}

func (p *PB) Bool(field int, value bool) {
	if value {
		p.Uint(field, 1)
	} else {
		p.Uint(field, 0)
	}
}

func (p *PB) Bytes(field int, value []byte) {
	p.tag(field, 2)
	p.b = binary.AppendUvarint(p.b, uint64(len(value)))
	p.b = append(p.b, value...)
}

func (p *PB) String(field int, value string) {
	p.Bytes(field, []byte(value))
}

func (p *PB) Message(field int, value []byte) {
	p.Bytes(field, value)
}

func (p *PB) Fixed32(field int, value uint32) {
	p.tag(field, 5)
	p.b = binary.LittleEndian.AppendUint32(p.b, value)
}

func (p *PB) tag(field, wire int) {
	p.b = binary.AppendUvarint(p.b, uint64(field<<3|wire))
}

func (p *PB) Result() []byte {
	return p.b
}

type Field struct {
	Number int
	Wire   int
	Uint   uint64
	Bytes  []byte
}

type Fields struct {
	values map[int][]Field
}

func ParseFields(data []byte) (Fields, error) {
	result := Fields{values: make(map[int][]Field)}
	for offset := 0; offset < len(data); {
		tag, n := binary.Uvarint(data[offset:])
		if n <= 0 {
			return Fields{}, fmt.Errorf("invalid protobuf tag")
		}
		offset += n
		number, wire := int(tag>>3), int(tag&7)
		if number <= 0 {
			return Fields{}, fmt.Errorf("invalid protobuf field number")
		}
		field := Field{Number: number, Wire: wire}
		switch wire {
		case 0:
			value, size := binary.Uvarint(data[offset:])
			if size <= 0 {
				return Fields{}, fmt.Errorf("invalid protobuf varint")
			}
			offset += size
			field.Uint = value
		case 1:
			if len(data)-offset < 8 {
				return Fields{}, fmt.Errorf("truncated fixed64 field")
			}
			field.Bytes = append([]byte(nil), data[offset:offset+8]...)
			offset += 8
		case 2:
			size, n := binary.Uvarint(data[offset:])
			if n <= 0 {
				return Fields{}, fmt.Errorf("invalid protobuf length")
			}
			offset += n
			if size > uint64(len(data)-offset) {
				return Fields{}, fmt.Errorf("truncated protobuf bytes")
			}
			field.Bytes = append([]byte(nil), data[offset:offset+int(size)]...)
			offset += int(size)
		case 5:
			if len(data)-offset < 4 {
				return Fields{}, fmt.Errorf("truncated fixed32 field")
			}
			field.Uint = uint64(binary.LittleEndian.Uint32(data[offset : offset+4]))
			offset += 4
		default:
			return Fields{}, fmt.Errorf("unsupported protobuf wire type %d", wire)
		}
		result.values[number] = append(result.values[number], field)
	}
	return result, nil
}

func (f Fields) Last(field int) (Field, bool) {
	values := f.values[field]
	if len(values) == 0 {
		return Field{}, false
	}
	return values[len(values)-1], true
}

func (f Fields) Uint(field int) uint64 {
	value, ok := f.Last(field)
	if !ok || value.Wire != 0 {
		return 0
	}
	return value.Uint
}

func (f Fields) Bool(field int) bool {
	return f.Uint(field) != 0
}

func (f Fields) Bytes(field int) []byte {
	value, ok := f.Last(field)
	if !ok || value.Wire != 2 {
		return nil
	}
	return value.Bytes
}

func (f Fields) String(field int) string {
	return string(f.Bytes(field))
}

func (f Fields) Messages(field int) [][]byte {
	values := f.values[field]
	result := make([][]byte, 0, len(values))
	for _, value := range values {
		if value.Wire == 2 {
			result = append(result, value.Bytes)
		}
	}
	return result
}
