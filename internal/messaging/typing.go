package messaging

import (
	"context"
	"time"
)

// SendTyping shows or clears the typing indicator in a chat, on platforms that
// have one.
func (m *Manager) SendTyping(ctx context.Context, userID int64, agentID, platform, chatID string, typing bool) {
	agentID = m.resolveAgent(ctx, userID, agentID)
	m.mu.Lock()
	mc := m.conns[connKey{userID: userID, agentID: agentID, platform: platform}]
	m.mu.Unlock()
	if mc == nil || mc.platform == nil {
		return
	}
	if typer, ok := mc.platform.(Typer); ok {
		_ = typer.SendTyping(ctx, chatID, typing)
	}
}

// MarkRead sends a read receipt for a message, on platforms that have them.
func (m *Manager) MarkRead(ctx context.Context, userID int64, agentID, platform, chatID, messageID string) error {
	agentID = m.resolveAgent(ctx, userID, agentID)
	m.mu.Lock()
	mc := m.conns[connKey{userID: userID, agentID: agentID, platform: platform}]
	m.mu.Unlock()
	if mc == nil || mc.platform == nil {
		return nil
	}
	if marker, ok := mc.platform.(ReadMarker); ok {
		ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
		defer cancel()
		return marker.MarkRead(ctx, chatID, messageID)
	}
	return nil
}
