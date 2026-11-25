package accounterase

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/ratelimit"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const sessionCookie = "neoagent.sid"

// API serves the two account routes.
type API struct {
	*Eraser
	limiter      *ratelimit.Limiter
	secureCookie bool
}

// Config wires the routes.
type Config struct {
	Eraser *Eraser
	// SecureCookie marks the cleared session cookie Secure, like the session
	// cookie itself.
	SecureCookie bool
	TrustProxy   bool
}

// New builds the API.
func New(cfg Config) *API {
	return &API{
		Eraser:       cfg.Eraser,
		secureCookie: cfg.SecureCookie,
		limiter: ratelimit.New(ratelimit.Config{
			Window:  15 * time.Minute,
			Max:     30,
			Message: map[string]string{"error": "Too many account security attempts, try again later"},
			Key:     func(r *http.Request) string { return httpx.ClientIP(r, cfg.TrustProxy) },
		}),
	}
}

// Routes registers GET /api/account/export and POST /api/account/delete.
func (a *API) Routes(mux *http.ServeMux) {
	mux.Handle("GET /api/account/export", a.auth(a.limiter.Middleware(http.HandlerFunc(a.export))))
	mux.Handle("POST /api/account/delete", a.auth(a.limiter.Middleware(http.HandlerFunc(a.delete))))
}

func (a *API) auth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := sessionUser(r); !ok {
			httpx.Error(w, http.StatusUnauthorized, "Unauthorized")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func sessionUser(r *http.Request) (int64, bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}

func (a *API) fail(w http.ResponseWriter, err error) {
	if a.Log != nil {
		a.Log.Error("account route failed", "error", err)
	}
	httpx.Error(w, http.StatusInternalServerError, "Something went wrong. Please try again.")
}

func (a *API) export(w http.ResponseWriter, r *http.Request) {
	uid, _ := sessionUser(r)
	payload, err := a.Export(r.Context(), uid)
	switch {
	case errors.Is(err, ErrNotFound):
		httpx.Error(w, http.StatusNotFound, "Account not found.")
		return
	case err != nil:
		a.fail(w, err)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="neoagent-data-export-`+strconv.FormatInt(uid, 10)+`.json"`)
	_, _ = w.Write(payload)
}

func (a *API) delete(w http.ResponseWriter, r *http.Request) {
	uid, _ := sessionUser(r)
	var username string
	var admin int64
	err := a.DB.W.QueryRowContext(r.Context(), `SELECT username, COALESCE(is_admin, 0) FROM users WHERE id = ?`, uid).Scan(&username, &admin)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			httpx.Error(w, http.StatusNotFound, "Account not found.")
			return
		}
		a.fail(w, err)
		return
	}
	// An install's admin deleting themselves could leave nobody able to reach
	// the admin page; admin is removed from the operator side first.
	if admin == 1 {
		httpx.WriteJSON(w, http.StatusForbidden, struct {
			Error string `json:"error"`
			Code  string `json:"code"`
		}{"Admin accounts can’t delete themselves. Ask the operator to run `neoagent admin revoke <username>` first.", "ADMIN_SELF_DELETE"})
		return
	}
	if confirmed(r) != username {
		httpx.Error(w, http.StatusBadRequest, "Confirmation does not match your username.")
		return
	}
	tables, err := a.Erase(r.Context(), uid)
	switch {
	case errors.Is(err, ErrNotFound):
		httpx.Error(w, http.StatusNotFound, "Account not found.")
		return
	case err != nil:
		a.fail(w, err)
		return
	}
	sessionx.FromContext(r.Context()).Destroy()
	http.SetCookie(w, &http.Cookie{
		Name: sessionCookie, Value: "", Path: "/", HttpOnly: true,
		SameSite: http.SameSiteLaxMode, Secure: a.secureCookie,
		Expires: time.Unix(0, 0), MaxAge: -1,
	})
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true, "tablesCleared": tables})
}

// confirmed reads the typed username like Node's String(body.confirmUsername ||
// ”).trim(): a missing or falsy member counts as empty.
func confirmed(r *http.Request) string {
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, 1<<20))
	if err != nil || !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return ""
	}
	var body struct {
		Confirm any `json:"confirmUsername"`
	}
	if json.NewDecoder(bytes.NewReader(raw)).Decode(&body) != nil {
		return ""
	}
	switch v := body.Confirm.(type) {
	case nil:
		return ""
	case bool:
		if !v {
			return ""
		}
		return "true"
	case float64:
		if v == 0 {
			return ""
		}
		return strings.TrimSpace(fmt.Sprint(v))
	case string:
		return strings.TrimSpace(v)
	}
	return ""
}
