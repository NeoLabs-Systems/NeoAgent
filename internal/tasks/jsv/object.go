// Package jsv holds the JavaScript semantics the Node server's scheduling and
// device-data code relied on: objects that keep their key order (so a stored
// config reads back exactly as written), JSON.stringify, Number(), String(),
// truthiness and Date parsing. Inputs from phones and browsers were validated
// with those rules, so the same input must be accepted or refused here.
package jsv

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"math"
	"sort"
	"strconv"
	"strings"
	"unicode/utf16"
	"unicode/utf8"
)

// Object is a JSON object that remembers the order its keys were first set in,
// like a JavaScript object. Keys that look like array indexes come first in
// ascending order, as they do in JavaScript.
type Object struct {
	keys []string
	vals map[string]any
}

// NewObject returns an empty object.
func NewObject() *Object { return &Object{vals: map[string]any{}} }

// Get returns the value of key; ok is false when the key is absent.
func (o *Object) Get(key string) (any, bool) {
	if o == nil {
		return nil, false
	}
	v, ok := o.vals[key]
	return v, ok
}

// Val returns the value of key, nil (JavaScript undefined or null) when absent.
func (o *Object) Val(key string) any {
	v, _ := o.Get(key)
	return v
}

// Has reports whether key is set.
func (o *Object) Has(key string) bool {
	_, ok := o.Get(key)
	return ok
}

// Set assigns key. A key already present keeps its position.
func (o *Object) Set(key string, value any) *Object {
	if _, ok := o.vals[key]; !ok {
		o.keys = append(o.keys, key)
	}
	o.vals[key] = value
	return o
}

