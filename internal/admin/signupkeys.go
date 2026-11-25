package admin

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/json"
	"strings"
)

// One-time sign-up keys: twelve Crockford base32 characters (60 bits), shown
// as XXXX-XXXX-XXXX and kept as written so admins can export the unused ones.
// Redeeming a key is the accounts package's job; this is the admin side.

const (
	keyAlphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
	keyLength   = 12
	keyGroup    = 4
	maxBatch    = 500
	maxLabel    = 80
)

// SignupKey is a key as the admin page lists it.
type SignupKey struct {
	ID        int64      `json:"id"`
	Code      string     `json:"code"`
	Label     string     `json:"label"`
	Status    string     `json:"status"`
	CreatedAt string     `json:"createdAt"`
	CreatedBy *string    `json:"createdBy"`
	UsedAt    *string    `json:"usedAt"`
	UsedBy    *KeyUsedBy `json:"usedBy"`
	RevokedAt *string    `json:"revokedAt"`
}

// KeyUsedBy names the account that redeemed a key.
type KeyUsedBy struct {
	ID       int64   `json:"id"`
	Username *string `json:"username"`
}

func generateKeyCode() (string, error) {
	raw := make([]byte, keyLength)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	code := make([]byte, keyLength)
	for i, b := range raw {
		code[i] = keyAlphabet[b&31] // 32 symbols divide 256, so no bias
	}
	return string(code), nil
}

func formatKeyCode(code string) string {
	var groups []string
	for len(code) > keyGroup {
		groups = append(groups, code[:keyGroup])
		code = code[keyGroup:]
	}
	return strings.Join(append(groups, code), "-")
}

const keySelect = `
	SELECT keys.id, keys.code, keys.label, keys.created_at, keys.used_at, keys.used_by_user_id,
	       keys.revoked_at, creator.username, redeemer.username
	FROM signup_keys keys
	LEFT JOIN users creator ON creator.id = keys.created_by_user_id
	LEFT JOIN users redeemer ON redeemer.id = keys.used_by_user_id`

type keyQuerier interface {
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
}

func queryKeys(ctx context.Context, q keyQuerier, tail string, args ...any) ([]SignupKey, error) {
	rows, err := q.QueryContext(ctx, keySelect+tail, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	keys := []SignupKey{}
	for rows.Next() {
		var k SignupKey
		var code string
		var usedByID sql.NullInt64
		var redeemer *string
		if err := rows.Scan(&k.ID, &code, &k.Label, &k.CreatedAt, &k.UsedAt, &usedByID, &k.RevokedAt, &k.CreatedBy, &redeemer); err != nil {
			return nil, err
		}
		k.Code = formatKeyCode(code)
		switch {
		case k.RevokedAt != nil:
			k.Status = "revoked"
		case k.UsedAt != nil:
			k.Status = "used"
		default:
			k.Status = "unused"
		}
		if usedByID.Valid {
			k.UsedBy = &KeyUsedBy{ID: usedByID.Int64, Username: redeemer}
		}
		keys = append(keys, k)
	}
	return keys, rows.Err()
}

// ListSignupKeys returns every key, newest first.
func (s *Store) ListSignupKeys(ctx context.Context) ([]SignupKey, error) {
	return queryKeys(ctx, s.DB.R, ` ORDER BY keys.created_at DESC, keys.id DESC`)
}

type keysCreatedEvent struct {
	Count int    `json:"count"`
	Label string `json:"label"`
}

type keyRevokedEvent struct {
	KeyID int64 `json:"keyId"`
}

// CreateSignupKeys makes count keys in one transaction and audits it. count
// must be a JSON number holding a whole number from 1 to 500.
func (s *Store) CreateSignupKeys(ctx context.Context, actor int64, count any, label any) ([]SignupKey, error) {
	n, isNumber := count.(json.Number)
	f := jsToNumber(n)
	if !isNumber || !isInteger(f) || f < 1 || f > maxBatch {
		return nil, fail(400, "count must be a whole number from 1 to 500.", "SIGNUP_KEY_COUNT_INVALID")
	}
	wanted := int(f)
	cleanLabel := sliceUTF16(jsTrim(jsText(label)), maxLabel)

	ids := make([]any, 0, wanted)
	err := s.inTx(ctx, func(tx *sql.Tx) error {
		// A collision is vanishingly rare at 60 bits; draw again if one happens.
		for len(ids) < wanted {
			code, err := generateKeyCode()
			if err != nil {
				return err
			}
			res, err := tx.ExecContext(ctx, `INSERT OR IGNORE INTO signup_keys (code, label, created_by_user_id) VALUES (?, ?, ?)`, code, cleanLabel, actor)
			if err != nil {
				return err
			}
			if changed, _ := res.RowsAffected(); changed == 1 {
				id, err := res.LastInsertId()
				if err != nil {
					return err
				}
				ids = append(ids, id)
			}
		}
		return recordEvent(ctx, tx, "signup_keys.create", &actor, nil, keysCreatedEvent{Count: wanted, Label: cleanLabel})
	})
	if err != nil {
		return nil, err
	}
	marks := strings.TrimSuffix(strings.Repeat("?, ", len(ids)), ", ")
	return queryKeys(ctx, s.DB.W, ` WHERE keys.id IN (`+marks+`) ORDER BY keys.id`, ids...)
}

// RevokeSignupKey voids a key that has not been used.
func (s *Store) RevokeSignupKey(ctx context.Context, actor, keyID int64) error {
	return s.inTx(ctx, func(tx *sql.Tx) error {
		res, err := tx.ExecContext(ctx, `
			UPDATE signup_keys SET revoked_at = datetime('now')
			WHERE id = ? AND used_at IS NULL AND revoked_at IS NULL`, keyID)
		if err != nil {
			return err
		}
		if changed, _ := res.RowsAffected(); changed == 0 {
			return fail(404, "No unused sign-up key with that id.", "SIGNUP_KEY_NOT_FOUND")
		}
		return recordEvent(ctx, tx, "signup_keys.revoke", &actor, nil, keyRevokedEvent{KeyID: keyID})
	})
}
