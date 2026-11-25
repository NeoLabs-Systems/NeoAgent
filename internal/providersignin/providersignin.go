package providersignin

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/ratelimit"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const expiredMessage = flowExpired

// FlowManager drives provider OAuth/device sign-in flows.
type FlowManager interface {
	Begin(ctx context.Context, providerID string, userID int64, agentID, baseURL string) (map[string]any, error)
	Status(state string, userID int64) (map[string]any, bool)
	Complete(ctx context.Context, state, code string, userID int64) (map[string]any, error)
}

// Config configures /api/provider-sign-in/*.
type Config struct {
	DB        *dbx.DB
	Flows     FlowManager
	PublicURL string
	BindState func(*sessionx.Session, string)
	UserID    func(*http.Request) (int64, bool)
}

// API serves /api/provider-sign-in/*.
type API struct {
	cfg    Config
	agents agentscope.Resolver
}

// New creates a providersignin API.
func New(cfg Config) *API {
	return &API{cfg: cfg, agents: agentscope.Resolver{DB: cfg.DB}}
}

// Routes registers /api/provider-sign-in endpoints on mux.
func (a *API) Routes(mux *http.ServeMux) {
	limiter := ratelimit.New(ratelimit.Config{
		Window:  time.Minute,
		Max:     20,
		Message: map[string]string{"error": "Too many requests, try again in a minute."},
		Key:     func(r *http.Request) string { return r.RemoteAddr },
	}).Middleware

	mux.Handle("POST /api/provider-sign-in/{providerId}", limiter(a.requireAuth(a.handleBegin)))
	mux.HandleFunc("GET /api/provider-sign-in/{state}", a.requireAuth(a.handleStatus))
	mux.Handle("POST /api/provider-sign-in/{state}/code", limiter(a.requireAuth(a.handleCode)))
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

func (a *API) baseURL(r *http.Request) string {
	if a.cfg.PublicURL != "" {
		return strings.TrimRight(a.cfg.PublicURL, "/")
	}
	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}
	if r.Host != "" {
		return scheme + "://" + r.Host
	}
	return "http://localhost:3333"
}

func (a *API) handleBegin(w http.ResponseWriter, r *http.Request, userID int64) {
	if a.cfg.Flows == nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(errors.New("provider sign-in is not configured").Error(), "", "")})
		return
	}
	providerID := strings.TrimSpace(r.PathValue("providerId"))
	agentID := strings.TrimSpace(r.URL.Query().Get("agentId"))
	if a.cfg.DB != nil {
		if resolved, err := a.agents.Resolve(r.Context(), userID, agentID); err == nil && resolved != "" {
			agentID = resolved
		}
	}
	if agentID == "" {
		agentID = "main"
	}
	flow, err := a.cfg.Flows.Begin(r.Context(), providerID, userID, agentID, a.baseURL(r))
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	if flow["mode"] == "redirect" && a.cfg.BindState != nil {
		if state, ok := flow["state"].(string); ok {
			a.cfg.BindState(sessionx.FromContext(r.Context()), state)
		}
	}
	httpx.WriteJSON(w, http.StatusOK, flow)
}

func (a *API) handleStatus(w http.ResponseWriter, r *http.Request, userID int64) {
	if a.cfg.Flows == nil {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": expiredMessage})
		return
	}
	res, ok := a.cfg.Flows.Status(r.PathValue("state"), userID)
	if !ok {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": expiredMessage})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (a *API) handleCode(w http.ResponseWriter, r *http.Request, userID int64) {
	if a.cfg.Flows == nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": expiredMessage})
		return
	}
	var body struct {
		Code string `json:"code"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 16*1024)).Decode(&body); err != nil || strings.TrimSpace(body.Code) == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "A sign-in code is required."})
		return
	}
	res, err := a.cfg.Flows.Complete(r.Context(), r.PathValue("state"), strings.TrimSpace(body.Code), userID)
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}
