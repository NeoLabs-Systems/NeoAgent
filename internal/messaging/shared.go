package messaging

import (
	"context"
	"database/sql"
	"errors"
	"net/url"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/sharedmessaging"
	"github.com/NeoLabs-Systems/neolabs-go/apperr"
)

// Instance-wide messaging accounts (messaging/shared_connections.js): one
// Telegram bot or WhatsApp number serves every linked person. Inbound
// messages are authorized by the gate before the adapter touches attachments,
// then enter the normal per-user pipeline; each linked agent replies through
// its SharedRoutePlatform. Direct messages only: a group on a shared account
// would mix several people's agents. The CLI and the admin page change the
// rows from outside, so the server looks for new revisions on a timer.

const (
	sharedReconcileInterval = 5 * time.Second
	sharedReconnectBase     = 2 * time.Second
	sharedReconnectMax      = 60 * time.Second
	linkAttemptsPerWindow   = 5
	linkAttemptWindow       = 10 * time.Minute
	sharedInboundPerMinute  = 30
	linkConfirmationEmoji   = "👍"
)

// keyedWindow is a sliding-window limiter per key.
type keyedWindow struct {
	mu     sync.Mutex
	limit  int
	window time.Duration
	hits   map[string][]time.Time
	now    func() time.Time
}

func newKeyedWindow(limit int, window time.Duration) *keyedWindow {
	return &keyedWindow{limit: limit, window: window, hits: map[string][]time.Time{}, now: time.Now}
}

func (w *keyedWindow) take(key string) bool {
	w.mu.Lock()
	defer w.mu.Unlock()
	now := w.now()
	var recent []time.Time
	for _, at := range w.hits[key] {
		if now.Sub(at) < w.window {
			recent = append(recent, at)
		}
	}
	if len(recent) >= w.limit {
		w.hits[key] = recent
		return false
	}
	w.hits[key] = append(recent, now)
	if len(w.hits) > 10000 {
		for k := range w.hits {
			delete(w.hits, k)
			break
		}
	}
	return true
}

type sharedEntry struct {
	platform string
	adapter  Platform
	revision int64
	attempts int
	timer    *time.Timer
	retired  bool
}

// SharedConnections runs the instance-wide accounts inside the manager.
type SharedConnections struct {
	m     *Manager
	store *sharedmessaging.Store
	// IsAdmin lets admins connect a personal account where the server only
	// offers the shared one.
	IsAdmin func(ctx context.Context, userID int64) bool

	interval      time.Duration
	reconnectBase time.Duration
	linkAttempts  *keyedWindow
	inbound       *keyedWindow
	now           func() time.Time

	mu       sync.Mutex
	adapters map[string]*sharedEntry
	stopped  bool
	run      sync.Mutex // one reconcile at a time
	cancel   context.CancelFunc
}

// NewSharedConnections attaches the shared accounts to the manager.
func NewSharedConnections(m *Manager, store *sharedmessaging.Store) *SharedConnections {
	s := &SharedConnections{
		m: m, store: store, interval: sharedReconcileInterval, reconnectBase: sharedReconnectBase,
		linkAttempts: newKeyedWindow(linkAttemptsPerWindow, linkAttemptWindow),
		inbound:      newKeyedWindow(sharedInboundPerMinute, time.Minute),
		now:          time.Now, adapters: map[string]*sharedEntry{},
	}
	m.shared = s
	return s
}

func (s *SharedConnections) authDir(platform string) string {
	if s.m.cfg.DataDir == "" {
		return ""
	}
	return filepath.Join(s.m.cfg.DataDir, "messaging-auth", "shared", platform)
}

// Start reconciles now and then on every interval until Stop.
func (s *SharedConnections) Start(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	s.cancel = cancel
	if err := s.Reconcile(ctx); err != nil {
		s.m.log.Error("shared messaging reconcile failed", "error", err)
	}
	go func() {
		t := time.NewTicker(s.interval)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				if err := s.Reconcile(ctx); err != nil && ctx.Err() == nil {
					s.m.log.Error("shared messaging reconcile failed", "error", err)
				}
			}
		}
	}()
	return nil
}

