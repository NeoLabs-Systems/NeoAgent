package accounts

import (
	"context"
	"database/sql"
	"errors"
	"strconv"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/lockout"
	"github.com/NeoLabs-Systems/neolabs-go/passhash"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/totp"
)

const recoveryCodeCount = 10

// TwoFactorStatus is what the account page shows.
type TwoFactorStatus struct {
	Enabled                bool    `json:"enabled"`
	Pending                bool    `json:"pending"`
	EnabledAt              *string `json:"enabledAt"`
	RecoveryCodesRemaining int     `json:"recoveryCodesRemaining"`
}

// TwoFactor is the authenticator-app second factor.
type TwoFactor struct {
	DB      *dbx.DB
	Box     *secretbox.Box // seals the TOTP secret at rest; nil when no key is configured
	Lockout lockout.Store
	Issuer  string
	Now     func() time.Time
}

func (t *TwoFactor) now() time.Time {
	if t.Now != nil {
		return t.Now()
	}
	return time.Now()
}

type twoFactorRow struct {
	secret, pending sql.NullString
	enabled         bool
}

func (t *TwoFactor) row(ctx context.Context, userID int64) (*twoFactorRow, error) {
	var r twoFactorRow
	var enabled sql.NullInt64
	err := t.DB.R.QueryRowContext(ctx, `SELECT secret, pending_secret, enabled FROM user_two_factor WHERE user_id = ?`, userID).
		Scan(&r.secret, &r.pending, &enabled)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	r.enabled = enabled.Int64 == 1
	return &r, nil
}

// Status reports whether the factor is on, pending setup, and spare codes.
func (t *TwoFactor) Status(ctx context.Context, userID int64) (TwoFactorStatus, error) {
	var st TwoFactorStatus
	var enabled sql.NullInt64
	var pending, enabledAt sql.NullString
	err := t.DB.R.QueryRowContext(ctx, `SELECT enabled, pending_secret, enabled_at FROM user_two_factor WHERE user_id = ?`, userID).
		Scan(&enabled, &pending, &enabledAt)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return st, err
	}
	st.Enabled = enabled.Int64 == 1
	st.Pending = pending.Valid && pending.String != ""
	if enabledAt.Valid && enabledAt.String != "" {
		st.EnabledAt = &enabledAt.String
	}
	err = t.DB.R.QueryRowContext(ctx, `SELECT COUNT(*) FROM user_recovery_codes WHERE user_id = ? AND used_at IS NULL`, userID).
		Scan(&st.RecoveryCodesRemaining)
	return st, err
}

func (t *TwoFactor) box() (*secretbox.Box, error) {
	if t.Box == nil {
		return nil, fail(500, "SESSION_SECRET must be configured before enabling 2FA", "")
	}
	return t.Box, nil
}

// VerifyCurrentPassword asks a signed-in account for its password again before
// a sensitive change. Wrong tries count per account, not per address, so a
// stolen session cannot guess from many places.
func (t *TwoFactor) VerifyCurrentPassword(ctx context.Context, userID int64, password string) error {
	key := lockout.ConfirmKey(strconv.FormatInt(userID, 10))
	if err := t.Lockout.Check(ctx, key); err != nil {
		return err
	}
	if err := t.Lockout.Record(ctx, key, "password"); err != nil {
		return err
	}
	var hash string
	err := t.DB.R.QueryRowContext(ctx, `SELECT password FROM users WHERE id = ?`, userID).Scan(&hash)
	if errors.Is(err, sql.ErrNoRows) || (err == nil && !passhash.Verify(hash, password)) {
		return fail(401, "Current password is incorrect", "")
	}
	if err != nil {
		return err
	}
	return t.Lockout.Clear(ctx, key, "password")
}

// VerifyCurrentCode asks for a 2FA or recovery code again, throttled like passwords.
func (t *TwoFactor) VerifyCurrentCode(ctx context.Context, userID int64, code string) error {
	key := lockout.ConfirmKey(strconv.FormatInt(userID, 10))
	if err := t.Lockout.Check(ctx, key); err != nil {
		return err
	}
	if err := t.Lockout.Record(ctx, key, "second_factor"); err != nil {
		return err
	}
	ok, err := t.VerifyLoginCode(ctx, userID, code)
	if err != nil {
		return err
	}
	if !ok {
		return fail(401, "Invalid 2FA code", "")
	}
	return t.Lockout.Clear(ctx, key, "second_factor")
}

