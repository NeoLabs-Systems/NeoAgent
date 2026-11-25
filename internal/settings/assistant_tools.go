package settings

import (
	"context"
	"errors"
	"strings"
)

// The app-settings tools (integrated_tools/app_settings.js): settings_read,
// settings_update and settings_link.

// Integration is one official integration as settings_read lists it.
type Integration struct {
	Key, Label           string
	Connected, Available bool
}

// Integrations lists the integrations of an agent and every integration key.
type Integrations interface {
	List(ctx context.Context, userID int64, agentID string) ([]Integration, error)
	Keys() []string
}

// AssistantTools answers the three app-settings tools.
type AssistantTools struct {
	Assistant    *Assistant
	Integrations Integrations
	// Changed tells the user's clients that a setting changed.
	Changed func(userID int64, agentID, key string)
}

// Places is the map of app places settings_link can open, with links.
func (t *AssistantTools) Places() map[string]any {
	base := t.Assistant.baseURL()
	sections := map[string]any{}
	for _, s := range AppSections {
		if s.Name == "settings" {
			continue
		}
		link, _ := BuildAppLink(base, s.Name, "", "", nil)
		sections[s.Name] = map[string]any{"summary": s.Summary, "link": link}
	}
	pages := map[string]any{}
	for _, p := range SettingsPages {
		link, _ := BuildAppLink(base, "settings", p.Name, "", nil)
		pages[p.Name] = map[string]any{"summary": p.Summary, "anchors": p.Anchors, "link": link}
	}
	return map[string]any{"sections": sections, "settingsPages": pages}
}

func (t *AssistantTools) integrations(ctx context.Context, uid int64, aid string) ([]map[string]any, error) {
	out := []map[string]any{}
	if t.Integrations == nil {
		return out, nil
	}
	list, err := t.Integrations.List(ctx, uid, aid)
	if err != nil {
		return nil, err
	}
	base := t.Assistant.baseURL()
	for _, i := range list {
		link, _ := BuildAppLink(base, "integrations", "", i.Key, []string{i.Key})
		out = append(out, map[string]any{"key": i.Key, "label": i.Label, "connected": i.Connected, "available": i.Available, "link": link})
	}
	return out, nil
}

// Read is settings_read.
func (t *AssistantTools) Read(ctx context.Context, uid int64, aid string, args map[string]any) (any, error) {
	var keys []string
	if list, ok := args["keys"].([]any); ok {
		for _, k := range list {
			keys = append(keys, text(k))
		}
	}
	search, _ := args["search"].(string)
	settings, err := t.Assistant.Read(ctx, uid, aid, keys, search)
	if err != nil {
		return nil, err
	}
	integrations, err := t.integrations(ctx, uid, aid)
	if err != nil {
		return nil, err
	}
	return map[string]any{"settings": settings, "integrations": integrations, "places": t.Places()}, nil
}

// Update is settings_update.
func (t *AssistantTools) Update(ctx context.Context, uid int64, aid string, args map[string]any) (any, error) {
	key := ""
	if args["key"] != nil {
		key = text(args["key"])
	}
	result, err := t.Assistant.Update(ctx, uid, aid, key, args["value"])
	if err != nil {
		return nil, err
	}
	if result["success"] == true && t.Changed != nil {
		t.Changed(uid, aid, result["key"].(string))
	}
	return result, nil
}

// linkArguments come back with a rejected link, so a call made without the
// schema can be corrected.
func linkArguments() map[string]any {
	return map[string]any{
		"section": strings.Join(sectionNames(), " | "),
		"page":    "settings page when section is settings: " + strings.Join(pageNames(), " | "),
		"focus":   "optional: an anchor of that settings page, or an integration key",
	}
}

// Link is settings_link.
func (t *AssistantTools) Link(_ context.Context, args map[string]any) (any, error) {
	var keys []string
	if t.Integrations != nil {
		keys = t.Integrations.Keys()
	}
	str := func(k string) string { s, _ := args[k].(string); return s }
	url, err := BuildAppLink(t.Assistant.baseURL(), str("section"), str("page"), str("focus"), keys)
	var invalid *LinkError
	if errors.As(err, &invalid) {
		return map[string]any{"success": false, "error": invalid.Msg, "expected": linkArguments()}, nil
	}
	if err != nil {
		return nil, err
	}
	return map[string]any{"url": url}, nil
}
