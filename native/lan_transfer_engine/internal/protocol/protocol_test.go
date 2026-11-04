package protocol

import (
	"bytes"
	"testing"
)

func TestFrameRoundTrip(t *testing.T) {
	var buffer bytes.Buffer
	original := Frame{Type: FrameChunkData, StreamID: 7, Payload: []byte("payload")}
	if err := WriteFrame(&buffer, original); err != nil {
		t.Fatal(err)
	}
	decoded, err := ReadFrame(&buffer)
	if err != nil {
		t.Fatal(err)
	}
	if decoded.Type != original.Type || decoded.StreamID != original.StreamID {
		t.Fatalf("unexpected frame: %#v", decoded)
	}
	if !bytes.Equal(decoded.Payload, original.Payload) {
		t.Fatal("payload mismatch")
	}
}

func TestOfferRoundTrip(t *testing.T) {
	value := Offer{
		SessionID: "send:1", BundleID: "bundle", AppID: 42, GameName: "Game",
		InstallDir: "Game", TotalBytes: 100, SelectedBytes: 90, FileCount: 2,
		ChunkCount: 3, LuaEnabled: true, ManifestAvailable: true,
		Warnings: []string{"warning"},
	}
	decoded, err := DecodeOffer(EncodeOffer(value))
	if err != nil {
		t.Fatal(err)
	}
	if decoded.AppID != 42 || decoded.SelectedBytes != 90 || len(decoded.Warnings) != 1 {
		t.Fatalf("unexpected offer: %#v", decoded)
	}
}
