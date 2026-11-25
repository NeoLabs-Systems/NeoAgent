package webshares

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"unicode"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/google/uuid"
	"golang.org/x/text/unicode/norm"
)

// Shared web pages (services/web_shares): an app running in the owner's
// computer, served at /<username>/<slug>/ while that computer runs.

const (
	settingKey     = "web_sharing_enabled"
	maxShares      = 20
	guestAgentPort = 8421
)

// reserved are first path segments the server already answers; an account
// named like one cannot share.
var reserved = map[string]bool{
	"api": true, "app": true, "socket.io": true, "_neolabs": true, "status": true, "login": true, "logout": true, "auth": true, "health": true,
	"assets": true, "css": true, "images": true, "js": true, "index.html": true, "status.html": true, "404.html": true,
	"app-build.json": true, "favicon.ico": true, "robots.txt": true, "sitemap.xml": true, ".well-known": true,
}

// Store keeps the web_shares rows.
type Store struct {
	DB     *dbx.DB
	Getenv func(string) string
}

// Allowed is the admin's server-wide switch (NEOAGENT_WEB_SHARING), on unless
// turned off.
func (s *Store) Allowed() bool {
	value := ""
	if s.Getenv != nil {
		value = strings.ToLower(strings.TrimSpace(s.Getenv("NEOAGENT_WEB_SHARING")))
	}
	if value == "" {
		return true
	}
	return value == "1" || value == "true" || value == "yes" || value == "on"
}

// Enabled reports whether a user may share: on unless the admin or the owner
// turned it off. An unreadable setting counts as off.
func (s *Store) Enabled(ctx context.Context, userID int64) bool {
	if userID == 0 || !s.Allowed() {
		return false
	}
	var raw string
	err := s.DB.R.QueryRowContext(ctx, `SELECT value FROM user_settings WHERE user_id = ? AND key = ?`, userID, settingKey).Scan(&raw)
	if errors.Is(err, sql.ErrNoRows) {
		return true
	}
	if err != nil {
		return false
	}
	var v any
	if json.Unmarshal([]byte(raw), &v) != nil {
		return false
	}
	return v != false
}

var (
	nonAlnum   = regexp.MustCompile(`[^a-z0-9]+`)
	edgeDash   = regexp.MustCompile(`^-+|-+$`)
	trailDash  = regexp.MustCompile(`-+$`)
	slugPrefix = 48
)

// SlugFor is the URL slug of a share name.
func SlugFor(name string) string {
	var b strings.Builder
	for _, r := range norm.NFKD.String(name) {
		if r >= 0x300 && r <= 0x36F {
			continue
		}
		b.WriteRune(unicode.ToLower(r))
	}
	s := edgeDash.ReplaceAllString(nonAlnum.ReplaceAllString(strings.ToLower(b.String()), "-"), "")
	if len(s) > slugPrefix {
		s = s[:slugPrefix]
	}
	return trailDash.ReplaceAllString(s, "")
}

// encodeComponent is encodeURIComponent.
func encodeComponent(s string) string {
	return strings.NewReplacer("+", "%20", "%21", "!", "%27", "'", "%28", "(", "%29", ")", "%2A", "*", "%7E", "~").Replace(url.QueryEscape(s))
}

func isReserved(segment string) bool { return reserved[strings.ToLower(segment)] }

func shareURL(baseURL, username, slug string) string {
	return strings.TrimRight(baseURL, "/") + "/" + encodeComponent(username) + "/" + slug + "/"
}

func (s *Store) username(ctx context.Context, userID int64) (string, error) {
	var name string
	err := s.DB.R.QueryRowContext(ctx, `SELECT username FROM users WHERE id = ?`, userID).Scan(&name)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil
	}
	return name, err
}

