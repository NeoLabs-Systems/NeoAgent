package codenav

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// TestStructureMatchesOxc compares the scanner with what oxc-parser found in
// the same files (structure.json, recorded from Node).
func TestStructureMatchesOxc(t *testing.T) {
	raw, err := os.ReadFile("testdata/structure.json")
	if err != nil {
		t.Fatal(err)
	}
	var want map[string]struct {
		ParseErrors []string `json:"parseErrors"`
		Symbols     []Symbol `json:"symbols"`
	}
	if err := json.Unmarshal(raw, &want); err != nil {
		t.Fatal(err)
	}
	for file, w := range want {
		src, err := os.ReadFile(filepath.Join("testdata/src", file))
		if err != nil {
			t.Fatal(err)
		}
		got, errs := Structure(string(src))
		if len(errs) != len(w.ParseErrors) {
			t.Errorf("%s errors %v, want %v", file, errs, w.ParseErrors)
		}
		g, _ := json.MarshalIndent(got, "", " ")
		e, _ := json.MarshalIndent(w.Symbols, "", " ")
		if string(g) != string(e) {
			t.Errorf("%s:\n got: %s\nwant: %s", file, g, e)
		}
	}
}
