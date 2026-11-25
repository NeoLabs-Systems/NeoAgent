// Package agent runs the agent: one run, the same on every surface. It accepts
// the request, assembles the context (system prompt with the agent's persona,
// memory, history, tools), lets the agent loop (internal/ai) work until the
// model answers, and delivers that answer through the run's channel exactly as
// the model wrote it. It also owns everything around a run's life: lifecycle
// controls, steering, progress updates, background runs, restarts.
package agent

import (
	"context"
	"log/slog"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/systemone"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// Emitter pushes realtime events to a user's connected clients.
type Emitter interface {
	EmitToUser(userID int64, event string, payload any)
}

// Settings reads an agent's AI settings (defaults overlaid with the stored
// rows), as JSON-shaped values.
type Settings interface {
	AISettings(ctx context.Context, userID int64, agentID string) (dyn.Map, error)
}

// Models is the live model catalog and the clients behind it.
type Models interface {
	// Catalog is every model the account can route to, with availability.
	Catalog(ctx context.Context, userID int64, agentID string) ([]aimodels.Model, error)
	// Provider builds the client for a catalog model.
	Provider(ctx context.Context, userID int64, agentID string, model aimodels.Model) (llm.Provider, error)
	// IsBYOK reports a provider the account configured with its own credentials.
	IsBYOK(ctx context.Context, userID int64, agentID, provider string) bool
}

// CatalogRequest describes the run a tool catalog is built for.
type CatalogRequest struct {
	UserID        int64
	AgentID       string
	TriggerType   string
	TriggerSource string
	// Public is set for runs that answer a public thread.
	Public *PublicScope
}

// Tools is the tool catalog: built-ins, integrated tools, skills, the
// account's integrations and MCP servers.
type Tools interface {
	// Registry is the built-in metadata.
	Registry() *tools.Registry
	// Available lists what a run of this kind may be offered.
	Available(ctx context.Context, req CatalogRequest) []tools.Definition
	// External lists the MCP tools of the account's agent.
	External(ctx context.Context, userID int64, agentID string) []tools.Definition
}

// Agents resolves which of the account's agents a value names.
type Agents interface {
	Resolve(ctx context.Context, userID int64, candidate string) (string, error)
}

// SendRequest is a message for a chat platform.
type SendRequest struct {
	UserID              int64
	AgentID             string
	Platform, ChatID    string
	Content             string
	MediaPath           string
	RunID               string
	IdempotencyKey      string
	PersistConversation bool
	// Metadata is stored with the message (interim kind, ...): a JSON object.
	Metadata any
	// Kind is "final" or "interim".
	Kind string
}

// SendResult is what the platform confirmed.
type SendResult struct {
	Success, Suppressed, Ambiguous bool
	PlatformMessageID              string
	Error                          string
}

// Messaging is the chat-platform side the engine delivers through.
// BehaviorOutcome is what the behavior pipeline did with a final answer.
type BehaviorOutcome struct {
	// Skipped: the run has no behavior state, so the plain path applies.
	Skipped, Delivered, Suppressed bool
	Reason, Content                string
	DeliveredBubbles               int
}

// BehaviorDelivery delivers a messaging run's reply through the behavior
// pipeline. state is the run's SocialContext.Behavior.
type BehaviorDelivery interface {
	Deliver(ctx context.Context, userID int64, agentID string, state any, content, runID string) (BehaviorOutcome, error)
}

type Messaging interface {
	Send(ctx context.Context, req SendRequest) (SendResult, error)
	SendTyping(ctx context.Context, userID int64, agentID, platform, chatID string)
	// Normalize is the outgoing form of a message on a platform ("" when nothing
	// would be sent).
	Normalize(platform, content string) string
	// NormalizeInterim is the interim-update form of a message.
	NormalizeInterim(platform, content string) string
	// Split cuts a message into the chunks a platform accepts.
	Split(platform, content string) []string
	// Guide is the reply formatting guide for a platform.
	Guide(platform string) string
}

// Voice presents deliveries on live voice calls.
type Voice interface {
	// PresentDelivery hands a message to the call it belongs to; detached means
	// the call has ended and the message goes to the chat instead.
	PresentDelivery(entry *runledger.Entry) (presented, detached bool)
}

// Artifacts keeps the full text of tool results the transcript had to cut.
type Artifacts interface {
	CreateTextArtifact(ctx context.Context, userID int64, kind, filenameBase, contentType, content string, metadata map[string]any) (string, error)
}

// Integrations describes the account's connected integrations.
type Integrations interface {
	ConnectedProviderLabels(ctx context.Context, userID int64, agentID string) string
	SummarizeConnectedProviders(ctx context.Context, userID int64, agentID string, keys []string) string
}

// PromptExtras contribute run context the system prompt does not carry.
type PromptExtras interface {
	// Timeline is recent activity relevant to the request.
	Timeline(ctx context.Context, userID int64, agentID, query string) string
	// Skills lists the account's skills for the prompt.
	Skills(ctx context.Context, userID int64) string
}

// CapabilityHealth summarizes what currently needs the owner's attention ("" for
// nothing).
type CapabilityHealth interface {
	Summary(ctx context.Context, userID int64, agentID, triggerSource, platform, deviceTarget string) string
}

// SkillLearning learns from completed runs.
type SkillLearning interface {
	EnqueueCompletedRun(userID int64, agentID, runID, triggerType, triggerSource, task string, taskID int64, finalContent string, iterations int, messages []llm.Message)
}

// TaskResumer starts again the scheduled task occurrence a restart cut off.
type TaskResumer interface {
	ResumeInterruptedTask(ctx context.Context, taskID, userID int64, scheduledAt, triggerSource, runID, resumedFromRunID, note string) error
}

// GateFactory builds the policy gate for a run's trust record.
type GateFactory interface {
	Gate(run *Run) ai.Gate
}

// Deps are the engine's collaborators. Optional ones may be nil.
type Deps struct {
	DB       *dbx.DB
	Log      *slog.Logger
	Emitter  Emitter
	Settings Settings
	Models   Models
	Tools    Tools
	Agents   Agents
	Memory   *memory.Manager
	Prompts  *ai.SystemPrompts
	Failures *aimodels.Failures
	// RateLimits enforces the account's usage limits; nil disables them.
	RateLimits *aimodels.RateLimiter
	// Backend runs tools.
	Backend ai.ToolBackend
	// Optional collaborators.
	Messaging     Messaging
	Voice         Voice
	Artifacts     Artifacts
	Integrations  Integrations
	Extras        PromptExtras
	Health        CapabilityHealth
	SkillLearning SkillLearning
	Tasks         TaskResumer
	Gates         GateFactory
	SystemOne     *systemone.Service
	// Embedder finds tools by meaning; DataDir keeps their vectors
	// (tool_vectors.json). Without an embedder tools are found by words.
	Embedder memory.Embedder
	DataDir  string
	// Commands runs the workspace checkpoints' git reads; nil turns them off.
	Commands CommandRunner
	// Behavior delivers a group-chat run's final answer through the behavior
	// pipeline (bubbles, stale-turn checks); nil sends it in plain chunks.
	Behavior BehaviorDelivery
	// RunEnded is told when a run has ended (the tool backend drops what it
	// kept for it).
	RunEnded func(runID string)
	// Getenv reads the environment; nil means os.Getenv.
	Getenv func(string) string
}
