// Package agentscope answers "which agent is this request about?". Every
// account has a main agent; a request may name another one of its agents by id
// or slug (body, query or X-Agent-Id header), and anything unknown falls back
// to the account's default agent. It reads and writes the same agents table as
// the Node server's agents manager.
package agentscope

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

const mainSlug = "main"

// Resolver finds agents. It creates the account's main agent on first use, as
// Node did.
type Resolver struct{ DB *dbx.DB }

var slugJunk = regexp.MustCompile(`[^a-z0-9_-]+`)

func normalizeSlug(value string) string {
	slug := strings.Trim(slugJunk.ReplaceAllString(strings.ToLower(strings.TrimSpace(value)), "-"), "-")
	if len(slug) > 48 {
		slug = slug[:48]
	}
	return slug
}

func newID() (string, error) {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	h := hex.EncodeToString(b[:])
	return fmt.Sprintf("%s-%s-%s-%s-%s", h[:8], h[8:12], h[12:16], h[16:20], h[20:]), nil
}

// ensureMain returns the id of the user's main agent, creating it (and making
// it the default) when the account has none yet.
func (r Resolver) ensureMain(ctx context.Context, userID int64) (string, error) {
	var id string
	var isDefault sql.NullInt64
	err := r.DB.W.QueryRowContext(ctx, `SELECT id, is_default FROM agents WHERE user_id = ? AND slug = ?`, userID, mainSlug).Scan(&id, &isDefault)
	switch {
	case err == nil:
		if isDefault.Int64 == 0 {
			err = r.makeDefault(ctx, userID, id)
		}
		return id, err
	case !errors.Is(err, sql.ErrNoRows):
		return "", err
	}

	id, err = newID()
	if err != nil {
		return "", err
	}
	// The unique (user_id, slug) index settles a race between two requests.
	_, err = r.DB.W.ExecContext(ctx, `INSERT INTO agents (
		id, user_id, slug, display_name, description, responsibilities, instructions,
		status, is_default, can_delegate, can_be_delegated_to, delegate_targets_json
	) VALUES (?, ?, ?, ?, ?, ?, ?, 'active', 1, 1, 0, '[]') ON CONFLICT(user_id, slug) DO NOTHING`,
		id, userID, mainSlug, "Main",
		"Default personal AI contact and fallback agent.",
		"Handle general requests. Delegate to specialist agents only when their responsibilities clearly match.", "")
	if err != nil {
		return "", err
	}
	if err := r.DB.W.QueryRowContext(ctx, `SELECT id FROM agents WHERE user_id = ? AND slug = ?`, userID, mainSlug).Scan(&id); err != nil {
		return "", err
	}
	return id, r.makeDefault(ctx, userID, id)
}

func (r Resolver) makeDefault(ctx context.Context, userID int64, id string) error {
	_, err := r.DB.W.ExecContext(ctx, `UPDATE agents SET is_default = CASE WHEN id = ? THEN 1 ELSE 0 END WHERE user_id = ?`, id, userID)
	return err
}

func (r Resolver) defaultAgent(ctx context.Context, userID int64) (string, error) {
	var id string
	err := r.DB.W.QueryRowContext(ctx,
		`SELECT id FROM agents WHERE user_id = ? AND is_default = 1 AND status != 'archived' ORDER BY updated_at DESC LIMIT 1`, userID).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return r.ensureMain(ctx, userID)
	}
	return id, err
}

func (r Resolver) lookup(ctx context.Context, query string, args ...any) (string, error) {
	var id string
	err := r.DB.W.QueryRowContext(ctx, query, args...).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil
	}
	return id, err
}

// Resolve returns the id of the agent candidate names (an id or a slug) among
// the user's agents, or the user's default agent when it names none of them.
func (r Resolver) Resolve(ctx context.Context, userID int64, candidate string) (string, error) {
	if _, err := r.ensureMain(ctx, userID); err != nil {
		return "", err
	}
	raw := strings.TrimSpace(candidate)
	if raw == "" {
		return r.defaultAgent(ctx, userID)
	}
	if id, err := r.lookup(ctx, `SELECT id FROM agents WHERE user_id = ? AND id = ?`, userID, raw); err != nil || id != "" {
		return id, err
	}
	if slug := normalizeSlug(raw); slug != "" {
		if id, err := r.lookup(ctx, `SELECT id FROM agents WHERE user_id = ? AND slug = ?`, userID, slug); err != nil || id != "" {
			return id, err
		}
	}
	return r.defaultAgent(ctx, userID)
}

// IsMain reports whether agentID is the user's main agent.
func (r Resolver) IsMain(ctx context.Context, userID int64, agentID string) (bool, error) {
	if agentID == "" {
		return false, nil
	}
	id, err := r.lookup(ctx, `SELECT id FROM agents WHERE user_id = ? AND id = ? AND slug = ?`, userID, agentID, mainSlug)
	return id != "", err
}

// Candidate is the agent a request names: body agentId or agent_id, the same
// inside body.options, the agentId or agent_id query parameter, then the
// X-Agent-Id header. The first one that is set wins. body holds the request's
// top-level JSON members; it may be nil.
func Candidate(r *http.Request, body map[string]json.RawMessage) string {
	var options map[string]json.RawMessage
	if raw, ok := body["options"]; ok {
		_ = json.Unmarshal(raw, &options)
	}
	for _, raw := range []json.RawMessage{body["agentId"], body["agent_id"], options["agentId"], options["agent_id"]} {
		if s, ok := truthyString(raw); ok {
			return s
		}
	}
	query := r.URL.Query()
	for _, key := range []string{"agentId", "agent_id"} {
		if s := strings.Join(query[key], ","); s != "" {
			return s
		}
	}
	return r.Header.Get("X-Agent-Id")
}

// truthyString is `String(value)` for a JSON value JavaScript would treat as
// set (so not null, false, 0 or ""); anything but a string, number or boolean
// reads as text no agent has.
func truthyString(raw json.RawMessage) (string, bool) {
	if len(raw) == 0 {
		return "", false
	}
	var v any
	if err := json.Unmarshal(raw, &v); err != nil {
		return "", false
	}
	switch v := v.(type) {
	case string:
		return v, v != ""
	case float64:
		return strconv.FormatFloat(v, 'f', -1, 64), v != 0
	case bool:
		return "true", v
	case nil:
		return "", false
	}
	return "[object Object]", true
}
