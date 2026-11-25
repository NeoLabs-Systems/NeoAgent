// Package dyn reads loosely typed JSON values the way the Node harness did.
// Tool results, tool arguments and stored run records are JSON documents whose
// shape the harness inspects defensively (result?.error, args.path || ...), so
// the helpers here keep that tolerance in one place: missing keys and wrong
// types read as "nothing" instead of failing, and truthiness, numbers and
// string conversion follow JavaScript where the prompts depend on it.
package dyn

import (
	"bytes"
	"encoding/json"
	"math"
	"sort"
	"strconv"
	"strings"
)

// Map is a decoded JSON object.
type Map = map[string]any

// Get follows keys through nested objects and returns nil when any step is
// missing or not an object.
func Get(v any, keys ...string) any {
	for _, key := range keys {
		m, ok := v.(Map)
		if !ok {
			return nil
		}
		v = m[key]
	}
	return v
}

// Truthy is JavaScript truthiness.
func Truthy(v any) bool {
	switch x := v.(type) {
	case nil:
		return false
	case bool:
		return x
	case string:
		return x != ""
	case float64:
		return x != 0 && !math.IsNaN(x)
	case int:
		return x != 0
	case int64:
		return x != 0
	}
	return true
}

// Str is String(v || ”): the value as text, and "" for anything falsy.
func Str(v any) string {
	if !Truthy(v) {
		return ""
	}
	return String(v)
}

// String is String(v): objects read "[object Object]" and arrays join their
// elements with commas, as in JavaScript.
func String(v any) string {
	switch x := v.(type) {
	case nil:
		return "null"
	case string:
		return x
	case bool:
		return strconv.FormatBool(x)
	case float64:
		return Number(x)
	case int:
		return strconv.Itoa(x)
	case int64:
		return strconv.FormatInt(x, 10)
	case []any:
		parts := make([]string, len(x))
		for i, item := range x {
			if item != nil {
				parts[i] = String(item)
			}
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}

// Number formats a number as JavaScript prints it for the values that occur
// here: integers without a fraction, otherwise the shortest round-trip form.
func Number(n float64) string {
	if n == math.Trunc(n) && math.Abs(n) < 1e21 {
		return strconv.FormatFloat(n, 'f', -1, 64)
	}
	return strconv.FormatFloat(n, 'g', -1, 64)
}

// Float reads a JSON number.
func Float(v any) (float64, bool) {
	switch x := v.(type) {
	case float64:
		return x, true
	case int:
		return float64(x), true
	case int64:
		return float64(x), true
	}
	return 0, false
}

// Int reads a JSON number as an integer.
func Int(v any) (int, bool) {
	f, ok := Float(v)
	return int(f), ok
}

// Text is the value when it is a string, else "".
func Text(v any) string {
	s, _ := v.(string)
	return s
}

// List is the value when it is an array, else nil.
func List(v any) []any {
	l, _ := v.([]any)
	return l
}

// Obj is the value when it is an object, else nil.
func Obj(v any) Map {
	m, _ := v.(Map)
	return m
}

// Stringify is JSON.stringify without whitespace: no HTML escaping, object keys
// in sorted order (Go maps carry no insertion order). Ordered values built with
// Ordered keep their order.
func Stringify(v any) string {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return ""
	}
	return string(bytes.TrimSuffix(buf.Bytes(), []byte("\n")))
}

// StringifyIndent is JSON.stringify(v, null, 2).
func StringifyIndent(v any) string {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", "  ")
	if err := enc.Encode(v); err != nil {
		return ""
	}
	return string(bytes.TrimSuffix(buf.Bytes(), []byte("\n")))
}

// KV is one member of an Ordered object.
type KV struct {
	Key   string
	Value any
}

// Ordered is a JSON object that keeps the order its members were added in.
// Model-visible envelopes use it so their layout matches what the Node harness
// produced.
type Ordered []KV

// MarshalJSON writes the members in order.
func (o Ordered) MarshalJSON() ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteByte('{')
	for i, kv := range o {
		if i > 0 {
			buf.WriteByte(',')
		}
		key, _ := marshal(kv.Key)
		buf.Write(key)
		buf.WriteByte(':')
		value, err := marshal(kv.Value)
		if err != nil {
			return nil, err
		}
		buf.Write(value)
	}
	buf.WriteByte('}')
	return buf.Bytes(), nil
}

func marshal(v any) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return nil, err
	}
	return bytes.TrimSuffix(buf.Bytes(), []byte("\n")), nil
}

// Trim drops the members that JavaScript's trimObject drops: nil and "".
func (o Ordered) Trim() Ordered {
	out := make(Ordered, 0, len(o))
	for _, kv := range o {
		if kv.Value == nil || kv.Value == "" {
			continue
		}
		out = append(out, kv)
	}
	return out
}

// Get looks a member up.
func (o Ordered) Get(key string) any {
	for _, kv := range o {
		if kv.Key == key {
			return kv.Value
		}
	}
	return nil
}

// Set replaces a member or appends it.
func (o Ordered) Set(key string, value any) Ordered {
	for i := range o {
		if o[i].Key == key {
			o[i].Value = value
			return o
		}
	}
	return append(o, KV{key, value})
}

// TrimMap is trimObject for a plain map: nil and "" values are dropped.
func TrimMap(m Map) Map {
	out := make(Map, len(m))
	for k, v := range m {
		if v != nil && v != "" {
			out[k] = v
		}
	}
	return out
}

// SortedKeys lists an object's keys in order.
func SortedKeys(m Map) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

// Parse decodes JSON text; ok is false when it is not valid JSON.
func Parse(text string) (any, bool) {
	var v any
	if err := json.Unmarshal([]byte(text), &v); err != nil {
		return nil, false
	}
	return v, true
}
