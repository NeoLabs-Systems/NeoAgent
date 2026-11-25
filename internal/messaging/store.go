package messaging

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strconv"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// Agents resolves which agent a request or message is about.
type Agents interface {
	// Resolve returns the id of the agent candidate names, or the default one.
	Resolve(ctx context.Context, userID int64, candidate string) (string, error)
	IsMain(ctx context.Context, userID int64, agentID string) (bool, error)
}

// Store reads and writes the messaging rows of the shared database.
type Store struct {
	DB     *dbx.DB
	Agents Agents
}

// setting reads a setting as stored (JSON text): the agent's own row, and for
// the main agent the account-wide one.
func (s *Store) setting(ctx context.Context, userID int64, agentID, key string) (*string, error) {
	var value string
	err := s.DB.W.QueryRowContext(ctx, `SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?`, userID, agentID, key).Scan(&value)
	if err == nil {
		return &value, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return nil, err
	}
	main, err := s.Agents.IsMain(ctx, userID, agentID)
	if err != nil || !main {
		return nil, err
	}
	err = s.DB.W.QueryRowContext(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = ?`, userID, key).Scan(&value)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &value, nil
}

func (s *Store) upsertSetting(ctx context.Context, userID int64, agentID, key string, value any) error {
	raw, err := json.Marshal(value)
	if err != nil {
		return err
	}
	_, err = s.DB.W.ExecContext(ctx, `INSERT INTO agent_settings (user_id, agent_id, key, value)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`, userID, agentID, key, string(raw))
	return err
}

// UILanguage is the account's interface language, "en" when unset.
func (s *Store) UILanguage(ctx context.Context, userID int64, agentID string) string {
	raw, err := s.setting(ctx, userID, agentID, "ui_language")
	if err != nil || raw == nil {
		return "en"
	}
	var language string
	if json.Unmarshal([]byte(*raw), &language) != nil || language == "" {
		return "en"
	}
	return language
}

// LoadAccessPolicy is the stored policy of an agent on a platform, falling back
// to the older allow-list and then the default.
func (s *Store) LoadAccessPolicy(ctx context.Context, userID int64, agentID, platform string) (AccessPolicy, error) {
	policy, err := s.setting(ctx, userID, agentID, AccessPolicyKey(platform))
	if err != nil {
		return AccessPolicy{}, err
	}
	legacy, err := s.setting(ctx, userID, agentID, LegacyWhitelistKey(platform))
	if err != nil {
		return AccessPolicy{}, err
	}
	return ParseStoredAccessPolicy(platform, policy, legacy), nil
}

func formatInt(n int64) string { return strconv.FormatInt(n, 10) }
