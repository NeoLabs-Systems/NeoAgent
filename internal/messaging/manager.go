package messaging

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"

	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

// Emitter pushes realtime events to a user's connected clients.
type Emitter interface {
	EmitToUser(userID int64, event string, payload any)
}

// Engine runs the AI loop for an inbound chat message.
type Engine interface {
	HandleMessage(ctx context.Context, userID int64, agentID string, msg *Message) Outcome
}

// InboundObserver is an Engine that looks at each message before it queues;
// the returned window is how long a group message waits for more.
type InboundObserver interface {
	NoteInbound(ctx context.Context, userID int64, agentID string, msg *Message) time.Duration
}

// ManagerConfig wires the messaging Manager.
type ManagerConfig struct {
	DB        *dbx.DB
	Box       *secretbox.Box
	Agents    Agents
	Emitter   Emitter
	Engine    Engine
	Factories map[string]Factory
	// OnEvent receives what triggers can wait for: member_joined, member_left,
	// reaction_added and platform_disconnected.
	OnEvent func(name string, event map[string]any)
	// DataDir holds the platforms' logins (messaging-auth/...): the agent data
	// directory. LegacyWhatsAppDir is the pre-scoping WhatsApp login, moved into
	// the agent's folder on first use.
	DataDir           string
	LegacyWhatsAppDir string
	Log               *slog.Logger
	UserID            func(*http.Request) (int64, bool)
	// ResolveMedia turns a named attachment into the user's own host file;
	// without it attachments are refused.
	ResolveMedia MediaResolver
}

type connKey struct {
	userID   int64
	agentID  string
	platform string
}

type managedConn struct {
	key      connKey
	platform Platform
	closed   bool
	// stored is the sealed config written with each status change;
	// reconnect is the config a reconnect starts from.
	stored    string
	reconnect map[string]any
}

// Manager owns all live chat-platform connections, durable inbound queues, and
// access policies.
type Manager struct {
	cfg    ManagerConfig
	store  *Store
	queues *Queues
	log    *slog.Logger

	mu    sync.Mutex
	conns map[connKey]*managedConn

	approvals ApprovalHandler
	// shared runs the instance-wide accounts; nil when none are set up.
	shared *SharedConnections

	// suggestions are the refused senders the access screen offers to allow.
	suggestions map[connKey][]Suggestion

	// jobs tracks the inbound jobs being handled in this process.
	jobs jobTracker

	// Reconnect timers and attempt counts per connection.
	reconnectTimers   map[connKey]*time.Timer
	reconnectAttempts map[connKey]int

	ctxMu  sync.Mutex
	ctx    context.Context
	cancel context.CancelFunc
	wg     sync.WaitGroup
}

// NewManager creates a messaging Manager.
func NewManager(cfg ManagerConfig) *Manager {
	log := cfg.Log
	if log == nil {
		log = slog.Default()
	}
	ctx, cancel := context.WithCancel(context.Background())
	return &Manager{
		cfg:         cfg,
		store:       &Store{DB: cfg.DB, Agents: cfg.Agents},
		queues:      NewQueues(log),
		log:         log,
		conns:       make(map[connKey]*managedConn),
		suggestions: make(map[connKey][]Suggestion),
		ctx:         ctx,
		cancel:      cancel,
	}
}

// Start restores previously enabled platform connections.
func (m *Manager) Start(ctx context.Context) error {
	m.ctxMu.Lock()
	if m.ctx == nil || m.ctx.Err() != nil {
		m.ctx, m.cancel = context.WithCancel(ctx)
	}
	m.ctxMu.Unlock()
	if m.cfg.DB == nil {
		return nil
	}
	m.restoreConnections(ctx)
	m.recoverInBackground(JobFilter{})
	return nil
}

