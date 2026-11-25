// Package bitwarden is the Bitwarden integration: the account's vault, signed
// in through the Bitwarden CLI, behind the credential broker so secret values
// never reach the model.
package bitwarden

import (
	"context"
	_ "embed"
	"errors"
	"math"
	"net/url"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

//go:embed provider.json
var specJSON []byte

const (
	key              = "bitwarden"
	appID            = "password_manager"
	defaultServerURL = "https://vault.bitwarden.com"
	noBindings       = "No credential bindings are configured."
)

// Bindings summarizes the credential bindings for the snapshot and the model.
type Bindings interface {
	SummarizeBindings(ctx context.Context, userID int64, agentID string) (string, error)
}

// Provider is the Bitwarden integration.
type Provider struct {
	svc      *integrations.Services
	spec     integrations.Spec
	cli      *CLI
	bindings Bindings
}

// New builds the provider over the CLI driver; bindings may be nil.
func New(svc *integrations.Services, cli *CLI, bindings Bindings) *Provider {
	return &Provider{svc: svc, spec: integrations.LoadSpec(specJSON), cli: cli, bindings: bindings}
}

func text(v any) string { return strings.TrimSpace(integrations.Str(v)) }

func normalizeServerURL(value any) (string, error) {
	raw := text(value)
	if raw == "" {
		raw = defaultServerURL
	}
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.Host == "" || u.User != nil || u.RawQuery != "" || u.ForceQuery || u.Fragment != "" {
		return "", errors.New("Bitwarden server must be an HTTPS URL without embedded credentials.")
	}
	if u.Path == "" {
		u.Path = "/"
	}
	return strings.TrimRight(u.String(), "/"), nil
}

type config struct {
	serverURL, email, clientID, clientSecret string
	idleMinutes                              float64
}

func parseConfig(raw, existing map[string]any) (config, error) {
	pick := func(k string) string {
		if v := text(raw[k]); v != "" {
			return v
		}
		return text(existing[k])
	}
	server := raw["serverUrl"]
	if !dyn.Truthy(server) {
		server = existing["serverUrl"]
	}
	if !dyn.Truthy(server) {
		server = defaultServerURL
	}
	serverURL, err := normalizeServerURL(server)
	if err != nil {
		return config{}, err
	}
	idle := raw["idleTimeoutMinutes"]
	if !dyn.Truthy(idle) {
		idle = existing["idleTimeoutMinutes"]
	}
	n, ok := integrations.JSNumber(idle)
	if !dyn.Truthy(idle) {
		n, ok = 30, true
	}
	minutes := math.NaN()
	if ok {
		minutes = math.Max(5, math.Min(120, n))
	}
	return config{serverURL: serverURL, email: pick("email"), clientID: pick("clientId"), clientSecret: pick("clientSecret"), idleMinutes: minutes}, nil
}

func (c config) stored() map[string]any {
	var idle any = c.idleMinutes
	if math.IsNaN(c.idleMinutes) {
		idle = nil
	}
	return map[string]any{"serverUrl": c.serverURL, "email": c.email, "clientId": c.clientID, "clientSecret": c.clientSecret, "idleTimeoutMinutes": idle}
}

func (p *Provider) config(ctx context.Context, scope integrations.Scope) (config, map[string]any, error) {
	stored := p.svc.ProviderConfig(ctx, scope, key)
	c, err := parseConfig(stored, map[string]any{})
	return c, stored, err
}

func (p *Provider) connection(ctx context.Context, scope integrations.Scope) (*integrations.Connection, error) {
	rows, err := p.svc.ListConnections(ctx, scope.UserID, key, scope.AgentID)
	if err != nil {
		return nil, err
	}
	var best *integrations.Connection
	for i := range rows {
		r := rows[i]
		if r.AppKey != appID {
			continue
		}
		if best == nil || r.UpdatedAt > best.UpdatedAt || (r.UpdatedAt == best.UpdatedAt && r.ID > best.ID) {
			best = &r
		}
	}
	return best, nil
}

func (p *Provider) publicConfig(c config, conn *integrations.Connection, st Status) dyn.Ordered {
	connected := conn != nil && conn.Status == "connected"
	count := 0
	if connected {
		count = 1
	}
	var connID any
	if conn != nil {
		connID = conn.ID
	}
	server := c.serverURL
	if server == "" {
		server = defaultServerURL
	}
	return dyn.Ordered{
		{Key: "serverUrl", Value: server}, {Key: "email", Value: c.email}, {Key: "authenticationMethod", Value: "master_password"},
		{Key: "hasClientId", Value: c.clientID != ""}, {Key: "hasClientSecret", Value: c.clientSecret != ""},
		{Key: "configured", Value: c.email != ""}, {Key: "accountCount", Value: count}, {Key: "hasConnectedAccount", Value: connected},
		{Key: "connectionId", Value: connID}, {Key: "cliAvailable", Value: st.CLIAvailable}, {Key: "unlocked", Value: st.Unlocked},
		{Key: "persistent", Value: st.Persistent}, {Key: "lastUsedAt", Value: st.LastUsedAt},
	}
}

// ---- Provider -----------------------------------------------------------------

func (p *Provider) Info() integrations.Info { return p.spec.Info() }

func (p *Provider) App(id string) (integrations.App, bool) {
	if strings.TrimSpace(id) == appID {
		return p.spec.Apps[0], true
	}
	return integrations.App{}, false
}

func (p *Provider) EnvStatus(scope integrations.Scope) integrations.Env {
	email := ""
	if scope.UserID > 0 {
		if c, _, err := p.config(context.Background(), scope); err == nil {
			email = c.email
		}
	}
	if email != "" {
		return integrations.Env{Configured: true, Missing: []string{}, Summary: "Bitwarden is ready. Sign in once with the master password to connect the vault.", SetupMode: "user"}
	}
	return integrations.Env{Configured: false, Missing: []string{"email"}, Summary: "Add the Bitwarden account email in Official Integrations.", SetupMode: "user"}
}

func (p *Provider) Tools([]string, []integrations.Connection) []integrations.Tool { return nil }

func (p *Provider) ToolAppID(string) string { return "" }

func (p *Provider) SupportsTool(string) bool { return false }

func (p *Provider) ExecuteTool(context.Context, string, map[string]any, integrations.Connection) (*integrations.Execution, error) {
	return nil, errors.New("Bitwarden has no tools.")
}

func (p *Provider) bindingSummary(ctx context.Context, scope integrations.Scope) string {
	if p.bindings == nil || scope.UserID <= 0 {
		return noBindings
	}
	s, err := p.bindings.SummarizeBindings(ctx, scope.UserID, scope.AgentID)
	if err != nil || s == "" {
		return noBindings
	}
	return s
}

// Snapshot shows the one vault connection, newest row first.
func (p *Provider) Snapshot(rows []integrations.Connection, scope integrations.Scope) integrations.Snapshot {
	env := p.EnvStatus(scope)
	var row *integrations.Connection
	for i := range rows {
		r := rows[i]
		if r.AppKey == appID && (row == nil || r.UpdatedAt > row.UpdatedAt) {
			row = &r
		}
	}
	status := "env_not_configured"
	if env.Configured {
		status = "not_connected"
	}
	accounts := []integrations.AccountSnapshot{}
	conn := integrations.AppConnection{Status: status}
	if row != nil {
		id := row.ID
		acc := integrations.AccountSnapshot{ID: &id, Status: row.Status, Connected: row.Status == "connected",
			AccountEmail: nonEmpty(row.AccountEmail), LastConnectedAt: nonEmpty(row.LastConnectedAt), AccessMode: integrations.AccessMode(row)}
		accounts = append(accounts, acc)
		conn = integrations.AppConnection{Status: row.Status, Connected: acc.Connected, AccountEmail: acc.AccountEmail, LastConnectedAt: acc.LastConnectedAt}
		if !env.Configured {
			conn.Status = "env_not_configured"
		}
		if acc.Connected {
			conn.AccountCount = 1
		}
	}
	tools := 0
	if conn.Connected {
		tools = 2
	}
	app := p.spec.Apps[0]
	appCount := conn.AccountCount
	conn.AppCount = &appCount
	return integrations.Snapshot{
		ID: p.spec.Key, Label: p.spec.Label, Description: p.spec.Description, Icon: p.spec.Icon,
		Apps: []integrations.AppSnapshot{{ID: app.ID, Label: app.Label, Description: app.Description, Accounts: accounts,
			Connection: conn, AvailableToolCount: tools}},
		Env: env,
		Connection: integrations.ProviderConnection{Status: conn.Status, Connected: conn.Connected, AccountEmail: conn.AccountEmail,
			AccountCount: conn.AccountCount, AppCount: appCount, LastConnectedAt: conn.LastConnectedAt},
		AvailableToolCount: tools,
		Extra: map[string]any{"credentialBindingsSummary": p.bindingSummary(context.Background(), scope),
			"connectPrompt": p.spec.ConnectPrompt, "supportsMultipleAccounts": false, "connectionMethod": "user_config"},
	}
}

func nonEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func (p *Provider) SummarizeForModel(s integrations.Snapshot) string {
	if !s.Connection.Connected {
		return "Bitwarden: not configured. The user can connect it in Official Integrations."
	}
	bindings, _ := s.Extra["credentialBindingsSummary"].(string)
	if bindings == "" {
		bindings = noBindings
	}
	return "Bitwarden credential broker: " + bindings + " Secret values are never available to the model."
}

// Shutdown locks the vault sessions that do not persist.
func (p *Provider) Shutdown(context.Context) error {
	if p.cli != nil {
		p.cli.Close()
	}
	return nil
}

// HasTest: the check syncs the vault.
func (p *Provider) HasTest() bool { return true }

// TestConnection syncs the vault.
func (p *Provider) TestConnection(ctx context.Context, conn integrations.Connection) (oauthclient.Credentials, error) {
	if p.cli == nil {
		return nil, errors.New("Bitwarden credential service is unavailable.")
	}
	return nil, p.cli.Sync(ctx, conn.UserID, conn.AgentID)
}

// ---- setup ---------------------------------------------------------------------

func (p *Provider) status(scope integrations.Scope) Status {
	if p.cli == nil {
		return Status{}
	}
	return p.cli.GetStatus(scope.UserID, scope.AgentID)
}

// SetupConfig is what the setup dialog shows.
func (p *Provider) SetupConfig(ctx context.Context, scope integrations.Scope) (any, error) {
	c, _, err := p.config(ctx, scope)
	if err != nil {
		return nil, err
	}
	conn, err := p.connection(ctx, scope)
	if err != nil {
		return nil, err
	}
	return p.publicConfig(c, conn, p.status(scope)), nil
}

// SaveSetup stores the account details; another account or server signs
// the old one out.
func (p *Provider) SaveSetup(ctx context.Context, scope integrations.Scope, raw map[string]any) (any, error) {
	if scope.UserID <= 0 {
		return nil, errors.New("A valid user is required to save Bitwarden configuration.")
	}
	existing := p.svc.ProviderConfig(ctx, scope, key)
	parsed, err := parseConfig(raw, existing)
	if err != nil {
		return nil, err
	}
	if parsed.email == "" {
		return nil, errors.New("Bitwarden account email is required.")
	}
	if p.cli == nil {
		return nil, errors.New("Bitwarden credential service is unavailable.")
	}
	current, err := p.connection(ctx, scope)
	if err != nil {
		return nil, err
	}
	if current != nil {
		oldServer, err := normalizeServerURL(existing["serverUrl"])
		if err != nil {
			return nil, err
		}
		if !strings.EqualFold(strings.TrimSpace(current.AccountEmail), parsed.email) || oldServer != parsed.serverURL {
			p.cli.Logout(ctx, scope.UserID, scope.AgentID)
			if _, err := p.svc.DB.W.ExecContext(ctx, `DELETE FROM integration_connections WHERE id = ?`, current.ID); err != nil {
				return nil, err
			}
		}
	}
	if err := p.svc.SetProviderConfig(ctx, scope, key, parsed.stored()); err != nil {
		return nil, err
	}
	conn, err := p.connection(ctx, scope)
	if err != nil {
		return nil, err
	}
	return p.publicConfig(parsed, conn, p.status(scope)), nil
}

// ClearSetup signs out and forgets the account.
func (p *Provider) ClearSetup(ctx context.Context, scope integrations.Scope) error {
	if p.cli != nil {
		p.cli.Logout(ctx, scope.UserID, scope.AgentID)
	}
	if err := p.svc.DeleteProviderConfig(ctx, scope, key); err != nil {
		return err
	}
	return p.svc.DeleteProviderConnections(ctx, scope, key)
}

// Unlock signs in with the master password (never stored) and connects.
func (p *Provider) Unlock(ctx context.Context, scope integrations.Scope, password string, persist bool, method, code any) (dyn.Ordered, error) {
	c, _, err := p.config(ctx, scope)
	if err != nil {
		return nil, err
	}
	if c.email == "" {
		return nil, errors.New("Save the Bitwarden account email before signing in.")
	}
	if p.cli == nil {
		return nil, errors.New("Bitwarden credential service is unavailable.")
	}
	var idle any = c.idleMinutes
	if _, err := p.cli.Unlock(ctx, scope.UserID, scope.AgentID, password, idle, UnlockOptions{
		ServerURL: c.serverURL, Email: c.email, ClientID: c.clientID, ClientSecret: c.clientSecret,
		Persist: persist, TwoStepMethod: method, TwoStepCode: code,
	}); err != nil {
		return nil, err
	}
	conn, err := p.upsertConnection(ctx, scope, c)
	if err != nil {
		return nil, err
	}
	return p.publicConfig(c, conn, p.status(scope)), nil
}

func (p *Provider) upsertConnection(ctx context.Context, scope integrations.Scope, c config) (*integrations.Connection, error) {
	existing, err := p.connection(ctx, scope)
	if err != nil {
		return nil, err
	}
	creds, _ := oauthclient.MarshalJS(map[string]any{"serverUrl": c.serverURL, "email": c.email})
	sealed, err := p.svc.Seal(string(creds))
	if err != nil {
		return nil, err
	}
	var idle any = c.idleMinutes
	if math.IsNaN(c.idleMinutes) {
		idle = nil
	}
	if err := p.svc.UpsertConnection(ctx, integrations.ConnectedAccount{
		UserID: scope.UserID, AgentID: scope.AgentID, ProviderKey: key, AppKey: appID, AccountEmail: c.email,
		Scopes: []string{"vault:read_selected"}, CredentialsJSON: sealed,
		Metadata: map[string]any{"access_mode": integrations.AccessMode(existing), "idleTimeoutMinutes": idle},
	}); err != nil {
		return nil, err
	}
	if existing != nil && existing.AccountEmail != c.email {
		if _, err := p.svc.DB.W.ExecContext(ctx, `DELETE FROM integration_connections WHERE id = ?`, existing.ID); err != nil {
			return nil, err
		}
	}
	return p.connection(ctx, scope)
}
