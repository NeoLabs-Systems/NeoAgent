package settings

import (
	"context"
	"encoding/json"
	"errors"
	"regexp"
	"sort"
	"strings"
	"unicode/utf16"

	"github.com/NeoLabs-Systems/neoagent/internal/voice"
)

// Assistant settings (settings/assistant_settings.js): the settings the
// assistant may change for the user. Everything here is reversible and only
// shapes how the assistant behaves; security, access, credentials, runtimes
// and account data stay with the user, who gets a link instead.

// AssistantModels lists the models the model settings offer, each with id,
// label, name, modelId, provider and available.
type AssistantModels interface {
	ChatModels(ctx context.Context, userID int64, agentID string) ([]map[string]any, error)
	SystemOneModels(ctx context.Context, userID int64, agentID string) ([]map[string]any, error)
}

// Assistant reads and changes the assistant-managed settings.
type Assistant struct {
	Store  *Store
	Models AssistantModels
	Voice  voice.Defaults
	// BaseURL is the server's public base URL, for app links.
	BaseURL func() string
}

// Choice is an allowed value of a setting.
type Choice struct {
	Value string `json:"value"`
	Label string `json:"label,omitempty"`
}

type assistantEntry struct {
	key, description string
	page, focus      string
	maxLength        int
	choices          func(a *Assistant, ctx context.Context, userID int64, agentID string) ([]Choice, error)
	alsoSets         map[string]any
}

// UILanguageCodes are the languages the client ships translations for.
var UILanguageCodes = []string{"en", "de", "bg", "hr", "cs", "da", "nl", "et", "fi", "fr", "el", "hu", "ga", "it", "lv", "lt", "mt", "pl", "pt", "ro", "sk", "sl", "es", "sv"}

func modelChoices(list []map[string]any) []Choice {
	var out []Choice
	for _, m := range list {
		if m["available"] == false {
			continue
		}
		label := firstText(m["label"], m["name"], m["modelId"])
		out = append(out, Choice{Value: text(m["id"]), Label: label + " (" + text(m["provider"]) + ")"})
	}
	return out
}

func text(v any) string {
	switch x := v.(type) {
	case string:
		return x
	case nil:
		return "undefined"
	}
	raw, _ := json.Marshal(v)
	return string(raw)
}

func firstText(values ...any) string {
	for _, v := range values {
		if s, ok := v.(string); ok && s != "" {
			return s
		}
	}
	return "undefined"
}

var assistantEntries = []assistantEntry{
	{
		key: "default_chat_model", description: `Model that answers chats. "auto" lets the smart selector pick per message.`,
		page: "models", focus: "chatModel",
		choices: func(a *Assistant, ctx context.Context, uid int64, aid string) ([]Choice, error) {
			list, err := a.Models.ChatModels(ctx, uid, aid)
			if err != nil {
				return nil, err
			}
			return append([]Choice{{"auto", "Automatic"}}, modelChoices(list)...), nil
		},
	},
	{
		key: "system_one_model", description: `Fast model for behind-the-scenes decisions. "off" leaves them to the chat model.`,
		page: "models", focus: "systemOne",
		choices: func(a *Assistant, ctx context.Context, uid int64, aid string) ([]Choice, error) {
			list, err := a.Models.SystemOneModels(ctx, uid, aid)
			if err != nil {
				return nil, err
			}
			return append([]Choice{{"auto", "Automatic"}, {"off", "Off"}}, modelChoices(list)...), nil
		},
	},
	{
		key: "assistant_behavior_notes", description: "Standing persona and behavior instructions for this agent. Replaces the whole text, so include what should stay.",
		page: "behavior", focus: "persona", maxLength: 8000,
	},
	{
		key: "voice_input_mode", description: "How voice conversations take input: hands-free or push-to-talk.",
		page: "voice", focus: "inputMode",
		choices: func(*Assistant, context.Context, int64, string) ([]Choice, error) {
			var out []Choice
			for _, m := range voice.InputModes() {
				out = append(out, Choice{Value: m})
			}
			return out, nil
		},
	},
	{
		key: "voice_live_provider", description: "Live voice provider. Empty follows the server default. Changing it resets the live model and voice.",
		page: "voice", focus: "liveProvider",
		choices: func(*Assistant, context.Context, int64, string) ([]Choice, error) {
			out := []Choice{{"", "Server default"}}
			for _, p := range voice.LiveProviders() {
				out = append(out, Choice{p.ID, p.Label})
			}
			return out, nil
		},
		alsoSets: map[string]any{"voice_live_model": "", "voice_live_voice": ""},
	},
	{
		key: "voice_live_voice", description: "Voice the live voice provider speaks with. Empty uses the provider default.",
		page: "voice", focus: "liveVoice",
		choices: func(a *Assistant, ctx context.Context, uid int64, aid string) ([]Choice, error) {
			stored, err := a.Store.ReadValue(ctx, uid, aid, "voice_live_provider")
			if err != nil {
				return nil, err
			}
			var configured string
			_ = json.Unmarshal(stored, &configured)
			provider, _ := voice.ProviderByID(a.Voice.NormalizeProvider(configured))
			out := []Choice{{"", "Provider default (" + provider.DefaultVoice + ")"}}
			for _, v := range provider.Voices {
				out = append(out, Choice{Value: v})
			}
			return out, nil
		},
	},
	{
		key: "ui_language", description: "Language of the app interface, as a language code.",
		page: "general", focus: "language",
		choices: func(*Assistant, context.Context, int64, string) ([]Choice, error) {
			var out []Choice
			for _, c := range UILanguageCodes {
				out = append(out, Choice{Value: c})
			}
			return out, nil
		},
	},
	{
		key: "timezone", description: "IANA time zone (for example Europe/Berlin) for the assistant's clock and scheduled tasks. Stops following the device's zone.",
		page: "general", focus: "timeZone",
		alsoSets: map[string]any{"timezone_auto": false},
	},
}

