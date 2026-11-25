package wiring

import (
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
)

// The settings the agent may change itself, in the order settings_read lists them.
var assistantSettingKeys = []any{"default_chat_model", "system_one_model", "assistant_behavior_notes", "voice_input_mode", "voice_live_provider",
	"voice_live_voice", "ui_language", "timezone"}

func names[T any](list []T, name func(T) string) []any {
	out := make([]any, len(list))
	for i, v := range list {
		out[i] = name(v)
	}
	return out
}

// integratedDefinitions are the integrated tools: the app's own settings, and
// the SynthID detector when Google Cloud credentials are configured.
func integratedDefinitions(getenv func(string) string) []tools.Definition {
	defs := []map[string]any{
		{
			"name": "settings_read", "family": "app_settings", "access": "read",
			"description": "Read NeoAgent's own settings you can change (chat model, persona notes, voice, language, time zone) with values, choices and app links; which integrations are connected; and the map of app places settings_link can open. Call it first when the user asks about configuring NeoAgent.",
			"parameters": map[string]any{"type": "object", "properties": map[string]any{
				"keys":   map[string]any{"type": "array", "items": map[string]any{"type": "string", "enum": assistantSettingKeys}, "description": "Only these settings. Omit for all."},
				"search": map[string]any{"type": "string", "description": `Filter the listed choices, for example "claude" or "sonnet" when looking for a model.`},
			}},
		},
		{
			"name": "settings_update", "family": "app_settings", "access": "write",
			"description": "Change one NeoAgent setting the user asked for. Only the listed keys; for anything else (security, permissions, API keys, runtimes, account, theme, connecting platforms or integrations) use settings_link. Tell the user what changed, with the returned link.",
			"parameters": map[string]any{"type": "object", "properties": map[string]any{
				"key":   map[string]any{"type": "string", "enum": assistantSettingKeys, "description": "The setting to change."},
				"value": map[string]any{"type": "string", "description": "The new value, exactly as listed in settings_read choices where the setting has them."},
			}, "required": []any{"key", "value"}},
		},
		{
			"name": "settings_link", "family": "app_settings", "access": "read",
			"description": "Link the user to the place in the NeoAgent app where they connect or set up an integration or messaging platform, or change security, permissions, API keys, theme, or any setting you cannot change yourself. settings_read lists the places. Put the url in your reply as a markdown link.",
			"parameters": map[string]any{"type": "object", "properties": map[string]any{
				"section": map[string]any{"type": "string", "enum": names(settings.AppSections, func(s settings.AppSection) string { return s.Name }), "description": "Where the link goes."},
				"page":    map[string]any{"type": "string", "enum": names(settings.SettingsPages, func(p settings.SettingsPage) string { return p.Name }), "description": "Settings page, when section is settings."},
				"focus": map[string]any{"type": "string",
					"description": "Optional. On a settings page, the setting to scroll to (an anchor of that page). For integrations, the integration key to open, from settings_read."},
			}, "required": []any{"section"}},
		},
	}
	if synthIDAvailable(getenv) {
		defs = append(defs, map[string]any{
			"name": "detect_synthid_watermark", "access": "read",
			"description": "Check a PNG or JPEG image for Google's invisible SynthID watermark using the official Vertex AI detector. A negative result does not prove that an image is human-made or not AI-generated.",
			"parameters": map[string]any{"type": "object", "properties": map[string]any{
				"image_path": map[string]any{"type": "string", "description": "Workspace image path, owned artifact path, artifact ID, or artifact content URL."},
			}, "required": []any{"image_path"}},
		})
	}
	out := make([]tools.Definition, 0, len(defs))
	for _, raw := range defs {
		if d, ok := definitionFrom(raw); ok {
			out = append(out, d)
		}
	}
	return out
}

func synthIDAvailable(getenv func(string) string) bool {
	text := func(k string) string { return strings.TrimSpace(getenv(k)) }
	apiKey := text("GOOGLE_AI_KEY")
	if apiKey == "" {
		apiKey = text("GOOGLE_API_KEY")
	}
	credentialFile := ""
	adc := ""
	if runtime.GOOS == "windows" {
		if appData := text("APPDATA"); appData != "" {
			adc = filepath.Join(appData, "gcloud", "application_default_credentials.json")
		}
	} else if home, err := os.UserHomeDir(); err == nil {
		adc = filepath.Join(home, ".config", "gcloud", "application_default_credentials.json")
	}
	for _, candidate := range []string{text("GOOGLE_APPLICATION_CREDENTIALS"), adc} {
		if candidate == "" {
			continue
		}
		if info, err := os.Stat(candidate); err == nil && info.Mode().IsRegular() {
			credentialFile = candidate
			break
		}
	}
	project := text("GOOGLE_CLOUD_PROJECT")
	for _, k := range []string{"GCLOUD_PROJECT", "GCP_PROJECT"} {
		if project == "" {
			project = text(k)
		}
	}
	if project == "" && credentialFile != "" {
		if raw, err := os.ReadFile(credentialFile); err == nil {
			var creds struct {
				ProjectID      string `json:"project_id"`
				QuotaProjectID string `json:"quota_project_id"`
			}
			if json.Unmarshal(raw, &creds) == nil {
				project = strings.TrimSpace(creds.ProjectID)
				if project == "" {
					project = strings.TrimSpace(creds.QuotaProjectID)
				}
			}
		}
	}
	return project != "" && (apiKey != "" || credentialFile != "")
}
