package integrations

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

// AccountHooks is what a provider that connects without an OAuth redirect
// supplies beyond its spec: it stores its connections itself, from a setup
// form (an app password, an instance URL) or an interactive connect page.
type AccountHooks struct {
	// Env says whether accounts can connect yet; required.
	Env func(scope Scope) Env
	// Execute runs one tool; its result is what the agent receives.
	Execute func(ctx context.Context, name string, args map[string]any, tc *ToolContext) (any, error)
	// Test checks the connection without side effects; optional.
	Test func(ctx context.Context, tc *ToolContext) error
	// Disconnect runs before the Manager deletes the connection; optional.
	Disconnect func(ctx context.Context, tc *ToolContext) error
	// Summarize replaces the default model summary; optional.
	Summarize func(Snapshot) string
	// Decorate adjusts the snapshot (members the provider adds or leaves
	// out); optional.
	Decorate func(snap *Snapshot, scope Scope)
}

// AccountProvider is the shared provider behind Email, Nextcloud, Trello,
// Weather and the other integrations that need no OAuth app.
type AccountProvider struct {
	svc   *Services
	spec  Spec
	tools Toolset
	hooks AccountHooks
	apps  map[string]App
}

// NewAccountProvider builds a provider from its spec.
func NewAccountProvider(svc *Services, spec Spec, hooks AccountHooks) *AccountProvider {
	apps := make(map[string]App, len(spec.Apps))
	for _, a := range spec.Apps {
		apps[a.ID] = a
	}
	return &AccountProvider{svc: svc, spec: spec, tools: NewToolset(spec.ToolList()), hooks: hooks, apps: apps}
}

func (p *AccountProvider) Info() Info { return p.spec.Info() }

func (p *AccountProvider) App(id string) (App, bool) {
	a, ok := p.apps[strings.TrimSpace(id)]
	return a, ok
}

func (p *AccountProvider) EnvStatus(scope Scope) Env { return p.hooks.Env(scope) }

func (p *AccountProvider) Tools(connectedApps []string, _ []Connection) []Tool {
	return p.tools.ForApps(connectedApps)
}

func (p *AccountProvider) ToolAppID(name string) string { return p.tools.AppID(name) }

func (p *AccountProvider) SupportsTool(name string) bool { return p.tools.Supports(name) }

func (p *AccountProvider) Snapshot(rows []Connection, scope Scope) Snapshot {
	snap := specSnapshot(p.spec, p.tools, rows, p.EnvStatus(scope))
	if p.hooks.Decorate != nil {
		p.hooks.Decorate(&snap, scope)
	}
	return snap
}

func (p *AccountProvider) SummarizeForModel(s Snapshot) string {
	if p.hooks.Summarize != nil {
		return p.hooks.Summarize(s)
	}
	return specSummary(p.spec, p.tools, s)
}

func (p *AccountProvider) toolContext(conn Connection) *ToolContext {
	return &ToolContext{
		AppID: conn.AppKey, Connection: conn, Credentials: p.svc.Credentials(conn),
		Env: p.EnvStatus(Scope{UserID: conn.UserID, AgentID: conn.AgentID}),
	}
}

func (p *AccountProvider) ExecuteTool(ctx context.Context, name string, args map[string]any, conn Connection) (*Execution, error) {
	tc := p.toolContext(conn)
	if app := p.tools.AppID(name); app != "" {
		tc.AppID = app
	}
	result, err := p.hooks.Execute(ctx, name, args, tc)
	if err != nil {
		return nil, err
	}
	return tc.execution(result), nil
}

// Disconnect runs the provider's cleanup.
func (p *AccountProvider) Disconnect(ctx context.Context, conn Connection) error {
	if p.hooks.Disconnect == nil {
		return nil
	}
	return p.hooks.Disconnect(ctx, p.toolContext(conn))
}

// TestConnection runs the provider's own check (see HasTest).
func (p *AccountProvider) TestConnection(ctx context.Context, conn Connection) (oauthclient.Credentials, error) {
	tc := p.toolContext(conn)
	if err := p.hooks.Test(ctx, tc); err != nil {
		return nil, err
	}
	if tc.updated {
		return tc.Credentials, nil
	}
	return nil, nil
}

// HasTest reports whether the provider has its own connection check.
func (p *AccountProvider) HasTest() bool { return p.hooks.Test != nil }

