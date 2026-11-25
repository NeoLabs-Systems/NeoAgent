package admin

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/ratelimit"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const (
	bodyLimit      = 10 << 20
	limiterWindow  = 15 * time.Minute
	settingsBudget = 20
	sqlBudget      = 60
)

// Deps is what the admin routes need.
type Deps struct {
	DB      *dbx.DB
	Records *accounts.SessionRecords
	// EnvFile is the .env file the settings routes write.
	EnvFile    string
	TrustProxy bool
	Log        *slog.Logger
	// ModelCatalog lists the ids of every model the server has discovered. It
	// belongs to the AI domain; without it the route that grants models to an
	// account is not registered.
	ModelCatalog func(ctx context.Context) ([]string, error)
	Extra        ExtraDeps
}

// API serves /api/admin/*.
type API struct {
	Store    *Store
	Settings *Settings

	records      *accounts.SessionRecords
	log          *slog.Logger
	catalog      func(ctx context.Context) ([]string, error)
	extra        ExtraDeps
	settingsRate *ratelimit.Limiter
	sqlRate      *ratelimit.Limiter

	updOnce sync.Once
	upd     *updater
}

// New builds the admin API.
func New(d Deps) *API {
	limiter := func(max int, message string) *ratelimit.Limiter {
		return ratelimit.New(ratelimit.Config{
			Window:  limiterWindow,
			Max:     max,
			Message: map[string]string{"error": message},
			Key:     func(r *http.Request) string { return httpx.ClientIP(r, d.TrustProxy) },
		})
	}
	return &API{
		Store:        &Store{DB: d.DB},
		Settings:     &Settings{Env: &EnvStore{File: d.EnvFile}},
		records:      d.Records,
		log:          d.Log,
		catalog:      d.ModelCatalog,
		extra:        d.Extra,
		settingsRate: limiter(settingsBudget, "Too many settings changes, slow down"),
		sqlRate:      limiter(sqlBudget, "Too many SQL queries, slow down"),
	}
}

// Routes registers the admin routes on mux.
func (a *API) Routes(mux *http.ServeMux) {
	route := func(pattern string, fn func(*http.Request) (any, error)) {
		mux.Handle(pattern, a.guard(a.respond(http.StatusOK, fn)))
	}
	write := func(pattern string, limiter *ratelimit.Limiter, status int, fn func(*http.Request) (any, error)) {
		mux.Handle(pattern, a.guard(limiter.Middleware(a.respond(status, fn))))
	}
	settings := func(pattern string, fn func(*http.Request) (any, error)) {
		write(pattern, a.settingsRate, http.StatusOK, fn)
	}

	route("GET /api/admin/users", a.listUsers)
	route("DELETE /api/admin/users/{id}/sessions", a.revokeSessions)
	settings("POST /api/admin/users/{id}/password", a.resetPassword)
	route("GET /api/admin/users/{id}/rate-limits", a.getUserRateLimits)
	route("PUT /api/admin/users/{id}/rate-limits", a.putUserRateLimits)
	route("GET /api/admin/users/{id}/allowed-models", a.getModelGrants)
	if a.catalog != nil {
		route("PUT /api/admin/users/{id}/allowed-models", a.putModelGrants)
	}
	route("GET /api/admin/config/rate-limits", a.getDefaultRateLimits)
	route("PUT /api/admin/config/rate-limits", a.putDefaultRateLimits)

	write("POST /api/admin/sql", a.sqlRate, http.StatusOK, a.runSQL)

	route("GET /api/admin/access", a.getAccess)
	settings("PUT /api/admin/access/signup", a.putSignup)
	route("GET /api/admin/signup-keys", a.listSignupKeys)
	write("POST /api/admin/signup-keys", a.settingsRate, http.StatusCreated, a.createSignupKeys)
	route("DELETE /api/admin/signup-keys/{id}", a.revokeSignupKey)

	route("PUT /api/admin/models/config", a.putModelsConfig)
	route("GET /api/admin/config/general", a.getGeneral)
	settings("PUT /api/admin/config/general", a.putGeneral)
	route("GET /api/admin/config/email", a.getEmail)
	settings("PUT /api/admin/config/email", a.putEmail)

	route("GET /api/admin/version", a.getVersion)
	route("GET /api/admin/update", a.getUpdateStatus)
	settings("POST /api/admin/update/check", a.postUpdateCheck)
	write("POST /api/admin/update", a.settingsRate, http.StatusAccepted, a.postUpdateStart)
	settings("PUT /api/admin/update/channel", a.putUpdateChannel)
	route("GET /api/admin/health", a.getHealth)
	route("GET /api/admin/logs", a.getLogs)
	route("GET /api/admin/analytics", a.getAnalytics)
	route("DELETE /api/admin/users/{id}", a.deleteUser)
	route("GET /api/admin/messaging", a.getMessaging)
	settings("PUT /api/admin/messaging/{platform}", a.putMessaging)
	settings("DELETE /api/admin/messaging/{platform}", a.deleteMessaging)
	route("GET /api/admin/providers", a.getProviders)
	route("PUT /api/admin/providers", a.putProviders)
	route("GET /api/admin/models", a.getModels)
	route("GET /api/admin/config/vm", a.getVMConfig)
	settings("PUT /api/admin/config/vm", a.putVMConfig)
	route("GET /api/admin/config/integrations", a.getIntegrationConfig)
	settings("PUT /api/admin/config/integrations", a.putIntegrationConfig)
}

