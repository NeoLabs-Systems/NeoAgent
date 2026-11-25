// Package whatsapppersonal implements the personal WhatsApp integration: the
// person links their own WhatsApp account by scanning a QR code, and the agent
// gets read tools over what that link synchronised and a send tool. It is kept
// apart from the messaging-platform WhatsApp bridge. Calls are not supported.
package whatsapppersonal

import (
	"context"
	"crypto/rand"
	_ "embed"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"go.mau.fi/whatsmeow/types"
	"go.mau.fi/whatsmeow/types/events"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
)

//go:embed provider.json
var specJSON []byte

const (
	providerKey = "whatsapp_personal"
	appID       = "personal"
	label       = "WhatsApp"
	connectWait = 60 * time.Second
	sendWait    = 60 * time.Second
)

// MessageEvent is an incoming message on a linked account, for the tasks that
// trigger on it.
type MessageEvent struct {
	UserID       int64
	AgentID      string
	ConnectionID int64
	ChatID       string
	Sender       string
	SenderTag    string
	MessageID    any
	Text         string
	Timestamp    string
	IsGroup      bool
}

// Options are the provider's collaborators.
type Options struct {
	// AgentDataDir holds the device stores (integrations/whatsapp-personal/...).
	AgentDataDir string
	// Open opens a device store; nil is OpenStore.
	Open Opener
	// OnMessage receives incoming messages; optional.
	OnMessage func(MessageEvent)
	Log       *slog.Logger
}

// Provider is the personal WhatsApp integration.
type Provider struct {
	*integrations.AccountProvider
	svc  *integrations.Services
	spec integrations.Spec
	o    Options

	mu       sync.Mutex
	sessions map[string]*session
	clients  map[int64]*client
	stopping bool
}

// link is a running device with its cache.
type link struct {
	dev   Device
	cache *cache
}

type session struct {
	link
	id, appKey, authDir string
	userID              int64
	agentID             string
	status, qr, err     string
	email               string
	connectionID        *int64
	cancel              context.CancelFunc
}

type client struct {
	link
	connectionID int64
	userID       int64
	agentID      string
	authDir      string
	email        string
	status       string
	ready        chan struct{} // closed when a connect attempt ends
}

// New builds the provider.
func New(svc *integrations.Services, o Options) *Provider {
	if o.Open == nil {
		o.Open = OpenStore
	}
	if o.Log == nil {
		o.Log = slog.Default()
	}
	spec := integrations.LoadSpec(specJSON)
	p := &Provider{svc: svc, spec: spec, o: o, sessions: map[string]*session{}, clients: map[int64]*client{}}
	p.AccountProvider = integrations.NewAccountProvider(svc, spec, integrations.AccountHooks{
		Env: func(integrations.Scope) integrations.Env {
			return integrations.Env{Configured: true, Missing: []string{}, Summary: "WhatsApp personal linking is ready for account connections."}
		},
		Execute:    p.execute,
		Disconnect: p.disconnect,
		Summarize:  p.summarize,
	})
	return p
}

