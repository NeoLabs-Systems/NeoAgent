package messaging

import (
	"encoding/json"
	"log/slog"
	"strings"
)

// nstr is a string that JSON writes as null when empty: Node's `value || null`.
type nstr string

func (s nstr) MarshalJSON() ([]byte, error) {
	if s == "" {
		return []byte("null"), nil
	}
	return json.Marshal(string(s))
}

// Message is an inbound message as the server stores and forwards it: the
// durable payload of messaging_inbound_jobs and the body of the
// messaging:message socket event. Its JSON keys and order are Node's.
type Message struct {
	AgentID           string         `json:"agentId"`
	Platform          string         `json:"platform"`
	ChatID            string         `json:"chatId"`
	MessageID         nstr           `json:"messageId"`
	Sender            string         `json:"sender"`
	SenderName        nstr           `json:"senderName"`
	SenderDisplayName nstr           `json:"senderDisplayName"`
	SenderUsername    nstr           `json:"senderUsername"`
	SenderTag         nstr           `json:"senderTag"`
	WasMentioned      bool           `json:"wasMentioned"`
	RepliedToAgent    bool           `json:"repliedToAgent"`
	BotUsername       nstr           `json:"botUsername,omitempty"`
	BotDisplayName    nstr           `json:"botDisplayName,omitempty"`
	BotTag            nstr           `json:"botTag,omitempty"`
	Content           string         `json:"content"`
	MediaType         nstr           `json:"mediaType"`
	LocalMediaPath    nstr           `json:"localMediaPath"`
	MediaFileName     nstr           `json:"mediaFileName"`
	MediaError        nstr           `json:"mediaError"`
	VoiceNote         map[string]any `json:"voiceNote"`
	IsGroup           bool           `json:"isGroup"`
	Timestamp         string         `json:"timestamp"`
	ChannelContext    []ContextEntry `json:"channelContext"`
	ChannelName       nstr           `json:"channelName"`
	GroupName         nstr           `json:"groupName"`
	GuildName         nstr           `json:"guildName"`
	RoomName          nstr           `json:"roomName"`
	GroupID           nstr           `json:"groupId"`
	ChannelID         nstr           `json:"channelId"`
	ServerID          nstr           `json:"serverId"`
	GuildID           nstr           `json:"guildId"`
	RoomID            nstr           `json:"roomId"`
	RoleIDs           []string       `json:"roleIds"`
	ReplyToMessageID  nstr           `json:"replyToMessageId"`
	ReplyTo           *ReplyRef      `json:"replyTo"`
	ThreadID          nstr           `json:"threadId"`
	EventType         string         `json:"eventType"`
	Metadata          map[string]any `json:"metadata"`
	InboundJobID      string         `json:"inboundJobId,omitempty"`
	InboundJobIDs     []string       `json:"inboundJobIds,omitempty"`

	// Set while the message is handled, never stored or sent to clients.
	OwnerTrusted              bool         `json:"-"`
	ApprovedSpeaker           bool         `json:"-"`
	AccessPolicyAllowUntagged bool         `json:"-"`
	AccessDeniedReason        string       `json:"-"`
	WorkspaceMediaPath        string       `json:"-"`
	MessageBatch              []BatchEntry `json:"-"`
	BehaviorTurnEpoch         int64        `json:"-"`
}

// BatchEntry is one message of a batch collected in a group chat.
type BatchEntry struct {
	Sender         nstr   `json:"sender"`
	SenderName     nstr   `json:"senderName"`
	Content        string `json:"content"`
	MessageID      nstr   `json:"messageId"`
	Timestamp      nstr   `json:"timestamp"`
	WasMentioned   bool   `json:"wasMentioned"`
	RepliedToAgent bool   `json:"repliedToAgent"`
}

// AccessGuard is the shared inbound access check of every adapter: it applies
// the platform's policy (or the shared-account gate), and for a refused sender
// logs a hint and reports a BlockedSender so the app can offer to allow them.
type AccessGuard struct {
	platform string
	policy   AccessPolicy
	gate     func(AccessContext) AccessDecision
	events   Events
	log      *slog.Logger
}

// NewAccessGuard builds the guard of an adapter from its Config.
func NewAccessGuard(platform string, cfg Config, ev Events) *AccessGuard {
	policy := DefaultAccessPolicy(platform)
	if cfg.AccessPolicy.SchemaVersion != 0 {
		policy = cfg.AccessPolicy.Normalize(platform)
	}
	log := cfg.Log
	if log == nil {
		log = slog.Default()
	}
	return &AccessGuard{platform: platform, policy: policy, gate: cfg.AccessGate, events: ev, log: log}
}

// SetPolicy replaces the policy.
func (g *AccessGuard) SetPolicy(p AccessPolicy) { g.policy = p.Normalize(g.platform) }

// Policy is the current policy.
func (g *AccessGuard) Policy() AccessPolicy { return g.policy }

// Gated reports whether an instance-wide gate decides in place of a policy.
func (g *AccessGuard) Gated() bool { return g.gate != nil }

// Evaluate decides without reporting anything.
func (g *AccessGuard) Evaluate(c AccessContext) AccessDecision {
	if g.gate != nil {
		return g.gate(c)
	}
	return EvaluateAccessPolicy(g.policy, c, g.platform)
}

var accessDeniedHints = map[string]string{
	"direct_disabled":     "direct messages are switched off for this platform",
	"direct_not_allowed":  "the sender is not on the direct-message allowlist",
	"shared_disabled":     "group messages are switched off for this platform",
	"shared_not_allowed":  "the group is not on the allowlist",
	"unsupported_context": "the message was neither a direct nor a group message",
}

// MaskSenderID hides most of a sender id for logs.
func MaskSenderID(value string) string {
	text := jsTrim(value)
	switch {
	case text == "":
		return "(unknown)"
	case len([]rune(text)) <= 4:
		return string([]rune(text)[:1]) + "***"
	}
	r := []rune(text)
	return string(r[:2]) + "***" + string(r[len(r)-2:])
}

// Check evaluates an inbound message and, when refused by the policy, leaves a
// log line and a BlockedSender event. A gate's refusals stay quiet.
func (g *AccessGuard) Check(c AccessContext, o BlockedOptions) AccessDecision {
	d := g.Evaluate(c)
	if d.Allowed || g.gate != nil {
		return d
	}
	hint := accessDeniedHints[d.Reason]
	if hint == "" {
		hint = d.Reason
	}
	g.log.Warn(strings.Join([]string{g.platform, ": ignored a message from ", MaskSenderID(firstNonEmpty(c.SenderID, c.PhoneNumber)),
		" because ", hint, ". Allow the sender under Messaging access to let it through."}, ""))
	g.events.BlockedSender(BuildBlockedSender(g.platform, c, o))
	return d
}
