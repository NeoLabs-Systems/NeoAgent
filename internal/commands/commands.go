// Package commands handles slash commands typed into chat (/new, /stop,
// /status, /tools, /memory, /tasks, /models, /skills, /help) and their
// !command aliases on messaging platforms.
package commands

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"unicode/utf16"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// Parsed is a chat line recognised as a command.
type Parsed struct {
	Command string
	Args    []string
	Raw     string
	Source  string
	Prefix  string
}

func normalizeSource(source string) string {
	switch strings.ToLower(source) {
	case "http":
		return "http"
	case "messaging":
		return "messaging"
	}
	return "web"
}

// Parse reads a command out of a chat line. Messaging accepts "/" and "!"
// prefixes, everything else only "/". A path pasted at the start of a message
// is not a command. It returns false when the line is not one.
func Parse(input, source string) (Parsed, bool) {
	raw := strings.TrimSpace(input)
	if raw == "" {
		return Parsed{}, false
	}
	actual := normalizeSource(source)
	tokens := strings.Fields(raw)
	head := tokens[0]
	prefixOK := head[0] == '/' || (actual == "messaging" && head[0] == '!')
	// The match needs a prefix followed by at least one non-space character.
	if !prefixOK || len(head) < 2 {
		return Parsed{}, false
	}
	command := strings.ToLower(head[1:])
	if command == "" || strings.Contains(command, "/") {
		return Parsed{}, false
	}
	return Parsed{Command: command, Args: tokens[1:], Raw: raw, Source: actual, Prefix: head[:1]}, true
}

var aliases = map[string]string{
	"new": "clear", "clear": "clear", "stop": "stop", "help": "help", "status": "status",
	"tools": "tools", "memory": "memory", "tasks": "tasks", "models": "models", "skills": "skills",
}

// Event is a realtime event the caller emits after the command ran.
type Event struct {
	Name    string `json:"name"`
	Payload any    `json:"payload"`
}

// Metadata describes where a reply goes. Replies on messaging platforms carry
// the chat id too (null when unknown); others do not.
type Metadata struct {
	Source   string
	Platform *string
	ChatID   *string
	WithChat bool
}

// MarshalJSON writes source, platform and, for messaging, chatId.
func (m Metadata) MarshalJSON() ([]byte, error) {
	if m.WithChat {
		return json.Marshal(struct {
			Source   string  `json:"source"`
			Platform *string `json:"platform"`
			ChatID   *string `json:"chatId"`
		}{m.Source, m.Platform, m.ChatID})
	}
	return json.Marshal(struct {
		Source   string  `json:"source"`
		Platform *string `json:"platform"`
	}{m.Source, m.Platform})
}

// Result is what a dispatched line produced. Handled false means the line is
// not a command and goes to the agent as usual.
type Result struct {
	Handled  bool      `json:"handled"`
	Content  string    `json:"content,omitempty"`
	Events   []Event   `json:"events,omitempty"`
	Metadata *Metadata `json:"metadata,omitempty"`
	Error    string    `json:"error,omitempty"`
}

// Context is who typed the command and where.
type Context struct {
	UserID   int64
	AgentID  string
	Source   string
	Platform string
	ChatID   string
}

// Model is one entry of the model catalogue.
type Model struct {
	ID        string
	Provider  string
	Purpose   string
	Available bool
}

// The interfaces below are the other domains the router talks to.

// Agents resolves the agent a request is about (the main agent by default).
type Agents interface {
	Resolve(ctx context.Context, userID int64, candidate string) (string, error)
}

// Messages produces the fixed replies of the runtime in the user's language.
type Messages interface {
	Fixed(ctx context.Context, userID int64, agentID, key string, values map[string]string) string
}

// Engine is the agent loop: its active runs and a way to ask it for a reply.
type Engine interface {
	// StopRuns stops every active run of the user, restricted to agentID.
	StopRuns(userID int64, agentID string)
	ActiveRuns(userID int64, agentID string) int
	// Reply runs the agent once and returns its text.
	Reply(ctx context.Context, userID int64, prompt, agentID string) (string, error)
}

