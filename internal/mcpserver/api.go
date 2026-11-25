package mcpserver

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const bodyLimit = 1 << 20

// Auditor reports on the MCP servers of an account (the security domain's
// capability audit): GET /api/mcp/audit answers with its result.
type Auditor interface {
	AuditMcp(ctx context.Context, userID int64, agentID string) (any, error)
}

// Config wires the routes.
type Config struct {
	Manager *Manager
	Agents  agentscope.Resolver
	Log     *slog.Logger
	// Auditor serves GET /api/mcp/audit; nil leaves that route unregistered.
	Auditor Auditor
	// PublicBaseURL is the server's public address (PUBLIC_URL or the
	// localhost default). Its origin is the only target of the OAuth popup's
	// postMessage; without it the request's own host is used.
	PublicBaseURL string
	// UserID returns the signed-in account of a request. Nil reads "userId"
	// from the session.
	UserID func(*http.Request) (int64, bool)
}

// API serves /api/mcp.
type API struct {
	mgr     *Manager
	store   *Store
	agents  agentscope.Resolver
	log     *slog.Logger
	auditor Auditor
	origin  string
	userID  func(*http.Request) (int64, bool)
}

// New builds the API.
func New(cfg Config) *API {
	userID := cfg.UserID
	if userID == nil {
		userID = func(r *http.Request) (int64, bool) {
			sess := sessionx.FromContext(r.Context())
			if sess == nil {
				return 0, false
			}
			return sess.Int64("userId")
		}
	}
	origin := ""
	if u, err := url.Parse(cfg.PublicBaseURL); err == nil && u.Scheme != "" && u.Host != "" {
		origin = u.Scheme + "://" + u.Host
	}
	return &API{mgr: cfg.Manager, store: cfg.Manager.store, agents: cfg.Agents, log: cfg.Log, auditor: cfg.Auditor, origin: origin, userID: userID}
}

type body map[string]json.RawMessage

type handler func(w http.ResponseWriter, r *http.Request, userID int64, b body)

// Routes registers the /api/mcp routes on mux.
func (a *API) Routes(mux *http.ServeMux) {
	route := func(pattern string, fn handler) { mux.Handle(pattern, a.guard(fn)) }
	if a.auditor != nil {
		route("GET /api/mcp/audit", a.audit)
	}
	route("GET /api/mcp/{$}", a.list)
	route("GET /api/mcp", a.list)
	route("POST /api/mcp/{$}", a.add)
	route("POST /api/mcp", a.add)
	route("PUT /api/mcp/{id}", a.update)
	route("DELETE /api/mcp/{id}", a.remove)
	route("POST /api/mcp/{id}/start", a.start)
	route("POST /api/mcp/{id}/stop", a.stop)
	route("GET /api/mcp/{id}/tools", a.tools)
	route("GET /api/mcp/oauth/callback", a.oauthCallback)
	route("GET /api/mcp/tools/all", a.allTools)
	route("POST /api/mcp/tools/call", a.call)
}

func (a *API) guard(fn handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		userID, ok := a.userID(r)
		if !ok {
			httpx.Error(w, 401, "Unauthorized")
			return
		}
		var b body
		if strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
			raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, bodyLimit))
			if err != nil {
				httpx.Error(w, 413, "Request body too large")
				return
			}
			if raw = bytes.TrimSpace(raw); len(raw) > 0 {
				if err := json.Unmarshal(raw, &b); err != nil {
					httpx.Error(w, 400, "Invalid JSON body")
					return
				}
			}
		}
		fn(w, r, userID, b)
	})
}

func (a *API) fail(w http.ResponseWriter, status int, err error) {
	if status >= 500 {
		a.log.Error("mcp route failed", "error", err)
	}
	httpx.Error(w, status, err.Error())
}

func (a *API) agentFor(r *http.Request, userID int64, b body) (string, error) {
	return a.agents.Resolve(r.Context(), userID, agentscope.Candidate(r, b))
}

