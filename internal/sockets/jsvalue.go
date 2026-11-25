package sockets

import (
	"encoding/base64"
	"math"
	"regexp"
	"strconv"
	"strings"
	"unicode/utf16"
)

// Socket payloads are untrusted JSON read the way the Node handlers read them
// (asObject, toOptionalString), so a client sending an odd shape gets the same
// answer from both servers.

func asObject(v any) map[string]any {
	if m, ok := v.(map[string]any); ok {
		return m
	}
	return map[string]any{}
}

// jsSpace is what JavaScript's String.prototype.trim removes.
func jsSpace(r rune) bool {
	switch r {
	case '\t', '\n', '\v', '\f', '\r', ' ', 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff:
		return true
	}
	return r >= 0x2000 && r <= 0x200a
}

// jsString is String(value) for decoded JSON.
func jsString(v any) string {
	switch t := v.(type) {
	case nil:
		return "null"
	case string:
		return t
	case bool:
		return strconv.FormatBool(t)
	case float64:
		return jsNumber(t)
	case []any:
		parts := make([]string, len(t))
		for i, item := range t {
			if item != nil {
				parts[i] = jsString(item)
			}
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}

// jsNumber is Number.prototype.toString: plain digits from 1e-6 up to 1e21,
// exponent form outside that range ("1e-7", "1e+21").
func jsNumber(f float64) string {
	if a := math.Abs(f); a != 0 && (a >= 1e21 || a < 1e-6) {
		s := strconv.FormatFloat(f, 'e', -1, 64)
		mantissa, exp, _ := strings.Cut(s, "e")
		sign := exp[:1]
		exp = strings.TrimLeft(exp[1:], "0")
		return mantissa + "e" + sign + exp
	}
	return strconv.FormatFloat(f, 'f', -1, 64)
}

func utf16Len(s string) int { return len(utf16.Encode([]rune(s))) }

// optionalString is toOptionalString: trimmed text of a value, cut to maxLen
// UTF-16 code units; "" for null or a missing value.
func optionalString(v any, maxLen int) string {
	if v == nil {
		return ""
	}
	s := strings.TrimFunc(jsString(v), jsSpace)
	if units := utf16.Encode([]rune(s)); len(units) > maxLen {
		return string(utf16.Decode(units[:maxLen]))
	}
	return s
}

// truthyString is String(value) of a value JavaScript treats as set, else "".
func truthyString(v any) string {
	switch t := v.(type) {
	case string:
		return t
	case float64:
		if t != 0 {
			return jsNumber(t)
		}
	case bool:
		if t {
			return "true"
		}
	case map[string]any, []any:
		return jsString(t)
	}
	return ""
}

// firstTruthy is `a || b || ...` over string-ish values.
func firstTruthy(values ...any) string {
	for _, v := range values {
		if s := truthyString(v); s != "" {
			return s
		}
	}
	return ""
}

// decodeBase64 is Buffer.from(text, 'base64'): it accepts the URL-safe
// alphabet, skips characters outside the alphabet and stops at padding.
func decodeBase64(s string) []byte {
	clean := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		switch {
		case c == '=':
			i = len(s)
		case c == '-':
			clean = append(clean, '+')
		case c == '_':
			clean = append(clean, '/')
		case c >= 'A' && c <= 'Z', c >= 'a' && c <= 'z', c >= '0' && c <= '9', c == '+', c == '/':
			clean = append(clean, c)
		}
	}
	if len(clean)%4 == 1 { // a lone trailing sextet carries no byte
		clean = clean[:len(clean)-1]
	}
	// Trailing bits that are not zero are ignored, as Node does (Go's decoder
	// only rejects them in strict mode).
	out, _ := base64.RawStdEncoding.DecodeString(string(clean))
	return out
}

var jsNumeric = regexp.MustCompile(`^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$`)

// jsToNumber is Number(value); a missing value (undefined) is NaN.
func jsToNumber(v any, present bool) float64 {
	if !present {
		return math.NaN()
	}
	switch t := v.(type) {
	case nil:
		return 0
	case bool:
		if t {
			return 1
		}
		return 0
	case float64:
		return t
	case string:
		s := strings.TrimFunc(t, jsSpace)
		switch {
		case s == "":
			return 0
		case s == "Infinity" || s == "+Infinity":
			return math.Inf(1)
		case s == "-Infinity":
			return math.Inf(-1)
		case jsNumeric.MatchString(s):
			f, _ := strconv.ParseFloat(s, 64)
			return f
		case len(s) > 2 && s[0] == '0' && strings.ContainsRune("xXoObB", rune(s[1])):
			base := map[byte]int{'x': 16, 'o': 8, 'b': 2}[s[1]|0x20]
			if n, err := strconv.ParseUint(s[2:], base, 64); err == nil {
				return float64(n)
			}
		}
		return math.NaN()
	case []any:
		if len(t) == 0 {
			return 0
		}
		if len(t) == 1 {
			return jsToNumber(t[0], true)
		}
	}
	return math.NaN()
}

// boundedInt is toBoundedInt: Number(value) floored and clamped, or fallback
// when it is not a finite number.
func boundedInt(obj map[string]any, key string, fallback, minimum, maximum int) int {
	v, present := obj[key]
	f := jsToNumber(v, present)
	if math.IsNaN(f) || math.IsInf(f, 0) {
		return fallback
	}
	return int(math.Min(float64(maximum), math.Max(float64(minimum), math.Floor(f))))
}
