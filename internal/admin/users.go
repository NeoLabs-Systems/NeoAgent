package admin

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"math"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neolabs-go/passhash"
	"github.com/NeoLabs-Systems/neolabs-go/pwpolicy"
)

const maxModelGrants = 200

// UserRow is one account in the admin list.
type UserRow struct {
	ID              int64   `json:"id"`
	Username        string  `json:"username"`
	DisplayName     *string `json:"display_name"`
	Email           *string `json:"email"`
	EmailVerifiedAt *string `json:"email_verified_at"`
	CreatedAt       *string `json:"created_at"`
	LastLogin       *string `json:"last_login"`
	RateLimit4h     any     `json:"rate_limit_4h"`
	RateLimitWeekly any     `json:"rate_limit_weekly"`
	GrantedModels   int64   `json:"granted_models"`
	RunCount        int64   `json:"run_count"`
	StorageBytes    any     `json:"storage_bytes"`
	IsAdmin         int64   `json:"is_admin"`
	ManagedBy       *string `json:"managed_by"`
}

// ListUsers returns up to 200 accounts, newest first. A non-empty search
// matches username or email as a substring.
func (s *Store) ListUsers(ctx context.Context, search string) ([]UserRow, error) {
	var pattern any
	if search != "" {
		pattern = "%" + search + "%"
	}
	rows, err := s.DB.R.QueryContext(ctx, `
		SELECT u.id, u.username, u.display_name, u.email, u.email_verified_at,
		       u.created_at, u.last_login, u.rate_limit_4h, u.rate_limit_weekly,
		       CASE WHEN json_valid(u.allowed_models) THEN json_array_length(u.allowed_models) ELSE 0 END AS granted_models,
		       COALESCE(r.run_count,    0) AS run_count,
		       COALESCE(a.storage_bytes,0) AS storage_bytes,
		       u.is_admin,
		       manager.username AS managed_by
		FROM users u
		LEFT JOIN user_delegations d ON d.managed_user_id = u.id
		LEFT JOIN users manager ON manager.id = d.manager_user_id
		LEFT JOIN (
		  SELECT user_id, COUNT(*) AS run_count
		  FROM agent_runs GROUP BY user_id
		) r ON r.user_id = u.id
		LEFT JOIN (
		  SELECT user_id, COALESCE(SUM(byte_size),0) AS storage_bytes
		  FROM artifacts GROUP BY user_id
		) a ON a.user_id = u.id
		WHERE ? IS NULL OR u.username LIKE ? OR u.email LIKE ?
		ORDER BY u.created_at DESC LIMIT 200`, pattern, pattern, pattern)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	users := []UserRow{}
	for rows.Next() {
		var u UserRow
		if err := rows.Scan(&u.ID, &u.Username, &u.DisplayName, &u.Email, &u.EmailVerifiedAt,
			&u.CreatedAt, &u.LastLogin, &u.RateLimit4h, &u.RateLimitWeekly,
			&u.GrantedModels, &u.RunCount, &u.StorageBytes, &u.IsAdmin, &u.ManagedBy); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	return users, rows.Err()
}

type passwordResetEvent struct{}

// ResetPassword sets a new password for an account: the way back in when the
// server has no email to send a reset link. It voids any reset link still
// waiting in the inbox and audits the reset. The caller ends the account's
// sessions.
func (s *Store) ResetPassword(ctx context.Context, userID int64, password string, actor int64) error {
	var username string
	var email sql.NullString
	err := s.DB.W.QueryRowContext(ctx, `SELECT username, email FROM users WHERE id = ?`, userID).Scan(&username, &email)
	if errors.Is(err, sql.ErrNoRows) {
		return fail(404, "User not found", "USER_NOT_FOUND")
	}
	if err != nil {
		return err
	}
	if err := accounts.ValidateNewPassword(password, pwpolicy.Context{Username: username, Email: email.String}); err != nil {
		return err
	}
	hash, err := passhash.Hash(password, accounts.PasswordCost)
	if err != nil {
		return err
	}
	return s.inTx(ctx, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `UPDATE users SET password = ?, password_login_enabled = 1 WHERE id = ?`, hash, userID); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `
			UPDATE user_email_tokens SET consumed_at = datetime('now')
			WHERE user_id = ? AND type = 'password_reset' AND consumed_at IS NULL`, userID); err != nil {
			return err
		}
		return recordEvent(ctx, tx, "account.password_reset", &actor, &userID, passwordResetEvent{})
	})
}

// RateLimits are an account's token limits; nil means "use the server default"
// and 0 means unlimited. Values are whatever the column holds.
type RateLimits struct {
	FourHour any `json:"rate_limit_4h"`
	Weekly   any `json:"rate_limit_weekly"`
}

// UserRateLimits reads one account's limits.
func (s *Store) UserRateLimits(ctx context.Context, userID int64) (RateLimits, error) {
	var l RateLimits
	err := s.DB.W.QueryRowContext(ctx, `SELECT rate_limit_4h, rate_limit_weekly FROM users WHERE id = ?`, userID).Scan(&l.FourHour, &l.Weekly)
	if errors.Is(err, sql.ErrNoRows) {
		return l, fail(404, "User not found", "NOT_FOUND")
	}
	return l, err
}

