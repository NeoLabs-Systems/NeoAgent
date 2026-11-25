package wearable

import (
	"bytes"
	"encoding/json"
)

type field struct {
	key   string
	value any
}

// fields is a JSON object that keeps its keys in the order they were added,
// like a JavaScript object literal. Responses the firmware and the app parse
// keep Node's key order, including which keys a branch leaves out.
type fields []field

// MarshalJSON writes the object in insertion order.
func (f fields) MarshalJSON() ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteByte('{')
	for i, kv := range f {
		if i > 0 {
			buf.WriteByte(',')
		}
		key, _ := json.Marshal(kv.key)
		buf.Write(key)
		buf.WriteByte(':')
		value, err := marshalValue(kv.value)
		if err != nil {
			return nil, err
		}
		buf.Write(value)
	}
	buf.WriteByte('}')
	return buf.Bytes(), nil
}

// marshalValue encodes without HTML escaping, as JSON.stringify does.
func marshalValue(v any) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return nil, err
	}
	return bytes.TrimSuffix(buf.Bytes(), []byte("\n")), nil
}

// set replaces the value of key in place, or appends it: the semantics of
// assigning a property on a spread copy.
func (f fields) set(key string, value any) fields {
	out := append(fields(nil), f...)
	for i := range out {
		if out[i].key == key {
			out[i].value = value
			return out
		}
	}
	return append(out, field{key, value})
}

func (f fields) get(key string) (any, bool) {
	for _, kv := range f {
		if kv.key == key {
			return kv.value, true
		}
	}
	return nil, false
}