// Stop disconnects every shared account.
func (s *SharedConnections) Stop() {
	if s.cancel != nil {
		s.cancel()
	}
	s.mu.Lock()
	s.stopped = true
	entries := make([]*sharedEntry, 0, len(s.adapters))
	for _, e := range s.adapters {
		entries = append(entries, e)
	}
	s.adapters = map[string]*sharedEntry{}
	s.mu.Unlock()
	for _, e := range entries {
		s.retire(e)
	}
}

func (s *SharedConnections) adapter(platform string) Platform {
	s.mu.Lock()
	defer s.mu.Unlock()
	if e := s.adapters[platform]; e != nil && !e.retired {
		return e.adapter
	}
	return nil
}

func strPtr(v string) *string { return &v }

func nullStr(v string) *sql.NullString { return &sql.NullString{String: v, Valid: v != ""} }

// Reconcile starts, restarts or stops each account after its row, then
// gives every link its route.
func (s *SharedConnections) Reconcile(ctx context.Context) error {
	s.run.Lock()
	defer s.run.Unlock()
	s.mu.Lock()
	stopped := s.stopped
	s.mu.Unlock()
	if stopped {
		return nil
	}
	for _, p := range sharedmessaging.Platforms {
		row, err := s.store.Get(ctx, p.ID)
		if err != nil {
			return err
		}
		s.mu.Lock()
		entry := s.adapters[p.ID]
		s.mu.Unlock()
		switch {
		case row == nil:
			if entry != nil {
				s.stopAdapter(p.ID)
			}
			if dir := s.authDir(p.ID); dir != "" {
				_ = os.RemoveAll(dir)
			}
		case !row.Enabled:
			if entry != nil {
				s.stopAdapter(p.ID)
			}
			if row.Status != StatusDisconnected {
				if err := s.store.UpdateState(ctx, p.ID, sharedmessaging.State{Status: strPtr(StatusDisconnected), StatusReason: nullStr("")}); err != nil {
					return err
				}
			}
		case entry == nil || entry.revision != row.Revision:
			s.startAdapter(ctx, p.ID, row.Revision)
		}
	}
	return s.m.SyncSharedRoutes(ctx, s.adapter)
}

func (s *SharedConnections) retire(e *sharedEntry) {
	s.mu.Lock()
	e.retired = true
	if e.timer != nil {
		e.timer.Stop()
	}
	adapter := e.adapter
	s.mu.Unlock()
	if adapter != nil {
		_ = adapter.Disconnect(context.Background())
	}
}

func (s *SharedConnections) stopAdapter(platform string) {
	s.mu.Lock()
	e := s.adapters[platform]
	delete(s.adapters, platform)
	s.mu.Unlock()
	if e == nil {
		return
	}
	s.retire(e)
	s.notifyLinked(platform, "messaging:disconnected")
}

func (s *SharedConnections) startAdapter(ctx context.Context, platform string, revision int64) {
	s.mu.Lock()
	previous := s.adapters[platform]
	e := &sharedEntry{platform: platform, revision: revision}
	s.adapters[platform] = e
	s.mu.Unlock()
	if previous != nil {
		s.retire(previous)
	}
	s.connect(ctx, e)
}

func (s *SharedConnections) live(e *sharedEntry) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return !e.retired && !s.stopped && s.adapters[e.platform] == e
}

func (s *SharedConnections) connect(ctx context.Context, e *sharedEntry) {
	if !s.live(e) {
		return
	}
	factory, ok := s.m.cfg.Factories[e.platform]
	if !ok {
		return
	}
	row, err := s.store.Get(ctx, e.platform)
	if err != nil || row == nil {
		return
	}
	settings, err := s.store.DecodeConfig(row)
	if err != nil {
		s.m.log.Warn("shared account configuration is unreadable", "platform", e.platform)
		return
	}
	dir := s.authDir(e.platform)
	if dir != "" {
		_ = os.MkdirAll(dir, 0o700)
	}
	adapter, err := factory(Config{
		Settings:   settings,
		AccessGate: func(c AccessContext) AccessDecision { return s.gate(e.platform, c) },
		AuthDir:    dir,
		Log:        s.m.log.With("platform", e.platform, "shared", true),
	}, &sharedEvents{s: s, entry: e})
	if err != nil {
		s.scheduleReconnect(e)
		return
	}
	s.mu.Lock()
	e.adapter = adapter
	s.mu.Unlock()
	_ = s.store.UpdateState(ctx, e.platform, sharedmessaging.State{Status: strPtr(StatusConnecting), StatusReason: nullStr("")})
	if err := adapter.Connect(ctx); err != nil {
		if !s.live(e) {
			return
		}
		// Raw errors from a platform library can quote the credential.
		s.m.log.Warn("shared account failed to connect", "platform", e.platform)
		var userAction UserActionError
		if errors.As(err, &userAction) && userAction.RequiresUserAction() {
			reason := userAction.Reason()
			if reason == "" {
				reason = "reconnect_required"
			}
			_ = s.store.UpdateState(context.Background(), e.platform, sharedmessaging.State{Status: strPtr(StatusError), StatusReason: nullStr(reason)})
			return
		}
		s.scheduleReconnect(e)
	}
}

