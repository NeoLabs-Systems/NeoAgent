package tools

import (
	"encoding/json"
	"math"
	"regexp"
	"slices"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// Models send values in a near miss of the declared type: "5.0" for an
// integer, "true" for a boolean, a JSON string for an array, "Recurring" for
// "recurring". Each is fixed here, against the tool's own schema, before the
// call is checked or run; anything that is not an unambiguous near miss is left
// for the tool to reject.

var (
	numberText  = regexp.MustCompile(`^-?\d+(\.\d+)?$`)
	booleanText = regexp.MustCompile(`(?i)^(true|false)$`)
)

func typesOf(schema map[string]any) []string {
	switch t := schema["type"].(type) {
	case string:
		if t != "" {
			return []string{t}
		}
	case []any:
		var types []string
		for _, v := range t {
			if s, ok := v.(string); ok {
				types = append(types, s)
			}
		}
		return types
	}
	return nil
}

func coerceValue(value any, schema map[string]any) any {
	types := typesOf(schema)
	enum, hasEnum := schema["enum"].([]any)
	if len(types) == 0 && schema["enum"] == nil {
		return value
	}
	hasType := func(t string) bool { return slices.Contains(types, t) }

	switch v := value.(type) {
	case string:
		text := textx.Trim(v)
		if (hasType("integer") || hasType("number")) && !hasType("string") && numberText.MatchString(text) {
			number, _ := strconv.ParseFloat(text, 64)
			if !hasType("integer") || number == math.Trunc(number) {
				return number
			}
		}
		if hasType("boolean") && !hasType("string") && booleanText.MatchString(text) {
			return strings.EqualFold(text, "true")
		}
		if (hasType("array") || hasType("object")) && !hasType("string") && (strings.HasPrefix(text, "[") || strings.HasPrefix(text, "{")) {
			var parsed any
			if err := json.Unmarshal([]byte(text), &parsed); err != nil {
				return value
			}
			return coerceValue(parsed, schema)
		}
		if hasEnum && !enumContains(enum, v) {
			for _, option := range enum {
				if s, ok := option.(string); ok && strings.EqualFold(s, text) {
					return s
				}
			}
		}
		return value
	case float64:
		if len(types) == 1 && types[0] == "string" {
			return numberString(v)
		}
	case bool:
		if len(types) == 1 && types[0] == "string" {
			return strconv.FormatBool(v)
		}
	case []any:
		if items, ok := schema["items"].(map[string]any); ok {
			out := make([]any, len(v))
			for i, item := range v {
				out[i] = coerceValue(item, items)
			}
			return out
		}
	case map[string]any:
		if _, ok := schema["properties"].(map[string]any); ok {
			return CoerceArgs(v, schema)
		}
	}
	return value
}

func enumContains(enum []any, value string) bool {
	for _, option := range enum {
		if s, ok := option.(string); ok && s == value {
			return true
		}
	}
	return false
}

// numberString is String(number) for the values models send.
func numberString(n float64) string {
	if n == math.Trunc(n) && math.Abs(n) < 1e21 {
		return strconv.FormatFloat(n, 'f', -1, 64)
	}
	return strconv.FormatFloat(n, 'g', -1, 64)
}

// CoerceArgs fixes near-miss argument values against the tool's schema and
// returns the repaired copy; args itself is not modified.
func CoerceArgs(args map[string]any, schema map[string]any) map[string]any {
	properties, ok := schema["properties"].(map[string]any)
	if args == nil || !ok {
		return args
	}
	coerced := make(map[string]any, len(args))
	for k, v := range args {
		coerced[k] = v
	}
	for key, property := range properties {
		prop, isObject := property.(map[string]any)
		if _, present := coerced[key]; present && isObject {
			coerced[key] = coerceValue(coerced[key], prop)
		}
	}
	return coerced
}

// MissingRequiredArgs lists the arguments the schema requires that the call
// left out. No coercion can supply those.
func MissingRequiredArgs(args map[string]any, schema map[string]any) []string {
	required, _ := schema["required"].([]any)
	var missing []string
	for _, r := range required {
		key, _ := r.(string)
		if v, ok := args[key]; !ok || v == nil {
			missing = append(missing, key)
		}
	}
	return missing
}
