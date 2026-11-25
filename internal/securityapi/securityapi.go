// Package securityapi serves /api/security: the owner's security mode,
// category policies, approval decisions and the approval log.
package securityapi

import (
	"encoding/json"
	"io"
	"net/http"
	"strconv"

	"github.com/NeoLabs-Systems/neoagent/internal/security"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// Config configures the /api/security routes.
type Config struct {
	DB       *dbx.DB
	Policies *security.Policies
	Gate     *security.Gate
}

// API serves /api/security/*.
type API struct{ cfg Config }

// New creates the routes.
func New(cfg Config) *API { return &API{cfg: cfg} }

// Routes registers /api/security endpoints on mux.
func (a *API) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/security/mode", a.auth(a.handleGetMode))
	mux.HandleFunc("PUT /api/security/mode", a.auth(a.handlePutMode))
	mux.HandleFunc("GET /api/security/policies", a.auth(a.handleGetPolicies))
	mux.HandleFunc("PUT /api/security/policies", a.auth(a.handlePutPolicy))
	mux.HandleFunc("POST /api/security/approvals/{approvalId}", a.auth(a.handleApproval))
	mux.HandleFunc("GET /api/security/approval-log", a.auth(a.handleApprovalLog))
}

func (a *API) auth(next func(http.ResponseWriter, *http.Request, int64)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var uid int64
		ok := false
		if sess := sessionx.FromContext(r.Context()); sess != nil {
			uid, ok = sess.Int64("userId")
		}
		if !ok || uid <= 0 {
			httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
			return
		}
		next(w, r, uid)
	}
}

func body(r *http.Request) map[string]any {
	raw, _ := io.ReadAll(io.LimitReader(r.Body, 64*1024))
	var out map[string]any
	_ = json.Unmarshal(raw, &out)
	if out == nil {
		out = map[string]any{}
	}
	return out
}

func text(v any) string {
	s, _ := v.(string)
	return s
}

func (a *API) handleGetMode(w http.ResponseWriter, r *http.Request, userID int64) {
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"mode": a.cfg.Policies.Mode(r.Context(), userID)})
}

func (a *API) handlePutMode(w http.ResponseWriter, r *http.Request, userID int64) {
	mode := text(body(r)["mode"])
	if mode == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "mode is required"})
		return
	}
	if err := a.cfg.Policies.SetMode(r.Context(), userID, mode); err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true, "mode": mode})
}

// orderedPolicies keeps the category order of the Node server's object.
type orderedPolicies map[string]string

func (p orderedPolicies) MarshalJSON() ([]byte, error) {
	out := []byte{'{'}
	for i, c := range security.Categories {
		if i > 0 {
			out = append(out, ',')
		}
		k, _ := json.Marshal(c)
		v, _ := json.Marshal(p[c])
		out = append(append(append(out, k...), ':'), v...)
	}
	return append(out, '}'), nil
}

func (a *API) handleGetPolicies(w http.ResponseWriter, r *http.Request, userID int64) {
	ctx := r.Context()
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"policies":        orderedPolicies(a.cfg.Policies.All(ctx, userID)),
		"mode":            a.cfg.Policies.Mode(ctx, userID),
		"categories":      security.Categories,
		"lockedByManager": security.ManagerLocks(ctx, a.cfg.DB, userID),
	})
}

func (a *API) handlePutPolicy(w http.ResponseWriter, r *http.Request, userID int64) {
	b := body(r)
	category := text(b["category"])
	policy := text(b["policy"])
	// App versions from before "Always" merged into "Allow" still send allow_always.
	if policy == "allow_always" {
		policy = "allow"
	}
	if category == "" || policy == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "category and policy are required"})
		return
	}
	if err := a.cfg.Policies.SetPolicy(r.Context(), userID, category, policy); err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": err.Error()})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true, "category": category, "policy": policy})
}

func (a *API) handleApproval(w http.ResponseWriter, r *http.Request, userID int64) {
	id := r.PathValue("approvalId")
	b := body(r)
	decision := text(b["decision"])
	if decision != "approved" && decision != "denied" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "decision must be approved or denied"})
		return
	}
	scope := text(b["scope"])
	if scope != "session" && scope != "always" {
		scope = "once"
	}
	ctx := r.Context()
	if a.cfg.Gate.Decide(ctx, id, userID, decision, scope) == nil {
		expired := map[string]any{"error": "Approval expired because the run was interrupted or the server restarted."}
		if status := a.cfg.Gate.StoredStatus(ctx, id, userID); status == "expired" || status == "timeout" {
			httpx.WriteJSON(w, http.StatusGone, expired)
			return
		}
		if runID := text(b["runId"]); runID != "" {
			var status string
			if a.cfg.DB.R.QueryRowContext(ctx, `SELECT status FROM agent_runs WHERE id = ? AND user_id = ?`, runID, userID).Scan(&status) == nil && status == "interrupted" {
				httpx.WriteJSON(w, http.StatusGone, expired)
				return
			}
		}
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "Approval not found or already resolved"})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"ok": true, "approvalId": id, "decision": decision, "scope": scope})
}

func number(raw string, fallback int) int {
	if raw == "" {
		return fallback
	}
	f, err := strconv.ParseFloat(raw, 64)
	if err != nil || f != f || int(f) == 0 {
		return fallback
	}
	return int(f)
}

func (a *API) handleApprovalLog(w http.ResponseWriter, r *http.Request, userID int64) {
	q := r.URL.Query()
	limit := min(number(q.Get("limit"), 50), 200)
	offset := number(q.Get("offset"), 0)
	ctx := r.Context()
	rows, err := a.cfg.DB.R.QueryContext(ctx, `SELECT id, run_id, tool_name, tool_args_json, decision, scope, decided_at FROM tool_approval_log
		WHERE user_id = ? ORDER BY decided_at DESC LIMIT ? OFFSET ?`, userID, limit, offset)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "Something went wrong. Please try again."})
		return
	}
	defer rows.Close()
	log := []map[string]any{}
	for rows.Next() {
		var id, run, tool, decision, scope string
		var args, decided *string
		if rows.Scan(&id, &run, &tool, &args, &decision, &scope, &decided) != nil {
			continue
		}
		log = append(log, map[string]any{"id": id, "run_id": run, "tool_name": tool, "tool_args_json": args, "decision": decision, "scope": scope, "decided_at": decided})
	}
	var total int
	_ = a.cfg.DB.R.QueryRowContext(ctx, `SELECT COUNT(*) FROM tool_approval_log WHERE user_id = ?`, userID).Scan(&total)
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"log": log, "total": total, "limit": limit, "offset": offset})
}