// ---- access guard -----------------------------------------------------------

func sessionUser(r *http.Request) (int64, bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}

// guard answers 401 without a signed-in account and 403 unless that account
// holds the admin flag, which is read from the account row on every request.
func (a *API) guard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, ok := sessionUser(r)
		if !ok {
			httpx.Error(w, http.StatusUnauthorized, "Unauthorized")
			return
		}
		if !a.Store.IsAdmin(r.Context(), id) {
			httpx.WriteJSON(w, http.StatusForbidden, errorBody{Error: "Admin access required", Code: "ADMIN_REQUIRED"})
			return
		}
		next.ServeHTTP(w, r)
	})
}

// ---- request and response helpers -------------------------------------------

// body is a loosely typed JSON object, read like Express' `req.body?.field`.
type body map[string]any

func readBody(r *http.Request) (body, error) {
	if !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return body{}, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, bodyLimit))
	if err != nil {
		return nil, fail(http.StatusRequestEntityTooLarge, "Request body too large", "")
	}
	if len(bytes.TrimSpace(raw)) == 0 {
		return body{}, nil
	}
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	var v any
	if err := dec.Decode(&v); err != nil {
		return nil, fail(http.StatusBadRequest, "Invalid JSON body", "")
	}
	if m, ok := v.(map[string]any); ok {
		return body(m), nil
	}
	return body{}, nil
}

// respond runs fn and sends its value as JSON, or its error as the matching
// error response.
func (a *API) respond(status int, fn func(*http.Request) (any, error)) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		out, err := fn(r)
		if err != nil {
			a.fail(w, err)
			return
		}
		httpx.WriteJSON(w, status, out)
	})
}

// errorBody is the error envelope; the field order is the one Node writes.
type errorBody struct {
	Error string `json:"error"`
	Code  string `json:"code,omitempty"`
}

// fail maps an error to its response: a *accounts.Error carries its own status
// and code; anything else is a 500 whose text is cleaned of paths and secrets.
func (a *API) fail(w http.ResponseWriter, err error) {
	var he *accounts.Error
	if errors.As(err, &he) && he.Status < 500 {
		httpx.WriteJSON(w, he.Status, errorBody{Error: he.Message, Code: he.Code})
		return
	}
	status := http.StatusInternalServerError
	if he != nil {
		status = he.Status
	}
	a.log.Error("admin route failed", "error", err)
	httpx.WriteJSON(w, status, errorBody{Error: publicerr.Sanitize(err.Error(), "", "")})
}

// userID reads the `{id}` route parameter: a positive integer naming an account.
func userID(r *http.Request) (int64, error) {
	id, ok := positiveID(r.PathValue("id"))
	if !ok {
		return 0, fail(http.StatusBadRequest, "Invalid user id", "INVALID_USER_ID")
	}
	return id, nil
}

// withUser reads the `{id}` route parameter, then runs fn with it.
func withUser(r *http.Request, fn func(id int64) (any, error)) (any, error) {
	id, err := userID(r)
	if err != nil {
		return nil, err
	}
	return fn(id)
}

func actor(r *http.Request) int64 {
	id, _ := sessionUser(r)
	return id
}

// ---- users ------------------------------------------------------------------

func (a *API) listUsers(r *http.Request) (any, error) {
	search := strings.Join(r.URL.Query()["q"], ",")
	users, err := a.Store.ListUsers(r.Context(), search)
	return map[string]any{"users": users}, err
}

func (a *API) revokeSessions(r *http.Request) (any, error) {
	return withUser(r, func(id int64) (any, error) {
		if _, err := a.records.RevokeAll(r.Context(), id, ""); err != nil {
			return nil, err
		}
		return map[string]any{"ok": true}, nil
	})
}

func truthy(v any) bool {
	switch v := v.(type) {
	case nil:
		return false
	case bool:
		return v
	case string:
		return v != ""
	case json.Number:
		f := jsToNumber(v)
		return f != 0
	}
	return true
}

func (a *API) resetPassword(r *http.Request) (any, error) {
	return withUser(r, func(id int64) (any, error) {
		b, err := readBody(r)
		if err != nil {
			return nil, err
		}
		password := ""
		if truthy(b["password"]) {
			password = jsString(b["password"])
		}
		if err := a.Store.ResetPassword(r.Context(), id, password, actor(r)); err != nil {
			return nil, err
		}
		if _, err := a.records.RevokeAll(r.Context(), id, ""); err != nil {
			return nil, err
		}
		a.log.Info("admin reset an account password", "admin", actor(r), "account", id)
		return map[string]any{"success": true}, nil
	})
}