// Stop disconnects all active platforms and drains queues.
func (m *Manager) Stop() {
	m.mu.Lock()
	for k, t := range m.reconnectTimers {
		t.Stop()
		delete(m.reconnectTimers, k)
	}
	m.mu.Unlock()
	m.queues.CancelAll()
	m.ctxMu.Lock()
	cancel := m.cancel
	m.ctxMu.Unlock()
	if cancel != nil {
		cancel()
	}
	m.mu.Lock()
	conns := make([]*managedConn, 0, len(m.conns))
	for _, c := range m.conns {
		c.closed = true
		conns = append(conns, c)
	}
	m.conns = make(map[connKey]*managedConn)
	m.mu.Unlock()
	for _, c := range conns {
		_ = c.platform.Disconnect(context.Background())
	}
	m.wg.Wait()
}

func (m *Manager) resolveAgent(ctx context.Context, userID int64, agentID string) string {
	if m.cfg.Agents != nil {
		if id, err := m.cfg.Agents.Resolve(ctx, userID, agentID); err == nil && id != "" {
			return id
		}
	}
	if agentID == "" {
		return "main"
	}
	return agentID
}

func (m *Manager) authDir(userID int64, agentID, platform string) string {
	if m.cfg.DataDir == "" {
		return ""
	}
	if agentID == "" {
		agentID = "main"
	}
	dir := filepath.Join(m.cfg.DataDir, "messaging-auth", formatInt(userID), agentID, platform)
	_ = os.MkdirAll(filepath.Dir(dir), 0o700)
	return dir
}

// ConnectPlatform starts and persists a platform connection.
func (m *Manager) ConnectPlatform(ctx context.Context, userID int64, agentID, platform string, settings map[string]any, userInitiated bool) (map[string]any, error) {
	agentID = m.resolveAgent(ctx, userID, agentID)
	factory, ok := m.cfg.Factories[platform]
	if !ok {
		return nil, fmt.Errorf("Unsupported messaging platform: %s", platform)
	}
	if settings == nil {
		settings = map[string]any{}
	}
	policy, err := m.store.LoadAccessPolicy(ctx, userID, agentID, platform)
	if err != nil {
		policy = DefaultAccessPolicy(platform)
	}

	// Restores keep what the user chose; only their own request moves this
	// agent off a shared account.
	if m.shared != nil {
		if userInitiated {
			if err := m.shared.BeforePersonalConnect(ctx, userID, agentID, platform); err != nil {
				return nil, err
			}
		} else if m.sharedRoute(userID, agentID, platform) != nil {
			return map[string]any{"status": "skipped"}, nil
		}
	}
	key := connKey{userID: userID, agentID: agentID, platform: platform}
	settings["autoConnect"] = true
	authDir := m.authDir(userID, agentID, platform)
	if platform == "whatsapp" {
		m.moveLegacyWhatsAppAuth(authDir)
	}
	stored := m.encodeConfig(settings)
	m.mu.Lock()
	if prev := m.conns[key]; prev != nil {
		prev.closed = true
		delete(m.conns, key)
		m.mu.Unlock()
		_ = prev.platform.Disconnect(ctx)
	} else {
		m.mu.Unlock()
	}

	mc := &managedConn{key: key, stored: stored, reconnect: settings}
	ev := &connEvents{mgr: m, conn: mc}
	p, err := factory(Config{
		UserID:       userID,
		AgentID:      agentID,
		Settings:     settings,
		AccessPolicy: policy,
		AuthDir:      authDir,
		Log:          m.log.With("platform", platform, "user", userID),
	}, ev)
	if err != nil {
		return nil, err
	}
	mc.platform = p

	m.mu.Lock()
	m.conns[key] = mc
	m.mu.Unlock()

	if m.cfg.DB != nil {
		var id int64
		if m.cfg.DB.R.QueryRowContext(ctx, `SELECT id FROM platform_connections WHERE user_id = ? AND agent_id = ? AND platform = ?`, userID, agentID, platform).Scan(&id) == nil {
			_, _ = m.cfg.DB.W.ExecContext(ctx, `UPDATE platform_connections SET config = ?, status = ? WHERE user_id = ? AND agent_id = ? AND platform = ?`,
				stored, StatusConnecting, userID, agentID, platform)
		} else {
			_, _ = m.cfg.DB.W.ExecContext(ctx, `INSERT INTO platform_connections (user_id, agent_id, platform, config, status) VALUES (?, ?, ?, ?, ?)`,
				userID, agentID, platform, stored, StatusConnecting)
		}
	}

	if err := p.Connect(ctx); err != nil {
		m.mu.Lock()
		if m.conns[key] == mc {
			delete(m.conns, key)
		}
		mc.closed = true
		m.mu.Unlock()
		_ = p.Disconnect(ctx)
		return nil, err
	}
	return map[string]any{"status": p.Status()}, nil
}

