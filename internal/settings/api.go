package settings

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/cloudsec"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/ratelimit"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const bodyLimit = 10 << 20

// Config wires the settings routes.
type Config struct {
	DB  *dbx.DB
	Box *secretbox.Box
	Log *slog.Logger
	// RuntimeBackend is the runtime_backend setting; see RuntimeBackendFor.
	RuntimeBackend string
	TrustProxy     bool
	// UserID returns the signed-in account of a request. Nil reads "userId"
	// from the session.
	UserID func(*http.Request) (int64, bool)
	// URLChecker vets provider addresses users enter. The zero value resolves
	// hostnames through the system resolver.
	URLChecker cloudsec.Checker
	Hooks      Hooks
	Catalog    Catalog
}

// API serves the /api/settings routes.
type API struct {
	Store     *Store
	userID    func(*http.Request) (int64, bool)
	checker   cloudsec.Checker
	byokLimit *ratelimit.Limiter
	log       *slog.Logger
	catalog   Catalog
}

// New builds the API.
func New(cfg Config) *API {
	userID := cfg.UserID
	if userID == nil {
		userID = sessionUserID
	}
	return &API{
		Store: &Store{
			DB: cfg.DB, Agents: agentscope.Resolver{DB: cfg.DB}, Box: cfg.Box,
			RuntimeBackend: cfg.RuntimeBackend, Hooks: cfg.Hooks, Log: cfg.Log,
		},
		userID:  userID,
		checker: cfg.URLChecker,
		log:     cfg.Log,
		catalog: cfg.Catalog,
		byokLimit: ratelimit.New(ratelimit.Config{
			Window:  time.Minute,
			Max:     20,
			Message: map[string]any{"success": false, "error": "Too many requests, try again in a minute."},
			Key:     func(r *http.Request) string { return httpx.ClientIP(r, cfg.TrustProxy) },
		}),
	}
}

func sessionUserID(r *http.Request) (int64, bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}

// Routes registers the settings routes on mux.
//
// Not served (they answer 404 until the AI provider catalog is ported):
// GET /meta/models, /meta/system-one-models, /meta/ai-providers, GET /byok and
// POST /byok/{providerId}/test.
func (a *API) Routes(mux *http.ServeMux) {
	authed := func(fn handler) http.Handler { return a.guard(a.scoped(fn)) }
	limited := func(fn handler) http.Handler { return a.guard(a.byokLimit.Middleware(a.scoped(fn))) }

	if a.catalog != nil {
		mux.Handle("GET /api/settings/meta/models", authed(a.handleMetaModels))
		mux.Handle("GET /api/settings/meta/system-one-models", authed(a.handleMetaSystemOneModels))
		mux.Handle("GET /api/settings/meta/ai-providers", authed(a.handleMetaAIProviders))
		mux.Handle("GET /api/settings/byok", authed(a.handleBYOKList))
		mux.Handle("POST /api/settings/byok/{providerId}/test", limited(a.handleBYOKTest))
	} else {
		// GET /byok is a route of its own in Node, not the setting named "byok".
		mux.Handle("GET /api/settings/byok", http.NotFoundHandler())
	}
	mux.Handle("PUT /api/settings/byok/{providerId}", limited(a.byokPut))
	mux.Handle("DELETE /api/settings/byok/{providerId}", limited(a.byokDelete))

	mux.Handle("GET /api/settings/{$}", authed(a.getAll))
	mux.Handle("GET /api/settings", authed(a.getAll))
	mux.Handle("PUT /api/settings/{$}", authed(a.putAll))
	mux.Handle("PUT /api/settings", authed(a.putAll))
	mux.Handle("GET /api/settings/token-usage/summary", authed(a.tokenUsage))
	mux.Handle("GET /api/settings/{key}", authed(a.getOne))
	mux.Handle("PUT /api/settings/{key}", authed(a.putOne))
	mux.Handle("DELETE /api/settings/{key}", authed(a.deleteOne))
}

// request is what a route needs: the account, the agent the request is about
// and the JSON body.
type request struct {
	userID  int64
	agentID string
	body    Patch
}