// Snapshot lists the linked accounts, newest first.
func (p *Provider) Snapshot(rows []integrations.Connection, scope integrations.Scope) integrations.Snapshot {
	env := p.EnvStatus(scope)
	sorted := append([]integrations.Connection(nil), rows...)
	sort.SliceStable(sorted, func(i, j int) bool { return sorted[i].UpdatedAt > sorted[j].UpdatedAt })
	accounts := []integrations.AccountSnapshot{}
	var connected []integrations.AccountSnapshot
	for _, r := range sorted {
		id := r.ID
		status := r.Status
		if status == "" {
			status = "not_connected"
		}
		acc := integrations.AccountSnapshot{ID: &id, Status: status, Connected: r.Status == "connected",
			AccountEmail: nullable(r.AccountEmail), LastConnectedAt: nullable(r.LastConnectedAt), AccessMode: integrations.AccessMode(&r)}
		accounts = append(accounts, acc)
		if acc.Connected {
			connected = append(connected, acc)
		}
	}
	var latest *string
	for _, a := range connected {
		if a.LastConnectedAt != nil && (latest == nil || *a.LastConnectedAt > *latest) {
			latest = a.LastConnectedAt
		}
	}
	status := "not_connected"
	if len(connected) > 0 {
		status = "connected"
	}
	var email *string
	if len(connected) == 1 {
		email = connected[0].AccountEmail
	}
	tools := 0
	if len(connected) > 0 {
		tools = len(p.spec.Tools)
	}
	app := p.spec.Apps[0]
	appCount := 0
	if len(connected) > 0 {
		appCount = 1
	}
	return integrations.Snapshot{
		ID: p.spec.Key, Label: p.spec.Label, Description: p.spec.Description, Icon: p.spec.Icon, Env: env,
		Apps: []integrations.AppSnapshot{{ID: app.ID, Label: app.Label, Description: app.Description, Accounts: accounts,
			Connection:         integrations.AppConnection{Status: status, Connected: len(connected) > 0, AccountCount: len(connected), AccountEmail: email, LastConnectedAt: latest},
			AvailableToolCount: tools}},
		Connection:         integrations.ProviderConnection{Status: status, Connected: len(connected) > 0, AccountCount: len(connected), AppCount: appCount, AccountEmail: email, LastConnectedAt: latest},
		AvailableToolCount: tools,
		Extra:              map[string]any{"connectPrompt": p.spec.ConnectPrompt},
	}
}