func (s *SharedConnections) scheduleReconnect(e *sharedEntry) {
	s.mu.Lock()
	if e.retired || e.timer != nil || s.stopped {
		s.mu.Unlock()
		return
	}
	e.attempts++
	delay := s.reconnectBase * time.Duration(1<<min(e.attempts-1, 10))
	if delay > sharedReconnectMax {
		delay = sharedReconnectMax
	}
	e.timer = time.AfterFunc(delay, func() {
		s.mu.Lock()
		e.timer = nil
		adapter := e.adapter
		s.mu.Unlock()
		if adapter != nil {
			_ = adapter.Disconnect(context.Background())
		}
		s.connect(context.Background(), e)
	})
	s.mu.Unlock()
	_ = s.store.UpdateState(context.Background(), e.platform, sharedmessaging.State{Status: strPtr("reconnecting"), StatusReason: nullStr("connection_failed")})
}

// accountDetails names the account: the bot's @username, the number.
func accountDetails(platform string, adapter Platform) (id, label string) {
	info := adapter.AuthInfo()
	switch platform {
	case "telegram":
		if u, _ := info["username"].(string); u != "" {
			return u, "@" + u
		}
	case "whatsapp":
		if n, _ := info["number"].(string); n != "" {
			return n, "+" + n
		}
	}
	return "", ""
}

// gate runs before the adapter does anything expensive with a message. Only
// the platform's own sender field identifies the person. Refusals are quiet.
func (s *SharedConnections) gate(platform string, c AccessContext) AccessDecision {
	ctx := context.Background()
	refuse := func(reason string) AccessDecision { return AccessDecision{Reason: reason} }
	if !c.IsDirect {
		return refuse("shared_disabled")
	}
	row, err := s.store.Get(ctx, platform)
	if err != nil || row == nil || !row.Available {
		return refuse("unavailable")
	}
	externalID := c.StableSenderID
	if externalID == "" {
		externalID = c.SenderID
	}
	if externalID == "" {
		return refuse("unlinked")
	}
	if !isSendersOwnChat(platform, c.ChatID, externalID) {
		return refuse("shared_disabled")
	}
	if code := sharedmessaging.ExtractLinkCode(c.Text); code != "" {
		if s.linkAttempts.take(platform + ":" + externalID) {
			s.redeem(platform, code, externalID, c)
		}
		return refuse("link_attempt")
	}
	link, err := s.store.LinkByExternalID(ctx, platform, externalID)
	if err != nil || link == nil {
		return refuse("unlinked")
	}
	// A personal connection in this slot would send as a different identity.
	mc, _ := s.m.conn(ctx, link.UserID, link.AgentID, platform)
	if mc == nil {
		return refuse("unlinked")
	}
	if route, ok := mc.platform.(SharedRoute); !ok || !route.IsSharedRoute() {
		return refuse("unlinked")
	}
	if !s.inbound.take(platform + ":" + externalID) {
		return refuse("rate_limited")
	}
	if link.ChatID != c.ChatID {
		_ = s.store.UpdateLinkChat(ctx, link.ID, c.ChatID)
	}
	return AccessDecision{Allowed: true, OwnerUserID: link.UserID}
}

func identityLabel(platform, externalID string, c AccessContext) string {
	if c.SenderName != "" {
		units := []rune(c.SenderName)
		if len(units) > 80 {
			units = units[:80]
		}
		return string(units)
	}
	if platform == "whatsapp" {
		return "+" + normalizeWhatsAppID(externalID)
	}
	return externalID
}

