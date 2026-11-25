// Package messaging is NeoAgent's chat-platform layer: the adapters that talk
// to Telegram, Discord, Slack, GitHub and WhatsApp, the manager that owns their
// lifecycle, the durable inbound queue, the access policy that decides who may
// speak to an agent, chat approvals, instance-wide shared accounts and the
// /api/messaging routes.
//
// Platform adapters live in subpackages and import this package; this package
// never imports them. The server wires them in through Factories.
package messaging

import (
	"context"
	"log/slog"
	"net/http"
)

// Status strings an adapter reports. The manager also stores them in
// platform_connections.status.
const (
	StatusDisconnected = "disconnected"
	StatusConnecting   = "connecting"
	StatusConnected    = "connected"
	StatusAwaitingQR   = "awaiting_qr"
	StatusReconnecting = "reconnecting"
	StatusError        = "error"
	StatusLoggedOut    = "logged_out"
)

// Platform is one live connection to a chat service for one agent (or, for a
// shared account, for the whole instance).
type Platform interface {
	// Connect logs in and starts receiving. It returns once the platform is
	// reachable (or failed); events keep flowing through Events afterwards.
	Connect(ctx context.Context) error
	// Disconnect stops receiving and releases the connection. It is safe to
	// call on a platform that never connected.
	Disconnect(ctx context.Context) error
	Status() string
	// AuthInfo is the account information the app shows, or nil.
	AuthInfo() map[string]any
	SendMessage(ctx context.Context, to, content string, opts SendOptions) (SendResult, error)
	// SetAccessPolicy replaces the policy used for inbound messages.
	SetAccessPolicy(AccessPolicy)
	AccessPolicy() AccessPolicy
}

// Optional capabilities. The manager asks with a type assertion, as Node
// checked for the method.
type (
	// Logouter drops the stored login (WhatsApp) as well as the connection.
	Logouter interface {
		Logout(ctx context.Context) error
	}
	// Reactor puts an emoji on a message.
	Reactor interface {
		SendReaction(ctx context.Context, chatID, messageID, emoji string) error
	}
	// ReadMarker sends a read receipt.
	ReadMarker interface {
		MarkRead(ctx context.Context, chatID, messageID string) error
	}
	// Typer shows or clears the typing indicator.
	Typer interface {
		SendTyping(ctx context.Context, chatID string, typing bool) error
	}
	// ApprovalPrompter puts a tappable approval prompt in a chat. A platform
	// without it gets the prompt as plain text.
	ApprovalPrompter interface {
		SendApprovalPrompt(ctx context.Context, chatID string, prompt ApprovalPrompt) (PromptRef, error)
		DeleteApprovalPrompt(ctx context.Context, chatID, promptID string) error
	}
	// AccessTargetLister names the people and spaces the platform has seen, for
	// the access screen.
	AccessTargetLister interface {
		ListAccessTargets(ctx context.Context) ([]AccessTarget, error)
	}
	// ChatAliaser lists every address a chat is known under (WhatsApp: LID and
	// phone number), in conversation lookup order.
	ChatAliaser interface {
		ConversationChatIDs(ctx context.Context, chatID string) ([]string, error)
	}
	// WebhookHandler receives POST /api/messaging/webhook/{platform}.
	WebhookHandler interface {
		HandleWebhook(r *http.Request, body []byte) WebhookResult
	}
	// OwnerChatter knows which chat is the account owner's own.
	OwnerChatter interface{ OwnerChatID() string }
)

// WebhookResult is an adapter's answer to a webhook. Body is written as JSON
// when it is a map or slice and as plain text when it is a string.
type WebhookResult struct {
	Handled bool
	Status  int
	Body    any
}

// SendOptions are the per-send extras. MediaPath is already resolved to a
// file the platform may read.
type SendOptions struct {
	MediaPath string
	// ThreadID and ReplyTo carry reply targeting where the platform has it.
	ThreadID string
	ReplyTo  string
	// RunID is the agent run the message belongs to (GitHub keeps one comment
	// per run and thread).
	RunID string
	// Extra holds platform-specific options from the caller (Node passed the
	// whole options object through).
	Extra map[string]any
}

