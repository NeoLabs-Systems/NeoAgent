package wiring

import (
	"context"
	"encoding/json"
	"sort"

	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/commands"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neoagent/internal/skills"
	"github.com/NeoLabs-Systems/neoagent/internal/sockets"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// Slash commands (/stop, /clear, /status, ...) for the app's chat, the run
// routes and messaging.

// fixedMessages are the runtime's fixed replies in the owner's UI language.
type fixedMessages struct{ store *settings.Store }

func (f fixedMessages) Fixed(ctx context.Context, userID int64, agentID, key string, values map[string]string) string {
	language := "en"
	if raw, err := f.store.ReadValue(ctx, userID, agentID, "ui_language"); err == nil && len(raw) > 0 {
		var v string
		if json.Unmarshal(raw, &v) == nil && v != "" {
			language = v
		}
	}
	return messaging.FixedMessage(language, key, values)
}

type commandEngine struct{ link *engineLink }

func (c commandEngine) StopRuns(userID int64, agentID string) {
	if e := c.link.get(); e != nil {
		e.StopUserRuns(userID, agentID)
	}
}

func (c commandEngine) ActiveRuns(userID int64, agentID string) int {
	if e := c.link.get(); e != nil {
		return e.ActiveRunCount(userID, agentID)
	}
	return 0
}

func (c commandEngine) Reply(ctx context.Context, userID int64, prompt, agentID string) (string, error) {
	e := c.link.get()
	if e == nil {
		return "", errEngineNotReady
	}
	result, err := e.Run(ctx, userID, prompt, agent.Options{AgentID: agentID})
	return result.Content, err
}

type commandQueues struct{ mgr *messaging.Manager }

func (q commandQueues) Summary(userID int64, agentID string) (bool, int) {
	return q.mgr.QueueSummary(userID, agentID)
}
func (q commandQueues) CancelAll(userID int64, agentID string) { q.mgr.CancelQueues(userID, agentID) }
func (q commandQueues) ReleaseAbandonedJobs(userID int64, agentID string) {
	q.mgr.ReleaseAbandonedJobs(context.Background(), userID, agentID)
}

type commandMessaging struct {
	mgr *messaging.Manager
	db  *dbx.DB
}

// FindConversations lists a chat's conversations, one per address it is known under.
func (m commandMessaging) FindConversations(ctx context.Context, userID int64, platform, chatID, agentID string) ([]string, error) {
	var out []string
	for _, id := range m.mgr.ConversationChatIDs(ctx, userID, agentID, platform, chatID) {
		rows, err := m.db.R.QueryContext(ctx, `SELECT id FROM conversations WHERE user_id = ? AND agent_id = ? AND platform = ? AND platform_chat_id = ?`,
			userID, agentID, platform, id)
		if err != nil {
			return nil, err
		}
		for rows.Next() {
			var conversation string
			if rows.Scan(&conversation) == nil {
				out = append(out, conversation)
			}
		}
		rows.Close()
	}
	return out, nil
}

func (m commandMessaging) ConnectedPlatforms(userID int64, agentID string) int {
	return m.mgr.ConnectedPlatforms(context.Background(), userID, agentID)
}

type commandCatalog struct {
	tools  agent.Tools
	models settingsCatalogAdapter
	skills *skills.Runner
}

func (c commandCatalog) ToolNames(userID int64, agentID string) []string {
	var names []string
	for _, d := range c.tools.Available(context.Background(), agent.CatalogRequest{UserID: userID, AgentID: agentID}) {
		names = append(names, d.Name)
	}
	sort.Strings(names)
	return names
}

func (c commandCatalog) Models(ctx context.Context, userID int64, agentID string) ([]commands.Model, error) {
	rows, _, _ := c.models.listModels(ctx, userID, agentID)
	out := make([]commands.Model, 0, len(rows))
	for _, row := range rows {
		out = append(out, commands.Model{ID: dyn.Str(row["id"]), Provider: dyn.Str(row["provider"]), Purpose: dyn.Str(row["purpose"]), Available: row["available"] != false})
	}
	return out, nil
}

func (c commandCatalog) EnabledSkills() []string {
	if c.skills == nil {
		return nil
	}
	var names []string
	for _, s := range c.skills.GetAll(0) {
		if s.Enabled() {
			names = append(names, s.Name)
		}
	}
	return names
}

type webSummaries struct{ db *dbx.DB }

// ClearWebChat drops the web chat's stored summary (clearWebChatSummary).
func (s webSummaries) ClearWebChat(ctx context.Context, userID int64, agentID string) error {
	_, err := s.db.W.ExecContext(ctx, `DELETE FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key IN (?, ?)`, userID, agentID, ai.WebSummaryKey, ai.WebSummaryCountKey)
	return err
}

// socketCommands is the router as the app's chat socket uses it; the router
// exists once the engine is wired.
type socketCommands struct{ app *App }

func (s socketCommands) Dispatch(ctx context.Context, task string, userID int64, agentID, source, socketID string) (sockets.CommandResult, error) {
	if s.app.commands == nil {
		return sockets.CommandResult{}, nil
	}
	result, err := s.app.commands.Dispatch(ctx, task, commands.Context{UserID: userID, AgentID: agentID, Source: source})
	if err != nil {
		return sockets.CommandResult{}, err
	}
	out := sockets.CommandResult{Handled: result.Handled, Content: result.Content}
	for _, e := range result.Events {
		out.Events = append(out.Events, sockets.CommandEvent{Name: e.Name, Payload: e.Payload})
	}
	return out, nil
}