func (s *SharedConnections) redeem(platform, code, externalID string, c AccessContext) {
	ctx := context.Background()
	r, err := s.store.RedeemLinkCode(ctx, platform, code, sharedmessaging.Identity{ExternalID: externalID, ChatID: c.ChatID, DisplayName: identityLabel(platform, externalID, c)}, s.now())
	if err != nil {
		s.m.log.Error("link code redemption failed", "error", err)
		return
	}
	if r.Reason == "identity_taken" {
		s.emit(r.UserID, "messaging:link_failed", map[string]any{"platform": platform, "agentId": r.AgentID, "reason": r.Reason})
		return
	}
	if !r.Linked {
		return
	}
	go func() {
		if err := s.finishLink(ctx, platform, r, c); err != nil {
			s.m.log.Error("could not finish linking", "error", err)
		}
	}()
}

// finishLink: redeeming a code is the user switching to the shared account,
// so it retires their personal connection on this agent.
func (s *SharedConnections) finishLink(ctx context.Context, platform string, r sharedmessaging.Redemption, c AccessContext) error {
	if r.PreviousAgentID != "" && r.PreviousAgentID != r.AgentID {
		s.m.mu.Lock()
		delete(s.m.conns, connKey{userID: r.UserID, agentID: r.PreviousAgentID, platform: platform})
		s.m.mu.Unlock()
	}
	if mc, _ := s.m.conn(ctx, r.UserID, r.AgentID, platform); mc != nil {
		if _, shared := mc.platform.(*SharedRoutePlatform); !shared {
			if _, err := s.m.DisconnectPlatform(ctx, r.UserID, r.AgentID, platform); err != nil {
				return err
			}
		}
	}
	if err := s.m.SyncSharedRoutes(ctx, s.adapter); err != nil {
		return err
	}
	s.emit(r.UserID, "messaging:linked", map[string]any{"platform": platform, "agentId": r.AgentID})
	s.emit(r.UserID, "messaging:connected", map[string]any{"platform": platform, "agentId": r.AgentID})
	if c.MessageID != "" {
		if reactor, ok := s.adapter(platform).(Reactor); ok {
			_ = reactor.SendReaction(ctx, c.ChatID, c.MessageID, linkConfirmationEmoji)
		}
	}
	return nil
}

func (s *SharedConnections) emit(userID int64, event string, payload any) {
	if s.m.cfg.Emitter != nil {
		s.m.cfg.Emitter.EmitToUser(userID, event, payload)
	}
}

func (s *SharedConnections) notifyLinked(platform, event string) {
	links, err := s.store.AllLinks(context.Background())
	if err != nil {
		return
	}
	for _, l := range links {
		if l.Platform == platform {
			s.emit(l.UserID, event, map[string]any{"platform": platform, "agentId": l.AgentID})
		}
	}
}

// sharedEvents receives one shared adapter's events.
type sharedEvents struct {
	s     *SharedConnections
	entry *sharedEntry
}

func (e *sharedEvents) live() bool { return e.s.live(e.entry) }

func (e *sharedEvents) state(st sharedmessaging.State) {
	_ = e.s.store.UpdateState(context.Background(), e.entry.platform, st)
}

func (e *sharedEvents) Message(in Inbound) {
	if !e.live() {
		return
	}
	link, err := e.s.store.LinkByChat(context.Background(), e.entry.platform, in.ChatID)
	if err != nil || link == nil {
		return
	}
	meta := map[string]any{}
	for k, v := range in.Metadata {
		meta[k] = v
	}
	meta["sharedConnection"] = true
	in.Metadata = meta
	e.s.m.ingest(link.UserID, link.AgentID, e.entry.platform, in)
}

func (e *sharedEvents) QR(code string) {
	if e.live() {
		e.state(sharedmessaging.State{Status: strPtr(StatusAwaitingQR), QR: code})
	}
}

func (e *sharedEvents) Connected() {
	if !e.live() {
		return
	}
	e.s.mu.Lock()
	e.entry.attempts = 0
	adapter := e.entry.adapter
	e.s.mu.Unlock()
	st := sharedmessaging.State{Status: strPtr(StatusConnected), StatusReason: nullStr("")}
	if adapter != nil {
		if id, label := accountDetails(e.entry.platform, adapter); id != "" {
			st.AccountID, st.AccountLabel = &id, &label
		}
	}
	e.state(st)
	e.s.notifyLinked(e.entry.platform, "messaging:connected")
	if mgr := e.s.m; mgr != nil {
		platform := e.entry.platform
		mgr.recoverInBackground(JobFilter{Platform: &platform})
	}
}

