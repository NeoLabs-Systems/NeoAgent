package neorouterapi

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/ratelimit"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// Routes registers the /api/neorouter endpoints on mux.
func (s *Service) Routes(mux *http.ServeMux) {
	writeLimit := ratelimit.New(ratelimit.Config{
		Window:  time.Minute,
		Max:     20,
		Message: "Too many requests, try again in a minute.",
		Key: func(r *http.Request) string {
			if sess := sessionx.FromContext(r.Context()); sess != nil {
				if uid, ok := sess.Int64("userId"); ok && uid > 0 {
					return "user:" + strconv.FormatInt(uid, 10)
				}
			}
			return ratelimit.ClientIP(r)
		},
	}).Middleware

	mux.HandleFunc("GET /api/neorouter", s.requireAuth(s.handleGet))
	mux.Handle("POST /api/neorouter/connect", writeLimit(s.requireAuth(s.handleConnect)))
	mux.HandleFunc("GET /api/neorouter/connect/{id}", s.requireAuth(s.handleConnectStatus))
	mux.Handle("PUT /api/neorouter/{scope}/roles", writeLimit(s.requireAuth(s.handleUpdateRoles)))
	mux.Handle("DELETE /api/neorouter/{scope}", writeLimit(s.requireAuth(s.handleDisconnect)))
}

func (s *Service) requireAuth(next func(http.ResponseWriter, *http.Request, int64)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		sess := sessionx.FromContext(r.Context())
		if sess == nil {
			httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
			return
		}
		userID, ok := sess.Int64("userId")
		if !ok || userID <= 0 {
			httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
			return
		}
		next(w, r, userID)
	}
}

func (s *Service) isAdmin(ctx context.Context, userID int64) bool {
	return s.accounts != nil && s.accounts.IsAdmin(ctx, userID)
}

func (s *Service) agentOf(r *http.Request, userID int64) string {
	raw := strings.TrimSpace(r.URL.Query().Get("agentId"))
	if raw == "" {
		raw = strings.TrimSpace(r.Header.Get("X-Agent-Id"))
	}
	if s.accounts != nil {
		return s.accounts.ResolveAgentID(r.Context(), userID, raw)
	}
	if raw == "" {
		return "main"
	}
	return raw
}

func (s *Service) scopeOf(w http.ResponseWriter, r *http.Request, userID int64, rawScope string) (string, bool) {
	if rawScope != "server" && rawScope != "user" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": `scope must be "server" or "user".`})
		return "", false
	}
	if rawScope == "server" && !s.isAdmin(r.Context(), userID) {
		httpx.WriteJSON(w, http.StatusForbidden, map[string]any{
			"error": "Only an admin can connect NeoRouter for the whole server.",
			"code":  "ADMIN_REQUIRED",
		})
		return "", false
	}
	return rawScope, true
}

type connectionState struct {
	Connected bool     `json:"connected"`
	Address   *string  `json:"address"`
	Roles     []string `json:"roles"`
	Offer     *Offer   `json:"offer"`
	Reachable *bool    `json:"reachable,omitempty"`
}

func (s *Service) describe(ctx context.Context, conn *Connection, scope string, userID int64, agentID string) connectionState {
	if conn == nil {
		return connectionState{Connected: false, Address: nil, Roles: []string{}, Offer: nil}
	}
	offer, _ := s.DescribeOffer(ctx, conn, true)
	if offer != nil {
		_ = s.ApplyLiveChoice(ctx, conn, scope, userID, agentID, true, offer)
	}
	addr := conn.Origin
	roles := append([]string(nil), conn.Roles...)
	if roles == nil {
		roles = []string{}
	}
	reachable := offer != nil
	return connectionState{
		Connected: true,
		Address:   &addr,
		Roles:     roles,
		Offer:     offer,
		Reachable: &reachable,
	}
}

func (s *Service) handleGet(w http.ResponseWriter, r *http.Request, userID int64) {
	ctx := r.Context()
	isAdmin := s.isAdmin(ctx, userID)
	agentID := s.agentOf(r, userID)
	server := s.ServerConnection()
	userConn, _ := s.UserConnection(ctx, userID, agentID)

	var (
		wg          sync.WaitGroup
		serverState any
		userState   connectionState
	)
	wg.Add(2)
	go func() {
		defer wg.Done()
		if isAdmin {
			serverState = s.describe(ctx, server, "server", userID, "")
		} else {
			serverState = map[string]any{"connected": server != nil}
		}
	}()
	go func() {
		defer wg.Done()
		userState = s.describe(ctx, userConn, "user", userID, agentID)
	}()
	wg.Wait()

	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"roles":   Roles,
		"isAdmin": isAdmin,
		"server":  serverState,
		"user":    userState,
	})
}

func (s *Service) handleConnect(w http.ResponseWriter, r *http.Request, userID int64) {
	var body struct {
		Scope   string `json:"scope"`
		Address string `json:"address"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 16*1024)).Decode(&body); err != nil && err != io.EOF {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid JSON body."})
		return
	}
	scope, ok := s.scopeOf(w, r, userID, body.Scope)
	if !ok {
		return
	}
	address := strings.TrimSpace(body.Address)
	apiBase := APIBaseFor(address)
	serverConn := s.ServerConnection()
	if scope == "user" && apiBase != "" && (serverConn == nil || apiBase != serverConn.APIBase) {
		res, err := s.checker.Validate(r.Context(), apiBase)
		if err != nil {
			httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
			return
		}
		if !res.Allowed {
			httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": res.Reason})
			return
		}
	}
	agentID := ""
	if scope == "user" {
		agentID = s.agentOf(r, userID)
	}
	out, err := s.BeginSignIn(r.Context(), BeginSignInInput{
		Scope:   scope,
		UserID:  userID,
		AgentID: agentID,
		Address: address,
	})
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, out)
}

func (s *Service) handleConnectStatus(w http.ResponseWriter, r *http.Request, userID int64) {
	res, ok := s.SignInStatus(r.PathValue("id"), userID)
	if !ok {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "This sign-in expired. Start again."})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}

func (s *Service) handleUpdateRoles(w http.ResponseWriter, r *http.Request, userID int64) {
	scope, ok := s.scopeOf(w, r, userID, r.PathValue("scope"))
	if !ok {
		return
	}
	var body struct {
		Roles []string `json:"roles"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 16*1024)).Decode(&body); err != nil || body.Roles == nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "roles must be a list."})
		return
	}
	roles, err := s.UpdateRoles(r.Context(), scope, userID, s.agentOf(r, userID), body.Roles)
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"roles": roles})
}

func (s *Service) handleDisconnect(w http.ResponseWriter, r *http.Request, userID int64) {
	scope, ok := s.scopeOf(w, r, userID, r.PathValue("scope"))
	if !ok {
		return
	}
	if err := s.Disconnect(r.Context(), scope, userID, s.agentOf(r, userID)); err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"success": true})
}
