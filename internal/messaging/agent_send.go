package messaging

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
)

// AgentSend is one message an agent sends (sendMessage of the Node manager).
type AgentSend struct {
	UserID       int64
	AgentID      string
	Platform, To string
	Content      string
	// MediaReference is the attachment as the agent named it (an owned
	// artifact or a workspace path); it is resolved before sending and stored
	// with the message.
	MediaReference string
	RunID          string
	DeliveryKind   string
	Metadata       map[string]any
}

// SendError is a delivery failure; Ambiguous means earlier parts of the
// message already reached the chat.
type SendError struct {
	Msg       string
	Ambiguous bool
}

func (e *SendError) Error() string { return e.Msg }

// SendAgentMessage delivers an agent's message: long text in parts, the
// attachment with the first, "[NO RESPONSE]" as silence. The message is
// stored and shown in the web UI. The result is {success, result} or
// {success, suppressed}.
func (m *Manager) SendAgentMessage(ctx context.Context, s AgentSend) (map[string]any, error) {
	agentID := m.resolveAgent(ctx, s.UserID, s.AgentID)
	m.mu.Lock()
	mc := m.conns[connKey{userID: s.UserID, agentID: agentID, platform: s.Platform}]
	m.mu.Unlock()
	if mc == nil || mc.platform == nil {
		return nil, fmt.Errorf("Platform %s not connected", s.Platform)
	}
	mediaPath, err := m.resolveMedia(ctx, s.UserID, s.MediaReference)
	if err != nil {
		// Nothing reached the chat, so the send can be fixed and retried.
		return nil, &SendError{Msg: err.Error()}
	}
	normalized := NormalizeOutgoingMessage(s.Platform, s.Content, false)
	if mediaPath == "" && strings.ToUpper(normalized) == "[NO RESPONSE]" {
		return map[string]any{"success": true, "suppressed": true}, nil
	}
	var first *SendResult
	for i, part := range SplitToMessageLimit(s.Platform, normalized) {
		opts := SendOptions{}
		if i == 0 {
			opts.MediaPath = mediaPath
		}
		res, err := mc.platform.SendMessage(ctx, s.To, part, opts)
		if err != nil {
			return nil, &SendError{Msg: err.Error(), Ambiguous: i > 0}
		}
		if !res.Success {
			reason := res.Error
			if reason == "" {
				reason = res.Reason
			}
			if reason == "" {
				reason = "platform rejected the message"
			}
			return nil, &SendError{Msg: fmt.Sprintf("Platform %s delivery failed: %s", s.Platform, reason), Ambiguous: i > 0}
		}
		if first == nil {
			r := res
			first = &r
		}
	}
	kind := s.DeliveryKind
	if kind == "" {
		kind = "final"
	}
	var messageID, runID, media, metadata any
	if first != nil && first.MessageID != "" {
		messageID = first.MessageID
	}
	if s.RunID != "" {
		runID = s.RunID
	}
	if s.MediaReference != "" {
		media = s.MediaReference
	}
	if s.Metadata != nil {
		raw, _ := json.Marshal(s.Metadata)
		metadata = string(raw)
	}
	if m.cfg.DB != nil {
		if _, err := m.cfg.DB.W.ExecContext(ctx, `INSERT INTO messages (user_id, agent_id, run_id, role, content, platform, platform_msg_id, platform_chat_id, media_path, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
			s.UserID, agentID, runID, "assistant", normalized, s.Platform, messageID, s.To, media, metadata); err != nil {
			return nil, err
		}
	}
	if m.cfg.Emitter != nil {
		m.cfg.Emitter.EmitToUser(s.UserID, "messaging:sent", map[string]any{
			"platform": s.Platform, "agentId": agentID, "to": s.To, "content": normalized,
			"mediaPath": media, "runId": runID, "deliveryKind": kind, "metadata": s.Metadata,
		})
	}
	result := map[string]any{}
	if first != nil {
		raw, _ := json.Marshal(first)
		_ = json.Unmarshal(raw, &result)
	}
	return map[string]any{"success": true, "result": result}, nil
}

// OwnerDestination is the owner's own chat on a platform, or "": the identity
// link's chat on a shared account, the connection's own chat otherwise.
func (m *Manager) OwnerDestination(ctx context.Context, userID int64, agentID, platform string) string {
	mc, _ := m.conn(ctx, userID, agentID, platform)
	if mc == nil || mc.platform == nil {
		return ""
	}
	if shared, ok := mc.platform.(SharedRoute); ok && shared.IsSharedRoute() {
		if m.cfg.DB == nil {
			return ""
		}
		var chat sql.NullString
		if err := m.cfg.DB.R.QueryRowContext(ctx, `SELECT chat_id FROM messaging_identity_links WHERE platform = ? AND user_id = ?`, platform, userID).Scan(&chat); err != nil {
			return ""
		}
		return chat.String
	}
	if o, ok := mc.platform.(OwnerChatter); ok {
		return o.OwnerChatID()
	}
	return ""
}

func (m *Manager) reactor(ctx context.Context, userID int64, agentID, platform string) (Reactor, string) {
	agentID = m.resolveAgent(ctx, userID, agentID)
	m.mu.Lock()
	mc := m.conns[connKey{userID: userID, agentID: agentID, platform: platform}]
	m.mu.Unlock()
	if mc == nil || mc.platform == nil {
		return nil, agentID
	}
	r, _ := mc.platform.(Reactor)
	return r, agentID
}

// SupportsReactions reports whether the platform can put an emoji on a message.
func (m *Manager) SupportsReactions(ctx context.Context, userID int64, agentID, platform string) bool {
	r, _ := m.reactor(ctx, userID, agentID, platform)
	return r != nil
}

// SendReaction reacts to a message and records the reaction.
func (m *Manager) SendReaction(ctx context.Context, userID int64, agentID, platform, chatID, messageID, emoji, runID string) error {
	r, agentID := m.reactor(ctx, userID, agentID, platform)
	if r == nil {
		return fmt.Errorf("Platform %s cannot send reactions", platform)
	}
	if err := r.SendReaction(ctx, chatID, messageID, emoji); err != nil {
		return err
	}
	var run any
	if runID != "" {
		run = runID
	}
	metadata, _ := json.Marshal(map[string]any{"kind": "reaction", "targetMessageId": messageID})
	if m.cfg.DB != nil {
		if _, err := m.cfg.DB.W.ExecContext(ctx, `INSERT INTO messages (user_id, agent_id, run_id, role, content, platform, platform_chat_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			userID, agentID, run, "assistant", emoji, platform, chatID, string(metadata)); err != nil {
			return err
		}
	}
	if m.cfg.Emitter != nil {
		m.cfg.Emitter.EmitToUser(userID, "messaging:sent", map[string]any{
			"platform": platform, "agentId": agentID, "to": chatID, "content": emoji, "runId": run, "deliveryKind": "reaction",
		})
	}
	return nil
}

// SharedRoute marks a platform that stands in for an instance-wide shared
// account: the owner's chat on it is their identity link's chat.
type SharedRoute interface{ IsSharedRoute() bool }

func (m *Manager) conn(ctx context.Context, userID int64, agentID, platform string) (*managedConn, string) {
	agentID = m.resolveAgent(ctx, userID, agentID)
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.conns[connKey{userID: userID, agentID: agentID, platform: platform}], agentID
}

// ConversationChatIDs is every address a chat is known under (WhatsApp LID
// and number), the chat itself last.
func (m *Manager) ConversationChatIDs(ctx context.Context, userID int64, agentID, platform, chatID string) []string {
	var aliases []string
	if mc, _ := m.conn(ctx, userID, agentID, platform); mc != nil && mc.platform != nil {
		if a, ok := mc.platform.(ChatAliaser); ok {
			aliases, _ = a.ConversationChatIDs(ctx, chatID)
		}
	}
	seen := map[string]bool{}
	var out []string
	for _, id := range append(aliases, chatID) {
		if id != "" && !seen[id] {
			seen[id] = true
			out = append(out, id)
		}
	}
	return out
}

// ConversationFor is the conversation of a chat under any of its addresses,
// created under the first one when there is none (getOrCreateConversation).
func (m *Manager) ConversationFor(ctx context.Context, userID int64, agentID, platform, chatID, title string) (string, error) {
	if m.cfg.DB == nil {
		return "", errors.New("Database is unavailable.")
	}
	agentID = m.resolveAgent(ctx, userID, agentID)
	ids := m.ConversationChatIDs(ctx, userID, agentID, platform, chatID)
	if len(ids) == 0 {
		ids = []string{""}
	}
	args := []any{userID, agentID, platform}
	for _, id := range ids {
		args = append(args, id)
	}
	rows, err := m.cfg.DB.R.QueryContext(ctx, `SELECT id, platform_chat_id FROM conversations WHERE user_id = ? AND agent_id = ? AND platform = ? AND platform_chat_id IN (`+
		strings.TrimSuffix(strings.Repeat("?, ", len(ids)), ", ")+`)`, args...)
	if err != nil {
		return "", err
	}
	byChat := map[string]string{}
	for rows.Next() {
		var id, chat string
		if err := rows.Scan(&id, &chat); err != nil {
			rows.Close()
			return "", err
		}
		if _, ok := byChat[chat]; !ok {
			byChat[chat] = id
		}
	}
	rows.Close()
	for _, chat := range ids {
		if id, ok := byChat[chat]; ok {
			return id, nil
		}
	}
	if title == "" {
		title = platform + " — " + chatID
	}
	id := uuid.NewString()
	if _, err := m.cfg.DB.W.ExecContext(ctx, `INSERT INTO conversations (id, user_id, agent_id, platform, platform_chat_id, title) VALUES (?, ?, ?, ?, ?, ?)`,
		id, userID, agentID, platform, ids[0], title); err != nil {
		return "", err
	}
	return id, nil
}