const maxListedChoices = 40

// AssistantSettingKeys lists the settings the assistant may change.
func AssistantSettingKeys() []string {
	out := make([]string, len(assistantEntries))
	for i, e := range assistantEntries {
		out[i] = e.key
	}
	return out
}

func entryByKey(key string) *assistantEntry {
	for i := range assistantEntries {
		if assistantEntries[i].key == key {
			return &assistantEntries[i]
		}
	}
	return nil
}

func (a *Assistant) baseURL() string {
	if a.BaseURL == nil {
		return ""
	}
	return a.BaseURL()
}

func (a *Assistant) link(e *assistantEntry) string {
	url, _ := BuildAppLink(a.baseURL(), "settings", e.page, e.focus, nil)
	return url
}

// defaultValue is the createDefaultAiSettings value of a key, or nil.
func defaultValue(key string) json.RawMessage {
	for _, d := range aiDefaults {
		if d.Key == key {
			return json.RawMessage(d.JSON)
		}
	}
	return nil
}

func (a *Assistant) current(ctx context.Context, e *assistantEntry, uid int64, aid string) (any, error) {
	raw, err := a.Store.ReadValue(ctx, uid, aid, e.key)
	if err != nil {
		return nil, err
	}
	if string(raw) == "null" || len(raw) == 0 {
		raw = defaultValue(e.key)
	}
	var v any
	if raw != nil {
		_ = json.Unmarshal(raw, &v)
	}
	return v, nil
}

func searchTerms(search string) []string { return strings.Fields(strings.ToLower(search)) }

func (c Choice) haystack() string { return strings.ToLower(c.Value + " " + c.Label) }

// AssistantSetting describes one setting for settings_read.
type AssistantSetting struct {
	Key         string `json:"key"`
	Description string `json:"description"`
	Value       any    `json:"value"`
	Link        string `json:"link"`
	MaxLength   int    `json:"maxLength,omitempty"`
	// Choices is a []Choice for settings that have them (empty when the
	// search matched none), nil otherwise.
	Choices     any `json:"choices,omitempty"`
	MoreChoices int `json:"moreChoices,omitempty"`
}

// Read is readAssistantSettings: current values, allowed choices and links.
func (a *Assistant) Read(ctx context.Context, uid int64, aid string, keys []string, search string) ([]AssistantSetting, error) {
	var entries []*assistantEntry
	for _, k := range keys {
		if e := entryByKey(k); e != nil {
			entries = append(entries, e)
		}
	}
	if len(keys) == 0 {
		for i := range assistantEntries {
			entries = append(entries, &assistantEntries[i])
		}
	}
	terms := searchTerms(search)
	out := []AssistantSetting{}
	for _, e := range entries {
		value, err := a.current(ctx, e, uid, aid)
		if err != nil {
			return nil, err
		}
		d := AssistantSetting{Key: e.key, Description: e.description, Value: value, Link: a.link(e), MaxLength: e.maxLength}
		if e.choices != nil {
			all, err := e.choices(a, ctx, uid, aid)
			if err != nil {
				return nil, err
			}
			matched := []Choice{}
			for _, c := range all {
				if matchesAll(c.haystack(), terms) {
					matched = append(matched, c)
				}
			}
			d.Choices = matched[:min(len(matched), maxListedChoices)]
			if len(matched) > maxListedChoices {
				d.MoreChoices = len(matched) - maxListedChoices
			}
		}
		out = append(out, d)
	}
	return out, nil
}

