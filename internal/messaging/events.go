package messaging

import (
	"context"
	"encoding/json"
	"time"
)

// publish hands one connection's event to ManagerConfig.OnEvent, with the
// account, agent and platform it belongs to.
func (m *Manager) publish(key connKey, name string, payload any) {
	if m.cfg.OnEvent == nil {
		return
	}
	event := map[string]any{}
	raw, err := json.Marshal(payload)
	if err == nil {
		err = json.Unmarshal(raw, &event)
	}
	if err != nil {
		m.log.Error("could not encode platform event", "event", name, "error", err)
		return
	}
	event["userId"], event["agentId"], event["platform"] = key.userID, key.agentID, key.platform
	m.cfg.OnEvent(name, event)
}

// reaction keeps a reaction as chat context, with the text it points at, and
// hands it to the triggers. It never starts a run by itself.
func (m *Manager) reaction(key connKey, r Reaction) {
	if err := m.recordReaction(context.Background(), key, r); err != nil {
		m.log.Error("could not record inbound reaction", "platform", key.platform, "error", err)
	}
	m.publish(key, "reaction_added", r)
}

func (m *Manager) recordReaction(ctx context.Context, key connKey, r Reaction) error {
	if m.cfg.DB == nil {
		return nil
	}
	var target string
	// A reaction to a message that was never stored has no text to quote.
	_ = m.cfg.DB.R.QueryRowContext(ctx, `SELECT content FROM messages
		WHERE user_id = ? AND agent_id IS ? AND platform = ? AND platform_chat_id = ? AND platform_msg_id = ?
		ORDER BY id DESC LIMIT 1`, key.userID, key.agentID, key.platform, r.ChatID, r.TargetMessageID).Scan(&target)
	metadata := map[string]any{"kind": "reaction", "sender": r.Sender, "senderName": nil, "targetMessageId": r.TargetMessageID, "targetText": nil}
	if r.SenderName != "" {
		metadata["senderName"] = r.SenderName
	}
	if target != "" {
		metadata["targetText"] = string([]rune(target)[:min(200, len([]rune(target)))])
	}
	raw, err := json.Marshal(metadata)
	if err != nil {
		return err
	}
	at := r.Timestamp
	if at == "" {
		at = isoNow()
	}
	_, err = m.cfg.DB.W.ExecContext(ctx, `INSERT INTO messages (user_id, agent_id, role, content, platform, platform_chat_id, metadata, created_at)
		VALUES (?, ?, 'user', ?, ?, ?, ?, ?)`, key.userID, key.agentID, r.Emoji, key.platform, r.ChatID, string(raw), at)
	return err
}

func isoNow() string { return time.Now().UTC().Format("2006-01-02T15:04:05.000Z") }
