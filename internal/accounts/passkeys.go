package accounts

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strconv"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/webauthnx"
)

// PasskeyStore keeps credentials in user_webauthn_credentials, the table the
// Node server used, so existing security keys keep working.
type PasskeyStore struct{ DB *dbx.DB }

var _ webauthnx.Store = (*PasskeyStore)(nil)

const passkeyColumns = `id, user_id, credential_id, public_key, counter, rp_id, transports_json,
	device_type, backed_up, user_verified, label, created_at, last_used_at`

func scanPasskey(row rowScanner) (*webauthnx.Credential, error) {
	var c webauthnx.Credential
	var userID int64
	var counter, backedUp, uv sql.NullInt64
	var transports, deviceType, createdAt, lastUsed sql.NullString
	if err := row.Scan(&c.RowID, &userID, &c.CredentialID, &c.PublicKey, &counter, &c.RPID, &transports,
		&deviceType, &backedUp, &uv, &c.Label, &createdAt, &lastUsed); err != nil {
		return nil, err
	}
	c.UserID = strconv.FormatInt(userID, 10)
	if counter.Int64 > 0 {
		c.Counter = uint32(counter.Int64)
	}
	c.DeviceType = deviceType.String
	c.BackedUp = backedUp.Int64 == 1
	c.UserVerified = uv.Int64 == 1
	c.CreatedAt = createdAt.String
	c.LastUsedAt = lastUsed.String
	var ts []string
	if json.Unmarshal([]byte(transports.String), &ts) == nil {
		c.Transports = ts
	}
	return &c, nil
}

func (s *PasskeyStore) list(ctx context.Context, query string, args ...any) ([]webauthnx.Credential, error) {
	rows, err := s.DB.R.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []webauthnx.Credential
	for rows.Next() {
		c, err := scanPasskey(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *c)
	}
	return out, rows.Err()
}

func (s *PasskeyStore) ListForUser(ctx context.Context, userID string) ([]webauthnx.Credential, error) {
	return s.list(ctx, `SELECT `+passkeyColumns+` FROM user_webauthn_credentials WHERE user_id = ? ORDER BY created_at DESC, id DESC`, userID)
}

func (s *PasskeyStore) ForUserAndRP(ctx context.Context, userID, rpID string) ([]webauthnx.Credential, error) {
	return s.list(ctx, `SELECT `+passkeyColumns+` FROM user_webauthn_credentials WHERE user_id = ? AND rp_id = ?`, userID, rpID)
}

func (s *PasskeyStore) CountForRP(ctx context.Context, rpID string) (int, error) {
	var n int
	err := s.DB.R.QueryRowContext(ctx, `SELECT COUNT(*) FROM user_webauthn_credentials WHERE rp_id = ?`, rpID).Scan(&n)
	return n, err
}

func (s *PasskeyStore) FindByCredentialID(ctx context.Context, credentialID, rpID string) (*webauthnx.Credential, error) {
	c, err := scanPasskey(s.DB.R.QueryRowContext(ctx,
		`SELECT `+passkeyColumns+` FROM user_webauthn_credentials WHERE credential_id = ? AND rp_id = ?`, credentialID, rpID))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return c, err
}

func (s *PasskeyStore) Exists(ctx context.Context, credentialID string) (bool, error) {
	var one int
	err := s.DB.R.QueryRowContext(ctx, `SELECT 1 FROM user_webauthn_credentials WHERE credential_id = ?`, credentialID).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (s *PasskeyStore) Insert(ctx context.Context, c webauthnx.Credential) error {
	transports, _ := json.Marshal(append([]string{}, c.Transports...))
	_, err := s.DB.W.ExecContext(ctx, `
		INSERT INTO user_webauthn_credentials
		  (user_id, credential_id, public_key, counter, rp_id, transports_json, device_type, backed_up, user_verified, label)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		c.UserID, c.CredentialID, c.PublicKey, c.Counter, c.RPID, string(transports),
		nullable(c.DeviceType), boolInt(c.BackedUp), boolInt(c.UserVerified), c.Label)
	return err
}

func (s *PasskeyStore) UpdateAfterLogin(ctx context.Context, rowID int64, counter uint32, uv bool) error {
	_, err := s.DB.W.ExecContext(ctx,
		`UPDATE user_webauthn_credentials SET counter = ?, user_verified = ?, last_used_at = datetime('now') WHERE id = ?`,
		counter, boolInt(uv), rowID)
	return err
}

func (s *PasskeyStore) Rename(ctx context.Context, userID string, rowID int64, label string) (bool, error) {
	res, err := s.DB.W.ExecContext(ctx, `UPDATE user_webauthn_credentials SET label = ? WHERE id = ? AND user_id = ?`, label, rowID, userID)
	if err != nil {
		return false, err
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}

func (s *PasskeyStore) Delete(ctx context.Context, userID string, rowID int64) (bool, error) {
	res, err := s.DB.W.ExecContext(ctx, `DELETE FROM user_webauthn_credentials WHERE id = ? AND user_id = ?`, rowID, userID)
	if err != nil {
		return false, err
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}

// PasskeyAccounts lets the passkey ceremonies find accounts.
type PasskeyAccounts struct{ Repo *Repo }

var _ webauthnx.Accounts = PasskeyAccounts{}

func identity(u *User) webauthnx.Identity {
	return webauthnx.Identity{
		ID:          strconv.FormatInt(u.ID, 10),
		Username:    u.Username,
		DisplayName: u.DisplayName.String,
		Email:       u.Email.String,
	}
}

func (a PasskeyAccounts) ByID(ctx context.Context, userID string) (webauthnx.Identity, bool, error) {
	id, err := strconv.ParseInt(userID, 10, 64)
	if err != nil {
		return webauthnx.Identity{}, false, nil
	}
	u, err := a.Repo.ByID(ctx, id)
	if err != nil || u == nil {
		return webauthnx.Identity{}, false, err
	}
	return identity(u), true, nil
}

func (a PasskeyAccounts) ForSignIn(ctx context.Context, identifier string) (webauthnx.Identity, bool, error) {
	u, err := a.Repo.ForSignIn(ctx, identifier)
	if err != nil || u == nil {
		return webauthnx.Identity{}, false, err
	}
	return identity(u), true, nil
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
