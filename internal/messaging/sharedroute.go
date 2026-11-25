package messaging

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"
)

// Shared routes (messaging/shared_route.js): what one user's agent holds in
// place of a platform connection when it reaches Telegram or WhatsApp through
// the instance-wide shared account. The manager treats it like any platform,
// so runs, typing and delivery need no second path; this is where the shared
// account is narrowed to that user's own chat. The identity link is read on
// every call, so an unlink applies at once.

const sharedOutboundPerMinute = 60

// SharedAdapter returns the running shared account of a platform, or nil.
type SharedAdapter func(platform string) Platform

// CodedError is an error with a machine code (SHARED_RECIPIENT_NOT_ALLOWED,
// SHARED_RATE_LIMITED).
type CodedError struct {
	Msg, Code string
}

func (e *CodedError) Error() string     { return e.Msg }
func (e *CodedError) ErrorCode() string { return e.Code }

type identityLink struct {
	externalID, chatID, agentID string
	displayName                 sql.NullString
}

// sharedChatKey compares chat addresses: Telegram's dm_ prefix and WhatsApp's
// JID forms are the same chat.
func sharedChatKey(platform, value string) string {
	raw := strings.TrimSpace(value)
	switch platform {
	case "telegram":
		return strings.TrimPrefix(raw, "dm_")
	case "whatsapp":
		return normalizeWhatsAppID(raw)
	}
	return raw
}

// isSendersOwnChat: only the person's own direct chat with the shared account
// may receive replies; a broadcast list or status looks direct too.
func isSendersOwnChat(platform, chatID, externalID string) bool {
	switch platform {
	case "telegram":
		return chatID == "dm_"+externalID
	case "whatsapp":
		if strings.HasSuffix(chatID, "@lid") {
			return true
		}
		return strings.HasSuffix(chatID, "@s.whatsapp.net") && normalizeWhatsAppID(chatID) == externalID
	}
	return false
}

func normalizeWhatsAppID(value string) string {
	raw := strings.ToLower(strings.TrimSpace(value))
	if raw == "" {
		return ""
	}
	base := strings.Split(raw, "@")[0]
	primary := strings.Split(base, ":")[0]
	var digits strings.Builder
	for _, r := range primary {
		if r >= '0' && r <= '9' {
			digits.WriteRune(r)
		}
	}
	if digits.Len() > 0 {
		return digits.String()
	}
	return primary
}

// slidingWindow allows limit events per window.
type slidingWindow struct {
	mu     sync.Mutex
	limit  int
	window time.Duration
	hits   []time.Time
	now    func() time.Time
}

func (w *slidingWindow) take() bool {
	w.mu.Lock()
	defer w.mu.Unlock()
	now := w.now()
	recent := w.hits[:0]
	for _, at := range w.hits {
		if now.Sub(at) < w.window {
			recent = append(recent, at)
		}
	}
	w.hits = recent
	if len(w.hits) >= w.limit {
		return false
	}
	w.hits = append(w.hits, now)
	return true
}

// SharedRoutePlatform is one agent's route through a shared account.
type SharedRoutePlatform struct {
	platform string
	userID   int64
	agentID  string
	db       queryRower
	adapter  SharedAdapter
	limiter  *slidingWindow
	policy   AccessPolicy
}

type queryRower interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

// NewSharedRoute builds the route of an agent's identity link.
func NewSharedRoute(db queryRower, platform string, userID int64, agentID string, adapter SharedAdapter) *SharedRoutePlatform {
	return &SharedRoutePlatform{
		platform: platform, userID: userID, agentID: agentID, db: db, adapter: adapter,
		limiter: &slidingWindow{limit: sharedOutboundPerMinute, window: time.Minute, now: time.Now},
	}
}

// IsSharedRoute marks the route for OwnerDestination and unlinking.
func (p *SharedRoutePlatform) IsSharedRoute() bool { return true }

// activeLink is this agent's link, nil when it is gone or belongs to another agent.
func (p *SharedRoutePlatform) activeLink(ctx context.Context) *identityLink {
	var l identityLink
	err := p.db.QueryRowContext(ctx, `SELECT external_id, chat_id, agent_id, display_name FROM messaging_identity_links WHERE platform = ? AND user_id = ?`, p.platform, p.userID).
		Scan(&l.externalID, &l.chatID, &l.agentID, &l.displayName)
	if err != nil || l.agentID != p.agentID {
		return nil
	}
	return &l
}

func (p *SharedRoutePlatform) running() Platform {
	if p.adapter == nil {
		return nil
	}
	return p.adapter(p.platform)
}

// deliveryTarget is the linked chat; replies go there whatever form to used.
func (p *SharedRoutePlatform) deliveryTarget(ctx context.Context, to string) (Platform, string, error) {
	link := p.activeLink(ctx)
	if link == nil {
		return nil, "", fmt.Errorf("This agent is no longer linked to the shared %s account.", p.platform)
	}
	refused := &CodedError{Msg: fmt.Sprintf("The shared %s account can only message your own linked chat.", p.platform), Code: "SHARED_RECIPIENT_NOT_ALLOWED"}
	if !isSendersOwnChat(p.platform, link.chatID, link.externalID) {
		return nil, "", refused
	}
	requested := sharedChatKey(p.platform, to)
	if requested != sharedChatKey(p.platform, link.chatID) && requested != link.externalID {
		return nil, "", refused
	}
	adapter := p.running()
	if adapter == nil {
		return nil, "", fmt.Errorf("The shared %s account is not connected.", p.platform)
	}
	return adapter, link.chatID, nil
}

