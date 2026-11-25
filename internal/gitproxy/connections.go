package gitproxy

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

// Connection is an agent's GitHub repository connection.
type Connection struct {
	AgentID  string
	Token    string
	ReadOnly bool
	// Login and UserID name the GitHub account the agent commits as. UserID
	// is empty when the connection does not know it.
	Login  string
	UserID string
}

// Connections finds the GitHub connection of an agent.
type Connections interface {
	// Github returns the agent's connected GitHub "repos" connection, or nil
	// when it has none.
	Github(ctx context.Context, userID int64, agentID string) (*Connection, error)
}

// DBConnections reads integration_connections.
type DBConnections struct {
	DB  *dbx.DB
	Box *secretbox.Box
}

// Github implements Connections. The newest connected row wins.
func (d DBConnections) Github(ctx context.Context, userID int64, agentID string) (*Connection, error) {
	var credentials, metadata, email sql.NullString
	err := d.DB.W.QueryRowContext(ctx, `SELECT credentials_json, metadata_json, account_email
		FROM integration_connections
		WHERE user_id = ? AND agent_id = ? AND provider_key = 'github' AND status = 'connected' AND app_key = 'repos'
		ORDER BY updated_at DESC, id DESC LIMIT 1`, userID, agentID).Scan(&credentials, &metadata, &email)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	meta := parseObject(metadata.String)
	conn := &Connection{
		AgentID:  agentID,
		Token:    d.token(credentials.String),
		ReadOnly: strings.ToLower(strings.TrimSpace(asText(meta["access_mode"]))) == "read_only",
		Login:    strings.TrimSpace(email.String),
		UserID:   asText(meta["userId"]),
	}
	return conn, nil
}

// token is the stored access token, or "" when it cannot be read.
func (d DBConnections) token(stored string) string {
	plain := "{}"
	if stored != "" {
		var err error
		if plain, err = d.Box.Open(stored); err != nil {
			return ""
		}
	}
	return asText(parseObject(plain)["access_token"])
}

func parseObject(text string) map[string]any {
	if text == "" {
		return nil
	}
	dec := json.NewDecoder(strings.NewReader(text))
	dec.UseNumber()
	var out map[string]any
	if err := dec.Decode(&out); err != nil {
		return nil
	}
	return out
}

// asText is String(value) for the JSON values a connection holds, with the
// values JavaScript treats as false (null, false, 0, "") as "".
func asText(v any) string {
	switch t := v.(type) {
	case string:
		return t
	case json.Number:
		if f, err := t.Float64(); err == nil && f == 0 {
			return ""
		}
		return t.String()
	case bool:
		if t {
			return "true"
		}
	}
	return ""
}
