package sharedmessaging

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"math/big"
	"regexp"
	"time"
)

// Identity links and link codes (shared_store.js): a person links their own
// chat with the shared account to one of their agents by sending a one-time
// code from the app.

const (
	linkCodeTTL      = 10 * time.Minute
	linkCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	linkCodePrefix   = "NeoAgent-"
)

var linkCodePattern = regexp.MustCompile(`\bNeoAgent-[A-HJ-NP-Z2-9]{10}\b`)

// Link is one row of messaging_identity_links.
type Link struct {
	ID          int64
	Platform    string
	ExternalID  string
	ChatID      string
	DisplayName sql.NullString
	UserID      int64
	AgentID     string
	LinkedAt    string
}

const linkColumns = `id, platform, external_id, chat_id, display_name, user_id, agent_id, linked_at`

func scanLink(sc interface{ Scan(...any) error }) (*Link, error) {
	var l Link
	err := sc.Scan(&l.ID, &l.Platform, &l.ExternalID, &l.ChatID, &l.DisplayName, &l.UserID, &l.AgentID, &l.LinkedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return &l, err
}

type queryer interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
}

func (s *Store) links(ctx context.Context, q queryer, where string, args ...any) ([]Link, error) {
	rows, err := q.QueryContext(ctx, `SELECT `+linkColumns+` FROM messaging_identity_links`+where, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Link
	for rows.Next() {
		l, err := scanLink(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *l)
	}
	return out, rows.Err()
}

func (s *Store) link(ctx context.Context, q queryer, where string, args ...any) (*Link, error) {
	return scanLink(q.QueryRowContext(ctx, `SELECT `+linkColumns+` FROM messaging_identity_links WHERE `+where, args...))
}

// AllLinks lists every identity link.
func (s *Store) AllLinks(ctx context.Context) ([]Link, error) { return s.links(ctx, s.DB.R, "") }

// LinksForUser lists a user's links.
func (s *Store) LinksForUser(ctx context.Context, userID int64) ([]Link, error) {
	return s.links(ctx, s.DB.R, " WHERE user_id = ?", userID)
}

// LinkByExternalID finds the link of a platform identity.
func (s *Store) LinkByExternalID(ctx context.Context, platform, externalID string) (*Link, error) {
	return s.link(ctx, s.DB.R, "platform = ? AND external_id = ?", platform, externalID)
}

// LinkByChat finds the link of a chat.
func (s *Store) LinkByChat(ctx context.Context, platform, chatID string) (*Link, error) {
	return s.link(ctx, s.DB.R, "platform = ? AND chat_id = ?", platform, chatID)
}

// LinkForUser finds a user's link on a platform.
func (s *Store) LinkForUser(ctx context.Context, platform string, userID int64) (*Link, error) {
	return s.link(ctx, s.DB.R, "platform = ? AND user_id = ?", platform, userID)
}

// UpdateLinkChat moves a link to the chat the person now writes from.
func (s *Store) UpdateLinkChat(ctx context.Context, id int64, chatID string) error {
	_, err := s.DB.W.ExecContext(ctx, `UPDATE messaging_identity_links SET chat_id = ? WHERE id = ?`, chatID, id)
	return err
}

func recordEvent(ctx context.Context, tx *sql.Tx, action string, actor, subject any, detail any) error {
	raw, _ := json.Marshal(detail)
	_, err := tx.ExecContext(ctx, `INSERT INTO access_audit_log (action, actor_user_id, subject_user_id, detail_json) VALUES (?, ?, ?, ?)`, action, actor, subject, string(raw))
	return err
}

// Unlink removes a user's link; actor is who did it (the user themself by default).
func (s *Store) Unlink(ctx context.Context, platform string, userID int64, actor any, source string) (bool, error) {
	if actor == nil {
		actor = userID
	}
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return false, err
	}
	defer tx.Rollback()
	res, err := tx.ExecContext(ctx, `DELETE FROM messaging_identity_links WHERE platform = ? AND user_id = ?`, platform, userID)
	if err != nil {
		return false, err
	}
	n, _ := res.RowsAffected()
	if n > 0 {
		if err := recordEvent(ctx, tx, "messaging.identity_unlink", actor, userID, map[string]any{"platform": platform, "source": source}); err != nil {
			return false, err
		}
	}
	return n > 0, tx.Commit()
}

func hashCode(code string) string {
	sum := sha256.Sum256([]byte(code))
	return hex.EncodeToString(sum[:])
}

// ExtractLinkCode is the link code in a message, or "".
func ExtractLinkCode(text string) string { return linkCodePattern.FindString(text) }