func (a *API) audit(w http.ResponseWriter, r *http.Request, userID int64, b body) {
	agentID, err := a.agentFor(r, userID, b)
	if err == nil {
		var result any
		if result, err = a.auditor.AuditMcp(r.Context(), userID, agentID); err == nil {
			httpx.WriteJSON(w, 200, result)
			return
		}
	}
	a.fail(w, 500, err)
}

// serverView is one entry of GET /api/mcp, with Node's key order.
type serverView struct {
	ID               int64  `json:"id"`
	Name             string `json:"name"`
	Command          string `json:"command"`
	Config           any    `json:"config"`
	AgentID          any    `json:"agentId"`
	Enabled          bool   `json:"enabled"`
	Status           string `json:"status"`
	ToolCount        int    `json:"toolCount"`
	Error            any    `json:"error"`
	ConsecutiveFails int    `json:"consecutiveFails"`
	NextRetryAt      any    `json:"nextRetryAt"`
}

func (a *API) list(w http.ResponseWriter, r *http.Request, userID int64, b body) {
	agentID, err := a.agentFor(r, userID, b)
	if err != nil {
		a.fail(w, 500, err)
		return
	}
	legacy, err := a.agents.IsMain(r.Context(), userID, agentID)
	if err != nil {
		a.fail(w, 500, err)
		return
	}
	rows, err := a.store.ForAgent(r.Context(), userID, agentID, legacy)
	if err != nil {
		a.fail(w, 500, err)
		return
	}
	live := a.mgr.Status(userID, agentID)
	out := make([]serverView, 0, len(rows))
	for _, s := range rows {
		cfg, err := a.store.DecodeConfig(s.Config)
		if err != nil {
			a.fail(w, 500, err)
			return
		}
		l, isLive := live[s.ID]
		status := s.Status
		if isLive && l.Status != "" {
			status = l.Status
		}
		if status == "" {
			status = "stopped"
		}
		var agent, lastErr, retry any
		if s.AgentID != "" {
			agent = s.AgentID
		}
		if l.Error != "" {
			lastErr = l.Error
		}
		if l.NextRetryAt != "" {
			retry = l.NextRetryAt
		}
		out = append(out, serverView{
			ID: s.ID, Name: s.Name, Command: s.Command, Config: cfg, AgentID: agent, Enabled: s.Enabled, Status: status,
			ToolCount: l.ToolCount, Error: lastErr, ConsecutiveFails: l.ConsecutiveFails, NextRetryAt: retry,
		})
	}
	httpx.WriteJSON(w, 200, out)
}

// jsString is String(value) for a JSON value JavaScript treats as set.
func jsString(raw json.RawMessage) (string, bool) {
	if len(raw) == 0 {
		return "", false
	}
	var v any
	if json.Unmarshal(raw, &v) != nil {
		return "", false
	}
	switch t := v.(type) {
	case string:
		return t, t != ""
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64), t != 0
	case bool:
		return "true", t
	case nil:
		return "", false
	}
	return "[object Object]", true
}

// truthy is JavaScript truthiness of a JSON member.
func truthy(raw json.RawMessage) bool {
	_, ok := jsString(raw)
	return ok
}

// configOf reads the config member, `config || fallback`.
func configOf(raw json.RawMessage, fallback map[string]any) (map[string]any, error) {
	if !truthy(raw) {
		return fallback, nil
	}
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil || m == nil {
		return nil, errors.New("config must be an object")
	}
	return m, nil
}

func (a *API) add(w http.ResponseWriter, r *http.Request, userID int64, b body) {
	agentID, err := a.agentFor(r, userID, b)
	if err != nil {
		a.fail(w, 400, err)
		return
	}
	name, okName := jsString(b["name"])
	command, okCommand := jsString(b["command"])
	if !okName || !okCommand {
		httpx.Error(w, 400, "name and command are required")
		return
	}
	endpoint, err := ValidateEndpoint(command)
	if err != nil {
		a.fail(w, 400, err)
		return
	}
	cfg, err := configOf(b["config"], map[string]any{})
	if err != nil {
		a.fail(w, 400, err)
		return
	}
	enabled := string(bytes.TrimSpace(b["enabled"])) != "false"
	id, err := a.store.Insert(r.Context(), userID, agentID, name, endpoint, cfg, enabled)
	if err != nil {
		a.fail(w, 400, err)
		return
	}
	httpx.WriteJSON(w, 201, struct {
		ID      int64  `json:"id"`
		Name    string `json:"name"`
		Command string `json:"command"`
	}{id, name, endpoint})
}

