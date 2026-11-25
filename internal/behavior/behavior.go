package behavior

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// Runtime provides runtime diagnostics and decisions once the pipeline runs.
type Runtime interface {
	Diagnostics(userID int64, agentID, platform, chatID string) any
	ListDecisions(userID int64, agentID, platform string) any
}

// Config configures the /api/behavior routes.
type Config struct {
	DB       *dbx.DB
	Pipeline Runtime
	OnChange func(userID int64, agentID string)
	UserID   func(*http.Request) (int64, bool)
}

// API serves /api/behavior/*.
type API struct {
	cfg    Config
	agents agentscope.Resolver
	store  *Store
}

// New creates a behavior API.
func New(cfg Config) *API {
	return &API{cfg: cfg, agents: agentscope.Resolver{DB: cfg.DB}, store: NewStore(cfg.DB)}
}

// Routes registers /api/behavior endpoints on mux.
func (a *API) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/behavior", a.requireAuth(a.handleGet))
	mux.HandleFunc("PUT /api/behavior", a.requireAuth(a.handlePut))
	mux.HandleFunc("GET /api/behavior/effective", a.requireAuth(a.handleEffective))
	mux.HandleFunc("GET /api/behavior/diagnostics", a.requireAuth(a.handleDiagnostics))
	mux.HandleFunc("GET /api/behavior/decisions", a.requireAuth(a.handleDecisions))
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

func (a *API) agentID(r *http.Request, userID int64) string {
	cand := strings.TrimSpace(r.URL.Query().Get("agentId"))
	if cand == "" {
		cand = strings.TrimSpace(r.Header.Get("X-Agent-Id"))
	}
	if a.cfg.DB == nil {
		if cand == "" {
			return "main"
		}
		return cand
	}
	id, err := a.agents.Resolve(r.Context(), userID, cand)
	if err != nil || id == "" {
		return "main"
	}
	return id
}

func (a *API) handleGet(w http.ResponseWriter, r *http.Request, userID int64) {
	agentID := a.agentID(r, userID)
	httpx.WriteJSON(w, http.StatusOK, dyn.Ordered{{Key: "agentId", Value: agentID}, {Key: "modules", Value: ModuleIDs},
		{Key: "defaults", Value: Defaults()}, {Key: "config", Value: a.store.Get(r.Context(), userID, agentID)}})
}

func (a *API) handlePut(w http.ResponseWriter, r *http.Request, userID int64) {
	var body struct {
		Config json.RawMessage `json:"config"`
	}
	err := json.NewDecoder(io.LimitReader(r.Body, 256*1024)).Decode(&body)
	trimmed := bytes.TrimSpace(body.Config)
	if err != nil || len(trimmed) == 0 || trimmed[0] != '{' {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "config must be an object"})
		return
	}
	agentID := a.agentID(r, userID)
	saved, err := a.store.Set(r.Context(), userID, agentID, trimmed)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "Something went wrong. Please try again."})
		return
	}
	if a.cfg.OnChange != nil {
		a.cfg.OnChange(userID, agentID)
	}
	httpx.WriteJSON(w, http.StatusOK, dyn.Ordered{{Key: "agentId", Value: agentID}, {Key: "config", Value: saved}})
}

func (a *API) handleEffective(w http.ResponseWriter, r *http.Request, userID int64) {
	platform := strings.TrimSpace(r.URL.Query().Get("platform"))
	chatID := strings.TrimSpace(r.URL.Query().Get("chatId"))
	if platform == "" || chatID == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "platform and chatId are required"})
		return
	}
	agentID := a.agentID(r, userID)
	isGroup := r.URL.Query().Get("isGroup") != "false"
	httpx.WriteJSON(w, http.StatusOK, dyn.Ordered{{Key: "agentId", Value: agentID},
		{Key: "config", Value: a.store.Resolve(r.Context(), userID, agentID, platform, chatID, isGroup)}})
}

func (a *API) handleDiagnostics(w http.ResponseWriter, r *http.Request, userID int64) {
	platform := strings.TrimSpace(r.URL.Query().Get("platform"))
	chatID := strings.TrimSpace(r.URL.Query().Get("chatId"))
	if platform == "" || chatID == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "platform and chatId are required"})
		return
	}
	if a.cfg.Pipeline == nil {
		httpx.WriteJSON(w, http.StatusServiceUnavailable, map[string]any{"error": "Behavior runtime is not initialized"})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, a.cfg.Pipeline.Diagnostics(userID, a.agentID(r, userID), platform, chatID))
}

func (a *API) handleDecisions(w http.ResponseWriter, r *http.Request, userID int64) {
	platform := strings.TrimSpace(r.URL.Query().Get("platform"))
	if platform == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "platform is required"})
		return
	}
	if a.cfg.Pipeline == nil {
		httpx.WriteJSON(w, http.StatusServiceUnavailable, map[string]any{"error": "Behavior runtime is not initialized"})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"decisions": a.cfg.Pipeline.ListDecisions(userID, a.agentID(r, userID), platform),
	})
}
