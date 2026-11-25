package wiring

import (
	"context"
	"encoding/json"
	"log/slog"
	"strings"
	"sync"

	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/security"
)

// Always understood, on top of the words the prompt offers in the owner's language.
var approvalReplyWords = map[string]string{"allow": "allow", "always": "always", "allow always": "always", "deny": "deny", "disallow": "deny"}

// Public threads are read by anyone, so a call is never put up for a vote there.
var noPromptPlatforms = map[string]bool{"github": true}

type chatPrompt struct {
	approvalID, agentID, platform, chatID, promptID string
	userID                                          int64
	options                                         []security.Option
	timedOutNotice                                  string
}

// chatApprovals puts approvals up in the chat a run came from and takes the
// answer from there. The app keeps getting them too; whichever answers first
// decides.
type chatApprovals struct {
	mgr     *messaging.Manager
	gate    *security.Gate
	inbound *inboundHandler
	log     *slog.Logger

	mu      sync.Mutex
	prompts map[string]*chatPrompt
}

func newChatApprovals(mgr *messaging.Manager, gate *security.Gate, inbound *inboundHandler, log *slog.Logger) *chatApprovals {
	if log == nil {
		log = slog.Default()
	}
	return &chatApprovals{mgr: mgr, gate: gate, inbound: inbound, log: log, prompts: map[string]*chatPrompt{}}
}

func (c *chatApprovals) CanOffer(userID int64, agentID string, trust *agent.Trust) bool {
	if trust == nil || trust.Origin == nil || trust.Origin.ChatID == "" || trust.Origin.Platform == "" || trust.Audience == "public" {
		return false
	}
	if noPromptPlatforms[trust.Origin.Platform] {
		return false
	}
	policy, connected := c.mgr.ConnectedAccessPolicy(context.Background(), userID, agentID, trust.Origin.Platform)
	if !connected {
		return false
	}
	if trust.Audience != "shared" {
		return true
	}
	// Someone unvetted in a DM, or a group nobody in it was listed for: no one
	// there could answer, and asking would only show them the request.
	if !trust.Origin.IsGroup {
		return false
	}
	for _, rule := range policy.SharedActorRules {
		if rule.Scope != "role" {
			return true
		}
	}
	return false
}

func (c *chatApprovals) Offer(o security.ChatOffer) {
	ctx := context.Background()
	origin := o.Trust.Origin
	copy := c.gate.Describer.Describe(ctx, o.UserID, o.AgentID, o.ToolName, o.Args, o.ArgOrder, o.Category, o.Reason, o.ReasonKey, o.ReasonParams)
	detail, reason := copy.Detail, copy.Reason
	if origin.IsGroup {
		// What a group sees stops at what is being asked: the details may be the owner's.
		detail, reason = "", ""
	}
	lines := []string{"🔐 " + copy.Title, "", copy.Action}
	if detail != "" {
		lines = append(lines, detail)
	}
	if reason != "" {
		lines = append(lines, reason)
	}
	options := security.Options(copy.Language)
	promptOptions := make([]messaging.ApprovalOption, len(options))
	for i, op := range options {
		promptOptions[i] = messaging.ApprovalOption{ID: op.ID, Label: op.Label, Word: op.Word, Emoji: op.Emoji, Decision: op.Decision, Scope: op.Scope}
	}
	prompt := messaging.ApprovalPrompt{Title: copy.Title, Action: copy.Action, Detail: detail, Reason: reason,
		Note: security.TimeLimitNote(copy.Language, int(o.Timeout.Minutes()+0.5)), Text: strings.Join(lines, "\n"),
		ReplyHint: security.ReplyHint(copy.Language), Options: promptOptions}
	entry := &chatPrompt{approvalID: o.ApprovalID, userID: o.UserID, agentID: c.mgr.ResolveAgent(ctx, o.UserID, o.AgentID), platform: origin.Platform,
		chatID: origin.ChatID, options: options, timedOutNotice: security.TimedOutNotice(copy.Language, copy.Action)}
	c.mu.Lock()
	c.prompts[o.ApprovalID] = entry
	c.mu.Unlock()
	promptID, err := c.mgr.SendApprovalPrompt(ctx, o.UserID, o.AgentID, origin.Platform, origin.ChatID, prompt)
	if err != nil {
		c.log.Warn("Could not ask for approval in chat", "platform", origin.Platform, "error", err)
		c.mu.Lock()
		delete(c.prompts, o.ApprovalID)
		c.mu.Unlock()
		return
	}
	c.mu.Lock()
	entry.promptID = promptID
	c.mu.Unlock()
	// The app can answer while the prompt is on its way.
	if !c.gate.IsPending(o.ApprovalID) {
		c.remove(entry)
	}
}

