package sockets

import (
	"encoding/hex"
	"encoding/json"
	"os"
	"testing"
)

// The vectors are computed by the Node helpers themselves (gen/jsvalues.js).
type jsVectors struct {
	OptionalString []struct {
		Value any    `json:"value"`
		Max   int    `json:"max"`
		Want  string `json:"want"`
	} `json:"optionalString"`
	BoundedInt []struct {
		Present bool `json:"present"`
		Value   any  `json:"value"`
		Want    int  `json:"want"`
	} `json:"boundedInt"`
	Base64 []struct {
		Text string `json:"text"`
		Want string `json:"want"`
	} `json:"base64"`
}

func loadJSVectors(t *testing.T) jsVectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/jsvalues.json")
	if err != nil {
		t.Fatal(err)
	}
	var v jsVectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func TestOptionalStringMatchesNode(t *testing.T) {
	for _, c := range loadJSVectors(t).OptionalString {
		if got := optionalString(c.Value, c.Max); got != c.Want {
			t.Errorf("optionalString(%#v, %d) = %q, Node says %q", c.Value, c.Max, got, c.Want)
		}
	}
}

func TestBoundedIntMatchesNode(t *testing.T) {
	for _, c := range loadJSVectors(t).BoundedInt {
		obj := map[string]any{}
		if c.Present {
			obj["limit"] = c.Value
		}
		if got := boundedInt(obj, "limit", 20, 1, 100); got != c.Want {
			t.Errorf("boundedInt(%#v, present=%v) = %d, Node says %d", c.Value, c.Present, got, c.Want)
		}
	}
}

func TestDecodeBase64MatchesNodeBuffer(t *testing.T) {
	for _, c := range loadJSVectors(t).Base64 {
		if got := hex.EncodeToString(decodeBase64(c.Text)); got != c.Want {
			t.Errorf("decodeBase64(%q) = %s, Node says %s", c.Text, got, c.Want)
		}
	}
}

func TestFirstTruthyFollowsJavaScriptOr(t *testing.T) {
	for _, tc := range []struct {
		in   []any
		want string
	}{
		{[]any{nil, "", 0.0, false, "x"}, "x"},
		{[]any{"a", "b"}, "a"},
		{[]any{0.0, 7.0}, "7"},
		{[]any{true}, "true"},
		{[]any{map[string]any{}}, "[object Object]"},
		{[]any{nil, nil}, ""},
	} {
		if got := firstTruthy(tc.in...); got != tc.want {
			t.Errorf("%v: %q want %q", tc.in, got, tc.want)
		}
	}
}