func nullable(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func (p *Provider) summarize(s integrations.Snapshot) string {
	if !s.Env.Configured {
		return label + ": available but not configured on the server yet."
	}
	if !s.Connection.Connected {
		return label + ": personal integration is available, but no account is connected. The separate messaging-platform WhatsApp bridge does not count as this official integration."
	}
	var parts []string
	for _, app := range s.Apps {
		for _, a := range app.Accounts {
			if !a.Connected {
				continue
			}
			name := fmt.Sprintf("connection %d", *a.ID)
			if a.AccountEmail != nil {
				name = *a.AccountEmail
			}
			mode := "read/write"
			if a.AccessMode == integrations.AccessReadOnly {
				mode = "read-only"
			}
			parts = append(parts, name+" ("+mode+")")
		}
	}
	return fmt.Sprintf("%s: personal official integration connected for %s. Keep it separate from messaging-platform WhatsApp usage.", label, strings.Join(parts, ", "))
}

func randomHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func (p *Provider) authDir(userID int64, agentID, sessionID string) string {
	if agentID == "" {
		agentID = "main"
	}
	return filepath.Join(p.o.AgentDataDir, "integrations", "whatsapp-personal", strconv.FormatInt(userID, 10), agentID, sessionID)
}

// ---- linking -------------------------------------------------------------------

// BeginConnection starts linking a new account with a QR code.
func (p *Provider) BeginConnection(_ context.Context, scope integrations.Scope, appKey string) (integrations.ConnectionStart, error) {
	p.mu.Lock()
	stopping := p.stopping
	p.mu.Unlock()
	if stopping {
		return integrations.ConnectionStart{}, errors.New("WhatsApp integration is shutting down.")
	}
	if _, ok := p.App(appKey); !ok {
		missing := appKey
		if missing == "" {
			missing = "missing app key"
		}
		return integrations.ConnectionStart{}, fmt.Errorf("Unknown %s app: %s", label, missing)
	}
	id := randomHex(18)
	ctx, cancel := context.WithCancel(context.Background())
	s := &session{link: link{cache: newCache()}, id: id, appKey: appKey, userID: scope.UserID, agentID: scope.AgentID,
		status: "connecting", authDir: p.authDir(scope.UserID, scope.AgentID, id), cancel: cancel}
	p.mu.Lock()
	p.sessions[id] = s
	p.mu.Unlock()
	go p.runSession(ctx, s)
	return integrations.ConnectionStart{Status: "interactive_connect", SessionID: id, URL: "/api/integrations/" + providerKey + "/connect/" + id}, nil
}

func (p *Provider) setSession(s *session, fn func()) {
	p.mu.Lock()
	defer p.mu.Unlock()
	fn()
}

// runSession pairs the device, retrying with backoff until it is linked or
// logged out.
func (p *Provider) runSession(ctx context.Context, s *session) {
	for attempt := 1; ; attempt++ {
		done, err := p.pairOnce(ctx, s)
		if done || ctx.Err() != nil {
			return
		}
		p.setSession(s, func() {
			s.status, s.qr = "connecting", ""
			if err != nil {
				s.err = err.Error()
			}
		})
		delay := time.Duration(math.Min(30000, 1000*math.Pow(2, float64(attempt-1)))) * time.Millisecond
		select {
		case <-ctx.Done():
			return
		case <-time.After(delay):
		}
	}
}

// pairOnce runs one pairing attempt. done is true when the session reached a
// final state (linked or logged out); the device then stays with the client.
func (p *Provider) pairOnce(ctx context.Context, s *session) (bool, error) {
	dev, err := p.o.Open(ctx, s.authDir)
	if err != nil {
		p.setSession(s, func() { s.status, s.err = "failed", err.Error() })
		return true, err
	}
	ended := make(chan string, 4)
	dev.AddEventHandler(func(evt any) {
		switch e := evt.(type) {
		case *events.Connected:
			// whatsmeow reconnects by itself; only the first connect links.
			if p.sessionConnection(s) != 0 {
				p.setClientStatus(s, "connected")
				return
			}
			p.linked(s, dev)
			signal(ended, "connected")
		case *events.Disconnected:
			if p.sessionConnection(s) != 0 {
				p.setClientStatus(s, "disconnected")
				p.setSession(s, func() { s.status = "disconnected" })
			}
		case *events.LoggedOut:
			p.loggedOut(s)
			signal(ended, "logged_out")
		case *events.HistorySync:
			p.historySync(&s.link, dev, e)
		case *events.Message:
			p.incoming(s.userID, s.agentID, p.sessionConnection(s), s.cache, e)
		}
	})
	if !dev.IsPaired() {
		codes, err := dev.QRChannel(ctx)
		if err != nil {
			_ = dev.Close()
			return false, err
		}
		go func() {
			for item := range codes {
				switch item.Event {
				case "code":
					p.setSession(s, func() { s.qr, s.err, s.status = item.Code, "", "awaiting_qr" })
				case "success":
				default:
					signal(ended, "retry")
					return
				}
			}
		}()
	}
	if err := dev.Connect(); err != nil {
		_ = dev.Close()
		return false, err
	}
	select {
	case <-ctx.Done():
		dev.Disconnect()
		_ = dev.Close()
		return true, nil
	case outcome := <-ended:
		if outcome == "retry" {
			dev.Disconnect()
			_ = dev.Close()
			return false, nil
		}
		return true, nil
	}
}

// signal reports an outcome without blocking a whatsmeow event handler.
func signal(ch chan string, outcome string) {
	select {
	case ch <- outcome:
	default:
	}
}

func (p *Provider) setClientStatus(s *session, status string) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if s.connectionID != nil {
		if c := p.clients[*s.connectionID]; c != nil {
			c.status = status
		}
	}
	if status == "connected" {
		s.status = status
	}
}

func (p *Provider) sessionConnection(s *session) int64 {
	p.mu.Lock()
	defer p.mu.Unlock()
	if s.connectionID == nil {
		return 0
	}
	return *s.connectionID
}

// linked stores the account once the device is connected.
func (p *Provider) linked(s *session, dev Device) {
	email := normalizeID(dev.OwnJID())
	if email == "" {
		email = dev.OwnJID()
	}
	p.setSession(s, func() { s.status, s.qr, s.err, s.email, s.dev = "connected", "", "", email, dev })
	conn, err := p.upsertAccount(context.Background(), s)
	if err != nil {
		p.o.Log.Warn("storing the linked WhatsApp account failed", "error", err)
		p.setSession(s, func() { s.status, s.err = "failed", err.Error() })
		return
	}
	id := conn.ID
	c := &client{link: link{dev: dev, cache: s.cache}, connectionID: id, userID: s.userID, agentID: s.agentID,
		authDir: s.authDir, email: email, status: "connected", ready: closedChan()}
	p.mu.Lock()
	s.connectionID = &id
	p.clients[id] = c
	p.mu.Unlock()
}