func (e *sharedEvents) Disconnected(d Disconnect) {
	if !e.live() || d.Manual {
		return
	}
	e.s.notifyLinked(e.entry.platform, "messaging:disconnected")
	switch {
	case d.RequiresUserAction || (d.ShouldReconnect != nil && !*d.ShouldReconnect):
		reason := d.Reason
		if reason == "" {
			reason = "reconnect_required"
		}
		e.state(sharedmessaging.State{Status: strPtr(StatusError), StatusReason: nullStr(reason)})
	case d.WillReconnect:
		e.state(sharedmessaging.State{Status: strPtr("reconnecting")})
	default:
		e.s.scheduleReconnect(e.entry)
	}
}

func (e *sharedEvents) LoggedOut() {
	if !e.live() {
		return
	}
	e.state(sharedmessaging.State{Status: strPtr(StatusLoggedOut), StatusReason: nullStr("authentication_required")})
	e.s.notifyLinked(e.entry.platform, "messaging:disconnected")
}

func (e *sharedEvents) Error(info ErrorInfo) {
	if !e.live() {
		return
	}
	switch {
	case info.RequiresUserAction:
		reason := info.Reason
		if reason == "" {
			reason = "reconnect_required"
		}
		e.state(sharedmessaging.State{Status: strPtr(StatusError), StatusReason: nullStr(reason)})
	case !info.WillReconnect:
		e.s.scheduleReconnect(e.entry)
	}
}

// BlockedSender: a gate's refusals stay quiet.
func (e *sharedEvents) BlockedSender(BlockedSender) {}

func (e *sharedEvents) ApprovalResponse(r ApprovalResponse) {
	if !e.live() {
		return
	}
	link, err := e.s.store.LinkByChat(context.Background(), e.entry.platform, r.ChatID)
	if err != nil || link == nil {
		return
	}
	if h := e.s.m.approvalHandler(); h != nil {
		h.HandleResponse(link.UserID, link.AgentID, r)
	}
}

func (e *sharedEvents) Reaction(r Reaction) {
	if !e.live() {
		return
	}
	link, err := e.s.store.LinkByChat(context.Background(), e.entry.platform, r.ChatID)
	if err != nil || link == nil {
		return
	}
	e.s.emit(link.UserID, "messaging:reaction", r)
	e.s.m.reaction(connKey{userID: link.UserID, agentID: link.AgentID, platform: e.entry.platform}, r)
}

// Membership: shared accounts serve direct chats only.
func (e *sharedEvents) Membership(Membership) {}

// --- What a user sees ---

// SharedOption is a shared account a user can link to.
type SharedOption struct {
	Platform        string         `json:"platform"`
	AuthMethod      string         `json:"authMethod"`
	Status          string         `json:"status"`
	AccountLabel    *string        `json:"accountLabel"`
	PersonalAllowed bool           `json:"personalAllowed"`
	Link            map[string]any `json:"link"`
}

func (s *SharedConnections) isAdmin(ctx context.Context, userID int64) bool {
	return s.IsAdmin != nil && s.IsAdmin(ctx, userID)
}

func nullable(v sql.NullString) *string {
	if !v.Valid {
		return nil
	}
	return &v.String
}

// ListOptions lists the accounts a user can link to: never credentials, the
// login QR, or who else is linked.
func (s *SharedConnections) ListOptions(ctx context.Context, userID int64) ([]SharedOption, error) {
	links, err := s.store.LinksForUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := []SharedOption{}
	for _, p := range sharedmessaging.Platforms {
		row, err := s.store.Get(ctx, p.ID)
		if err != nil {
			return nil, err
		}
		if row == nil || !row.Enabled || !row.Available {
			continue
		}
		var link map[string]any
		for _, l := range links {
			if l.Platform == p.ID {
				link = map[string]any{"agentId": l.AgentID, "displayName": nullable(l.DisplayName), "linkedAt": l.LinkedAt}
				break
			}
		}
		if row.Status != StatusConnected && link == nil {
			continue
		}
		out = append(out, SharedOption{
			Platform: p.ID, AuthMethod: p.AuthMethod, Status: row.Status, AccountLabel: nullable(row.AccountLabel),
			PersonalAllowed: row.AllowPersonal || s.isAdmin(ctx, userID), Link: link,
		})
	}
	return out, nil
}