// DisconnectPlatform stops a live platform connection and disables auto-connect.
func (m *Manager) DisconnectPlatform(ctx context.Context, userID int64, agentID, platform string) (map[string]any, error) {
	agentID = m.resolveAgent(ctx, userID, agentID)
	if m.shared != nil && m.sharedRoute(userID, agentID, platform) != nil {
		return m.shared.Unlink(ctx, userID, platform, agentID)
	}
	key := connKey{userID: userID, agentID: agentID, platform: platform}
	m.clearReconnect(key)
	m.mu.Lock()
	mc := m.conns[key]
	if mc != nil {
		mc.closed = true
		delete(m.conns, key)
	}
	m.mu.Unlock()
	if mc != nil {
		if err := mc.platform.Disconnect(ctx); err != nil {
			return nil, err
		}
	}
	if m.cfg.DB != nil {
		// A user's disconnect sticks: the stored config stops restores.
		config := m.storedConfig(ctx, userID, agentID, platform)
		config["autoConnect"] = false
		_, _ = m.cfg.DB.W.ExecContext(ctx, `UPDATE platform_connections SET config = ?, status = ? WHERE user_id = ? AND agent_id = ? AND platform = ?`,
			m.encodeConfig(config), StatusDisconnected, userID, agentID, platform)
	}
	return map[string]any{"status": StatusDisconnected}, nil
}

// LogoutPlatform logs out of a platform (e.g. WhatsApp) and clears stored auth.
func (m *Manager) LogoutPlatform(ctx context.Context, userID int64, agentID, platform string) (map[string]any, error) {
	agentID = m.resolveAgent(ctx, userID, agentID)
	if m.shared != nil && m.sharedRoute(userID, agentID, platform) != nil {
		return m.shared.Unlink(ctx, userID, platform, agentID)
	}
	key := connKey{userID: userID, agentID: agentID, platform: platform}
	m.clearReconnect(key)
	m.mu.Lock()
	mc := m.conns[key]
	if mc != nil {
		mc.closed = true
		delete(m.conns, key)
	}
	m.mu.Unlock()
	// WhatsApp logs out to pair again: it reconnects with the same settings
	// and offers a new QR code.
	var reconnect map[string]any
	if platform == "whatsapp" {
		if mc != nil {
			reconnect = mc.reconnect
		}
		if len(reconnect) == 0 {
			reconnect = m.storedConfig(ctx, userID, agentID, platform)
		}
	}
	if mc != nil {
		if l, ok := mc.platform.(Logouter); ok {
			_ = l.Logout(ctx)
		} else {
			_ = mc.platform.Disconnect(ctx)
		}
	}
	if dir := m.authDir(userID, agentID, platform); dir != "" {
		_ = os.RemoveAll(dir)
	}
	if m.cfg.DB != nil {
		_, _ = m.cfg.DB.W.ExecContext(ctx, `DELETE FROM platform_connections WHERE user_id = ? AND agent_id = ? AND platform = ?`, userID, agentID, platform)
	}
	if platform == "whatsapp" {
		return m.ConnectPlatform(ctx, userID, agentID, platform, reconnect, false)
	}
	return map[string]any{"status": StatusLoggedOut}, nil
}