// SetupResult is what the enrolment screen shows.
type SetupResult struct {
	OtpauthURL string          `json:"otpauthUrl"`
	ManualKey  string          `json:"manualKey"`
	Status     TwoFactorStatus `json:"status"`
}

// BeginSetup creates a pending secret after re-checking the password.
func (t *TwoFactor) BeginSetup(ctx context.Context, userID int64, currentPassword string) (*SetupResult, error) {
	box, err := t.box()
	if err != nil {
		return nil, err
	}
	if err := t.VerifyCurrentPassword(ctx, userID, currentPassword); err != nil {
		return nil, err
	}
	var username string
	var email sql.NullString
	err = t.DB.R.QueryRowContext(ctx, `SELECT username, email FROM users WHERE id = ?`, userID).Scan(&username, &email)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, fail(404, "User not found", "")
	}
	if err != nil {
		return nil, err
	}
	secret, err := totp.GenerateSecret()
	if err != nil {
		return nil, err
	}
	label := email.String
	if label == "" {
		label = username
	}
	if label == "" {
		label = "user-" + strconv.FormatInt(userID, 10)
	}
	sealed, err := box.Seal(secret)
	if err != nil {
		return nil, err
	}
	_, err = t.DB.W.ExecContext(ctx, `
		INSERT INTO user_two_factor (user_id, pending_secret, enabled, created_at, updated_at)
		VALUES (?, ?, COALESCE((SELECT enabled FROM user_two_factor WHERE user_id = ?), 0), datetime('now'), datetime('now'))
		ON CONFLICT(user_id) DO UPDATE SET pending_secret = excluded.pending_secret, updated_at = datetime('now')`,
		userID, sealed, userID)
	if err != nil {
		return nil, err
	}
	st, err := t.Status(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &SetupResult{OtpauthURL: totp.URI(t.Issuer, label, secret), ManualKey: secret, Status: st}, nil
}

