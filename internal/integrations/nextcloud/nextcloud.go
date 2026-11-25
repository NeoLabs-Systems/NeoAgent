// Package nextcloud is the Nextcloud integration: Login Flow v2 sign-in to the
// person's own instance, then Files (WebDAV and sharing), Calendar (CalDAV)
// and Contacts (CardDAV) tools.
package nextcloud

import (
	"context"
	"crypto/rand"
	_ "embed"
	"encoding/hex"
	"fmt"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/dav"
)

//go:embed provider.json
var specJSON []byte

const key = "nextcloud"

var appIDs = []string{"files", "calendar", "contacts"}

type session struct {
	id           string
	scope        integrations.Scope
	appKey       string
	baseURL      string
	status       string
	loginURL     string
	poll         poll
	connectionID *int64
	accountEmail string
	err          string
	created      time.Time
	cancel       context.CancelFunc
}

// Provider is the Nextcloud integration.
type Provider struct {
	*integrations.AccountProvider
	svc *integrations.Services
	// pollInterval is how often a pending login is checked (tests shorten it).
	pollInterval time.Duration

	mu       sync.Mutex
	sessions map[string]*session
}

// New builds the provider.
func New(svc *integrations.Services) *Provider {
	p := &Provider{svc: svc, pollInterval: loginPoll, sessions: map[string]*session{}}
	p.AccountProvider = integrations.NewAccountProvider(svc, integrations.LoadSpec(specJSON), integrations.AccountHooks{
		Env:     p.env,
		Execute: p.execute,
		Test: func(ctx context.Context, tc *integrations.ToolContext) error {
			_, err := p.fetchUser(ctx, tc.Credentials)
			return err
		},
		Disconnect: func(ctx context.Context, tc *integrations.ToolContext) error {
			p.revokeUnique(ctx, []map[string]any{tc.Credentials})
			return p.svc.DeleteSiblingConnections(ctx, tc.Connection)
		},
		Summarize: modelSummary,
	})
	return p
}

func modelSummary(s integrations.Snapshot) string {
	if !s.Env.Configured {
		return "Nextcloud: setup is not complete yet. Tell the user to add their Nextcloud URL in Official Integrations."
	}
	if !s.Connection.Connected {
		return "Nextcloud: setup is ready, but no Nextcloud account is connected yet. Tell the user to open Official Integrations and sign in."
	}
	return strings.Join([]string{
		"Nextcloud: connected. Use Nextcloud tools for the user's files, shares, calendars, and contacts on their instance.",
		"Prefer nextcloud_list_files and nextcloud_search_files for documents,",
		"nextcloud_list_events for schedule questions, and nextcloud_list_contacts for people.",
		"Use nextcloud_ocs_request only for other Nextcloud apps under /ocs/v2.php/.",
		"Talk chat stays in messaging, not these tools.",
	}, " ")
}

func (p *Provider) storedBaseURL(ctx context.Context, scope integrations.Scope) string {
	if scope.UserID <= 0 {
		return ""
	}
	return text(p.svc.ProviderConfig(ctx, scope, key)["baseUrl"])
}

func (p *Provider) env(scope integrations.Scope) integrations.Env {
	if p.storedBaseURL(context.Background(), scope) != "" {
		return integrations.Env{Configured: true, Missing: []string{}, Summary: "Nextcloud is ready for account connections.", SetupMode: "user"}
	}
	return integrations.Env{Configured: false, Missing: []string{"baseUrl"}, Summary: "Add your Nextcloud instance URL to enable Files, Calendar, and Contacts tools.", SetupMode: "user"}
}

func (p *Provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	if out, ok, err := p.files(ctx, name, args, tc.Credentials); ok {
		return out, err
	}
	for _, kind := range []struct {
		collection string
		run        func(context.Context, string, string, map[string]any, dav.Store) (any, bool, error)
	}{{"calendars", dav.Calendar}, {"addressbooks", dav.Contacts}} {
		store, err := p.davStore(tc.Credentials, kind.collection)
		if err != nil {
			return nil, err
		}
		if out, ok, err := kind.run(ctx, key, name, args, store); ok {
			return out, err
		}
	}
	return nil, fmt.Errorf("Unsupported Nextcloud tool: %s", name)
}

