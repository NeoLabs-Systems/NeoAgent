package textx

import "testing"

func TestSliceCountsUTF16Units(t *testing.T) {
	s := "a😀b" // the emoji is two UTF-16 units
	if Len(s) != 4 {
		t.Fatalf("Len = %d", Len(s))
	}
	cases := []struct {
		from, to int
		want     string
	}{{0, 1, "a"}, {0, 3, "a😀"}, {3, 4, "b"}, {-1, 4, "b"}, {2, 1, ""}, {0, 99, s}}
	for _, c := range cases {
		if got := Slice(s, c.from, c.to); got != c.want {
			t.Errorf("Slice(%d,%d) = %q, want %q", c.from, c.to, got, c.want)
		}
	}
}

func TestCollapseAndTrimUseJavaScriptWhitespace(t *testing.T) {
	if got := Collapse("  a \n\t b　"); got != "a b" {
		t.Errorf("Collapse = %q", got)
	}
	if got := Trim("\ufeffx "); got != "x" {
		t.Errorf("Trim = %q", got)
	}
}
