package agentimport

import (
	"os"
	"path/filepath"
)

// Parts is what the user can leave out of an import. Agents always come:
// everything else is attached to one.
var Parts = []string{"keys", "memories", "skills", "model", "tasks", "mcp", "channels"}

// skippedKinds are left-behind notes that belong to a part, so leaving the
// part out also leaves out its notes.
var skippedKinds = map[string][]string{
	"keys":     {"AI provider", "Sign-in"},
	"tasks":    {"Automation"},
	"mcp":      {"MCP server"},
	"channels": {"Channel"},
}

var fallbackKeyLabels = map[string]string{
	"BRAVE_SEARCH_API_KEY":       "Brave Search",
	"DEEPGRAM_API_KEY":           "Deepgram",
	"ELEVENLABS_API_KEY":         "ElevenLabs",
	"OLLAMA_URL":                 "Ollama",
	"OPENAI_COMPATIBLE_BASE_URL": "Custom endpoint",
}

// AIProvider describes one AI provider of the server: the name shown to the
// user and the .env key that holds its credential (empty for Ollama, which is
// configured by OLLAMA_URL).
type AIProvider struct {
	ID     string
	Label  string
	EnvKey string
}

// Content is one line of "what this installation holds".
type Content struct {
	Part  string   `json:"part"`
	Count int      `json:"count"`
	Names []string `json:"names"`
	// Days is set for memories only.
	Days *int `json:"days,omitempty"`
}

// Scan finds every OpenClaw and Hermes Agent installation on this computer,
// or only the one in From.
func (s Scanner) Scan() []Bundle {
	if s.From != "" {
		switch SourceKind(s.From) {
		case "openclaw":
			return []Bundle{s.ScanOpenClaw(s.From)}
		case "hermes":
			return []Bundle{s.ScanHermes(s.From)}
		}
		return nil
	}
	var out []Bundle
	for _, home := range s.FindOpenClawHomes() {
		out = append(out, s.ScanOpenClaw(home))
	}
	for _, home := range s.FindHermesHomes() {
		out = append(out, s.ScanHermes(home))
	}
	return out
}

func keyLabel(providers []AIProvider, envKey string) string {
	for _, p := range providers {
		if p.EnvKey == envKey {
			return p.Label
		}
	}
	return fallbackKeyLabels[envKey]
}

// bundleContents says what a bundle holds, per part. Only parts with something
// in them; agents only when they are more than a nameless default.
func bundleContents(b Bundle, providers []AIProvider) []Content {
	var contents []Content
	named := false
	var agentNames []string
	for _, a := range b.Agents {
		if a.Instructions != "" || !a.IsDefault {
			named = true
		}
		agentNames = append(agentNames, a.Name)
	}
	if named {
		contents = append(contents, Content{Part: "agents", Count: len(b.Agents), Names: agentNames})
	}
	memories, days := 0, 0
	for _, a := range b.Agents {
		memories += len(a.Memories)
		if a.UserProfile != "" {
			memories++
		}
		days += len(a.DailyLogs)
	}
	if memories > 0 || days > 0 {
		contents = append(contents, Content{Part: "memories", Count: memories, Names: []string{}, Days: &days})
	}
	if len(b.Skills) > 0 {
		names := make([]string, len(b.Skills))
		for i, s := range b.Skills {
			names[i] = s.Name
		}
		contents = append(contents, Content{Part: "skills", Count: len(names), Names: names})
	}
	var keyNames []string
	for _, name := range b.Keys.names {
		if label := keyLabel(providers, name); label != "" && !contains(keyNames, label) {
			keyNames = append(keyNames, label)
		}
	}
	if len(keyNames) > 0 {
		contents = append(contents, Content{Part: "keys", Count: len(keyNames), Names: keyNames})
	}
	if b.Model != "" {
		contents = append(contents, Content{Part: "model", Count: 1, Names: []string{b.SourceModel}})
	}
	if len(b.Tasks) > 0 {
		names := make([]string, len(b.Tasks))
		for i, t := range b.Tasks {
			names[i] = t.Name
		}
		contents = append(contents, Content{Part: "tasks", Count: len(names), Names: names})
	}
	if len(b.MCP) > 0 {
		names := make([]string, len(b.MCP))
		for i, m := range b.MCP {
			names[i] = m.Name
		}
		contents = append(contents, Content{Part: "mcp", Count: len(names), Names: names})
	}
	if len(b.Channels) > 0 {
		names := make([]string, len(b.Channels))
		for i, c := range b.Channels {
			names[i] = platformLabels[c.Platform]
		}
		contents = append(contents, Content{Part: "channels", Count: len(names), Names: names})
	}
	return contents
}

// selectParts copies the bundle holding only the chosen parts.
func selectParts(b Bundle, parts []string) Bundle {
	keep := map[string]bool{}
	for _, p := range parts {
		keep[p] = true
	}
	dropped := map[string]bool{}
	for _, part := range Parts {
		if !keep[part] {
			for _, kind := range skippedKinds[part] {
				dropped[kind] = true
			}
		}
	}
	out := b
	if !keep["keys"] {
		out.Keys = newKeyList()
		out.IgnoredKeys = nil
	}
	out.Agents = make([]Agent, len(b.Agents))
	for i, a := range b.Agents {
		if !keep["memories"] {
			a.Memories, a.UserProfile, a.DailyLogs = nil, "", nil
		}
		if !keep["model"] {
			a.Model = ""
		}
		out.Agents[i] = a
	}
	if !keep["skills"] {
		out.Skills = nil
	}
	if !keep["model"] {
		out.Model = ""
	}
	if !keep["tasks"] {
		out.Tasks = nil
	}
	if !keep["mcp"] {
		out.MCP = nil
	}
	if !keep["channels"] {
		out.Channels = nil
	}
	out.Skipped = nil
	for _, item := range b.Skipped {
		if !dropped[item.Kind] {
			out.Skipped = append(out.Skipped, item)
		}
	}
	return out
}

// SourceKind is "openclaw" or "hermes" for an installation folder, "" for
// anything else.
func SourceKind(dir string) string {
	for _, name := range []string{"openclaw.json", "clawdbot.json", "moltbot.json"} {
		if info, err := os.Stat(filepath.Join(dir, name)); err == nil && info.Mode().IsRegular() {
			return "openclaw"
		}
	}
	if info, err := os.Stat(filepath.Join(dir, "config.yaml")); err == nil && info.Mode().IsRegular() {
		return "hermes"
	}
	if _, err := os.Stat(filepath.Join(dir, "memories")); err == nil {
		return "hermes"
	}
	return ""
}