// specSnapshot is the snapshot every spec-based provider shows.
func specSnapshot(spec Spec, tools Toolset, rows []Connection, env Env) Snapshot {
	byApp := map[string][]Connection{}
	for _, row := range rows {
		id := strings.TrimSpace(row.AppKey)
		byApp[id] = append(byApp[id], row)
	}
	apps := make([]AppSnapshot, 0, len(spec.Apps))
	for _, app := range spec.Apps {
		apps = append(apps, SummarizeApp(app, byApp[app.ID], env, tools.CountForApp(app.ID)))
	}
	conn, count := SummarizeProvider(apps, env)
	multiple := true
	if spec.SupportsMultipleAccounts != nil {
		multiple = *spec.SupportsMultipleAccounts
	}
	method := spec.ConnectionMethod
	if method == "" {
		method = "oauth"
	}
	return Snapshot{
		ID: spec.Key, Label: spec.Label, Description: spec.Description, Icon: spec.Icon,
		Apps: apps, Env: env, Connection: conn, AvailableToolCount: count,
		Extra: map[string]any{"connectPrompt": spec.ConnectPrompt, "supportsMultipleAccounts": multiple, "connectionMethod": method},
	}
}

// specSummary is the default model summary of a spec-based provider.
func specSummary(spec Spec, tools Toolset, s Snapshot) string {
	if !s.Env.Configured {
		return DescribeIncompleteSetup(spec.Label, s.Env)
	}
	if !s.Connection.Connected {
		return spec.Label + ": setup is ready, but no accounts are connected yet. If the user wants to use it, tell them to connect an account in Official Integrations first."
	}
	lines := []string{
		spec.Label + ": native account access is connected in this run.",
		"Connected apps: " + ConnectedAppSummary(s.Apps),
	}
	for _, app := range s.Apps {
		if !app.Connection.Connected {
			continue
		}
		names := strings.Join(tools.NamesForApp(app.ID), ", ")
		if names == "" {
			names = "no built-in tools"
		}
		lines = append(lines, fmt.Sprintf("- %s: %s", app.Label, names))
	}
	return strings.Join(lines, "\n")
}

// ---- per-user setup ------------------------------------------------------------

// SetupReader is a provider whose setup dialog shows a provider-specific
// document (GET /api/integrations/:provider/config).
type SetupReader interface {
	SetupConfig(ctx context.Context, scope Scope) (any, error)
}

// SetupSaver saves the setup dialog (PUT .../config); for some providers that
// connects the account itself.
type SetupSaver interface {
	SaveSetup(ctx context.Context, scope Scope, config map[string]any) (any, error)
}

// SetupClearer removes the setup (DELETE .../config).
type SetupClearer interface {
	ClearSetup(ctx context.Context, scope Scope) error
}

// ---- interactive connections -------------------------------------------------

// ConnectionStart is how a provider that connects without OAuth answers a
// connect request: the page the apps open and the session it polls.
type ConnectionStart struct {
	Status    string `json:"status"`
	SessionID string `json:"sessionId"`
	// LoginURL is a sign-in page the connect page opens (Tailscale).
	LoginURL string `json:"loginUrl,omitempty"`
	URL      string `json:"url"`
}

// Connector connects accounts through its own connect page instead of an
// OAuth redirect.
type Connector interface {
	BeginConnection(ctx context.Context, scope Scope, appKey string) (ConnectionStart, error)
}

// ConnectionSession is what the connect page polls. Fields are written in
// this order; loginUrl only by providers that set HasLoginURL.
type ConnectionSession struct {
	ID           string
	Provider     string
	AppID        string
	Status       string
	LoginURL     string
	HasLoginURL  bool
	ConnectionID *int64
	AccountEmail string
	Error        string
	QR           string
}

// MarshalJSON writes the session like the Node providers do: empty values
// are null.
func (s ConnectionSession) MarshalJSON() ([]byte, error) {
	type kv struct {
		k string
		v any
	}
	fields := []kv{{"id", s.ID}, {"provider", s.Provider}, {"appId", s.AppID}, {"status", s.Status}}
	if s.HasLoginURL {
		fields = append(fields, kv{"loginUrl", nullableString(s.LoginURL)})
	}
	var conn any
	if s.ConnectionID != nil {
		conn = *s.ConnectionID
	}
	fields = append(fields, kv{"connectionId", conn}, kv{"accountEmail", nullableString(s.AccountEmail)},
		kv{"error", nullableString(s.Error)}, kv{"qr", nullableString(s.QR)})
	out := []byte{'{'}
	for i, f := range fields {
		if i > 0 {
			out = append(out, ',')
		}
		k, _ := json.Marshal(f.k)
		v, err := oauthclient.MarshalJS(f.v)
		if err != nil {
			return nil, err
		}
		out = append(append(append(out, k...), ':'), v...)
	}
	return append(out, '}'), nil
}

