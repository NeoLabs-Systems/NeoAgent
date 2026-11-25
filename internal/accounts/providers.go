package accounts

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/oauthlogin"
	"github.com/NeoLabs-Systems/neolabs-go/passhash"
)

// ProviderAccounts adapts the account store to the OAuth sign-in engine.
type ProviderAccounts struct{ Repo *Repo }

var _ oauthlogin.Accounts = ProviderAccounts{}

func (a ProviderAccounts) SignupKeyRequired(ctx context.Context) (bool, error) {
	return a.Repo.SignupKeyRequired(ctx)
}

func (a ProviderAccounts) AssertSignupKeyUsable(ctx context.Context, raw string) (string, error) {
	return a.Repo.AssertSignupKeyUsable(ctx, raw)
}

func (a ProviderAccounts) ValidateNewUsername(ctx context.Context, username string) error {
	return a.Repo.ValidateNewUsername(ctx, username)
}

func (a ProviderAccounts) EmailTaken(ctx context.Context, email string) (bool, error) {
	var one int
	err := a.Repo.DB.R.QueryRowContext(ctx, `SELECT id FROM users WHERE lower(email) = ?`, strings.ToLower(email)).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func randomPassword() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

func firstAvailableUsername(ctx context.Context, r *Repo, q querier, base string) (string, error) {
	norm := oauthlogin.UsernameCandidate(base)
	if norm == "" {
		norm = "user"
	}
	for attempt := 0; attempt < 1000; attempt++ {
		suffix := ""
		if attempt > 0 {
			suffix = strconv.Itoa(attempt + 1)
		}
		name := norm + suffix
		if len(name) > 32 {
			name = name[:32]
		}
		taken, err := usernameTaken(ctx, q, name)
		if err != nil {
			return "", err
		}
		reserved, err := r.isReservedAdminUsername(ctx, q, name)
		if err != nil {
			return "", err
		}
		if !taken && !reserved {
			return name, nil
		}
	}
	ms := strconv.FormatInt(time.Now().UnixMilli(), 10)
	return "user" + ms[len(ms)-6:], nil
}

func generateUniqueUsername(ctx context.Context, r *Repo, q querier, id oauthlogin.Identity) (string, error) {
	local := id.Email
	if i := strings.Index(local, "@"); i >= 0 {
		local = local[:i]
	}
	name := id.Username
	if name == "" {
		name = id.DisplayName
	}
	candidates := []string{oauthlogin.UsernameCandidate(name), oauthlogin.UsernameCandidate(local), "user"}
	for _, c := range candidates {
		if c == "" {
			continue
		}
		if v, err := firstAvailableUsername(ctx, r, q, c); err != nil || v != "" {
			return v, err
		}
	}
	return firstAvailableUsername(ctx, r, q, "user")
}

// CreateFromProvider creates the account and its provider link in one
// transaction, spending the sign-up key. If the identity was linked meanwhile,
// that account is signed in instead.
func (a ProviderAccounts) CreateFromProvider(ctx context.Context, p oauthlogin.Provider, id oauthlogin.Identity, signupKey, username string) (int64, bool, error) {
	// The account has no usable password; the random one only satisfies NOT NULL.
	pw, err := randomPassword()
	if err != nil {
		return 0, false, err
	}
	hash, err := passhash.Hash(pw, PasswordCost)
	if err != nil {
		return 0, false, err
	}
	r := a.Repo
	tx, err := r.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return 0, false, err
	}
	defer tx.Rollback()

	// Another callback can register this identity while password hashing runs.
	var existing int64
	err = tx.QueryRowContext(ctx, `SELECT user_id FROM user_auth_providers WHERE provider_key = ? AND provider_user_id = ?`, p.Key(), id.ProviderUserID).Scan(&existing)
	if err == nil {
		if err := oauthlogin.SaveLink(ctx, tx, existing, p.Key(), id); err != nil {
			return 0, false, err
		}
		return existing, false, tx.Commit()
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return 0, false, err
	}
	if username != "" {
		if err := r.validateNewUsername(ctx, tx, username); err != nil {
			return 0, false, err
		}
	} else if username, err = generateUniqueUsername(ctx, r, tx, id); err != nil {
		return 0, false, err
	}
	var email, verified any
	if id.Email != "" {
		email = strings.ToLower(id.Email)
		verified = time.Now().UTC().Format("2006-01-02T15:04:05.000Z")
	}
	res, err := tx.ExecContext(ctx, `INSERT INTO users (username, email, email_verified_at, password, password_login_enabled) VALUES (?, ?, ?, ?, 0)`,
		username, email, verified, hash)
	if err != nil {
		return 0, false, mapConstraint(err)
	}
	userID, err := res.LastInsertId()
	if err != nil {
		return 0, false, err
	}
	if err := r.redeemSignupKey(ctx, tx, signupKey, userID); err != nil {
		return 0, false, err
	}
	if err := oauthlogin.SaveLink(ctx, tx, userID, p.Key(), id); err != nil {
		return 0, false, err
	}
	return userID, true, tx.Commit()
}
