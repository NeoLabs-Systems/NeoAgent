// Package accounts is NeoAgent's account store: users, sign-up keys, the second
// factor, passkeys and the per-device session records. It reads and writes the
// same tables as the Node server.
package accounts

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/apperr"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/pwpolicy"
)

// Error is a failure with the HTTP status and stable code clients branch on.
type Error = apperr.Error

func fail(status int, message, code string) *Error { return apperr.New(status, message, code) }

const MinUsernameLength = 3

// PasswordCost is the bcrypt work factor for new hashes. It is a variable only
// so tests can lower it; production always uses 12.
var PasswordCost = 12

// User is an account row.
type User struct {
	ID                     int64
	Username               string
	DisplayName            sql.NullString
	Email                  sql.NullString
	EmailVerifiedAt        sql.NullString
	Password               string
	PasswordLoginEnabled   bool
	CreatedAt              sql.NullString
	LastLogin              sql.NullString
	HasCompletedOnboarding bool
	IsAdmin                bool
}

const userColumns = `id, username, display_name, email, email_verified_at, password,
	password_login_enabled, created_at, last_login, has_completed_onboarding, is_admin`

type rowScanner interface{ Scan(dest ...any) error }

func scanUser(row rowScanner) (*User, error) {
	var u User
	var pwEnabled, onboarding, admin sql.NullInt64
	err := row.Scan(&u.ID, &u.Username, &u.DisplayName, &u.Email, &u.EmailVerifiedAt, &u.Password,
		&pwEnabled, &u.CreatedAt, &u.LastLogin, &onboarding, &admin)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	u.PasswordLoginEnabled = pwEnabled.Int64 == 1
	u.HasCompletedOnboarding = onboarding.Int64 == 1
	u.IsAdmin = admin.Int64 == 1
	return &u, nil
}

// Repo reads and writes accounts.
type Repo struct {
	DB *dbx.DB
	// OpenSignup reports whether anyone may register. It is read on every sign-up
	// so an administrator can close registration without a restart. Nil means open.
	OpenSignup func() bool
	// AdminUsers are names reserved for operator-granted admin.
	AdminUsers []string
}

func (r *Repo) signupOpen() bool { return r.OpenSignup == nil || r.OpenSignup() }

// querier is satisfied by *sql.DB and *sql.Tx.
type querier interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
}

// ByID returns an account or nil.
func (r *Repo) ByID(ctx context.Context, id int64) (*User, error) {
	return scanUser(r.DB.R.QueryRowContext(ctx, `SELECT `+userColumns+` FROM users WHERE id = ?`, id))
}

// ForSignIn resolves a username or email, ignoring case. An exact username
// match wins, so installs that still hold names differing only by case keep
// signing each of them in as before.
func (r *Repo) ForSignIn(ctx context.Context, identifier string) (*User, error) {
	v := strings.TrimSpace(identifier)
	if v == "" {
		return nil, nil
	}
	return scanUser(r.DB.R.QueryRowContext(ctx, `
		SELECT `+userColumns+` FROM users
		WHERE lower(username) = lower(?) OR lower(email) = lower(?)
		ORDER BY username = ? DESC, lower(username) = lower(?) DESC, id
		LIMIT 1`, v, v, v, v))
}

// Count is the number of accounts.
func (r *Repo) Count(ctx context.Context) (int, error) {
	var n int
	err := r.DB.R.QueryRowContext(ctx, `SELECT COUNT(*) FROM users`).Scan(&n)
	return n, err
}

// IsAdmin reads the flag fresh every time, so revoking admin locks the account
// out of admin routes immediately.
func (r *Repo) IsAdmin(ctx context.Context, id int64) bool {
	var v sql.NullInt64
	if err := r.DB.R.QueryRowContext(ctx, `SELECT is_admin FROM users WHERE id = ?`, id).Scan(&v); err != nil {
		return false
	}
	return v.Int64 == 1
}

// SignupKeyRequired reports whether a new account needs a key right now: the
// first account on an install never does.
func (r *Repo) SignupKeyRequired(ctx context.Context) (bool, error) {
	n, err := r.Count(ctx)
	if err != nil {
		return false, err
	}
	return n > 0 && !r.signupOpen(), nil
}

func usernameTaken(ctx context.Context, q querier, username string) (bool, error) {
	var one int
	err := q.QueryRowContext(ctx, `SELECT 1 FROM users WHERE lower(username) = lower(?)`, username).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (r *Repo) isReservedAdminUsername(ctx context.Context, q querier, username string) (bool, error) {
	name := strings.ToLower(strings.TrimSpace(username))
	for _, reserved := range r.AdminUsers {
		if strings.ToLower(reserved) != name {
			continue
		}
		var one int
		err := q.QueryRowContext(ctx, `SELECT 1 FROM users WHERE username = ?`, reserved).Scan(&one)
		if errors.Is(err, sql.ErrNoRows) {
			return true, nil
		}
		return false, err
	}
	return false, nil
}

// ValidateNewUsername rejects short, reserved and taken names.
func (r *Repo) ValidateNewUsername(ctx context.Context, username string) error {
	return r.validateNewUsername(ctx, r.DB.R, username)
}

func (r *Repo) validateNewUsername(ctx context.Context, q querier, username string) error {
	if len([]rune(username)) < MinUsernameLength {
		return fail(400, fmt.Sprintf("Username must be at least %d characters.", MinUsernameLength), "USERNAME_TOO_SHORT")
	}
	reserved, err := r.isReservedAdminUsername(ctx, q, username)
	if err != nil {
		return err
	}
	taken, err := usernameTaken(ctx, q, username)
	if err != nil {
		return err
	}
	if reserved || taken {
		return fail(409, "Username is already taken", "USERNAME_TAKEN")
	}
	return nil
}

func assertEmailAvailable(ctx context.Context, q querier, email string) error {
	var one int
	err := q.QueryRowContext(ctx, `SELECT 1 FROM users WHERE lower(email) = lower(?)`, email).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return nil
	}
	if err != nil {
		return err
	}
	return fail(409, "Email is already in use", "EMAIL_TAKEN")
}

