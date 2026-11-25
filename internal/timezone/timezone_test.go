package timezone

import (
	"encoding/json"
	"os"
	"testing"
)

// testdata/vectors.json holds what Node's Intl.DateTimeFormat answered for
// every zone name, its upper and lower case forms, and malformed and offset
// inputs (regenerate with gen/zones.js).
func TestNormalizeMatchesNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors []struct {
		Input     string  `json:"input"`
		Canonical *string `json:"canonical"`
	}
	if err := json.Unmarshal(raw, &vectors); err != nil {
		t.Fatal(err)
	}
	if len(vectors) < 1000 {
		t.Fatalf("only %d vectors", len(vectors))
	}
	for _, v := range vectors {
		got, ok := Normalize(v.Input)
		switch {
		case v.Canonical == nil && ok:
			t.Errorf("Normalize(%q) = %q, Node rejects it", v.Input, got)
		case v.Canonical != nil && (!ok || got != *v.Canonical):
			t.Errorf("Normalize(%q) = %q,%v, Node says %q", v.Input, got, ok, *v.Canonical)
		}
	}
}
