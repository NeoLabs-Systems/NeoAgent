// Package handlers runs the agent's tools: the built-in handlers, the
// integrated tools (app settings, SynthID) and the fall-through to official
// integrations, MCP servers and skills. Backend implements ai.ToolBackend.
//
// Every handler reaches other domains through the small consumer-side
// interfaces in deps.go; internal/wiring implements them from the domain
// packages. A nil dependency answers with the same "unavailable" result the
// Node handlers gave.
package handlers

import (
	"context"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

// Run is what the engine knows about the run a tool call belongs to.
type Run struct {
	UserID  int64
	AgentID string
	RunID   string

	// TriggerType is "user", "subagent", ...; TriggerSource is "web",
	// "messaging", "agent_delegation", "task", ...
	TriggerType, TriggerSource string
	TaskID, ScheduledAt        string
	ConversationID             string
	// Source and ChatID name the messaging chat the run answers.
	Source, ChatID string
	DeviceTarget   string
	WorkspaceRoot  string

	AllowMultipleProactiveMessages bool
	AllowExternalSideEffects       bool
	StageProactiveMessages         bool

	// Inbound is the chat message the run answers, when it answers one.
	Inbound *Inbound
	// Behavior is set when the run answers through the messaging behavior
	// pipeline (typing bubbles, turn epochs).
	Behavior *Behavior
	// Delivery is the run's view of what it has shown the user; nil outside a run.
	Delivery Delivery
	// Tainted: the run has read outside content. OwnerStatements are the
	// owner's own words in the run, which back a user_stated memory.
	Tainted         bool
	OwnerStatements []string
	// Public pins a run that answers a public thread.
	Public *PublicScope
	// DeliveryScopeID groups the deliveries of a run and its continuations.
	DeliveryScopeID string
	// Persisted is true when the run has a row in agent_runs, so its
	// deliveries go through the outbox.
	Persisted bool
}

// Inbound is the incoming chat message of a messaging run.
type Inbound struct {
	Platform  string
	ChatID    string
	MessageID string
	Sender    string
	IsGroup   bool
}

// Behavior is the messaging behavior context of a run.
type Behavior struct {
	Enabled   bool
	IsGroup   bool
	TurnEpoch int64
	// Message and Config are the pipeline's own records, passed back to it.
	Message any
	Config  any
}

// PublicScope limits a run that answers a public thread.
type PublicScope struct {
	Platform    string
	ChatID      string
	ToolNames   map[string]bool
	ProviderKey string
	AppKey      string
}

// Delivery is the per-run delivery record the send tools update.
type Delivery interface {
	// NotifyTarget is a background task's resolved target.
	NotifyTarget() (platform, to string, ok bool)
	SentCount() int
	Staged() bool
	Stage(StagedMessage)
	ChooseSilence()
	MarkLastWordSent()
	MarkFinalDelivered()
	MarkSent(content string)
}

// StagedMessage is a task's message held until the run ends.
type StagedMessage struct {
	Platform, To, Content, Purpose, MediaPath, StagedAt string
}

// DeliveryCommit reserves a slot in the run's outbox before transmitting.
type DeliveryCommit struct {
	ScopeID   string
	Channel   string
	Recipient string
	Purpose   string
	// SlotContent is what the slot is derived from (slotForContent).
	SlotContent       string
	Content           string
	Metadata          dyn.Map
	DedupeContent     bool
	AllowEmptyContent bool
	Transmit          func(ctx context.Context) TransmitResult
}

// TransmitResult is what one transmission did.
type TransmitResult struct {
	OK                  bool
	SkippedTransmission bool
	Ambiguous           bool
	PlatformMessageID   string
	Reason              string
	Error               string
}

// DeliveryOutcome is how a commit ended.
type DeliveryOutcome struct {
	OK        bool
	Duplicate bool
	Reason    string
	Error     string
}

// InterimUpdate is send_interim_update's request to the engine.
type InterimUpdate struct {
	UserID                      int64
	RunID, AgentID              string
	TriggerSource               string
	ConversationID              string
	Platform, ChatID            string
	Content, Kind               string
	ExpectsReply, DeferFollowUp bool
}

// SubagentRequest is spawn_subagent's request.
type SubagentRequest struct {
	Task              string
	Model             string
	Context           any
	RequiredArtifacts []any
	AllowedTools      []string
	Write             bool
	MaxTurns          any
	MaxTokens         any
	MaxSeconds        any
	SelectedTools     []string
}

// Engine is what the handlers need from the agent engine itself: the run
// registry and the loop-level actions (tool search, sub-agents, delegation,
// background runs, the outbox).
type Engine interface {
	// Run is the run a call belongs to; nil when the call runs outside a run.
	Run(runID string) *Run

	SearchTools(ctx context.Context, runID, query string, limit any) (any, error)
	ActivateTools(ctx context.Context, runID string, names []string) (any, error)
	ManageBackgroundRun(ctx context.Context, runID string, args dyn.Map) (any, error)
	UpdateTaskLedger(ctx context.Context, runID string, args dyn.Map) (any, error)

	SpawnSubagent(ctx context.Context, run *Run, req SubagentRequest) (any, error)
	ActiveToolNames(runID string) []string
	DelegateTask(ctx context.Context, run *Run, args dyn.Map) (any, error)
	AgentTaskAction(ctx context.Context, run *Run, args dyn.Map) (any, error)
	ListSubagents(runID string) (any, error)
	WaitSubagent(ctx context.Context, runID, handle string, timeoutMS any) (any, error)
	CancelSubagent(ctx context.Context, runID, handle string) (any, error)
	// AgentCreated records an agent create_agent made, once per run.
	CreatedAgentInRun(runID string) bool
	AgentCreated(ctx context.Context, run *Run, agentID string)

	PublishInterimUpdate(ctx context.Context, u InterimUpdate) (any, error)
	MarkRunVisibleReply(runID string)
	Emit(userID int64, event string, payload any)

	RollbackWorkspace(ctx context.Context, runID string) (any, error)
	// RunRepositories is what the run's checkpoints recorded it changed.
	RunRepositories(runID string) []dyn.Map
	// FileDiagnosticsHistory keeps the diagnostics a run has seen per file.
	FileDiagnosticsHistory(runID string) map[string]string

	CommitDelivery(ctx context.Context, runID string, c DeliveryCommit) (DeliveryOutcome, error)
}