func matchesAll(haystack string, terms []string) bool {
	for _, t := range terms {
		if !strings.Contains(haystack, t) {
			return false
		}
	}
	return true
}

var valueWords = regexp.MustCompile(`[^a-z0-9.]+`)

func closestChoices(choices []Choice, value string) []Choice {
	var words []string
	for _, w := range valueWords.Split(strings.ToLower(value), -1) {
		if w != "" {
			words = append(words, w)
		}
	}
	type scored struct {
		c     Choice
		score int
	}
	var list []scored
	for _, c := range choices {
		n := 0
		for _, w := range words {
			if strings.Contains(c.haystack(), w) {
				n++
			}
		}
		if n > 0 {
			list = append(list, scored{c, n})
		}
	}
	sort.SliceStable(list, func(i, j int) bool { return list[i].score > list[j].score })
	out := choices
	if len(list) > 0 {
		out = make([]Choice, len(list))
		for i, s := range list {
			out[i] = s.c
		}
	}
	return out[:min(len(out), 12)]
}

func findAssistantEntry(key string) *assistantEntry {
	name := strings.TrimSpace(key)
	if e := entryByKey(name); e != nil {
		return e
	}
	if name == "" {
		return nil
	}
	var match *assistantEntry
	count := 0
	for i := range assistantEntries {
		if strings.HasSuffix(assistantEntries[i].key, "_"+name) {
			match = &assistantEntries[i]
			count++
		}
	}
	if count == 1 {
		return match
	}
	return nil
}

func utf16Len(s string) int { return len(utf16.Encode([]rune(s))) }

// Update is updateAssistantSetting: it changes one setting through the store
// the settings screen uses. The result is the tool's answer.
func (a *Assistant) Update(ctx context.Context, uid int64, aid, key string, value any) (map[string]any, error) {
	e := findAssistantEntry(key)
	if e == nil {
		return map[string]any{
			"success":  false,
			"error":    `There is no setting "` + key + `" here. Use a key from expected.key (settings_read lists their values); anything not listed there is linked with settings_link instead.`,
			"expected": map[string]any{"key": strings.Join(AssistantSettingKeys(), " | "), "value": "string, as listed by settings_read"},
		}, nil
	}
	requested := ""
	switch v := value.(type) {
	case string:
		requested = strings.TrimSpace(v)
	case nil:
	default:
		requested = text(v)
	}
	next := requested
	if e.choices != nil {
		choices, err := e.choices(a, ctx, uid, aid)
		if err != nil {
			return nil, err
		}
		found := false
		var byModel []Choice
		for _, c := range choices {
			if c.Value == requested {
				found = true
			}
			if strings.HasSuffix(c.Value, "::"+requested) {
				byModel = append(byModel, c)
			}
		}
		switch {
		case found:
		case len(byModel) == 1:
			next = byModel[0].Value
		default:
			return map[string]any{"success": false, "error": `"` + requested + `" is not an option for ` + e.key + ".", "choices": closestChoices(choices, requested)}, nil
		}
	} else if e.maxLength > 0 && utf16Len(requested) > e.maxLength {
		return map[string]any{"success": false, "error": e.key + " is limited to " + itoa(e.maxLength) + " characters."}, nil
	}
	previous, err := a.current(ctx, e, uid, aid)
	if err != nil {
		return nil, err
	}
	patch := Patch{}
	raw, _ := json.Marshal(next)
	patch[e.key] = raw
	for k, v := range e.alsoSets {
		raw, _ := json.Marshal(v)
		patch[k] = raw
	}
	if err := a.Store.Update(ctx, uid, aid, patch, "assistant"); err != nil {
		var invalid *ValidationError
		if errors.As(err, &invalid) {
			return map[string]any{"success": false, "error": err.Error()}, nil
		}
		return nil, err
	}
	stored, err := a.current(ctx, e, uid, aid)
	if err != nil {
		return nil, err
	}
	return map[string]any{"success": true, "key": e.key, "previous": previous, "value": stored, "link": a.link(e)}, nil
}

func itoa(n int) string {
	raw, _ := json.Marshal(n)
	return string(raw)
}
