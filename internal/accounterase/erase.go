// Package accounterase exports and erases one account's data: the GDPR data
// portability download (GET /api/account/export) and the account deletion
// (POST /api/account/delete). It works from the live schema, like the Node
// server's services/account/erasure.js: every table with a user_id column is
// exported or cleared, so a table added later is covered without a code change.
package accounterase

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// Sentinel errors for an id that cannot be an account and an account that does
// not exist.
var (
	ErrInvalidID = errors.New("Invalid user id")
	ErrNotFound  = errors.New("User not found")
)

// RuntimeKiller stops a user's cloud computer and deletes its persisted state.
type RuntimeKiller interface {
	KillUserRuntime(userID string) error
}

// SessionPurger ends every session of an account (sessionx.Store satisfies it).
type SessionPurger interface {
	DestroyForUser(ctx context.Context, userID string) error
}

// Eraser removes and exports account data.
type Eraser struct {
	DB *dbx.DB
	// DataDir holds artifacts/ ; AgentDataDir holds workspaces/.
	DataDir      string
	AgentDataDir string
	Sessions     SessionPurger
	// Runtime is optional; without it no cloud computer is stopped.
	Runtime RuntimeKiller
	Log     *slog.Logger
}

// sensitiveColumn marks credential columns that a portability export redacts.
var sensitiveColumn = regexp.MustCompile(`(?i)pass|secret|token|hash|cipher|encrypt|_iv$|nonce|totp|recovery|priv(ate)?_?key|api_?key|credential`)

func quote(name string) string { return `"` + strings.ReplaceAll(name, `"`, `""`) + `"` }

// userScopedTables lists the tables that have a user_id column, in schema
// order. Names come from sqlite_master, never from user input.
func (e *Eraser) userScopedTables(ctx context.Context) ([]string, error) {
	rows, err := e.DB.W.QueryContext(ctx, `SELECT name FROM sqlite_master WHERE type = 'table'`)
	if err != nil {
		return nil, err
	}
	var names []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			rows.Close()
			return nil, err
		}
		names = append(names, name)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}

	var tables []string
	for _, name := range names {
		if name == "users" || strings.HasPrefix(name, "sqlite_") {
			continue
		}
		has, err := e.hasUserID(ctx, name)
		if err != nil {
			continue // unreadable (virtual) table: skipped, as Node did
		}
		if has {
			tables = append(tables, name)
		}
	}
	return tables, nil
}

func (e *Eraser) hasUserID(ctx context.Context, table string) (bool, error) {
	rows, err := e.DB.W.QueryContext(ctx, `SELECT name FROM pragma_table_info(?)`, table)
	if err != nil {
		return false, err
	}
	defer rows.Close()
	for rows.Next() {
		var column string
		if err := rows.Scan(&column); err != nil {
			return false, err
		}
		if column == "user_id" {
			return true, nil
		}
	}
	return false, rows.Err()
}

// Erase permanently deletes an account and everything it owns: database rows,
// artifact files, the workspace, sessions and the cloud computer. It returns
// the number of user-scoped tables cleared.
func (e *Eraser) Erase(ctx context.Context, userID int64) (int, error) {
	if userID <= 0 {
		return 0, ErrInvalidID
	}
	var exists int64
	switch err := e.DB.W.QueryRowContext(ctx, `SELECT id FROM users WHERE id = ?`, userID).Scan(&exists); {
	case errors.Is(err, sql.ErrNoRows):
		return 0, ErrNotFound
	case err != nil:
		return 0, err
	}

	artifactPaths := e.artifactPaths(ctx, userID)
	tables, err := e.userScopedTables(ctx)
	if err != nil {
		return 0, err
	}
	if err := e.eraseRows(ctx, userID, tables); err != nil {
		return 0, err
	}

	// Off-database state is best effort, like Node.
	e.removeArtifacts(userID, artifactPaths)
	e.removeWorkspace(userID)
	if e.Sessions != nil {
		if err := e.Sessions.DestroyForUser(ctx, strconv.FormatInt(userID, 10)); err != nil {
			e.warn("session purge failed", err)
		}
	}
	if e.Runtime != nil {
		go func() {
			if err := e.Runtime.KillUserRuntime(strconv.FormatInt(userID, 10)); err != nil {
				e.warn("runtime teardown failed", err)
			}
		}()
	}
	return len(tables), nil
}

func (e *Eraser) warn(msg string, err error) {
	if e.Log != nil {
		e.Log.Warn("account erasure: "+msg, "error", err)
	}
}

