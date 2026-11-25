package guest

import (
	"bytes"
	"encoding/json"
)

type kv struct {
	key   string
	value any
}

// object is a JSON object that keeps its keys in the order given, as the
// Node agent's object literals did; a Go map would sort them.
type object []kv

func (o object) MarshalJSON() ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteByte('{')
	for i, item := range o {
		if i > 0 {
			buf.WriteByte(',')
		}
		key, _ := json.Marshal(item.key)
		buf.Write(key)
		buf.WriteByte(':')
		enc := json.NewEncoder(&buf)
		enc.SetEscapeHTML(false)
		if err := enc.Encode(item.value); err != nil {
			return nil, err
		}
		buf.Truncate(buf.Len() - 1)
	}
	buf.WriteByte('}')
	return buf.Bytes(), nil
}

func obj(pairs ...any) object {
	out := make(object, 0, len(pairs)/2)
	for i := 0; i+1 < len(pairs); i += 2 {
		out = append(out, kv{pairs[i].(string), pairs[i+1]})
	}
	return out
}