// revokeUnique revokes each distinct app password once.
func (p *Provider) revokeUnique(ctx context.Context, creds []map[string]any) {
	seen := map[string]bool{}
	for _, c := range creds {
		a := account{baseURL: integrations.Str(c["baseUrl"]), username: text(c["username"]), appPassword: text(c["appPassword"])}
		k := a.username + ":" + a.appPassword
		if a.appPassword == "" || seen[k] {
			continue
		}
		seen[k] = true
		p.revokeAppPassword(ctx, a)
	}
}

func (p *Provider) allCredentials(ctx context.Context, scope integrations.Scope) ([]map[string]any, error) {
	rows, err := p.svc.ListConnections(ctx, scope.UserID, key, scope.AgentID)
	if err != nil {
		return nil, err
	}
	out := make([]map[string]any, 0, len(rows))
	for _, r := range rows {
		out = append(out, p.svc.Credentials(r))
	}
	return out, nil
}

// ---- setup ---------------------------------------------------------------------

func (p *Provider) connectedAccounts(ctx context.Context, scope integrations.Scope) int {
	var n int
	_ = p.svc.DB.R.QueryRowContext(ctx, `SELECT COUNT(DISTINCT account_email) FROM integration_connections
		WHERE user_id=? AND agent_id=? AND provider_key=? AND status='connected'`, scope.UserID, scope.AgentID, key).Scan(&n)
	return n
}

// SetupConfig is what the setup dialog shows.
func (p *Provider) SetupConfig(ctx context.Context, scope integrations.Scope) (any, error) {
	base := p.storedBaseURL(ctx, scope)
	n := p.connectedAccounts(ctx, scope)
	return dyn.Ordered{{Key: "baseUrl", Value: base}, {Key: "configured", Value: base != ""},
		{Key: "accountCount", Value: n}, {Key: "hasConnectedAccount", Value: n > 0}}, nil
}

// SaveSetup checks and stores the instance URL; a new URL disconnects the
// accounts of the old one.
func (p *Provider) SaveSetup(ctx context.Context, scope integrations.Scope, config map[string]any) (any, error) {
	existing := p.storedBaseURL(ctx, scope)
	raw := text(config["baseUrl"])
	if raw == "" {
		raw = existing
	}
	base, err := normalizeBaseURL(raw)
	if err != nil {
		return nil, err
	}
	if err := p.fetchStatus(ctx, base); err != nil {
		return nil, err
	}
	if err := p.svc.SetProviderConfig(ctx, scope, key, map[string]any{"baseUrl": base}); err != nil {
		return nil, err
	}
	if existing != "" && existing != base {
		creds, err := p.allCredentials(ctx, scope)
		if err != nil {
			return nil, err
		}
		p.revokeUnique(ctx, creds)
		if err := p.svc.DeleteProviderConnections(ctx, scope, key); err != nil {
			return nil, err
		}
	}
	return p.SetupConfig(ctx, scope)
}

// ClearSetup revokes every app password and forgets the instance.
func (p *Provider) ClearSetup(ctx context.Context, scope integrations.Scope) error {
	creds, err := p.allCredentials(ctx, scope)
	if err != nil {
		return err
	}
	p.revokeUnique(ctx, creds)
	if err := p.svc.DeleteProviderConfig(ctx, scope, key); err != nil {
		return err
	}
	return p.svc.DeleteProviderConnections(ctx, scope, key)
}

// ---- Login Flow v2 sessions ------------------------------------------------

const sessionTTL = loginTimeout + time.Minute

