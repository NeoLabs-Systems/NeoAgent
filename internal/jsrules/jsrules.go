// Package jsrules keeps the few JavaScript rules the Node server's validation
// and file formats relied on: String(value), Boolean(value), Number(value),
// trim() with its Unicode spaces, string lengths counted in UTF-16 units and
// JSON.stringify's handling of line separators. Decoded JSON values are the
// types encoding/json produces (nil, bool, float64, string, []any, and
// workspace.Obj for objects that keep their member order).
package jsrules

import (
	"bytes"
	"encoding/json"
	"math"
	"strconv"
	"strings"
	"unicode/utf16"
)

// IsSpace reports whether JavaScript counts r as white space or a line
// terminator.
func IsSpace(r rune) bool {
	switch r {
	case '\t', '\n', '\v', '\f', '\r', ' ', 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff:
		return true
	}
	return r >= 0x2000 && r <= 0x200a
}

// Trim is String.prototype.trim.
func Trim(s string) string { return strings.TrimFunc(s, IsSpace) }

// String is String(value) for a decoded value.
func String(v any) string {
	switch v := v.(type) {
	case nil:
		return "null"
	case string:
		return v
	case bool:
		return strconv.FormatBool(v)
	case float64:
		return strconv.FormatFloat(v, 'f', -1, 64)
	case []any:
		parts := make([]string, len(v))
		for i, item := range v {
			if item != nil {
				parts[i] = String(item)
			}
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}

// Truthy is Boolean(value).
func Truthy(v any) bool {
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

// OrEmpty is String(value || ”).
func OrEmpty(v any) string {
	if !Truthy(v) {
		return ""
	}
	return String(v)
}

// OrDefault is value || fallback.
func OrDefault(v, fallback any) any {
	if Truthy(v) {
		return v
	}
	return fallback
}

// Number is Number(value) for a decoded value; a member that was absent
// (undefined) is NaN, which the caller passes as math.NaN().
func Number(v any) float64 {
	switch v := v.(type) {
	case nil:
		return 0
	case bool:
		if v {
			return 1
		}
		return 0
	case float64:
		return v
	case string:
		return stringNumber(v)
	case []any:
		switch len(v) {
		case 0:
			return 0
		case 1:
			if v[0] == nil {
				return 0
			}
			return Number(v[0])
		}
	}
	return math.NaN()
}

func stringNumber(s string) float64 {
	s = Trim(s)
	if s == "" {
		return 0
	}
	if len(s) > 2 && s[0] == '0' {
		base := map[byte]int{'x': 16, 'X': 16, 'o': 8, 'O': 8, 'b': 2, 'B': 2}[s[1]]
		if base != 0 {
			n, err := strconv.ParseUint(s[2:], base, 64)
			if err != nil {
				return math.NaN()
			}
			return float64(n)
		}
	}
	switch s {
	case "Infinity", "+Infinity":
		return math.Inf(1)
	case "-Infinity":
		return math.Inf(-1)
	}
	// ParseFloat accepts spellings JavaScript does not ("inf", "nan", "1_0",
	// hex floats), so only plain decimal numbers get through.
	for _, r := range s {
		if !strings.ContainsRune("+-.0123456789eE", r) {
			return math.NaN()
		}
	}
	f, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return math.NaN()
	}
	return f
}

// Len is the length JavaScript reports: UTF-16 code units.
func Len(s string) int { return len(utf16.Encode([]rune(s))) }

// JSON is JSON.stringify: no HTML escaping, and U+2028 and U+2029 written as
// they are.
func JSON(v any) string {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return ""
	}
	return rawLineSeparators(strings.TrimRight(buf.String(), "\n"))
}

func rawLineSeparators(s string) string {
	if !strings.Contains(s, `\u202`) {
		return s
	}
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		if s[i] != '\\' || i+1 >= len(s) {
			b.WriteByte(s[i])
			continue
		}
		switch {
		case strings.HasPrefix(s[i:], `\u2028`):
			b.WriteString("\u2028")
			i += 5
		case strings.HasPrefix(s[i:], `\u2029`):
			b.WriteString("\u2029")
			i += 5
		default:
			b.WriteString(s[i : i+2])
			i++
		}
	}
	return b.String()
}
