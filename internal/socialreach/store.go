package socialreach

import (
	"context"
	"database/sql"
	"encoding/json"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

// cookieStore keeps each account's imported cookies, sealed, in user_settings.
type cookieStore struct {
	db  *dbx.DB
	box *secretbox.Box
}

type cookieBundle struct {
	Platform   string           `json:"platform"`
	ImportedAt string           `json:"importedAt"`
	Cookies    []map[string]any `json:"cookies"`
}

type cookieSummary struct {
	Configured bool    `json:"configured"`
	Count      int     `json:"count"`
	ImportedAt *string `json:"importedAt"`
}

func settingKey(platform string) string {
	return "social_reach_cookies_" + normalizePlatformID(platform)
}

// read returns the stored bundle; unreadable data counts as none, like Node.
func (s *cookieStore) read(ctx context.Context, userID int64, platform string) *cookieBundle {
	var raw sql.NullString
	err := s.db.R.QueryRowContext(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = ?`, userID, settingKey(platform)).Scan(&raw)
	if err != nil || raw.String == "" {
		return nil
	}
	plain, err := s.box.Open(raw.String)
	if err != nil {
		return nil
	}
	var bundle cookieBundle
	if json.Unmarshal([]byte(plain), &bundle) != nil {
		return nil
	}
	return &bundle
}

func (s *cookieStore) write(ctx context.Context, userID int64, platform string, cookies []map[string]any) (cookieBundle, error) {
	if cookies == nil {
		cookies = []map[string]any{}
	}
	bundle := cookieBundle{Platform: normalizePlatformID(platform), ImportedAt: time.Now().UTC().Format("2006-01-02T15:04:05.000Z"), Cookies: cookies}
	raw, err := json.Marshal(bundle)
	if err != nil {
		return bundle, err
	}
	sealed, err := s.box.Seal(string(raw))
	if err != nil {
		return bundle, err
	}
	_, err = s.db.W.ExecContext(ctx, `INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?)
		ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`, userID, settingKey(platform), sealed)
	return bundle, err
}

func (s *cookieStore) delete(ctx context.Context, userID int64, platform string) error {
	_, err := s.db.W.ExecContext(ctx, `DELETE FROM user_settings WHERE user_id = ? AND key = ?`, userID, settingKey(platform))
	return err
}

func (s *cookieStore) summary(ctx context.Context, userID int64, platform string) cookieSummary {
	bundle := s.read(ctx, userID, platform)
	if bundle == nil || len(bundle.Cookies) == 0 {
		var at *string
		if bundle != nil && bundle.ImportedAt != "" {
			at = &bundle.ImportedAt
		}
		return cookieSummary{ImportedAt: at}
	}
	var at *string
	if bundle.ImportedAt != "" {
		at = &bundle.ImportedAt
	}
	return cookieSummary{Configured: true, Count: len(bundle.Cookies), ImportedAt: at}
}

// header is the Cookie header for a platform's requests.
func (s *cookieStore) header(ctx context.Context, userID int64, platform string) string {
	bundle := s.read(ctx, userID, platform)
	if bundle == nil {
		return ""
	}
	var parts []string
	for _, c := range bundle.Cookies {
		if c == nil || !truthy(c["name"]) || c["value"] == nil {
			continue
		}
		parts = append(parts, jsTrim(text(c["name"]))+"="+text(c["value"]))
	}
	return strings.Join(parts, "; ")
}
