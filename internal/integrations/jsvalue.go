package integrations

import (
	"encoding/json"
	"fmt"
	"math"
	"sort"
	"strconv"
	"strings"
)

// JSNumber is JavaScript's Number(value) for a decoded JSON value; ok is false
// where JavaScript gives NaN.
func JSNumber(v any) (float64, bool) {
	switch t := v.(type) {
	case nil:
		return 0, true
	case bool:
		if t {
			return 1, true
		}
		return 0, true
	case float64:
		return t, !math.IsNaN(t)
	case json.Number:
		f, err := t.Float64()
		return f, err == nil
	case string:
		s := strings.TrimSpace(t)
		if s == "" {
			return 0, true
		}
		f, err := strconv.ParseFloat(s, 64)
		return f, err == nil
	}
	return 0, false
}

// jsText is String(value || ”) for a decoded JSON value.
func jsText(v any) string {
	switch t := v.(type) {
	case nil:
		return ""
	case string:
		return t
	case bool:
		if t {
			return "true"
		}
		return ""
	case float64:
		if t == 0 {
			return ""
		}
		return strconv.FormatFloat(t, 'f', -1, 64)
	case json.Number:
		return t.String()
	case []any:
		parts := make([]string, len(t))
		for i, e := range t {
			parts[i] = jsText(e)
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}

// Get walks nested objects the way `value?.a?.b` does: nil when any step is
// missing or not an object.
func Get(v any, keys ...string) any {
	for _, k := range keys {
		m, ok := v.(map[string]any)
		if !ok {
			return nil
		}
		v = m[k]
	}
	return v
}

// Truthy is JavaScript truthiness of a decoded JSON value.
func Truthy(v any) bool {
	switch t := v.(type) {
	case nil:
		return false
	case bool:
		return t
	case string:
		return t != ""
	case float64:
		return t != 0 && !math.IsNaN(t)
	case json.Number:
		f, err := t.Float64()
		return err != nil || f != 0
	}
	return true
}

// Or is `a || b || c`: the first truthy value, else the last.
func Or(values ...any) any {
	for _, v := range values {
		if Truthy(v) {
			return v
		}
	}
	if len(values) == 0 {
		return nil
	}
	return values[len(values)-1]
}

// Str is String(value ?? ”) for a decoded JSON value.
func Str(v any) string {
	switch t := v.(type) {
	case nil:
		return ""
	case string:
		return t
	case bool:
		if t {
			return "true"
		}
		return "false"
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64)
	case json.Number:
		return t.String()
	case []any:
		parts := make([]string, len(t))
		for i, e := range t {
			parts[i] = Str(e)
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}

// Object decodes a JSON object, keeping numbers as json.Number; anything else
// is an empty object.
func Object(raw []byte) map[string]any {
	dec := json.NewDecoder(strings.NewReader(string(raw)))
	dec.UseNumber()
	var m map[string]any
	if dec.Decode(&m) != nil || m == nil {
		return map[string]any{}
	}
	return m
}

// RequireText is requireText(value, label): the trimmed text or an error.
func RequireText(v any, label string) (string, error) {
	t := strings.TrimSpace(jsText(v))
	if t == "" {
		return "", fmt.Errorf("%s is required.", label)
	}
	return t, nil
}

// Clamp is Math.max(lo, Math.min(Number(v) || def, hi)) as text for a query.
func Clamp(v any, def, lo, hi float64) string {
	n, ok := JSNumber(v)
	if !ok || n == 0 {
		n = def
	}
	return strconv.FormatFloat(math.Max(lo, math.Min(n, hi)), 'f', -1, 64)
}

// SortedKeys lists an object's keys in a stable order, for building query
// strings from model-supplied objects.
func SortedKeys(m map[string]any) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