func (a *API) getUserRateLimits(r *http.Request) (any, error) {
	return withUser(r, func(id int64) (any, error) {
		limits, err := a.Store.UserRateLimits(r.Context(), id)
		return map[string]any{"limits": limits}, err
	})
}

func (a *API) putUserRateLimits(r *http.Request) (any, error) {
	return withUser(r, func(id int64) (any, error) {
		b, err := readBody(r)
		if err != nil {
			return nil, err
		}
		fourHour, err := parseLimit(b["rate_limit_4h"], "rate_limit_4h")
		if err != nil {
			return nil, err
		}
		weekly, err := parseLimit(b["rate_limit_weekly"], "rate_limit_weekly")
		if err != nil {
			return nil, err
		}
		return map[string]any{"ok": true}, a.Store.SetUserRateLimits(r.Context(), id, fourHour, weekly)
	})
}

func (a *API) getModelGrants(r *http.Request) (any, error) {
	return withUser(r, func(id int64) (any, error) {
		ids, err := a.Store.UserModelGrants(r.Context(), id)
		return map[string]any{"modelIds": ids}, err
	})
}

func (a *API) putModelGrants(r *http.Request) (any, error) {
	return withUser(r, func(id int64) (any, error) {
		b, err := readBody(r)
		if err != nil {
			return nil, err
		}
		catalog, err := a.catalog(r.Context())
		if err != nil {
			return nil, err
		}
		granted, err := a.Store.SetUserModelGrants(r.Context(), id, b["modelIds"], actor(r), catalog)
		if err != nil {
			return nil, err
		}
		return struct {
			OK       bool     `json:"ok"`
			ModelIDs []string `json:"modelIds"`
		}{true, granted}, nil
	})
}

func (a *API) getDefaultRateLimits(*http.Request) (any, error) {
	return a.Settings.DefaultRateLimits(), nil
}

func (a *API) putDefaultRateLimits(r *http.Request) (any, error) {
	b, err := readBody(r)
	if err != nil {
		return nil, err
	}
	return map[string]any{"ok": true}, a.Settings.SetDefaultRateLimits(b)
}

// ---- SQL console ------------------------------------------------------------

func (a *API) runSQL(r *http.Request) (any, error) {
	b, err := readBody(r)
	if err != nil {
		return nil, err
	}
	return a.Store.RunReadOnlyQuery(r.Context(), b["query"])
}

// ---- access -----------------------------------------------------------------

func (a *API) getAccess(*http.Request) (any, error) {
	return map[string]any{"signupKeyRequired": SignupKeyRequired()}, nil
}

func (a *API) putSignup(r *http.Request) (any, error) {
	b, err := readBody(r)
	if err != nil {
		return nil, err
	}
	required, err := a.Settings.SetSignupKeyRequired(b["keyRequired"])
	if err != nil {
		return nil, err
	}
	return map[string]any{"ok": true, "signupKeyRequired": required}, nil
}

func (a *API) listSignupKeys(r *http.Request) (any, error) {
	keys, err := a.Store.ListSignupKeys(r.Context())
	return map[string]any{"keys": keys}, err
}

func (a *API) createSignupKeys(r *http.Request) (any, error) {
	b, err := readBody(r)
	if err != nil {
		return nil, err
	}
	keys, err := a.Store.CreateSignupKeys(r.Context(), actor(r), b["count"], b["label"])
	return map[string]any{"keys": keys}, err
}

func (a *API) revokeSignupKey(r *http.Request) (any, error) {
	id, ok := positiveID(r.PathValue("id"))
	if !ok {
		return nil, fail(http.StatusBadRequest, "Invalid sign-up key id", "SIGNUP_KEY_NOT_FOUND")
	}
	return map[string]any{"ok": true}, a.Store.RevokeSignupKey(r.Context(), actor(r), id)
}

// ---- server settings --------------------------------------------------------

func (a *API) putModelsConfig(r *http.Request) (any, error) {
	b, err := readBody(r)
	if err != nil {
		return nil, err
	}
	return a.Settings.SetModelsConfig(b["disabledModels"], b["autoEnableNewModels"])
}

func (a *API) getGeneral(*http.Request) (any, error) {
	return map[string]any{"settings": a.Settings.General()}, nil
}

func (a *API) putGeneral(r *http.Request) (any, error) {
	b, err := readBody(r)
	if err != nil {
		return nil, err
	}
	return map[string]any{"ok": true}, a.Settings.UpdateGeneral(b)
}

func (a *API) getEmail(*http.Request) (any, error) { return a.Settings.Email(), nil }

func (a *API) putEmail(r *http.Request) (any, error) {
	b, err := readBody(r)
	if err != nil {
		return nil, err
	}
	view, err := a.Settings.UpdateEmail(b)
	if err != nil {
		return nil, err
	}
	return struct {
		OK bool `json:"ok"`
		EmailView
	}{true, view}, nil
}
