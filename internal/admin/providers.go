package admin

import (
	"net/http"
	"net/url"
	"os"
	"strings"
)

type providerSetting struct{ key, label, kind string }

var providerSettings = []providerSetting{
	{"ANTHROPIC_API_KEY", "Anthropic (Claude)", "key"},
	{"OPENAI_API_KEY", "OpenAI", "key"},
	{"OPENAI_COMPATIBLE_API_KEY", "Custom OpenAI-compatible token", "key"},
	{"OPENAI_COMPATIBLE_BASE_URL", "Custom OpenAI-compatible base URL", "url"},
	{"XAI_API_KEY", "xAI (Grok)", "key"},
	{"GOOGLE_AI_KEY", "Google (Gemini)", "key"},
	{"MINIMAX_API_KEY", "MiniMax", "key"},
	{"NVIDIA_API_KEY", "NVIDIA NIM", "key"},
	{"OPENROUTER_API_KEY", "OpenRouter", "key"},
	{"NOUS_API_KEY", "Nous Portal", "key"},
	{"TYPESAFE_API_KEY", "TypeSafe (SystemOne)", "key"},
	{"BRAVE_SEARCH_API_KEY", "Brave Search", "key"},
	{"DEEPGRAM_API_KEY", "Deepgram (Voice)", "key"},
	{"GITHUB_COPILOT_ACCESS_TOKEN", "GitHub Copilot", "key"},
	{"OPENAI_CODEX_ACCESS_TOKEN", "OpenAI Codex", "key"},
	{"OLLAMA_URL", "Ollama (Local)", "url"},
	{"OPENAI_BASE_URL", "OpenAI Base URL override", "url"},
	{"ANTHROPIC_BASE_URL", "Anthropic Base URL override", "url"},
	{"XAI_BASE_URL", "xAI Base URL override", "url"},
}

func (a *API) getProviders(_ *http.Request) (any, error) {
	providers := make([]map[string]any, 0, len(providerSettings))
	for _, p := range providerSettings {
		value := os.Getenv(p.key)
		hint := value
		if p.kind == "key" {
			chars := []rune(value)
			if len(chars) <= 8 {
				hint = strings.Repeat("•", len(chars))
			} else {
				hint = string(chars[:4]) + "••••" + string(chars[len(chars)-4:])
			}
		}
		providers = append(providers, map[string]any{"key": p.key, "label": p.label, "type": p.kind, "configured": value != "", "hint": hint})
	}
	return map[string]any{"providers": providers}, nil
}
func (a *API) putProviders(r *http.Request) (any, error) {
	body, err := readBody(r)
	if err != nil {
		return nil, err
	}
	key := strVal(body["key"])
	for _, p := range providerSettings {
		if p.key != key {
			continue
		}
		value := cleanLine(body["value"])
		if p.kind == "url" && value != "" {
			u, err := url.Parse(value)
			if err != nil || u.Hostname() == "" {
				return nil, fail(http.StatusBadRequest, "Provider URL must be a valid HTTP or HTTPS URL", "")
			}
			if u.Scheme != "http" && u.Scheme != "https" {
				return nil, fail(http.StatusBadRequest, "Provider URL must use HTTP or HTTPS", "")
			}
			if u.User != nil {
				return nil, fail(http.StatusBadRequest, "Provider URL must not contain embedded credentials", "")
			}
		}
		if err := a.Settings.Env.Persist(key, value); err != nil {
			return nil, err
		}
		if value != "" && a.extra.MarkSetupSection != nil {
			if err := a.extra.MarkSetupSection("providers"); err != nil {
				return nil, err
			}
		}
		return map[string]any{"ok": true}, nil
	}
	return nil, fail(http.StatusBadRequest, "Unknown provider key", "")
}