// Delete removes key.
func (o *Object) Delete(key string) {
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
func (o *Object) Len() int {
	if o == nil {
		return 0
	}
	return len(o.keys)
}

func arrayIndex(key string) (uint64, bool) {
	if key == "" || len(key) > 10 || (len(key) > 1 && key[0] == '0') {
		return 0, false
	}
	n, err := strconv.ParseUint(key, 10, 64)
	return n, err == nil && n < math.MaxUint32
}

// Keys lists the keys in JavaScript's enumeration order.
func (o *Object) Keys() []string {
	if o == nil {
		return nil
	}
	var indexes, others []string
	for _, k := range o.keys {
		if _, ok := arrayIndex(k); ok {
			indexes = append(indexes, k)
		} else {
			others = append(others, k)
		}
	}
	sort.Slice(indexes, func(i, j int) bool {
		a, _ := arrayIndex(indexes[i])
		b, _ := arrayIndex(indexes[j])
		return a < b
	})
	return append(indexes, others...)
}

// Clone is the object spread `{...o}`: a shallow copy.
func (o *Object) Clone() *Object {
	c := NewObject()
	if o == nil {
		return c
	}
	for _, k := range o.keys {
		c.Set(k, o.vals[k])
	}
	return c
}

// Assign copies every key of src onto o, like Object.assign.
func (o *Object) Assign(src *Object) *Object {
	for _, k := range src.Keys() {
		o.Set(k, src.vals[k])
	}
	return o
}

// MarshalJSON writes the object as JSON.stringify would.
func (o *Object) MarshalJSON() ([]byte, error) {
	var b bytes.Buffer
	writeValue(&b, o)
	return b.Bytes(), nil
}

// Decode reads one JSON value, keeping object key order. Numbers become
// float64, like JSON.parse. Input that JSON.parse refuses is an error.
func Decode(raw []byte) (any, error) {
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	v, err := decodeValue(dec)
	if err != nil {
		return nil, err
	}
	if _, err := dec.Token(); !errors.Is(err, io.EOF) {
		return nil, errors.New("unexpected data after JSON value")
	}
	return v, nil
}

func decodeValue(dec *json.Decoder) (any, error) {
	tok, err := dec.Token()
	if err != nil {
		return nil, err
	}
	switch t := tok.(type) {
	case json.Delim:
		if t == '{' {
			o := NewObject()
			for dec.More() {
				keyTok, err := dec.Token()
				if err != nil {
					return nil, err
				}
				v, err := decodeValue(dec)
				if err != nil {
					return nil, err
				}
				o.Set(keyTok.(string), v)
			}
			_, err := dec.Token()
			return o, err
		}
		arr := []any{}
		for dec.More() {
			v, err := decodeValue(dec)
			if err != nil {
				return nil, err
			}
			arr = append(arr, v)
		}
		_, err := dec.Token()
		return arr, err
	case json.Number:
		f, err := strconv.ParseFloat(string(t), 64)
		if err != nil && !math.IsInf(f, 0) {
			return nil, err
		}
		return f, nil
	}
	return tok, nil
}

// ParseObject is JSON.parse of text when it holds an object; anything else
// (invalid JSON, an array, a scalar) yields nil.
func ParseObject(text string) *Object {
	v, err := Decode([]byte(text))
	if err != nil {
		return nil
	}
	o, _ := v.(*Object)
	return o
}

// Stringify is JSON.stringify(v) for a value Decode produced (or built from
// Object, []any, string, float64, int, bool and nil). Unrepresentable numbers
// become null.
func Stringify(v any) string {
	var b bytes.Buffer
	writeValue(&b, v)
	return b.String()
}

func writeValue(b *bytes.Buffer, v any) {
	switch v := v.(type) {
	case nil:
		b.WriteString("null")
	case bool:
		b.WriteString(strconv.FormatBool(v))
	case string:
		writeString(b, v)
	case float64:
		if math.IsNaN(v) || math.IsInf(v, 0) {
			b.WriteString("null")
		} else {
			b.WriteString(NumberString(v))
		}
	case int:
		b.WriteString(strconv.Itoa(v))
	case int64:
		b.WriteString(strconv.FormatInt(v, 10))
	case []any:
		b.WriteByte('[')
		for i, e := range v {
			if i > 0 {
				b.WriteByte(',')
			}
			writeValue(b, e)
		}
		b.WriteByte(']')
	case []string:
		b.WriteByte('[')
		for i, e := range v {
			if i > 0 {
				b.WriteByte(',')
			}
			writeString(b, e)
		}
		b.WriteByte(']')
	case *Object:
		if v == nil {
			b.WriteString("null")
			return
		}
		b.WriteByte('{')
		for i, k := range v.Keys() {
			if i > 0 {
				b.WriteByte(',')
			}
			writeString(b, k)
			b.WriteByte(':')
			writeValue(b, v.vals[k])
		}
		b.WriteByte('}')
	case map[string]any:
		keys := make([]string, 0, len(v))
		for k := range v {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		b.WriteByte('{')
		for i, k := range keys {
			if i > 0 {
				b.WriteByte(',')
			}
			writeString(b, k)
			b.WriteByte(':')
			writeValue(b, v[k])
		}
		b.WriteByte('}')
	default:
		raw, err := json.Marshal(v)
		if err != nil {
			b.WriteString("null")
			return
		}
		b.Write(raw)
	}
}

const hexDigits = "0123456789abcdef"

// writeString quotes s as JSON.stringify does: only quotes, backslashes and
// control characters are escaped.
func writeString(b *bytes.Buffer, s string) {
	b.WriteByte('"')
	for i := 0; i < len(s); {
		c := s[i]
		if c < utf8.RuneSelf {
			switch c {
			case '"':
				b.WriteString(`\"`)
			case '\\':
				b.WriteString(`\\`)
			case '\b':
				b.WriteString(`\b`)
			case '\f':
				b.WriteString(`\f`)
			case '\n':
				b.WriteString(`\n`)
			case '\r':
				b.WriteString(`\r`)
			case '\t':
				b.WriteString(`\t`)
			default:
				if c < 0x20 {
					b.WriteString(`\u00`)
					b.WriteByte(hexDigits[c>>4])
					b.WriteByte(hexDigits[c&0xf])
				} else {
					b.WriteByte(c)
				}
			}
			i++
			continue
		}
		r, size := utf8.DecodeRuneInString(s[i:])
		if r == utf8.RuneError && size == 1 {
			b.WriteString(`�`)
		} else {
			b.WriteString(s[i : i+size])
		}
		i += size
	}
	b.WriteByte('"')
}

// NumberString is String(n) for a finite number.
func NumberString(f float64) string {
	if f == 0 {
		return "0"
	}
	if math.IsNaN(f) {
		return "NaN"
	}
	if math.IsInf(f, 1) {
		return "Infinity"
	}
	if math.IsInf(f, -1) {
		return "-Infinity"
	}
	sign := ""
	if f < 0 {
		sign = "-"
		f = -f
	}
	e := strconv.FormatFloat(f, 'e', -1, 64) // d.ddde±xx
	mantissa, expText, _ := strings.Cut(e, "e")
	digits := strings.Replace(mantissa, ".", "", 1)
	exp, _ := strconv.Atoi(expText)
	n := exp + 1
	k := len(digits)
	switch {
	case k <= n && n <= 21:
		return sign + digits + strings.Repeat("0", n-k)
	case 0 < n && n <= 21:
		return sign + digits[:n] + "." + digits[n:]
	case -6 < n && n <= 0:
		return sign + "0." + strings.Repeat("0", -n) + digits
	}
	expSign := "+"
	if n-1 < 0 {
		expSign = "-"
	}
	abs := n - 1
	if abs < 0 {
		abs = -abs
	}
	if k == 1 {
		return sign + digits + "e" + expSign + strconv.Itoa(abs)
	}
	return sign + digits[:1] + "." + digits[1:] + "e" + expSign + strconv.Itoa(abs)
}

// Units is the length of s in UTF-16 code units, JavaScript's string length.
func Units(s string) int {
	n := 0
	for _, r := range s {
		n += utf16.RuneLen(r)
	}
	return n
}

// Slice is s.slice(0, n): the first n UTF-16 code units. A cut through a
// surrogate pair leaves a lone surrogate in JavaScript; here it is dropped.
func Slice(s string, n int) string {
	if n <= 0 {
		return ""
	}
	units := 0
	for i, r := range s {
		w := utf16.RuneLen(r)
		if units+w > n {
			return s[:i]
		}
		units += w
	}
	return s
}

// StringifyIndent is JSON.stringify(v, null, 2): two spaces per level, empty
// objects and lists written as {} and [].
func StringifyIndent(v any) string {
	var b bytes.Buffer
	writeIndented(&b, v, 0)
	return b.String()
}

func writeIndented(b *bytes.Buffer, v any, depth int) {
	pad := func(n int) { b.WriteString(strings.Repeat("  ", n)) }
	switch v := v.(type) {
	case *Object:
		if v == nil || v.Len() == 0 {
			b.WriteString("{}")
			return
		}
		b.WriteString("{\n")
		for i, k := range v.Keys() {
			if i > 0 {
				b.WriteString(",\n")
			}
			pad(depth + 1)
			writeString(b, k)
			b.WriteString(": ")
			writeIndented(b, v.vals[k], depth+1)
		}
		b.WriteByte('\n')
		pad(depth)
		b.WriteByte('}')
	case []any:
		if len(v) == 0 {
			b.WriteString("[]")
			return
		}
		b.WriteString("[\n")
		for i, e := range v {
			if i > 0 {
				b.WriteString(",\n")
			}
			pad(depth + 1)
			writeIndented(b, e, depth+1)
		}
		b.WriteByte('\n')
		pad(depth)
		b.WriteByte(']')
	default:
		writeValue(b, v)
	}
}
