package messaging

import (
	"context"
	"errors"
	"sync"
)

// ApprovalHandler takes answers to approval prompts from chats.
type ApprovalHandler interface {
	// HandleResponse is an answer by poll, button or reaction.
	HandleResponse(userID int64, agentID string, r ApprovalResponse) bool
	// HandleInboundText is a typed answer; true means the message was that
	// answer and starts no run.
	HandleInboundText(userID int64, agentID string, msg Inbound, platform string) bool
}

var approvalsMu sync.RWMutex

// SetApprovals installs the chat approvals.
func (m *Manager) SetApprovals(h ApprovalHandler) {
	approvalsMu.Lock()
	m.approvals = h
	approvalsMu.Unlock()
}

func (m *Manager) approvalHandler() ApprovalHandler {
	approvalsMu.RLock()
	defer approvalsMu.RUnlock()
	return m.approvals
}

func (m *Manager) live(ctx context.Context, userID int64, agentID, platform string) (*managedConn, string) {
	agentID = m.resolveAgent(ctx, userID, agentID)
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.conns[connKey{userID: userID, agentID: agentID, platform: platform}], agentID
}

// ResolveAgent is the agent a value names.
func (m *Manager) ResolveAgent(ctx context.Context, userID int64, agentID string) string {
	return m.resolveAgent(ctx, userID, agentID)
}

// ConnectedAccessPolicy is the access policy of a connected platform, and
// whether it is connected.
func (m *Manager) ConnectedAccessPolicy(ctx context.Context, userID int64, agentID, platform string) (AccessPolicy, bool) {
	status, _ := m.GetPlatformStatus(ctx, userID, agentID, platform)["status"].(string)
	if status != StatusConnected {
		return AccessPolicy{}, false
	}
	policy, err := m.store.LoadAccessPolicy(ctx, userID, m.resolveAgent(ctx, userID, agentID), platform)
	if err != nil {
		return AccessPolicy{}, false
	}
	return policy, true
}

// SendApprovalPrompt puts an approval prompt in a chat: tappable where the
// platform has prompts, as text with a reply hint elsewhere.
func (m *Manager) SendApprovalPrompt(ctx context.Context, userID int64, agentID, platform, chatID string, prompt ApprovalPrompt) (string, error) {
	mc, _ := m.live(ctx, userID, agentID, platform)
	if mc == nil || mc.platform == nil {
		return "", errors.New(platform + " is not connected")
	}
	if prompter, ok := mc.platform.(ApprovalPrompter); ok {
		ref, err := prompter.SendApprovalPrompt(ctx, chatID, prompt)
		return ref.PromptID, err
	}
	res, err := mc.platform.SendMessage(ctx, chatID, prompt.Text+"\n\n"+prompt.ReplyHint, SendOptions{})
	return res.MessageID, err
}

// DeleteApprovalPrompt removes a prompt from its chat, where the platform can.
func (m *Manager) DeleteApprovalPrompt(ctx context.Context, userID int64, agentID, platform, chatID, promptID string) error {
	mc, _ := m.live(ctx, userID, agentID, platform)
	if mc == nil || mc.platform == nil {
		return nil
	}
	if prompter, ok := mc.platform.(ApprovalPrompter); ok {
		return prompter.DeleteApprovalPrompt(ctx, chatID, promptID)
	}
	return nil
}

// SendPlain sends a fixed text to a chat as it is.
func (m *Manager) SendPlain(ctx context.Context, userID int64, agentID, platform, chatID, text string) error {
	mc, _ := m.live(ctx, userID, agentID, platform)
	if mc == nil || mc.platform == nil {
		return errors.New(platform + " is not connected")
	}
	_, err := mc.platform.SendMessage(ctx, chatID, text, SendOptions{})
	return err
}
