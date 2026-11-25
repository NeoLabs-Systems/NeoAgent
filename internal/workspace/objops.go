package workspace

import (
	"bytes"
	"encoding/json"
	"io"
)

// Value returns the member named key, nil when there is none.
func (o Obj) Value(key string) any {
	v, _ := o.Get(key)
	return v
}

// With returns a copy with key assigned the way JavaScript assigns a member:
// an existing key keeps its place, a new one goes last.
func (o Obj) With(key string, value any) Obj {
	for i := range o {
		if o[i].Key == key {
			out := append(Obj(nil), o...)
			out[i].Value = value
			return out
		}
	}
	return append(append(Obj(nil), o...), Field{Key: key, Value: value})
}

// Merge is {...o, ...over}.
func (o Obj) Merge(over Obj) Obj {
	out := append(Obj(nil), o...)
	for _, f := range over {
		out = out.With(f.Key, f.Value)
	}
	return out
}

// Without returns a copy that lacks the named members.
func (o Obj) Without(keys ...string) Obj {
	out := Obj{}
	for _, f := range o {
		drop := false
		for _, k := range keys {
			drop = drop || f.Key == k
		}
		if !drop {
			out = append(out, f)
		}
	}
	return out
}

// DecodeJSON reads one JSON value the way JSON.parse does for member order:
// objects become Obj values that keep the order they were written in, arrays
// []any, numbers float64.
func DecodeJSON(data []byte) (any, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	v, err := decodeValue(dec)
	if err != nil {
		return nil, err
	}
	if _, err := dec.Token(); err != io.EOF {
		return nil, io.ErrUnexpectedEOF
	}
	return v, nil
}

func decodeValue(dec *json.Decoder) (any, error) {
	tok, err := dec.Token()
	if err != nil {
		return nil, err
	}
	delim, ok := tok.(json.Delim)
	if !ok {
		return tok, nil
	}
	if delim == '[' {
		list := []any{}
		for dec.More() {
			item, err := decodeValue(dec)
			if err != nil {
				return nil, err
			}
			list = append(list, item)
		}
		_, err := dec.Token()
		return list, err
	}
	obj := Obj{}
	for dec.More() {
		keyTok, err := dec.Token()
		if err != nil {
			return nil, err
		}
		value, err := decodeValue(dec)
		if err != nil {
			return nil, err
		}
		obj = obj.With(keyTok.(string), value)
	}
	_, err = dec.Token()
	return obj, err
}
