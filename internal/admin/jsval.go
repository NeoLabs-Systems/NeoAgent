package admin

import (
	"bytes"
	"encoding/json"
	"math"
	"regexp"
	"strconv"
	"strings"
	"unicode"
	"unicode/utf16"
)

// The Node routes read request bodies as loosely typed JavaScript values and
// lean on String(), Number() and trim(). These helpers reproduce exactly those
// coercions so a body the Node server accepts or rejects gets the same answer
// here.

func isJSSpace(r rune) bool {
	switch r {
	case '\t', '\n', '\v', '\f', '\r', 0xFEFF, 0x2028, 0x2029:
		return true
	}
	return unicode.Is(unicode.Zs, r)
}

// jsTrim is String.prototype.trim: Unicode space separators, the BOM, tab,
// vertical tab, form feed and the line terminators (but not U+0085).
func jsTrim(s string) string { return strings.TrimFunc(s, isJSSpace) }

// jsString is String(value) for a decoded JSON value.
func jsString(v any) string {
	switch v := v.(type) {
	case nil:
		return "null"
	case string:
		return v
	case bool:
		return strconv.FormatBool(v)
	case json.Number:
		return numberString(jsToNumber(v))
	case []any:
		parts := make([]string, len(v))
		for i, item := range v {
			if item != nil {
				parts[i] = jsString(item)
			}
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}

// jsText is String(value ?? ”): a missing or null field reads as empty.
func jsText(v any) string {
	if v == nil {
		return ""
	}
	return jsString(v)
}

// numberString formats a number the way JavaScript prints it.
func numberString(f float64) string {
	switch {
	case math.IsNaN(f):
		return "NaN"
	case math.IsInf(f, 1):
		return "Infinity"
	case math.IsInf(f, -1):
		return "-Infinity"
	case f == 0:
		return "0"
	}
	abs := math.Abs(f)
	if abs >= 1e-6 && abs < 1e21 {
		return strconv.FormatFloat(f, 'f', -1, 64)
	}
	out := strconv.FormatFloat(f, 'e', -1, 64)
	mantissa, exponent, _ := strings.Cut(out, "e")
	sign := exponent[:1]
	digits := strings.TrimLeft(exponent[1:], "0")
	return mantissa + "e" + sign + digits
}

var decimalLiteral = regexp.MustCompile(`^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$`)

// stringToNumber is Number(string).
func stringToNumber(s string) float64 {
	s = jsTrim(s)
	if s == "" {
		return 0
	}
	switch s {
	case "Infinity", "+Infinity":
		return math.Inf(1)
	case "-Infinity":
		return math.Inf(-1)
	}
	if len(s) > 2 && s[0] == '0' {
		base := map[byte]int{'x': 16, 'X': 16, 'o': 8, 'O': 8, 'b': 2, 'B': 2}[s[1]]
		if base != 0 {
			n, err := strconv.ParseUint(s[2:], base, 64)
			if err != nil && !isRangeError(err) {
				return math.NaN()
			}
			return float64(n)
		}
	}
	if !decimalLiteral.MatchString(s) {
		return math.NaN()
	}
	f, err := strconv.ParseFloat(s, 64)
	if err != nil && !isRangeError(err) {
		return math.NaN()
	}
	return f
}

func isRangeError(err error) bool {
	ne, ok := err.(*strconv.NumError)
	return ok && ne.Err == strconv.ErrRange
}

// jsToNumber is Number(value) for a decoded JSON value.
func jsToNumber(v any) float64 {
	switch v := v.(type) {
	case nil:
		return 0
	case bool:
		if v {
			return 1
		}
		return 0
	case json.Number:
		return stringToNumber(string(v))
	case string:
		return stringToNumber(v)
	}
	return stringToNumber(jsString(v))
}

// isInteger is Number.isInteger.
func isInteger(f float64) bool {
	return !math.IsNaN(f) && !math.IsInf(f, 0) && f == math.Trunc(f)
}

// positiveID reads a route parameter the way `Number(value)` does and accepts
// it only when it is a positive integer.
func positiveID(raw string) (int64, bool) {
	f := stringToNumber(raw)
	if !isInteger(f) || f <= 0 || f > math.MaxInt64 {
		return 0, false
	}
	return int64(f), true
}

// jsonText is JSON.stringify for a value: no HTML escaping and the U+2028 and
// U+2029 separators left as they are, which is what stored detail columns hold.
func jsonText(v any) string {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		panic("admin: cannot encode " + err.Error())
	}
	out := strings.TrimRight(buf.String(), "\n")
	out = strings.ReplaceAll(out, ` `, " ")
	return strings.ReplaceAll(out, ` `, " ")
}

// sliceUTF16 is String.prototype.slice(0, n): n counts UTF-16 code units, and a
// cut inside a surrogate pair leaves the replacement character.
func sliceUTF16(s string, n int) string {
	units := utf16.Encode([]rune(s))
	if len(units) <= n {
		return s
	}
	return string(utf16.Decode(units[:n]))
}
