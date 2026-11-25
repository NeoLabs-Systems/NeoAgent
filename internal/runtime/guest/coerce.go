package guest

import (
	"encoding/json"
	"math"
	"strconv"
	"strings"
	"unicode/utf16"
)

// number reads a request field like JavaScript's Number(value): absent is
// NaN, null is 0, numeric text is its value.
func number(body map[string]any, key string) float64 {
	v, ok := body[key]
	if !ok {
		return math.NaN()
	}
	return toNumber(v)
}

func toNumber(v any) float64 {
	switch x := v.(type) {
	case nil:
		return 0
	case json.Number:
		f, err := x.Float64()
		if err != nil {
			return math.NaN()
		}
		return f
	case float64:
		return x
	case bool:
		if x {
			return 1
		}
		return 0
	case string:
		t := strings.TrimSpace(x)
		if t == "" {
			return 0
		}
		f, err := strconv.ParseFloat(t, 64)
		if err != nil {
			return math.NaN()
		}
		return f
	}
	return math.NaN()
}

// truthy is JavaScript truthiness for decoded JSON.
func truthy(v any) bool {
	switch x := v.(type) {
	case nil:
		return false
	case bool:
		return x
	case string:
		return x != ""
	case json.Number:
		f, _ := x.Float64()
		return f != 0 && !math.IsNaN(f)
	case float64:
		return x != 0 && !math.IsNaN(x)
	}
	return true
}

// text is String(value || ""): falsy values are empty, the rest their text.
func text(body map[string]any, keys ...string) string {
	for _, key := range keys {
		if v := body[key]; truthy(v) {
			return stringOf(v)
		}
	}
	return ""
}

func stringOf(v any) string {
	switch x := v.(type) {
	case string:
		return x
	case json.Number:
		return x.String()
	case bool:
		return strconv.FormatBool(x)
	case nil:
		return ""
	}
	body, _ := json.Marshal(v)
	return string(body)
}

// round is Math.round: halves go up.
func round(f float64) int { return int(math.Floor(f + 0.5)) }

func finite(f float64) bool { return !math.IsNaN(f) && !math.IsInf(f, 0) }

// utf16Len is a string's JavaScript length.
func utf16Len(s string) int { return len(utf16.Encode([]rune(s))) }

// utf16Prefix is s.slice(0, n).
func utf16Prefix(s string, n int) string {
	units := utf16.Encode([]rune(s))
	if len(units) <= n {
		return s
	}
	return string(utf16.Decode(units[:n]))
}

func trimSpace(s string) string { return strings.TrimSpace(s) }