// SendResult is what a platform returns for a delivery. A false Success with a
// reason is a delivery the platform refused.
type SendResult struct {
	Success   bool   `json:"success"`
	MessageID string `json:"messageId,omitempty"`
	Error     string `json:"error,omitempty"`
	Reason    string `json:"reason,omitempty"`
}

// ApprovalPrompt is a request for the owner's decision, already worded.
type ApprovalPrompt struct {
	Title     string
	Action    string
	Detail    string
	Reason    string
	Note      string
	Text      string
	ReplyHint string
	Options   []ApprovalOption
}

// ApprovalOption is one answer to an approval prompt.
type ApprovalOption struct {
	ID       string `json:"id"`
	Label    string `json:"label"`
	Word     string `json:"word"`
	Emoji    string `json:"emoji"`
	Decision string `json:"decision"`
	Scope    string `json:"scope"`
}

// PromptRef identifies a prompt in its chat.
type PromptRef struct{ PromptID string }

// AccessTarget is a person or space offered on the access screen. Its JSON is
// what Node sent: source, bucket, scope, value, label, subtitle.
type AccessTarget struct {
	Source     string `json:"source"`
	Bucket     string `json:"bucket"`
	Scope      string `json:"scope"`
	Value      string `json:"value"`
	Label      string `json:"label"`
	Subtitle   string `json:"subtitle"`
	SpaceScope string `json:"spaceScope,omitempty"`
	SpaceValue string `json:"spaceValue,omitempty"`
	SpaceLabel string `json:"spaceLabel,omitempty"`
}

// Config is what the manager hands a Factory.
type Config struct {
	UserID  int64
	AgentID string
	// Settings is the stored per-platform configuration (botToken, ...).
	Settings map[string]any
	// AccessPolicy is the policy to start with.
	AccessPolicy AccessPolicy
	// AccessGate, when set, decides every sender in place of AccessPolicy. The
	// instance-wide shared accounts use it.
	AccessGate func(AccessContext) AccessDecision
	// AuthDir is the directory a platform may keep its login in.
	AuthDir string
	Log     *slog.Logger
}

// Factory builds an adapter. Dependencies an adapter needs beyond Config (the
// media store, the integrations) are captured when the factory is made.
type Factory func(cfg Config, ev Events) (Platform, error)

// Events is how an adapter reports what happens on the platform. The manager
// implements it per connection and ignores events from a connection that has
// been replaced.
type Events interface {
	Message(Inbound)
	QR(code string)
	Connected()
	Disconnected(Disconnect)
	LoggedOut()
	Error(ErrorInfo)
	BlockedSender(BlockedSender)
	ApprovalResponse(ApprovalResponse)
	Reaction(Reaction)
	Membership(Membership)
}

// Disconnect describes why a platform stopped.
type Disconnect struct {
	Manual             bool   `json:"manual,omitempty"`
	RequiresUserAction bool   `json:"requiresUserAction,omitempty"`
	ShouldReconnect    *bool  `json:"shouldReconnect,omitempty"`
	WillReconnect      bool   `json:"willReconnect,omitempty"`
	Reason             string `json:"reason,omitempty"`
}

// ErrorInfo is a platform error the manager may have to react to.
type ErrorInfo struct {
	Message            string `json:"message,omitempty"`
	RequiresUserAction bool   `json:"requiresUserAction,omitempty"`
	WillReconnect      bool   `json:"willReconnect,omitempty"`
	Reason             string `json:"reason,omitempty"`
}

// ConfigurationRequiredError is a connect failure only the user can fix
// (missing credentials); the manager stops retrying.
type ConfigurationRequiredError struct{ Message string }

func (e *ConfigurationRequiredError) Error() string { return e.Message }

