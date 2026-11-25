package messaging

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime/debug"
	"sort"
	"time"
)

// Reconnects back off from 2 s to at most a minute.
const (
	reconnectBaseDelay = 2 * time.Second
	reconnectMaxDelay  = 60 * time.Second
)

// restoreConnections reconnects every platform the user left on. A platform
// type this server no longer has is switched off; a user's own disconnect
// (autoConnect false) is kept.
func (m *Manager) restoreConnections(ctx context.Context) {
	rows, err := m.cfg.DB.R.QueryContext(ctx, `SELECT user_id, agent_id, platform, config, status FROM platform_connections
		WHERE status IN ('connected', 'connecting', 'reconnecting', 'awaiting_qr', 'disconnected')`)
	if err != nil {
		m.log.Warn("messaging restore failed", "error", err)
		return
	}
	type saved struct {
		uid              int64
		agentID          sql.NullString
		platform, config string
	}
	var list []saved
	for rows.Next() {
		var s saved
		var cfg, status sql.NullString
		if rows.Scan(&s.uid, &s.agentID, &s.platform, &cfg, &status) == nil {
			s.config = cfg.String
			list = append(list, s)
		}
	}
	rows.Close()
	for _, s := range list {
		if _, ok := m.cfg.Factories[s.platform]; !ok {
			_, _ = m.cfg.DB.W.ExecContext(ctx, `UPDATE platform_connections SET status = 'disabled' WHERE user_id = ? AND agent_id IS ? AND platform = ?`,
				s.uid, s.agentID, s.platform)
			continue
		}
		config := m.decodeConfig(s.config)
		if config["autoConnect"] == false {
			continue
		}
		m.log.Info("restoring messaging platform", "platform", s.platform, "user", s.uid)
		agentID := s.agentID.String
		if err := m.restoreOne(ctx, s.uid, agentID, s.platform, config); err != nil {
			m.log.Warn("messaging restore failed", "platform", s.platform, "user", s.uid, "error", err)
			key := connKey{userID: s.uid, agentID: m.resolveAgent(ctx, s.uid, agentID), platform: s.platform}
			if m.stopIfNeedsUser(key, err) {
				continue
			}
			m.scheduleReconnect(key, config)
		}
	}
}

// restoreOne reconnects one saved connection. A crash inside a platform
// adapter fails only that connection, not the server.
func (m *Manager) restoreOne(ctx context.Context, userID int64, agentID, platform string, config map[string]any) (err error) {
	defer func() {
		if r := recover(); r != nil {
			m.log.Error("messaging platform crashed while connecting", "platform", platform, "user", userID, "panic", r, "stack", string(debug.Stack()))
			err = fmt.Errorf("%s connection failed: %v", platform, r)
		}
	}()
	_, err = m.ConnectPlatform(ctx, userID, agentID, platform, config, false)
	return err
}

// encodeConfig seals a platform config for storage.
func (m *Manager) encodeConfig(config map[string]any) string {
	raw, err := json.Marshal(config)
	if err != nil || len(raw) == 0 {
		return "{}"
	}
	if m.cfg.Box == nil {
		return string(raw)
	}
	sealed, err := m.cfg.Box.Seal(string(raw))
	if err != nil {
		return string(raw)
	}
	return sealed
}

// decodeConfig opens a stored config: sealed, or plain JSON from older rows.
func (m *Manager) decodeConfig(stored string) map[string]any {
	out := map[string]any{}
	if stored == "" {
		return out
	}
	plain := stored
	if m.cfg.Box != nil {
		if opened, err := m.cfg.Box.Open(stored); err == nil {
			plain = opened
		}
	}
	_ = json.Unmarshal([]byte(plain), &out)
	if out == nil {
		out = map[string]any{}
	}
	return out
}

func (m *Manager) storedConfig(ctx context.Context, userID int64, agentID, platform string) map[string]any {
	var stored sql.NullString
	_ = m.cfg.DB.R.QueryRowContext(ctx, `SELECT config FROM platform_connections WHERE user_id = ? AND agent_id = ? AND platform = ?`, userID, agentID, platform).Scan(&stored)
	return m.decodeConfig(stored.String)
}

// moveLegacyWhatsAppAuth moves the pre-scoping WhatsApp session into the
// agent's folder. It moves rather than copies: a copy left behind would come
// back after every logout and WhatsApp would never offer a new QR code.
func (m *Manager) moveLegacyWhatsAppAuth(authDir string) {
	legacy := m.cfg.LegacyWhatsAppDir
	if legacy == "" || authDir == "" {
		return
	}
	if _, err := os.Stat(legacy); err != nil {
		return
	}
	if _, err := os.Stat(authDir); err == nil {
		return
	}
	if err := os.MkdirAll(filepath.Dir(authDir), 0o700); err == nil {
		if err := os.Rename(legacy, authDir); err != nil {
			m.log.Warn("moving the legacy WhatsApp login failed", "error", err)
		}
	}
}

