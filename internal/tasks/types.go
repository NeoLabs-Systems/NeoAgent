package tasks

import (
	"context"
	"log/slog"
	"net/http"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neoagent/internal/timeline"
	"github.com/NeoLabs-Systems/neolabs-go/cron"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

// Target is a chat a task reports to.
type Target struct{ Platform, To string }

// StagedMessage is a task's message, held until the run ends.
type StagedMessage struct{ Platform, Content, MediaPath string }

// Delivery is what one run has shown the user. The runtime creates it, the
// engine and its send tools fill it in while the run works, and the runtime
// reads it afterwards to decide whether the result still has to be delivered.
type Delivery struct {
	// NotifyTarget is the run's resolved destination: results go here, whatever
	// the model named.
	NotifyTarget *Target
	// FinalDelivered and FinalContent: the run's final answer reached the user.
	FinalDelivered bool
	FinalContent   string
	// NoResponse: the model chose silence.
	NoResponse bool
	// LastWordSent: a reply in the run's own chat is still its last word.
	LastWordSent bool
	// AwaitingReply: the run asked the user something and is waiting.
	AwaitingReply any
	// Staged is a message held until the run ends.
	Staged *StagedMessage
	// WrappedUp: a guard ended the run before its answer could be sent.
	WrappedUp bool
	// Sent are the messages that answered the request, oldest first.
	Sent []string
}

// ChatContext is what a run is told of the chat it reports to.
type ChatContext struct {
	PriorMessages any
	PriorSummary  string
}

// ResumableTask names the occurrence of a task that a restart may start again.
type ResumableTask struct {
	TaskID        int64
	ScheduledAt   string
	TriggerSource string
}

// RunRequest asks the engine to run the agent for a task. Every task run
// bypasses the user's rate limits, stages proactive messages until the run
// ends, skips global recall and the conversation's own history (PriorMessages
// stand in for it) and does not stream.
type RunRequest struct {
	UserID  int64
	AgentID string
	Prompt  string
	// Model is the task's own model choice; empty means the agent's default.
	Model          string
	Title          string
	TriggerType    string
	TriggerSource  string
	ConversationID string
	TaskID         int64
	ScheduledAt    string
	// AllowMultipleProactiveMessages lets the run send more than one message.
	AllowMultipleProactiveMessages bool
	PriorMessages                  any
	PriorSummary                   string
	// Context is the trigger event's payload, an empty object for schedules.
	Context *jsv.Object
	// RunID continues a run a restart cut off; ResumedFromRunID names it.
	RunID            string
	ResumedFromRunID string
	// Resumable, when set, lets a restart start this run again once.
	Resumable *ResumableTask
	Delivery  *Delivery
}

// RunResult is what a finished run gives back. Result is the run's answer:
// text, or an object with a content, message, text, summary, finalResponse or
// final_response member. The runtime records it as the task's result and
// sends it to the task's target when the run delivered nothing itself.
type RunResult struct {
	RunID  string
	Result any
}

// Engine runs the agent. RunTask returns when the run has finished; ctx ends
// when the task runtime stops.
type Engine interface {
	RunTask(ctx context.Context, req RunRequest) (RunResult, error)
}

// Failures classifies the errors an engine run can end with. A nil Failures
// treats every error as an ordinary failure.
type Failures interface {
	// IsTransient: a rate or quota limit that will pass; the run is skipped.
	IsTransient(err error) bool
	// IsProviderHealthIssue: the model routing already tracks this failure.
	IsProviderHealthIssue(err error) bool
	// IsModelsUnavailable: routing found no usable model (AI_MODELS_UNAVAILABLE).
	IsModelsUnavailable(err error) bool
	// EnvelopeMessage is the human message inside a provider's JSON error
	// envelope, or "" when there is none.
	EnvelopeMessage(err error) string
}

// SendRequest is a task result to deliver to a chat.
type SendRequest struct {
	UserID    int64
	AgentID   string
	Target    Target
	Message   string
	MediaPath string
	// RunID, when set, is the run whose ledger must record the message (channel
	// "messaging", purpose "final", slot "task_result", metadata platform and
	// taskId) so a retry of the step can never send it twice.
	RunID  string
	TaskID int64
}

// AccessTarget is a chat a messaging platform can list for a task to report to.
type AccessTarget struct {
	To, Label, Subtitle         string
	Connected, SupportsDelivery bool
}

// Messaging is the chat side of the server. A nil Messaging means no chat
// platform is available: tasks run, their results stay with the run.
type Messaging interface {
	// IsRefusedSharedRecipient: the agent reaches the platform through the
	// instance's shared account, which would refuse this recipient.
	IsRefusedSharedRecipient(userID int64, agentID string, t Target) bool
	// ReachableSharedTarget is t, or the user's own chat when the shared
	// account would refuse t.
	ReachableSharedTarget(userID int64, agentID string, t Target) Target
	// IsPublicPlatform: threads of this platform belong to one public issue.
	IsPublicPlatform(platform string) bool
	// PlatformConnected: the agent's account on the platform is connected.
	PlatformConnected(userID int64, agentID, platform string) bool
	// ChatContext reads what a run should know of the chat it reports to: the
	// conversation under any address the chat is known by and its context window.
	ChatContext(ctx context.Context, userID int64, agentID string, t Target) (ChatContext, error)
	// FormatOutgoing prepares text for a platform (formatting rules, no raw
	// HTML where the platform shows none), keeping a [NO RESPONSE] marker.
	FormatOutgoing(platform, content string) string
	// Send delivers the message and returns the platform's answer.
	Send(ctx context.Context, req SendRequest) (any, error)
	// AccessTargets lists the chats of a platform the agent could report to.
	AccessTargets(ctx context.Context, userID int64, agentID, platform string) ([]AccessTarget, error)
}

// Integrations runs the tools of connected accounts, for the triggers that
// poll them. A nil Integrations makes every integration trigger unavailable.
type Integrations interface {
	// ExecuteTool runs one integration tool as the agent and returns its answer.
	ExecuteTool(ctx context.Context, userID int64, agentID, name string, args *jsv.Object) (any, error)
}

// Agents finds the agent a request is about; internal/agentscope's Resolver
// satisfies it.
type Agents interface {
	// Resolve returns the user's agent named by candidate (an id or a slug), or
	// their default agent.
	Resolve(ctx context.Context, userID int64, candidate string) (string, error)
	// IsMain reports whether agentID is the user's main agent.
	IsMain(ctx context.Context, userID int64, agentID string) (bool, error)
}

// Emitter pushes realtime events to a user's connected clients.
type Emitter interface {
	EmitToUser(userID int64, event string, payload any)
}

// Timeline records what happened to tasks; timeline.Service satisfies it.
type Timeline interface {
	RecordTaskLifecycle(ctx context.Context, t timeline.TaskLifecycle) (*timeline.Item, error)
}

// Config wires the task system.
type Config struct {
	DB  *dbx.DB
	Box *secretbox.Box
	Log *slog.Logger
	// Agents, Emitter and Engine are required; the rest are optional.
	Agents       Agents
	Emitter      Emitter
	Engine       Engine
	Timeline     Timeline
	Messaging    Messaging
	Integrations Integrations
	Failures     Failures
	// UserID returns the signed-in account of a request. Nil reads "userId"
	// from the session.
	UserID func(*http.Request) (int64, bool)
	// Clock drives the schedules; nil is the real clock.
	Clock cron.Clock
}