// RequiresUserAction reports whether retrying cannot help.
func (e *ConfigurationRequiredError) RequiresUserAction() bool { return true }

// Reason is the attention reason sent to the app.
func (e *ConfigurationRequiredError) Reason() string { return "configuration_required" }

// UserActionError is implemented by errors that need the user.
type UserActionError interface {
	error
	RequiresUserAction() bool
	Reason() string
}

// BlockedSender is a refused sender with suggestions for allowing them.
type BlockedSender struct {
	Sender      nstr         `json:"sender"`
	ChatID      nstr         `json:"chatId"`
	SenderName  nstr         `json:"senderName"`
	Meta        string       `json:"meta"`
	Suggestions []Suggestion `json:"suggestions"`
}

// ApprovalResponse is an answer to an approval prompt by poll, button or
// reaction.
type ApprovalResponse struct {
	Platform string
	ChatID   string
	PromptID string
	ChoiceID string
	Actor    Actor
}

// Actor is who answered an approval or who wrote a message.
type Actor struct {
	Sender         string
	SenderName     string
	SenderUsername string
	IsGroup        bool
	GroupID        string
	ChannelID      string
	GuildID        string
	RoleIDs        []string
	// IsAccountHolder marks the platform account's own user.
	IsAccountHolder bool
	Metadata        map[string]any
}

// Reaction is an emoji put on a message by someone else.
type Reaction struct {
	Platform        string `json:"platform"`
	ChatID          string `json:"chatId"`
	Sender          string `json:"sender"`
	SenderName      string `json:"senderName"`
	TargetMessageID string `json:"targetMessageId"`
	Emoji           string `json:"emoji"`
	Timestamp       string `json:"timestamp"`
}

// Membership is someone joining or leaving a space.
type Membership struct {
	Kind       string `json:"-"` // "member_joined" or "member_left"
	SpaceID    string `json:"spaceId"`
	SpaceName  string `json:"spaceName"`
	ChatID     string `json:"chatId"`
	MemberID   string `json:"memberId"`
	MemberName string `json:"memberName"`
	DMChatID   string `json:"dmChatId"`
	OccurredAt string `json:"occurredAt"`
}

// ReplyRef is the earlier message a message answers.
type ReplyRef struct {
	FromAgent bool    `json:"fromAgent"`
	Sender    *string `json:"sender"`
	Content   string  `json:"content"`
}

// ContextEntry is one line of recent channel context.
type ContextEntry struct {
	Author  string `json:"author,omitempty"`
	Sender  string `json:"sender,omitempty"`
	Content string `json:"content"`
	Mine    bool   `json:"mine"`
}

// Inbound is one message an adapter received and the access policy let
// through. Empty strings stand for the fields Node left unset.
type Inbound struct {
	AgentID           string
	Platform          string
	ChatID            string
	MessageID         string
	Sender            string
	SenderName        string
	SenderDisplayName string
	SenderUsername    string
	SenderTag         string
	Content           string
	IsGroup           bool
	WasMentioned      bool
	RepliedToAgent    bool
	// BotUsername, BotDisplayName and BotTag are the agent's own account, so
	// the turn-taking gate knows the names it answers to.
	BotUsername    string
	BotDisplayName string
	BotTag         string
	GroupID        string
	GroupName      string
	ChannelID      string
	ChannelName    string
	ServerID       string
	ServerName     string
	GuildID        string
	GuildName      string
	RoomID         string
	RoomName       string
	RoleIDs        []string
	MediaType      string
	LocalMediaPath string
	MediaFileName  string
	MediaError     string
	// VoiceNote is the voice-note descriptor the voice domain reads.
	VoiceNote        map[string]any
	Timestamp        string // RFC 3339 with milliseconds, like toISOString()
	ChannelContext   []ContextEntry
	ReplyToMessageID string
	ReplyTo          *ReplyRef
	ThreadID         string
	EventType        string
	Metadata         map[string]any
}
