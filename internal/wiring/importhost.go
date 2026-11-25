package wiring

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/agentimport"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neoagent/internal/skills"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// importHost is where an OpenClaw/Hermes import writes: the same agents,
// memory, skills, settings and automations the app itself uses.
type importHost struct {
	db       *dbx.DB
	memory   *memory.Manager
	skills   *skills.Runner
	settings *settings.Store
	tasks    *tasks.Runtime
}

var _ agentimport.Host = importHost{}

const mainAgentSlug = "main"

func newUUID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

func (h importHost) agentBy(ctx context.Context, query string, args ...any) (*agentimport.AgentInfo, error) {
	var a agentimport.AgentInfo
	err := h.db.R.QueryRowContext(ctx, `SELECT id, slug, display_name, COALESCE(instructions, '') FROM agents WHERE `+query, args...).
		Scan(&a.ID, &a.Slug, &a.DisplayName, &a.Instructions)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return &a, err
}

// EnsureMainAgent returns the main agent, making it the default, or creates it.
func (h importHost) EnsureMainAgent(ctx context.Context, userID int64) (agentimport.AgentInfo, error) {
	a, err := h.agentBy(ctx, `user_id = ? AND slug = ?`, userID, mainAgentSlug)
	if err != nil {
		return agentimport.AgentInfo{}, err
	}
	if a != nil {
		_, err := h.db.W.ExecContext(ctx, `UPDATE agents SET is_default = CASE WHEN id = ? THEN 1 ELSE 0 END WHERE user_id = ? AND (id = ? AND is_default = 0 OR id != ? AND is_default = 1)`, a.ID, userID, a.ID, a.ID)
		return *a, err
	}
	id := newUUID()
	if _, err := h.db.W.ExecContext(ctx, `
		INSERT INTO agents (id, user_id, slug, display_name, description, responsibilities, instructions,
			status, is_default, can_delegate, can_be_delegated_to, delegate_targets_json)
		VALUES (?, ?, ?, 'Main', 'Default personal AI contact and fallback agent.', '', '', 'active', 1, 1, 0, '[]')`,
		id, userID, mainAgentSlug); err != nil {
		return agentimport.AgentInfo{}, err
	}
	if _, err := h.db.W.ExecContext(ctx, `UPDATE agents SET is_default = CASE WHEN id = ? THEN 1 ELSE 0 END WHERE user_id = ?`, id, userID); err != nil {
		return agentimport.AgentInfo{}, err
	}
	return agentimport.AgentInfo{ID: id, Slug: mainAgentSlug, DisplayName: "Main"}, nil
}

func (h importHost) AgentBySlug(ctx context.Context, userID int64, slug string) (*agentimport.AgentInfo, error) {
	return h.agentBy(ctx, `user_id = ? AND slug = ?`, userID, slug)
}

func (h importHost) CreateAgent(ctx context.Context, userID int64, a agentimport.NewAgent) (agentimport.AgentInfo, error) {
	if existing, err := h.AgentBySlug(ctx, userID, a.Slug); err != nil || existing != nil {
		if err == nil {
			err = fmt.Errorf("An agent with the identifier %q already exists.", a.Slug)
		}
		return agentimport.AgentInfo{}, err
	}
	name := strings.TrimSpace(a.DisplayName)
	if name == "" {
		name = a.Slug
	}
	if len(name) > 120 {
		name = name[:120]
	}
	id := newUUID()
	_, err := h.db.W.ExecContext(ctx, `
		INSERT INTO agents (id, user_id, slug, display_name, description, responsibilities, instructions,
			status, is_default, can_delegate, can_be_delegated_to, delegate_targets_json, tool_restrictions_json)
		VALUES (?, ?, ?, ?, ?, '', '', 'active', 0, 0, 1, '[]', '{}')`,
		id, userID, a.Slug, name, strings.TrimSpace(a.Description))
	return agentimport.AgentInfo{ID: id, Slug: a.Slug, DisplayName: name}, err
}

func (h importHost) SetInstructions(ctx context.Context, userID int64, agentID, text string) error {
	_, err := h.db.W.ExecContext(ctx, `UPDATE agents SET instructions = ?, updated_at = datetime('now') WHERE user_id = ? AND id = ?`, text, userID, agentID)
	return err
}

func (h importHost) BehaviorNotes(ctx context.Context, userID int64, agentID string) (string, error) {
	return h.memory.AssistantBehaviorNotes(ctx, userID, agentID)
}

func (h importHost) SetBehaviorNotes(ctx context.Context, userID int64, agentID, text string) error {
	return h.memory.SetAssistantBehaviorNotes(ctx, userID, agentID, text)
}

func (h importHost) UserProfile(ctx context.Context, userID int64, agentID string) (string, error) {
	core, err := h.memory.CoreMemory(ctx, userID, agentID)
	if err != nil {
		return "", err
	}
	return core.String("user_profile"), nil
}

func (h importHost) SetUserProfile(ctx context.Context, userID int64, agentID, text string) error {
	return h.memory.UpdateCore(ctx, userID, agentID, "user_profile", text)
}

func (h importHost) SaveMemory(ctx context.Context, userID int64, agentID string, m agentimport.MemoryToSave) (bool, error) {
	id, err := h.memory.SaveMemory(ctx, userID, m.Text, m.Category, float64(m.Importance), memory.SaveOptions{
		AgentID: agentID, SourceRef: memory.NewSourceRef(m.SourceType, m.SourceID, m.SourceLabel),
	})
	return id != "", err
}

