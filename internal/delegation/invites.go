package delegation

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neolabs-go/apperr"

	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
)

const (
	inviteTokenBytes  = 24
	maxExpiryHours    = 24 * 90
	maxActiveInvites  = 25
	inviteQueryParam  = "invite"
	maxInviteLabelLen = 80
)

var bareToken = regexp.MustCompile(`^[A-Za-z0-9_-]+$`)

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// InviteLink is the link handed to the issuer; only its token's hash is stored.
func InviteLink(baseURL, token string) string {
	return strings.TrimRight(baseURL, "/") + "/app/?" + inviteQueryParam + "=" + token
}

// tokenFromLink accepts the full link or just the token, however it was pasted.
func tokenFromLink(link any) string {
	text, _ := link.(string)
	text = strings.TrimSpace(text)
	if text == "" {
		return ""
	}
	if u, err := url.Parse(text); err == nil && u.Scheme != "" && u.Host != "" {
		return u.Query().Get(inviteQueryParam)
	}
	if bareToken.MatchString(text) {
		return text
	}
	return ""
}

type inviteRow struct {
	id                   string
	issuer               int64
	label, permissions   string
	maxUses              sql.NullInt64
	useCount             int64
	expiresAt, revokedAt sql.NullString
	createdAt            string
}

const inviteColumns = `id, issuer_user_id, label, permissions_json, max_uses, use_count, expires_at, revoked_at, created_at`

func scanInvite(sc interface{ Scan(...any) error }) (inviteRow, error) {
	var r inviteRow
	err := sc.Scan(&r.id, &r.issuer, &r.label, &r.permissions, &r.maxUses, &r.useCount, &r.expiresAt, &r.revokedAt, &r.createdAt)
	return r, err
}

func (r inviteRow) status(now time.Time) string {
	if r.revokedAt.Valid {
		return "revoked"
	}
	// SQLite datetime('now') values are UTC without a zone marker.
	if r.expiresAt.Valid {
		if t, err := time.Parse("2006-01-02 15:04:05", r.expiresAt.String); err == nil && !t.After(now) {
			return "expired"
		}
	}
	if r.maxUses.Valid && r.useCount >= r.maxUses.Int64 {
		return "used"
	}
	return "active"
}

func nullable[T any](valid bool, v T) any {
	if !valid {
		return nil
	}
	return v
}

func (r inviteRow) serialize() *jsonobj.Object {
	return jsonobj.New(
		"id", r.id,
		"label", r.label,
		"permissions", allowedList(r.permissions),
		"maxUses", nullable(r.maxUses.Valid, r.maxUses.Int64),
		"useCount", r.useCount,
		"expiresAt", nullable(r.expiresAt.Valid, r.expiresAt.String),
		"revokedAt", nullable(r.revokedAt.Valid, r.revokedAt.String),
		"createdAt", r.createdAt,
		"status", r.status(time.Now()),
	)
}

