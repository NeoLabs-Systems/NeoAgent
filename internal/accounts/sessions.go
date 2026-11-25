package accounts

import (
	"context"
	"database/sql"
	"encoding/json"
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// SessionRecords keep a human-readable list of where an account is signed in
// (user_sessions), next to the session rows themselves. Only a keyed hash of a
// session id is stored here, never the id.
type SessionRecords struct {
	DB         *dbx.DB
	Store      *sessionx.Store
	Secret     string // session secret, keys the id hash
	TrustProxy bool
}

// Info describes one recorded sign-in.
type Info struct {
	Hash      string
	IsNew     bool
	Unusual   bool
	IPAddress string
	Location  string
	UserAgent string
}

type location struct {
	Label string
	Data  map[string]any
}

// locate classifies an address. Public addresses are not geolocated yet (no
// GeoIP database is bundled), so they read "Unknown".
func locate(ip string) location {
	parsed := net.ParseIP(ip)
	switch {
	case ip == "" || parsed == nil:
		return location{"Unknown", map[string]any{}}
	case parsed.IsLoopback():
		return location{"Local network", map[string]any{"kind": "loopback"}}
	case parsed.IsPrivate() || parsed.IsLinkLocalUnicast():
		return location{"Private network", map[string]any{"kind": "private"}}
	}
	return location{"Unknown", map[string]any{}}
}

func userAgent(r *http.Request) string {
	ua := r.Header.Get("User-Agent")
	if len(ua) > 500 {
		ua = ua[:500]
	}
	return ua
}

const activeWhere = `revoked_at IS NULL AND (expires_at IS NULL OR datetime(expires_at) > datetime('now'))`

func isoMillis(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }

// Record upserts the record for the current session. A sign-in from a device
// and place unlike any recent one is reported as unusual.
func (s *SessionRecords) Record(ctx context.Context, sid string, r *http.Request, userID int64, expires time.Time, login bool) (*Info, error) {
	ip := httpx.ClientIP(r, s.TrustProxy)
	geo := locate(ip)
	hash := sessionx.HashID(s.Secret, sid)
	ua := userAgent(r)

	var existing int64
	err := s.DB.R.QueryRowContext(ctx, `SELECT id FROM user_sessions WHERE session_hash = ?`, hash).Scan(&existing)
	isNew := err == sql.ErrNoRows
	if err != nil && !isNew {
		return nil, err
	}
	unusual := false
	if login && isNew {
		unusual, err = s.looksUnusual(ctx, userID, hash, ip, geo.Label, ua)
		if err != nil {
			return nil, err
		}
	}
	dataJSON, _ := json.Marshal(geo.Data)
	_, err = s.DB.W.ExecContext(ctx, `
		INSERT INTO user_sessions (user_id, session_hash, ip_address, user_agent, location_label, location_json,
		                           created_at, last_seen_at, expires_at, revoked_at)
		VALUES (?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'), ?, NULL)
		ON CONFLICT(session_hash) DO UPDATE SET
		  user_id = excluded.user_id, ip_address = excluded.ip_address, user_agent = excluded.user_agent,
		  location_label = excluded.location_label, location_json = excluded.location_json,
		  last_seen_at = datetime('now'), expires_at = excluded.expires_at, revoked_at = NULL`,
		userID, hash, nullable(ip), ua, geo.Label, string(dataJSON), isoMillis(expires))
	if err != nil {
		return nil, err
	}
	return &Info{Hash: hash, IsNew: isNew, Unusual: unusual, IPAddress: ip, Location: geo.Label, UserAgent: ua}, nil
}

func (s *SessionRecords) looksUnusual(ctx context.Context, userID int64, hash, ip, label, ua string) (bool, error) {
	rows, err := s.DB.R.QueryContext(ctx, `
		SELECT ip_address, user_agent, location_label FROM user_sessions
		WHERE user_id = ? AND session_hash != ? AND `+activeWhere+`
		ORDER BY datetime(last_seen_at) DESC LIMIT 20`, userID, hash)
	if err != nil {
		return false, err
	}
	defer rows.Close()
	any := false
	for rows.Next() {
		any = true
		var pip, pua, ploc sql.NullString
		if err := rows.Scan(&pip, &pua, &ploc); err != nil {
			return false, err
		}
		sameDevice := pip.String == ip && pua.String == ua
		sameLocation := label != "" && label != "Unknown" && ploc.String == label
		if sameDevice || sameLocation {
			return false, nil
		}
	}
	return any, rows.Err()
}

// Listed is one entry of the sessions page.
type Listed struct {
	ID           int64          `json:"id"`
	Current      bool           `json:"current"`
	IPAddress    *string        `json:"ipAddress"`
	UserAgent    string         `json:"userAgent"`
	Location     string         `json:"location"`
	LocationData map[string]any `json:"locationData"`
	CreatedAt    *string        `json:"createdAt"`
	LastSeenAt   *string        `json:"lastSeenAt"`
	ExpiresAt    *string        `json:"expiresAt"`
}

func (s *SessionRecords) prune(ctx context.Context) {
	// Session metadata must never block the account page.
	_, _ = s.DB.W.ExecContext(ctx, `
		UPDATE user_sessions SET revoked_at = COALESCE(revoked_at, datetime('now'))
		WHERE expires_at IS NOT NULL AND datetime(expires_at) <= datetime('now') AND revoked_at IS NULL`)
}

// List returns the account's live sessions, newest first.
func (s *SessionRecords) List(ctx context.Context, userID int64, currentSID string) ([]Listed, error) {
	s.prune(ctx)
	current := ""
	if currentSID != "" {
		current = sessionx.HashID(s.Secret, currentSID)
	}
	rows, err := s.DB.R.QueryContext(ctx, `
		SELECT id, session_hash, ip_address, user_agent, location_label, location_json, created_at, last_seen_at, expires_at
		FROM user_sessions WHERE user_id = ? AND `+activeWhere+`
		ORDER BY datetime(last_seen_at) DESC, id DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Listed{}
	for rows.Next() {
		var l Listed
		var hash string
		var ip, ua, label, dataJSON, created, seen, expires sql.NullString
		if err := rows.Scan(&l.ID, &hash, &ip, &ua, &label, &dataJSON, &created, &seen, &expires); err != nil {
			return nil, err
		}
		l.Current = current != "" && current == hash
		l.IPAddress = strPtr(ip)
		l.UserAgent = ua.String
		l.Location = label.String
		if l.Location == "" {
			l.Location = "Unknown"
		}
		l.LocationData = map[string]any{}
		_ = json.Unmarshal([]byte(dataJSON.String), &l.LocationData)
		if l.LocationData == nil {
			l.LocationData = map[string]any{}
		}
		l.CreatedAt, l.LastSeenAt, l.ExpiresAt = strPtr(created), strPtr(seen), strPtr(expires)
		out = append(out, l)
	}
	return out, rows.Err()
}

func strPtr(s sql.NullString) *string {
	if !s.Valid || s.String == "" {
		return nil
	}
	return &s.String
}

// Revoke ends one of the account's other sessions.
func (s *SessionRecords) Revoke(ctx context.Context, userID int64, recordID int64, currentSID string) error {
	var hash string
	err := s.DB.R.QueryRowContext(ctx, `SELECT session_hash FROM user_sessions WHERE id = ? AND user_id = ? AND revoked_at IS NULL`, recordID, userID).Scan(&hash)
	if err == sql.ErrNoRows {
		return fail(404, "Session not found", "")
	}
	if err != nil {
		return err
	}
	if currentSID != "" && hash == sessionx.HashID(s.Secret, currentSID) {
		return fail(400, "Use logout to end the current session", "")
	}
	if err := s.destroySessionsWithHashes(ctx, userID, map[string]bool{hash: true}); err != nil {
		return err
	}
	_, err = s.DB.W.ExecContext(ctx, `UPDATE user_sessions SET revoked_at = datetime('now') WHERE id = ? AND user_id = ?`, recordID, userID)
	return err
}

// RevokeAll ends every session of the account except exceptSID (use "" for all).
func (s *SessionRecords) RevokeAll(ctx context.Context, userID int64, exceptSID string) (int, error) {
	keep := ""
	if exceptSID != "" {
		keep = sessionx.HashID(s.Secret, exceptSID)
	}
	rows, err := s.DB.R.QueryContext(ctx, `SELECT session_hash FROM user_sessions WHERE user_id = ? AND revoked_at IS NULL`, userID)
	if err != nil {
		return 0, err
	}
	hashes := map[string]bool{}
	for rows.Next() {
		var h string
		if err := rows.Scan(&h); err != nil {
			rows.Close()
			return 0, err
		}
		if h != keep {
			hashes[h] = true
		}
	}
	rows.Close()
	if err := s.destroySessionsWithHashes(ctx, userID, hashes); err != nil {
		return 0, err
	}
	for h := range hashes {
		if _, err := s.DB.W.ExecContext(ctx, `UPDATE user_sessions SET revoked_at = datetime('now') WHERE session_hash = ? AND user_id = ?`, h, userID); err != nil {
			return 0, err
		}
	}
	return len(hashes), nil
}

// destroySessionsWithHashes deletes the session rows whose id hashes are in the
// set. Only this account's sessions are looked at.
func (s *SessionRecords) destroySessionsWithHashes(ctx context.Context, userID int64, hashes map[string]bool) error {
	if len(hashes) == 0 {
		return nil
	}
	ids, err := s.Store.IDsForUser(ctx, strconv.FormatInt(userID, 10))
	if err != nil {
		return err
	}
	for _, sid := range ids {
		if hashes[sessionx.HashID(s.Secret, sid)] {
			if err := s.Store.Destroy(ctx, sid); err != nil {
				return err
			}
		}
	}
	return nil
}

// Locate describes where an address is: a label and a JSON object of details.
// Public addresses are not geolocated (no GeoIP database is bundled).
func Locate(ip string) (label, dataJSON string) {
	l := locate(ip)
	raw, _ := json.Marshal(l.Data)
	return l.Label, string(raw)
}
