package tasks

import (
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// Routes registers the /api/tasks endpoints on mux.
func (r *Runtime) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/tasks", r.requireAuth(r.handleList))
	mux.HandleFunc("GET /api/tasks/catalog", r.requireAuth(r.handleCatalog))
	mux.HandleFunc("GET /api/tasks/delivery-targets", r.requireAuth(r.handleDeliveryTargets))
	mux.HandleFunc("POST /api/tasks", r.requireAuth(r.handleCreate))
	mux.HandleFunc("PUT /api/tasks/{id}", r.requireAuth(r.handleUpdate))
	mux.HandleFunc("DELETE /api/tasks/{id}", r.requireAuth(r.handleDelete))
	mux.HandleFunc("POST /api/tasks/{id}/run", r.requireAuth(r.handleRunNow))
}

func (r *Runtime) authUserID(req *http.Request) (int64, bool) {
	if r.cfg.UserID != nil {
		return r.cfg.UserID(req)
	}
	sess := sessionx.FromContext(req.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}

func (r *Runtime) requireAuth(next func(http.ResponseWriter, *http.Request, int64)) http.HandlerFunc {
	return func(w http.ResponseWriter, req *http.Request) {
		uid, ok := r.authUserID(req)
		if !ok || uid <= 0 {
			httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
			return
		}
		next(w, req, uid)
	}
}

func (r *Runtime) agentFromRequest(req *http.Request, userID int64) string {
	cand := strings.TrimSpace(req.URL.Query().Get("agentId"))
	if cand == "" {
		cand = strings.TrimSpace(req.Header.Get("X-Agent-Id"))
	}
	agentID, err := r.resolveAgent(req.Context(), userID, cand)
	if err != nil || agentID == "" {
		return "main"
	}
	return agentID
}

func parseTaskID(raw string) (int64, bool) {
	id, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || id <= 0 {
		return 0, false
	}
	return id, true
}

func decodeTaskObject(req *http.Request) (*jsv.Object, error) {
	raw, err := io.ReadAll(io.LimitReader(req.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	if len(strings.TrimSpace(string(raw))) == 0 {
		return jsv.NewObject(), nil
	}
	// Decoded in document order: nested configs are stored as sent.
	v, err := jsv.Decode(raw)
	if err != nil {
		return nil, err
	}
	if obj, ok := v.(*jsv.Object); ok {
		return obj, nil
	}
	// Destructuring a non-object body in Express reads every field as undefined.
	return jsv.NewObject(), nil
}

func (r *Runtime) handleList(w http.ResponseWriter, req *http.Request, userID int64) {
	agentID := r.agentFromRequest(req, userID)
	list, err := r.ListTasks(req.Context(), userID, agentID)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "Internal server error"})
		return
	}
	if list == nil {
		list = []*jsv.Object{}
	}
	httpx.WriteJSON(w, http.StatusOK, list)
}

func (r *Runtime) handleCatalog(w http.ResponseWriter, req *http.Request, userID int64) {
	agentID := r.agentFromRequest(req, userID)
	cat, err := r.TriggerCatalog(req.Context(), userID, agentID)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "Internal server error"})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, cat)
}

func (r *Runtime) handleDeliveryTargets(w http.ResponseWriter, req *http.Request, userID int64) {
	if r.cfg.Messaging == nil {
		httpx.WriteJSON(w, http.StatusOK, []AccessTarget{})
		return
	}
	agentID := r.agentFromRequest(req, userID)
	platform := strings.TrimSpace(req.URL.Query().Get("platform"))
	targets, err := r.cfg.Messaging.AccessTargets(req.Context(), userID, agentID, platform)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	if targets == nil {
		targets = []AccessTarget{}
	}
	httpx.WriteJSON(w, http.StatusOK, targets)
}

func (r *Runtime) handleCreate(w http.ResponseWriter, req *http.Request, userID int64) {
	body, err := decodeTaskObject(req)
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid JSON body"})
		return
	}
	agentID := r.agentFromRequest(req, userID)
	task, err := r.CreateTask(req.Context(), userID, agentID, body)
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, task)
}

func (r *Runtime) handleUpdate(w http.ResponseWriter, req *http.Request, userID int64) {
	taskID, ok := parseTaskID(req.PathValue("id"))
	if !ok {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid task id"})
		return
	}
	body, err := decodeTaskObject(req)
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid JSON body"})
		return
	}
	task, err := r.UpdateTask(req.Context(), taskID, userID, body)
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, task)
}

func (r *Runtime) handleDelete(w http.ResponseWriter, req *http.Request, userID int64) {
	taskID, ok := parseTaskID(req.PathValue("id"))
	if !ok {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid task id"})
		return
	}
	if err := r.DeleteTask(req.Context(), taskID, userID); err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"success": true})
}

func (r *Runtime) handleRunNow(w http.ResponseWriter, req *http.Request, userID int64) {
	taskID, ok := parseTaskID(req.PathValue("id"))
	if !ok {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid task id"})
		return
	}
	res, err := r.RunTaskNow(req.Context(), taskID, userID)
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}