func closedChan() chan struct{} {
	ch := make(chan struct{})
	close(ch)
	return ch
}

func (p *Provider) loggedOut(s *session) {
	p.mu.Lock()
	s.status = "logged_out"
	if s.connectionID != nil {
		delete(p.clients, *s.connectionID)
	}
	p.mu.Unlock()
	_ = os.RemoveAll(s.authDir)
}

// upsertAccount stores the linked account; a previous link of the same
// account loses its device store.
func (p *Provider) upsertAccount(ctx context.Context, s *session) (*integrations.Connection, error) {
	scope := integrations.Scope{UserID: s.userID, AgentID: s.agentID}
	existing, err := p.svc.FindAppConnection(ctx, s.userID, s.agentID, providerKey, s.appKey, s.email)
	if err != nil {
		return nil, err
	}
	conn, err := p.svc.UpsertAccountApp(ctx, integrations.AccountApp{
		Scope: scope, ProviderKey: providerKey, AppKey: s.appKey, AccountEmail: s.email, Scopes: []string{"personal_whatsapp"},
		Credentials: map[string]any{"authDir": s.authDir, "linkedAt": time.Now().UTC().Format("2006-01-02T15:04:05.000Z")},
		Metadata:    map[string]any{},
	})
	if err != nil {
		return nil, err
	}
	if existing != nil {
		if previous := strings.TrimSpace(integrations.Str(p.svc.Credentials(*existing)["authDir"])); previous != "" && previous != s.authDir {
			_ = os.RemoveAll(previous)
		}
	}
	return conn, nil
}

// ConnectionSession reports a linking session.
func (p *Provider) ConnectionSession(scope integrations.Scope, id string) (*integrations.ConnectionSession, bool) {
	p.mu.Lock()
	defer p.mu.Unlock()
	s := p.sessions[strings.TrimSpace(id)]
	if s == nil || s.userID != scope.UserID || s.agentID != scope.AgentID {
		return nil, false
	}
	return &integrations.ConnectionSession{ID: s.id, Provider: providerKey, AppID: s.appKey, Status: s.status,
		ConnectionID: s.connectionID, AccountEmail: s.email, Error: s.err, QR: s.qr}, true
}

// ---- tools ---------------------------------------------------------------------

func (p *Provider) historySync(l *link, dev Device, e *events.HistorySync) {
	for _, conv := range e.Data.GetConversations() {
		l.cache.upsertConversation(conv)
		chat, err := types.ParseJID(conv.GetID())
		if err != nil {
			continue
		}
		for _, hm := range conv.GetMessages() {
			evt, err := dev.ParseWebMessage(chat, hm.GetMessage())
			if err == nil && evt != nil {
				l.cache.record(simplify(evt))
			}
		}
	}
}

func (p *Provider) incoming(userID int64, agentID string, connectionID int64, c *cache, e *events.Message) {
	m := simplify(e)
	if !c.record(m) || m.FromMe || connectionID == 0 || p.o.OnMessage == nil {
		return
	}
	p.o.OnMessage(MessageEvent{UserID: userID, AgentID: agentID, ConnectionID: connectionID, ChatID: m.ChatID, Sender: m.Sender,
		SenderTag: m.SenderTag, MessageID: m.ID, Text: m.Text, Timestamp: m.Timestamp, IsGroup: strings.HasSuffix(m.ChatID, "@g.us")})
}

