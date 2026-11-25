package jsv

import (
	"encoding/json"
	"math"
	"os"
	"strconv"
	"testing"
	"time"
)

type vectors struct {
	Numbers []struct{ N, S string } `json:"numbers"`
	JSON    []struct {
		Text string  `json:"text"`
		Out  *string `json:"out"`
	} `json:"json"`
	Indent   []struct{ Text, Out string } `json:"indent"`
	NumberOf []struct {
		S        string `json:"s"`
		N        string `json:"n"`
		ParseInt any    `json:"parseInt"`
	} `json:"numberOf"`
	Dates []struct {
		S   string  `json:"s"`
		ISO *string `json:"iso"`
	} `json:"dates"`
}

func load(t *testing.T) vectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func TestNumberStringMatchesNode(t *testing.T) {
	for _, c := range load(t).Numbers {
		f, _ := strconv.ParseFloat(c.N, 64)
		if got := NumberString(f); got != c.S {
			t.Errorf("NumberString(%s) = %s, node says %s", c.N, got, c.S)
		}
	}
}

func TestDecodeStringifyMatchesJSONParseStringify(t *testing.T) {
	for _, c := range load(t).JSON {
		v, err := Decode([]byte(c.Text))
		switch {
		case c.Out == nil && err == nil:
			t.Errorf("%q decoded, JSON.parse refuses it", c.Text)
		case c.Out != nil && err != nil:
			t.Errorf("%q: %v", c.Text, err)
		case c.Out != nil && Stringify(v) != *c.Out:
			t.Errorf("%q: got %s want %s", c.Text, Stringify(v), *c.Out)
		}
	}
}

func TestNumberAndParseIntMatchNode(t *testing.T) {
	for _, c := range load(t).NumberOf {
		got := Number(c.S)
		gotText := "NaN"
		if !math.IsNaN(got) {
			gotText = NumberString(got)
		}
		if gotText != c.N {
			t.Errorf("Number(%q) = %s, node says %s", c.S, gotText, c.N)
		}
		n, ok := ParseInt(c.S)
		switch want := c.ParseInt.(type) {
		case string:
			if ok {
				t.Errorf("ParseInt(%q) = %d, node says NaN", c.S, n)
			}
		case float64:
			if !ok || n != int(want) {
				t.Errorf("ParseInt(%q) = %d,%v want %v", c.S, n, ok, want)
			}
		}
	}
}

func TestParseDateMatchesNode(t *testing.T) {
	time.Local = time.UTC // the vectors were generated with TZ=UTC
	for _, c := range load(t).Dates {
		got, ok := ParseDate(c.S)
		switch {
		case c.ISO == nil && ok:
			t.Errorf("ParseDate(%q) = %s, node says invalid", c.S, ISO(got))
		case c.ISO != nil && !ok:
			t.Errorf("ParseDate(%q) invalid, node says %s", c.S, *c.ISO)
		case c.ISO != nil && ISO(got) != *c.ISO:
			t.Errorf("ParseDate(%q) = %s, node says %s", c.S, ISO(got), *c.ISO)
		}
	}
}

func TestObjectKeepsOrderAndSpreads(t *testing.T) {
	o := ParseObject(`{"b":1,"a":2}`)
	o.Set("c", 3.0).Set("b", 9.0)
	if got := Stringify(o); got != `{"b":9,"a":2,"c":3}` {
		t.Fatal(got)
	}
	merged := ParseObject(`{"x":1}`).Assign(o)
	merged.Delete("a")
	if got := Stringify(merged); got != `{"x":1,"b":9,"c":3}` {
		t.Fatal(got)
	}
}

func TestSliceCountsUTF16Units(t *testing.T) {
	if got := Slice("a😀b", 2); got != "a" {
		t.Fatalf("%q", got)
	}
	if got := Slice("a😀b", 3); got != "a😀" {
		t.Fatalf("%q", got)
	}
	if Units("a😀b") != 4 {
		t.Fatal("units")
	}
}

func TestStringifyIndentMatchesNode(t *testing.T) {
	for _, c := range load(t).Indent {
		v, err := Decode([]byte(c.Text))
		if err != nil {
			t.Fatal(err)
		}
		if got := StringifyIndent(v); got != c.Out {
			t.Errorf("%s:\n got  %q\n want %q", c.Text, got, c.Out)
		}
	}
}