// Share is a shared page as the tool and the settings page list it.
type Share struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Slug      string `json:"slug"`
	Port      int64  `json:"port"`
	URL       string `json:"url"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
}

type shareRow struct {
	id, slug, title, createdAt, updatedAt string
	port                                  int64
}

const rowColumns = `id, slug, COALESCE(title, ''), port, created_at, updated_at`

func scanRow(sc interface{ Scan(...any) error }) (shareRow, error) {
	var r shareRow
	err := sc.Scan(&r.id, &r.slug, &r.title, &r.port, &r.createdAt, &r.updatedAt)
	return r, err
}

func describe(r shareRow, username, baseURL string) Share {
	name := r.title
	if name == "" {
		name = r.slug
	}
	return Share{ID: r.id, Name: name, Slug: r.slug, Port: r.port, URL: shareURL(baseURL, username, r.slug), CreatedAt: r.createdAt, UpdatedAt: r.updatedAt}
}

// List lists a user's shares, oldest first.
func (s *Store) List(ctx context.Context, userID int64, baseURL string) ([]Share, error) {
	username, err := s.username(ctx, userID)
	if err != nil {
		return nil, err
	}
	rows, err := s.DB.R.QueryContext(ctx, `SELECT `+rowColumns+` FROM web_shares WHERE user_id = ? ORDER BY created_at, id`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Share{}
	for rows.Next() {
		r, err := scanRow(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, describe(r, username, baseURL))
	}
	return out, rows.Err()
}

// ValidatePort is a port an app may listen on in the computer, or 0.
func ValidatePort(value any) int {
	var n float64
	switch v := value.(type) {
	case float64:
		n = v
	case int:
		n = float64(v)
	case string:
		f, err := strconv.ParseFloat(strings.TrimSpace(v), 64)
		if err != nil {
			return 0
		}
		if strings.TrimSpace(v) == "" {
			return 0
		}
		n = f
	default:
		return 0
	}
	if n != math.Trunc(n) || n < 1 || n > 65535 || n == guestAgentPort {
		return 0
	}
	return int(n)
}

// UserError is a refusal the tool reports as {error}.
type UserError struct{ Msg string }

func (e *UserError) Error() string { return e.Msg }

// trimSlice120 is String(name).trim().slice(0, 120) in UTF-16 units.
func trimSlice120(name string) string {
	s := strings.TrimSpace(name)
	units := 0
	for i, r := range s {
		w := 1
		if r > 0xFFFF {
			w = 2
		}
		if units+w > 120 {
			return s[:i]
		}
		units += w
	}
	return s
}

// Save creates the share, or points the one with the same name at the port.
func (s *Store) Save(ctx context.Context, userID int64, agentID, name string, port int, baseURL string) (Share, bool, error) {
	username, err := s.username(ctx, userID)
	if err != nil {
		return Share{}, false, err
	}
	if username == "" {
		return Share{}, false, &UserError{"Unknown account."}
	}
	if isReserved(encodeComponent(username)) {
		return Share{}, false, &UserError{`Pages cannot be shared under the account name "` + username + `", which the server uses for its own pages.`}
	}
	slug := SlugFor(name)
	if slug == "" {
		return Share{}, false, &UserError{"name needs at least one letter or digit."}
	}
	var agent any
	if agentID != "" {
		agent = agentID
	}
	var existing string
	err = s.DB.R.QueryRowContext(ctx, `SELECT id FROM web_shares WHERE user_id = ? AND slug = ?`, userID, slug).Scan(&existing)
	switch {
	case errors.Is(err, sql.ErrNoRows):
		var count int
		if err := s.DB.R.QueryRowContext(ctx, `SELECT COUNT(*) FROM web_shares WHERE user_id = ?`, userID).Scan(&count); err != nil {
			return Share{}, false, err
		}
		if count >= maxShares {
			return Share{}, false, &UserError{fmt.Sprintf("At most %d pages can be shared at once; stop sharing one first.", maxShares)}
		}
		if _, err := s.DB.W.ExecContext(ctx, `INSERT INTO web_shares (id, user_id, agent_id, slug, title, port) VALUES (?, ?, ?, ?, ?, ?)`,
			uuid.NewString(), userID, agent, slug, trimSlice120(name), port); err != nil {
			return Share{}, false, err
		}
	case err != nil:
		return Share{}, false, err
	default:
		if _, err := s.DB.W.ExecContext(ctx, `UPDATE web_shares SET port = ?, title = ?, agent_id = ?, updated_at = datetime('now') WHERE id = ?`,
			port, trimSlice120(name), agent, existing); err != nil {
			return Share{}, false, err
		}
	}
	r, err := scanRow(s.DB.R.QueryRowContext(ctx, `SELECT `+rowColumns+` FROM web_shares WHERE user_id = ? AND slug = ?`, userID, slug))
	if err != nil {
		return Share{}, false, err
	}
	return describe(r, username, baseURL), existing != "", nil
}

// Remove stops a share by id, slug or the name it was shared under.
func (s *Store) Remove(ctx context.Context, userID int64, ref string) (bool, error) {
	key := strings.TrimSpace(ref)
	if key == "" {
		return false, nil
	}
	slug := SlugFor(key)
	if slug == "" {
		slug = key
	}
	res, err := s.DB.W.ExecContext(ctx, `DELETE FROM web_shares WHERE user_id = ? AND (id = ? OR slug = ?)`, userID, key, slug)
	if err != nil {
		return false, err
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}

// publicShare is a live share and its owner.
type publicShare struct {
	userID      int64
	username    string
	slug, title string
	port        int64
}

// findPublic is the share a public address points at, if its owner still
// allows sharing.
func (s *Store) findPublic(ctx context.Context, segment, slug string) (*publicShare, error) {
	if isReserved(segment) {
		return nil, nil
	}
	username, err := url.PathUnescape(segment)
	if err != nil {
		return nil, nil
	}
	var p publicShare
	err = s.DB.R.QueryRowContext(ctx, `SELECT id, username FROM users WHERE lower(username) = lower(?)`, username).Scan(&p.userID, &p.username)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if !s.Enabled(ctx, p.userID) {
		return nil, nil
	}
	err = s.DB.R.QueryRowContext(ctx, `SELECT slug, COALESCE(title, ''), port FROM web_shares WHERE user_id = ? AND slug = ?`, p.userID, strings.ToLower(slug)).
		Scan(&p.slug, &p.title, &p.port)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}
