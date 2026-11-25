package settings

import "strings"

// providerDef is the part of the Node server's AI_PROVIDER_DEFINITIONS the
// settings routes use, in the same order (it decides how configs are written).
type providerDef struct {
	ID              string
	Authentication  string
	SupportsAPIKey  bool
	SupportsBaseURL bool
	RequiresBaseURL bool
	DefaultEnabled  bool
	DefaultBaseURL  string
}

var providers = []providerDef{
	{ID: "openai", Authentication: "api_key", SupportsAPIKey: true, SupportsBaseURL: true, DefaultEnabled: true},
	{ID: "openai-compatible", Authentication: "api_key", SupportsAPIKey: true, SupportsBaseURL: true, RequiresBaseURL: true},
	{ID: "anthropic", Authentication: "api_key", SupportsAPIKey: true, SupportsBaseURL: true},
	{ID: "google", Authentication: "api_key", SupportsAPIKey: true, DefaultEnabled: true},
	{ID: "grok", Authentication: "api_key", SupportsAPIKey: true, SupportsBaseURL: true, DefaultEnabled: true, DefaultBaseURL: "https://api.x.ai/v1"},
	{ID: "grok-oauth", Authentication: "oauth", SupportsAPIKey: true},
	{ID: "nvidia", Authentication: "api_key", SupportsAPIKey: true, SupportsBaseURL: true, DefaultBaseURL: "https://integrate.api.nvidia.com/v1"},
	{ID: "minimax", Authentication: "api_key", SupportsAPIKey: true, SupportsBaseURL: true, DefaultBaseURL: "https://api.minimax.io/anthropic"},
	{ID: "github-copilot", Authentication: "oauth", SupportsAPIKey: true, SupportsBaseURL: true, DefaultBaseURL: "https://api.githubcopilot.com"},
	{ID: "openai-codex", Authentication: "oauth", SupportsAPIKey: true, SupportsBaseURL: true, DefaultBaseURL: "https://chatgpt.com/backend-api/codex"},
	{ID: "claude-code", Authentication: "oauth", SupportsAPIKey: true},
	{ID: "nous", Authentication: "api_key", SupportsAPIKey: true, SupportsBaseURL: true, DefaultBaseURL: "https://inference-api.nousresearch.com/v1"},
	{ID: "openrouter", Authentication: "api_key", SupportsAPIKey: true, SupportsBaseURL: true, DefaultBaseURL: "https://openrouter.ai/api/v1"},
	{ID: "typesafe", Authentication: "api_key", SupportsAPIKey: true},
	{ID: "neorouter", Authentication: "oauth", SupportsAPIKey: true, SupportsBaseURL: true, RequiresBaseURL: true, DefaultEnabled: true},
	{ID: "ollama", Authentication: "local", SupportsBaseURL: true, DefaultEnabled: true, DefaultBaseURL: "http://localhost:11434"},
}

func providerByID(id string) (providerDef, bool) {
	for _, p := range providers {
		if p.ID == id {
			return p, true
		}
	}
	return providerDef{}, false
}

// byokEligible: providers a user can bring a pasted key for. OAuth logins and
// MiniMax's account-bound plan have no place in self-service credentials.
func (p providerDef) byokEligible() bool {
	return p.Authentication != "oauth" && p.ID != "minimax"
}

// baseURLRequired: a provider without an API key concept (Ollama) is only ever
// "yours" through its own address.
func (p providerDef) baseURLRequired() bool { return p.RequiresBaseURL || !p.SupportsAPIKey }

type providerConfig struct {
	Enabled bool
	BaseURL string
	Label   string
}

// providerConfigs is the ai_provider_configs setting. It marshals as an object
// in provider order, as the Node server wrote it.
type providerConfigs []providerConfig

func (c providerConfigs) MarshalJSON() ([]byte, error) {
	var b strings.Builder
	b.WriteByte('{')
	for i, p := range providers {
		if i > 0 {
			b.WriteByte(',')
		}
		b.Write(jsonText(p.ID))
		b.WriteString(`:{"enabled":`)
		b.Write(jsonText(c[i].Enabled))
		b.WriteString(`,"baseUrl":`)
		b.Write(jsonText(c[i].BaseURL))
		b.WriteString(`,"label":`)
		b.Write(jsonText(c[i].Label))
		b.WriteByte('}')
	}
	b.WriteByte('}')
	return []byte(b.String()), nil
}