// SendMessage sends a message through an active platform connection.
// mediaReference names the attachment as the user did (an owned artifact or a
// workspace path); it is resolved before any platform sees it.
func (m *Manager) SendMessage(ctx context.Context, userID int64, agentID, platform, to, content, mediaReference string) (SendResult, error) {
	agentID = m.resolveAgent(ctx, userID, agentID)
	m.mu.Lock()
	mc := m.conns[connKey{userID: userID, agentID: agentID, platform: platform}]
	m.mu.Unlock()
	if mc == nil || mc.platform == nil {
		return SendResult{}, fmt.Errorf("%s is not connected", platform)
	}
	mediaPath, err := m.resolveMedia(ctx, userID, mediaReference)
	if err != nil {
		return SendResult{}, err
	}
	formatted := NormalizeOutgoingMessage(platform, content, false)
	return mc.platform.SendMessage(ctx, to, formatted, SendOptions{MediaPath: mediaPath})
}

// GetAllStatuses returns the agent's configured platforms and its shared
// routes, keyed by platform.
func (m *Manager) GetAllStatuses(ctx context.Context, userID int64, agentID string) map[string]any {
	keys, entries := m.statusEntries(ctx, userID, agentID)
	out := make(map[string]any, len(keys))
	for _, k := range keys {
		out[k] = entries[k]
	}
	return out
}

// AllStatuses is GetAllStatuses in the order clients have always received.
func (m *Manager) AllStatuses(ctx context.Context, userID int64, agentID string) *jsonobj.Object {
	keys, entries := m.statusEntries(ctx, userID, agentID)
	out := jsonobj.New()
	for _, k := range keys {
		e := entries[k]
		out.Set(k, jsonobj.New("status", e["status"], "agentId", e["agentId"], "lastConnected", e["lastConnected"], "authInfo", e["authInfo"]))
	}
	return out
}

func (m *Manager) statusEntries(ctx context.Context, userID int64, agentID string) ([]string, map[string]map[string]any) {
	agentID = m.resolveAgent(ctx, userID, agentID)
	var keys []string
	entries := map[string]map[string]any{}
	add := func(platform string, entry map[string]any) {
		if _, ok := entries[platform]; !ok {
			keys = append(keys, platform)
		}
		entries[platform] = entry
	}
	if m.cfg.DB != nil {
		rows, err := m.cfg.DB.R.QueryContext(ctx, `SELECT platform, status, last_connected FROM platform_connections WHERE user_id = ? AND agent_id = ?`, userID, agentID)
		if err == nil {
			defer rows.Close()
			for rows.Next() {
				var platform string
				var status, last sql.NullString
				if rows.Scan(&platform, &status, &last) != nil {
					continue
				}
				if _, ok := m.cfg.Factories[platform]; !ok {
					continue
				}
				entry := map[string]any{"status": nullString(status), "agentId": agentID, "lastConnected": nullString(last), "authInfo": nil}
				if mc := m.liveConn(userID, agentID, platform); mc != nil {
					entry["status"] = mc.platform.Status()
					if info := mc.platform.AuthInfo(); info != nil {
						entry["authInfo"] = info
					}
				}
				add(platform, entry)
			}
		}
	}
	if m.shared != nil {
		if shared, err := m.shared.StatusEntries(ctx, userID, agentID); err == nil {
			for _, p := range sortedKeys(shared) {
				if e, ok := shared[p].(map[string]any); ok {
					add(p, e)
				}
			}
		}
	}
	return keys, entries
}

func nullString(v sql.NullString) any {
	if !v.Valid {
		return nil
	}
	return v.String
}

func (m *Manager) liveConn(userID int64, agentID, platform string) *managedConn {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.conns[connKey{userID: userID, agentID: agentID, platform: platform}]
}

