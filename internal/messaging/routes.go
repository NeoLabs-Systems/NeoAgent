package messaging

import (
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/apperr"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/ratelimit"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// Routes registers the /api/messaging endpoints on mux.
func (m *Manager) Routes(mux *http.ServeMux) {
	sharedLimit := ratelimit.New(ratelimit.Config{
		Window:  10 * time.Minute,
		Max:     20,
		Message: "Too many link requests, slow down",
		Key: func(r *http.Request) string {
			if uid, ok := m.authUserID(r); ok && uid > 0 {
				return strconv.FormatInt(uid, 10)
			}
			return "anonymous"
		},
	}).Middleware

	mux.HandleFunc("POST /api/messaging/webhook/{platform}", m.handleWebhook)
	mux.HandleFunc("GET /api/messaging/shared", m.requireAuth(m.handleListShared))
	mux.Handle("POST /api/messaging/shared/{platform}/link", sharedLimit(m.requireAuth(m.handleStartSharedLink)))
	mux.HandleFunc("DELETE /api/messaging/shared/{platform}/link", m.requireAuth(m.handleUnlinkShared))
	mux.HandleFunc("GET /api/messaging/status", m.requireAuth(m.handleAllStatuses))
	mux.HandleFunc("POST /api/messaging/connect", m.requireAuth(m.handleConnect))
	mux.HandleFunc("POST /api/messaging/disconnect", m.requireAuth(m.handleDisconnect))
	mux.HandleFunc("POST /api/messaging/logout", m.requireAuth(m.handleLogout))
	mux.HandleFunc("POST /api/messaging/send", m.requireAuth(m.handleSend))
	mux.HandleFunc("GET /api/messaging/messages", m.requireAuth(m.handleMessages))
	mux.HandleFunc("GET /api/messaging/{first}/{second}", m.requireAuth(func(w http.ResponseWriter, r *http.Request, userID int64) {
		first, second := r.PathValue("first"), r.PathValue("second")
		switch {
		case first == "status":
			m.handlePlatformStatus(w, r, userID, second)
		case second == "access-policy":
			m.handleGetAccessPolicy(w, r, userID, first)
		case second == "devices":
			m.handleDevices(w, r, userID, first)
		default:
			httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "Not found"})
		}
	}))
	mux.HandleFunc("PUT /api/messaging/{platform}/access-policy", m.requireAuth(m.handlePutAccessPolicy))
	mux.HandleFunc("PUT /api/messaging/discord/whitelist", m.requireAuth(m.handleLegacyWhitelist("discord")))
	mux.HandleFunc("PUT /api/messaging/telegram/whitelist", m.requireAuth(m.handleLegacyWhitelist("telegram")))
	mux.HandleFunc("PUT /api/messaging/{platform}/whitelist", m.requireAuth(m.handleGenericWhitelist))
}

func (m *Manager) authUserID(r *http.Request) (int64, bool) {
	if m.cfg.UserID != nil {
		return m.cfg.UserID(r)
	}
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}

func (m *Manager) requireAuth(next func(http.ResponseWriter, *http.Request, int64)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		uid, ok := m.authUserID(r)
		if !ok || uid <= 0 {
			httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
			return
		}
		next(w, r, uid)
	}
}

func (m *Manager) agentFromRequest(r *http.Request, userID int64) string {
	cand := strings.TrimSpace(r.URL.Query().Get("agentId"))
	if cand == "" {
		cand = strings.TrimSpace(r.Header.Get("X-Agent-Id"))
	}
	return m.resolveAgent(r.Context(), userID, cand)
}

func (m *Manager) handleWebhook(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 2<<20))
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid webhook body"})
		return
	}
	res := m.HandlePlatformWebhook(r.PathValue("platform"), r, body)
	status := res.Status
	if status == 0 {
		if res.Handled {
			status = http.StatusOK
		} else {
			status = http.StatusNotFound
		}
	}
	switch v := res.Body.(type) {
	case nil:
		w.WriteHeader(status)
		if res.Handled {
			_, _ = w.Write([]byte("OK"))
		} else {
			_, _ = w.Write([]byte("Not found"))
		}
	case string:
		w.WriteHeader(status)
		_, _ = w.Write([]byte(v))
	default:
		httpx.WriteJSON(w, status, v)
	}
}

