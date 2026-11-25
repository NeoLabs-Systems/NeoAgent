package socialreach

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math"
	"regexp"
	"strconv"
	"strings"
	"unicode/utf16"
)

// The Node server worked on loosely typed JSON with JavaScript's rules
// (||, ??, String(), Number()). These helpers keep those rules for decoded
// values so the same inputs give the same answers.

const jsSpace = `\s\x{0b}\x{a0}\x{1680}\x{2000}-\x{200a}\x{2028}\x{2029}\x{202f}\x{205f}\x{3000}\x{feff}`

var spaceRun = regexp.MustCompile(`[` + jsSpace + `]+`)

func jsTrim(s string) string {
	return strings.TrimFunc(s, func(r rune) bool {
		switch r {
		case '\t', '\n', '\v', '\f', '\r', ' ', 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff:
			return true
		}
		return r >= 0x2000 && r <= 0x200a
	})
}

// decode parses JSON keeping numbers exact (json.Number).
func decode(raw []byte) (any, error) {
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	var v any
	if err := dec.Decode(&v); err != nil {
		return nil, err
	}
	return v, nil
}

// truthy is Boolean(value).
func truthy(v any) bool {
	switch v := v.(type) {
	case nil:
		return false
	case bool:
		return v
	case string:
		return v != ""
	case json.Number:
		f, err := v.Float64()
		return err != nil || (f != 0 && !math.IsNaN(f))
	}
	return true
}

// or is a || b || c: the first truthy operand, else the last.
func or(values ...any) any {
	for _, v := range values {
		if truthy(v) {
			return v
		}
	}
	return values[len(values)-1]
}

// dig follows keys (string) and indexes (int), like optional chaining.
func dig(v any, path ...any) any {
	for _, step := range path {
		switch step := step.(type) {
		case string:
			m, ok := v.(map[string]any)
			if !ok {
				return nil
			}
			v = m[step]
		case int:
			l, ok := v.([]any)
			if !ok || step >= len(l) {
				return nil
			}
			v = l[step]
		}
	}
	return v
}

// has reports whether an object carries the key (JavaScript undefined drops a
// key from JSON output, null does not).
func has(v any, key string) bool {
	m, ok := v.(map[string]any)
	if !ok {
		return false
	}
	_, found := m[key]
	return found
}

func list(v any) []any {
	l, _ := v.([]any)
	return l
}

// text is String(v) for strings, numbers and booleans.
func text(v any) string {
	switch v := v.(type) {
	case nil:
		return "null"
	case string:
		return v
	case bool:
		return strconv.FormatBool(v)
	case json.Number:
		return numberText(v)
	case []any, map[string]any:
		if _, ok := v.([]any); ok {
			parts := make([]string, 0)
			for _, item := range v.([]any) {
				if item == nil {
					parts = append(parts, "")
				} else {
					parts = append(parts, text(item))
				}
			}
			return strings.Join(parts, ",")
		}
		return "[object Object]"
	}
	return fmt.Sprint(v)
}

func numberText(n json.Number) string {
	f, err := n.Float64()
	if err != nil {
		return string(n)
	}
	if f == math.Trunc(f) && math.Abs(f) < 1e21 {
		return strconv.FormatFloat(f, 'f', -1, 64)
	}
	return strconv.FormatFloat(f, 'g', -1, 64)
}

// str is String(value || ”).
func str(v any) string {
	if !truthy(v) {
		return ""
	}
	return text(v)
}

// number is Number(value).
func number(v any) float64 {
	switch v := v.(type) {
	case nil:
		return 0
	case bool:
		if v {
			return 1
		}
		return 0
	case json.Number:
		f, _ := v.Float64()
		return f
	case string:
		s := jsTrim(v)
		if s == "" {
			return 0
		}
		f, err := strconv.ParseFloat(s, 64)
		if err != nil {
			return math.NaN()
		}
		return f
	}
	return math.NaN()
}

func normalizeLimit(v any, fallback, max int) int {
	n := number(v)
	if math.IsNaN(n) || math.IsInf(n, 0) || n <= 0 {
		return fallback
	}
	return int(math.Max(1, math.Min(math.Floor(n), float64(max))))
}

func units(s string) []uint16 { return utf16.Encode([]rune(s)) }

// compactText collapses whitespace and cuts at maxChars UTF-16 units.
func compactText(v any, maxChars int) string {
	s := jsTrim(spaceRun.ReplaceAllString(str(v), " "))
	u := units(s)
	if len(u) <= maxChars {
		return s
	}
	return jsTrim(string(utf16.Decode(u[:maxChars]))) + "..."
}

const uriSafe = "-_.!~*'()"

// encodeURIComponent escapes everything but letters, digits and -_.!~*'().
func encodeURIComponent(s string) string {
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || strings.IndexByte(uriSafe, c) >= 0 {
			b.WriteByte(c)
		} else {
			fmt.Fprintf(&b, "%%%02X", c)
		}
	}
	return b.String()
}

type field struct {
	K string
	V any
}

// obj is a JSON object that keeps the order its keys were added in, which is
// what clients saw from Node.
type obj []field

func (o obj) MarshalJSON() ([]byte, error) {
	var b bytes.Buffer
	b.WriteByte('{')
	for i, f := range o {
		if i > 0 {
			b.WriteByte(',')
		}
		k, _ := json.Marshal(f.K)
		b.Write(k)
		b.WriteByte(':')
		var v bytes.Buffer
		enc := json.NewEncoder(&v)
		enc.SetEscapeHTML(false)
		if err := enc.Encode(f.V); err != nil {
			return nil, err
		}
		b.Write(bytes.TrimRight(v.Bytes(), "\n"))
	}
	b.WriteByte('}')
	return b.Bytes(), nil
}

// set replaces a key in place or appends it, like assigning to a JS object.
func (o *obj) set(k string, v any) {
	for i := range *o {
		if (*o)[i].K == k {
			(*o)[i].V = v
			return
		}
	}
	*o = append(*o, field{k, v})
}

// orderedFromJSON turns a marshalled object back into an obj, keeping the
// order of its top-level keys.
func orderedFromJSON(raw []byte) (obj, error) {
	dec := json.NewDecoder(bytes.NewReader(raw))
	if tok, err := dec.Token(); err != nil || tok != json.Delim('{') {
		return nil, fmt.Errorf("not an object")
	}
	var o obj
	for dec.More() {
		k, err := dec.Token()
		if err != nil {
			return nil, err
		}
		var v json.RawMessage
		if err := dec.Decode(&v); err != nil {
			return nil, err
		}
		o = append(o, field{k.(string), v})
	}
	return o, nil
}