// sharedRoute is the shared-account route in a slot, nil when there is none.
func (m *Manager) sharedRoute(userID int64, agentID, platform string) *SharedRoutePlatform {
	if mc := m.liveConn(userID, agentID, platform); mc != nil {
		if r, ok := mc.platform.(*SharedRoutePlatform); ok {
			return r
		}
	}
	return nil
}

// GetPlatformStatus is one platform's status: live, stored, or not configured.
func (m *Manager) GetPlatformStatus(ctx context.Context, userID int64, agentID, platform string) map[string]any {
	agentID = m.resolveAgent(ctx, userID, agentID)
	if _, ok := m.cfg.Factories[platform]; !ok {
		return map[string]any{"status": "not_supported"}
	}
	if mc := m.liveConn(userID, agentID, platform); mc != nil {
		var info any
		if a := mc.platform.AuthInfo(); a != nil {
			info = a
		}
		return map[string]any{"status": mc.platform.Status(), "authInfo": info}
	}
	status := "not_configured"
	if m.cfg.DB != nil {
		var stored sql.NullString
		if m.cfg.DB.R.QueryRowContext(ctx, `SELECT status FROM platform_connections WHERE user_id = ? AND agent_id = ? AND platform = ?`, userID, agentID, platform).Scan(&stored) == nil && stored.Valid && stored.String != "" {
			status = stored.String
		}
	}
	return map[string]any{"status": status}
}

// ListAccessTargets names the people and spaces a live connection can see; a
// platform that cannot list, or is not connected, has none.
func (m *Manager) ListAccessTargets(ctx context.Context, userID int64, agentID, platform string) []AccessTarget {
	m.mu.Lock()
	mc := m.conns[connKey{userID: userID, agentID: m.resolveAgent(ctx, userID, agentID), platform: platform}]
	m.mu.Unlock()
	if mc == nil {
		return nil
	}
	lister, ok := mc.platform.(AccessTargetLister)
	if !ok {
		return nil
	}
	targets, err := lister.ListAccessTargets(ctx)
	if err != nil {
		m.log.Warn("could not list chats", "platform", platform, "error", err)
	}
	return targets
}

// SetAccessPolicy persists and applies a normalized access policy.
func (m *Manager) SetAccessPolicy(ctx context.Context, userID int64, agentID, platform string, policy AccessPolicy) (AccessPolicy, error) {
	agentID = m.resolveAgent(ctx, userID, agentID)
	norm := policy.Normalize(platform)
	if err := m.store.upsertSetting(ctx, userID, agentID, AccessPolicyKey(platform), norm); err != nil {
		return AccessPolicy{}, err
	}
	m.mu.Lock()
	mc := m.conns[connKey{userID: userID, agentID: agentID, platform: platform}]
	m.mu.Unlock()
	if mc != nil && mc.platform != nil {
		mc.platform.SetAccessPolicy(norm)
	}
	return norm, nil
}

// UpdateAllowedEntries migrates legacy whitelist entries into an AccessPolicy.
func (m *Manager) UpdateAllowedEntries(ctx context.Context, userID int64, agentID, platform string, entries []string) error {
	agentID = m.resolveAgent(ctx, userID, agentID)
	_ = m.store.upsertSetting(ctx, userID, agentID, LegacyWhitelistKey(platform), entries)
	policy := MigrateLegacyWhitelist(platform, entries)
	_, err := m.SetAccessPolicy(ctx, userID, agentID, platform, policy)
	return err
}

// GetPlatformDevices lists known devices/sessions for a platform.
func (m *Manager) GetPlatformDevices(ctx context.Context, userID int64, agentID, platform string) []map[string]any {
	agentID = m.resolveAgent(ctx, userID, agentID)
	m.mu.Lock()
	mc := m.conns[connKey{userID: userID, agentID: agentID, platform: platform}]
	m.mu.Unlock()
	if mc == nil || mc.platform == nil {
		return []map[string]any{}
	}
	if info := mc.platform.AuthInfo(); info != nil {
		return []map[string]any{info}
	}
	return []map[string]any{}
}

