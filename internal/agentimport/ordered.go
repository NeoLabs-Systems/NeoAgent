package agentimport

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"regexp"
	"strconv"
	"strings"
	"unicode"
	"unicode/utf16"
	"unicode/utf8"

	"go.yaml.in/yaml/v3"
)

// Obj is a decoded JSON or YAML object that remembers key order, the way a
// JavaScript object does (integer-like keys first, ascending, then the rest in
// insertion order). The importers walk source configs in that order, so the
// order of servers, agents and jobs they produce stays the same.
type Obj struct {
	keys []string
	vals map[string]any
}

func newObj() *Obj { return &Obj{vals: map[string]any{}} }

func (o *Obj) set(key string, v any) {
	if _, ok := o.vals[key]; !ok {
		o.keys = append(o.keys, key)
	}
	o.vals[key] = v
}

var arrayIndex = regexp.MustCompile(`^(0|[1-9][0-9]{0,8})$`)

// Keys lists the keys in JavaScript order.
func (o *Obj) Keys() []string {
	if o == nil {
		return nil
	}
	var ints, rest []string
	for _, k := range o.keys {
		if arrayIndex.MatchString(k) {
			ints = append(ints, k)
		} else {
			rest = append(rest, k)
		}
	}
	sortIndexKeys(ints)
	return append(ints, rest...)
}

func sortIndexKeys(keys []string) {
	for i := 1; i < len(keys); i++ {
		for j := i; j > 0; j-- {
			a, _ := strconv.Atoi(keys[j-1])
			b, _ := strconv.Atoi(keys[j])
			if a <= b {
				break
			}
			keys[j-1], keys[j] = keys[j], keys[j-1]
		}
	}
}

// Get returns a member, or nil. It is safe on a nil Obj, like `obj?.key`.
func (o *Obj) Get(key string) any {
	if o == nil {
		return nil
	}
	return o.vals[key]
}

// Has reports whether the key is present.
func (o *Obj) Has(key string) bool {
	if o == nil {
		return false
	}
	_, ok := o.vals[key]
	return ok
}

// asObj returns v as an object, or nil.
func asObj(v any) *Obj {
	o, _ := v.(*Obj)
	return o
}

func asList(v any) []any {
	l, _ := v.([]any)
	return l
}

// str is String(v || ”) for decoded values: nil, false, 0 and "" are empty.
func str(v any) string {
	switch t := v.(type) {
	case nil:
		return ""
	case string:
		return t
	case bool:
		if t {
			return "true"
		}
		return ""
	case float64:
		if t == 0 {
			return ""
		}
		return strconv.FormatFloat(t, 'f', -1, 64)
	}
	return fmt.Sprint(v)
}

// truthy is JavaScript truthiness for decoded values.
func truthy(v any) bool {
	switch t := v.(type) {
	case nil:
		return false
	case string:
		return t != ""
	case bool:
		return t
	case float64:
		return t != 0
	}
	return true
}

// parseJSON decodes strict JSON keeping object order.
func parseJSON(data []byte) (any, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	v, err := readValue(dec)
	if err != nil {
		return nil, err
	}
	if _, err := dec.Token(); err != io.EOF {
		return nil, fmt.Errorf("unexpected data after JSON value")
	}
	return v, nil
}

func readValue(dec *json.Decoder) (any, error) {
	tok, err := dec.Token()
	if err != nil {
		return nil, err
	}
	switch t := tok.(type) {
	case json.Delim:
		if t == '{' {
			o := newObj()
			for dec.More() {
				kt, err := dec.Token()
				if err != nil {
					return nil, err
				}
				v, err := readValue(dec)
				if err != nil {
					return nil, err
				}
				o.set(kt.(string), v)
			}
			if _, err := dec.Token(); err != nil {
				return nil, err
			}
			return o, nil
		}
		list := []any{}
		for dec.More() {
			v, err := readValue(dec)
			if err != nil {
				return nil, err
			}
			list = append(list, v)
		}
		if _, err := dec.Token(); err != nil {
			return nil, err
		}
		return list, nil
	case json.Number:
		f, _ := t.Float64()
		return f, nil
	}
	return tok, nil
}

// parseYAML decodes YAML keeping mapping order.
func parseYAML(text string) (any, error) {
	var doc yaml.Node
	if err := yaml.Unmarshal([]byte(text), &doc); err != nil {
		return nil, err
	}
	if doc.Kind == 0 {
		return nil, nil
	}
	return fromYAML(&doc)
}

func fromYAML(n *yaml.Node) (any, error) {
	switch n.Kind {
	case yaml.DocumentNode:
		if len(n.Content) == 0 {
			return nil, nil
		}
		return fromYAML(n.Content[0])
	case yaml.AliasNode:
		return fromYAML(n.Alias)
	case yaml.MappingNode:
		o := newObj()
		for i := 0; i+1 < len(n.Content); i += 2 {
			v, err := fromYAML(n.Content[i+1])
			if err != nil {
				return nil, err
			}
			o.set(n.Content[i].Value, v)
		}
		return o, nil
	case yaml.SequenceNode:
		list := []any{}
		for _, c := range n.Content {
			v, err := fromYAML(c)
			if err != nil {
				return nil, err
			}
			list = append(list, v)
		}
		return list, nil
	}
	switch n.ShortTag() {
	case "!!null":
		return nil, nil
	case "!!bool":
		var b bool
		if err := n.Decode(&b); err == nil {
			return b, nil
		}
	case "!!int", "!!float":
		var f float64
		if err := n.Decode(&f); err == nil {
			return f, nil
		}
	}
	return n.Value, nil
}

// ---- JavaScript string helpers ----------------------------------------------

// ws is the class JavaScript's \s matches.
const ws = `[\t\n\v\f\r \x{00A0}\x{1680}\x{2000}-\x{200A}\x{2028}\x{2029}\x{202F}\x{205F}\x{3000}\x{FEFF}]`

func isJSSpace(r rune) bool {
	return unicode.IsSpace(r) || r == 0xFEFF
}

// trim is String.prototype.trim.
func trim(s string) string { return strings.TrimFunc(s, isJSSpace) }

// jsLen is String.prototype.length (UTF-16 code units).
func jsLen(s string) int {
	n := 0
	for _, r := range s {
		n += utf16.RuneLen(r)
		if r == utf8.RuneError {
			n = n - utf16.RuneLen(r) + 1
		}
	}
	return n
}

// jsSlice is s.slice(0, n) cut at a character boundary.
func jsSlice(s string, n int) string {
	units := 0
	for i, r := range s {
		w := 1
		if r >= 0x10000 {
			w = 2
		}
		if units+w > n {
			return s[:i]
		}
		units += w
	}
	return s
}

func readText(path string) (string, bool) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return "", false
	}
	text := strings.TrimPrefix(string(raw), "\ufeff")
	text = strings.ReplaceAll(text, "\r\n", "\n")
	return strings.ReplaceAll(text, "\r", "\n"), true
}

func isDir(path string) bool {
	st, err := os.Stat(path)
	return err == nil && st.IsDir()
}

func isFile(path string) bool {
	st, err := os.Stat(path)
	return err == nil && st.Mode().IsRegular()
}

// parseNumber is Number(text) for a trimmed string; ok is false for NaN.
func parseNumber(text string) (float64, bool) {
	if text == "" {
		return 0, true
	}
	f, err := strconv.ParseFloat(text, 64)
	if err != nil || strings.ContainsAny(text, "_xXpPiInN") {
		return 0, false
	}
	return f, true
}
