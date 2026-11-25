// Package tailscale implements the Tailscale integration: a dedicated
// Tailscale node inside the user's isolated cloud computer, signed in
// interactively, that reaches only the peer services the person granted. The
// computer only makes outgoing connections.
package tailscale

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"net/url"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
)

//go:embed provider.json
var specJSON []byte

const (
	providerKey = "tailscale"
	appID       = "tailnet"
	sessionTTL  = 5 * time.Minute
)

// Locker serialises work on a connection with its tool calls
// (Manager.LockConnection).
type Locker func(ctx context.Context, conn integrations.Connection) (func(), error)

// Provider is the Tailscale integration. Its computer and lock come from
// components built after the integrations; until SetComputer, Tailscale is
// reported as not configured.
type Provider struct {
	*integrations.AccountProvider
	svc      *integrations.Services
	rt       *runtime
	computer atomic.Pointer[Computer]
	locker   atomic.Pointer[Locker]

	mu       sync.Mutex
	sessions map[string]*session
	stopping bool
}

// New builds the provider.
func New(svc *integrations.Services) *Provider {
	p := &Provider{svc: svc, sessions: map[string]*session{}}
	p.rt = &runtime{svc: svc, computer: p.currentComputer}
	p.AccountProvider = integrations.NewAccountProvider(svc, integrations.LoadSpec(specJSON), integrations.AccountHooks{
		Env:        p.env,
		Execute:    p.execute,
		Disconnect: p.logout,
	})
	return p
}

// SetComputer connects the provider to the cloud computer runtime.
func (p *Provider) SetComputer(c Computer) { p.computer.Store(&c) }

// SetLocker connects the provider to the Manager's connection lock.
func (p *Provider) SetLocker(l Locker) { p.locker.Store(&l) }

func (p *Provider) currentComputer() Computer {
	if c := p.computer.Load(); c != nil {
		return *c
	}
	return nil
}

// Info marks tool calls as exclusive per connection: a node's state blob
// changes with every operation.
func (p *Provider) Info() integrations.Info {
	info := p.AccountProvider.Info()
	info.Exclusive = true
	return info
}

func (p *Provider) env(integrations.Scope) integrations.Env {
	if c := p.currentComputer(); c != nil && c.Isolated() {
		return integrations.Env{Configured: true, Missing: []string{}, SetupMode: "server", Summary: "Sign in to your Tailscale account to connect."}
	}
	return integrations.Env{Missing: []string{"isolated_computer"}, SetupMode: "server", Summary: "Tailscale requires an isolated per-user QEMU or Docker computer runtime."}
}

func (p *Provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	action := map[string]string{"tailscale_list_peers": "list", "tailscale_ping": "ping", "tailscale_request": "request"}[name]
	if action == "" {
		return nil, nil
	}
	return p.rt.execute(ctx, tc.Connection, action, args)
}

// logout removes the node from the tailnet.
func (p *Provider) logout(ctx context.Context, tc *integrations.ToolContext) error {
	payload := map[string]any{"action": "logout"}
	for k, v := range tc.Credentials {
		payload[k] = v
	}
	_, err := p.rt.call(ctx, tc.Connection.UserID, connectionScope(tc.Connection), payload, "")
	return err
}

// BeforeDisconnect stops the connection's running operations.
func (p *Provider) BeforeDisconnect(_ context.Context, conn integrations.Connection) error {
	p.rt.stop(connectionScope(conn))
	return nil
}

// ---- service access ------------------------------------------------------------

func (p *Provider) ownedConnection(ctx context.Context, scope integrations.Scope, connectionID string) (*integrations.Connection, error) {
	id, err := strconv.ParseFloat(connectionID, 64)
	var conn *integrations.Connection
	if err == nil && id == float64(int64(id)) {
		conn, err = p.svc.ConnectionByID(ctx, scope.UserID, int64(id), scope.AgentID)
		if err != nil {
			return nil, err
		}
	}
	if conn == nil || conn.ProviderKey != providerKey || conn.Status != "connected" {
		return nil, errors.New("That Tailscale connection is not available to this agent.")
	}
	return conn, nil
}

