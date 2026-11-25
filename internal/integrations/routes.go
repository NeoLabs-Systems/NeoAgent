package integrations

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const bodyLimit = 1 << 20

// Config wires the /api/integrations routes.
type Config struct {
	Manager *Manager
	Log     *slog.Logger
	// BindState ties an OAuth state to the session that started it, so the
	// callback can tell whether it returned to the same browser. It is the
	// function the account sign-in callback uses.
	BindState func(sess *sessionx.Session, state string)
	// UserID returns the signed-in account of a request. Nil reads "userId"
	// from the session.
	UserID func(*http.Request) (int64, bool)
	// Home and Root are hidden in error messages (see publicerr.Sanitize).
	Home, Root string
}

// API serves the /api/integrations routes.
type API struct {
	m         *Manager
	log       *slog.Logger
	bindState func(*sessionx.Session, string)
	userID    func(*http.Request) (int64, bool)
	home      string
	root      string
}

// New builds the API.
func New(cfg Config) *API {
	log := cfg.Log
	if log == nil {
		log = slog.Default()
	}
	userID := cfg.UserID
	if userID == nil {
		userID = sessionUserID
	}
	return &API{m: cfg.Manager, log: log, bindState: cfg.BindState, userID: userID, home: cfg.Home, root: cfg.Root}
}

func sessionUserID(r *http.Request) (int64, bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}

// Routes registers the routes behind sign-in. The OAuth callback endpoints are
// not here: the shared callback serves them and calls Manager.FinishOAuth and
// Manager.DescribePendingOAuth for integration states.
//
// Provider-specific routes (the Bitwarden vault) are mounted by their
// providers' own packages.
func (a *API) Routes(mux *http.ServeMux) {
	mux.Handle("GET /api/integrations", a.authed(a.list))
	mux.Handle("GET /api/integrations/{$}", a.authed(a.list))
	mux.Handle("POST /api/integrations/{provider}/connect", a.authed(a.connect))
	mux.Handle("POST /api/integrations/{provider}/disconnect", a.authed(a.disconnect))
	mux.Handle("POST /api/integrations/{provider}/test", a.authed(a.test))
	mux.Handle("POST /api/integrations/{provider}/access-mode", a.authed(a.accessMode))
	mux.Handle("GET /api/integrations/{provider}/tools/status", a.authed(a.toolStatus))
	mux.Handle("GET /api/integrations/{provider}/config", a.authed(a.getConfig))
	mux.Handle("PUT /api/integrations/{provider}/config", a.authed(a.putConfig))
	mux.Handle("DELETE /api/integrations/{provider}/config", a.authed(a.deleteConfig))
	mux.Handle("GET /api/integrations/{provider}/connect/{sessionId}", a.authed(a.connectPage))
	mux.Handle("GET /api/integrations/{provider}/connect/{sessionId}/status", a.authed(a.connectStatus))
	mux.Handle("DELETE /api/integrations/{provider}/connect/{sessionId}", a.authed(a.connectCancel))
	a.extraRoutes(mux)
}

type request struct {
	userID  int64
	agentID string // resolved
	body    map[string]json.RawMessage
	sess    *sessionx.Session
}

func (r request) scope() Scope { return Scope{UserID: r.userID, AgentID: r.agentID} }

// value decodes one body member.
func (r request) value(key string) any {
	raw, ok := r.body[key]
	if !ok {
		return nil
	}
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	var v any
	if dec.Decode(&v) != nil {
		return nil
	}
	return v
}

func (r request) text(key string) string { return strings.TrimSpace(jsText(r.value(key))) }

type handler func(w http.ResponseWriter, r *http.Request, req request)

// authed answers 401 unless the session belongs to an account, then reads the
// body and resolves the agent the request is about.
func (a *API) authed(fn handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		userID, ok := a.userID(r)
		if !ok {
			httpx.Error(w, http.StatusUnauthorized, "Unauthorized")
			return
		}
		body, err := readBody(r)
		if err != nil {
			httpx.Error(w, http.StatusBadRequest, err.Error())
			return
		}
		agentID, err := a.m.agent(r.Context(), userID, agentscope.Candidate(r, body))
		if err != nil {
			a.log.Error("resolving agent", "error", err)
			httpx.Error(w, http.StatusInternalServerError, "Something went wrong. Please try again.")
			return
		}
		fn(w, r, request{userID: userID, agentID: agentID, body: body, sess: sessionx.FromContext(r.Context())})
	})
}

func readBody(r *http.Request) (map[string]json.RawMessage, error) {
	if !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return map[string]json.RawMessage{}, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, bodyLimit))
	if err != nil {
		return nil, errors.New("Request body too large")
	}
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || raw[0] == '[' {
		return map[string]json.RawMessage{}, nil
	}
	var body map[string]json.RawMessage
	if err := json.Unmarshal(raw, &body); err != nil || body == nil {
		return nil, errors.New("Invalid JSON body")
	}
	return body, nil
}

// Scoped serves a provider's own route behind sign-in, with the agent
// resolved and the JSON body decoded.
func (a *API) Scoped(fn func(w http.ResponseWriter, r *http.Request, scope Scope, body map[string]any)) http.Handler {
	return a.authed(func(w http.ResponseWriter, r *http.Request, req request) {
		body := make(map[string]any, len(req.body))
		for k := range req.body {
			body[k] = req.value(k)
		}
		fn(w, r, req.scope(), body)
	})
}

// FailWithCode answers {"error", "code"} with the error's code or null.
func (a *API) FailWithCode(w http.ResponseWriter, status int, err error) {
	a.failWithCode(w, status, err)
}