// owned loads the server named in the URL or answers 404.
func (a *API) owned(w http.ResponseWriter, r *http.Request, userID int64) (Row, bool) {
	row, ok, err := a.store.Owned(r.Context(), userID, r.PathValue("id"))
	if err != nil {
		a.fail(w, 500, err)
		return Row{}, false
	}
	if !ok {
		httpx.Error(w, 404, "Server not found")
	}
	return row, ok
}

func (a *API) update(w http.ResponseWriter, r *http.Request, userID int64, b body) {
	server, ok := a.owned(w, r, userID)
	if !ok {
		return
	}
	wasLive := a.mgr.IsLive(server.ID)
	_, hasAgent := b["agentId"]
	_, hasSnake := b["agent_id"]
	agentID := server.AgentID
	var err error
	if hasAgent || hasSnake || agentID == "" {
		candidate := ""
		if hasAgent || hasSnake {
			candidate = agentscope.Candidate(r, b)
		}
		agentID, err = a.agents.Resolve(r.Context(), userID, candidate)
		if err != nil {
			a.fail(w, 400, err)
			return
		}
	}
	name := server.Name
	if s, ok := jsString(b["name"]); ok {
		name = s
	}
	endpoint := server.Command
	if s, ok := jsString(b["command"]); ok {
		if endpoint, err = ValidateEndpoint(s); err != nil {
			a.fail(w, 400, err)
			return
		}
	}
	current, err := a.store.DecodeConfig(server.Config)
	if err != nil {
		a.fail(w, 400, err)
		return
	}
	cfg, err := configOf(b["config"], current)
	if err != nil {
		a.fail(w, 400, err)
		return
	}
	enabled := server.Enabled
	if raw, present := b["enabled"]; present {
		enabled = truthy(raw)
	}
	if err := a.store.Update(r.Context(), server.ID, agentID, name, endpoint, cfg, enabled); err != nil {
		a.fail(w, 400, err)
		return
	}
	if wasLive {
		a.mgr.Stop(server.ID)
	}
	httpx.WriteJSON(w, 200, struct {
		Success bool   `json:"success"`
		Status  string `json:"status"`
	}{true, "stopped"})
}

func (a *API) remove(w http.ResponseWriter, r *http.Request, userID int64, _ body) {
	server, ok := a.owned(w, r, userID)
	if !ok {
		return
	}
	a.mgr.Stop(server.ID)
	if err := a.store.Delete(r.Context(), server.ID); err != nil {
		a.fail(w, 500, err)
		return
	}
	httpx.WriteJSON(w, 200, map[string]any{"success": true})
}

func (a *API) start(w http.ResponseWriter, r *http.Request, userID int64, _ body) {
	server, ok := a.owned(w, r, userID)
	if !ok {
		return
	}
	res, err := a.mgr.Start(r.Context(), server.ID, server.Command, server.Name, userID, server.AgentID)
	if err != nil {
		if url, found := strings.CutPrefix(err.Error(), oauthRedirect); found {
			httpx.WriteJSON(w, 200, map[string]any{"status": "oauth_redirect", "url": url})
			return
		}
		a.fail(w, 500, err)
		return
	}
	httpx.WriteJSON(w, 200, struct {
		Status string           `json:"status"`
		Tools  []map[string]any `json:"tools"`
	}{res.Status, res.Tools})
}

func (a *API) stop(w http.ResponseWriter, r *http.Request, userID int64, _ body) {
	server, ok := a.owned(w, r, userID)
	if !ok {
		return
	}
	a.mgr.Stop(server.ID)
	httpx.WriteJSON(w, 200, map[string]any{"status": "stopped"})
}