// ensureClient returns the connected client of a connection, linking its
// stored device again after a restart.
func (p *Provider) ensureClient(ctx context.Context, conn integrations.Connection) (*client, error) {
	p.mu.Lock()
	if p.stopping {
		p.mu.Unlock()
		return nil, errors.New("WhatsApp integration is shutting down.")
	}
	c := p.clients[conn.ID]
	if c != nil && c.status == "connected" && c.dev != nil {
		p.mu.Unlock()
		return c, nil
	}
	if c == nil || c.status != "connecting" {
		authDir := strings.TrimSpace(integrations.Str(p.svc.Credentials(conn)["authDir"]))
		if authDir == "" {
			p.mu.Unlock()
			return nil, errors.New("WhatsApp account credentials are missing.")
		}
		c = &client{link: link{cache: newCache()}, connectionID: conn.ID, userID: conn.UserID, agentID: conn.AgentID,
			authDir: authDir, email: conn.AccountEmail, status: "connecting", ready: make(chan struct{})}
		p.clients[conn.ID] = c
		go p.connectClient(c)
	}
	ready := c.ready
	p.mu.Unlock()
	select {
	case <-ctx.Done():
		return nil, context.Cause(ctx)
	case <-ready:
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	if c.status != "connected" || c.dev == nil {
		return nil, errors.New("WhatsApp personal account is not connected.")
	}
	return c, nil
}

// connectClient opens and connects a stored device, waiting up to a minute.
func (p *Provider) connectClient(c *client) {
	finish := func(status string) {
		p.mu.Lock()
		c.status = status
		p.mu.Unlock()
		close(c.ready)
	}
	ctx, cancel := context.WithTimeout(context.Background(), connectWait)
	defer cancel()
	dev, err := p.o.Open(ctx, c.authDir)
	if err != nil {
		p.o.Log.Warn("opening the WhatsApp device failed", "connection", c.connectionID, "error", err)
		finish("disconnected")
		return
	}
	opened := make(chan bool, 2)
	dev.AddEventHandler(func(evt any) {
		switch e := evt.(type) {
		case *events.Connected:
			own := normalizeID(dev.OwnJID())
			p.mu.Lock()
			c.status = "connected"
			if own != "" {
				c.email = own
			}
			p.mu.Unlock()
			select {
			case opened <- true:
			default:
			}
		case *events.LoggedOut:
			p.mu.Lock()
			c.status = "disconnected"
			p.mu.Unlock()
			select {
			case opened <- false:
			default:
			}
		case *events.Disconnected:
			p.mu.Lock()
			if c.status == "connected" {
				c.status = "disconnected"
			}
			p.mu.Unlock()
		case *events.HistorySync:
			p.historySync(&c.link, dev, e)
		case *events.Message:
			p.incoming(c.userID, c.agentID, c.connectionID, c.cache, e)
		}
	})
	p.mu.Lock()
	c.dev = dev
	p.mu.Unlock()
	if !dev.IsPaired() {
		_ = dev.Close()
		finish("disconnected")
		return
	}
	if err := dev.Connect(); err != nil {
		_ = dev.Close()
		finish("disconnected")
		return
	}
	select {
	case ok := <-opened:
		if ok {
			finish("connected")
			return
		}
	case <-ctx.Done():
	}
	dev.Disconnect()
	finish("disconnected")
}

// limitArg is Math.max(1, Math.min(Number(v) || def, 100)).
func limitArg(v any, def float64) int {
	n, ok := integrations.JSNumber(v)
	if !ok || n == 0 {
		n = def
	}
	return int(math.Max(1, math.Min(n, 100)))
}

func requireText(v any, name string) (string, error) {
	t := ""
	if integrations.Truthy(v) {
		t = strings.TrimSpace(integrations.Str(v))
	}
	if t == "" {
		return "", fmt.Errorf("%s is required.", name)
	}
	return t, nil
}

type profile struct {
	Account            any    `json:"account"`
	Connected          bool   `json:"connected"`
	ChatCount          int    `json:"chatCount"`
	CachedMessageChats int    `json:"cachedMessageChats"`
	SyncNote           string `json:"syncNote"`
}

type chatList struct {
	Account   any    `json:"account"`
	Connected bool   `json:"connected"`
	Chats     []Chat `json:"chats"`
	Count     int    `json:"count"`
	SyncNote  string `json:"syncNote"`
}

type messageList struct {
	ChatID   string    `json:"chatId"`
	Messages []Message `json:"messages"`
	Count    int       `json:"count"`
	SyncNote string    `json:"syncNote"`
}

func (p *Provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	c, err := p.ensureClient(ctx, tc.Connection)
	if err != nil {
		return nil, err
	}
	p.mu.Lock()
	account := any(nil)
	if c.email != "" {
		account = c.email
	} else if tc.Connection.AccountEmail != "" {
		account = tc.Connection.AccountEmail
	}
	connected := c.status == "connected"
	dev := c.dev
	p.mu.Unlock()
	switch name {
	case "whatsapp_personal_get_profile":
		chats, messageChats := c.cache.counts()
		return profile{account, connected, chats, messageChats,
			"This account is linked and connected. Read tools expose only chats and messages currently available in this session cache."}, nil
	case "whatsapp_personal_list_chats":
		chats := c.cache.recentChats(limitArg(args["limit"], 25))
		note := "Chats shown here come from the current personal WhatsApp cache."
		if len(chats) == 0 {
			note = "The personal WhatsApp account is connected, but no chats are cached yet. The cache populates as history/events are synchronized."
		}
		return chatList{account, connected, chats, len(chats), note}, nil
	case "whatsapp_personal_get_messages":
		raw, err := requireText(args["chat_id"], "chat_id")
		if err != nil {
			return nil, err
		}
		jid := chatJID(raw)
		messages := c.cache.latest(jid, limitArg(args["limit"], 20))
		return messageList{jid, messages, len(messages), "Only messages synchronized through this personal integration session are readable here."}, nil
	case "whatsapp_personal_send_message":
		raw, err := requireText(args["to"], "to")
		if err != nil {
			return nil, err
		}
		jid := chatJID(raw)
		text, err := requireText(args["text"], "text")
		if err != nil {
			return nil, err
		}
		to, err := types.ParseJID(jid)
		if err != nil {
			return nil, err
		}
		sendCtx, cancel := context.WithTimeout(ctx, sendWait)
		defer cancel()
		if err := dev.SendText(sendCtx, to, text); err != nil {
			if sendCtx.Err() == context.DeadlineExceeded && ctx.Err() == nil {
				return nil, errors.New("WhatsApp send timed out after 60000ms.")
			}
			return nil, err
		}
		return struct {
			Sent bool   `json:"sent"`
			To   string `json:"to"`
		}{true, jid}, nil
	}
	return nil, nil
}

// disconnect unlinks the device and removes its store.
func (p *Provider) disconnect(ctx context.Context, tc *integrations.ToolContext) error {
	authDir := strings.TrimSpace(integrations.Str(tc.Credentials["authDir"]))
	p.mu.Lock()
	c := p.clients[tc.Connection.ID]
	delete(p.clients, tc.Connection.ID)
	p.mu.Unlock()
	if c != nil && c.dev != nil {
		if err := c.dev.Logout(ctx); err != nil {
			p.o.Log.Warn("WhatsApp logout failed during disconnect", "connection", tc.Connection.ID, "error", err)
		}
		c.dev.Disconnect()
		_ = c.dev.Close()
	}
	if authDir != "" {
		return os.RemoveAll(authDir)
	}
	return nil
}

// Shutdown closes every device.
func (p *Provider) Shutdown(context.Context) error {
	p.mu.Lock()
	p.stopping = true
	sessions, clients := p.sessions, p.clients
	p.sessions, p.clients = map[string]*session{}, map[int64]*client{}
	p.mu.Unlock()
	closed := map[Device]bool{}
	for _, s := range sessions {
		s.cancel()
	}
	for _, c := range clients {
		if c.dev != nil && !closed[c.dev] {
			closed[c.dev] = true
			c.dev.Disconnect()
			_ = c.dev.Close()
		}
	}
	return nil
}
