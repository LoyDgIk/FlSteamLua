package plan

import (
	"testing"
)

func TestParseVDF(t *testing.T) {
	value, err := ParseVDF(`"AppState" { "appid" "42" "InstalledDepots" { "99" { "manifest" "123" } } }`)
	if err != nil {
		t.Fatal(err)
	}
	state := MapValue(value, "AppState")
	if StringValue(state, "appid") != "42" {
		t.Fatal("appid not parsed")
	}
	depots := MapValue(state, "InstalledDepots")
	if StringValue(MapValue(depots, "99"), "manifest") != "123" {
		t.Fatal("depot manifest not parsed")
	}
}

func TestNormalizeRelativeRejectsTraversal(t *testing.T) {
	if normalizeRelative(`game\file.bin`) != "game/file.bin" {
		t.Fatal("path was not normalized")
	}
}
