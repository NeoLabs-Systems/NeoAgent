package accounts

import (
	"context"
	"database/sql"
	"errors"
	"strings"
)

// Sign-up keys are twelve Crockford base32 characters shown as XXXX-XXXX-XXXX.
// While open sign-up is off, a new account needs one; the first account never does.

const (
	signupAlphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
	signupLength   = 12
)

// NormalizeSignupKey accepts a key however it was typed or pasted: any case,
// with or without dashes and spaces, and with the letters Crockford base32 reads
// as digits. It returns "" for anything that cannot be a key.
func NormalizeSignupKey(raw string) string {
	code := strings.ToUpper(raw)
	code = strings.Join(strings.FieldsFunc(code, func(r rune) bool { return r == '-' || r == ' ' || r == '\t' || r == '\n' || r == '\r' }), "")
	code = strings.ReplaceAll(code, "O", "0")
	code = strings.ReplaceAll(code, "I", "1")
	code = strings.ReplaceAll(code, "L", "1")
	if len(code) != signupLength {
		return ""
	}
	for _, c := range code {
		if !strings.ContainsRune(signupAlphabet, c) {
			return ""
		}
	}
	return code
}

// AssertSignupKeyUsable returns the normalized code of a key that can still be
// redeemed, or the error a sign-up form shows.
func (r *Repo) AssertSignupKeyUsable(ctx context.Context, raw string) (string, error) {
	return assertSignupKeyUsable(ctx, r.DB.R, raw)
}

func assertSignupKeyUsable(ctx context.Context, q querier, raw string) (string, error) {
	if strings.TrimSpace(raw) == "" {
		return "", fail(403, "A sign-up key is required to create an account.", "SIGNUP_KEY_REQUIRED")
	}
	code := NormalizeSignupKey(raw)
	var usedAt, revokedAt sql.NullString
	found := false
	if code != "" {
		err := q.QueryRowContext(ctx, `SELECT used_at, revoked_at FROM signup_keys WHERE code = ?`, code).Scan(&usedAt, &revokedAt)
		if err != nil && !errors.Is(err, sql.ErrNoRows) {
			return "", err
		}
		found = err == nil
	}
	if !found || revokedAt.Valid {
		return "", fail(403, "That sign-up key isn’t valid.", "SIGNUP_KEY_INVALID")
	}
	if usedAt.Valid {
		return "", fail(403, "That sign-up key has already been used.", "SIGNUP_KEY_USED")
	}
	return code, nil
}

// redeemSignupKey spends the key on the account just inserted, when one is
// needed. It runs in the transaction that creates the account, so a rejected
// key rolls the account back.
func (r *Repo) redeemSignupKey(ctx context.Context, tx querier, raw string, userID int64) error {
	var others int
	if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM users WHERE id <> ?`, userID).Scan(&others); err != nil {
		return err
	}
	if others == 0 || r.signupOpen() {
		return nil
	}
	code, err := assertSignupKeyUsable(ctx, tx, raw)
	if err != nil {
		return err
	}
	res, err := tx.ExecContext(ctx, `
		UPDATE signup_keys SET used_at = datetime('now'), used_by_user_id = ?
		WHERE code = ? AND used_at IS NULL AND revoked_at IS NULL`, userID, code)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return fail(403, "That sign-up key has already been used.", "SIGNUP_KEY_USED")
	}
	return nil
}