// HandlePlatformWebhook dispatches an inbound HTTP webhook to a matching adapter.
func (m *Manager) HandlePlatformWebhook(platform string, r *http.Request, body []byte) WebhookResult {
	m.mu.Lock()
	var handlers []WebhookHandler
	for k, mc := range m.conns {
		if k.platform == platform {
			if wh, ok := mc.platform.(WebhookHandler); ok {
				handlers = append(handlers, wh)
			}
		}
	}
	m.mu.Unlock()
	for _, h := range handlers {
		res := h.HandleWebhook(r, body)
		if res.Handled {
			return res
		}
	}
	return WebhookResult{Handled: false, Status: http.StatusNotFound, Body: "Not found"}
}

// PlatformConnected reports whether platform is currently connected for the agent.
func (m *Manager) PlatformConnected(userID int64, agentID, platform string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	mc := m.conns[connKey{userID: userID, agentID: agentID, platform: platform}]
	return mc != nil && mc.platform != nil && mc.platform.Status() == StatusConnected
}

// IsPublicPlatform reports whether threads on platform belong to a public issue.
func (m *Manager) IsPublicPlatform(platform string) bool {
	return platform == "github"
}

// FormatOutgoing prepares text for platform delivery.
func (m *Manager) FormatOutgoing(platform, content string) string {
	return NormalizeOutgoingMessage(platform, content, false)
}

type connEvents struct {
	mgr  *Manager
	conn *managedConn
}

func (e *connEvents) active() bool {
	e.mgr.mu.Lock()
	defer e.mgr.mu.Unlock()
	return !e.conn.closed && e.mgr.conns[e.conn.key] == e.conn
}

func (e *connEvents) emit(event string, payload any) {
	if !e.active() || e.mgr.cfg.Emitter == nil {
		return
	}
	e.mgr.cfg.Emitter.EmitToUser(e.conn.key.userID, event, payload)
}

func (e *connEvents) Message(in Inbound) {
	if !e.active() {
		return
	}
	k := e.conn.key
	e.mgr.ingest(k.userID, k.agentID, k.platform, in)
}

