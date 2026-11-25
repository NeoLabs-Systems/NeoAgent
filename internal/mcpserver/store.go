package mcpserver

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"regexp"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

// Row is one mcp_servers row.
type Row struct {
	ID      int64
	UserID  int64
	AgentID string // "" when the row has no agent
	Name    string
	Command string
	Config  string
	Enabled bool
	Status  string
}

// Store reads and writes mcp_servers. Secrets inside a server's config are
// sealed at rest; the API and the connection code see them in the clear.
type Store struct {
	DB  *dbx.DB
	Box *secretbox.Box // nil stores config unsealed (tests)
}

const rowColumns = `id, user_id, agent_id, name, command, config, enabled, status`

type scanner interface{ Scan(...any) error }

func scanRow(s scanner) (Row, error) {
	var r Row
	var agent, config, status sql.NullString
	var enabled sql.NullInt64
	if err := s.Scan(&r.ID, &r.UserID, &agent, &r.Name, &r.Command, &config, &enabled, &status); err != nil {
		return Row{}, err
	}
	r.AgentID, r.Config, r.Status = agent.String, config.String, status.String
	r.Enabled = enabled.Int64 != 0
	return r, nil
}

func (s *Store) rows(ctx context.Context, query string, args ...any) ([]Row, error) {
	res, err := s.DB.W.QueryContext(ctx, `SELECT `+rowColumns+` FROM mcp_servers `+query, args...)
	if err != nil {
		return nil, err
	}
	defer res.Close()
	var out []Row
	for res.Next() {
		r, err := scanRow(res)
		if err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, res.Err()
}

// ForAgent lists the servers of an agent by name. The main agent also sees
// servers that predate agents (no agent id).
func (s *Store) ForAgent(ctx context.Context, userID int64, agentID string, includeLegacy bool) ([]Row, error) {
	if includeLegacy {
		return s.rows(ctx, `WHERE user_id = ? AND (agent_id = ? OR agent_id IS NULL) ORDER BY name ASC`, userID, agentID)
	}
	return s.rows(ctx, `WHERE user_id = ? AND agent_id = ? ORDER BY name ASC`, userID, agentID)
}

// Enabled lists the servers of an account that should be running.
func (s *Store) Enabled(ctx context.Context, userID int64) ([]Row, error) {
	return s.rows(ctx, `WHERE user_id = ? AND enabled = 1`, userID)
}

// Owned finds a server by the id as written in a URL; the account must own it.
func (s *Store) Owned(ctx context.Context, userID int64, id string) (Row, bool, error) {
	rs, err := s.rows(ctx, `WHERE id = ? AND user_id = ?`, id, userID)
	if err != nil || len(rs) == 0 {
		return Row{}, false, err
	}
	return rs[0], true, nil
}

// OwnedBy finds a server of an agent (the legacy rows without agent do not match).
func (s *Store) OwnedBy(ctx context.Context, userID int64, id any, agentID string) (bool, error) {
	var n int
	err := s.DB.W.QueryRowContext(ctx, `SELECT COUNT(*) FROM mcp_servers WHERE id = ? AND user_id = ? AND agent_id = ?`, id, userID, agentID).Scan(&n)
	return n > 0, err
}

// Enabledrow returns a server that is still enabled.
func (s *Store) enabledRow(ctx context.Context, id int64) (Row, bool, error) {
	rs, err := s.rows(ctx, `WHERE id = ? AND enabled = 1`, id)
	if err != nil || len(rs) == 0 {
		return Row{}, false, err
	}
	return rs[0], true, nil
}

// Insert adds a server and returns its id.
func (s *Store) Insert(ctx context.Context, userID int64, agentID, name, command string, config map[string]any, enabled bool) (int64, error) {
	sealed, err := s.encodeConfig(config)
	if err != nil {
		return 0, err
	}
	res, err := s.DB.W.ExecContext(ctx, `INSERT INTO mcp_servers (user_id, agent_id, name, command, config, enabled) VALUES (?, ?, ?, ?, ?, ?)`,
		userID, nullable(agentID), name, command, sealed, boolInt(enabled))
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// Update rewrites a server and marks it stopped.
func (s *Store) Update(ctx context.Context, id int64, agentID, name, command string, config map[string]any, enabled bool) error {
	sealed, err := s.encodeConfig(config)
	if err != nil {
		return err
	}
	_, err = s.DB.W.ExecContext(ctx, `UPDATE mcp_servers SET agent_id = ?, name = ?, command = ?, config = ?, enabled = ?, status = 'stopped' WHERE id = ?`,
		nullable(agentID), name, command, sealed, boolInt(enabled), id)
	return err
}

// Delete removes a server.
func (s *Store) Delete(ctx context.Context, id int64) error {
	_, err := s.DB.W.ExecContext(ctx, `DELETE FROM mcp_servers WHERE id = ?`, id)
	return err
}

func (s *Store) setStatus(ctx context.Context, id int64, status string) error {
	_, err := s.DB.W.ExecContext(ctx, `UPDATE mcp_servers SET status = ? WHERE id = ?`, status, id)
	return err
}

func nullable(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

// ServerConfig reads a server's decrypted config; a missing row or invalid
// JSON reads as empty, as in Node's `JSON.parse(row.config || '{}')`.
func (s *Store) ServerConfig(ctx context.Context, id int64) (map[string]any, error) {
	var raw sql.NullString
	err := s.DB.W.QueryRowContext(ctx, `SELECT config FROM mcp_servers WHERE id = ?`, id).Scan(&raw)
	if errors.Is(err, sql.ErrNoRows) {
		return map[string]any{}, nil
	}
	if err != nil {
		return nil, err
	}
	return s.DecodeConfig(raw.String)
}

// DecodeConfig parses and unseals a stored config.
func (s *Store) DecodeConfig(raw string) (map[string]any, error) {
	if strings.TrimSpace(raw) == "" {
		return map[string]any{}, nil
	}
	var v any
	if err := json.Unmarshal([]byte(raw), &v); err != nil {
		return nil, err
	}
	v = s.walk(v, "", false)
	m, _ := v.(map[string]any)
	if m == nil {
		return map[string]any{}, nil
	}
	return m, nil
}

func (s *Store) encodeConfig(config map[string]any) (string, error) {
	if config == nil {
		config = map[string]any{}
	}
	raw, err := json.Marshal(s.walk(config, "", true))
	return string(raw), err
}

var secretKey = regexp.MustCompile(`(?i)(^|_)(secret|token|password|api_key|private_key)($|_)`)

// sensitive says whether a string at this key (or under headers) is a secret.
func sensitive(key string, inHeaders bool) bool {
	return inHeaders || key == "codeVerifier" || secretKey.MatchString(key)
}

func (s *Store) walk(v any, key string, seal bool) any {
	return s.walkIn(v, key, false, seal)
}

func (s *Store) walkIn(v any, key string, inHeaders, seal bool) any {
	switch t := v.(type) {
	case map[string]any:
		out := make(map[string]any, len(t))
		for k, child := range t {
			out[k] = s.walkIn(child, k, inHeaders || k == "headers", seal)
		}
		return out
	case []any:
		out := make([]any, len(t))
		for i, child := range t {
			out[i] = s.walkIn(child, key, inHeaders, seal)
		}
		return out
	case string:
		if s.Box == nil || t == "" {
			return t
		}
		if seal && sensitive(key, inHeaders) {
			if sealed, err := s.Box.Seal(t); err == nil {
				return sealed
			}
			return t
		}
		if !seal {
			if plain, err := s.Box.Open(t); err == nil {
				return plain
			}
		}
	}
	return v
}

// SaveAuthState stores the digest of a pending OAuth state.
func (s *Store) SaveAuthState(ctx context.Context, id int64, state string) error {
	return s.mutateConfig(ctx, id, func(c map[string]any) bool {
		auth := authOf(c)
		auth["oauthStateHash"] = hashState(state)
		auth["oauthStateCreatedAt"] = isoNow()
		return true
	})
}

// ConsumeState checks a callback's state against the stored digest and, when it
// matches and is fresh, forgets it so it works once.
func (s *Store) ConsumeState(ctx context.Context, id int64, state string) (bool, error) {
	var raw sql.NullString
	err := s.DB.W.QueryRowContext(ctx, `SELECT config FROM mcp_servers WHERE id = ?`, id).Scan(&raw)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	var config map[string]any
	if json.Unmarshal([]byte(orBraces(raw.String)), &config) != nil || config == nil {
		return false, nil
	}
	auth, _ := config["auth"].(map[string]any)
	expected, _ := auth["oauthStateHash"].(string)
	createdStr, _ := auth["oauthStateCreatedAt"].(string)
	created, perr := time.Parse(time.RFC3339Nano, createdStr)
	now := time.Now()
	if expected == "" || perr != nil || now.Sub(created) > oauthStateTTL || created.After(now.Add(time.Minute)) {
		return false, nil
	}
	if !stateMatches(expected, state) {
		return false, nil
	}
	delete(auth, "oauthStateHash")
	delete(auth, "oauthStateCreatedAt")
	out, err := json.Marshal(config)
	if err != nil {
		return false, err
	}
	_, err = s.DB.W.ExecContext(ctx, `UPDATE mcp_servers SET config = ? WHERE id = ?`, string(out), id)
	return err == nil, err
}

// SaveTokens stores the OAuth tokens of a server.
func (s *Store) SaveTokens(ctx context.Context, id int64, tokens map[string]any) error {
	return s.mutateConfig(ctx, id, func(c map[string]any) bool {
		authOf(c)["tokens"] = tokens
		return true
	})
}

func orBraces(s string) string {
	if strings.TrimSpace(s) == "" {
		return "{}"
	}
	return s
}

func authOf(c map[string]any) map[string]any {
	auth, _ := c["auth"].(map[string]any)
	if auth == nil {
		auth = map[string]any{}
		c["auth"] = auth
	}
	return auth
}

// mutateConfig decrypts, edits and re-seals a server's config.
func (s *Store) mutateConfig(ctx context.Context, id int64, edit func(map[string]any) bool) error {
	config, err := s.ServerConfig(ctx, id)
	if err != nil {
		return err
	}
	if !edit(config) {
		return nil
	}
	sealed, err := s.encodeConfig(config)
	if err != nil {
		return err
	}
	_, err = s.DB.W.ExecContext(ctx, `UPDATE mcp_servers SET config = ? WHERE id = ?`, sealed, id)
	return err
}