func (a *API) tools(w http.ResponseWriter, r *http.Request, userID int64, _ body) {
	server, ok := a.owned(w, r, userID)
	if !ok {
		return
	}
	tools, err := a.mgr.ListTools(server.ID, userID)
	if err != nil {
		a.fail(w, 500, err)
		return
	}
	httpx.WriteJSON(w, 200, tools)
}

func (a *API) allTools(w http.ResponseWriter, r *http.Request, userID int64, b body) {
	agentID, err := a.agentFor(r, userID, b)
	if err != nil {
		a.fail(w, 500, err)
		return
	}
	httpx.WriteJSON(w, 200, a.mgr.AllTools(userID, agentID))
}

func (a *API) call(w http.ResponseWriter, r *http.Request, userID int64, b body) {
	serverID, okServer := jsString(b["serverId"])
	tool, okTool := jsString(b["toolName"])
	if !okServer || !okTool {
		httpx.Error(w, 400, "serverId and toolName required")
		return
	}
	agentID, err := a.agentFor(r, userID, b)
	if err != nil {
		a.fail(w, 500, err)
		return
	}
	found, err := a.store.OwnedBy(r.Context(), userID, serverID, agentID)
	if err != nil {
		a.fail(w, 500, err)
		return
	}
	id, perr := strconv.ParseInt(serverID, 10, 64)
	if !found || perr != nil {
		httpx.Error(w, 404, "Server not found")
		return
	}
	var args map[string]any
	if truthy(b["args"]) {
		if err := json.Unmarshal(b["args"], &args); err != nil {
			args = nil
		}
	}
	result, err := a.mgr.CallTool(id, tool, args, userID)
	if err != nil {
		a.fail(w, 500, err)
		return
	}
	httpx.WriteJSON(w, 200, result)
}

func plain(w http.ResponseWriter, status int, text string) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(status)
	_, _ = io.WriteString(w, text)
}

func html(w http.ResponseWriter, status int, text string) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	_, _ = io.WriteString(w, text)
}

// trustedOrigin is where the sign-in popup may post its result.
func (a *API) trustedOrigin(r *http.Request) string {
	if a.origin != "" {
		return a.origin
	}
	if r.Host == "" {
		return ""
	}
	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}
	return scheme + "://" + r.Host
}

const successPage = `
      <html><body>
      <script>
        if (window.opener) {
          window.opener.postMessage({ type: 'mcp_oauth_success', serverId: %d }, %s);
          window.close();
        } else {
          window.location.href = '/?page=mcp';
        }
      </script>
      <p>Authentication successful. You can close this window.</p>
      </body></html>
    `

func (a *API) oauthCallback(w http.ResponseWriter, r *http.Request, userID int64, _ body) {
	q := r.URL.Query()
	state, code, oauthErr := q.Get("state"), q.Get("code"), q.Get("error")
	if state == "" {
		plain(w, 400, "Missing state parameter")
		return
	}
	match := oauthStateRE.FindStringSubmatch(state)
	if match == nil {
		plain(w, 400, "Invalid state format")
		return
	}
	serverID, err := strconv.ParseInt(match[1], 10, 64)
	if err != nil || serverID <= 0 {
		plain(w, 400, "Invalid state format")
		return
	}
	if _, ok, err := a.store.Owned(r.Context(), userID, match[1]); err != nil {
		plain(w, 500, "Server error")
		return
	} else if !ok {
		plain(w, 404, "Server not found")
		return
	}
	if oauthErr == "" && code == "" {
		plain(w, 400, "Missing code parameter")
		return
	}
	if ok, err := a.store.ConsumeState(r.Context(), serverID, state); err != nil || !ok {
		plain(w, 400, "Invalid or expired OAuth state")
		return
	}
	if oauthErr != "" {
		plain(w, 400, "OAuth error: "+oauthErr)
		return
	}
	origin, _ := json.Marshal(a.trustedOrigin(r))
	if _, err := a.mgr.FinishOAuth(r.Context(), serverID, code, q.Get("iss")); err != nil {
		html(w, 500, "Failed to finish OAuth: "+err.Error())
		return
	}
	html(w, 200, fmt.Sprintf(successPage, serverID, origin))
}
