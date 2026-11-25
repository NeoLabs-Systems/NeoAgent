package security

import (
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// What a person reads when asked to approve a call. An approval is a control,
// not something the agent says, and no model is involved in showing it, so the
// text is fixed per UI language (tables recorded from the Node server).

//go:embed approval_copy.json
var copyJSON []byte

var copyTables struct {
	Copy    map[string]map[string]string `json:"copy"`
	Reasons map[string]map[string]string `json:"reasons"`
}

func init() {
	if err := json.Unmarshal(copyJSON, &copyTables); err != nil {
		panic(err)
	}
}

var categoryActions = map[string]string{"shell": "shell", "file_write": "file", "android_privileged": "android", "desktop_control": "desktop",
	"browser_privileged": "browser", "credential_use": "credential", "network_write": "network", "user_contact": "call", "skill_mutation": "skill",
	"agent_creation": "agent"}
var toolActions = map[string]string{"send_message": "message", "create_task": "task", "update_task": "task"}
var detailArgs = []string{"command", "url", "to", "path", "file_path", "query", "name"}

var placeholder = regexp.MustCompile(`\{(\w+)\}`)
var spaces = regexp.MustCompile(`\s+`)

func fill(template string, values map[string]string) string {
	return placeholder.ReplaceAllStringFunc(template, func(m string) string {
		if v, ok := values[m[1:len(m)-1]]; ok {
			return v
		}
		return m
	})
}

func utf16Len(s string) int {
	n := 0
	for _, r := range s {
		if r > 0xFFFF {
			n += 2
		} else {
			n++
		}
	}
	return n
}

func utf16Slice(s string, units int) string {
	n := 0
	for i, r := range s {
		size := 1
		if r > 0xFFFF {
			size = 2
		}
		if n+size > units {
			return s[:i]
		}
		n += size
	}
	return s
}

func shorten(text string, limit int) string {
	flat := strings.TrimSpace(spaces.ReplaceAllString(RedactSecrets(text), " "))
	if utf16Len(flat) > limit {
		return utf16Slice(flat, limit-1) + "…"
	}
	return flat
}

// detailFor: one value says what the call is about.
func detailFor(args map[string]any, order []string) string {
	for _, key := range detailArgs {
		if s, ok := args[key].(string); ok && strings.TrimSpace(s) != "" {
			return shorten(s, 120)
		}
	}
	for _, key := range order {
		if s, ok := args[key].(string); ok && strings.TrimSpace(s) != "" {
			return shorten(s, 120)
		}
	}
	return ""
}

// Copy is an approval in words.
type Copy struct {
	Language, AgentName, Title, Action, Detail, Reason string
}

// Describer words approvals.
type Describer struct{ DB *dbx.DB }

func (d Describer) language(ctx context.Context, userID int64, agentID string) string {
	var raw string
	if d.DB.R.QueryRowContext(ctx, `SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = 'ui_language'`, userID, agentID).Scan(&raw) != nil {
		_ = d.DB.R.QueryRowContext(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = 'ui_language'`, userID).Scan(&raw)
	}
	var lang string
	if json.Unmarshal([]byte(raw), &lang) != nil {
		lang = raw
	}
	if _, ok := copyTables.Copy[lang]; ok {
		return lang
	}
	return "en"
}

func (d Describer) agentName(ctx context.Context, userID int64, agentID string) string {
	var name string
	q := `SELECT display_name FROM agents WHERE user_id = ? AND (id = ? OR slug = ?)`
	if agentID == "" {
		q = `SELECT display_name FROM agents WHERE user_id = ? AND is_default = 1 AND ? = ? LIMIT 1`
	}
	_ = d.DB.R.QueryRowContext(ctx, q, userID, agentID, agentID).Scan(&name)
	if strings.TrimSpace(name) == "" {
		return "NeoAgent"
	}
	return strings.TrimSpace(name)
}

// Describe words an approval for the app and for chats. argOrder is the order
// the arguments were written in (for the detail fallback).
func (d Describer) Describe(ctx context.Context, userID int64, agentID, toolName string, args map[string]any, argOrder []string, category, reason, reasonKey string, reasonParams map[string]string) Copy {
	lang := d.language(ctx, userID, agentID)
	table := copyTables.Copy[lang]
	key := toolActions[toolName]
	if key == "" {
		key = categoryActions[category]
	}
	if key == "" {
		key = "other"
	}
	name := d.agentName(ctx, userID, agentID)
	reasonText := reason
	if template := copyTables.Reasons[lang][reasonKey]; template != "" {
		reasonText = fill(template, reasonParams)
	}
	if reasonText != "" {
		reasonText = shorten(reasonText, 180)
	}
	return Copy{Language: lang, AgentName: name, Title: fill(table["title"], map[string]string{"agent": name}),
		Action: fill(table[key], map[string]string{"tool": strings.ReplaceAll(toolName, "_", " ")}), Detail: detailFor(args, argOrder), Reason: reasonText}
}

// Option is one answer to an approval prompt.
type Option struct {
	ID, Label, Word, Emoji, Decision, Scope string
}

func tableFor(lang string) map[string]string {
	if t, ok := copyTables.Copy[lang]; ok {
		return t
	}
	return copyTables.Copy["en"]
}

// Options are the answers of an approval prompt.
func Options(lang string) []Option {
	t := tableFor(lang)
	return []Option{
		{"allow", "✅ " + t["allow"], t["allow"], "✅", "approved", "once"},
		{"always", "🔁 " + t["always"], t["always"], "🔁", "approved", "always"},
		{"deny", "🚫 " + t["deny"], t["deny"], "🚫", "denied", "once"},
	}
}

// TimeLimitNote says how long the owner has to answer.
func TimeLimitNote(lang string, minutes int) string {
	return fill(tableFor(lang)["time"], map[string]string{"minutes": fmt.Sprint(minutes)})
}

// ReplyHint says how to answer by typing.
func ReplyHint(lang string) string {
	t := tableFor(lang)
	return fill(t["reply"], map[string]string{"allow": t["allow"], "always": t["always"], "deny": t["deny"]})
}

// TimedOutNotice tells a chat that an approval was skipped.
func TimedOutNotice(lang, action string) string {
	return "⏱️ " + fill(tableFor(lang)["timedOut"], map[string]string{"action": action})
}