// Queues is the inbound message queue of the messaging domain.
type Queues interface {
	Summary(userID int64, agentID string) (running bool, pending int)
	// CancelAll cancels running work and drops pending messages.
	CancelAll(userID int64, agentID string)
	// ReleaseAbandonedJobs frees inbound jobs nobody works on any more.
	ReleaseAbandonedJobs(userID int64, agentID string)
}

// Messaging is the connected chat platforms.
type Messaging interface {
	// FindConversations lists the conversations a chat is known under.
	FindConversations(ctx context.Context, userID int64, platform, chatID, agentID string) ([]string, error)
	ConnectedPlatforms(userID int64, agentID string) int
}

// Catalog lists what the agent can use.
type Catalog interface {
	ToolNames(userID int64, agentID string) []string
	Models(ctx context.Context, userID int64, agentID string) ([]Model, error)
	// EnabledSkills names the skills that are on.
	EnabledSkills() []string
}

// Summaries clears the stored summary of the web chat.
type Summaries interface {
	ClearWebChat(ctx context.Context, userID int64, agentID string) error
}

// Config wires the router. Engine, Queues, Messaging and Summaries may be nil
// where a deployment lacks them, as in Node.
type Config struct {
	DB        *dbx.DB
	Agents    Agents
	Messages  Messages
	Engine    Engine
	Queues    Queues
	Messaging Messaging
	Catalog   Catalog
	Summaries Summaries
}

// Router dispatches commands.
type Router struct{ cfg Config }

// New builds a router.
func New(cfg Config) *Router { return &Router{cfg: cfg} }

// Dispatch runs a chat line if it is a command.
func (r *Router) Dispatch(ctx context.Context, input string, c Context) (Result, error) {
	parsed, ok := Parse(input, c.Source)
	if !ok {
		return Result{}, nil
	}
	resolved, known := aliases[parsed.Command]
	if !known {
		if parsed.Source == "messaging" {
			return Result{}, nil
		}
		return Result{Handled: true, Content: r.cfg.Messages.Fixed(ctx, c.UserID, c.AgentID, "unknownCommand", map[string]string{"command": parsed.Command})}, nil
	}
	if c.UserID == 0 {
		return Result{Handled: true, Content: "Cannot run command: missing user context."}, nil
	}
	agentID, err := r.cfg.Agents.Resolve(ctx, c.UserID, c.AgentID)
	if err != nil {
		return Result{}, err
	}
	switch resolved {
	case "clear":
		c.AgentID = agentID
		return r.clear(ctx, parsed, c)
	case "stop":
		return r.stop(ctx, c.UserID, agentID), nil
	case "help":
		return Result{Handled: true, Content: helpText}, nil
	case "status":
		return r.status(c.UserID, agentID), nil
	case "tools":
		return r.tools(c.UserID, agentID), nil
	case "memory":
		return r.memory(ctx, c.UserID, agentID)
	case "tasks":
		return r.tasks(ctx, c.UserID, parsed.Args, agentID)
	case "models":
		return r.models(ctx, c.UserID, agentID)
	default:
		return r.skills(), nil
	}
}