func (p *SharedRoutePlatform) Connect(context.Context) error { return nil }

// Disconnect leaves the shared account running for everyone else.
func (p *SharedRoutePlatform) Disconnect(context.Context) error { return nil }

func (p *SharedRoutePlatform) Status() string {
	if p.activeLink(context.Background()) == nil {
		return StatusDisconnected
	}
	if adapter := p.running(); adapter != nil {
		return adapter.Status()
	}
	return StatusDisconnected
}

// AuthInfo is never the shared account's own: for WhatsApp that is the QR.
func (p *SharedRoutePlatform) AuthInfo() map[string]any {
	link := p.activeLink(context.Background())
	if link == nil {
		return nil
	}
	var label any
	if link.displayName.Valid && link.displayName.String != "" {
		label = link.displayName.String
	}
	return map[string]any{"shared": true, "label": label}
}

func (p *SharedRoutePlatform) SetAccessPolicy(a AccessPolicy) { p.policy = a }
func (p *SharedRoutePlatform) AccessPolicy() AccessPolicy     { return p.policy }

func (p *SharedRoutePlatform) SendMessage(ctx context.Context, to, content string, opts SendOptions) (SendResult, error) {
	adapter, chatID, err := p.deliveryTarget(ctx, to)
	if err != nil {
		return SendResult{}, err
	}
	if !p.limiter.take() {
		return SendResult{}, &CodedError{Msg: fmt.Sprintf("Too many messages through the shared %s account; try again in a minute.", p.platform), Code: "SHARED_RATE_LIMITED"}
	}
	return adapter.SendMessage(ctx, chatID, content, opts)
}

func (p *SharedRoutePlatform) ConversationChatIDs(ctx context.Context, chatID string) ([]string, error) {
	if a, ok := p.running().(ChatAliaser); ok {
		ids, err := a.ConversationChatIDs(ctx, chatID)
		if err == nil && len(ids) > 0 {
			return ids, nil
		}
	}
	return []string{chatID}, nil
}

// SendApprovalPrompt taps where the adapter can, plain text otherwise.
func (p *SharedRoutePlatform) SendApprovalPrompt(ctx context.Context, to string, prompt ApprovalPrompt) (PromptRef, error) {
	adapter, chatID, err := p.deliveryTarget(ctx, to)
	if err != nil {
		return PromptRef{}, err
	}
	if a, ok := adapter.(ApprovalPrompter); ok {
		return a.SendApprovalPrompt(ctx, chatID, prompt)
	}
	res, err := adapter.SendMessage(ctx, chatID, prompt.Text+"\n\n"+prompt.ReplyHint, SendOptions{})
	return PromptRef{PromptID: res.MessageID}, err
}

func (p *SharedRoutePlatform) DeleteApprovalPrompt(ctx context.Context, to, promptID string) error {
	adapter, chatID, err := p.deliveryTarget(ctx, to)
	if err != nil {
		return err
	}
	if a, ok := adapter.(ApprovalPrompter); ok {
		return a.DeleteApprovalPrompt(ctx, chatID, promptID)
	}
	return nil
}

func (p *SharedRoutePlatform) SendTyping(ctx context.Context, to string, typing bool) error {
	adapter, chatID, err := p.deliveryTarget(ctx, to)
	if err != nil {
		return err
	}
	if t, ok := adapter.(Typer); ok {
		return t.SendTyping(ctx, chatID, typing)
	}
	return nil
}

func (p *SharedRoutePlatform) MarkRead(ctx context.Context, to, messageID string) error {
	adapter, chatID, err := p.deliveryTarget(ctx, to)
	if err != nil {
		return err
	}
	if r, ok := adapter.(ReadMarker); ok {
		return r.MarkRead(ctx, chatID, messageID)
	}
	return nil
}

func (p *SharedRoutePlatform) SendReaction(ctx context.Context, to, messageID, emoji string) error {
	adapter, chatID, err := p.deliveryTarget(ctx, to)
	if err != nil {
		return err
	}
	r, ok := adapter.(Reactor)
	if !ok {
		return fmt.Errorf("Platform %s cannot send reactions", p.platform)
	}
	return r.SendReaction(ctx, chatID, messageID, emoji)
}

// SyncSharedRoutes gives every identity link its route and drops routes whose
// link is gone (_syncRoutes). A personal connection is never replaced.
func (m *Manager) SyncSharedRoutes(ctx context.Context, adapter SharedAdapter) error {
	if m.cfg.DB == nil {
		return errors.New("Database is unavailable.")
	}
	rows, err := m.cfg.DB.R.QueryContext(ctx, `SELECT platform, user_id, agent_id FROM messaging_identity_links`)
	if err != nil {
		return err
	}
	wanted := map[connKey]bool{}
	for rows.Next() {
		var k connKey
		if err := rows.Scan(&k.platform, &k.userID, &k.agentID); err != nil {
			rows.Close()
			return err
		}
		wanted[k] = true
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	for k, mc := range m.conns {
		if _, shared := mc.platform.(*SharedRoutePlatform); shared && !wanted[k] {
			delete(m.conns, k)
		}
	}
	for k := range wanted {
		if _, exists := m.conns[k]; exists {
			continue
		}
		m.conns[k] = &managedConn{key: k, platform: NewSharedRoute(m.cfg.DB.R, k.platform, k.userID, k.agentID, adapter)}
	}
	return nil
}
