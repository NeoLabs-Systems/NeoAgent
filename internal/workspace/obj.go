package workspace

import (
	"bytes"
	"encoding/json"
)

// Field is one member of an Obj.
type Field struct {
	Key   string
	Value any
}

// Undefined marks a member JSON.stringify would drop (a JS undefined).
type Undefined struct{}

// Obj is a JSON object that keeps member order, because the tool results the
// model reads were written with a fixed key order.
type Obj []Field

// MarshalJSON writes the members in order without HTML escaping.
func (o Obj) MarshalJSON() ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteByte('{')
	wrote := false
	for _, f := range o {
		if _, skip := f.Value.(Undefined); skip {
			continue
		}
		if wrote {
			buf.WriteByte(',')
		}
		wrote = true
		key, _ := json.Marshal(f.Key)
		buf.Write(key)
		buf.WriteByte(':')
		enc := json.NewEncoder(&buf)
		enc.SetEscapeHTML(false)
		if err := enc.Encode(f.Value); err != nil {
			return nil, err
		}
		buf.Truncate(buf.Len() - 1) // Encode appends a newline.
	}
	buf.WriteByte('}')
	return buf.Bytes(), nil
}

// Get returns the member named key.
func (o Obj) Get(key string) (any, bool) {
	for _, f := range o {
		if f.Key == key {
			return f.Value, true
		}
	}
	return nil, false
}
