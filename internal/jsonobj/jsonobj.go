// Package jsonobj is an ordered JSON object: answers are built the way the
// Node code built them (object literals and spreads) and forwarded with the
// key order they arrived in, so a plain map would not do.
package jsonobj

import (
	"bytes"
	"encoding/json"
	"fmt"
)

// Object is an ordered JSON object.
type Object struct {
	keys []string
	vals map[string]any
}

// New builds an Object from alternating keys and values.
func New(pairs ...any) *Object {
	o := &Object{vals: map[string]any{}}
	for i := 0; i+1 < len(pairs); i += 2 {
		o.Set(pairs[i].(string), pairs[i+1])
	}
	return o
}

// Set stores a value. Like a JS object, an existing key keeps its position.
func (o *Object) Set(key string, value any) *Object {
	if _, ok := o.vals[key]; !ok {
		o.keys = append(o.keys, key)
	}
	o.vals[key] = value
	return o
}

// Get returns a value and whether it was set.
func (o *Object) Get(key string) (any, bool) {
	v, ok := o.vals[key]
	return v, ok
}

// Merge copies every key of other (a spread).
func (o *Object) Merge(other *Object) *Object {
	if other == nil {
		return o
	}
	for _, k := range other.keys {
		o.Set(k, other.vals[k])
	}
	return o
}

// Clone copies the object.
func (o *Object) Clone() *Object { return New().Merge(o) }

// Delete removes a key.
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

// MarshalJSON writes the keys in insertion order, without HTML escaping.
func (o *Object) MarshalJSON() ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteByte('{')
	for i, k := range o.keys {
		if i > 0 {
			buf.WriteByte(',')
		}
		key, _ := json.Marshal(k)
		buf.Write(key)
		buf.WriteByte(':')
		enc := json.NewEncoder(&buf)
		enc.SetEscapeHTML(false)
		if err := enc.Encode(o.vals[k]); err != nil {
			return nil, err
		}
		buf.Truncate(buf.Len() - 1)
	}
	buf.WriteByte('}')
	return buf.Bytes(), nil
}

// UnmarshalJSON reads an object keeping the order of its keys. Values stay
// raw (json.RawMessage), so nested objects are written back byte for byte.
func (o *Object) UnmarshalJSON(data []byte) error {
	o.keys, o.vals = nil, map[string]any{}
	dec := json.NewDecoder(bytes.NewReader(data))
	tok, err := dec.Token()
	if err != nil {
		return err
	}
	if delim, ok := tok.(json.Delim); !ok || delim != '{' {
		return fmt.Errorf("expected a JSON object")
	}
	for dec.More() {
		keyTok, err := dec.Token()
		if err != nil {
			return err
		}
		var raw json.RawMessage
		if err := dec.Decode(&raw); err != nil {
			return err
		}
		o.Set(keyTok.(string), raw)
	}
	return nil
}

// decode reads key into out, whether it was set by code or came from JSON.
func (o *Object) decodeValue(key string, out any) bool {
	v, ok := o.vals[key]
	if !ok {
		return false
	}
	raw, isRaw := v.(json.RawMessage)
	if !isRaw {
		var err error
		if raw, err = json.Marshal(v); err != nil {
			return false
		}
	}
	return json.Unmarshal(raw, out) == nil
}

// Decode reads key into out; false when it is missing or does not fit.
func (o *Object) Decode(key string, out any) bool { return o.decodeValue(key, out) }

// Keys are the keys in order.
func (o *Object) Keys() []string { return append([]string(nil), o.keys...) }

// Map decodes the object into a plain map (key order is lost).
func (o *Object) Map() map[string]any {
	if o == nil {
		return nil
	}
	out := make(map[string]any, len(o.keys))
	for _, k := range o.keys {
		var v any
		o.decodeValue(k, &v)
		out[k] = v
	}
	return out
}

// String returns a string value ("" if missing or not a string).
func (o *Object) String(key string) string {
	var s string
	o.decodeValue(key, &s)
	return s
}

// Bool reports whether the value is exactly true.
func (o *Object) Bool(key string) bool {
	var b bool
	o.decodeValue(key, &b)
	return b
}

// Float returns a numeric value (0 if missing or not a number).
func (o *Object) Float(key string) float64 {
	var f float64
	o.decodeValue(key, &f)
	return f
}

// Has reports whether the key is set (even to null).
func (o *Object) Has(key string) bool {
	_, ok := o.vals[key]
	return ok
}