// parseLimit reads a token limit: a whole number >= 0, or empty for "use the
// default". The value is nil or what to bind.
func parseLimit(v any, field string) (any, error) {
	if v == nil || v == "" {
		return nil, nil
	}
	f := jsToNumber(v)
	if !isInteger(f) || f < 0 {
		return nil, fail(400, field+" must be a whole number ≥ 0, or null.", "")
	}
	if f >= math.MaxInt64 {
		return f, nil
	}
	return int64(f), nil
}

// SetUserRateLimits stores both limits for an account. An unknown account is
// not an error, as on the Node server: the update simply matches nothing.
func (s *Store) SetUserRateLimits(ctx context.Context, userID int64, fourHour, weekly any) error {
	_, err := s.DB.W.ExecContext(ctx, `UPDATE users SET rate_limit_4h = ?, rate_limit_weekly = ? WHERE id = ?`, fourHour, weekly, userID)
	return err
}

// grantedModelIDs reads the allowed_models column: a JSON array of ids, or
// anything else meaning none.
func grantedModelIDs(raw sql.NullString) []string {
	ids := []string{}
	if !raw.Valid || raw.String == "" {
		return ids
	}
	dec := json.NewDecoder(strings.NewReader(raw.String))
	dec.UseNumber()
	var list []any
	if dec.Decode(&list) != nil || dec.More() {
		return ids
	}
	for _, item := range list {
		if id := jsTrim(jsString(item)); id != "" {
			ids = append(ids, id)
		}
	}
	return ids
}

func (s *Store) userModels(ctx context.Context, userID int64) (sql.NullString, error) {
	var raw sql.NullString
	err := s.DB.W.QueryRowContext(ctx, `SELECT allowed_models FROM users WHERE id = ?`, userID).Scan(&raw)
	if errors.Is(err, sql.ErrNoRows) {
		return raw, fail(404, "User not found", "NOT_FOUND")
	}
	return raw, err
}

// UserModelGrants lists the models granted to one account beyond the
// server-wide list.
func (s *Store) UserModelGrants(ctx context.Context, userID int64) ([]string, error) {
	raw, err := s.userModels(ctx, userID)
	if err != nil {
		return nil, err
	}
	return grantedModelIDs(raw), nil
}

type modelsChangedEvent struct {
	Granted []string `json:"granted"`
	Revoked []string `json:"revoked"`
}

// SetUserModelGrants replaces an account's granted models; nil or empty clears
// them. Every id must be one the server has discovered (catalog), so a typo
// cannot quietly grant nothing. It returns the stored list.
func (s *Store) SetUserModelGrants(ctx context.Context, userID int64, modelIDs any, actor int64, catalog []string) ([]string, error) {
	var requested []any
	if modelIDs != nil {
		list, ok := modelIDs.([]any)
		if !ok {
			return nil, fail(400, "modelIds must be an array of model ids, or null", "")
		}
		requested = list
	}
	wanted := []string{}
	seen := map[string]bool{}
	for _, item := range requested {
		if id := jsTrim(jsString(item)); id != "" && !seen[id] {
			seen[id] = true
			wanted = append(wanted, id)
		}
	}
	if len(wanted) > maxModelGrants {
		return nil, fail(400, "At most 200 models can be granted to one account", "")
	}
	known := map[string]bool{}
	for _, id := range catalog {
		known[id] = true
	}
	unknown := []string{}
	for _, id := range wanted {
		if !known[id] {
			unknown = append(unknown, id)
		}
	}
	if len(unknown) > 0 {
		if len(unknown) > 10 {
			unknown = unknown[:10]
		}
		return nil, fail(400, "Unknown model ids: "+strings.Join(unknown, ", "), "UNKNOWN_MODEL")
	}

	raw, err := s.userModels(ctx, userID)
	if err != nil {
		return nil, err
	}
	before := grantedModelIDs(raw)
	beforeSet := map[string]bool{}
	for _, id := range before {
		beforeSet[id] = true
	}
	wantedSet := map[string]bool{}
	for _, id := range wanted {
		wantedSet[id] = true
	}
	event := modelsChangedEvent{Granted: []string{}, Revoked: []string{}}
	for _, id := range wanted {
		if !beforeSet[id] {
			event.Granted = append(event.Granted, id)
		}
	}
	for _, id := range uniqueStrings(before) {
		if !wantedSet[id] {
			event.Revoked = append(event.Revoked, id)
		}
	}

	var stored any
	if len(wanted) > 0 {
		stored = jsonText(wanted)
	}
	err = s.inTx(ctx, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `UPDATE users SET allowed_models = ? WHERE id = ?`, stored, userID); err != nil {
			return err
		}
		if len(event.Granted) == 0 && len(event.Revoked) == 0 {
			return nil
		}
		return recordEvent(ctx, tx, "account.models_changed", &actor, &userID, event)
	})
	return wanted, err
}

func uniqueStrings(items []string) []string {
	seen := map[string]bool{}
	out := []string{}
	for _, item := range items {
		if !seen[item] {
			seen[item] = true
			out = append(out, item)
		}
	}
	return out
}
