// Package sharedmessaging stores the instance-wide messaging accounts (one
// Telegram bot or WhatsApp number everybody links to) in the tables the
// Node.js server used. Writers bump `revision`; the server re-applies an
// account when it changes. The CLI and the admin page both write here.
package sharedmessaging

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/apperr"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

// Platforms that can have an instance-wide account and how it signs in.
// Discord and Slack are absent on purpose (see docs/shared-messaging.md).
var Platforms = []struct{ ID, AuthMethod string }{{"telegram", "token"}, {"whatsapp", "qr"}}

var telegramToken = regexp.MustCompile(`^\d+:[\w-]{20,}$`)

// Store reads and writes the shared accounts.
type Store struct {
	DB  *dbx.DB
	Box *secretbox.Box
}

// Connection is one row of messaging_shared_connections.
type Connection struct {
	Platform      string
	Config        string
	Enabled       bool
	Available     bool
	AllowPersonal bool
	Revision      int64
	Status        string
	StatusReason  sql.NullString
	AccountID     sql.NullString
	AccountLabel  sql.NullString
	QR            sql.NullString
	LastConnected sql.NullString
}

// AssertShared fails for a platform without instance-wide accounts.
func AssertShared(platform string) error {
	for _, p := range Platforms {
		if p.ID == platform {
			return nil
		}
	}
	return apperr.New(400, platform+" cannot use an instance-wide account", "SHARED_PLATFORM_UNSUPPORTED")
}

// Get returns the platform's account, or nil.
func (s *Store) Get(ctx context.Context, platform string) (*Connection, error) {
	var c Connection
	err := s.DB.R.QueryRowContext(ctx, `
		SELECT platform, config, enabled, available, allow_personal, revision, status, status_reason, account_id, account_label, qr, last_connected
		FROM messaging_shared_connections WHERE platform = ?`, platform).
		Scan(&c.Platform, &c.Config, &c.Enabled, &c.Available, &c.AllowPersonal, &c.Revision, &c.Status, &c.StatusReason, &c.AccountID, &c.AccountLabel, &c.QR, &c.LastConnected)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &c, nil
}

// QR is the pairing code the server last wrote for the account.
func (s *Store) QR(c *Connection) string {
	if c == nil || !c.QR.Valid || c.QR.String == "" {
		return ""
	}
	v, err := s.Box.Open(c.QR.String)
	if err != nil {
		return ""
	}
	return v
}

// Input changes an account; nil fields keep their value.
type Input struct {
	BotToken      *string
	Enabled       *bool
	Available     *bool
	AllowPersonal *bool
	Reconnect     bool
}

func flag(v *bool, current bool) bool {
	if v == nil {
		return current
	}
	return *v
}

// Configure creates or changes the account. A new account, a new token, a
// requested reconnect or switching it on or off bumps the revision, which
// makes the server reconnect it.
func (s *Store) Configure(ctx context.Context, platform string, in Input, source string) error {
	if err := AssertShared(platform); err != nil {
		return err
	}
	existing, err := s.Get(ctx, platform)
	if err != nil {
		return err
	}
	config := map[string]any{}
	if existing != nil && existing.Config != "" {
		raw, err := s.Box.Open(existing.Config)
		if err != nil {
			return err
		}
		if err := json.Unmarshal([]byte(raw), &config); err != nil {
			return err
		}
	}
	if platform == "telegram" {
		if in.BotToken != nil {
			token := strings.TrimSpace(*in.BotToken)
			if !telegramToken.MatchString(token) {
				return apperr.New(400, "That does not look like a Telegram bot token", "SHARED_TOKEN_INVALID")
			}
			config["botToken"] = token
		}
		if t, _ := config["botToken"].(string); t == "" {
			return apperr.New(400, "A Telegram bot token is required", "SHARED_TOKEN_REQUIRED")
		}
	}
	rawConfig, err := json.Marshal(config)
	if err != nil {
		return err
	}
	sealed, err := s.Box.Seal(string(rawConfig))
	if err != nil {
		return err
	}
	current := Connection{Enabled: true, Available: true, AllowPersonal: true}
	if existing != nil {
		current = *existing
	}
	enabled := flag(in.Enabled, current.Enabled)
	available := flag(in.Available, current.Available)
	allowPersonal := flag(in.AllowPersonal, current.AllowPersonal)
	bump := 0
	if existing == nil || in.BotToken != nil || in.Reconnect || enabled != existing.Enabled {
		bump = 1
	}
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `
		INSERT INTO messaging_shared_connections (platform, config, enabled, available, allow_personal)
		VALUES (?1, ?2, ?3, ?4, ?5)
		ON CONFLICT(platform) DO UPDATE SET
			config = excluded.config,
			enabled = excluded.enabled,
			available = excluded.available,
			allow_personal = excluded.allow_personal,
			revision = revision + ?6,
			status = CASE WHEN excluded.enabled = 0 THEN 'disconnected' WHEN ?6 = 1 THEN 'connecting' ELSE status END,
			status_reason = CASE WHEN ?6 = 1 THEN NULL ELSE status_reason END,
			qr = CASE WHEN ?6 = 1 THEN NULL ELSE qr END,
			updated_at = datetime('now')`,
		platform, sealed, boolInt(enabled), boolInt(available), boolInt(allowPersonal), bump); err != nil {
		return err
	}
	detail, _ := json.Marshal(struct {
		Platform      string `json:"platform"`
		Source        string `json:"source"`
		Enabled       bool   `json:"enabled"`
		Available     bool   `json:"available"`
		AllowPersonal bool   `json:"allowPersonal"`
	}{platform, source, enabled, available, allowPersonal})
	if err := audit(ctx, tx, "messaging.shared_configure", string(detail)); err != nil {
		return err
	}
	return tx.Commit()
}