// CreateLinkCode gives a user one live code per platform; asking again
// retires the last one. expiresAt is in milliseconds.
func (s *Store) CreateLinkCode(ctx context.Context, platform string, userID int64, agentID string, now time.Time) (code string, expiresAt int64, err error) {
	suffix := make([]byte, 10)
	for i := range suffix {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(linkCodeAlphabet))))
		if err != nil {
			return "", 0, err
		}
		suffix[i] = linkCodeAlphabet[n.Int64()]
	}
	code = linkCodePrefix + string(suffix)
	nowMS := now.UnixMilli()
	expiresAt = nowMS + linkCodeTTL.Milliseconds()
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return "", 0, err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `DELETE FROM messaging_link_codes WHERE expires_at <= ? OR (platform = ? AND user_id = ?)`, nowMS, platform, userID); err != nil {
		return "", 0, err
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO messaging_link_codes (code_hash, platform, user_id, agent_id, expires_at) VALUES (?, ?, ?, ?, ?)`,
		hashCode(code), platform, userID, agentID, expiresAt); err != nil {
		return "", 0, err
	}
	return code, expiresAt, tx.Commit()
}

// Identity is who sent a code, from the platform's own sender field.
type Identity struct {
	ExternalID, ChatID, DisplayName string
}

// Redemption is the outcome of a code.
type Redemption struct {
	Linked          bool
	Reason          string
	UserID          int64
	AgentID         string
	PreviousAgentID string
}

// RedeemLinkCode links the sender to the code's agent. An identity linked to
// someone else stays theirs until they unlink it.
func (s *Store) RedeemLinkCode(ctx context.Context, platform, code string, id Identity, now time.Time) (Redemption, error) {
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return Redemption{}, err
	}
	defer tx.Rollback()
	hash := hashCode(code)
	var userID, expires int64
	var agentID string
	err = tx.QueryRowContext(ctx, `SELECT user_id, agent_id, expires_at FROM messaging_link_codes WHERE code_hash = ? AND platform = ?`, hash, platform).Scan(&userID, &agentID, &expires)
	if errors.Is(err, sql.ErrNoRows) || (err == nil && expires <= now.UnixMilli()) {
		return Redemption{Reason: "invalid_code"}, nil
	}
	if err != nil {
		return Redemption{}, err
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM messaging_link_codes WHERE code_hash = ?`, hash); err != nil {
		return Redemption{}, err
	}
	holder, err := s.link(ctx, tx, "platform = ? AND external_id = ?", platform, id.ExternalID)
	if err != nil {
		return Redemption{}, err
	}
	if holder != nil && holder.UserID != userID {
		if err := recordEvent(ctx, tx, "messaging.identity_conflict", nil, userID, map[string]any{"platform": platform}); err != nil {
			return Redemption{}, err
		}
		return Redemption{Reason: "identity_taken", UserID: userID, AgentID: agentID}, tx.Commit()
	}
	previous, err := s.link(ctx, tx, "platform = ? AND user_id = ?", platform, userID)
	if err != nil {
		return Redemption{}, err
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM messaging_identity_links WHERE platform = ? AND user_id = ?`, platform, userID); err != nil {
		return Redemption{}, err
	}
	var display any
	if id.DisplayName != "" {
		display = id.DisplayName
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO messaging_identity_links (platform, external_id, chat_id, display_name, user_id, agent_id) VALUES (?, ?, ?, ?, ?, ?)`,
		platform, id.ExternalID, id.ChatID, display, userID, agentID); err != nil {
		return Redemption{}, err
	}
	if err := recordEvent(ctx, tx, "messaging.identity_link", nil, userID, map[string]any{"platform": platform}); err != nil {
		return Redemption{}, err
	}
	r := Redemption{Linked: true, UserID: userID, AgentID: agentID}
	if previous != nil {
		r.PreviousAgentID = previous.AgentID
	}
	return r, tx.Commit()
}

// State is what the server reports about a running account. Nil fields keep
// their value; QR is always replaced ("" clears it).
type State struct {
	Status       *string
	StatusReason *sql.NullString
	QR           string
	AccountID    *string
	AccountLabel *string
}

// UpdateState records the account's live state (updateConnectionState).
func (s *Store) UpdateState(ctx context.Context, platform string, st State) error {
	c, err := s.Get(ctx, platform)
	if err != nil || c == nil {
		return err
	}
	status := c.Status
	if st.Status != nil {
		status = *st.Status
	}
	reason := c.StatusReason
	if st.StatusReason != nil {
		reason = *st.StatusReason
	}
	var qr any
	if st.QR != "" {
		sealed, err := s.Box.Seal(st.QR)
		if err != nil {
			return err
		}
		qr = sealed
	}
	accountID := c.AccountID
	if st.AccountID != nil {
		accountID = sql.NullString{String: *st.AccountID, Valid: true}
	}
	label := c.AccountLabel
	if st.AccountLabel != nil {
		label = sql.NullString{String: *st.AccountLabel, Valid: true}
	}
	_, err = s.DB.W.ExecContext(ctx, `UPDATE messaging_shared_connections
		SET status = ?, status_reason = ?, qr = ?, account_id = ?, account_label = ?,
		    last_connected = CASE WHEN ? = 'connected' THEN datetime('now') ELSE last_connected END
		WHERE platform = ?`, status, reason, qr, accountID, label, status, platform)
	return err
}

// Config is the account's decrypted configuration (bot token, ...).
func (s *Store) DecodeConfig(c *Connection) (map[string]any, error) {
	out := map[string]any{}
	if c == nil || c.Config == "" {
		return out, nil
	}
	raw, err := s.Box.Open(c.Config)
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return nil, err
	}
	return out, nil
}
