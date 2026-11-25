package agentsapi

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/agents"
	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// Config configures /api/agent-profiles/* and /api/agents/*.
type Config struct {
	DB     *dbx.DB
	UserID func(*http.Request) (int64, bool)
	// IsAdmin decides who reads technical run failures.
	IsAdmin func(ctx context.Context, userID int64) bool
}

// API serves /api/agent-profiles/* and /api/agents/*.
type API struct {
	cfg    Config
	agents agentscope.Resolver
}

// New creates an agentsapi API.
func New(cfg Config) *API {
	return &API{cfg: cfg, agents: agentscope.Resolver{DB: cfg.DB}}
}

// Routes registers /api/agent-profiles and /api/agents endpoints on mux.
func (a *API) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/agent-profiles", a.requireAuth(a.handleListProfiles))
	mux.HandleFunc("GET /api/agent-profiles/tasks", a.requireAuth(a.handleListDelegationTasks))
	mux.HandleFunc("POST /api/agent-profiles/tasks/{taskId}/cancel", a.requireAuth(a.handleCancelDelegationTask))
	mux.HandleFunc("POST /api/agent-profiles", a.requireAuth(a.handleCreateProfile))
	mux.HandleFunc("PUT /api/agent-profiles/{id}", a.requireAuth(a.handleUpdateProfile))
	mux.HandleFunc("POST /api/agent-profiles/{id}/default", a.requireAuth(a.handleSetDefaultProfile))
	mux.HandleFunc("DELETE /api/agent-profiles/{id}", a.requireAuth(a.handleArchiveProfile))

	mux.HandleFunc("GET /api/agents", a.requireAuth(a.handleListRuns))
	mux.HandleFunc("GET /api/agents/chat-history", a.requireAuth(a.handleChatHistory))
	mux.HandleFunc("GET /api/agents/capture-next", a.requireAuth(a.handleGetCaptureNext))
	mux.HandleFunc("POST /api/agents/capture-next", a.requireAuth(a.handlePostCaptureNext))
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

func (a *API) agentFromRequest(r *http.Request, userID int64) string {
	cand := strings.TrimSpace(r.URL.Query().Get("agentId"))
	if cand == "" {
		cand = strings.TrimSpace(r.Header.Get("X-Agent-Id"))
	}
	id, err := a.agents.Resolve(r.Context(), userID, cand)
	if err != nil || id == "" {
		return "main"
	}
	return id
}

func (a *API) manager() *agents.Manager { return &agents.Manager{DB: a.cfg.DB} }

// body reads a JSON request body the way express.json did; an empty or
// non-object body is {}.
func body(r *http.Request) map[string]any {
	var raw map[string]json.RawMessage
	if json.NewDecoder(io.LimitReader(r.Body, 10<<20)).Decode(&raw) != nil || raw == nil {
		return map[string]any{}
	}
	in := make(map[string]any, len(raw))
	for k, v := range raw {
		// An object keeps its key order (tool restrictions are stored as given).
		if trimmed := bytes.TrimSpace(v); len(trimmed) > 0 && trimmed[0] == '{' {
			in[k] = json.RawMessage(trimmed)
			continue
		}
		dec := json.NewDecoder(bytes.NewReader(v))
		dec.UseNumber()
		var value any
		if dec.Decode(&value) == nil {
			in[k] = value
		}
	}
	return in
}

func sanitized(err error) string { return publicerr.Sanitize(err.Error(), "", "") }

// profileFailure answers a failed change: 404 for an unknown agent, 400 else.
func profileFailure(w http.ResponseWriter, err error) {
	if errors.Is(err, agents.ErrNotFound) {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": err.Error()})
		return
	}
	httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": sanitized(err)})
}

func (a *API) handleListProfiles(w http.ResponseWriter, r *http.Request, userID int64) {
	list, defaultID, err := a.manager().List(r.Context(), userID, r.URL.Query().Get("includeArchived") == "true")
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": sanitized(err)})
		return
	}
	var def any
	if defaultID != "" {
		def = defaultID
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"agents": list, "defaultAgentId": def})
}

func (a *API) handleCreateProfile(w http.ResponseWriter, r *http.Request, userID int64) {
	agent, err := a.manager().Create(r.Context(), userID, body(r))
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": sanitized(err)})
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, agent)
}