const maxProviderLabel = 80

// normalizeProviderConfigs reads a stored ai_provider_configs value (anything
// that is not an object counts as empty) into one entry per known provider.
func normalizeProviderConfigs(stored any) providerConfigs {
	parsed, _ := stored.(map[string]any)
	out := make(providerConfigs, len(providers))
	for i, p := range providers {
		entry, _ := parsed[p.ID].(map[string]any)
		baseURL, _ := entry["baseUrl"].(string)
		label, _ := entry["label"].(string)
		out[i] = providerConfig{
			Enabled: enabledFlag(entry["enabled"]),
			BaseURL: jsTrim(baseURL),
			Label:   truncateUTF16(jsTrim(label), maxProviderLabel),
		}
		out[i].BaseURL = p.resolveBaseURL(out[i].BaseURL)
	}
	return out
}

// resolveBaseURL: a provider without base URL support has none; an empty one
// falls back to the provider's default.
func (p providerDef) resolveBaseURL(baseURL string) string {
	if !p.SupportsBaseURL {
		return ""
	}
	if baseURL == "" {
		return p.DefaultBaseURL
	}
	return baseURL
}

// enabledFlag is `enabled !== false && enabled !== 'false' && enabled !== 0`.
func enabledFlag(v any) bool {
	switch v := v.(type) {
	case bool:
		return v
	case string:
		return v != "false"
	case float64:
		return v != 0
	}
	return true
}

// defaultProviderConfigsJSON is what a new agent starts with: only enabled and
// baseUrl, as createDefaultProviderConfigs wrote them.
func defaultProviderConfigsJSON() string {
	var b strings.Builder
	b.WriteByte('{')
	for i, p := range providers {
		if i > 0 {
			b.WriteByte(',')
		}
		baseURL := ""
		if p.SupportsBaseURL {
			baseURL = p.DefaultBaseURL
		}
		b.Write(jsonText(p.ID))
		b.WriteString(`:{"enabled":`)
		b.Write(jsonText(p.DefaultEnabled))
		b.WriteString(`,"baseUrl":`)
		b.Write(jsonText(baseURL))
		b.WriteByte('}')
	}
	b.WriteByte('}')
	return b.String()
}

// aiDefault is one agent setting every agent starts with, as JSON text.
type aiDefault struct{ Key, JSON string }

// aiDefaults mirrors createDefaultAiSettings, in order.
var aiDefaults = []aiDefault{
	{"cost_mode", `"balanced_auto"`},
	{"chat_history_window", `20`},
	{"tool_replay_budget_chars", `12000`},
	{"tool_replay_budget_file_chars", `null`},
	{"tool_replay_budget_browser_chars", `null`},
	{"tool_replay_budget_command_chars", `null`},
	{"max_consecutive_read_only_iterations", `null`},
	{"max_consecutive_tool_failures", `null`},
	{"subagent_max_children_per_run", `10`},
	{"assistant_behavior_notes", `""`},
	{"auto_skill_learning", `true`},
	{"system_one_model", `"off"`},
	{"enabled_models", `[]`},
	{"default_chat_model", `"auto"`},
	{"default_subagent_model", `"auto"`},
	{"default_speech_model", `"auto"`},
	{"task_models", `{}`},
	{"ai_provider_configs", defaultProviderConfigsJSON()},
	{"voice_stt_provider", `"auto"`},
	{"voice_stt_model", `""`},
	{"voice_live_provider", `""`},
	{"voice_live_model", `""`},
	{"voice_live_voice", `""`},
	{"voice_input_mode", `"hands_free"`},
	{"neorouter_roles", `null`},
}

// normalizeSystemOneModel: anything other than "auto" or a provider-scoped
// model id (provider::model) reads as "off".
func normalizeSystemOneModel(v any) string {
	selection := ""
	if v != nil {
		selection = jsTrim(jsString(v))
	}
	if selection == "auto" || isModelSelectionID(selection) {
		return selection
	}
	return "off"
}

func isModelSelectionID(raw string) bool {
	sep := strings.Index(raw, "::")
	if sep <= 0 {
		return false
	}
	provider := strings.ToLower(jsTrim(raw[:sep]))
	modelID := jsTrim(raw[sep+2:])
	return provider != "" && modelID != "" && modelID != "auto"
}