// BeginConnection opens the instance's login page and waits for approval in
// the background.
func (p *Provider) BeginConnection(ctx context.Context, scope integrations.Scope, appKey string) (integrations.ConnectionStart, error) {
	if _, ok := p.App(appKey); !ok {
		missing := appKey
		if strings.TrimSpace(missing) == "" {
			missing = "missing app key"
		}
		return integrations.ConnectionStart{}, fmt.Errorf("Unknown Nextcloud app: %s", missing)
	}
	base, err := normalizeBaseURL(p.storedBaseURL(ctx, scope))
	if err != nil {
		return integrations.ConnectionStart{}, err
	}
	begun, err := p.startLoginFlow(ctx, base)
	if err != nil {
		return integrations.ConnectionStart{}, err
	}
	raw := make([]byte, 18)
	if _, err := rand.Read(raw); err != nil {
		return integrations.ConnectionStart{}, err
	}
	// The login outlives the request that started it.
	loginCtx, cancel := context.WithTimeout(context.Background(), loginTimeout+30*time.Second)
	s := &session{id: hex.EncodeToString(raw), scope: scope, appKey: appKey, baseURL: base, status: "connecting",
		loginURL: begun.loginURL, poll: begun.poll, created: p.svc.Now(), cancel: cancel}
	p.mu.Lock()
	p.pruneLocked()
	p.sessions[s.id] = s
	p.mu.Unlock()
	go p.completeLogin(loginCtx, s)
	return integrations.ConnectionStart{Status: "interactive_connect", SessionID: s.id, URL: "/api/integrations/nextcloud/connect/" + s.id}, nil
}

func (p *Provider) pruneLocked() {
	cutoff := p.svc.Now().Add(-sessionTTL)
	for id, s := range p.sessions {
		if s.created.Before(cutoff) {
			s.cancel()
			delete(p.sessions, id)
		}
	}
}

func (p *Provider) completeLogin(ctx context.Context, s *session) {
	defer s.cancel()
	conn, email, err := p.finishLogin(ctx, s)
	p.mu.Lock()
	defer p.mu.Unlock()
	if err != nil {
		s.status, s.err = "failed", err.Error()
		if s.err == "" {
			s.err = "Nextcloud login failed."
		}
		return
	}
	s.status, s.accountEmail, s.connectionID, s.err = "connected", email, conn, ""
}

func (p *Provider) finishLogin(ctx context.Context, s *session) (*int64, string, error) {
	got, err := p.pollLoginFlow(ctx, s.poll, loginTimeout)
	if err != nil {
		return nil, "", err
	}
	creds := map[string]any{"baseUrl": s.baseURL, "username": got.loginName, "appPassword": got.appPassword}
	u, err := p.fetchUser(ctx, creds)
	if err != nil {
		return nil, "", err
	}
	if u.id == "" {
		u.id = got.loginName
	}
	host := ""
	if parsed, err := url.Parse(s.baseURL); err == nil {
		host = parsed.Host
	}
	email := u.email
	if email == "" {
		id := u.id
		if id == "" {
			id = "nextcloud"
		}
		email = id + "@" + host
	}
	meta := map[string]any{"baseUrl": s.baseURL, "username": got.loginName, "displayName": orNil(u.displayName), "email": orNil(u.email)}
	var files *int64
	for _, app := range appIDs {
		conn, err := p.svc.UpsertAccountApp(ctx, integrations.AccountApp{
			Scope: s.scope, ProviderKey: key, AppKey: app, AccountEmail: email,
			Scopes: []string{"nextcloud:dav", "nextcloud:ocs"}, Credentials: creds, Metadata: meta,
		})
		if err != nil {
			return nil, "", err
		}
		if app == "files" && conn != nil {
			id := conn.ID
			files = &id
		}
	}
	return files, email, nil
}

func orNil(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// ConnectionSession reports a login of the signed-in account.
func (p *Provider) ConnectionSession(scope integrations.Scope, id string) (*integrations.ConnectionSession, bool) {
	p.mu.Lock()
	defer p.mu.Unlock()
	s, ok := p.sessions[id]
	if !ok || s.scope != scope {
		return nil, false
	}
	return &integrations.ConnectionSession{ID: s.id, Provider: key, AppID: s.appKey, Status: s.status,
		LoginURL: s.loginURL, HasLoginURL: true, ConnectionID: s.connectionID, AccountEmail: s.accountEmail, Error: s.err}, true
}

// Shutdown stops pending logins.
func (p *Provider) Shutdown(context.Context) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	for id, s := range p.sessions {
		s.cancel()
		delete(p.sessions, id)
	}
	return nil
}
