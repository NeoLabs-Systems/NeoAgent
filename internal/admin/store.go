// Package admin is NeoAgent's admin and access domain: the /api/admin routes,
// admin grants and the access audit log, sign-up keys, per-account limits and
// model grants, and the server settings the admin page edits. It reads and
// writes the same tables, .env keys and JSON shapes as the Node server.
package admin

import (
	"context"
	"database/sql"
	"errors"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// Store is the admin domain's database access.
type Store struct {
	DB *dbx.DB
}

func fail(status int, message, code string) *accounts.Error {
	return &accounts.Error{Status: status, Message: message, Code: code}
}

func (s *Store) inTx(ctx context.Context, fn func(tx *sql.Tx) error) error {
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit()
}

type execer interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

// recordEvent appends to access_audit_log. Every change to who is admin, and
// admin actions taken on someone else's account, land here. Rows keep user ids
// only, so the log survives account deletion without personal data.
func recordEvent(ctx context.Context, q execer, action string, actor, subject *int64, detail any) error {
	_, err := q.ExecContext(ctx, `
		INSERT INTO access_audit_log (action, actor_user_id, subject_user_id, detail_json)
		VALUES (?, ?, ?, ?)`, action, actor, subject, jsonText(detail))
	return err
}

// Admin is an account that holds the admin flag.
type Admin struct {
	ID       int64  `json:"id"`
	Username string `json:"username"`
}

// ListAdmins returns every admin account, oldest first.
func (s *Store) ListAdmins(ctx context.Context) ([]Admin, error) {
	rows, err := s.DB.R.QueryContext(ctx, `SELECT id, username FROM users WHERE is_admin = 1 ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	admins := []Admin{}
	for rows.Next() {
		var a Admin
		if err := rows.Scan(&a.ID, &a.Username); err != nil {
			return nil, err
		}
		admins = append(admins, a)
	}
	return admins, rows.Err()
}

// GrantResult tells which account a grant or revoke touched and whether the
// flag actually changed.
type GrantResult struct {
	Username string
	Changed  bool
}

type grantEvent struct {
	Source string `json:"source"`
}

func (s *Store) findAccount(ctx context.Context, username string) (id int64, name string, admin bool, err error) {
	name = jsTrim(username)
	var flag sql.NullInt64
	err = s.DB.W.QueryRowContext(ctx, `SELECT id, username, is_admin FROM users WHERE username = ?`, name).Scan(&id, &name, &flag)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, "", false, fail(404, `No account named "`+jsTrim(username)+`".`, "NOT_FOUND")
	}
	return id, name, flag.Int64 == 1, err
}

// GrantAdmin gives an account the admin flag and audits it. The operator
// drives this (the `neoagent admin` command or NEOAGENT_ADMIN_USERS), never an
// HTTP route. source says which of them it was.
func (s *Store) GrantAdmin(ctx context.Context, username, source string) (GrantResult, error) {
	return s.setAdmin(ctx, username, source, true)
}

// RevokeAdmin removes the admin flag and audits it.
func (s *Store) RevokeAdmin(ctx context.Context, username, source string) (GrantResult, error) {
	return s.setAdmin(ctx, username, source, false)
}

func (s *Store) setAdmin(ctx context.Context, username, source string, grant bool) (GrantResult, error) {
	id, name, isAdmin, err := s.findAccount(ctx, username)
	if err != nil {
		return GrantResult{}, err
	}
	if isAdmin == grant {
		return GrantResult{Username: name}, nil
	}
	action, flag := "admin.revoke", 0
	if grant {
		action, flag = "admin.grant", 1
	}
	err = s.inTx(ctx, func(tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `UPDATE users SET is_admin = ? WHERE id = ?`, flag, id); err != nil {
			return err
		}
		return recordEvent(ctx, tx, action, nil, &id, grantEvent{Source: source})
	})
	return GrantResult{Username: name, Changed: err == nil}, err
}

// EnvGrants is what applying NEOAGENT_ADMIN_USERS did, name by name.
type EnvGrants struct {
	Granted []string
	Missing []string
	Revoked []string // left alone: the operator revoked these accounts
}

// ApplyEnvAdminGrants grants admin to every listed username. It is additive:
// dropping a name from the list does not revoke it (use RevokeAdmin), and an
// account the operator revoked stays revoked until granted explicitly.
func (s *Store) ApplyEnvAdminGrants(ctx context.Context, usernames []string) (EnvGrants, error) {
	out := EnvGrants{Granted: []string{}, Missing: []string{}, Revoked: []string{}}
	for _, name := range usernames {
		var id int64
		var flag sql.NullInt64
		err := s.DB.W.QueryRowContext(ctx, `SELECT id, is_admin FROM users WHERE username = ?`, name).Scan(&id, &flag)
		if errors.Is(err, sql.ErrNoRows) {
			out.Missing = append(out.Missing, name)
			continue
		}
		if err != nil {
			return out, err
		}
		if flag.Int64 != 1 {
			revoked, err := s.revokedByOperator(ctx, id)
			if err != nil {
				return out, err
			}
			if revoked {
				out.Revoked = append(out.Revoked, name)
				continue
			}
		}
		res, err := s.GrantAdmin(ctx, name, "env")
		if err != nil {
			return out, err
		}
		if res.Changed {
			out.Granted = append(out.Granted, name)
		}
	}
	return out, nil
}

func (s *Store) revokedByOperator(ctx context.Context, userID int64) (bool, error) {
	var action string
	err := s.DB.W.QueryRowContext(ctx, `
		SELECT action FROM access_audit_log
		WHERE subject_user_id = ? AND action IN ('admin.grant', 'admin.revoke')
		ORDER BY id DESC LIMIT 1`, userID).Scan(&action)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return action == "admin.revoke", err
}

// NeedsAdminGrant is true when accounts exist but none can open the admin
// page: an install that predates per-account admin. Startup and the command
// line show a hint then.
func (s *Store) NeedsAdminGrant(ctx context.Context) (bool, error) {
	var accountsCount, admins int
	err := s.DB.W.QueryRowContext(ctx, `SELECT COUNT(*), COALESCE(SUM(is_admin), 0) FROM users`).Scan(&accountsCount, &admins)
	return accountsCount > 0 && admins == 0, err
}

// IsAdmin reads the flag fresh every time, so revoking admin locks the account
// out of the admin routes at once. Unknown accounts are not admins.
func (s *Store) IsAdmin(ctx context.Context, userID int64) bool {
	var flag sql.NullInt64
	if err := s.DB.R.QueryRowContext(ctx, `SELECT is_admin FROM users WHERE id = ?`, userID).Scan(&flag); err != nil {
		return false
	}
	return flag.Int64 == 1
}