// storeRecoveryCodes replaces the account's recovery codes inside tx and
// returns the plain codes to show once. Hashing ten bcrypt hashes in parallel
// keeps this to roughly one hash of wall time.
func storeRecoveryCodes(ctx context.Context, tx *sql.Tx, userID int64) ([]string, error) {
	codes := make([]string, recoveryCodeCount)
	hashes := make([]string, recoveryCodeCount)
	errs := make([]error, recoveryCodeCount)
	var wg sync.WaitGroup
	for i := range codes {
		c, err := totp.NewRecoveryCode()
		if err != nil {
			return nil, err
		}
		codes[i] = c
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			hashes[i], errs[i] = passhash.Hash(totp.NormalizeRecoveryCode(codes[i]), PasswordCost)
		}(i)
	}
	wg.Wait()
	for _, err := range errs {
		if err != nil {
			return nil, err
		}
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM user_recovery_codes WHERE user_id = ?`, userID); err != nil {
		return nil, err
	}
	for _, h := range hashes {
		if _, err := tx.ExecContext(ctx, `INSERT INTO user_recovery_codes (user_id, code_hash, created_at) VALUES (?, ?, datetime('now'))`, userID, h); err != nil {
			return nil, err
		}
	}
	return codes, nil
}

// EnableResult is what the account page gets after turning 2FA on.
type EnableResult struct {
	Success       bool            `json:"success"`
	RecoveryCodes []string        `json:"recoveryCodes"`
	Status        TwoFactorStatus `json:"status"`
}

// Enable verifies the first code of the pending secret and switches 2FA on.
func (t *TwoFactor) Enable(ctx context.Context, userID int64, code string) (*EnableResult, error) {
	box, err := t.box()
	if err != nil {
		return nil, err
	}
	row, err := t.row(ctx, userID)
	if err != nil {
		return nil, err
	}
	if row == nil || !row.pending.Valid || row.pending.String == "" {
		return nil, fail(400, "No 2FA setup is pending", "")
	}
	secret, err := box.Open(row.pending.String)
	if err != nil || !totp.Verify(secret, code, t.now()) {
		return nil, fail(401, "Invalid 2FA code", "")
	}
	tx, err := t.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	codes, err := storeRecoveryCodes(ctx, tx, userID)
	if err != nil {
		return nil, err
	}
	if _, err := tx.ExecContext(ctx, `
		UPDATE user_two_factor
		SET secret = pending_secret, pending_secret = NULL, enabled = 1,
		    enabled_at = datetime('now'), updated_at = datetime('now')
		WHERE user_id = ?`, userID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	st, err := t.Status(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &EnableResult{Success: true, RecoveryCodes: codes, Status: st}, nil
}

func (t *TwoFactor) consumeRecoveryCode(ctx context.Context, userID int64, code string) (bool, error) {
	normalized := totp.NormalizeRecoveryCode(code)
	if len(normalized) < 6 {
		return false, nil
	}
	rows, err := t.DB.R.QueryContext(ctx, `SELECT id, code_hash FROM user_recovery_codes WHERE user_id = ? AND used_at IS NULL ORDER BY id ASC`, userID)
	if err != nil {
		return false, err
	}
	type entry struct {
		id   int64
		hash string
	}
	var entries []entry
	for rows.Next() {
		var e entry
		if err := rows.Scan(&e.id, &e.hash); err != nil {
			rows.Close()
			return false, err
		}
		entries = append(entries, e)
	}
	rows.Close()
	for _, e := range entries {
		if passhash.Verify(e.hash, normalized) {
			// The WHERE clause makes a code single-use even under concurrent tries.
			res, err := t.DB.W.ExecContext(ctx, `UPDATE user_recovery_codes SET used_at = datetime('now') WHERE id = ? AND user_id = ? AND used_at IS NULL`, e.id, userID)
			if err != nil {
				return false, err
			}
			n, _ := res.RowsAffected()
			return n == 1, nil
		}
	}
	return false, nil
}

// VerifyLoginCode accepts a current TOTP code or an unused recovery code. An
// account without an enabled factor passes, as in the Node server: callers
// only reach this for accounts that started a two-factor challenge.
func (t *TwoFactor) VerifyLoginCode(ctx context.Context, userID int64, code string) (bool, error) {
	row, err := t.row(ctx, userID)
	if err != nil {
		return false, err
	}
	if row == nil || !row.enabled || !row.secret.Valid || row.secret.String == "" {
		return true, nil
	}
	box, err := t.box()
	if err != nil {
		return false, err
	}
	secret, err := box.Open(row.secret.String)
	if err != nil {
		return false, nil
	}
	if totp.Verify(secret, code, t.now()) {
		return true, nil
	}
	return t.consumeRecoveryCode(ctx, userID, code)
}

// StatusResult is the plain success-with-status answer.
type StatusResult struct {
	Success bool            `json:"success"`
	Status  TwoFactorStatus `json:"status"`
}

// Disable turns 2FA off after the password and a current code.
func (t *TwoFactor) Disable(ctx context.Context, userID int64, currentPassword, code string) (*StatusResult, error) {
	if err := t.VerifyCurrentPassword(ctx, userID, currentPassword); err != nil {
		return nil, err
	}
	row, err := t.row(ctx, userID)
	if err != nil {
		return nil, err
	}
	if row == nil || !row.enabled {
		st, err := t.Status(ctx, userID)
		return &StatusResult{Success: true, Status: st}, err
	}
	if err := t.VerifyCurrentCode(ctx, userID, code); err != nil {
		return nil, err
	}
	tx, err := t.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `
		UPDATE user_two_factor
		SET enabled = 0, secret = NULL, pending_secret = NULL, enabled_at = NULL, updated_at = datetime('now')
		WHERE user_id = ?`, userID); err != nil {
		return nil, err
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM user_recovery_codes WHERE user_id = ?`, userID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	st, err := t.Status(ctx, userID)
	return &StatusResult{Success: true, Status: st}, err
}

// RegenerateRecoveryCodes replaces the codes after the password and a current code.
func (t *TwoFactor) RegenerateRecoveryCodes(ctx context.Context, userID int64, currentPassword, code string) (*EnableResult, error) {
	if err := t.VerifyCurrentPassword(ctx, userID, currentPassword); err != nil {
		return nil, err
	}
	if err := t.VerifyCurrentCode(ctx, userID, code); err != nil {
		return nil, err
	}
	tx, err := t.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	codes, err := storeRecoveryCodes(ctx, tx, userID)
	if err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	st, err := t.Status(ctx, userID)
	return &EnableResult{Success: true, RecoveryCodes: codes, Status: st}, err
}
