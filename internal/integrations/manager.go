package integrations

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

const oauthStateTTL = 15 * time.Minute

// Hooks are the other domains that react to integrations. Each is optional.
type Hooks struct {
	// OnConnected runs after an account was connected through OAuth.
	OnConnected func(conn Connection, memorySweep bool)
	// DecorateSnapshot adds what other domains know about a provider (memory
	// ingestion coverage) to a snapshot.
	DecorateSnapshot func(ctx context.Context, snap *Snapshot, userID int64, agentID string)
}

// Manager owns the connections of every provider.
type Manager struct {
	svc       *Services
	providers []Provider
	byKey     map[string]Provider
	hooks     Hooks
	log       *slog.Logger
	locks     keyedLocks
}

// NewManager registers the providers. Their order is their order in the apps.
func NewManager(svc *Services, providers []Provider, hooks Hooks, log *slog.Logger) (*Manager, error) {
	svc.init()
	if log == nil {
		log = slog.Default()
	}
	m := &Manager{svc: svc, providers: providers, byKey: map[string]Provider{}, hooks: hooks, log: log}
	for _, p := range providers {
		key := p.Info().Key
		if _, dup := m.byKey[key]; dup {
			return nil, fmt.Errorf("duplicate official integration provider key: %s", key)
		}
		m.byKey[key] = p
	}
	return m, nil
}

// Provider finds a provider by key.
func (m *Manager) Provider(key string) Provider { return m.byKey[strings.TrimSpace(key)] }

// Providers lists the registered providers in order.
func (m *Manager) Providers() []Provider { return m.providers }

// Services are the shared dependencies.
func (m *Manager) Services() *Services { return m.svc }

func (m *Manager) agent(ctx context.Context, userID int64, candidate string) (string, error) {
	return m.svc.ResolveAgent(ctx, userID, candidate)
}

func (m *Manager) unknownProvider(key string) error {
	return fmt.Errorf("Unknown integration provider: %s", key)
}

// ---- listing -----------------------------------------------------------------

func rowsByProvider(rows []Connection) map[string][]Connection {
	out := map[string][]Connection{}
	for _, r := range rows {
		key := strings.TrimSpace(r.ProviderKey)
		out[key] = append(out[key], r)
	}
	return out
}

// safeTestTool is a read tool that needs no arguments, usable to check a
// connection.
func safeTestTool(p Provider, appKey string) *Tool {
	for _, t := range p.Tools([]string{strings.TrimSpace(appKey)}, nil) {
		if t.Access == "read" && !t.HasRequired {
			t := t
			return &t
		}
	}
	return nil
}

func providerTester(p Provider) Tester {
	if t, ok := p.(Tester); ok && t.HasTest() {
		return t
	}
	return nil
}

func (m *Manager) supportsConnectionTest(p Provider, c *Connection) bool {
	if c == nil || c.Status != "connected" {
		return false
	}
	return providerTester(p) != nil || safeTestTool(p, c.AppKey) != nil
}

func (m *Manager) decorateTestSupport(snap Snapshot, p Provider, rows []Connection) Snapshot {
	byID := map[int64]*Connection{}
	for i := range rows {
		byID[rows[i].ID] = &rows[i]
	}
	apps := make([]AppSnapshot, len(snap.Apps))
	for i, app := range snap.Apps {
		accounts := make([]AccountSnapshot, len(app.Accounts))
		for j, acc := range app.Accounts {
			if acc.ID != nil {
				acc.SupportsConnectionTest = m.supportsConnectionTest(p, byID[*acc.ID])
			}
			accounts[j] = acc
			app.SupportsConnectionTest = app.SupportsConnectionTest || acc.SupportsConnectionTest
		}
		app.Accounts = accounts
		apps[i] = app
		snap.SupportsConnectionTest = snap.SupportsConnectionTest || app.SupportsConnectionTest
	}
	snap.Apps = apps
	return snap
}