// Remove deletes the account with its links and pending link codes.
func (s *Store) Remove(ctx context.Context, platform, source string) error {
	if err := AssertShared(platform); err != nil {
		return err
	}
	tx, err := s.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for _, table := range []string{"messaging_link_codes", "messaging_identity_links", "messaging_shared_connections"} {
		if _, err := tx.ExecContext(ctx, `DELETE FROM `+table+` WHERE platform = ?`, platform); err != nil {
			return err
		}
	}
	detail, _ := json.Marshal(struct {
		Platform string `json:"platform"`
		Source   string `json:"source"`
	}{platform, source})
	if err := audit(ctx, tx, "messaging.shared_remove", string(detail)); err != nil {
		return err
	}
	return tx.Commit()
}

// CountLinks is how many people are linked on the platform.
func (s *Store) CountLinks(ctx context.Context, platform string) (int, error) {
	var n int
	err := s.DB.R.QueryRowContext(ctx, `SELECT COUNT(*) FROM messaging_identity_links WHERE platform = ?`, platform).Scan(&n)
	return n, err
}

// Overview is one platform as the admin page and `neoagent messaging list`
// show it.
type Overview struct {
	Platform      string  `json:"platform"`
	AuthMethod    string  `json:"authMethod"`
	Configured    bool    `json:"configured"`
	Enabled       bool    `json:"enabled"`
	Available     bool    `json:"available"`
	AllowPersonal bool    `json:"allowPersonal"`
	Status        string  `json:"status"`
	StatusReason  *string `json:"statusReason"`
	AccountLabel  *string `json:"accountLabel"`
	LastConnected *string `json:"lastConnected"`
	QR            *string `json:"qr"`
	LinkedUsers   int     `json:"linkedUsers"`
}

func nullable(v sql.NullString) *string {
	if !v.Valid || v.String == "" {
		return nil
	}
	return &v.String
}

// AdminOverview lists every shared platform, configured or not.
func (s *Store) AdminOverview(ctx context.Context) ([]Overview, error) {
	var out []Overview
	for _, p := range Platforms {
		c, err := s.Get(ctx, p.ID)
		if err != nil {
			return nil, err
		}
		links, err := s.CountLinks(ctx, p.ID)
		if err != nil {
			return nil, err
		}
		o := Overview{Platform: p.ID, AuthMethod: p.AuthMethod, Available: true, AllowPersonal: true, Status: "not_configured", LinkedUsers: links}
		if c != nil {
			o.Configured, o.Enabled, o.Available, o.AllowPersonal, o.Status = true, c.Enabled, c.Available, c.AllowPersonal, c.Status
			o.StatusReason, o.AccountLabel, o.LastConnected = nullable(c.StatusReason), nullable(c.AccountLabel), nullable(c.LastConnected)
			if qr := s.QR(c); qr != "" {
				o.QR = &qr
			}
		}
		out = append(out, o)
	}
	return out, nil
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

func audit(ctx context.Context, tx *sql.Tx, action, detail string) error {
	_, err := tx.ExecContext(ctx, `INSERT INTO access_audit_log (action, actor_user_id, subject_user_id, detail_json) VALUES (?, NULL, NULL, ?)`, action, detail)
	return err
}
