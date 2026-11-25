package sockets

import (
	"context"
	"net/http"
)

// The domains the socket handlers call into. Each interface lists exactly
// what services/websocket.js calls on the Node object of the same name; the
// lead satisfies them with adapters over the ported domain packages.

// Peer is a connected client as the domains see it: they address events to it
// and read its id. *realtime.Socket satisfies it.
type Peer interface {
	ID() string
	Emit(event string, args ...any) error
	Request() *http.Request // handshake request, for the client's user agent
}

// Access is services/access/admin: what an account may read of a failure or a
// run record. Unknown accounts are not admins.
type Access interface {
	// ErrorMessageForUser is errorMessageForUser.
	ErrorMessageForUser(userID int64, err error) string
	// RunRecordsForUser is runRecordsForUser: records unchanged for admins,
	// redacted for everyone else.
	RunRecordsForUser(userID int64, records RunRecords) RunRecords
}

// RunRecords is the argument and result of runRecordsForUser. Rows are the
// column-name keyed rows of agent_runs / agent_steps; events are as listEvents
// returns them. Fields a caller did not set stay nil and are not serialised.
type RunRecords struct {
	Run    map[string]any
	Runs   []map[string]any
	Steps  []map[string]any
	Events []any
}

// RunEvents is services/ai/runtime/events/run_event_store.listEvents.
type RunEvents interface {
	List(ctx context.Context, runID string) ([]any, error)
}

// Agents resolves which agent a payload names (agents/manager resolveAgentId):
// an id or slug among the user's agents, else the default agent.
type Agents interface {
	Resolve(ctx context.Context, userID int64, candidate string) (string, error)
}

// SteerableRun is a run that can take a steering message.
type SteerableRun struct {
	RunID          string
	AgentID        string
	ConversationID string
}

// SteerOptions are the options of enqueueSteering.
type SteerOptions struct {
	Platform       string
	ConversationID string
	SocketID       string
}

// RunOptions are what the web client may influence plus what the socket entry
// point decides (clientRunOptions + the fields websocket.js adds).
type RunOptions struct {
	RunID          string
	AgentID        string
	ConversationID string
	TriggerSource  string
	PriorMessages  []map[string]any
	PriorSummary   any
	// Client holds only the keys clientRunOptions lets through: agentId,
	// agent_id and conversationId of the client's options object.
	Client map[string]any
}

// RunResult is what agentEngine.run returns and storeWebRunReply consumes.
type RunResult struct {
	RunID       string
	Content     string
	TotalTokens any
	// Raw is the complete engine result, handed to Chat.StoreWebReply unchanged.
	Raw any
}

// Engine is the AI agent engine (ai/loop/agent_engine).
type Engine interface {
	FindSteerableRun(userID int64, triggerSource string) (SteerableRun, bool)
	EnqueueSteering(runID, task string, opts SteerOptions) bool
	Run(ctx context.Context, userID int64, task string, opts RunOptions) (RunResult, error)
	Abort(runID string, userID int64) error // empty runID aborts the user's current run
}

// CommandEvent is an event a chat command wants the client to see.
type CommandEvent struct {
	Name    string
	Payload any
}

// CommandResult is the outcome of the slash-command router.
type CommandResult struct {
	Handled bool
	Events  []CommandEvent
	Content string
}

// Commands is app.locals.commandRouter; it may be nil.
type Commands interface {
	Dispatch(ctx context.Context, task string, userID int64, agentID, source, socketID string) (CommandResult, error)
}

// Conversations is the memory manager's conversation bookkeeping.
type Conversations interface {
	// AssertOwned fails unless the conversation belongs to the user.
	AssertOwned(userID int64, conversationID string) error
	DefaultWebID(userID int64, agentID string) (string, error)
}

// ChatContext is getWebChatContext: the recent messages of the web chat and
// its rolling summary.
type ChatContext struct {
	Recent  []map[string]any // {role, content, ...}
	Summary any
}

// Chat is ai/settings and ai/history as the web chat uses them.
type Chat interface {
	// EnsureSettings is ensureDefaultAiSettings + getAiSettings and returns the
	// chat_history_window.
	EnsureSettings(userID int64, agentID string) (historyWindow int, err error)
	WebContext(userID int64, historyWindow int, agentID string) (ChatContext, error)
	StoreWebReply(userID int64, agentID, conversationID string, result RunResult) error
}

// Messaging is the messaging manager.
type Messaging interface {
	Connect(ctx context.Context, userID int64, platform string, config map[string]any, agentID string) (any, error)
	Disconnect(ctx context.Context, userID int64, platform, agentID string) (any, error)
	Send(ctx context.Context, userID int64, platform, to, content, agentID, mediaPath string) (any, error)
	Statuses(userID int64, agentID string) (any, error)
}

// OpenVoiceSession is the argument of openFlutterSession.
type OpenVoiceSession struct {
	UserID    int64
	AgentID   string
	Peer      Peer
	SessionID string // empty to start a new session
}

// VoiceRuntime is voice/voice_runtime_manager.
type VoiceRuntime interface {
	OpenFlutterSession(ctx context.Context, o OpenVoiceSession) (sessionID string, err error)
	AppendAudio(sessionID string, audio []byte, userID int64) error
	StartInput(sessionID string, userID int64) error
	EndInput(sessionID string, userID int64) error
	InterruptOutput(sessionID string, userID int64) error
	CancelTask(sessionID string, userID int64, runID string) error
	CloseSession(ctx context.Context, sessionID, reason string, userID int64, cancelTask bool) error
	DetachSession(ctx context.Context, sessionID, reason string, userID int64) error
}

// AcceptResult is the outcome of accepting a call.
type AcceptResult struct {
	Accepted bool
	Status   string
	// SessionID is the live call an accepted invitation opened on the socket.
	SessionID string
}

// AgentCalls is voice/agent_call_coordinator; it may be nil.
type AgentCalls interface {
	OfferPendingCall(peer Peer, userID int64)
	Accept(ctx context.Context, callID string, userID int64, peer Peer) (AcceptResult, error)
	Decline(callID string, userID int64, peer Peer, later bool) error
	HandleDisconnect(socketID string, userID int64)
}

// Approvals is security/approval_gate_service; it may be nil.
type Approvals interface {
	OfferPendingApprovals(peer Peer, userID int64)
}

// MCP is the MCP client manager.
type MCP interface {
	Status(ctx context.Context, userID int64, agentID string) (any, error)
	ListTools(ctx context.Context, serverID string, userID int64) (any, error)
	AllTools(userID int64, agentID string) (any, error)
}

// Integrations is the official integration manager; it may be nil.
type Integrations interface {
	ListProviders(userID int64, agentID string) (any, error)
}

// Memory is the memory manager's read side.
type Memory interface {
	Read(userID int64) (any, error)
	AssistantBehaviorNotes(userID int64, agentID string) (any, error)
	DailyLogs(count int, userID int64) (any, error)
	Search(ctx context.Context, query string, userID int64, agentID string) (any, error)
}

// Services bundles the collaborators. Optional ones are documented above;
// everything else must be set.
type Services struct {
	Access        Access
	Agents        Agents
	Engine        Engine
	Commands      Commands
	Conversations Conversations
	Chat          Chat
	RunEvents     RunEvents
	Messaging     Messaging
	Voice         VoiceRuntime
	Calls         AgentCalls
	Approvals     Approvals
	MCP           MCP
	Integrations  Integrations
	Memory        Memory
}
