package jsx

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"sort"
	"strconv"
	"strings"
)

// Obj is a JSON object that remembers insertion order, as a JavaScript object
// does (apart from integer-like keys, which JavaScript lists first).
type Obj struct {
	keys []string
	vals map[string]any
}

// NewObj returns an empty object.
func NewObj() *Obj { return &Obj{vals: map[string]any{}} }

// O builds an object from alternating keys and values.
func O(kv ...any) *Obj {
	o := NewObj()
	for i := 0; i+1 < len(kv); i += 2 {
		o.Set(kv[i].(string), kv[i+1])
	}
	return o
}

// Set stores v under key; an existing key keeps its position.
func (o *Obj) Set(key string, v any) *Obj {
	if _, ok := o.vals[key]; !ok {
		o.keys = append(o.keys, key)
	}
	o.vals[key] = v
	return o
}

// Get returns the value under key.
func (o *Obj) Get(key string) (any, bool) {
	if o == nil {
		return nil, false
	}
	v, ok := o.vals[key]
	return v, ok
}

// Value returns the value under key, or nil.
func (o *Obj) Value(key string) any {
	v, _ := o.Get(key)
	return v
}

// Has reports whether key is set.
func (o *Obj) Has(key string) bool {
	_, ok := o.Get(key)
	return ok
}

// Delete removes key.
func (o *Obj) Delete(key string) {
	if _, ok := o.vals[key]; !ok {
		return
	}
	delete(o.vals, key)
	for i, k := range o.keys {
		if k == key {
			o.keys = append(o.keys[:i], o.keys[i+1:]...)
			break
		}
	}
}

// Len is the number of keys.
func (o *Obj) Len() int {
	if o == nil {
		return 0
	}
	return len(o.keys)
}

// Keys lists the keys in JavaScript's enumeration order.
func (o *Obj) Keys() []string {
	if o == nil {
		return nil
	}
	var index, other []string
	for _, k := range o.keys {
		if isArrayIndex(k) {
			index = append(index, k)
		} else {
			other = append(other, k)
		}
	}
	if len(index) == 0 {
		return other
	}
	sort.Slice(index, func(i, j int) bool {
		a, _ := strconv.ParseUint(index[i], 10, 32)
		b, _ := strconv.ParseUint(index[j], 10, 32)
		return a < b
	})
	return append(index, other...)
}

func isArrayIndex(k string) bool {
	if k == "" || len(k) > 10 || (len(k) > 1 && k[0] == '0') {
		return false
	}
	for i := 0; i < len(k); i++ {
		if k[i] < '0' || k[i] > '9' {
			return false
		}
	}
	n, err := strconv.ParseUint(k, 10, 64)
	return err == nil && n < 1<<32-1
}

// Clone copies the object one level deep, like `{ ...o }`.
func (o *Obj) Clone() *Obj {
	c := NewObj()
	if o == nil {
		return c
	}
	for _, k := range o.keys {
		c.Set(k, o.vals[k])
	}
	return c
}

// Assign copies the keys of other over o, like `{ ...o, ...other }`.
func (o *Obj) Assign(other *Obj) *Obj {
	if other == nil {
		return o
	}
	for _, k := range other.keys {
		o.Set(k, other.vals[k])
	}
	return o
}

// String returns the value under key when it is a string.
func (o *Obj) String(key string) string {
	s, _ := o.Value(key).(string)
	return s
}

// Truthy is JavaScript truthiness of the value under key.
func (o *Obj) Truthy(key string) bool { return Truthy(o.Value(key)) }

// Truthy is JavaScript truthiness.
func Truthy(v any) bool {
	switch t := v.(type) {
	case nil, undefinedType:
		return false
	case bool:
		return t
	case float64:
		return t != 0 && t == t
	case string:
		return t != ""
	}
	return true
}

// MarshalJSON is JSON.stringify. It lets an Obj sit inside any value that is
// encoded with encoding/json.
func (o *Obj) MarshalJSON() ([]byte, error) { return []byte(Marshal(o)), nil }

// Marshal is JSON.stringify(v) for values built from nil, bool, numbers,
// strings, []any, []string, []*Obj, map[string]any and *Obj.
func Marshal(v any) string {
	var b strings.Builder
	write(&b, v, "", "")
	return b.String()
}

// MarshalIndent is JSON.stringify(v, null, 2).
func MarshalIndent(v any) string {
	var b strings.Builder
	write(&b, v, "  ", "")
	return b.String()
}