// writeError answers as sendJsonError: a client-facing error with its
// status and code, anything else as a sanitized 500.
func writeError(w http.ResponseWriter, err error) {
	if e, ok := apperr.As(err); ok && e.Status < 500 {
		body := map[string]any{"error": e.Message}
		if e.Code != "" {
			body["code"] = e.Code
		}
		httpx.WriteJSON(w, e.Status, body)
		return
	}
	httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
}

// handleListShared lists the instance-wide accounts this user can link to.
func (m *Manager) handleListShared(w http.ResponseWriter, r *http.Request, userID int64) {
	options := []SharedOption{}
	if m.shared != nil {
		var err error
		if options, err = m.shared.ListOptions(r.Context(), userID); err != nil {
			writeError(w, err)
			return
		}
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"options": options})
}

func (m *Manager) handleStartSharedLink(w http.ResponseWriter, r *http.Request, userID int64) {
	if m.shared == nil {
		writeError(w, apperr.New(409, "The shared "+r.PathValue("platform")+" account is not available right now", "SHARED_UNAVAILABLE"))
		return
	}
	res, err := m.shared.StartLink(r.Context(), userID, m.agentFromRequest(r, userID), r.PathValue("platform"))
	if err != nil {
		writeError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (m *Manager) handleUnlinkShared(w http.ResponseWriter, r *http.Request, userID int64) {
	if m.shared == nil {
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"status": "not_configured"})
		return
	}
	res, err := m.shared.Unlink(r.Context(), userID, r.PathValue("platform"), "")
	if err != nil {
		writeError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (m *Manager) handleAllStatuses(w http.ResponseWriter, r *http.Request, userID int64) {
	agentID := m.agentFromRequest(r, userID)
	httpx.WriteJSON(w, http.StatusOK, m.AllStatuses(r.Context(), userID, agentID))
}

func (m *Manager) handleConnect(w http.ResponseWriter, r *http.Request, userID int64) {
	var body struct {
		Platform string         `json:"platform"`
		Config   map[string]any `json:"config"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&body); err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid JSON body"})
		return
	}
	if strings.TrimSpace(body.Platform) == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Platform is required"})
		return
	}
	agentID := m.agentFromRequest(r, userID)
	res, err := m.ConnectPlatform(r.Context(), userID, agentID, body.Platform, body.Config, true)
	if err != nil {
		writeError(w, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (m *Manager) handleDisconnect(w http.ResponseWriter, r *http.Request, userID int64) {
	var body struct {
		Platform string `json:"platform"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 64*1024)).Decode(&body); err != nil || strings.TrimSpace(body.Platform) == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Platform is required"})
		return
	}
	agentID := m.agentFromRequest(r, userID)
	res, err := m.DisconnectPlatform(r.Context(), userID, agentID, body.Platform)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (m *Manager) handleLogout(w http.ResponseWriter, r *http.Request, userID int64) {
	var body struct {
		Platform string `json:"platform"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 64*1024)).Decode(&body); err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Platform is required"})
		return
	}
	agentID := m.agentFromRequest(r, userID)
	res, err := m.LogoutPlatform(r.Context(), userID, agentID, body.Platform)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (m *Manager) handleSend(w http.ResponseWriter, r *http.Request, userID int64) {
	var body struct {
		Platform  string `json:"platform"`
		To        string `json:"to"`
		Content   string `json:"content"`
		MediaPath string `json:"mediaPath"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<20)).Decode(&body); err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid JSON body"})
		return
	}
	if body.Platform == "" || body.To == "" || body.Content == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "platform, to, and content required"})
		return
	}
	agentID := m.agentFromRequest(r, userID)
	res, err := m.SendMessage(r.Context(), userID, agentID, body.Platform, body.To, body.Content, body.MediaPath)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (m *Manager) handleMessages(w http.ResponseWriter, r *http.Request, userID int64) {
	if m.cfg.DB == nil {
		httpx.WriteJSON(w, http.StatusOK, []any{})
		return
	}
	agentID := m.agentFromRequest(r, userID)
	platform := strings.TrimSpace(r.URL.Query().Get("platform"))
	chatID := strings.TrimSpace(r.URL.Query().Get("chatId"))
	limit := 50
	if n, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && n > 0 {
		limit = min(n, 200)
	}
	query := `SELECT id, user_id, agent_id, platform, platform_chat_id, role, content, created_at FROM messages WHERE user_id = ? AND agent_id = ?`
	args := []any{userID, agentID}
	if platform != "" {
		query += ` AND platform = ?`
		args = append(args, platform)
	}
	if chatID != "" {
		query += ` AND platform_chat_id = ?`
		args = append(args, chatID)
	}
	query += ` ORDER BY created_at DESC LIMIT ?`
	args = append(args, limit)
	rows, err := m.cfg.DB.R.QueryContext(r.Context(), query, args...)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "Internal server error"})
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id int64
		var uid int64
		var aid, plat, cid, role, content, createdAt string
		if err := rows.Scan(&id, &uid, &aid, &plat, &cid, &role, &content, &createdAt); err == nil {
			out = append(out, map[string]any{
				"id": id, "user_id": uid, "agent_id": aid, "platform": plat,
				"platform_chat_id": cid, "role": role, "content": content, "created_at": createdAt,
			})
		}
	}
	httpx.WriteJSON(w, http.StatusOK, out)
}

