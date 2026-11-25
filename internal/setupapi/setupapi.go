package setupapi

import (
	"context"
	"crypto/rand"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"os"
	"slices"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

var completionSections = []string{"core", "network", "providers", "integrations", "voice", "optional-capabilities"}

// Config configures the setup API.
type Config struct {
	DB      *dbx.DB
	Version string
	Getenv  func(string) string
	UserID  func(*http.Request) (int64, bool)
}

// API serves /api/setup/*.
type API struct {
	cfg Config
}

// New creates a setup API.
func New(cfg Config) *API {
	if cfg.Getenv == nil {
		cfg.Getenv = os.Getenv
	}
	if cfg.Version == "" {
		cfg.Version = "dev"
	}
	return &API{cfg: cfg}
}

// Routes registers /api/setup/handshake and /api/setup/status.
func (a *API) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/setup/handshake", a.handleHandshake)
	mux.HandleFunc("GET /api/setup/status", a.handleStatus)
}

func (a *API) ensureInstance(ctx context.Context) (instanceID, displayName string) {
	return EnsureInstance(ctx, a.cfg.DB, a.cfg.Getenv)
}

// EnsureInstance returns the instance's id and name, creating them on first
// use. The CLI calls it before the first start so it can tell its own server
// from another NeoAgent on the same port.
func EnsureInstance(ctx context.Context, db *dbx.DB, getenv func(string) string) (instanceID, displayName string) {
	if db == nil {
		return "local", "NeoAgent"
	}
	err := db.R.QueryRowContext(ctx, `SELECT instance_id, display_name FROM neoagent_instance WHERE singleton_id = 1`).Scan(&instanceID, &displayName)
	if err == nil {
		return instanceID, displayName
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "local", "NeoAgent"
	}
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	instanceID = fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
	displayName = strings.TrimSpace(getenv("NEOAGENT_INSTANCE_NAME"))
	if displayName == "" {
		if h, err := os.Hostname(); err == nil && h != "" {
			displayName = h
		} else {
			displayName = "NeoAgent"
		}
	}
	if len(displayName) > 80 {
		displayName = displayName[:80]
	}
	_, _ = db.W.ExecContext(ctx, `INSERT OR IGNORE INTO neoagent_instance (singleton_id, instance_id, display_name) VALUES (1, ?, ?)`, instanceID, displayName)
	_ = db.R.QueryRowContext(ctx, `SELECT instance_id, display_name FROM neoagent_instance WHERE singleton_id = 1`).Scan(&instanceID, &displayName)
	return instanceID, displayName
}

func (a *API) handleHandshake(w http.ResponseWriter, r *http.Request) {
	instanceID, displayName := a.ensureInstance(r.Context())
	var count int
	if a.cfg.DB != nil {
		_ = a.cfg.DB.R.QueryRowContext(r.Context(), `SELECT COUNT(*) FROM users`).Scan(&count)
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"product":          "NeoAgent",
		"protocolVersion":  1,
		"serverVersion":    a.cfg.Version,
		"instanceId":       instanceID,
		"displayName":      displayName,
		"claimed":          count > 0,
		"pairingSupported": true,
		"capabilities":     []string{"qr-login"},
	})
}

func (a *API) handleStatus(w http.ResponseWriter, r *http.Request) {
	var uid int64
	var ok bool
	if a.cfg.UserID != nil {
		uid, ok = a.cfg.UserID(r)
	} else if sess := sessionx.FromContext(r.Context()); sess != nil {
		uid, ok = sess.Int64("userId")
	}
	if !ok || uid <= 0 {
		httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
		return
	}

	profile := "quick"
	if a.cfg.Getenv("NEOAGENT_SETUP_PROFILE") == "full" {
		profile = "full"
	}
	rawCompleted := a.cfg.Getenv("NEOAGENT_SETUP_COMPLETED_SECTIONS")
	if rawCompleted == "" {
		rawCompleted = "core"
	}
	doneSet := map[string]bool{}
	for _, s := range strings.Split(rawCompleted, ",") {
		s = strings.TrimSpace(s)
		if slices.Contains(completionSections, s) {
			doneSet[s] = true
		}
	}
	completed := []string{}
	open := []string{}
	for _, s := range completionSections {
		if doneSet[s] {
			completed = append(completed, s)
		} else {
			open = append(open, s)
		}
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"schemaVersion":     1,
		"profile":           profile,
		"completedSections": completed,
		"openSections":      open,
		"complete":          len(open) == 0,
	})
}

// MarkSectionComplete persists a completed setup section in contract order.
func MarkSectionComplete(section string, getenv func(string) string, persist func(string, string) error) error {
	if !slices.Contains(completionSections, section) {
		return nil
	}
	raw := getenv("NEOAGENT_SETUP_COMPLETED_SECTIONS")
	if raw == "" {
		raw = "core"
	}
	done := map[string]bool{section: true}
	for _, part := range strings.Split(raw, ",") {
		done[strings.TrimSpace(part)] = true
	}
	var result []string
	for _, name := range completionSections {
		if done[name] {
			result = append(result, name)
		}
	}
	return persist("NEOAGENT_SETUP_COMPLETED_SECTIONS", strings.Join(result, ","))
}