func optional(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func (r *Router) clear(ctx context.Context, p Parsed, c Context) (Result, error) {
	events := []Event{{Name: "chat:cleared", Payload: map[string]any{}}}
	if p.Source == "messaging" {
		platform, chatID := strings.TrimSpace(c.Platform), strings.TrimSpace(c.ChatID)
		if platform != "" && chatID != "" {
			ids, err := r.conversations(ctx, c.UserID, c.AgentID, platform, chatID)
			if err != nil {
				return Result{}, err
			}
			for _, id := range ids {
				if _, err := r.cfg.DB.W.ExecContext(ctx, `DELETE FROM conversations WHERE id = ?`, id); err != nil {
					return Result{}, err
				}
			}
		}
		return Result{
			Handled: true, Content: r.cfg.Messages.Fixed(ctx, c.UserID, c.AgentID, "contextCleared", nil), Events: events,
			Metadata: &Metadata{Source: p.Source, Platform: optional(c.Platform), ChatID: optional(c.ChatID), WithChat: true},
		}, nil
	}
	if _, err := r.cfg.DB.W.ExecContext(ctx, `DELETE FROM conversation_history WHERE user_id = ? AND agent_id = ?`, c.UserID, c.AgentID); err != nil {
		return Result{}, err
	}
	if r.cfg.Summaries != nil {
		if err := r.cfg.Summaries.ClearWebChat(ctx, c.UserID, c.AgentID); err != nil {
			return Result{}, err
		}
	}
	if p.Source == "web" && r.cfg.Engine != nil {
		// The model words the acknowledgement; there is no canned text.
		reply, err := r.cfg.Engine.Reply(ctx, c.UserID,
			"context was just cleared. say something very brief (1-2 sentences max) acknowledging the fresh start, in your own style. no tools needed.", c.AgentID)
		if err != nil {
			return Result{Handled: true, Content: r.cfg.Messages.Fixed(ctx, c.UserID, c.AgentID, "contextCleared", nil), Events: events, Error: err.Error()}, nil
		}
		if reply == "" {
			reply = "fresh start."
		}
		return Result{Handled: true, Content: reply, Events: events}, nil
	}
	return Result{
		Handled: true, Content: r.cfg.Messages.Fixed(ctx, c.UserID, c.AgentID, "contextCleared", nil), Events: events,
		Metadata: &Metadata{Source: p.Source, Platform: optional(c.Platform)},
	}, nil
}

// conversations finds the conversations of a chat: through the messaging
// domain when it is running, else straight from the database.
func (r *Router) conversations(ctx context.Context, userID int64, agentID, platform, chatID string) ([]string, error) {
	if r.cfg.Messaging != nil {
		return r.cfg.Messaging.FindConversations(ctx, userID, platform, chatID, agentID)
	}
	var id string
	err := r.cfg.DB.W.QueryRowContext(ctx,
		`SELECT id FROM conversations WHERE user_id = ? AND agent_id = ? AND platform = ? AND platform_chat_id = ?`,
		userID, agentID, platform, chatID).Scan(&id)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return []string{id}, nil
}

func (r *Router) stop(ctx context.Context, userID int64, agentID string) Result {
	if r.cfg.Engine != nil {
		r.cfg.Engine.StopRuns(userID, agentID)
	}
	if r.cfg.Queues != nil {
		r.cfg.Queues.CancelAll(userID, agentID)
		r.cfg.Queues.ReleaseAbandonedJobs(userID, agentID)
	}
	return Result{Handled: true, Content: r.cfg.Messages.Fixed(ctx, userID, agentID, "stopped", nil)}
}

const helpText = "**Available commands**\n" +
	"- `/new` or `/clear` - clear conversation context\n" +
	"- `/stop` - abort active runs and clear pending queue\n" +
	"- `/status` - show current run/queue status\n" +
	"- `/tools` - list available built-in tools\n" +
	"- `/memory` - quick memory summary\n" +
	"- `/tasks` - list latest task runs and configured tasks\n" +
	"- `/models` - list currently available models\n" +
	"- `/skills` - list enabled skills\n" +
	"- `/help` - show this message\n\n" +
	"Messaging also accepts `!command` aliases (for example `!stop`)."

func (r *Router) status(userID int64, agentID string) Result {
	active, pending, connected := 0, 0, 0
	running := false
	if r.cfg.Engine != nil {
		active = r.cfg.Engine.ActiveRuns(userID, agentID)
	}
	if r.cfg.Queues != nil {
		running, pending = r.cfg.Queues.Summary(userID, agentID)
	}
	if r.cfg.Messaging != nil {
		connected = r.cfg.Messaging.ConnectedPlatforms(userID, agentID)
	}
	state := "idle"
	if running {
		state = "running"
	}
	return Result{Handled: true, Content: fmt.Sprintf("**Status**\n- Active runs: %d\n- Messaging queue: %s (%d pending)\n- Connected messaging platforms: %d", active, state, pending, connected)}
}

func (r *Router) tools(userID int64, agentID string) Result {
	var names []string
	if r.cfg.Catalog != nil {
		names = append(names, r.cfg.Catalog.ToolNames(userID, agentID)...)
	}
	sort.Strings(names)
	preview := names[:min(len(names), 30)]
	extra := ""
	if len(names) > len(preview) {
		extra = fmt.Sprintf("\n- ...and %d more", len(names)-len(preview))
	}
	return Result{Handled: true, Content: fmt.Sprintf("**Tools (%d)**\n- %s%s", len(names), strings.Join(preview, "\n- "), extra)}
}

func truncateUnits(s string, n int) string {
	units := utf16.Encode([]rune(s))
	if len(units) <= n {
		return s
	}
	return string(utf16.Decode(units[:n]))
}

func (r *Router) memory(ctx context.Context, userID int64, agentID string) (Result, error) {
	var episodic, core int
	if err := r.cfg.DB.W.QueryRowContext(ctx, `SELECT COUNT(*) FROM memories WHERE user_id = ? AND agent_id = ? AND archived = 0`, userID, agentID).Scan(&episodic); err != nil {
		return Result{}, err
	}
	if err := r.cfg.DB.W.QueryRowContext(ctx, `SELECT COUNT(*) FROM core_memory WHERE user_id = ? AND agent_id = ?`, userID, agentID).Scan(&core); err != nil {
		return Result{}, err
	}
	var category, content sql.NullString
	err := r.cfg.DB.W.QueryRowContext(ctx,
		`SELECT category, content FROM memories WHERE user_id = ? AND agent_id = ? AND archived = 0 ORDER BY updated_at DESC LIMIT 1`,
		userID, agentID).Scan(&category, &content)
	if err != nil && err != sql.ErrNoRows {
		return Result{}, err
	}
	out := fmt.Sprintf("**Memory**\n- Episodic entries: %d\n- Core memory keys: %d", episodic, core)
	if preview := truncateUnits(strings.Join(strings.Fields(content.String), " "), 140); err == nil && preview != "" {
		kind := category.String
		if kind == "" {
			kind = "episodic"
		}
		out += fmt.Sprintf("\n- Latest: %s - %s", kind, preview)
	}
	return Result{Handled: true, Content: out}, nil
}

func jsString(v any) string {
	switch x := v.(type) {
	case string:
		return x
	case float64:
		b, _ := json.Marshal(x)
		return string(b)
	case bool:
		if x {
			return "true"
		}
	}
	return ""
}

func (r *Router) tasks(ctx context.Context, userID int64, args []string, agentID string) (Result, error) {
	mode := "recent"
	if len(args) > 0 {
		mode = strings.ToLower(args[0])
	}
	if mode == "scheduled" {
		rows, err := r.cfg.DB.W.QueryContext(ctx,
			`SELECT id, name, enabled, trigger_type, trigger_config FROM scheduled_tasks WHERE user_id = ? AND agent_id = ? ORDER BY created_at DESC`, userID, agentID)
		if err != nil {
			return Result{}, err
		}
		defer rows.Close()
		var lines []string
		for rows.Next() {
			var id int64
			var name string
			var enabled sql.NullInt64
			var triggerType, triggerConfig sql.NullString
			if err := rows.Scan(&id, &name, &enabled, &triggerType, &triggerConfig); err != nil {
				return Result{}, err
			}
			label := triggerType.String
			if label == "" {
				label = "schedule"
			}
			if label == "schedule" {
				var config map[string]any
				_ = json.Unmarshal([]byte(orDefault(triggerConfig.String, "{}")), &config)
				if jsString(config["mode"]) == "one_time" {
					label = "one-time at " + orDefault(jsString(config["runAt"]), "unknown")
				} else {
					label = orDefault(jsString(config["cronExpression"]), "schedule")
				}
			}
			state := "disabled"
			if enabled.Int64 != 0 {
				state = "enabled"
			}
			lines = append(lines, fmt.Sprintf("- #%d %s [%s] - %s", id, name, state, label))
		}
		if err := rows.Err(); err != nil {
			return Result{}, err
		}
		if len(lines) == 0 {
			return Result{Handled: true, Content: "**Tasks**\n- No tasks found."}, nil
		}
		return Result{Handled: true, Content: fmt.Sprintf("**Tasks (%d)**\n%s", len(lines), strings.Join(lines, "\n"))}, nil
	}

	rows, err := r.cfg.DB.W.QueryContext(ctx,
		`SELECT id, title, status, trigger_source FROM agent_runs WHERE user_id = ? AND agent_id = ? ORDER BY created_at DESC LIMIT 8`, userID, agentID)
	if err != nil {
		return Result{}, err
	}
	defer rows.Close()
	var lines []string
	for rows.Next() {
		var id string
		var title, status, source sql.NullString
		if err := rows.Scan(&id, &title, &status, &source); err != nil {
			return Result{}, err
		}
		short := []rune(id)
		lines = append(lines, fmt.Sprintf("- %s [%s] %s (%s)", string(short[:min(len(short), 8)]), status.String, orDefault(title.String, "Untitled"), orDefault(source.String, "web")))
	}
	if err := rows.Err(); err != nil {
		return Result{}, err
	}
	if len(lines) == 0 {
		return Result{Handled: true, Content: "**Tasks**\n- No runs yet."}, nil
	}
	return Result{Handled: true, Content: fmt.Sprintf("**Recent Tasks (%d)**\n%s\n\nTip: use `/tasks scheduled` to view cron/one-time tasks.", len(lines), strings.Join(lines, "\n"))}, nil
}

func orDefault(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

func (r *Router) models(ctx context.Context, userID int64, agentID string) (Result, error) {
	var all []Model
	if r.cfg.Catalog != nil {
		var err error
		if all, err = r.cfg.Catalog.Models(ctx, userID, agentID); err != nil {
			return Result{}, err
		}
	}
	var available []Model
	for _, m := range all {
		if m.Available {
			available = append(available, m)
		}
	}
	if len(available) == 0 {
		return Result{Handled: true, Content: "**Models**\n- No models are currently available. Check provider settings."}, nil
	}
	var lines []string
	for _, m := range available[:min(len(available), 20)] {
		lines = append(lines, fmt.Sprintf("- %s (%s, %s)", m.ID, m.Provider, orDefault(m.Purpose, "general")))
	}
	extra := ""
	if len(available) > 20 {
		extra = fmt.Sprintf("\n- ...and %d more", len(available)-20)
	}
	return Result{Handled: true, Content: fmt.Sprintf("**Models (%d)**\n%s%s", len(available), strings.Join(lines, "\n"), extra)}, nil
}

func (r *Router) skills() Result {
	var enabled []string
	if r.cfg.Catalog != nil {
		enabled = r.cfg.Catalog.EnabledSkills()
	}
	if len(enabled) == 0 {
		return Result{Handled: true, Content: "**Skills**\n- No enabled skills found."}
	}
	var lines []string
	for _, name := range enabled[:min(len(enabled), 20)] {
		lines = append(lines, "- "+name)
	}
	extra := ""
	if len(enabled) > 20 {
		extra = fmt.Sprintf("\n- ...and %d more", len(enabled)-20)
	}
	return Result{Handled: true, Content: fmt.Sprintf("**Skills (%d)**\n%s%s", len(enabled), strings.Join(lines, "\n"), extra)}
}