// ingest hands an inbound message to the user's pipeline: chat approvals
// first, then the stored inbound queue and the agent.
func (m *Manager) ingest(userID int64, agentID, platform string, in Inbound) {
	if h := m.approvalHandler(); h != nil && h.HandleInboundText(userID, agentID, in, platform) {
		return
	}
	k := connKey{userID: userID, agentID: agentID, platform: platform}
	msg := Message{
		AgentID:           k.agentID,
		Platform:          k.platform,
		ChatID:            in.ChatID,
		MessageID:         nstr(in.MessageID),
		Sender:            in.Sender,
		SenderName:        nstr(in.SenderName),
		SenderDisplayName: nstr(in.SenderDisplayName),
		SenderUsername:    nstr(in.SenderUsername),
		SenderTag:         nstr(in.SenderTag),
		Content:           in.Content,
		IsGroup:           in.IsGroup,
		WasMentioned:      in.WasMentioned,
		RepliedToAgent:    in.RepliedToAgent,
		BotUsername:       nstr(in.BotUsername),
		BotDisplayName:    nstr(in.BotDisplayName),
		BotTag:            nstr(in.BotTag),
		GroupID:           nstr(in.GroupID),
		GroupName:         nstr(in.GroupName),
		ChannelID:         nstr(in.ChannelID),
		ChannelName:       nstr(in.ChannelName),
		ServerID:          nstr(in.ServerID),
		GuildID:           nstr(in.GuildID),
		GuildName:         nstr(in.GuildName),
		RoomID:            nstr(in.RoomID),
		RoomName:          nstr(in.RoomName),
		RoleIDs:           in.RoleIDs,
		MediaType:         nstr(in.MediaType),
		LocalMediaPath:    nstr(in.LocalMediaPath),
		MediaFileName:     nstr(in.MediaFileName),
		MediaError:        nstr(in.MediaError),
		VoiceNote:         in.VoiceNote,
		Timestamp:         in.Timestamp,
		ChannelContext:    in.ChannelContext,
		ReplyToMessageID:  nstr(in.ReplyToMessageID),
		ReplyTo:           in.ReplyTo,
		ThreadID:          nstr(in.ThreadID),
		EventType:         in.EventType,
		Metadata:          in.Metadata,
	}
	m.wg.Add(1)
	go func() {
		defer m.wg.Done()
		ctx := m.ctx
		if m.store == nil || m.cfg.DB == nil {
			m.runUnstored(ctx, k, &msg)
			return
		}
		queued, err := m.store.EnqueueInbound(ctx, k.userID, k.agentID, msg, in.Metadata)
		if err != nil {
			m.log.Error("store inbound message failed", "platform", k.platform, "error", err)
			return
		}
		if queued.Created {
			if m.cfg.Emitter != nil {
				m.cfg.Emitter.EmitToUser(k.userID, "messaging:message", queued.Payload)
			}
		} else if queued.Job == nil {
			m.log.Warn("duplicate message predates durable processing state; skipping replay", "platform", k.platform, "user", k.userID)
			return
		}
		payload := queued.Payload
		if payload == nil {
			payload = &msg
		}
		m.dispatchJob(ctx, queued.Job, payload)
	}()
}

// runUnstored hands a message to the agent when there is no database to keep
// it in.
func (m *Manager) runUnstored(ctx context.Context, k connKey, msg *Message) {
	if m.cfg.Engine == nil {
		return
	}
	// The behavior pipeline snapshots the chat's turn and says how long a
	// group message waits for more to merge into it.
	var window time.Duration
	if o, ok := m.cfg.Engine.(InboundObserver); ok {
		window = o.NoteInbound(ctx, k.userID, k.agentID, msg)
	}
	m.queues.Process(ctx, ProcessRequest{
		UserID:      k.userID,
		BatchWindow: window,
		Message:     msg,
		Execute: func(runCtx context.Context, queued *Message) Outcome {
			return m.cfg.Engine.HandleMessage(runCtx, k.userID, k.agentID, queued)
		},
	})
}

func (e *connEvents) QR(code string) {
	if !e.active() {
		return
	}
	k := e.conn.key
	e.emit("messaging:qr", map[string]any{"agentId": k.agentID, "platform": k.platform, "qr": code})
	if e.mgr.cfg.DB != nil {
		_, _ = e.mgr.cfg.DB.W.ExecContext(context.Background(), `UPDATE platform_connections SET status = ?, config = ? WHERE user_id = ? AND agent_id = ? AND platform = ?`,
			StatusAwaitingQR, e.conn.stored, k.userID, k.agentID, k.platform)
	}
}

func (e *connEvents) Connected() {
	if !e.active() {
		return
	}
	k := e.conn.key
	e.mgr.clearReconnect(k)
	e.emit("messaging:connected", map[string]any{"agentId": k.agentID, "platform": k.platform})
	if e.mgr.cfg.DB != nil {
		_, _ = e.mgr.cfg.DB.W.ExecContext(context.Background(), `UPDATE platform_connections SET status = ?, last_connected = datetime('now') WHERE user_id = ? AND agent_id = ? AND platform = ?`,
			StatusConnected, k.userID, k.agentID, k.platform)
	}
	e.mgr.recoverInBackground(JobFilter{UserID: &k.userID, AgentID: &k.agentID, Platform: &k.platform})
}

