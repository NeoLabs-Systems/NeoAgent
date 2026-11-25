package agentimport

import (
	"encoding/json"
	"strings"
)

// marshal writes a decoded value as JSON.stringify would: object order kept,
// no HTML escaping.
func marshal(v any) string {
	var b strings.Builder
	writeJSON(&b, v)
	return b.String()
}

func writeJSON(b *strings.Builder, v any) {
	switch t := v.(type) {
	case nil:
		b.WriteString("null")
	case string:
		q, _ := jsonQuote(t)
		b.WriteString(q)
	case bool, float64:
		raw, _ := json.Marshal(t)
		b.Write(raw)
	case []any:
		b.WriteByte('[')
		for i, item := range t {
			if i > 0 {
				b.WriteByte(',')
			}
			writeJSON(b, item)
		}
		b.WriteByte(']')
	case *Obj:
		b.WriteByte('{')
		for i, k := range t.Keys() {
			if i > 0 {
				b.WriteByte(',')
			}
			q, _ := jsonQuote(k)
			b.WriteString(q + ":")
			writeJSON(b, t.Get(k))
		}
		b.WriteByte('}')
	default:
		raw, _ := json.Marshal(t)
		b.Write(raw)
	}
}
