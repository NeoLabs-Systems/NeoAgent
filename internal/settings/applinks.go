package settings

import (
	"net/url"
	"slices"
	"strings"
)

// App links (settings/app_links.js): URLs that open one place of the NeoAgent
// app. The Flutter client resolves the same names (app_link.dart).

// SettingsPage is one page of the Settings screen.
type SettingsPage struct {
	Name    string
	Summary string
	Anchors []string
}

// SettingsPages lists the Settings pages in the order the app shows them.
var SettingsPages = []SettingsPage{
	{"profile", "Display name, email, data export, data sharing, sign out, delete account.", []string{"displayName", "email", "exportData", "dataSharing", "signOut", "deleteAccount"}},
	{"security", "Password, two-factor, security keys and passkeys, linked sign-in providers, active sessions, QR login.", []string{"password", "twoFactor", "securityKeys", "linkedProviders", "sessions", "qrLogin"}},
	{"usage", "Usage limits and token usage.", []string{"limits", "tokenUsage"}},
	{"agents", "The user's agents (bots): create, rename, delegate, default agent.", []string{"agentList"}},
	{"permissions", "Tool permissions: which tool categories ask for approval, run, or are blocked.", []string{"toolPermissions"}},
	{"computer", "Computer workspace (VM, browser, desktop), shell, Social Reach cookies.", []string{"computerRuntime", "shell", "socialReach"}},
	{"models", "Chat model, model pool, SystemOne models, per-task models, bring-your-own API keys.", []string{"chatModel", "modelPool", "systemOne", "apiKeys"}},
	{"behavior", "Persona and behavior notes, social behavior in group chats.", []string{"persona", "socialBehavior", "turnTaking", "minimumNeed", "batchWindow"}},
	{"voice", "Voice input mode, live voice provider, model and voice, speech-to-text, voice reply model.", []string{"inputMode", "liveProvider", "liveModel", "liveVoice", "speechToText", "voiceReplyModel"}},
	{"messaging", "Messaging platforms (WhatsApp, Telegram, Discord, Signal, Slack, webhooks): linking, group participation, delivery.", []string{"channels", "participation", "delivery"}},
	{"general", "Theme, language, time zone, desktop window and hotkey, location and notification triggers, redo onboarding.", []string{"theme", "language", "timeZone", "closeWindow", "hotkey", "locationTriggers", "notificationTriggers", "onboarding"}},
	{"system", "Server updates and release channel. Desktop app only.", []string{"server"}},
}

// AppSection is a top-level place outside Settings.
type AppSection struct{ Name, Summary string }

// AppSections lists the app's top-level places.
var AppSections = []AppSection{
	{"settings", "Settings, by page."},
	{"integrations", "Official integrations (Google, Microsoft, GitHub, Notion, Slack, ...): connect and manage accounts."},
	{"skills", "Installed skills."},
	{"mcp", "MCP servers."},
	{"tasks", "Scheduled and triggered tasks."},
	{"memory", "Saved memories and core memory."},
	{"devices", "Paired phones, computers and the wearable."},
	{"health", "Synced health data."},
	{"runs", "Past agent runs and logs."},
}

const openPath = "/app/open"

// LinkError is an app link that names no place of the app.
type LinkError struct{ Msg string }

func (e *LinkError) Error() string { return e.Msg }

func sectionNames() []string {
	out := make([]string, len(AppSections))
	for i, s := range AppSections {
		out[i] = s.Name
	}
	return out
}

func pageNames() []string {
	out := make([]string, len(SettingsPages))
	for i, p := range SettingsPages {
		out[i] = p.Name
	}
	return out
}

func findPage(name string) *SettingsPage {
	for i := range SettingsPages {
		if SettingsPages[i].Name == name {
			return &SettingsPages[i]
		}
	}
	return nil
}

// encodeComponent is encodeURIComponent.
func encodeComponent(s string) string {
	return strings.NewReplacer("+", "%20", "%21", "!", "%27", "'", "%28", "(", "%29", ")", "%2A", "*", "%7E", "~").Replace(url.QueryEscape(s))
}

// BuildAppLink is the URL opening a section, a settings page (and anchor) or
// an integration's connect sheet. baseURL is the public base URL.
func BuildAppLink(baseURL, section, page, focus string, integrationKeys []string) (string, error) {
	section = strings.TrimSpace(section)
	if !slices.Contains(sectionNames(), section) {
		return "", &LinkError{`Unknown app section "` + section + `". Use one of: ` + strings.Join(sectionNames(), ", ") + "."}
	}
	segments := []string{section}
	focus = strings.TrimSpace(focus)
	switch {
	case section == "settings":
		page = strings.TrimSpace(page)
		entry := findPage(page)
		if entry == nil {
			return "", &LinkError{`Unknown settings page "` + page + `". Use one of: ` + strings.Join(pageNames(), ", ") + "."}
		}
		segments = append(segments, page)
		if focus != "" {
			if !slices.Contains(entry.Anchors, focus) {
				return "", &LinkError{"The " + page + ` page has no "` + focus + `". Use one of: ` + strings.Join(entry.Anchors, ", ") + "."}
			}
			segments = append(segments, focus)
		}
	case section == "integrations" && focus != "":
		if !slices.Contains(integrationKeys, focus) {
			return "", &LinkError{`Unknown integration "` + focus + `". Use one of: ` + strings.Join(integrationKeys, ", ") + "."}
		}
		segments = append(segments, focus)
	}
	for i, s := range segments {
		segments[i] = encodeComponent(s)
	}
	return baseURL + openPath + "/" + strings.Join(segments, "/"), nil
}
