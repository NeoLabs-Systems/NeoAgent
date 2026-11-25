package settings

import (
	"encoding/json"
	"strconv"
	"strings"
)

// The Node server validated loosely typed JSON with JavaScript's own rules
// (String(value || ''), value.trim(), truthiness). These helpers keep those
// rules for decoded values so the same input is accepted or refused.

// jsTrim is String.prototype.trim.
func jsTrim(s string) string {
	return strings.TrimFunc(s, func(r rune) bool {
		switch r {
		case '\t', '\n', '\v', '\f', '\r', ' ', 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff:
			return true
		}
		return r >= 0x2000 && r <= 0x200a
	})
}

// decode reads a JSON value; a missing value (JavaScript undefined) and an
// unreadable one both come back as nil.
func decode(raw json.RawMessage) any {
	if len(raw) == 0 {
		return nil
	}
	var v any
	if err := json.Unmarshal(raw, &v); err != nil {
		return nil
	}
	return v
}

// truthy is JavaScript's Boolean(value).
func truthy(v any) bool {
	switch v := v.(type) {
	case nil:
		return false
	case bool:
		return v
	case float64:
		return v != 0 && v == v
	case string:
		return v != ""
	}
	return true
}

// jsString is String(value) for a decoded value that is not nil.
func jsString(v any) string {
	switch v := v.(type) {
	case nil:
		return ""
	case string:
		return v
	case bool:
		return strconv.FormatBool(v)
	case float64:
		return strconv.FormatFloat(v, 'f', -1, 64)
	case []any:
		parts := make([]string, len(v))
		for i, item := range v {
			parts[i] = jsString(item)
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}

// orEmpty is String(value || ”).
func orEmpty(v any) string {
	if !truthy(v) {
		return ""
	}
	return jsString(v)
}

// truncateUTF16 is value.slice(0, n): n counts UTF-16 code units. A character
// that would be cut in half is dropped whole.
func truncateUTF16(s string, n int) string {
	units := 0
	for i, r := range s {
		width := 1
		if r > 0xffff {
			width = 2
		}
		if units+width > n {
			return s[:i]
		}
		units += width
	}
	return s
}

// number is Number(value) for the shapes stored token metrics can take; other
// values count as zero.
func number(v any) float64 {
	switch v := v.(type) {
	case float64:
		return v
	case bool:
		if v {
			return 1
		}
	case string:
		if n, err := strconv.ParseFloat(jsTrim(v), 64); err == nil {
			return n
		}
	}
	return 0
}

// jsonText is JSON.stringify for a Go value, without HTML escaping.
func jsonText(v any) json.RawMessage {
	var b strings.Builder
	enc := json.NewEncoder(&b)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		panic("settings: value is not JSON: " + err.Error())
	}
	return json.RawMessage(strings.TrimRight(b.String(), "\n"))
}
