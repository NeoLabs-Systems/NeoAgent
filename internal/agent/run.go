package agent

import (
	"context"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// Attachment is a file that came with the request.
type Attachment struct {
	Type string `json:"type"`
	Path string `json:"path"`
}

// SocialMessage is who wrote the inbound chat message a run answers.
type SocialMessage struct {
	Sender     string `json:"sender,omitempty"`
	SenderName string `json:"senderName,omitempty"`
}

// SocialContext is the chat situation of a messaging run.
type SocialContext struct {
	IsGroup bool           `json:"isGroup"`
	Message *SocialMessage `json:"message,omitempty"`
	// Behavior is the messaging behavior state the reply pipeline reads.
	Behavior any `json:"-"`
}

// RunContext is what the caller adds to the request.
type RunContext struct {
	// RawUserMessage is the person's own words when the request text wraps them
	// in instructions.
	RawUserMessage        string         `json:"rawUserMessage,omitempty"`
	AdditionalContext     string         `json:"additionalContext,omitempty"`
	IncludeRuntimeDetails bool           `json:"includeRuntimeDetails,omitempty"`
	Social                *SocialContext `json:"socialIntelligence,omitempty"`
}

// ResumableTask names the scheduled task occurrence a run serves, so a restart
// can start it again.
type ResumableTask struct {
	TaskID        int64  `json:"taskId"`
	ScheduledAt   string `json:"scheduledAt"`
	TriggerSource string `json:"triggerSource"`
}

// Options are what a run is started with. Zero values mean "not set".
type Options struct {
	RunID, Title   string
	AgentID        string
	ConversationID string
	// TriggerType is "user", "task", "subagent", "agent_delegation", ...;
	// TriggerSource the surface ("web", "messaging", "voice_live", "tasks", ...).
	TriggerType, TriggerSource string
	// Source is the messaging platform; ChatID the chat a messaging run answers.
	Source, ChatID string
	DeviceTarget   string
	WorkspaceRoot  string
	// Model is an explicit model choice for this run.
	Model string

	TaskID        int64
	ScheduledAt   string
	ResumableTask *ResumableTask
	// StageProactiveMessages holds a task's messages until the run ends.
	StageProactiveMessages   bool
	AllowExternalSideEffects bool
	ResumedFromRunID         string

	VoiceSessionID  string
	SessionBinding  map[string]any
	LatencyPriority string
	LatencyProfile  string

	Audience        string
	MemoryAudience  string
	ApprovedSpeaker bool
	Public          *PublicScope

	SkipGlobalRecall        bool
	SkipConversationHistory bool
	PriorMessages           []llm.Message
	PriorSummary            string
	HistoryWindow           int
	MediaAttachments        []Attachment
	Context                 RunContext

	AllowedToolNames    []string
	DisallowedToolNames []string
	ReadOnly            bool

	MaxTokens         int
	ReasoningEffort   string
	ModelCallTimeout  time.Duration
	MaxIterations     int
	MaxTotalTokens    int
	MaxSilenceSeconds int

	BypassUserRateLimits bool
	CaptureContent       bool
	// AllowMultipleProactiveMessages lets a task run send more than one message.
	AllowMultipleProactiveMessages bool

	// Delivery is shared with a caller that owns the delivery view (a task
	// resolves the target and sends what the run staged).
	Delivery *Delivery
	// OnBackground is told when the run moves to the background.
	OnBackground func()

	SubagentDepth int
	ParentRunID   string
	ParentTrust   *Trust
}

func (o Options) guardOptions() dyn.Map {
	m := dyn.Map{}
	if o.MaxIterations > 0 {
		m["maxIterations"] = float64(o.MaxIterations)
	}
	if o.MaxTotalTokens > 0 {
		m["maxTotalTokens"] = float64(o.MaxTotalTokens)
	}
	return m
}

func (o Options) toolOptions() tools.RunOptions {
	return tools.RunOptions{AllowedToolNames: o.AllowedToolNames, DisallowedToolNames: o.DisallowedToolNames, ReadOnly: o.ReadOnly}
}

// Result is how a run ended.
type Result struct {
	RunID       string `json:"runId"`
	Content     string `json:"content"`
	TotalTokens int    `json:"totalTokens"`
	Iterations  int    `json:"iterations"`
	// Status is "completed", "failed", "stopped" or "interrupted".
	Status            string `json:"status"`
	Error             string `json:"error,omitempty"`
	DeliveryStatus    string `json:"deliveryStatus,omitempty"`
	ExecutionComplete bool   `json:"executionCompleted,omitempty"`
}

// Staged is a task message held until the run ends.
type Staged struct {
	Platform, To, Content, Purpose, MediaPath, StagedAt string
}

// AwaitingReply is a question the run asked the user and waits on.
type AwaitingReply struct {
	Kind, Content, CreatedAt string
}

// NotifyTarget is a background task's resolved destination.
type NotifyTarget struct {
	Platform, To string
}

// Delivery is what one run knows about what it has shown the user. The outbox
// is the authority on whether a message went out; this is the per-run view the
// loop, the send tools and the task runtime read.
type Delivery struct {
	mu sync.Mutex
	// NotifyTarget: results go here, whatever the model named.
	NotifyTarget *NotifyTarget
	// FinalDelivered: the run's final answer reached the user; FinalContent is it.
	FinalDelivered bool
	FinalContent   string
	// NoResponse: the model chose silence.
	NoResponse bool
	// LastWordSent: a reply in the run's own chat is still its last word.
	LastWordSent bool
	// AwaitingReply: the run asked the user something and is waiting.
	AwaitingReply *AwaitingReply
	// Staged is a task's message held until the run ends.
	Staged *Staged
	// WrappedUp: a guard ended the run before its answer could use send_message.
	WrappedUp bool
	// Sent are the messages that answered the request, oldest first.
	Sent []string
}

// Lock and Unlock guard the view for callers that change several fields.
func (d *Delivery) Lock()   { d.mu.Lock() }
func (d *Delivery) Unlock() { d.mu.Unlock() }

// MarkSent records a message that answered the request.
func (d *Delivery) MarkSent(content string) {
	if d == nil {
		return
	}
	if text := strings.TrimSpace(content); text != "" {
		d.mu.Lock()
		d.Sent = append(d.Sent, text)
		d.mu.Unlock()
	}
}

// LastSent is the newest message that answered the request.
func (d *Delivery) LastSent() string {
	if d == nil {
		return ""
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	if len(d.Sent) == 0 {
		return ""
	}
	return d.Sent[len(d.Sent)-1]
}

type steeringItem struct {
	id, content, reason, signature string
	metadata                       map[string]any
	createdAt                      string
}

// Run is an active run as the engine and the tool handlers see it.
type Run struct {
	ID, AgentID, Title string
	UserID             int64
	TriggerType        string
	TriggerSource      string
	ConversationID     string
	DeviceTarget       string
	WorkspaceRoot      string
	VoiceSessionID     string
	SessionBinding     map[string]any
	LatencyPriority    string
	Request            string
	DeliveryScopeID    string
	Delivery           *Delivery
	Options            Options
	SubagentDepth      int
	BackgroundEligible bool
	MessagingPlatform  string
	MessagingChatID    string
	MessagingBehavior  any
	Public             *PublicScope
	StartedAt          time.Time
	WorkerID           string
	Capture            captureDecision
	Repetition         *ai.ToolRepetitionGuard

	mu                sync.Mutex
	status            string
	aborted           bool
	steeringClosed    bool
	background        string
	lastUserVisibleAt string
	trust             *Trust
	steering          []steeringItem
	systemSteering    []steeringItem
	turnCtx           context.Context
	turnCancel        context.CancelCauseFunc
	resume            chan struct{}
	pauseAvailable    bool
	toolCatalog       []tools.Definition
	activeTools       []tools.Definition
	describedIntegr   map[string]bool
	promptMetrics     map[string]any
	model             ai.ModelHandle
	selection         map[string]Candidate
	modelEventID      string
	broker            *progressBroker
	systemPrompt      string
	journal           *runJournal
	requestTurn       *llm.Message
	ledger            map[string]any
	changedPaths      []string
	checkpoints       *checkpointState
	fileDiagnostics   map[string]string
	createdAgent      string
	session           *ai.Session
	runCtx            context.Context
	runCancel         context.CancelCauseFunc
}

// Status is the run's in-memory status ("running", "pausing", "paused",
// "stopped", "interrupted").
func (r *Run) Status() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.status
}

// Aborted says whether the run was stopped or interrupted.
func (r *Run) Aborted() bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.aborted
}

// Trust is the run's trust record.
func (r *Run) Trust() *Trust {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.trust
}

// InBackground says whether the run moved to the background.
func (r *Run) InBackground() bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.background != ""
}

// Context is the run's current turn context: it ends when the run is paused,
// stopped or interrupted.
func (r *Run) Context() context.Context {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.turnCtx != nil {
		return r.turnCtx
	}
	return r.runCtx
}

// LastUserVisibleAt is when the user last saw something from the run.
func (r *Run) LastUserVisibleAt() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.lastUserVisibleAt
}

// ActiveTools are the tool definitions the model currently sees.
func (r *Run) ActiveTools() []tools.Definition {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]tools.Definition(nil), r.activeTools...)
}

// Model is the model the run currently talks to.
func (r *Run) Model() ai.ModelHandle {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.model
}

func (r *Run) setModel(m ai.ModelHandle) {
	r.mu.Lock()
	r.model = m
	r.mu.Unlock()
}

func isoNow() string { return time.Now().UTC().Format("2006-01-02T15:04:05.000Z") }

func msDuration(ms int64) time.Duration { return time.Duration(ms) * time.Millisecond }
