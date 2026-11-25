package webshares

import (
	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
	"net/http"
	"os"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// Config configures the /api/web-shares routes.
type Config struct {
	DB              *dbx.DB
	Getenv          func(string) string
	ComputerRunning func(userID int64) bool
	UserID          func(*http.Request) (int64, bool)
}

// API serves /api/web-shares/*.
type API struct {
	cfg Config
}

// New creates a webshares API.
func New(cfg Config) *API {
	if cfg.Getenv == nil {
		cfg.Getenv = os.Getenv
	}
	return &API{cfg: cfg}
}

// Routes registers /api/web-shares endpoints on mux.
func (a *API) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/web-shares", a.requireAuth(a.handleList))
	mux.HandleFunc("DELETE /api/web-shares/{id}", a.requireAuth(a.handleDelete))
}

func (a *API) requireAuth(next func(http.ResponseWriter, *http.Request, int64)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
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
		next(w, r, uid)
	}
}

func (a *API) store() *Store { return &Store{DB: a.cfg.DB, Getenv: a.cfg.Getenv} }

// baseURL is publicBaseUrlForRequest: PUBLIC_URL, else the request's own.
func (a *API) baseURL(r *http.Request) string {
	if configured := strings.TrimSpace(a.cfg.Getenv("PUBLIC_URL")); configured != "" {
		return strings.TrimRight(configured, "/")
	}
	proto := strings.TrimSpace(r.Header.Get("X-Forwarded-Proto"))
	if proto == "" {
		proto = "http"
		if r.TLS != nil {
			proto = "https"
		}
	}
	return proto + "://" + r.Host
}

// handleList is the settings page's view of the shared pages.
func (a *API) handleList(w http.ResponseWriter, r *http.Request, userID int64) {
	store := a.store()
	if !store.Allowed() {
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"allowed": false})
		return
	}
	shares, err := store.List(r.Context(), userID, a.baseURL(r))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "Internal server error")
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"allowed":         true,
		"enabled":         store.Enabled(r.Context(), userID),
		"supported":       runtime.ParseTerminalEnv(a.cfg.Getenv("TERMINAL_ENV")) != runtime.TerminalHost,
		"computerRunning": a.cfg.ComputerRunning != nil && a.cfg.ComputerRunning(userID),
		"shares":          shares,
	})
}

func (a *API) handleDelete(w http.ResponseWriter, r *http.Request, userID int64) {
	removed, err := a.store().Remove(r.Context(), userID, r.PathValue("id"))
	if err != nil || !removed {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "Shared page not found."})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"stopped": true})
}