// ValidateNewPassword applies the shared password policy.
func ValidateNewPassword(password string, ctx pwpolicy.Context) error {
	s := pwpolicy.Evaluate(password, ctx)
	if !s.HasMinimumLength {
		return fail(400, fmt.Sprintf("Password must be at least %d characters.", pwpolicy.MinLength), "PASSWORD_TOO_SHORT")
	}
	if !s.IsAcceptable {
		return fail(400, pwpolicy.Error(s), "PASSWORD_WEAK")
	}
	return nil
}

// NewUser is the data for a sign-up.
type NewUser struct {
	Username     string
	Email        string
	PasswordHash string
	NeedsConfirm bool // email not yet confirmed
	SignupKey    string
}

// Create inserts the account and spends the sign-up key in one transaction.
// Names are checked again inside it: hashing the password takes long enough for
// a concurrent sign-up to claim either one.
func (r *Repo) Create(ctx context.Context, n NewUser) (int64, error) {
	tx, err := r.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	if err := r.validateNewUsername(ctx, tx, n.Username); err != nil {
		return 0, err
	}
	if err := assertEmailAvailable(ctx, tx, n.Email); err != nil {
		return 0, err
	}
	res, err := tx.ExecContext(ctx, `
		INSERT INTO users (username, email, email_verified_at, password, password_login_enabled)
		VALUES (?, ?, CASE WHEN ? THEN NULL ELSE datetime('now') END, ?, 1)`,
		n.Username, n.Email, n.NeedsConfirm, n.PasswordHash)
	if err != nil {
		return 0, mapConstraint(err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		return 0, err
	}
	if err := r.redeemSignupKey(ctx, tx, n.SignupKey, id); err != nil {
		return 0, err
	}
	return id, tx.Commit()
}

// mapConstraint turns the unique-index race loser into the same error the
// pre-checks give.
func mapConstraint(err error) error {
	msg := strings.ToLower(err.Error())
	if strings.Contains(msg, "constraint") {
		if strings.Contains(msg, "email") {
			return fail(409, "Email is already in use", "EMAIL_TAKEN")
		}
		return fail(409, "Username is already taken", "USERNAME_TAKEN")
	}
	return err
}

// Delete removes an account that never became usable.
func (r *Repo) Delete(ctx context.Context, id int64) error {
	_, err := r.DB.W.ExecContext(ctx, `DELETE FROM users WHERE id = ?`, id)
	return err
}

// TouchLastLogin records a sign-in. A failure here must never block the login.
func (r *Repo) TouchLastLogin(ctx context.Context, id int64) error {
	_, err := r.DB.W.ExecContext(ctx, `UPDATE users SET last_login = datetime('now') WHERE id = ?`, id)
	return err
}

// CompleteOnboarding marks the first-run tour as done.
func (r *Repo) CompleteOnboarding(ctx context.Context, id int64) error {
	_, err := r.DB.W.ExecContext(ctx, `UPDATE users SET has_completed_onboarding = 1 WHERE id = ?`, id)
	return err
}

// SetDisplayName stores a display name; empty clears it.
func (r *Repo) SetDisplayName(ctx context.Context, id int64, name string) error {
	var v any
	if name != "" {
		v = name
	}
	_, err := r.DB.W.ExecContext(ctx, `UPDATE users SET display_name = ? WHERE id = ?`, v, id)
	return err
}

// SetPassword stores a new password hash and enables password sign-in.
func (r *Repo) SetPassword(ctx context.Context, id int64, hash string) error {
	_, err := r.DB.W.ExecContext(ctx, `UPDATE users SET password = ?, password_login_enabled = 1 WHERE id = ?`, hash, id)
	return err
}

// DataSharing is the opt-in usage-sharing consent kept in user_settings.
type DataSharing struct {
	Enabled bool            `json:"enabled"`
	Since   *string         `json:"since"`
	Client  json.RawMessage `json:"client"`
}

// DataSharing reads the consent record. Everything but `enabled` is only
// reported while sharing is on.
func (r *Repo) DataSharing(ctx context.Context, id int64) DataSharing {
	out := DataSharing{Client: json.RawMessage("null")}
	var raw string
	if err := r.DB.R.QueryRowContext(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = 'usage_data_sharing'`, id).Scan(&raw); err != nil {
		return out
	}
	var rec struct {
		Enabled bool            `json:"enabled"`
		Since   *string         `json:"since"`
		Client  json.RawMessage `json:"client"`
	}
	if json.Unmarshal([]byte(raw), &rec) != nil || !rec.Enabled {
		return out
	}
	out.Enabled, out.Since = true, rec.Since
	if len(rec.Client) > 0 && string(rec.Client) != "null" {
		out.Client = rec.Client
	}
	return out
}
