package agentimport

import (
	"context"
	"errors"
)

// Host is what an import needs from the rest of the server. Each part belongs
// to a domain of its own (agent profiles, memory, skills, settings, automations,
// messaging access), so the import asks for exactly this much and the server
// wires the real services in.
type Host interface {
	// EnsureMainAgent returns the account's main agent, creating it first when
	// the account has none.
	EnsureMainAgent(ctx context.Context, userID int64) (AgentInfo, error)
	// AgentBySlug returns nil when the account has no agent with that slug.
	AgentBySlug(ctx context.Context, userID int64, slug string) (*AgentInfo, error)
	CreateAgent(ctx context.Context, userID int64, agent NewAgent) (AgentInfo, error)
	SetInstructions(ctx context.Context, userID int64, agentID, text string) error

	// BehaviorNotes are the long persona text of an agent that does not fit
	// agents.instructions.
	BehaviorNotes(ctx context.Context, userID int64, agentID string) (string, error)
	SetBehaviorNotes(ctx context.Context, userID int64, agentID, text string) error
	// UserProfile is the "about you" core memory of an agent.
	UserProfile(ctx context.Context, userID int64, agentID string) (string, error)
	SetUserProfile(ctx context.Context, userID int64, agentID, text string) error
	// SaveMemory saves one fact (duplicates are the memory manager's business)
	// and reports whether it returned a result.
	SaveMemory(ctx context.Context, userID int64, agentID string, m MemoryToSave) (bool, error)

	// CreateSkill stores a skill for the account and returns the path of its
	// SKILL.md. The body is the skill's text as the source had it; the host adds
	// NeoAgent's own notes before storing it. ErrSkillExists reports a name that
	// is already taken.
	CreateSkill(ctx context.Context, userID int64, skill NewSkill) (skillFile string, err error)

	// ApplySetting stores one setting through the settings validation; agentID
	// is "" for account-wide settings. A refused value is an error.
	ApplySetting(ctx context.Context, userID int64, agentID, key, value string) error
	// DefaultChatModel is the agent's default_chat_model setting ("" or "auto"
	// when unset).
	DefaultChatModel(ctx context.Context, userID int64, agentID string) (string, error)
	// UserTimeZone is the account's time zone, "" when none is set.
	UserTimeZone(ctx context.Context, userID int64) (string, error)

	// ValidateSchedule checks a trigger the way the automations do and returns
	// its normalised configuration.
	ValidateSchedule(ctx context.Context, userID int64, agentID string, t Trigger) (map[string]any, error)
	// CreateTask stores a scheduled prompt automation.
	CreateTask(ctx context.Context, userID int64, task TaskSpec) error

	// AllowlistPolicy is the JSON of the messaging access policy that allows
	// exactly these entries on a platform (legacy allowlist migration, then
	// normalisation).
	AllowlistPolicy(platform string, entries []string) (string, error)
}

// ErrSkillExists is returned by Host.CreateSkill for a taken name.
var ErrSkillExists = errors.New("skill already exists")

// AgentInfo is an agent of the account.
type AgentInfo struct {
	ID           string
	Slug         string
	DisplayName  string
	Instructions string
}

// NewAgent is an agent to create.
type NewAgent struct {
	Slug        string
	DisplayName string
	Description string
}

// MemoryToSave is one imported fact.
type MemoryToSave struct {
	Text       string
	Category   string
	Importance int
	// SourceType, SourceID and SourceLabel record where the fact came from.
	SourceType  string
	SourceID    string
	SourceLabel string
}

// NewSkill is a skill to create.
type NewSkill struct {
	Name         string
	Description  string
	Body         string
	Source       string
	ImportedFrom string
}

// TaskSpec is a scheduled prompt automation ("agent_prompt" task on a schedule
// trigger, execution mode "prompt").
type TaskSpec struct {
	AgentID       string
	Name          string
	TriggerConfig map[string]any
	TaskConfig    TaskConfig
	Enabled       bool
}

// TaskConfig is the stored configuration of an imported automation.
type TaskConfig struct {
	Prompt         string `json:"prompt"`
	Model          string `json:"model,omitempty"`
	NotifyPlatform string `json:"notifyPlatform,omitempty"`
	NotifyTo       string `json:"notifyTo,omitempty"`
}
