package android

import (
	"math"
	"strconv"
	"strings"
)

// Params is a request body kept as decoded JSON, because the Node API reads
// loosely typed fields (a coordinate may arrive as 100 or "100").
type Params map[string]any

// number follows JavaScript's Number(): ok is false for NaN (a missing field,
// non-numeric text, or an object).
func number(v any, present bool) (float64, bool) {
	if !present {
		return 0, false
	}
	switch x := v.(type) {
	case nil:
		return 0, true
	case bool:
		if x {
			return 1, true
		}
		return 0, true
	case float64:
		return x, !math.IsNaN(x)
	case string:
		t := strings.TrimSpace(x)
		if t == "" {
			return 0, true
		}
		f, err := strconv.ParseFloat(t, 64)
		return f, err == nil && !math.IsNaN(f)
	}
	return 0, false
}

func (p Params) number(key string) (float64, bool) {
	v, ok := p[key]
	return number(v, ok)
}

// finite is JavaScript's Number.isFinite(Number(p[key])).
func (p Params) finite(key string) bool {
	f, ok := p.number(key)
	return ok && !math.IsInf(f, 0)
}

// text is String(p[key] || ”): falsy values read as empty.
func (p Params) text(key string) string {
	switch x := p[key].(type) {
	case nil:
		return ""
	case string:
		return x
	case bool:
		if x {
			return "true"
		}
		return ""
	case float64:
		if x == 0 || math.IsNaN(x) {
			return ""
		}
		return jsNumberString(x)
	}
	return "[object Object]"
}

func jsNumberString(f float64) string {
	if f == math.Trunc(f) && math.Abs(f) < 1e21 {
		return strconv.FormatFloat(f, 'f', -1, 64)
	}
	return strconv.FormatFloat(f, 'g', -1, 64)
}

// truthy is JavaScript truthiness.
func truthy(v any) bool {
	switch x := v.(type) {
	case nil:
		return false
	case bool:
		return x
	case float64:
		return x != 0 && !math.IsNaN(x)
	case string:
		return x != ""
	}
	return true
}

// clamp is the Node clampNumber helper: non-finite input takes the fallback,
// everything else is rounded and bounded.
func clamp(v float64, ok bool, fallback, lo, hi int) int {
	if !ok || math.IsInf(v, 0) {
		return fallback
	}
	return min(hi, max(lo, int(math.Floor(v+0.5))))
}

func (p Params) clamped(key string, fallback, lo, hi int) int {
	v, ok := p.number(key)
	return clamp(v, ok, fallback, lo, hi)
}

// selector reads the UI selector fields. textKey lets type() name its text
// selector "textSelector".
func (p Params) selector(textKey string) Selector {
	return Selector{
		Text: p.text(textKey), ResourceID: p.text("resourceId"), Description: p.text("description"),
		ClassName: p.text("className"), PackageName: p.text("packageName"), Clickable: p["clickable"] == true,
	}
}

// defined is the selector as JSON.stringify would print it: only the fields
// that were given.
func (s Selector) defined() map[string]any {
	out := map[string]any{}
	for k, v := range map[string]string{
		"text": s.Text, "resourceId": s.ResourceID, "description": s.Description,
		"className": s.ClassName, "packageName": s.PackageName,
	} {
		if v != "" {
			out[k] = v
		}
	}
	return out
}

// jsString is JavaScript's String(v).
func jsString(v any) string {
	switch x := v.(type) {
	case nil:
		return "null"
	case string:
		return x
	case bool:
		return strconv.FormatBool(x)
	case float64:
		return jsNumberString(x)
	case []any:
		parts := make([]string, len(x))
		for i, e := range x {
			if e != nil {
				parts[i] = jsString(e)
			}
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}