// ServiceAccess lists the peers the connection sees, with its grants.
func (p *Provider) ServiceAccess(ctx context.Context, scope integrations.Scope, connectionID string) (any, error) {
	conn, err := p.ownedConnection(ctx, scope, connectionID)
	if err != nil {
		return nil, err
	}
	if l := p.locker.Load(); l != nil {
		release, err := (*l)(ctx, *conn)
		if err != nil {
			return nil, err
		}
		defer release()
	}
	return p.rt.execute(ctx, *conn, "list", map[string]any{})
}

// SetServiceAccess replaces the grants and stops running operations, which
// were authorised by the old ones.
func (p *Provider) SetServiceAccess(ctx context.Context, scope integrations.Scope, connectionID string, services any) (any, error) {
	conn, err := p.ownedConnection(ctx, scope, connectionID)
	if err != nil {
		return nil, err
	}
	normalized, err := NormalizeServices(services)
	if err != nil {
		return nil, err
	}
	var meta map[string]any
	if json.Unmarshal([]byte(conn.MetadataJSON), &meta) != nil || meta == nil {
		meta = map[string]any{}
	}
	meta["services"] = normalized
	raw, _ := json.Marshal(meta)
	if _, err := p.svc.DB.W.ExecContext(ctx, `UPDATE integration_connections SET metadata_json = ?, updated_at = datetime('now')
		WHERE id = ? AND user_id = ? AND agent_id = ? AND status = 'connected'`, string(raw), conn.ID, conn.UserID, conn.AgentID); err != nil {
		return nil, err
	}
	p.rt.stop(connectionScope(*conn))
	return map[string]any{"services": normalized}, nil
}

// ---- interactive sign-in -------------------------------------------------------

type session struct {
	id           string
	userID       int64
	agentID      string
	status       string
	loginURL     string
	connectionID *int64
	accountEmail string
	err          string
	timer        *time.Timer
	poll         sync.Mutex
}

// BeginConnection starts a sign-in; an older pending sign-in of the agent is
// cancelled.
func (p *Provider) BeginConnection(ctx context.Context, scope integrations.Scope, appKey string) (integrations.ConnectionStart, error) {
	p.mu.Lock()
	if p.stopping {
		p.mu.Unlock()
		return integrations.ConnectionStart{}, errors.New("Tailscale integration is stopping.")
	}
	p.mu.Unlock()
	if appKey != appID {
		return integrations.ConnectionStart{}, errors.New("Unknown Tailscale app.")
	}
	s := &session{id: operationID(), userID: scope.UserID, agentID: scope.AgentID, status: "connecting"}
	s.timer = time.AfterFunc(sessionTTL, func() { p.expire(s) })
	p.mu.Lock()
	p.sessions[s.id] = s
	var previous []*session
	for _, other := range p.sessions {
		if other != s && other.userID == s.userID && other.agentID == s.agentID && other.status == "connecting" {
			other.status = "failed"
			previous = append(previous, other)
		}
	}
	p.mu.Unlock()
	fail := func(err error) (integrations.ConnectionStart, error) {
		p.mu.Lock()
		s.status, s.err = "failed", "Could not start Tailscale sign-in. Please try again."
		p.mu.Unlock()
		_ = p.rt.cancelLogin(s.userID, s.id)
		return integrations.ConnectionStart{}, err
	}
	for _, other := range previous {
		if err := p.rt.cancelLogin(other.userID, other.id); err != nil {
			return fail(err)
		}
	}
	if p.status(s) != "connecting" {
		return fail(errors.New("Tailscale sign-in was replaced by a new request."))
	}
	started, err := p.rt.call(ctx, s.userID, strconv.FormatInt(s.userID, 10)+":"+s.agentID+":login", map[string]any{"action": "login"}, s.id)
	if err != nil {
		return fail(err)
	}
	if p.status(s) != "connecting" {
		return fail(errors.New("Tailscale sign-in was canceled."))
	}
	login, err := url.Parse(integrations.Str(started["loginUrl"]))
	if err != nil || login.Scheme != "https" || login.Host != "login.tailscale.com" || login.User != nil {
		return fail(errors.New("Tailscale returned an invalid sign-in URL."))
	}
	p.mu.Lock()
	s.loginURL = login.String()
	p.mu.Unlock()
	return integrations.ConnectionStart{Status: "interactive_connect", SessionID: s.id, LoginURL: s.loginURL, URL: "/api/integrations/tailscale/connect/" + s.id}, nil
}