func linkURL(platform, accountID, code string) any {
	if accountID == "" {
		return nil
	}
	if platform == "telegram" {
		return "https://t.me/" + accountID + "?start=" + code
	}
	return "https://wa.me/" + accountID + "?text=" + url.QueryEscape(code)
}

// StartLink makes a one-time code the user sends to the shared account.
func (s *SharedConnections) StartLink(ctx context.Context, userID int64, agentID, platform string) (map[string]any, error) {
	if err := sharedmessaging.AssertShared(platform); err != nil {
		return nil, err
	}
	row, err := s.store.Get(ctx, platform)
	if err != nil {
		return nil, err
	}
	if row == nil || !row.Enabled || !row.Available || row.Status != StatusConnected {
		return nil, apperr.New(409, "The shared "+platform+" account is not available right now", "SHARED_UNAVAILABLE")
	}
	code, expires, err := s.store.CreateLinkCode(ctx, platform, userID, agentID, s.now())
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"platform":     platform,
		"code":         code,
		"expiresAt":    time.UnixMilli(expires).UTC().Format("2006-01-02T15:04:05.000Z"),
		"accountLabel": nullable(row.AccountLabel),
		"url":          linkURL(platform, row.AccountID.String, code),
	}, nil
}

// Unlink removes the user's link (only the given agent's, when set).
func (s *SharedConnections) Unlink(ctx context.Context, userID int64, platform, agentID string) (map[string]any, error) {
	if err := sharedmessaging.AssertShared(platform); err != nil {
		return nil, err
	}
	link, err := s.store.LinkForUser(ctx, platform, userID)
	if err != nil {
		return nil, err
	}
	if link == nil || (agentID != "" && link.AgentID != agentID) {
		return map[string]any{"status": "not_configured"}, nil
	}
	if _, err := s.store.Unlink(ctx, platform, userID, nil, "app"); err != nil {
		return nil, err
	}
	s.m.mu.Lock()
	delete(s.m.conns, connKey{userID: userID, agentID: link.AgentID, platform: platform})
	s.m.mu.Unlock()
	return map[string]any{"status": "disconnected"}, nil
}

// BeforePersonalConnect: a person choosing their own account on this agent
// replaces the shared one, where the server allows personal accounts.
func (s *SharedConnections) BeforePersonalConnect(ctx context.Context, userID int64, agentID, platform string) error {
	if sharedmessaging.AssertShared(platform) != nil {
		return nil
	}
	row, err := s.store.Get(ctx, platform)
	if err != nil {
		return err
	}
	offered := row != nil && row.Enabled && row.Available
	if offered && !row.AllowPersonal && !s.isAdmin(ctx, userID) {
		return apperr.New(403, "This server only allows the shared "+platform+" account", "PERSONAL_NOT_ALLOWED")
	}
	_, err = s.Unlink(ctx, userID, platform, agentID)
	return err
}

// StatusEntries are the shared platforms of an agent for the status list.
func (s *SharedConnections) StatusEntries(ctx context.Context, userID int64, agentID string) (map[string]any, error) {
	links, err := s.store.LinksForUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := map[string]any{}
	for _, l := range links {
		if l.AgentID != agentID {
			continue
		}
		row, err := s.store.Get(ctx, l.Platform)
		if err != nil {
			return nil, err
		}
		mc, _ := s.m.conn(ctx, userID, agentID, l.Platform)
		var route *SharedRoutePlatform
		if mc != nil {
			r, ok := mc.platform.(*SharedRoutePlatform)
			if !ok {
				continue
			}
			route = r
		}
		status := StatusDisconnected
		var lastConnected any
		if row != nil {
			status = row.Status
			lastConnected = nullable(row.LastConnected)
		}
		var auth any
		if route != nil {
			status = route.Status()
			auth = route.AuthInfo()
		}
		out[l.Platform] = map[string]any{"status": status, "agentId": agentID, "lastConnected": lastConnected, "authInfo": auth}
	}
	return out, nil
}