func (s *Service) listInviteRows(ctx context.Context, issuer int64) ([]inviteRow, error) {
	rows, err := s.db.R.QueryContext(ctx, `SELECT `+inviteColumns+` FROM delegation_invites WHERE issuer_user_id = ? ORDER BY created_at DESC, id`, issuer)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []inviteRow
	for rows.Next() {
		r, err := scanInvite(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// ListInvites lists an issuer's invite links, newest first.
func (s *Service) ListInvites(ctx context.Context, issuer int64) ([]*jsonobj.Object, error) {
	rows, err := s.listInviteRows(ctx, issuer)
	if err != nil {
		return nil, err
	}
	out := make([]*jsonobj.Object, 0, len(rows))
	for _, r := range rows {
		out = append(out, r.serialize())
	}
	return out, nil
}

// InviteInput is a create request as the client sent it.
type InviteInput struct {
	Label          any
	Permissions    any
	ExpiresInHours any
	MaxUses        any
}

type inviteSpec struct {
	label       string
	permissions []string
	expires     any // hours or nil
	maxUses     any // 1 or nil
}

func normalizeInvite(in InviteInput) (inviteSpec, error) {
	list, ok := in.Permissions.([]any)
	if !ok {
		return inviteSpec{}, apperr.New(http.StatusBadRequest, "permissions must be a list of known permission keys.", "INVITE_SCOPE_UNKNOWN")
	}
	var perms []string
	seen := map[string]bool{}
	for _, v := range list {
		key, ok := v.(string)
		if !ok || !knownPermission(key) {
			return inviteSpec{}, apperr.New(http.StatusBadRequest, "permissions must be a list of known permission keys.", "INVITE_SCOPE_UNKNOWN")
		}
		if !seen[key] {
			seen[key] = true
			perms = append(perms, key)
		}
	}
	if perms == nil {
		perms = []string{}
	}
	spec := inviteSpec{permissions: perms}
	if in.ExpiresInHours != nil {
		h, ok := in.ExpiresInHours.(float64)
		if !ok || h != math.Trunc(h) || h < 1 || h > maxExpiryHours {
			return inviteSpec{}, apperr.New(http.StatusBadRequest, fmt.Sprintf("expiresInHours must be between 1 and %d, or null.", maxExpiryHours), "INVITE_EXPIRY_INVALID")
		}
		spec.expires = int64(h)
	}
	if in.MaxUses != nil {
		if n, ok := in.MaxUses.(float64); !ok || n != 1 {
			return inviteSpec{}, apperr.New(http.StatusBadRequest, "maxUses must be 1 (single-use) or null (reusable).", "INVITE_USES_INVALID")
		}
		spec.maxUses = int64(1)
	}
	label := strings.TrimSpace(jsTruthyString(in.Label))
	if r := []rune(label); len(r) > maxInviteLabelLen {
		label = string(r[:maxInviteLabelLen])
	}
	spec.label = label
	return spec, nil
}

// jsTruthyString is String(value || ”).
func jsTruthyString(v any) string {
	switch t := v.(type) {
	case nil:
		return ""
	case string:
		return t
	case bool:
		if t {
			return "true"
		}
		return ""
	case float64:
		if t == 0 {
			return ""
		}
		return jsString(t)
	}
	return jsString(v)
}

// CreateInvite issues a link that grants at most what the issuer holds.
func (s *Service) CreateInvite(ctx context.Context, issuer int64, in InviteInput) (*jsonobj.Object, string, error) {
	spec, err := normalizeInvite(in)
	if err != nil {
		return nil, "", err
	}
	held, err := s.held(ctx, s.db.R, issuer)
	if err != nil {
		return nil, "", err
	}
	for _, k := range spec.permissions {
		if !held[k] {
			return nil, "", apperr.New(http.StatusForbidden, "A link can only grant permissions you hold yourself.", "INVITE_SCOPE")
		}
	}
	rows, err := s.listInviteRows(ctx, issuer)
	if err != nil {
		return nil, "", err
	}
	active := 0
	now := time.Now()
	for _, r := range rows {
		if r.status(now) == "active" {
			active++
		}
	}
	if active >= maxActiveInvites {
		return nil, "", apperr.New(http.StatusTooManyRequests, fmt.Sprintf("You already have %d open invite links. Revoke some before creating more.", maxActiveInvites), "INVITE_LIMIT")
	}
	id := uuid.NewString()
	buf := make([]byte, inviteTokenBytes)
	if _, err := rand.Read(buf); err != nil {
		return nil, "", err
	}
	token := base64.RawURLEncoding.EncodeToString(buf)
	scope, _ := json.Marshal(spec.permissions)
	err = s.inTx(ctx, func(q querier) error {
		if _, err := q.ExecContext(ctx, `INSERT INTO delegation_invites (id, issuer_user_id, token_hash, label, permissions_json, max_uses, expires_at)
      VALUES (?, ?, ?, ?, ?, ?, CASE WHEN ? IS NULL THEN NULL ELSE datetime('now', '+' || ? || ' hours') END)`,
			id, issuer, hashToken(token), spec.label, string(scope), spec.maxUses, spec.expires, spec.expires); err != nil {
			return err
		}
		return record(ctx, q, "invite.create", issuer, issuer, jsonobj.New("inviteId", id, "permissions", spec.permissions, "maxUses", spec.maxUses, "expiresInHours", spec.expires))
	})
	if err != nil {
		return nil, "", err
	}
	row, err := scanInvite(s.db.R.QueryRowContext(ctx, `SELECT `+inviteColumns+` FROM delegation_invites WHERE id = ?`, id))
	if err != nil {
		return nil, "", err
	}
	return row.serialize(), token, nil
}

// RevokeInvite revokes one of the issuer's open links.
func (s *Service) RevokeInvite(ctx context.Context, issuer int64, inviteID string) error {
	return s.inTx(ctx, func(q querier) error {
		res, err := q.ExecContext(ctx, `UPDATE delegation_invites SET revoked_at = datetime('now')
      WHERE id = ? AND issuer_user_id = ? AND revoked_at IS NULL`, inviteID, issuer)
		if err != nil {
			return err
		}
		if n, _ := res.RowsAffected(); n == 0 {
			return apperr.New(http.StatusNotFound, "No active invite link with that id.", "INVITE_NOT_FOUND")
		}
		return record(ctx, q, "invite.revoke", issuer, issuer, jsonobj.New("inviteId", inviteID))
	})
}

// checkRedeemable is everything that must hold for userID to redeem link. It
// runs for the preview and again inside the redeeming transaction.
func (s *Service) checkRedeemable(ctx context.Context, q querier, userID int64, link any) (inviteRow, []string, error) {
	token := tokenFromLink(link)
	var row inviteRow
	err := sql.ErrNoRows
	if token != "" {
		row, err = scanInvite(q.QueryRowContext(ctx, `SELECT `+inviteColumns+` FROM delegation_invites WHERE token_hash = ?`, hashToken(token)))
	}
	if errors.Is(err, sql.ErrNoRows) {
		return row, nil, apperr.New(http.StatusNotFound, "This invite link isn’t valid.", "INVITE_INVALID")
	}
	if err != nil {
		return row, nil, err
	}
	switch row.status(time.Now()) {
	case "revoked":
		return row, nil, apperr.New(http.StatusGone, "This invite link was revoked.", "INVITE_REVOKED")
	case "expired":
		return row, nil, apperr.New(http.StatusGone, "This invite link has expired.", "INVITE_EXPIRED")
	case "used":
		return row, nil, apperr.New(http.StatusGone, "This invite link has already been used.", "INVITE_USED")
	}
	scope := allowedList(row.permissions)
	held, err := s.held(ctx, q, row.issuer)
	if err != nil {
		return row, nil, err
	}
	for _, k := range scope {
		if !held[k] {
			return row, nil, apperr.New(http.StatusConflict, "This link grants permissions its creator no longer holds.", "INVITE_SCOPE")
		}
	}
	if err := s.assertCanAttach(ctx, q, row.issuer, userID); err != nil {
		return row, nil, err
	}
	return row, scope, nil
}

// PreviewInvite says who would manage the account and with which scope.
func (s *Service) PreviewInvite(ctx context.Context, userID int64, link any) (*jsonobj.Object, error) {
	row, scope, err := s.checkRedeemable(ctx, s.db.R, userID, link)
	if err != nil {
		return nil, err
	}
	return jsonobj.New(
		"issuer", publicUser(ctx, s.db.R, row.issuer),
		"permissions", scope,
		"expiresAt", nullable(row.expiresAt.Valid, row.expiresAt.String),
		"singleUse", row.maxUses.Valid && row.maxUses.Int64 == 1,
	), nil
}

// RedeemInvite puts userID under the link's issuer.
func (s *Service) RedeemInvite(ctx context.Context, userID int64, link any) error {
	return s.inTx(ctx, func(q querier) error {
		row, scope, err := s.checkRedeemable(ctx, q, userID, link)
		if err != nil {
			return err
		}
		res, err := q.ExecContext(ctx, `UPDATE delegation_invites SET use_count = use_count + 1
      WHERE id = ? AND revoked_at IS NULL AND (max_uses IS NULL OR use_count < max_uses)`, row.id)
		if err != nil {
			return err
		}
		if n, _ := res.RowsAffected(); n == 0 {
			return apperr.New(http.StatusGone, "This invite link has already been used.", "INVITE_USED")
		}
		if err := s.assertCanAttach(ctx, q, row.issuer, userID); err != nil {
			return err
		}
		raw, _ := json.Marshal(scope)
		if _, err := q.ExecContext(ctx, `INSERT INTO user_delegations (managed_user_id, manager_user_id, allowed_permissions_json, invite_id)
      VALUES (?, ?, ?, ?)`, userID, row.issuer, string(raw), row.id); err != nil {
			return err
		}
		return record(ctx, q, "delegation.create", userID, userID, jsonobj.New("managerUserId", row.issuer, "inviteId", row.id, "permissions", scope))
	})
}
