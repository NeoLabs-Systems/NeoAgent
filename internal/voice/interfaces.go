package voice

import (
	"context"
)

// Agents resolves which of an account's agents a request is about; the agents
// table lives with the agentscope package, whose Resolver satisfies this.
type Agents interface {
	// Resolve maps a requested agent id or slug to an agent of the account,
	// falling back to its default agent.
	Resolve(ctx context.Context, userID int64, candidate string) (string, error)
	// IsMain reports whether agentID is the account's main agent.
	IsMain(ctx context.Context, userID int64, agentID string) (bool, error)
}

// Credentials are what a provider needs to be called.
type Credentials struct {
	APIKey  string
	BaseURL string
}

// LiveModel is a model a provider lists for live voice.
type LiveModel struct {
	ID string
	// Thinking marks models that take a thinking level.
	Thinking bool
	// Protocols are the live protocols a NeoRouter relays for the model.
	Protocols []string
}

// Router is a connected NeoRouter that handles a role.
type Router struct {
	APIKey  string
	APIBase string
}

// RouterModel is a model a NeoRouter offers for a role.
type RouterModel struct {
	ID   string
	Name string
}

// AIDirectory is the AI domain as voice needs it: provider credentials, model
// lists and NeoRouter connections.
type AIDirectory interface {
	// ProviderCredentials is the account's key and base URL for a provider
	// (getProviderRuntimeConfig); an unset provider has empty fields.
	ProviderCredentials(userID int64, provider, agentID string) Credentials
	// ProviderServesRole is false for a NeoRouter that does not handle role.
	ProviderServesRole(provider string, userID int64, agentID, role string) bool
	// ListVoiceModels lists the provider's live voice models, taking the last
	// list while the next one loads.
	ListVoiceModels(ctx context.Context, userID int64, provider string, creds Credentials) ([]LiveModel, error)
	// NeoRouterFor is the NeoRouter that handles role for this agent, if any.
	NeoRouterFor(userID int64, agentID, role string) (Router, bool)
	// NeoRouterModels lists the router's models for role.
	NeoRouterModels(ctx context.Context, router Router, role string) ([]RouterModel, error)
	// ResolveAPIKey finds a key for a provider the app has no stored credential
	// for: the server environment, then the API_KEYS.json file.
	ResolveAPIKey(names []string) string
}

// Persona supplies what the live model is told about the owner and the
// conversation around a call.
type Persona interface {
	// Sections are the persona sections the live model speaks with
	// (buildVoicePersonaSections).
	Sections(ctx context.Context, userID int64, agentID string) ([]string, error)
	// LocalNow is the owner's current local time as the prompt shows it.
	LocalNow(userID int64) string
	// DefaultWebConversationID is the conversation a call joins.
	DefaultWebConversationID(userID int64, agentID string) (string, error)
	// RecentContext is the conversation thread behind a call: its summary and
	// the latest messages (role, text, and whether a message carries tool calls).
	RecentContext(conversationID string, limit int) (Context, error)
}

// Context is a conversation's summary and recent messages.
type Context struct {
	Summary  string
	Messages []ContextMessage
}

// ContextMessage is one message of a conversation thread.
type ContextMessage struct {
	Role         string
	Content      string
	HasToolCalls bool
}

// RunOptions start an agent run for a hand-off.
type RunOptions struct {
	RunID          string
	AgentID        string
	ConversationID string
	// TriggerSource and Source are both "voice_live".
	TriggerSource   string
	Source          string
	ChatID          string
	VoiceSessionID  string
	LatencyPriority string
	RawUserMessage  string
}

// RunResult is how a run ended.
type RunResult struct {
	Status  string
	Content string
}

// RunMeta is what the engine knows about a run it is executing.
type RunMeta struct {
	Aborted bool
	Status  string
	Request string
}

// RunStep is one recent tool step of a run.
type RunStep struct {
	Step        string `json:"step"`
	Status      string `json:"status"`
	StartedAt   string `json:"started_at"`
	CompletedAt string `json:"completed_at,omitempty"`
	Error       string `json:"error,omitempty"`
}

// BackgroundRun describes one of the owner's running tasks.
type BackgroundRun struct {
	RunID       string    `json:"run_id"`
	Request     string    `json:"request"`
	Channel     string    `json:"channel"`
	StartedAt   string    `json:"started_at"`
	Status      string    `json:"status"`
	RecentSteps []RunStep `json:"recent_steps"`
}

// Engine is the agent loop behind live voice. Everything the live model hands
// off runs as an ordinary agent run: same orchestrator, tools, memory,
// approvals and delivery as a chat or messaging request.
type Engine interface {
	// Run executes a request and returns when it ends.
	Run(ctx context.Context, userID int64, request string, o RunOptions) (RunResult, error)
	RunMeta(runID string) (RunMeta, bool)
	// Abort stops a run; it reports whether one was stopped.
	Abort(runID string, userID int64, reason string) bool
	// BackgroundRuns lists the owner's running tasks with this agent, the chat's
	// foreground run included.
	BackgroundRuns(userID int64, agentID string) []BackgroundRun
	// ApplyBackgroundAction is applyBackgroundAction: act ("instruct" or
	// "cancel") on one of runs. origin names the call in the run's event log.
	ApplyBackgroundAction(userID int64, agentID string, runs []BackgroundRun, voiceSessionID string, args map[string]any) map[string]any
}

// Renderer renders a prompt fragment with its {{placeholders}} filled
// (ai/prompts.Render).
type Renderer func(file string, values map[string]string) string

// ErrorWriter words an error for the account that reads it: the full sanitized
// message for an admin, a plain one for everyone else.
type ErrorWriter func(userID int64, err error) string

// Realtime is the socket hub as agent calls use it.
type Realtime interface {
	// UserSocketIDs are the sockets the account has open.
	UserSocketIDs(ctx context.Context, userID int64) []string
	// EmitToUser sends an event to every socket of the account.
	EmitToUser(userID int64, event string, payload any)
	// EmitToSocket sends an event to one socket.
	EmitToSocket(socketID, event string, payload any)
	// EmitToUserExcept sends an event to the account's sockets other than one.
	EmitToUserExcept(userID int64, exceptSocketID, event string, payload any)
}

// AgentDirectory names an agent for the call screen.
type AgentDirectory interface {
	// Describe resolves agentID (resolveAgent) and returns the agent's id and
	// display name; either may be empty for an unknown agent.
	Describe(ctx context.Context, userID int64, agentID string) (id, displayName string)
}