func (e *Eraser) eraseRows(ctx context.Context, uid int64, tables []string) error {
	tx, err := e.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if err := retireManager(ctx, tx, uid); err != nil {
		return err
	}
	// Child tables keyed by a parent id; a table missing on an older schema is
	// skipped.
	for _, stmt := range []string{
		`DELETE FROM conversation_messages WHERE conversation_id IN (SELECT id FROM conversations WHERE user_id = ?)`,
		`DELETE FROM agent_steps WHERE run_id IN (SELECT id FROM agent_runs WHERE user_id = ?)`,
		`DELETE FROM memory_source_links WHERE memory_id IN (SELECT id FROM memories WHERE user_id = ?)`,
	} {
		if _, err := tx.ExecContext(ctx, stmt, uid); err != nil && !strings.Contains(err.Error(), "no such table") {
			return err
		}
	}
	for _, table := range tables {
		if _, err := tx.ExecContext(ctx, `DELETE FROM `+quote(table)+` WHERE user_id = ?`, uid); err != nil {
			return fmt.Errorf("clear %s: %w", table, err)
		}
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM users WHERE id = ?`, uid); err != nil {
		return err
	}
	return tx.Commit()
}

// retireManager stops the account acting as a manager before it is deleted:
// its open invite links are revoked and the accounts it manages move up to its
// own manager (or become unmanaged when it has none). Every step is audited.
func retireManager(ctx context.Context, tx *sql.Tx, uid int64) error {
	const reason = "account_deleted"
	var upstream sql.NullInt64
	err := tx.QueryRowContext(ctx, `SELECT manager_user_id FROM user_delegations WHERE managed_user_id = ?`, uid).Scan(&upstream)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return err
	}
	res, err := tx.ExecContext(ctx, `UPDATE delegation_invites SET revoked_at = datetime('now') WHERE issuer_user_id = ? AND revoked_at IS NULL`, uid)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n > 0 {
		if err := audit(ctx, tx, "invite.revoke", uid, `{"reason":"`+reason+`","count":`+strconv.FormatInt(n, 10)+`}`); err != nil {
			return err
		}
	}

	rows, err := tx.QueryContext(ctx, `SELECT managed_user_id FROM user_delegations WHERE manager_user_id = ? ORDER BY created_at`, uid)
	if err != nil {
		return err
	}
	var managed []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return err
		}
		managed = append(managed, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}
	for _, id := range managed {
		if !upstream.Valid {
			if _, err := tx.ExecContext(ctx, `DELETE FROM user_delegations WHERE managed_user_id = ?`, id); err != nil {
				return err
			}
			detail := fmt.Sprintf(`{"managerUserId":%d,"reason":"%s"}`, uid, reason)
			if err := audit(ctx, tx, "delegation.release", id, detail); err != nil {
				return err
			}
			continue
		}
		if _, err := tx.ExecContext(ctx, `UPDATE user_delegations SET manager_user_id = ? WHERE managed_user_id = ?`, upstream.Int64, id); err != nil {
			return err
		}
		detail := fmt.Sprintf(`{"fromManagerUserId":%d,"toManagerUserId":%d,"reason":"%s"}`, uid, upstream.Int64, reason)
		if err := audit(ctx, tx, "delegation.reattach", id, detail); err != nil {
			return err
		}
	}
	return nil
}

func audit(ctx context.Context, tx *sql.Tx, action string, subject int64, detail string) error {
	_, err := tx.ExecContext(ctx, `INSERT INTO access_audit_log (action, actor_user_id, subject_user_id, detail_json) VALUES (?, NULL, ?, ?)`, action, subject, detail)
	return err
}

func (e *Eraser) artifactPaths(ctx context.Context, uid int64) []string {
	rows, err := e.DB.W.QueryContext(ctx, `SELECT storage_path FROM artifacts WHERE user_id = ?`, uid)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var paths []string
	for rows.Next() {
		var p sql.NullString
		if rows.Scan(&p) == nil && p.String != "" {
			paths = append(paths, p.String)
		}
	}
	return paths
}

// removeArtifacts deletes the account's artifact files. Everything is confined
// to <DataDir>/artifacts with os.Root, so a stored path cannot reach outside
// it, symlinks included.
func (e *Eraser) removeArtifacts(uid int64, storagePaths []string) {
	base, err := filepath.Abs(filepath.Join(e.DataDir, "artifacts"))
	if err != nil {
		return
	}
	root, err := os.OpenRoot(base)
	if err != nil {
		return
	}
	defer root.Close()
	for _, p := range storagePaths {
		if !filepath.IsAbs(p) {
			p = filepath.Join(e.DataDir, p)
		}
		rel, err := filepath.Rel(base, filepath.Clean(p))
		if err != nil || rel == "." || !filepath.IsLocal(rel) {
			continue
		}
		if err := root.Remove(rel); err != nil && !errors.Is(err, fs.ErrNotExist) {
			e.warn("artifact file", err)
		}
	}
	if err := root.RemoveAll(strconv.FormatInt(uid, 10)); err != nil {
		e.warn("artifact directory", err)
	}
}

var workspaceJunk = regexp.MustCompile(`[^a-z0-9_-]+`)

// workspaceKey is the directory name a user's workspace lives under (Node's
// sanitizeWorkspaceKey).
func workspaceKey(userID int64) string {
	key := strings.Trim(workspaceJunk.ReplaceAllString(strings.ToLower(strconv.FormatInt(userID, 10)), "-"), "-")
	if len(key) > 64 {
		key = key[:64]
	}
	if key == "" {
		return "default"
	}
	return key
}

func (e *Eraser) removeWorkspace(uid int64) {
	base, err := filepath.Abs(filepath.Join(e.AgentDataDir, "workspaces"))
	if err != nil {
		return
	}
	root, err := os.OpenRoot(base)
	if err != nil {
		return
	}
	defer root.Close()
	if err := root.RemoveAll(workspaceKey(uid)); err != nil {
		e.warn("workspace", err)
	}
}
