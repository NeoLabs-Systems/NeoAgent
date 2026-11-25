package integrations

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

const connectionColumns = `id, user_id, agent_id, provider_key, app_key, status, account_email,
	scopes_json, credentials_json, metadata_json, last_connected_at, created_at, updated_at`

type scanner interface{ Scan(...any) error }

func scanConnection(sc scanner) (Connection, error) {
	var c Connection
	var agent, status, email, scopes, creds, meta, last, created, updated sql.NullString
	if err := sc.Scan(&c.ID, &c.UserID, &agent, &c.ProviderKey, &c.AppKey, &status, &email,
		&scopes, &creds, &meta, &last, &created, &updated); err != nil {
		return Connection{}, err
	}
	c.AgentID, c.Status, c.AccountEmail = agent.String, status.String, email.String
	c.ScopesJSON, c.CredentialsJSON, c.MetadataJSON = scopes.String, creds.String, meta.String
	c.LastConnectedAt, c.CreatedAt, c.UpdatedAt = last.String, created.String, updated.String
	return c, nil
}

func collectConnections(rows *sql.Rows) ([]Connection, error) {
	defer rows.Close()
	var out []Connection
	for rows.Next() {
		c, err := scanConnection(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// ListConnections are an agent's connection rows, newest first. An empty
// providerKey lists every provider.
func (s *Services) ListConnections(ctx context.Context, userID int64, providerKey, agentID string) ([]Connection, error) {
	query := `SELECT ` + connectionColumns + ` FROM integration_connections WHERE user_id = ? AND agent_id = ?`
	args := []any{userID, agentID}
	if providerKey != "" {
		query += ` AND provider_key = ?`
		args = append(args, providerKey)
	}
	rows, err := s.DB.R.QueryContext(ctx, query+` ORDER BY updated_at DESC, id DESC`, args...)
	if err != nil {
		return nil, err
	}
	return collectConnections(rows)
}

// ConnectionByID finds one of an agent's connections.
func (s *Services) ConnectionByID(ctx context.Context, userID, id int64, agentID string) (*Connection, error) {
	c, err := scanConnection(s.DB.R.QueryRowContext(ctx,
		`SELECT `+connectionColumns+` FROM integration_connections WHERE user_id = ? AND agent_id = ? AND id = ?`,
		userID, agentID, id))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &c, nil
}

// ConnectedAccount is the arguments of UpsertConnection.
type ConnectedAccount struct {
	UserID          int64
	AgentID         string
	ProviderKey     string
	AppKey          string
	AccountEmail    string
	Scopes          []string
	CredentialsJSON string // already sealed
	Metadata        map[string]any
}

func marshal(v any) (string, error) {
	raw, err := oauthclient.MarshalJS(v)
	return string(raw), err
}

// UpsertConnection writes the one row per (user, agent, provider, app,
// account), refreshing it in place when the same account reconnects.
func (s *Services) UpsertConnection(ctx context.Context, a ConnectedAccount) error {
	scopes := a.Scopes
	if scopes == nil {
		scopes = []string{}
	}
	scopesJSON, err := marshal(scopes)
	if err != nil {
		return err
	}
	meta := a.Metadata
	if meta == nil {
		meta = map[string]any{}
	}
	metaJSON, err := marshal(meta)
	if err != nil {
		return err
	}
	_, err = s.DB.W.ExecContext(ctx, `INSERT INTO integration_connections (
		user_id, agent_id, provider_key, app_key, status, account_email, scopes_json,
		credentials_json, metadata_json, last_connected_at, updated_at
	) VALUES (?, ?, ?, ?, 'connected', ?, ?, ?, ?, datetime('now'), datetime('now'))
	ON CONFLICT(user_id, agent_id, provider_key, app_key, account_email) DO UPDATE SET
		status = 'connected',
		scopes_json = excluded.scopes_json,
		credentials_json = excluded.credentials_json,
		metadata_json = excluded.metadata_json,
		last_connected_at = excluded.last_connected_at,
		updated_at = excluded.updated_at`,
		a.UserID, a.AgentID, a.ProviderKey, a.AppKey, a.AccountEmail, scopesJSON, a.CredentialsJSON, metaJSON)
	return err
}

// FindAppConnection is the row of one app of one account.
func (s *Services) FindAppConnection(ctx context.Context, userID int64, agentID, providerKey, appKey, accountEmail string) (*Connection, error) {
	c, err := scanConnection(s.DB.R.QueryRowContext(ctx, `SELECT `+connectionColumns+` FROM integration_connections
		WHERE user_id=? AND agent_id=? AND provider_key=? AND app_key=? AND account_email=?`,
		userID, agentID, providerKey, appKey, accountEmail))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &c, nil
}

// Credentials opens the stored credentials of a connection; an unreadable
// value is empty, as in Node.
func (s *Services) Credentials(conn Connection) oauthclient.Credentials {
	plain, err := s.Box.Open(conn.CredentialsJSON)
	if err != nil {
		return oauthclient.Credentials{}
	}
	return ParseCredentials(plain)
}

// ParseCredentials reads a credentials JSON object; numbers keep their text.
func ParseCredentials(plain string) oauthclient.Credentials {
	if plain == "" {
		return oauthclient.Credentials{}
	}
	dec := json.NewDecoder(strings.NewReader(plain))
	dec.UseNumber()
	var m map[string]any
	if dec.Decode(&m) != nil || m == nil {
		return oauthclient.Credentials{}
	}
	return m
}

func (s *Services) sealCredentials(c oauthclient.Credentials) (string, error) {
	if c == nil {
		c = oauthclient.Credentials{}
	}
	raw, err := marshal(c)
	if err != nil {
		return "", err
	}
	return s.Box.Seal(raw)
}

// PersistSharedCredentials stores credentials on every app row of an account:
// apps connected with one sign-in share one token.
func (s *Services) PersistSharedCredentials(ctx context.Context, userID int64, agentID, providerKey, accountEmail string, creds oauthclient.Credentials) error {
	email := strings.TrimSpace(accountEmail)
	if email == "" {
		return nil
	}
	sealed, err := s.sealCredentials(creds)
	if err != nil {
		return err
	}
	_, err = s.DB.W.ExecContext(ctx, `UPDATE integration_connections
		SET credentials_json = ?, updated_at = datetime('now')
		WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND lower(account_email) = lower(?)`,
		sealed, userID, agentID, providerKey, email)
	return err
}

// SaveRefreshedCredentials lets background collectors keep tokens they
// refreshed outside a tool call.
func (s *Services) SaveRefreshedCredentials(ctx context.Context, conn Connection, updated oauthclient.Credentials) error {
	if updated == nil {
		return nil
	}
	return s.PersistSharedCredentials(ctx, conn.UserID, conn.AgentID, conn.ProviderKey, conn.AccountEmail,
		oauthclient.Merge(s.Credentials(conn), updated))
}

// ---- OAuth redirect states ---------------------------------------------------

// OAuthState is a row of integration_oauth_states.
type OAuthState struct {
	UserID       int64
	AgentID      string
	ProviderKey  string
	AppKey       string
	State        string
	CodeVerifier string // sealed
	MemorySweep  bool
}

func (s *Services) cleanupExpiredStates(ctx context.Context) error {
	_, err := s.DB.W.ExecContext(ctx, `DELETE FROM integration_oauth_states WHERE datetime(expires_at) <= datetime('now')`)
	return err
}

func (s *Services) insertState(ctx context.Context, st OAuthState, expiresAt string) error {
	sweep := 0
	if st.MemorySweep {
		sweep = 1
	}
	_, err := s.DB.W.ExecContext(ctx, `INSERT INTO integration_oauth_states (
		user_id, agent_id, provider_key, app_key, state, code_verifier, expires_at, memory_sweep
	) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		st.UserID, st.AgentID, st.ProviderKey, st.AppKey, st.State, st.CodeVerifier, expiresAt, sweep)
	return err
}

// claimState takes an unexpired state exactly once.
func (s *Services) claimState(ctx context.Context, state string) (*OAuthState, error) {
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	var st OAuthState
	var agent sql.NullString
	var sweep sql.NullInt64
	err = tx.QueryRowContext(ctx, `SELECT user_id, agent_id, provider_key, app_key, state, code_verifier, memory_sweep
		FROM integration_oauth_states WHERE state = ? AND datetime(expires_at) > datetime('now')`, state).
		Scan(&st.UserID, &agent, &st.ProviderKey, &st.AppKey, &st.State, &st.CodeVerifier, &sweep)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	st.AgentID, st.MemorySweep = agent.String, sweep.Int64 == 1
	res, err := tx.ExecContext(ctx, `DELETE FROM integration_oauth_states WHERE state = ? AND datetime(expires_at) > datetime('now')`, state)
	if err != nil {
		return nil, err
	}
	if n, _ := res.RowsAffected(); n != 1 {
		return nil, nil
	}
	return &st, tx.Commit()
}

// PendingOAuth is what a person approves when a held callback asks to confirm.
type PendingOAuth struct {
	ProviderLabel string
	AppLabel      string // empty when unknown
	Username      string
	StartedAt     string
}