// ListProviders is the snapshot of every provider for one agent.
func (m *Manager) ListProviders(ctx context.Context, userID int64, agentID string) ([]Snapshot, error) {
	agentID, err := m.agent(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	if err := m.svc.cleanupExpiredStates(ctx); err != nil {
		return nil, err
	}
	rows, err := m.svc.ListConnections(ctx, userID, "", agentID)
	if err != nil {
		return nil, err
	}
	byProvider := rowsByProvider(rows)
	out := make([]Snapshot, 0, len(m.providers))
	for _, p := range m.providers {
		conns := byProvider[p.Info().Key]
		snap := m.decorateTestSupport(p.Snapshot(conns, Scope{UserID: userID, AgentID: agentID}), p, conns)
		if m.hooks.DecorateSnapshot != nil {
			m.hooks.DecorateSnapshot(ctx, &snap, userID, agentID)
		}
		out = append(out, snap)
	}
	return out, nil
}

// ---- OAuth flow --------------------------------------------------------------

// BeginOptions are the arguments of BeginOAuth.
type BeginOptions struct {
	AppKey      string
	AgentID     string
	MemorySweep bool
}

// OAuthStart is where the person goes to approve access.
type OAuthStart struct {
	Provider string `json:"provider"`
	AppID    string `json:"appId"`
	Status   string `json:"status"`
	State    string `json:"state"`
	URL      string `json:"url"`
}

// BeginOAuth stores a state and returns the provider's authorization URL.
func (m *Manager) BeginOAuth(ctx context.Context, userID int64, providerKey string, opts BeginOptions) (*OAuthStart, error) {
	if err := m.svc.cleanupExpiredStates(ctx); err != nil {
		return nil, err
	}
	agentID, err := m.agent(ctx, userID, opts.AgentID)
	if err != nil {
		return nil, err
	}
	p := m.Provider(providerKey)
	if p == nil {
		return nil, m.unknownProvider(providerKey)
	}
	info := p.Info()
	appKey := strings.TrimSpace(opts.AppKey)
	if _, ok := p.App(appKey); !ok {
		missing := appKey
		if missing == "" {
			missing = "missing app key"
		}
		return nil, fmt.Errorf("Unknown %s app: %s", info.Label, missing)
	}
	scope := Scope{UserID: userID, AgentID: agentID}
	if env := p.EnvStatus(scope); !env.Configured {
		return nil, errors.New(env.Summary)
	}
	oauth, ok := p.(OAuthProvider)
	if !ok {
		return nil, fmt.Errorf("%s cannot be connected with OAuth.", info.Label)
	}

	state, err := randomHex(24)
	if err != nil {
		return nil, err
	}
	verifier, err := randomBase64URL(48)
	if err != nil {
		return nil, err
	}
	begun, err := oauth.BeginOAuth(ctx, BeginParams{State: state, CodeVerifier: verifier, Scope: scope, AppKey: appKey})
	if err != nil {
		return nil, err
	}
	sealed, err := m.svc.Seal(verifier)
	if err != nil {
		return nil, err
	}
	err = m.svc.insertState(ctx, OAuthState{
		UserID: userID, AgentID: agentID, ProviderKey: info.Key, AppKey: appKey, State: state,
		CodeVerifier: sealed, MemorySweep: opts.MemorySweep,
	}, oauthclient.ISO(m.svc.Now().Add(oauthStateTTL)))
	if err != nil {
		return nil, err
	}
	return &OAuthStart{Provider: info.Key, AppID: appKey, Status: "oauth_redirect", State: state, URL: begun.URL}, nil
}

func randomHex(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

func randomBase64URL(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

// DescribePendingOAuth says what a held callback would connect; nil when the
// state is unknown or expired.
func (m *Manager) DescribePendingOAuth(ctx context.Context, state string) (*PendingOAuth, error) {
	var row struct{ provider, app, started, user string }
	err := m.svc.DB.R.QueryRowContext(ctx, `SELECT s.provider_key, s.app_key, s.created_at, u.username
		FROM integration_oauth_states s JOIN users u ON u.id = s.user_id
		WHERE s.state = ? AND datetime(s.expires_at) > datetime('now')`, strings.TrimSpace(state)).
		Scan(&row.provider, &row.app, &row.started, &row.user)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	pending := &PendingOAuth{ProviderLabel: row.provider, Username: row.user, StartedAt: row.started}
	if p := m.Provider(row.provider); p != nil {
		pending.ProviderLabel = p.Info().Label
		if app, ok := p.App(row.app); ok {
			pending.AppLabel = app.Label
		}
	}
	return pending, nil
}

// OAuthResult is the account a finished redirect connected.
type OAuthResult struct {
	Provider     string
	AppID        string
	ConnectionID *int64
	AccountEmail string
}

// FinishOAuth completes the redirect flow of a state. It is the one entry the
// shared OAuth callback calls for integration states.
func (m *Manager) FinishOAuth(ctx context.Context, state, code string) (*OAuthResult, error) {
	if err := m.svc.cleanupExpiredStates(ctx); err != nil {
		return nil, err
	}
	state = strings.TrimSpace(state)
	if !oauthStatePattern.MatchString(state) {
		return nil, errors.New("OAuth state is invalid or malformed.")
	}
	code = strings.TrimSpace(code)
	if code == "" {
		return nil, errors.New("OAuth authorization code is required.")
	}
	row, err := m.svc.claimState(ctx, state)
	if err != nil {
		return nil, err
	}
	if row == nil {
		return nil, errors.New("OAuth state is missing or expired.")
	}
	p := m.Provider(row.ProviderKey)
	if p == nil {
		return nil, m.unknownProvider(row.ProviderKey)
	}
	oauth, ok := p.(OAuthProvider)
	if !ok {
		return nil, fmt.Errorf("%s cannot be connected with OAuth.", p.Info().Label)
	}
	agentID := row.AgentID
	if agentID == "" {
		if agentID, err = m.agent(ctx, row.UserID, ""); err != nil {
			return nil, err
		}
	}
	verifier, err := m.svc.Open(row.CodeVerifier)
	if err != nil {
		return nil, err
	}
	finished, err := oauth.FinishOAuth(ctx, FinishParams{
		Code: code, CodeVerifier: verifier, State: row.State, AppKey: row.AppKey,
		Scope: Scope{UserID: row.UserID, AgentID: agentID},
	})
	if err != nil {
		return nil, err
	}
	info := p.Info()
	merged, err := m.mergeWithReusable(ctx, row.UserID, agentID, info.Key, finished.AccountEmail, finished.Credentials)
	if err != nil {
		return nil, err
	}
	if err := assertDurableCredentials(info, merged); err != nil {
		return nil, err
	}
	sealed, err := m.svc.sealCredentials(merged)
	if err != nil {
		return nil, err
	}

	appKeys := []string{}
	for _, k := range append([]string{row.AppKey}, finished.AlsoConnectsAppIDs...) {
		if k != "" && !contains(appKeys, k) {
			appKeys = append(appKeys, k)
		}
	}
	for _, k := range appKeys {
		meta := finished.Metadata
		if k != row.AppKey {
			meta = map[string]any{}
			for mk, mv := range finished.Metadata {
				meta[mk] = mv
			}
			meta["appId"] = k
		}
		if err := m.svc.UpsertConnection(ctx, ConnectedAccount{
			UserID: row.UserID, AgentID: agentID, ProviderKey: info.Key, AppKey: k,
			AccountEmail: finished.AccountEmail, Scopes: finished.Scopes, CredentialsJSON: sealed, Metadata: meta,
		}); err != nil {
			return nil, err
		}
	}
	if err := m.svc.PersistSharedCredentials(ctx, row.UserID, agentID, info.Key, finished.AccountEmail, merged); err != nil {
		return nil, err
	}

	result := &OAuthResult{Provider: info.Key, AppID: row.AppKey, AccountEmail: finished.AccountEmail}
	conn, err := m.svc.FindAppConnection(ctx, row.UserID, agentID, info.Key, row.AppKey, finished.AccountEmail)
	if err != nil {
		return nil, err
	}
	if conn != nil {
		result.ConnectionID = &conn.ID
		if m.hooks.OnConnected != nil {
			m.hooks.OnConnected(*conn, row.MemorySweep)
		}
	}
	return result, nil
}

func contains(list []string, s string) bool {
	for _, e := range list {
		if e == s {
			return true
		}
	}
	return false
}

// assertDurableCredentials refuses a connection that would stop working: no
// access token, or no refresh token where the provider needs one.
func assertDurableCredentials(info Info, creds oauthclient.Credentials) error {
	label := strings.TrimSpace(info.Label)
	if label == "" {
		label = "This integration"
	}
	if strings.TrimSpace(creds.String("access_token")) == "" {
		return fmt.Errorf("%s did not return an access token, so the connection could not be completed.", label)
	}
	if info.RequiresRefreshToken && strings.TrimSpace(creds.String("refresh_token")) == "" {
		return fmt.Errorf("%s did not return a refresh token, so the connection would expire. Revoke the existing app grant for this provider and reconnect it so offline access is granted.", label)
	}
	return nil
}

// mergeWithReusable adds the stored credentials of the same account so a
// reconnect that returns no refresh token keeps the old one.
func (m *Manager) mergeWithReusable(ctx context.Context, userID int64, agentID, providerKey, accountEmail string, creds oauthclient.Credentials) (oauthclient.Credentials, error) {
	if creds == nil {
		creds = oauthclient.Credentials{}
	}
	email := strings.ToLower(strings.TrimSpace(accountEmail))
	if email == "" {
		return creds, nil
	}
	rows, err := m.svc.ListConnections(ctx, userID, providerKey, agentID)
	if err != nil {
		return nil, err
	}
	var best *Connection
	for i := range rows {
		r := &rows[i]
		if strings.ToLower(strings.TrimSpace(r.AccountEmail)) != email || r.Status != "connected" {
			continue
		}
		if best == nil || r.UpdatedAt > best.UpdatedAt {
			best = r
		}
	}
	if best == nil {
		return creds, nil
	}
	return oauthclient.Merge(m.svc.Credentials(*best), creds), nil
}

// ---- disconnect, test, access mode -------------------------------------------

func parseConnectionID(v any) (int64, bool) {
	n, ok := JSNumber(v)
	if !ok || n != float64(int64(n)) || n <= 0 {
		return 0, false
	}
	return int64(n), true
}

// DisconnectResult is the answer to disconnecting an account.
type DisconnectResult struct {
	Disconnected bool   `json:"disconnected"`
	Provider     string `json:"provider"`
	AppID        string `json:"appId"`
	ConnectionID int64  `json:"connectionId"`
}

// Disconnect removes an account from an agent. connectionID is the raw request
// value.
func (m *Manager) Disconnect(ctx context.Context, userID int64, providerKey, agentID string, connectionID any) (*DisconnectResult, error) {
	agentID, err := m.agent(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	p := m.Provider(providerKey)
	if p == nil {
		return nil, m.unknownProvider(providerKey)
	}
	id, ok := parseConnectionID(connectionID)
	if !ok {
		return nil, errors.New("A valid connectionId is required to disconnect an account.")
	}
	info := p.Info()
	conn, err := m.svc.ConnectionByID(ctx, userID, id, agentID)
	if err != nil {
		return nil, err
	}
	if conn == nil || conn.ProviderKey != info.Key {
		return nil, fmt.Errorf("That %s account is not connected to this agent.", info.Label)
	}
	if err := m.prepareDisconnect(ctx, p, *conn, userID, agentID); err != nil {
		return nil, err
	}
	// Apps connected with the same account share one stored token; revoking it
	// would silently break the others.
	rows, err := m.svc.ListConnections(ctx, userID, info.Key, agentID)
	if err != nil {
		return nil, err
	}
	email := strings.ToLower(strings.TrimSpace(conn.AccountEmail))
	shared := false
	for _, r := range rows {
		if r.ID != conn.ID && strings.ToLower(strings.TrimSpace(r.AccountEmail)) == email {
			shared = true
		}
	}
	if d, ok := p.(Disconnector); ok && !shared {
		if err := d.Disconnect(ctx, *conn); err != nil {
			m.log.Warn("integration revoke failed", "provider", info.Key, "connection", conn.ID, "error", err)
		}
	}
	if _, err := m.svc.DB.W.ExecContext(ctx, `DELETE FROM integration_connections WHERE user_id = ? AND agent_id = ? AND id = ?`, userID, agentID, conn.ID); err != nil {
		return nil, err
	}
	return &DisconnectResult{Disconnected: true, Provider: info.Key, AppID: conn.AppKey, ConnectionID: conn.ID}, nil
}

// TestResult is the answer to a connection test.
type TestResult struct {
	OK           bool    `json:"ok"`
	Provider     string  `json:"provider"`
	ConnectionID int64   `json:"connectionId"`
	AccountEmail *string `json:"accountEmail"`
	CheckedAt    string  `json:"checkedAt"`
	Message      string  `json:"message"`
}

var expiredHints = []string{
	"invalid_grant", "token refresh failed", "token expired", "access token is missing",
	"refresh token is missing", "reconnect this integration account",
	"account is no longer authorized", "reauthorize", "re-authorize",
}

func isLikelyExpiredConnectionError(err error) bool {
	msg := strings.ToLower(err.Error())
	if msg == "" {
		return false
	}
	for _, hint := range expiredHints {
		if strings.Contains(msg, hint) {
			return true
		}
	}
	return false
}

func (m *Manager) markTested(ctx context.Context, c Connection, status string) (string, error) {
	current, err := m.svc.ConnectionByID(ctx, c.UserID, c.ID, c.AgentID)
	if err != nil || current == nil {
		return "", err
	}
	meta := parseMetadata(current.MetadataJSON)
	checkedAt := oauthclient.ISO(m.svc.Now())
	meta["last_connection_test_at"] = checkedAt
	meta["last_connection_test_status"] = status
	raw, err := marshal(meta)
	if err != nil {
		return "", err
	}
	_, err = m.svc.DB.W.ExecContext(ctx, `UPDATE integration_connections SET metadata_json = ?, updated_at = datetime('now')
		WHERE id = ? AND user_id = ? AND agent_id = ?`, raw, c.ID, c.UserID, c.AgentID)
	return checkedAt, err
}

// TestConnection checks that a connected account still works.
func (m *Manager) TestConnection(ctx context.Context, userID int64, providerKey, agentID string, connectionID any) (*TestResult, error) {
	agentID, err := m.agent(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	p := m.Provider(providerKey)
	if p == nil {
		return nil, m.unknownProvider(providerKey)
	}
	info := p.Info()
	id, ok := parseConnectionID(connectionID)
	if !ok {
		return nil, errors.New("Choose a connected account to test.")
	}
	conn, err := m.svc.ConnectionByID(ctx, userID, id, agentID)
	if err != nil {
		return nil, err
	}
	if conn == nil || conn.ProviderKey != info.Key || conn.Status != "connected" {
		return nil, fmt.Errorf("The selected %s account is not connected.", info.Label)
	}
	if !m.supportsConnectionTest(p, conn) {
		return nil, fmt.Errorf("%s does not provide a safe connection test yet.", info.Label)
	}

	err = m.runTest(ctx, p, conn, agentID)
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		if _, merr := m.markTested(ctx, *conn, "failed"); merr != nil {
			m.log.Warn("recording failed connection test", "error", merr)
		}
		if isLikelyExpiredConnectionError(err) {
			if _, uerr := m.svc.DB.W.ExecContext(ctx, `UPDATE integration_connections SET status = 'expired', updated_at = datetime('now')
				WHERE id = ? AND user_id = ? AND agent_id = ?`, conn.ID, userID, agentID); uerr != nil {
				return nil, uerr
			}
			return nil, fmt.Errorf("Your %s connection has expired. Reconnect the account and try again.", info.Label)
		}
		return nil, err
	}
	checkedAt, err := m.markTested(ctx, *conn, "passed")
	if err != nil {
		return nil, err
	}
	res := &TestResult{OK: true, Provider: info.Key, ConnectionID: conn.ID, CheckedAt: checkedAt, Message: info.Label + " is connected and responding."}
	res.AccountEmail = nonEmpty(conn.AccountEmail)
	return res, nil
}

func (m *Manager) runTest(ctx context.Context, p Provider, conn *Connection, agentID string) error {
	if t := providerTester(p); t != nil {
		creds, err := t.TestConnection(ctx, *conn)
		if err != nil {
			return err
		}
		if creds != nil {
			merged := oauthclient.Merge(m.svc.Credentials(*conn), creds)
			return m.svc.PersistSharedCredentials(ctx, conn.UserID, agentID, p.Info().Key, conn.AccountEmail, merged)
		}
		return nil
	}
	tool := safeTestTool(p, conn.AppKey)
	result, err := m.ExecuteTool(ctx, conn.UserID, tool.Name, map[string]any{"connection_id": float64(conn.ID)}, agentID, ExecOptions{})
	if err != nil {
		return err
	}
	if f, ok := result.(*ToolFailure); ok {
		return errors.New(f.Error)
	}
	return nil
}

// AccessModeResult is the answer to changing a connection's access mode.
type AccessModeResult struct {
	Provider     string `json:"provider"`
	ConnectionID int64  `json:"connectionId"`
	AccessMode   string `json:"accessMode"`
}

// UpdateAccessMode switches an account between read-only and read/write.
func (m *Manager) UpdateAccessMode(ctx context.Context, userID int64, providerKey, agentID string, connectionID any, accessMode string) (*AccessModeResult, error) {
	agentID, err := m.agent(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	p := m.Provider(providerKey)
	if p == nil {
		return nil, m.unknownProvider(providerKey)
	}
	info := p.Info()
	id, ok := parseConnectionID(connectionID)
	if !ok {
		return nil, errors.New("A valid connectionId is required to update integration access mode.")
	}
	conn, err := m.svc.ConnectionByID(ctx, userID, id, agentID)
	if err != nil {
		return nil, err
	}
	if conn == nil || conn.ProviderKey != info.Key {
		return nil, fmt.Errorf("No connected %s account matches connection_id %d.", info.Label, id)
	}
	mode := normalizeAccessMode(accessMode, "")
	if mode == "" {
		return nil, errors.New(`Invalid accessMode. Use "read_only" or "read_write".`)
	}
	raw, err := marshal(withAccessMode(conn.MetadataJSON, mode))
	if err != nil {
		return nil, err
	}
	if _, err := m.svc.DB.W.ExecContext(ctx, `UPDATE integration_connections SET metadata_json = ?, updated_at = datetime('now')
		WHERE id = ? AND user_id = ? AND agent_id = ?`, raw, conn.ID, userID, agentID); err != nil {
		return nil, err
	}
	return &AccessModeResult{Provider: info.Key, ConnectionID: conn.ID, AccessMode: mode}, nil
}

// ---- tools -------------------------------------------------------------------

func connectedApps(conns []Connection) ([]string, []Connection) {
	var apps []string
	var connected []Connection
	for _, c := range conns {
		if c.Status != "connected" {
			continue
		}
		connected = append(connected, c)
		if k := strings.TrimSpace(c.AppKey); k != "" && !contains(apps, k) {
			apps = append(apps, k)
		}
	}
	return apps, connected
}

// ToolDefinitions are the tool definitions the agent gets: every tool of the
// connected apps of providers that are set up, each tagged with its
// integration.
func (m *Manager) ToolDefinitions(ctx context.Context, userID int64, agentID string) ([]json.RawMessage, error) {
	agentID, err := m.agent(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	var out []json.RawMessage
	for _, p := range m.providers {
		info := p.Info()
		if !p.EnvStatus(Scope{UserID: userID, AgentID: agentID}).Configured {
			continue
		}
		rows, err := m.svc.ListConnections(ctx, userID, info.Key, agentID)
		if err != nil {
			return nil, err
		}
		apps, connected := connectedApps(rows)
		if len(apps) == 0 {
			continue
		}
		for _, t := range p.Tools(apps, connected) {
			out = append(out, t.WithIntegration(info.Key))
		}
	}
	return out, nil
}

// ProviderToolDefinitions are every tool a provider offers, whatever the owner
// connected. Public runs narrow this to their own allowlist.
func (m *Manager) ProviderToolDefinitions(providerKey string) []json.RawMessage {
	p := m.Provider(providerKey)
	if p == nil {
		return nil
	}
	var ids []string
	for _, a := range p.Info().Apps {
		ids = append(ids, a.ID)
	}
	var out []json.RawMessage
	for _, t := range p.Tools(ids, nil) {
		out = append(out, t.WithIntegration(p.Info().Key))
	}
	return out
}

// ToolStatusApp is one app in ToolStatus.
type ToolStatusApp struct {
	ID           string `json:"id"`
	Label        string `json:"label"`
	AccountCount int    `json:"accountCount"`
	ToolCount    int    `json:"toolCount"`
}

// ToolStatus says which tools a provider currently offers.
type ToolStatus struct {
	Provider   string             `json:"provider"`
	Connection ProviderConnection `json:"connection"`
	Apps       []ToolStatusApp    `json:"apps"`
	ToolCount  int                `json:"toolCount"`
	Tools      []string           `json:"tools"`
}

func (m *Manager) ToolStatus(ctx context.Context, userID int64, providerKey, agentID string) (*ToolStatus, error) {
	agentID, err := m.agent(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	p := m.Provider(providerKey)
	if p == nil {
		return nil, m.unknownProvider(providerKey)
	}
	scope := Scope{UserID: userID, AgentID: agentID}
	env := p.EnvStatus(scope)
	rows, err := m.svc.ListConnections(ctx, userID, p.Info().Key, agentID)
	if err != nil {
		return nil, err
	}
	snap := p.Snapshot(rows, scope)
	var ids []string
	status := &ToolStatus{Provider: p.Info().Key, Connection: snap.Connection, Apps: []ToolStatusApp{}, Tools: []string{}}
	for _, app := range snap.Apps {
		if app.Connection.Connected {
			ids = append(ids, app.ID)
		}
		status.Apps = append(status.Apps, ToolStatusApp{ID: app.ID, Label: app.Label, AccountCount: app.Connection.AccountCount, ToolCount: app.AvailableToolCount})
	}
	if env.Configured && len(ids) > 0 {
		_, connected := connectedApps(rows)
		if connected == nil {
			connected = []Connection{}
		}
		for _, t := range p.Tools(ids, connected) {
			status.Tools = append(status.Tools, t.Name)
		}
	}
	status.ToolCount = len(status.Tools)
	return status, nil
}

// ToolFailure is the result of a tool call that could not run. The field order
// is the order the model has always seen.
type ToolFailure struct {
	Error             string  `json:"error"`
	Expired           bool    `json:"expired,omitempty"`
	ConnectionID      int64   `json:"connectionId,omitempty"`
	Status            int     `json:"status,omitempty"`
	RetryAfterSeconds float64 `json:"retryAfterSeconds,omitempty"`
	Next              string  `json:"next,omitempty"`
}

// failureGuidance says what can be done about a failed call, from the status
// the service gave. Without it a refused call reads like a puzzle: the agent
// tried to do the same thing in the shell, which sent it looking for
// credentials it never has.
func failureGuidance(status int) string {
	switch {
	case status == 401 || status == 403:
		return "The service refused this account. Only the owner can change that, in the account or its organization; " +
			"connected accounts' credentials are never available to you, so tell the owner what was refused."
	case status == 404:
		return "Nothing by those names or IDs: check them before trying again."
	case status == 429 || status >= 500:
		return "The service is busy or failing; it may work later."
	}
	return ""
}

// PublicScope pins a run to the one account connected for its platform.
type PublicScope struct{ ProviderKey, AppKey string }

// ExecOptions tune ExecuteTool.
type ExecOptions struct {
	Public *PublicScope
	// Run is what started the agent run; calendar tools read it.
	Run Run
}

func (m *Manager) isWriteExecution(p Provider, name string, args map[string]any) bool {
	if wc, ok := p.(WriteClassifier); ok {
		if write, decided := wc.IsWriteTool(name, args); decided {
			return write
		}
	}
	var ids []string
	for _, a := range p.Info().Apps {
		ids = append(ids, a.ID)
	}
	for _, t := range p.Tools(ids, nil) {
		if t.Name != strings.TrimSpace(name) {
			continue
		}
		switch strings.ToLower(strings.TrimSpace(t.Access)) {
		case "write":
			return true
		case "read":
			return false
		case "dynamic_http_method":
			method := ""
			for _, k := range []string{"method", "http_method"} {
				if s := jsText(args[k]); s != "" {
					method = s
					break
				}
			}
			method = strings.ToUpper(strings.TrimSpace(orDefault(method, "GET")))
			return method != "GET" && method != "HEAD" && method != "OPTIONS"
		}
		break
	}
	// No explicit access metadata means writes cannot safely be allowed in
	// read-only mode.
	return true
}

func orDefault(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

// selectConnection picks the account a tool call uses, or says why none.
func (m *Manager) selectConnection(ctx context.Context, p Provider, name string, args map[string]any, userID int64, agentID string) (*Connection, string, error) {
	info := p.Info()
	appKey := p.ToolAppID(name)
	if appKey == "" {
		return nil, fmt.Sprintf("Unable to resolve an integration app for tool %s.", name), nil
	}
	appLabel := appKey
	if app, ok := p.App(appKey); ok && app.Label != "" {
		appLabel = app.Label
	}
	rows, err := m.svc.ListConnections(ctx, userID, info.Key, agentID)
	if err != nil {
		return nil, "", err
	}
	var conns []Connection
	for _, c := range rows {
		if c.Status == "connected" && strings.TrimSpace(c.AppKey) == appKey {
			conns = append(conns, c)
		}
	}
	if len(conns) == 0 {
		return nil, fmt.Sprintf("%s %s is not connected for this user.", info.Label, appLabel), nil
	}
	var choices []string
	for _, c := range conns {
		email := c.AccountEmail
		if email == "" {
			email = "account"
		}
		choices = append(choices, fmt.Sprintf("%s (connection_id %d)", email, c.ID))
	}
	accountChoices := strings.Join(choices, ", ")

	if id, ok := parseConnectionID(args["connection_id"]); ok {
		for i := range conns {
			if conns[i].ID == id {
				return &conns[i], "", nil
			}
		}
		return nil, fmt.Sprintf("No connected %s %s account matches connection_id %d. Connected: %s.", info.Label, appLabel, id, accountChoices), nil
	}
	if email := strings.ToLower(strings.TrimSpace(jsText(args["account_email"]))); email != "" {
		for i := range conns {
			if strings.ToLower(strings.TrimSpace(conns[i].AccountEmail)) == email {
				return &conns[i], "", nil
			}
		}
		return nil, fmt.Sprintf("No connected %s %s account matches %s. Connected: %s.", info.Label, appLabel, email, accountChoices), nil
	}
	if len(conns) == 1 {
		return &conns[0], "", nil
	}
	return nil, fmt.Sprintf("Multiple %s %s accounts are connected: %s. Re-run the tool with connection_id or account_email.", info.Label, appLabel, accountChoices), nil
}

// selectPublic is the account a public run acts as, never whichever account the
// model names.
func (m *Manager) selectPublic(ctx context.Context, p Provider, scope *PublicScope, userID int64, agentID string) (*Connection, string, error) {
	info := p.Info()
	if info.Key != scope.ProviderKey {
		return nil, info.Label + " tools are not available in this run.", nil
	}
	rows, err := m.svc.ListConnections(ctx, userID, info.Key, agentID)
	if err != nil {
		return nil, "", err
	}
	for i := range rows {
		if rows[i].Status == "connected" && strings.TrimSpace(rows[i].AppKey) == scope.AppKey {
			return &rows[i], "", nil
		}
	}
	appLabel := scope.AppKey
	if app, ok := p.App(scope.AppKey); ok && app.Label != "" {
		appLabel = app.Label
	}
	return nil, fmt.Sprintf("%s %s is not connected for this agent.", info.Label, appLabel), nil
}

func lockKey(c Connection) string {
	return fmt.Sprintf("%d:%s:%s:%s", c.UserID, c.AgentID, c.ProviderKey, strings.ToLower(strings.TrimSpace(c.AccountEmail)))
}

// ExecuteTool runs one tool call as the right account. The result is what the
// model reads: the provider's data, or a *ToolFailure. The error is only for
// cancellation and database failures.
func (m *Manager) ExecuteTool(ctx context.Context, userID int64, name string, args map[string]any, agentID string, opts ExecOptions) (any, error) {
	agentID, err := m.agent(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	if args == nil {
		args = map[string]any{}
	}
	ctx = WithRun(ctx, opts.Run)
	found := false
	for _, p := range m.providers {
		if !p.SupportsTool(name) {
			continue
		}
		found = true
		info := p.Info()
		scope := Scope{UserID: userID, AgentID: agentID}
		if env := p.EnvStatus(scope); !env.Configured {
			return &ToolFailure{Error: env.Summary}, nil
		}
		var selected *Connection
		var problem string
		if opts.Public != nil {
			selected, problem, err = m.selectPublic(ctx, p, opts.Public, userID, agentID)
		} else {
			selected, problem, err = m.selectConnection(ctx, p, name, args, userID, agentID)
		}
		if err != nil {
			return nil, err
		}
		if problem != "" {
			return &ToolFailure{Error: problem}, nil
		}
		if AccessMode(selected) == AccessReadOnly && m.isWriteExecution(p, name, args) {
			return &ToolFailure{Error: fmt.Sprintf("This %s account is set to read-only access. Change the connection access mode to read/write to allow this action.", info.Label)}, nil
		}

		stored := m.svc.Credentials(*selected)
		if info.Exclusive || info.RequiresRefreshToken || stored.String("refresh_token") != "" {
			release, err := m.locks.acquire(ctx, lockKey(*selected))
			if err != nil {
				return nil, err
			}
			defer release()
		}
		conn, err := m.svc.ConnectionByID(ctx, userID, selected.ID, agentID)
		if err != nil {
			return nil, err
		}
		if conn == nil || conn.Status != "connected" {
			return &ToolFailure{Error: fmt.Sprintf("The selected %s connection is no longer available.", info.Label)}, nil
		}

		execution, execErr := p.ExecuteTool(ctx, name, args, *conn)
		if execErr != nil {
			if ctx.Err() != nil {
				return nil, context.Cause(ctx)
			}
			return m.failure(ctx, p, *conn, agentID, execErr)
		}
		if execution == nil {
			return &ToolFailure{Error: "execution_failed"}, nil
		}
		if execution.Credentials != nil {
			merged := oauthclient.Merge(m.svc.Credentials(*conn), execution.Credentials)
			if err := m.svc.PersistSharedCredentials(ctx, userID, agentID, info.Key, conn.AccountEmail, merged); err != nil {
				return nil, err
			}
		}
		return execution.Result, nil
	}
	if found {
		return &ToolFailure{Error: "execution_failed"}, nil
	}
	return &ToolFailure{Error: "no_provider_support"}, nil
}

// failure turns a provider error into the tool result, marking the connection
// expired when the error says its grant is gone.
func (m *Manager) failure(ctx context.Context, p Provider, conn Connection, agentID string, err error) (any, error) {
	info := p.Info()
	if isLikelyExpiredConnectionError(err) {
		if _, uerr := m.svc.DB.W.ExecContext(ctx, `UPDATE integration_connections SET status = 'expired', updated_at = datetime('now')
			WHERE id = ? AND user_id = ? AND agent_id = ?`, conn.ID, conn.UserID, agentID); uerr != nil {
			return nil, uerr
		}
		return &ToolFailure{
			Error:        fmt.Sprintf("Your %s account connection has expired and needs to be reconnected. Open Official Integrations to reconnect your account.", info.Label),
			Expired:      true,
			ConnectionID: conn.ID,
		}, nil
	}
	// The status and any wait the service asked for stay with the error, so
	// the loop can tell a refusal from an outage.
	msg := err.Error()
	if msg == "" {
		msg = "execution_error"
	}
	out := &ToolFailure{Error: msg}
	var pe *oauthclient.Error
	if errors.As(err, &pe) {
		out.Status = pe.Status
		if wait, perr := strconv.ParseFloat(strings.TrimSpace(pe.Header.Get("Retry-After")), 64); perr == nil && wait > 0 {
			out.RetryAfterSeconds = wait
		}
		out.Next = failureGuidance(pe.Status)
	}
	return out, nil
}

// ---- summaries for the model -------------------------------------------------

type providerSnapshot struct {
	Provider Provider
	Snapshot Snapshot
}

func (m *Manager) connectedSnapshots(ctx context.Context, userID int64, agentID string, keys []string) ([]providerSnapshot, error) {
	agentID, err := m.agent(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	var out []providerSnapshot
	for _, p := range m.providers {
		if keys != nil && !contains(keys, p.Info().Key) {
			continue
		}
		rows, err := m.svc.ListConnections(ctx, userID, p.Info().Key, agentID)
		if err != nil {
			return nil, err
		}
		snap := p.Snapshot(rows, Scope{UserID: userID, AgentID: agentID})
		if m.hooks.DecorateSnapshot != nil {
			m.hooks.DecorateSnapshot(ctx, &snap, userID, agentID)
		}
		if snap.Connection.Connected {
			out = append(out, providerSnapshot{p, snap})
		}
	}
	return out, nil
}

// ConnectedProviderLabels is one line naming what is connected. Per-provider
// usage notes are served with the tools themselves (SummarizeConnected).
func (m *Manager) ConnectedProviderLabels(ctx context.Context, userID int64, agentID string) (string, error) {
	snaps, err := m.connectedSnapshots(ctx, userID, agentID, nil)
	if err != nil {
		return "", err
	}
	parts := make([]string, 0, len(snaps))
	for _, ps := range snaps {
		label := ps.Provider.Info().Label
		var apps []string
		for _, app := range ps.Snapshot.Apps {
			if app.Connection.Connected && app.Label != "" && app.Label != label {
				apps = append(apps, app.Label)
			}
		}
		if len(apps) > 0 {
			label += " (" + strings.Join(apps, ", ") + ")"
		}
		parts = append(parts, label)
	}
	return strings.Join(parts, ", "), nil
}

// SummarizeConnected tells the model what each connected provider offers. keys
// limits the providers; nil means all.
func (m *Manager) SummarizeConnected(ctx context.Context, userID int64, agentID string, keys []string) (string, error) {
	snaps, err := m.connectedSnapshots(ctx, userID, agentID, keys)
	if err != nil {
		return "", err
	}
	lines := make([]string, 0, len(snaps))
	for _, ps := range snaps {
		coverage := ""
		if cov, ok := ps.Snapshot.Extra["memoryCoverage"].(map[string]any); ok && cov["supported"] == true {
			domains := "none"
			if list, ok := cov["dataDomains"].([]string); ok && len(list) > 0 {
				domains = strings.Join(list, ", ")
			}
			coverage = fmt.Sprintf(" Memory ingestion: %v; domains: %s; documents: %v.", cov["status"], domains, orDefaultAny(cov["documentCount"], 0))
		}
		lines = append(lines, ps.Provider.SummarizeForModel(ps.Snapshot)+coverage)
	}
	return strings.Join(lines, "\n"), nil
}

func orDefaultAny(v any, fallback any) any {
	if v == nil {
		return fallback
	}
	return v
}

// ---- helpers -----------------------------------------------------------------

// keyedLocks serialise work per key and let a waiter give up when its context
// ends.
type keyedLocks struct {
	mu    sync.Mutex
	locks map[string]*keyedLock
}

type keyedLock struct {
	ch   chan struct{}
	refs int
}

func (k *keyedLocks) acquire(ctx context.Context, key string) (func(), error) {
	k.mu.Lock()
	if k.locks == nil {
		k.locks = map[string]*keyedLock{}
	}
	l := k.locks[key]
	if l == nil {
		l = &keyedLock{ch: make(chan struct{}, 1)}
		k.locks[key] = l
	}
	l.refs++
	k.mu.Unlock()

	drop := func() {
		k.mu.Lock()
		l.refs--
		if l.refs == 0 {
			delete(k.locks, key)
		}
		k.mu.Unlock()
	}
	select {
	case l.ch <- struct{}{}:
	case <-ctx.Done():
		drop()
		return nil, context.Cause(ctx)
	}
	var once sync.Once
	return func() {
		once.Do(func() {
			<-l.ch
			drop()
		})
	}, nil
}
