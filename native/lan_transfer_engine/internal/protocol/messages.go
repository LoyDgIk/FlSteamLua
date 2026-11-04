package protocol

import "fmt"

type Hello struct {
	Protocol    string
	Alias       string
	Fingerprint string
	Receiving   bool
}

func EncodeHello(value Hello) []byte {
	var p PB
	p.String(1, value.Protocol)
	p.String(2, value.Alias)
	p.String(3, value.Fingerprint)
	p.Bool(4, value.Receiving)
	return p.Result()
}

func DecodeHello(data []byte) (Hello, error) {
	f, err := ParseFields(data)
	if err != nil {
		return Hello{}, err
	}
	return Hello{
		Protocol:    f.String(1),
		Alias:       f.String(2),
		Fingerprint: f.String(3),
		Receiving:   f.Bool(4),
	}, nil
}

type Decision struct {
	Accepted      bool
	TargetLibrary string
	LuaRoot       string
	Remember      bool
	Message       string
}

func EncodeDecision(value Decision) []byte {
	var p PB
	p.Bool(1, value.Accepted)
	p.String(2, value.TargetLibrary)
	p.String(3, value.LuaRoot)
	p.Bool(4, value.Remember)
	p.String(5, value.Message)
	return p.Result()
}

func DecodeDecision(data []byte) (Decision, error) {
	f, err := ParseFields(data)
	if err != nil {
		return Decision{}, err
	}
	return Decision{
		Accepted:      f.Bool(1),
		TargetLibrary: f.String(2),
		LuaRoot:       f.String(3),
		Remember:      f.Bool(4),
		Message:       f.String(5),
	}, nil
}

type PlanReady struct {
	Window        uint32
	Bitmap        []byte
	PresentChunks uint64
}

func EncodePlanReady(value PlanReady) []byte {
	var p PB
	p.Uint(1, uint64(value.Window))
	p.Bytes(2, value.Bitmap)
	p.Uint(3, value.PresentChunks)
	return p.Result()
}

func DecodePlanReady(data []byte) (PlanReady, error) {
	f, err := ParseFields(data)
	if err != nil {
		return PlanReady{}, err
	}
	window := f.Uint(1)
	if window == 0 || window > 64 {
		window = 16
	}
	return PlanReady{
		Window:        uint32(window),
		Bitmap:        f.Bytes(2),
		PresentChunks: f.Uint(3),
	}, nil
}

type ChunkAck struct {
	Index   uint32
	OK      bool
	Message string
}

func EncodeChunkAck(value ChunkAck) []byte {
	var p PB
	p.Uint(1, uint64(value.Index))
	p.Bool(2, value.OK)
	p.String(3, value.Message)
	return p.Result()
}

func DecodeChunkAck(data []byte) (ChunkAck, error) {
	f, err := ParseFields(data)
	if err != nil {
		return ChunkAck{}, err
	}
	index := f.Uint(1)
	if index > uint64(^uint32(0)) {
		return ChunkAck{}, fmt.Errorf("invalid chunk index")
	}
	return ChunkAck{
		Index:   uint32(index),
		OK:      f.Bool(2),
		Message: f.String(3),
	}, nil
}

type Finish struct {
	Status  string
	Message string
}

func EncodeFinish(value Finish) []byte {
	var p PB
	p.String(1, value.Status)
	p.String(2, value.Message)
	return p.Result()
}

func DecodeFinish(data []byte) (Finish, error) {
	f, err := ParseFields(data)
	if err != nil {
		return Finish{}, err
	}
	return Finish{Status: f.String(1), Message: f.String(2)}, nil
}

func EncodeError(message string) []byte {
	var p PB
	p.String(1, message)
	return p.Result()
}

func DecodeError(data []byte) string {
	f, err := ParseFields(data)
	if err != nil {
		return "Unknown peer error"
	}
	return f.String(1)
}

type Credit struct {
	Frames uint32
	Bytes  uint64
}

func EncodeCredit(value Credit) []byte {
	var p PB
	p.Uint(1, uint64(value.Frames))
	p.Uint(2, value.Bytes)
	return p.Result()
}

func DecodeCredit(data []byte) (Credit, error) {
	f, err := ParseFields(data)
	if err != nil {
		return Credit{}, err
	}
	return Credit{Frames: uint32(f.Uint(1)), Bytes: f.Uint(2)}, nil
}
