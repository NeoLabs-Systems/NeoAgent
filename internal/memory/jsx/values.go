package jsx

import (
	"encoding/json"
	"math"
	"strconv"
	"strings"
	"time"
	"unicode"
)

type undefinedType struct{}

// Undefined is JavaScript's undefined, as opposed to nil for null.
var Undefined any = undefinedType{}

// Lookup is o[key]: Undefined when the key is absent.
func (o *Obj) Lookup(key string) any {
	if v, ok := o.Get(key); ok {
		return v
	}
	return Undefined
}

// Nullish is v == null.
func Nullish(v any) bool {
	if v == nil {
		return true
	}
	_, undefined := v.(undefinedType)
	return undefined
}

// Coalesce is `a ?? b ?? c`: the first value that is not nullish, else the last.
func Coalesce(values ...any) any {
	for i, v := range values {
		if i == len(values)-1 || !Nullish(v) {
			return v
		}
	}
	return Undefined
}

// Or is `a || b || c`: the first truthy value, else the last.
func Or(values ...any) any {
	for i, v := range values {
		if i == len(values)-1 || Truthy(v) {
			return v
		}
	}
	return Undefined
}

// ToNumber is Number(v).
func ToNumber(v any) float64 {
	switch t := v.(type) {
	case nil:
		return 0
	case undefinedType:
		return math.NaN()
	case bool:
		if t {
			return 1
		}
		return 0
	case float64:
		return t
	case int:
		return float64(t)
	case int64:
		return float64(t)
	case json.Number:
		f, _ := t.Float64()
		return f
	case string:
		return stringToNumber(t)
	case []any:
		if len(t) == 0 {
			return 0
		}
		if len(t) == 1 {
			return ToNumber(ToString(t[0]))
		}
	}
	return math.NaN()
}

func stringToNumber(s string) float64 {
	s = Trim(s)
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
		base := 0
		switch s[1] {
		case 'x', 'X':
			base = 16
		case 'o', 'O':
			base = 8
		case 'b', 'B':
			base = 2
		}
		if base != 0 {
			n, err := strconv.ParseUint(s[2:], base, 64)
			if err != nil {
				return math.NaN()
			}
			return float64(n)
		}
	}
	for _, c := range s {
		if !(c >= '0' && c <= '9' || c == '.' || c == 'e' || c == 'E' || c == '+' || c == '-') {
			return math.NaN()
		}
	}
	f, err := strconv.ParseFloat(s, 64)
	if err != nil && !math.IsInf(f, 0) {
		return math.NaN()
	}
	return f
}

// IsFinite is Number.isFinite(f).
func IsFinite(f float64) bool { return !math.IsNaN(f) && !math.IsInf(f, 0) }

// ToString is String(v).
func ToString(v any) string {
	switch t := v.(type) {
	case nil:
		return "null"
	case undefinedType:
		return "undefined"
	case bool:
		return strconv.FormatBool(t)
	case float64:
		if math.IsNaN(t) {
			return "NaN"
		}
		if math.IsInf(t, 1) {
			return "Infinity"
		}
		if math.IsInf(t, -1) {
			return "-Infinity"
		}
		return FormatNumber(t)
	case int:
		return strconv.Itoa(t)
	case int64:
		return strconv.FormatInt(t, 10)
	case string:
		return t
	case []any:
		parts := make([]string, len(t))
		for i, item := range t {
			if !Nullish(item) {
				parts[i] = ToString(item)
			}
		}
		return strings.Join(parts, ",")
	case *Obj:
		return "[object Object]"
	}
	return "[object Object]"
}

// StrOr is String(v || ”).
func StrOr(v any) string {
	if !Truthy(v) {
		return ""
	}
	return ToString(v)
}

// Clamp is Math.max(min, Math.min(max, Number(value))) with the fallback for
// a value that is not a number, as the retention helpers write it.
func Clamp(value any, min, max, fallback float64) float64 {
	n := ToNumber(value)
	if !IsFinite(n) {
		return fallback
	}
	return math.Max(min, math.Min(max, n))
}

// Lower is String.prototype.toLowerCase.
func Lower(s string) string {
	if isASCII(s) {
		return strings.ToLower(s)
	}
	runes := []rune(s)
	var b strings.Builder
	for i, r := range runes {
		switch {
		case r == 0x130:
			b.WriteString("i̇")
		case r == 0x3a3 && finalSigma(runes, i):
			b.WriteRune('ς')
		default:
			b.WriteRune(unicode.ToLower(r))
		}
	}
	return b.String()
}

func isCased(r rune) bool { return unicode.IsUpper(r) || unicode.IsLower(r) || unicode.IsTitle(r) }

func isCaseIgnorable(r rune) bool {
	return unicode.In(r, unicode.Mn, unicode.Me, unicode.Cf, unicode.Lm, unicode.Sk) || r == '\'' || r == '.' || r == ':' || r == 0xb7 || r == 0x2019
}

// finalSigma is the Final_Sigma condition of Unicode special casing.
func finalSigma(runes []rune, i int) bool {
	before := false
	for j := i - 1; j >= 0; j-- {
		if isCaseIgnorable(runes[j]) {
			continue
		}
		before = isCased(runes[j])
		break
	}
	if !before {
		return false
	}
	for j := i + 1; j < len(runes); j++ {
		if isCaseIgnorable(runes[j]) {
			continue
		}
		return !isCased(runes[j])
	}
	return true
}

var specialUpper = map[rune]string{
	'ß': "SS", 'ŉ': "ʼN", 'ǰ': "J̌", 'ΐ': "Ϊ́", 'ΰ': "Ϋ́", 'և': "ԵՒ",
	'ẖ': "H̱", 'ẗ': "T̈", 'ẘ': "W̊", 'ẙ': "Y̊", 'ẚ': "Aʾ",
	'ﬀ': "FF", 'ﬁ': "FI", 'ﬂ': "FL", 'ﬃ': "FFI", 'ﬄ': "FFL", 'ﬅ': "ST", 'ﬆ': "ST",
}

// Upper is String.prototype.toUpperCase.
func Upper(s string) string {
	if isASCII(s) {
		return strings.ToUpper(s)
	}
	var b strings.Builder
	for _, r := range s {
		if special, ok := specialUpper[r]; ok {
			b.WriteString(special)
		} else {
			b.WriteRune(unicode.ToUpper(r))
		}
	}
	return b.String()
}

// ISO is new Date(ms).toISOString().
func ISO(t time.Time) string {
	return t.UTC().Format("2006-01-02T15:04:05.000Z")
}