func (m *Manager) handlePlatformStatus(w http.ResponseWriter, r *http.Request, userID int64, platform string) {
	agentID := m.agentFromRequest(r, userID)
	httpx.WriteJSON(w, http.StatusOK, m.GetPlatformStatus(r.Context(), userID, agentID, platform))
}

func (m *Manager) handleGetAccessPolicy(w http.ResponseWriter, r *http.Request, userID int64, rawPlatform string) {
	platform := sanitizePlatform(rawPlatform)
	if platform == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "platform is required"})
		return
	}
	agentID := m.agentFromRequest(r, userID)
	cat, err := m.GetAccessCatalog(r.Context(), userID, agentID, platform)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, cat)
}

func (m *Manager) handlePutAccessPolicy(w http.ResponseWriter, r *http.Request, userID int64) {
	platform := sanitizePlatform(r.PathValue("platform"))
	if platform == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "platform is required"})
		return
	}
	var raw map[string]any
	if err := json.NewDecoder(io.LimitReader(r.Body, 256*1024)).Decode(&raw); err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid JSON body"})
		return
	}
	payload := any(raw)
	if inner, ok := raw["policy"]; ok {
		payload = inner
	}
	policy := NormalizeAccessPolicy(platform, payload)
	agentID := m.agentFromRequest(r, userID)
	saved, err := m.SetAccessPolicy(r.Context(), userID, agentID, platform, policy)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"success": true,
		"policy":  saved,
		"summary": SummarizeAccessPolicy(platform, saved),
	})
}

func (m *Manager) handleDevices(w http.ResponseWriter, r *http.Request, userID int64, platform string) {
	agentID := m.agentFromRequest(r, userID)
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"devices": m.GetPlatformDevices(r.Context(), userID, agentID, platform),
	})
}

func (m *Manager) handleLegacyWhitelist(platform string) func(http.ResponseWriter, *http.Request, int64) {
	return func(w http.ResponseWriter, r *http.Request, userID int64) {
		var body struct {
			IDs []any `json:"ids"`
		}
		if err := json.NewDecoder(io.LimitReader(r.Body, 256*1024)).Decode(&body); err != nil || body.IDs == nil {
			httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "ids must be an array"})
			return
		}
		list := make([]string, 0, len(body.IDs))
		for _, item := range body.IDs {
			cleaned := legacyIDRe.ReplaceAllString(jsOrEmpty(item), "")
			if cleaned != "" {
				list = append(list, cleaned)
			}
		}
		agentID := m.agentFromRequest(r, userID)
		if err := m.UpdateAllowedEntries(r.Context(), userID, agentID, platform, list); err != nil {
			httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
			return
		}
		httpx.WriteJSON(w, http.StatusOK, map[string]any{"success": true, "ids": list})
	}
}

func (m *Manager) handleGenericWhitelist(w http.ResponseWriter, r *http.Request, userID int64) {
	platform := sanitizePlatform(r.PathValue("platform"))
	if platform == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "platform is required"})
		return
	}
	var body struct {
		IDs []any `json:"ids"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 256*1024)).Decode(&body); err != nil || body.IDs == nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "ids must be an array"})
		return
	}
	list := make([]string, 0, len(body.IDs))
	for _, item := range body.IDs {
		cleaned := prefixedIDRe.ReplaceAllString(jsOrEmpty(item), "")
		if cleaned != "" {
			list = append(list, cleaned)
		}
	}
	agentID := m.agentFromRequest(r, userID)
	if err := m.UpdateAllowedEntries(r.Context(), userID, agentID, platform, list); err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"success": true, "ids": list})
}