type handler func(w http.ResponseWriter, r *http.Request, req request)

// guard answers 401 JSON unless the session belongs to an account.
func (a *API) guard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := a.userID(r); !ok {
			httpx.Error(w, 401, "Unauthorized")
			return
		}
		next.ServeHTTP(w, r)
	})
}

// scoped reads the body and resolves the agent before calling fn.
func (a *API) scoped(fn handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		userID, _ := a.userID(r)
		body, err := readBody(r)
		if err != nil {
			httpx.Error(w, 400, err.Error())
			return
		}
		agentID, err := a.Store.Agents.Resolve(r.Context(), userID, agentscope.Candidate(r, body))
		if err != nil {
			a.fail(w, err)
			return
		}
		fn(w, r, request{userID: userID, agentID: agentID, body: body})
	})
}

// readBody reads the JSON object a request carries; a request without a JSON
// body, or with a list, has no members.
func readBody(r *http.Request) (Patch, error) {
	if !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return Patch{}, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, bodyLimit))
	if err != nil {
		return nil, errors.New("Request body too large")
	}
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || raw[0] == '[' {
		return Patch{}, nil
	}
	var body Patch
	if err := json.Unmarshal(raw, &body); err != nil || body == nil {
		return nil, errors.New("Invalid JSON body")
	}
	return body, nil
}

func (a *API) fail(w http.ResponseWriter, err error) {
	a.log.Error("settings route failed", "error", err)
	httpx.Error(w, 500, "Something went wrong. Please try again.")
}

// refuse answers a rejected patch the way Node did.
func refuse(w http.ResponseWriter, err error) {
	httpx.WriteJSON(w, 400, map[string]any{"success": false, "error": err.Error()})
}

func (a *API) getAll(w http.ResponseWriter, r *http.Request, req request) {
	settings, err := a.Store.All(r.Context(), req.userID, req.agentID)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, settings)
}

func (a *API) update(w http.ResponseWriter, r *http.Request, req request, patch Patch) {
	source := "client " + orDefault(r.Header.Get("User-Agent"), "unknown")
	err := a.Store.Update(r.Context(), req.userID, req.agentID, patch, source)
	var invalid *ValidationError
	switch {
	case errors.As(err, &invalid):
		refuse(w, err)
	case err != nil:
		a.fail(w, err)
	default:
		httpx.WriteJSON(w, 200, map[string]any{"success": true})
	}
}

func orDefault(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

func (a *API) putAll(w http.ResponseWriter, r *http.Request, req request) {
	a.update(w, r, req, req.body)
}

func (a *API) tokenUsage(w http.ResponseWriter, r *http.Request, req request) {
	usage, err := a.Store.TokenUsage(r.Context(), req.userID, req.agentID)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, usage)
}

func (a *API) getOne(w http.ResponseWriter, r *http.Request, req request) {
	value, err := a.Store.ReadValue(r.Context(), req.userID, req.agentID, r.PathValue("key"))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"value": value})
}

func failure(w http.ResponseWriter, status int, message string) {
	httpx.WriteJSON(w, status, map[string]any{"success": false, "error": message})
}

const serverManagedMessage = "This setting is managed by the server, not per account."

func (a *API) putOne(w http.ResponseWriter, r *http.Request, req request) {
	key := r.PathValue("key")
	switch {
	case retiredKeys[key]:
		failure(w, 410, key+" has been retired")
	case serverManagedKeys[key]:
		failure(w, 403, serverManagedMessage)
	case isProtectedSecret(key):
		failure(w, 403, key+" is managed by Social Reach cookie setup")
	default:
		a.update(w, r, req, Patch{key: req.body["value"]})
	}
}

func (a *API) deleteOne(w http.ResponseWriter, r *http.Request, req request) {
	key := r.PathValue("key")
	if serverManagedKeys[key] {
		failure(w, 403, serverManagedMessage)
		return
	}
	if err := a.Store.Delete(r.Context(), req.userID, req.agentID, key); err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true})
}