func write(b *strings.Builder, v any, indent, cur string) {
	switch t := v.(type) {
	case nil:
		b.WriteString("null")
	case bool:
		b.WriteString(strconv.FormatBool(t))
	case float64:
		b.WriteString(FormatNumber(t))
	case float32:
		b.WriteString(FormatNumber(float64(t)))
	case int:
		b.WriteString(strconv.Itoa(t))
	case int64:
		b.WriteString(strconv.FormatInt(t, 10))
	case json.Number:
		f, _ := t.Float64()
		b.WriteString(FormatNumber(f))
	case string:
		writeQuoted(b, t)
	case *Obj:
		if t == nil {
			b.WriteString("null")
			return
		}
		writeObject(b, t, indent, cur)
	case map[string]any:
		o := NewObj()
		keys := make([]string, 0, len(t))
		for k := range t {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			o.Set(k, t[k])
		}
		writeObject(b, o, indent, cur)
	case []string:
		items := make([]any, len(t))
		for i, s := range t {
			items[i] = s
		}
		writeArray(b, items, indent, cur)
	case []*Obj:
		items := make([]any, len(t))
		for i, s := range t {
			items[i] = s
		}
		writeArray(b, items, indent, cur)
	case []any:
		writeArray(b, t, indent, cur)
	default:
		raw, err := json.Marshal(t)
		if err != nil {
			b.WriteString("null")
			return
		}
		b.Write(raw)
	}
}

func writeObject(b *strings.Builder, o *Obj, indent, cur string) {
	keys := o.Keys()
	if len(keys) == 0 {
		b.WriteString("{}")
		return
	}
	next := cur + indent
	b.WriteByte('{')
	for i, k := range keys {
		if i > 0 {
			b.WriteByte(',')
		}
		if indent != "" {
			b.WriteString("\n" + next)
		}
		writeQuoted(b, k)
		b.WriteByte(':')
		if indent != "" {
			b.WriteByte(' ')
		}
		write(b, o.vals[k], indent, next)
	}
	if indent != "" {
		b.WriteString("\n" + cur)
	}
	b.WriteByte('}')
}

func writeArray(b *strings.Builder, items []any, indent, cur string) {
	if len(items) == 0 {
		b.WriteString("[]")
		return
	}
	next := cur + indent
	b.WriteByte('[')
	for i, item := range items {
		if i > 0 {
			b.WriteByte(',')
		}
		if indent != "" {
			b.WriteString("\n" + next)
		}
		write(b, item, indent, next)
	}
	if indent != "" {
		b.WriteString("\n" + cur)
	}
	b.WriteByte(']')
}

// ErrSyntax is returned for text that is not JSON.
var ErrSyntax = errors.New("jsx: invalid JSON")

// Parse is JSON.parse: objects become *Obj, arrays []any, numbers float64.
func Parse(text string) (any, error) {
	dec := json.NewDecoder(strings.NewReader(text))
	dec.UseNumber()
	v, err := parseValue(dec)
	if err != nil {
		return nil, ErrSyntax
	}
	if _, err := dec.Token(); err != io.EOF {
		return nil, ErrSyntax
	}
	return v, nil
}

func parseValue(dec *json.Decoder) (any, error) {
	tok, err := dec.Token()
	if err != nil {
		return nil, err
	}
	switch t := tok.(type) {
	case json.Delim:
		switch t {
		case '{':
			o := NewObj()
			for dec.More() {
				keyTok, err := dec.Token()
				if err != nil {
					return nil, err
				}
				val, err := parseValue(dec)
				if err != nil {
					return nil, err
				}
				o.Set(keyTok.(string), val)
			}
			if _, err := dec.Token(); err != nil {
				return nil, err
			}
			return o, nil
		case '[':
			items := []any{}
			for dec.More() {
				val, err := parseValue(dec)
				if err != nil {
					return nil, err
				}
				items = append(items, val)
			}
			if _, err := dec.Token(); err != nil {
				return nil, err
			}
			return items, nil
		}
		return nil, ErrSyntax
	case json.Number:
		f, err := t.Float64()
		if err != nil {
			return nil, err
		}
		return f, nil
	default:
		return tok, nil
	}
}

// ParseObject is parseJsonObject(value, {}): the text as an object, or an
// empty one when it is empty, malformed or not an object.
func ParseObject(text string) *Obj {
	if text == "" {
		return NewObj()
	}
	v, err := Parse(text)
	if err != nil {
		return NewObj()
	}
	if o, ok := v.(*Obj); ok {
		return o
	}
	return NewObj()
}

// ParseArray parses a JSON array, or returns nil when it is not one.
func ParseArray(text string) []any {
	v, err := Parse(text)
	if err != nil {
		return nil
	}
	a, _ := v.([]any)
	return a
}

// DecodeBody decodes a request body, keeping object key order. It reports an
// error for an empty body or text that is not JSON.
func DecodeBody(raw []byte) (any, error) {
	if len(bytes.TrimSpace(raw)) == 0 {
		return nil, ErrSyntax
	}
	return Parse(string(raw))
}