func (p *Provider) status(s *session) string {
	p.mu.Lock()
	defer p.mu.Unlock()
	return s.status
}

func (p *Provider) expire(s *session) {
	p.mu.Lock()
	delete(p.sessions, s.id)
	pending := s.status == "connecting"
	p.mu.Unlock()
	if pending {
		_ = p.rt.cancelLogin(s.userID, s.id)
	}
}

func (p *Provider) find(scope integrations.Scope, id string) *session {
	p.mu.Lock()
	defer p.mu.Unlock()
	s := p.sessions[id]
	if s == nil || s.userID != scope.UserID || s.agentID != scope.AgentID {
		return nil
	}
	return s
}

// ConnectionSession reports a sign-in, checking the node's login once while
// it is pending.
func (p *Provider) ConnectionSession(scope integrations.Scope, id string) (*integrations.ConnectionSession, bool) {
	s := p.find(scope, id)
	if s == nil {
		return nil, false
	}
	if p.status(s) == "connecting" {
		s.poll.Lock()
		if p.status(s) == "connecting" {
			ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
			p.finish(ctx, s)
			cancel()
		}
		s.poll.Unlock()
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	return &integrations.ConnectionSession{
		ID: s.id, Provider: providerKey, AppID: appID, Status: s.status, LoginURL: s.loginURL, HasLoginURL: true,
		ConnectionID: s.connectionID, AccountEmail: s.accountEmail, Error: s.err,
	}, true
}

func (p *Provider) finish(ctx context.Context, s *session) {
	result, err := p.rt.loginStatus(ctx, s.userID, s.id)
	if err != nil {
		return
	}
	p.mu.Lock()
	live := s.status == "connecting" && !p.stopping && p.sessions[s.id] == s
	p.mu.Unlock()
	if !live {
		return
	}
	switch integrations.Str(result["status"]) {
	case "connected":
		creds, err := assertNodeCredentials(result)
		if err != nil {
			return
		}
		email := "tailscale:" + integrations.Str(result["tailnet"]) + ":" + creds.NodeID
		conn, err := p.svc.UpsertAccountApp(ctx, integrations.AccountApp{
			Scope: integrations.Scope{UserID: s.userID, AgentID: s.agentID}, ProviderKey: providerKey, AppKey: appID, AccountEmail: email,
			Credentials: map[string]any{"nodeId": creds.NodeID, "state": creds.State},
			Metadata:    map[string]any{"nodeId": creds.NodeID, "tailnet": result["tailnet"], "services": []any{}, "access_mode": integrations.AccessReadOnly},
		})
		if err != nil || conn == nil {
			return
		}
		id := conn.ID
		p.mu.Lock()
		s.status, s.connectionID, s.accountEmail = "connected", &id, email
		p.mu.Unlock()
		_ = p.rt.cancelLogin(s.userID, s.id)
	case "failed":
		p.mu.Lock()
		s.status, s.err = "failed", "Tailscale sign-in expired or was canceled. Please connect again."
		p.mu.Unlock()
	}
}

// CancelConnectionSession abandons a pending sign-in.
func (p *Provider) CancelConnectionSession(_ context.Context, scope integrations.Scope, id string) error {
	s := p.find(scope, id)
	if s == nil {
		return nil
	}
	p.mu.Lock()
	s.status = "failed"
	s.timer.Stop()
	p.mu.Unlock()
	err := p.rt.cancelLogin(s.userID, s.id)
	p.mu.Lock()
	delete(p.sessions, s.id)
	p.mu.Unlock()
	return err
}

// Shutdown cancels pending sign-ins and running operations.
func (p *Provider) Shutdown(context.Context) error {
	p.mu.Lock()
	p.stopping = true
	sessions := p.sessions
	p.sessions = map[string]*session{}
	p.mu.Unlock()
	for _, s := range sessions {
		s.timer.Stop()
		if s.status == "connecting" {
			_ = p.rt.cancelLogin(s.userID, s.id)
		}
	}
	p.rt.shutdown()
	return nil
}