func (m *Manager) setStatus(key connKey, status string) {
	if m.cfg.DB == nil {
		return
	}
	_, _ = m.cfg.DB.W.ExecContext(context.Background(), `UPDATE platform_connections SET status = ? WHERE user_id = ? AND agent_id = ? AND platform = ?`,
		status, key.userID, key.agentID, key.platform)
}

func (m *Manager) attentionRequired(key connKey, reason string) {
	if m.cfg.Emitter != nil {
		m.cfg.Emitter.EmitToUser(key.userID, "messaging:attention_required", map[string]any{"agentId": key.agentID, "platform": key.platform, "reason": reason})
	}
}

// stopIfNeedsUser ends retrying for a failure only the user can fix.
func (m *Manager) stopIfNeedsUser(key connKey, err error) bool {
	var ua UserActionError
	if !errors.As(err, &ua) || !ua.RequiresUserAction() {
		return false
	}
	m.clearReconnect(key)
	reason := ua.Reason()
	if reason == "" {
		reason = "reconnect_required"
	}
	m.attentionRequired(key, reason)
	m.setStatus(key, StatusError)
	return true
}

func (m *Manager) clearReconnect(key connKey) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if t := m.reconnectTimers[key]; t != nil {
		t.Stop()
		delete(m.reconnectTimers, key)
	}
	delete(m.reconnectAttempts, key)
}

func (m *Manager) liveStatus(key connKey) string {
	if mc := m.liveConn(key.userID, key.agentID, key.platform); mc != nil {
		return mc.platform.Status()
	}
	return ""
}

// scheduleReconnectWatchdog takes over when an adapter that said it would
// reconnect by itself has not come back within the longest backoff.
func (m *Manager) scheduleReconnectWatchdog(key connKey, config map[string]any) {
	m.armTimer(key, reconnectMaxDelay, func() {
		switch m.liveStatus(key) {
		case StatusConnected, StatusAwaitingQR:
			m.clearAttempts(key)
			return
		}
		m.log.Warn("messaging adapter reconnect stalled; taking over", "platform", key.platform)
		m.scheduleReconnect(key, config)
	})
}

// scheduleReconnect retries a connection with exponential backoff.
func (m *Manager) scheduleReconnect(key connKey, config map[string]any) {
	if r := m.liveConn(key.userID, key.agentID, key.platform); r != nil {
		if _, shared := r.platform.(*SharedRoutePlatform); shared {
			return
		}
	}
	m.mu.Lock()
	if m.shuttingDown() || m.reconnectTimers[key] != nil {
		m.mu.Unlock()
		return
	}
	if m.reconnectAttempts == nil {
		m.reconnectAttempts = map[connKey]int{}
	}
	m.reconnectAttempts[key]++
	attempt := m.reconnectAttempts[key]
	m.mu.Unlock()
	delay := reconnectBaseDelay << min(attempt-1, 10)
	if delay > reconnectMaxDelay {
		delay = reconnectMaxDelay
	}
	m.setStatus(key, StatusReconnecting)
	m.armTimer(key, delay, func() {
		if m.liveStatus(key) == StatusConnected {
			m.clearAttempts(key)
			return
		}
		if _, err := m.ConnectPlatform(m.ctx, key.userID, key.agentID, key.platform, config, false); err != nil {
			m.log.Warn("messaging reconnect failed", "platform", key.platform, "error", err)
			if !m.stopIfNeedsUser(key, err) {
				m.scheduleReconnect(key, config)
			}
		}
	})
}

func (m *Manager) armTimer(key connKey, delay time.Duration, fn func()) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.shuttingDown() || m.reconnectTimers[key] != nil {
		return
	}
	if m.reconnectTimers == nil {
		m.reconnectTimers = map[connKey]*time.Timer{}
	}
	var t *time.Timer
	t = time.AfterFunc(delay, func() {
		m.mu.Lock()
		if m.reconnectTimers[key] != t || m.shuttingDown() {
			m.mu.Unlock()
			return
		}
		delete(m.reconnectTimers, key)
		m.mu.Unlock()
		fn()
	})
	m.reconnectTimers[key] = t
}

func (m *Manager) clearAttempts(key connKey) {
	m.mu.Lock()
	delete(m.reconnectAttempts, key)
	m.mu.Unlock()
}

func sortedKeys(in map[string]any) []string {
	out := make([]string, 0, len(in))
	for k := range in {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
