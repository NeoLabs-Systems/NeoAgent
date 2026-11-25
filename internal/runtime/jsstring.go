package runtime

import (
	"bytes"
	"encoding/json"
)

// jsString quotes s the way JavaScript's JSON.stringify does for the ASCII
// text this package quotes: double quotes, backslash escapes, no HTML escaping.
func jsString(s string) string {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(s)
	return string(bytes.TrimSuffix(buf.Bytes(), []byte("\n")))
}