func (h importHost) CreateSkill(ctx context.Context, userID int64, s agentimport.NewSkill) (string, error) {
	saved, err := h.skills.Create(ctx, userID, s.Name, s.Description, skills.PrependNeoAgentNotes(s.Body),
		workspace.Obj{{Key: "source", Value: s.Source}, {Key: "imported_from", Value: s.ImportedFrom}})
	if err != nil {
		if strings.Contains(err.Error(), "already exists") {
			return "", agentimport.ErrSkillExists
		}
		return "", err
	}
	return saved.Path, nil
}

func (h importHost) ApplySetting(ctx context.Context, userID int64, agentID, key, value string) error {
	raw, err := json.Marshal(value)
	if err != nil {
		return err
	}
	return h.settings.Update(ctx, userID, agentID, settings.Patch{key: raw}, "import")
}

func (h importHost) DefaultChatModel(ctx context.Context, userID int64, agentID string) (string, error) {
	raw, err := h.settings.ReadValue(ctx, userID, agentID, "default_chat_model")
	if err != nil || len(raw) == 0 {
		return "", err
	}
	var v string
	_ = json.Unmarshal(raw, &v)
	return v, nil
}

func (h importHost) UserTimeZone(ctx context.Context, userID int64) (string, error) {
	raw, err := h.settings.ReadValue(ctx, userID, "", "timezone")
	if err != nil || len(raw) == 0 {
		return "", err
	}
	var v string
	_ = json.Unmarshal(raw, &v)
	return v, nil
}

// ValidateSchedule shapes the trigger; the automations validate and
// normalise it once more when the task is stored (CreateTask).
func (h importHost) ValidateSchedule(_ context.Context, _ int64, _ string, t agentimport.Trigger) (map[string]any, error) {
	config := map[string]any{"mode": t.Mode}
	if t.CronExpression != "" {
		config["cronExpression"] = t.CronExpression
	}
	if t.RunAt != "" {
		config["runAt"] = t.RunAt
	}
	return config, nil
}

func (h importHost) CreateTask(ctx context.Context, userID int64, t agentimport.TaskSpec) error {
	trigger := jsv.NewObject()
	for k, v := range t.TriggerConfig {
		trigger.Set(k, v)
	}
	config := jsv.NewObject().Set("prompt", t.TaskConfig.Prompt)
	if t.TaskConfig.Model != "" {
		config.Set("model", t.TaskConfig.Model)
	}
	if t.TaskConfig.NotifyPlatform != "" {
		config.Set("notifyPlatform", t.TaskConfig.NotifyPlatform)
	}
	if t.TaskConfig.NotifyTo != "" {
		config.Set("notifyTo", t.TaskConfig.NotifyTo)
	}
	input := jsv.NewObject().Set("name", t.Name).Set("triggerType", "schedule").Set("triggerConfig", trigger).
		Set("executionMode", "prompt").Set("taskType", "agent_prompt").Set("taskConfig", config).Set("enabled", t.Enabled)
	_, err := h.tasks.CreateTask(ctx, userID, t.AgentID, input)
	return err
}

func (h importHost) AllowlistPolicy(platform string, entries []string) (string, error) {
	policy := messaging.NormalizeAccessPolicy(platform, messaging.MigrateLegacyWhitelist(platform, entries))
	raw, err := json.Marshal(policy)
	return string(raw), err
}

// importAIProviders are the AI providers an import checks keys against (the
// settings' provider list with each one's credential variable; Ollama has
// none).
var importAIProviders = []agentimport.AIProvider{
	{ID: "openai", Label: "OpenAI", EnvKey: "OPENAI_API_KEY"},
	{ID: "openai-compatible", Label: "Custom OpenAI-compatible", EnvKey: "OPENAI_COMPATIBLE_API_KEY"},
	{ID: "anthropic", Label: "Anthropic", EnvKey: "ANTHROPIC_API_KEY"},
	{ID: "google", Label: "Google", EnvKey: "GOOGLE_AI_KEY"},
	{ID: "grok", Label: "xAI", EnvKey: "XAI_API_KEY"},
	{ID: "grok-oauth", Label: "Grok (xAI OAuth)", EnvKey: "GROK_OAUTH_ACCESS_TOKEN"},
	{ID: "nvidia", Label: "NVIDIA NIM", EnvKey: "NVIDIA_API_KEY"},
	{ID: "minimax", Label: "MiniMax Code", EnvKey: "MINIMAX_API_KEY"},
	{ID: "github-copilot", Label: "GitHub Copilot", EnvKey: "GITHUB_COPILOT_ACCESS_TOKEN"},
	{ID: "openai-codex", Label: "OpenAI Codex", EnvKey: "OPENAI_CODEX_ACCESS_TOKEN"},
	{ID: "claude-code", Label: "Claude Code", EnvKey: "CLAUDE_CODE_OAUTH_TOKEN"},
	{ID: "nous", Label: "Nous Portal", EnvKey: "NOUS_API_KEY"},
	{ID: "openrouter", Label: "OpenRouter", EnvKey: "OPENROUTER_API_KEY"},
	{ID: "typesafe", Label: "TypeSafe", EnvKey: "TYPESAFE_API_KEY"},
	{ID: "neorouter", Label: "NeoRouter", EnvKey: "NEOROUTER_API_KEY"},
	{ID: "ollama", Label: "Ollama"},
}