func (a *API) handleUpdateProfile(w http.ResponseWriter, r *http.Request, userID int64) {
	agent, err := a.manager().Update(r.Context(), userID, r.PathValue("id"), body(r))
	if err != nil {
		profileFailure(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, agent)
}

func (a *API) handleSetDefaultProfile(w http.ResponseWriter, r *http.Request, userID int64) {
	agent, err := a.manager().SetDefault(r.Context(), userID, r.PathValue("id"))
	if err != nil {
		profileFailure(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, agent)
}

func (a *API) handleArchiveProfile(w http.ResponseWriter, r *http.Request, userID int64) {
	if err := a.manager().Archive(r.Context(), userID, r.PathValue("id")); err != nil {
		profileFailure(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"archived": true})
}

func (a *API) handleListDelegationTasks(w http.ResponseWriter, r *http.Request, userID int64) {
	rows, err := a.cfg.DB.R.QueryContext(r.Context(), `SELECT id, parent_agent_id, target_agent_id, task, status, COALESCE(result_summary, ''), COALESCE(error, ''), created_at FROM agent_delegations WHERE user_id = ? ORDER BY created_at DESC LIMIT 100`, userID)
	if err != nil {
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"tasks": []any{}})
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, parent, target, task, status, summary, errMsg, createdAt string
		if rows.Scan(&id, &parent, &target, &task, &status, &summary, &errMsg, &createdAt) == nil {
			out = append(out, map[string]any{
				"id": id, "parentAgentId": parent, "targetAgentId": target,
				"task": task, "status": status, "resultSummary": summary,
				"error": errMsg, "createdAt": createdAt,
			})
		}
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"tasks": out})
}

func (a *API) handleCancelDelegationTask(w http.ResponseWriter, r *http.Request, userID int64) {
	res, err := a.cfg.DB.W.ExecContext(r.Context(), `UPDATE agent_delegations SET status = 'cancelled' WHERE id = ? AND user_id = ?`, r.PathValue("taskId"), userID)
	if err != nil {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "Task not found."})
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "Task not found."})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"id": r.PathValue("taskId"), "status": "cancelled"})
}

func (a *API) handleListRuns(w http.ResponseWriter, r *http.Request, userID int64) {
	limit := 50
	if n, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && n > 0 {
		limit = min(n, 200)
	}
	offset := 0
	if n, err := strconv.Atoi(r.URL.Query().Get("offset")); err == nil && n >= 0 {
		offset = n
	}
	agentID := a.agentFromRequest(r, userID)
	var total int
	_ = a.cfg.DB.R.QueryRowContext(r.Context(), `SELECT COUNT(*) FROM agent_runs WHERE user_id = ? AND agent_id = ?`, userID, agentID).Scan(&total)
	rows, err := a.cfg.DB.R.QueryContext(r.Context(), `SELECT * FROM agent_runs WHERE user_id = ? AND agent_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?`, userID, agentID, limit, offset)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "Internal server error"})
		return
	}
	defer rows.Close()
	runs, err := scanObjects(rows)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "Internal server error"})
		return
	}
	if a.cfg.IsAdmin == nil || !a.cfg.IsAdmin(r.Context(), userID) {
		for _, run := range runs {
			redactRun(run)
		}
	}
	httpx.WriteJSON(w, http.StatusOK, jsonobj.New("runs", runs, "total", total, "limit", limit, "offset", offset, "agentId", agentID))
}

func (a *API) handleChatHistory(w http.ResponseWriter, r *http.Request, userID int64) {
	limit := 40
	if n, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && n > 0 {
		limit = min(n, 100)
	}
	agentID := a.agentFromRequest(r, userID)
	rows, err := a.cfg.DB.R.QueryContext(r.Context(), `SELECT id, role, content, COALESCE(json_extract(metadata, '$.platform'), 'web'), created_at, COALESCE(agent_run_id, '')
		FROM conversation_history WHERE user_id = ? AND agent_id = ? ORDER BY created_at DESC, id DESC LIMIT ?`, userID, agentID, limit)
	if err != nil {
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"messages": []any{}, "hasMore": false})
		return
	}
	defer rows.Close()
	msgs := []map[string]any{}
	for rows.Next() {
		var id int64
		var role, content, plat, createdAt, runID string
		if rows.Scan(&id, &role, &content, &plat, &createdAt, &runID) == nil {
			msgs = append(msgs, map[string]any{
				"id": id, "role": role, "content": content, "platform": plat,
				"created_at": createdAt, "run_id": runID, "history_source": "conversation",
			})
		}
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"messages": msgs, "hasMore": false, "agentId": agentID})
}

func (a *API) handleGetCaptureNext(w http.ResponseWriter, r *http.Request, userID int64) {
	agentID := a.agentFromRequest(r, userID)
	var val sql.NullString
	_ = a.cfg.DB.R.QueryRowContext(r.Context(), `SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = 'capture_next_run'`, userID, agentID).Scan(&val)
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"requested": val.String == "true" || val.String == "1"})
}

func (a *API) handlePostCaptureNext(w http.ResponseWriter, r *http.Request, userID int64) {
	agentID := a.agentFromRequest(r, userID)
	_, _ = a.cfg.DB.W.ExecContext(r.Context(), `INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, 'capture_next_run', 'true')
		ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = 'true'`, userID, agentID)
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"requested": true})
}