func (e *connEvents) Disconnected(d Disconnect) {
	if !e.active() {
		return
	}
	k := e.conn.key
	payload := map[string]any{"agentId": k.agentID, "platform": k.platform}
	raw, _ := json.Marshal(d)
	_ = json.Unmarshal(raw, &payload)
	e.emit("messaging:disconnected", payload)
	if d.RequiresUserAction {
		reason := d.Reason
		if reason == "" {
			reason = "reconnect_required"
		}
		e.mgr.attentionRequired(k, reason)
	}
	willReconnect := !d.Manual && !d.RequiresUserAction && (d.ShouldReconnect == nil || *d.ShouldReconnect)
	if !willReconnect {
		e.mgr.clearReconnect(k)
		e.mgr.setStatus(k, StatusDisconnected)
		return
	}
	e.mgr.setStatus(k, StatusReconnecting)
	if d.WillReconnect {
		e.mgr.scheduleReconnectWatchdog(k, e.conn.reconnect)
	} else {
		e.mgr.scheduleReconnect(k, e.conn.reconnect)
	}
}

func (e *connEvents) LoggedOut() {
	if !e.active() {
		return
	}
	k := e.conn.key
	e.mgr.clearReconnect(k)
	e.emit("messaging:logged_out", map[string]any{"agentId": k.agentID, "platform": k.platform})
	e.mgr.attentionRequired(k, "authentication_required")
	e.mgr.setStatus(k, StatusLoggedOut)
	e.mgr.mu.Lock()
	if e.mgr.conns[k] == e.conn {
		delete(e.mgr.conns, k)
	}
	e.mgr.mu.Unlock()
}

func (e *connEvents) Error(info ErrorInfo) {
	if !e.active() {
		return
	}
	k := e.conn.key
	if info.RequiresUserAction {
		e.mgr.clearReconnect(k)
		reason := info.Reason
		if reason == "" {
			reason = "reconnect_required"
		}
		e.mgr.attentionRequired(k, reason)
		e.mgr.setStatus(k, StatusError)
		return
	}
	if !info.WillReconnect {
		e.mgr.scheduleReconnect(k, e.conn.reconnect)
	}
}

func (e *connEvents) BlockedSender(b BlockedSender) {
	e.mgr.rememberSuggestions(e.conn.key, b.Suggestions)
	var suggestions any
	if len(b.Suggestions) > 0 {
		suggestions = b.Suggestions
	}
	var meta any
	if b.Meta != "" {
		meta = b.Meta
	}
	e.emit("messaging:blocked_sender", map[string]any{"platform": e.conn.key.platform, "sender": b.Sender, "chatId": b.ChatID,
		"senderName": b.SenderName, "meta": meta, "suggestions": suggestions})
}

func (e *connEvents) ApprovalResponse(r ApprovalResponse) {
	if !e.active() {
		return
	}
	if h := e.mgr.approvalHandler(); h != nil {
		h.HandleResponse(e.conn.key.userID, e.conn.key.agentID, r)
	}
}
func (e *connEvents) Reaction(r Reaction) {
	if !e.active() {
		return
	}
	e.emit("messaging:reaction", r)
	e.mgr.reaction(e.conn.key, r)
}
func (e *connEvents) Membership(m Membership) {
	if !e.active() {
		return
	}
	e.emit("messaging:membership", m)
	e.mgr.publish(e.conn.key, m.Kind, m)
}

var (
	platformSlugRe = regexp.MustCompile(`[^0-9a-z_+-]`)
	prefixedIDRe   = regexp.MustCompile(`[^0-9a-z:_.@#+=\-!$*]`)
	legacyIDRe     = regexp.MustCompile(`[^0-9a-z:_-]`)
	_              = errors.New
	_              = rand.Read
	_              = hex.EncodeToString
	_              = time.Second
)

func sanitizePlatform(raw string) string {
	return platformSlugRe.ReplaceAllString(strings.ToLower(strings.TrimSpace(raw)), "")
}