func (a *API) message(err error) string {
	return publicerr.Sanitize(err.Error(), a.home, a.root)
}

func (a *API) fail(w http.ResponseWriter, status int, err error) {
	httpx.Error(w, status, a.message(err))
}

// failWithCode adds the error's code, null when it has none.
func (a *API) failWithCode(w http.ResponseWriter, status int, err error) {
	var code any
	var coded interface{ Code() string }
	if errors.As(err, &coded) && coded.Code() != "" {
		code = coded.Code()
	}
	httpx.WriteJSON(w, status, struct {
		Error string `json:"error"`
		Code  any    `json:"code"`
	}{a.message(err), code})
}

func (a *API) list(w http.ResponseWriter, r *http.Request, req request) {
	snaps, err := a.m.ListProviders(r.Context(), req.userID, req.agentID)
	if err != nil {
		a.fail(w, http.StatusInternalServerError, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, snaps)
}

func (a *API) connect(w http.ResponseWriter, r *http.Request, req request) {
	if interactive, ok, err := a.m.BeginConnection(r.Context(), req.userID, r.PathValue("provider"), req.text("appId"), req.agentID); ok || err != nil {
		if err != nil {
			a.fail(w, http.StatusBadRequest, err)
			return
		}
		httpx.WriteJSON(w, http.StatusOK, interactive)
		return
	}
	start, err := a.m.BeginOAuth(r.Context(), req.userID, r.PathValue("provider"), BeginOptions{
		AppKey: req.text("appId"), AgentID: req.agentID, MemorySweep: req.value("memorySweep") == true,
	})
	if err != nil {
		a.fail(w, http.StatusBadRequest, err)
		return
	}
	if start.State != "" && a.bindState != nil {
		a.bindState(req.sess, start.State)
	}
	httpx.WriteJSON(w, http.StatusOK, start)
}

func (a *API) disconnect(w http.ResponseWriter, r *http.Request, req request) {
	res, err := a.m.Disconnect(r.Context(), req.userID, r.PathValue("provider"), req.agentID, req.value("connectionId"))
	if err != nil {
		a.fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (a *API) test(w http.ResponseWriter, r *http.Request, req request) {
	res, err := a.m.TestConnection(r.Context(), req.userID, r.PathValue("provider"), req.agentID, req.value("connectionId"))
	if err != nil {
		a.failWithCode(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (a *API) accessMode(w http.ResponseWriter, r *http.Request, req request) {
	res, err := a.m.UpdateAccessMode(r.Context(), req.userID, r.PathValue("provider"), req.agentID, req.value("connectionId"), jsText(req.value("accessMode")))
	if err != nil {
		a.fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (a *API) toolStatus(w http.ResponseWriter, r *http.Request, req request) {
	res, err := a.m.ToolStatus(r.Context(), req.userID, r.PathValue("provider"), req.agentID)
	if err != nil {
		a.fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

// accountConfig is the per-user setup a config route works on.
type accountConfig interface {
	SetupReader
	SetupSaver
	SetupClearer
}

// configurable finds the provider and checks that it has per-user setup; it
// answers the request itself and returns nil when it cannot.
func (a *API) configurable(w http.ResponseWriter, r *http.Request) (Provider, accountConfig) {
	key := r.PathValue("provider")
	p := a.m.Provider(key)
	if p == nil {
		a.fail(w, http.StatusBadRequest, a.m.unknownProvider(key))
		return nil, nil
	}
	switch c := p.(type) {
	case accountConfig:
		return p, c
	case Configurable:
		return p, oauthAppConfig{c}
	}
	httpx.Error(w, http.StatusNotFound, fmt.Sprintf("%s does not support per-user configuration.", p.Info().Label))
	return nil, nil
}

// oauthAppConfig serves a provider's own OAuth app as its setup.
type oauthAppConfig struct{ c Configurable }

func (o oauthAppConfig) SetupConfig(_ context.Context, scope Scope) (any, error) {
	return o.c.UserConfig(scope), nil
}

func (o oauthAppConfig) SaveSetup(ctx context.Context, scope Scope, config map[string]any) (any, error) {
	return o.c.SaveUserConfig(ctx, scope, config)
}

func (o oauthAppConfig) ClearSetup(ctx context.Context, scope Scope) error {
	return o.c.ClearUserConfig(ctx, scope)
}

func (a *API) getConfig(w http.ResponseWriter, r *http.Request, req request) {
	p, c := a.configurable(w, r)
	if c == nil {
		return
	}
	config, err := c.SetupConfig(r.Context(), req.scope())
	if err != nil {
		a.fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"provider": p.Info().Key, "config": config})
}

func (a *API) putConfig(w http.ResponseWriter, r *http.Request, req request) {
	p, c := a.configurable(w, r)
	if c == nil {
		return
	}
	// The config is body.config when that is set, else the whole body.
	config := map[string]any{}
	if inner, ok := req.value("config").(map[string]any); ok {
		config = inner
	} else if len(req.body) > 0 {
		for k := range req.body {
			config[k] = req.value(k)
		}
	}
	saved, err := c.SaveSetup(r.Context(), req.scope(), config)
	if err != nil {
		a.fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"provider": p.Info().Key, "config": saved, "saved": true})
}

func (a *API) deleteConfig(w http.ResponseWriter, r *http.Request, req request) {
	p, c := a.configurable(w, r)
	if c == nil {
		return
	}
	if err := c.ClearSetup(r.Context(), req.scope()); err != nil {
		a.fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"provider": p.Info().Key, "cleared": true})
}
