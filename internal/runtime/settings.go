package runtime

import (
	"encoding/json"
	"regexp"
)

// Settings are the runtime settings. The shape is fixed; `runtime_backend` is
// the isolation technology TERMINAL_ENV selected.
type Settings struct {
	RuntimeProfile  string `json:"runtime_profile"`
	ComputerBackend string `json:"computer_backend"`
	AndroidBackend  string `json:"android_backend"`
	McpBackend      string `json:"mcp_backend"`
	RuntimeBackend  string `json:"runtime_backend"`
}

// RuntimeSettingKeys are the keys a runtime settings object has, in order.
var RuntimeSettingKeys = []string{"runtime_profile", "computer_backend", "android_backend", "mcp_backend", "runtime_backend"}

// RuntimeSettings returns the fixed settings for a TERMINAL_ENV value.
func RuntimeSettings(terminalEnv string) Settings {
	return Settings{
		RuntimeProfile:  "cloud-computer",
		ComputerBackend: "cloud",
		AndroidBackend:  "host",
		McpBackend:      "host-remote",
		RuntimeBackend:  string(ParseTerminalEnv(terminalEnv)),
	}
}

// SettingsValidation is the result of validating runtime settings; the
// settings are fixed, so it is always valid.
type SettingsValidation struct {
	Settings Settings `json:"settings"`
	Valid    bool     `json:"valid"`
	Issues   []string `json:"issues"`
}

// ValidateSettings reports the fixed settings as valid.
func ValidateSettings(terminalEnv string) SettingsValidation {
	return SettingsValidation{Settings: RuntimeSettings(terminalEnv), Valid: true, Issues: []string{}}
}

// SerializeSettingValue stores strings as they are and everything else as JSON.
func SerializeSettingValue(value any) (string, error) {
	if s, ok := value.(string); ok {
		return s, nil
	}
	body, err := json.Marshal(value)
	return string(body), err
}

var socialReachCookies = regexp.MustCompile(`(?i)^social_reach_cookies_`)

// RedactSettingValue hides the contents of cookie settings.
func RedactSettingValue(key string, value any) any {
	if socialReachCookies.MatchString(key) {
		return map[string]any{"configured": truthy(value), "redacted": true}
	}
	return value
}

// truthy follows JavaScript: empty strings, zero, false and null are false.
func truthy(value any) bool {
	switch v := value.(type) {
	case nil:
		return false
	case bool:
		return v
	case string:
		return v != ""
	case float64:
		return v != 0
	case int:
		return v != 0
	}
	return true
}
