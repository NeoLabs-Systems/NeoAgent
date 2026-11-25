package accounts

import (
	"context"
	"database/sql"
	"errors"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/passhash"
	"github.com/NeoLabs-Systems/neolabs-go/pwpolicy"
	"github.com/NeoLabs-Systems/neolabs-go/servicemail"
)

// Token types stored in user_email_tokens.
const (
	TokenSignupConfirmation = "signup_confirmation"
	TokenEmailChange        = "email_change_confirmation"
	TokenPasswordReset      = "password_reset"
)

// Confirmed is the result of following a confirmation link.
type Confirmed struct {
	Type          string
	Email         string
	PreviousEmail string
	UserID        int64
	Username      string
}

// ConsumeEmailToken applies a confirmation link: it verifies the signup email or
// switches the account to the new address.
func (r *Repo) ConsumeEmailToken(ctx context.Context, tk servicemail.Tokens, token string) (*Confirmed, error) {
	row, err := tk.Find(ctx, r.DB.W, token, "")
	if err != nil {
		return nil, err
	}
	if row == nil {
		return nil, fail(400, "Email confirmation link is invalid or expired", "")
	}
	tx, err := r.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	switch row.Type {
	case TokenSignupConfirmation:
		if _, err := tx.ExecContext(ctx, `UPDATE users SET email_verified_at = datetime('now') WHERE id = ? AND lower(email) = lower(?)`, row.UserID, row.Email); err != nil {
			return nil, err
		}
		if _, err := tx.ExecContext(ctx, `UPDATE user_email_tokens SET consumed_at = datetime('now') WHERE id = ?`, row.ID); err != nil {
			return nil, err
		}
	case TokenEmailChange:
		var one int
		err := tx.QueryRowContext(ctx, `SELECT id FROM users WHERE lower(email) = lower(?) AND id != ?`, row.Email, row.UserID).Scan(&one)
		if err == nil {
			return nil, fail(409, "Email is already in use", "")
		}
		if !errors.Is(err, sql.ErrNoRows) {
			return nil, err
		}
		if _, err := tx.ExecContext(ctx, `UPDATE users SET email = ?, email_verified_at = datetime('now') WHERE id = ?`, row.Email, row.UserID); err != nil {
			return nil, err
		}
		if _, err := tx.ExecContext(ctx, `UPDATE user_email_tokens SET consumed_at = datetime('now')
			WHERE user_id = ? AND type = 'email_change_confirmation' AND consumed_at IS NULL`, row.UserID); err != nil {
			return nil, err
		}
	default:
		return nil, fail(400, "Unsupported email confirmation type", "")
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return &Confirmed{Type: row.Type, Email: row.Email, PreviousEmail: row.CurrentEmail.String, UserID: row.UserID, Username: row.Username}, nil
}

// Reset is the account whose password was reset.
type Reset struct {
	UserID   int64
	Username string
	Email    string
}

func invalidResetLink() error { return fail(400, "Password reset link is invalid or expired", "") }

// ConsumePasswordReset sets a new password if the link is still live. The
// password is checked against the account's own username and email, like at
// sign-up, and wrong links are counted per link so one cannot be brute-forced.
func (r *Repo) ConsumePasswordReset(ctx context.Context, tk servicemail.Tokens, limiter *servicemail.AttemptLimiter, token, password string) (*Reset, error) {
	key := passhash.DigestToken(token)
	if err := limiter.Allowed(key); err != nil {
		return nil, fail(429, err.Error(), "")
	}
	row, err := tk.Find(ctx, r.DB.W, token, TokenPasswordReset)
	if err != nil {
		return nil, err
	}
	if row == nil {
		limiter.Register(key)
		return nil, invalidResetLink()
	}
	if err := ValidateNewPassword(password, pwpolicy.Context{Username: row.Username, Email: row.CurrentEmail.String}); err != nil {
		return nil, err
	}
	hash, err := passhash.Hash(password, PasswordCost)
	if err != nil {
		return nil, err
	}
	// The link is claimed inside the write so two submissions racing past the
	// lookup cannot both set a password.
	tx, err := r.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	res, err := tx.ExecContext(ctx, `UPDATE user_email_tokens SET consumed_at = datetime('now') WHERE id = ? AND consumed_at IS NULL`, row.ID)
	if err != nil {
		return nil, err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return nil, invalidResetLink()
	}
	if _, err := tx.ExecContext(ctx, `UPDATE users SET password = ?, password_login_enabled = 1 WHERE id = ?`, hash, row.UserID); err != nil {
		return nil, err
	}
	if _, err := tx.ExecContext(ctx, `UPDATE user_email_tokens SET consumed_at = datetime('now')
		WHERE user_id = ? AND type = 'password_reset' AND consumed_at IS NULL`, row.UserID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	limiter.Reset(key)
	return &Reset{UserID: row.UserID, Username: row.Username, Email: row.CurrentEmail.String}, nil
}

// ForPasswordReset finds the account a reset request names (username or email,
// any case) when it has an email address to send to.
func (r *Repo) ForPasswordReset(ctx context.Context, account string) (*Reset, error) {
	a := strings.ToLower(strings.TrimSpace(account))
	if a == "" {
		return nil, nil
	}
	var u Reset
	err := r.DB.R.QueryRowContext(ctx, `SELECT id, username, email FROM users
		WHERE email IS NOT NULL AND trim(email) != '' AND (lower(username) = ? OR lower(email) = ?)`, a, a).Scan(&u.UserID, &u.Username, &u.Email)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return &u, err
}

// EmailUsedByOther reports whether another account already uses the address.
func (r *Repo) EmailUsedByOther(ctx context.Context, email string, userID int64) (bool, error) {
	var one int
	err := r.DB.R.QueryRowContext(ctx, `SELECT id FROM users WHERE lower(email) = ? AND id != ?`, strings.ToLower(email), userID).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

// SetEmail switches the address and marks it verified.
func (r *Repo) SetEmail(ctx context.Context, userID int64, email string) error {
	_, err := r.DB.W.ExecContext(ctx, `UPDATE users SET email = ?, email_verified_at = datetime('now') WHERE id = ?`, email, userID)
	return err
}

// Discard removes an account that never became usable (its confirmation email
// could not be sent) and gives its sign-up key back.
func (r *Repo) Discard(ctx context.Context, userID int64) error {
	tx, err := r.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for _, q := range []string{
		`UPDATE signup_keys SET used_at = NULL, used_by_user_id = NULL WHERE used_by_user_id = ?`,
		`DELETE FROM user_email_tokens WHERE user_id = ?`,
		`DELETE FROM users WHERE id = ?`,
	} {
		if _, err := tx.ExecContext(ctx, q, userID); err != nil {
			return err
		}
	}
	return tx.Commit()
}