// bodyString reads a string member, trimmed; ok is false when it is absent or
// not a string.
func bodyString(body Patch, key string) (value string, ok bool) {
	text, isString := decode(body[key]).(string)
	return jsTrim(text), isString
}

// byokProvider finds the provider a /byok/{providerId} route names, or answers
// 404 with message.
func byokProvider(w http.ResponseWriter, r *http.Request, message string, usable func(providerDef) bool) (providerDef, bool) {
	def, ok := providerByID(jsTrim(r.PathValue("providerId")))
	if !ok || !def.byokEligible() || !usable(def) {
		failure(w, 404, message)
		return providerDef{}, false
	}
	return def, true
}

func (a *API) byokPut(w http.ResponseWriter, r *http.Request, req request) {
	def, ok := byokProvider(w, r, "Unknown or unsupported provider.", func(d providerDef) bool { return d.SupportsAPIKey || d.SupportsBaseURL })
	if !ok {
		return
	}
	apiKey, _ := bodyString(req.body, "apiKey")
	baseURL, hasBaseURL := bodyString(req.body, "baseUrl")
	label, hasLabel := bodyString(req.body, "label")

	if def.SupportsAPIKey && apiKey == "" {
		failure(w, 400, "An API key is required.")
		return
	}
	if def.baseURLRequired() && baseURL == "" {
		failure(w, 400, "A base URL is required for this provider.")
		return
	}
	if baseURL != "" && !a.safeBaseURL(w, r, baseURL) {
		return
	}

	ctx := r.Context()
	save := func() error {
		if def.SupportsAPIKey {
			if err := a.Store.SetProviderSecret(ctx, req.userID, req.agentID, def.ID, apiKey); err != nil {
				return err
			}
		}
		if def.SupportsBaseURL && (hasBaseURL || hasLabel) {
			return a.Store.SetProviderConfig(ctx, req.userID, req.agentID, def, optional(baseURL, hasBaseURL), optional(label, hasLabel))
		}
		return nil
	}
	if err := save(); err != nil {
		a.log.Error("failed to save provider credential", "error", err)
		failure(w, 500, "Could not save this credential.")
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true, "configured": true})
}

func optional(value string, present bool) *string {
	if !present {
		return nil
	}
	return &value
}

func (a *API) byokDelete(w http.ResponseWriter, r *http.Request, req request) {
	def, ok := byokProvider(w, r, "Unknown provider.", func(providerDef) bool { return true })
	if !ok {
		return
	}
	ctx := r.Context()
	clear := func() error {
		if def.SupportsAPIKey {
			if err := a.Store.SetProviderSecret(ctx, req.userID, req.agentID, def.ID, ""); err != nil {
				return err
			}
		}
		if def.SupportsBaseURL {
			empty := ""
			var label *string
			if !def.SupportsAPIKey {
				label = &empty
			}
			return a.Store.SetProviderConfig(ctx, req.userID, req.agentID, def, &empty, label)
		}
		return nil
	}
	if err := clear(); err != nil {
		a.log.Error("failed to clear provider credential", "error", err)
		failure(w, 500, "Could not clear this credential.")
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true, "configured": false})
}

// safeBaseURL answers 400 and returns false unless baseURL is an http(s)
// address that does not lead into the server's own network. A user-chosen
// address is called from the server, so it must never reach loopback, LAN or
// cloud metadata services, neither as a literal nor through DNS.
func (a *API) safeBaseURL(w http.ResponseWriter, r *http.Request, baseURL string) bool {
	if !cloudsec.ValidHTTPURL(baseURL) {
		httpx.WriteJSON(w, 400, map[string]any{"success": false, "ok": false, "error": "Base URL must be a valid http(s) URL."})
		return false
	}
	verdict, err := a.checker.Validate(r.Context(), baseURL)
	if err != nil {
		return false // the client went away
	}
	if !verdict.Allowed {
		httpx.WriteJSON(w, 400, map[string]any{"success": false, "ok": false, "error": verdict.Reason})
		return false
	}
	return true
}
