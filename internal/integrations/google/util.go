package google

import (
	"encoding/json"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
)

// textOf is String(value || ”).
func textOf(v any) string {
	if !integrations.Truthy(v) {
		return ""
	}
	return integrations.Str(v)
}

// trimmed is String(value || ”).trim().
func trimmed(v any) string { return strings.TrimSpace(textOf(v)) }

func orDefault(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

// has reports whether the argument was passed (JavaScript's !== undefined).
func has(args map[string]any, key string) bool {
	_, ok := args[key]
	return ok
}

func jsonUnmarshal(body []byte, out any) error { return json.Unmarshal(body, out) }