func nullableString(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// ConnectionSessions finds a session of the signed-in account.
type ConnectionSessions interface {
	ConnectionSession(scope Scope, sessionID string) (*ConnectionSession, bool)
}

// ConnectionCanceler stops a pending connection session.
type ConnectionCanceler interface {
	CancelConnectionSession(ctx context.Context, scope Scope, sessionID string) error
}

// ---- stores shared by these providers ---------------------------------------

// ProviderConfig is the account's stored setup of a provider
// (integration_provider_configs); unreadable values are empty, as in Node.
func (s *Services) ProviderConfig(ctx context.Context, scope Scope, providerKey string) map[string]any {
	if scope.UserID <= 0 || strings.TrimSpace(providerKey) == "" {
		return map[string]any{}
	}
	var stored string
	err := s.DB.R.QueryRowContext(ctx, `SELECT config_json FROM integration_provider_configs
		WHERE user_id = ? AND agent_id = ? AND provider_key = ?`, scope.UserID, scope.AgentID, providerKey).Scan(&stored)
	if err != nil {
		return map[string]any{}
	}
	plain, err := s.Box.Open(stored)
	if err != nil {
		return map[string]any{}
	}
	return ParseCredentials(plain)
}

// SetProviderConfig stores the setup sealed.
func (s *Services) SetProviderConfig(ctx context.Context, scope Scope, providerKey string, config map[string]any) error {
	if scope.UserID <= 0 || strings.TrimSpace(providerKey) == "" {
		return errors.New("A valid user and provider are required to save integration config.")
	}
	sealed, err := s.sealCredentials(config)
	if err != nil {
		return err
	}
	_, err = s.DB.W.ExecContext(ctx, `INSERT INTO integration_provider_configs (user_id, agent_id, provider_key, config_json, created_at, updated_at)
		VALUES (?, ?, ?, ?, datetime('now'), datetime('now'))
		ON CONFLICT(user_id, agent_id, provider_key) DO UPDATE SET
			config_json = excluded.config_json,
			updated_at = excluded.updated_at`, scope.UserID, scope.AgentID, providerKey, sealed)
	return err
}

// DeleteProviderConfig removes the setup.
func (s *Services) DeleteProviderConfig(ctx context.Context, scope Scope, providerKey string) error {
	_, err := s.DB.W.ExecContext(ctx, `DELETE FROM integration_provider_configs WHERE user_id = ? AND agent_id = ? AND provider_key = ?`,
		scope.UserID, scope.AgentID, providerKey)
	return err
}

// AccountApp is one app of an account connected with plain credentials.
type AccountApp struct {
	Scope        Scope
	ProviderKey  string
	AppKey       string
	AccountEmail string
	Scopes       []string
	Credentials  map[string]any
	Metadata     map[string]any
}

// UpsertAccountApp seals the credentials, keeps the access mode the person
// already chose for the app, and returns the stored row.
func (s *Services) UpsertAccountApp(ctx context.Context, a AccountApp) (*Connection, error) {
	existing, err := s.FindAppConnection(ctx, a.Scope.UserID, a.Scope.AgentID, a.ProviderKey, a.AppKey, a.AccountEmail)
	if err != nil {
		return nil, err
	}
	sealed, err := s.sealCredentials(a.Credentials)
	if err != nil {
		return nil, err
	}
	meta := map[string]any{}
	mode := AccessReadWrite
	if existing != nil {
		for k, v := range parseMetadata(existing.MetadataJSON) {
			meta[k] = v
		}
		mode = AccessMode(existing)
	} else if m, ok := a.Metadata["access_mode"].(string); ok {
		mode = normalizeAccessMode(m, AccessReadWrite)
	}
	for k, v := range a.Metadata {
		meta[k] = v
	}
	meta["access_mode"] = mode
	if err := s.UpsertConnection(ctx, ConnectedAccount{
		UserID: a.Scope.UserID, AgentID: a.Scope.AgentID, ProviderKey: a.ProviderKey, AppKey: a.AppKey,
		AccountEmail: a.AccountEmail, Scopes: a.Scopes, CredentialsJSON: sealed, Metadata: meta,
	}); err != nil {
		return nil, err
	}
	return s.FindAppConnection(ctx, a.Scope.UserID, a.Scope.AgentID, a.ProviderKey, a.AppKey, a.AccountEmail)
}

// DeleteSiblingConnections removes the other app rows of the connection's
// account: one sign-in backs them all, so disconnecting one disconnects it.
func (s *Services) DeleteSiblingConnections(ctx context.Context, conn Connection) error {
	_, err := s.DB.W.ExecContext(ctx, `DELETE FROM integration_connections
		WHERE user_id=? AND agent_id=? AND provider_key=? AND account_email=? AND id!=?`,
		conn.UserID, conn.AgentID, conn.ProviderKey, conn.AccountEmail, conn.ID)
	return err
}

// DeleteProviderConnections removes every connection of a provider.
func (s *Services) DeleteProviderConnections(ctx context.Context, scope Scope, providerKey string) error {
	_, err := s.DB.W.ExecContext(ctx, `DELETE FROM integration_connections WHERE user_id=? AND agent_id=? AND provider_key=?`,
		scope.UserID, scope.AgentID, providerKey)
	return err
}