func (c *chatApprovals) Withdraw(approvalID string, timedOut bool) {
	c.mu.Lock()
	entry := c.prompts[approvalID]
	delete(c.prompts, approvalID)
	c.mu.Unlock()
	if entry == nil {
		return
	}
	if entry.promptID != "" {
		c.remove(entry)
	}
	if timedOut {
		go func() {
			if err := c.mgr.SendPlain(context.Background(), entry.userID, entry.agentID, entry.platform, entry.chatID, entry.timedOutNotice); err != nil {
				c.log.Warn("Could not say an approval timed out", "error", err)
			}
		}()
	}
}

func (c *chatApprovals) remove(entry *chatPrompt) {
	c.mu.Lock()
	delete(c.prompts, entry.approvalID)
	c.mu.Unlock()
	go func() {
		if err := c.mgr.DeleteApprovalPrompt(context.Background(), entry.userID, entry.agentID, entry.platform, entry.chatID, entry.promptID); err != nil {
			c.log.Warn("Could not remove an approval prompt", "error", err)
		}
	}()
}

// mayDecide: only someone who speaks for the owner decides.
func (c *chatApprovals) mayDecide(entry *chatPrompt, actor messaging.Actor, content string) bool {
	if actor.IsAccountHolder {
		return true
	}
	raw, _ := json.Marshal(map[string]any{"agentId": entry.agentID, "platform": entry.platform, "chatId": entry.chatID, "sender": actor.Sender,
		"senderName": actor.SenderName, "senderUsername": actor.SenderUsername, "isGroup": actor.IsGroup, "content": content, "metadata": actor.Metadata,
		"roleIds": actor.RoleIDs, "groupId": actor.GroupID, "channelId": actor.ChannelID, "guildId": actor.GuildID})
	msg := &messaging.Message{}
	_ = json.Unmarshal(raw, msg)
	if !c.inbound.resolveSenderTrust(context.Background(), entry.userID, msg) {
		return false
	}
	return msg.OwnerTrusted || msg.ApprovedSpeaker
}

func (c *chatApprovals) decide(entry *chatPrompt, choiceID string, actor messaging.Actor, content string) bool {
	var option *security.Option
	for i := range entry.options {
		if entry.options[i].ID == choiceID {
			option = &entry.options[i]
		}
	}
	if option == nil || !c.mayDecide(entry, actor, content) {
		return false
	}
	return c.gate.Decide(context.Background(), entry.approvalID, entry.userID, option.Decision, option.Scope) != nil
}

func (c *chatApprovals) HandleResponse(userID int64, agentID string, r messaging.ApprovalResponse) bool {
	c.mu.Lock()
	var entry *chatPrompt
	for _, p := range c.prompts {
		if p.platform == r.Platform && p.chatID == r.ChatID && p.promptID == r.PromptID && p.userID == userID && p.agentID == agentID {
			entry = p
		}
	}
	c.mu.Unlock()
	return entry != nil && c.decide(entry, r.ChoiceID, r.Actor, "")
}

func (c *chatApprovals) HandleInboundText(userID int64, agentID string, in messaging.Inbound, platform string) bool {
	c.mu.Lock()
	var entry *chatPrompt
	for _, p := range c.prompts {
		if p.platform == platform && p.chatID == in.ChatID && p.userID == userID && p.agentID == agentID {
			entry = p
		}
	}
	c.mu.Unlock()
	if entry == nil {
		return false
	}
	typed := strings.ToLower(strings.TrimSpace(in.Content))
	choice := ""
	for _, op := range entry.options {
		if strings.ToLower(op.Word) == typed {
			choice = op.ID
			break
		}
	}
	if choice == "" {
		choice = approvalReplyWords[typed]
	}
	if choice == "" {
		return false
	}
	actor := messaging.Actor{Sender: in.Sender, SenderName: in.SenderName, SenderUsername: in.SenderUsername, IsGroup: in.IsGroup, Metadata: in.Metadata}
	actor.GroupID, actor.RoleIDs = in.GroupID, in.RoleIDs
	return c.decide(entry, choice, actor, in.Content)
}
