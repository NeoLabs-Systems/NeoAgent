package delegation

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/apperr"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/ratelimit"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"

	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
)

// Config configures /api/delegation/*.
type Config struct {
	DB      *dbx.DB
	IsAdmin func(ctx context.Context, userID int64) bool
	// PublicURL is how clients reach this server; empty uses the request's origin.
	PublicURL string
	Log       *slog.Logger
}

// API serves /api/delegation/*.
type API struct {
	cfg Config
	svc *Service
}

// New creates the delegation API.
func New(cfg Config) *API { return &API{cfg: cfg, svc: NewService(cfg.DB)} }

// Service is the access model behind the API, for the security gate.
func (a *API) Service() *Service { return a.svc }

// Routes registers the /api/delegation endpoints.
func (a *API) Routes(mux *http.ServeMux) {
	inviteLimit := ratelimit.New(ratelimit.Config{
		Window:  15 * time.Minute,
		Max:     20,
		Message: map[string]string{"error": "Too many invite link attempts, try again later", "code": "RATE_LIMITED"},
	}).Middleware
	changeLimit := ratelimit.New(ratelimit.Config{
		Window:  15 * time.Minute,
		Max:     120,
		Message: map[string]string{"error": "Too many access changes, slow down", "code": "RATE_LIMITED"},
	}).Middleware

	mux.Handle("GET /api/delegation", a.handle(http.StatusOK, a.summary))
	mux.Handle("POST /api/delegation/invites/preview", inviteLimit(a.handle(http.StatusOK, func(r *http.Request, uid int64, body map[string]any) (any, error) {
		return a.svc.PreviewInvite(r.Context(), uid, body["link"])
	})))
	mux.Handle("POST /api/delegation/invites/redeem", inviteLimit(a.handle(http.StatusOK, func(r *http.Request, uid int64, body map[string]any) (any, error) {
		if err := a.svc.RedeemInvite(r.Context(), uid, body["link"]); err != nil {
			return nil, err
		}
		return a.summary(r, uid, body)
	})))
	mux.Handle("POST /api/delegation/leave", changeLimit(a.handle(http.StatusOK, func(r *http.Request, uid int64, body map[string]any) (any, error) {
		if err := a.svc.Leave(r.Context(), uid); err != nil {
			return nil, err
		}
		return a.summary(r, uid, body)
	})))
	mux.Handle("POST /api/delegation/invites", changeLimit(a.handle(http.StatusCreated, func(r *http.Request, uid int64, body map[string]any) (any, error) {
		invite, token, err := a.svc.CreateInvite(r.Context(), uid, InviteInput{
			Label: body["label"], Permissions: body["permissions"], ExpiresInHours: body["expiresInHours"], MaxUses: body["maxUses"],
		})
		if err != nil {
			return nil, err
		}
		return jsonobj.New("invite", invite, "link", InviteLink(a.publicBaseURL(r), token)), nil
	})))
	mux.Handle("DELETE /api/delegation/invites/{id}", changeLimit(a.handle(http.StatusOK, func(r *http.Request, uid int64, body map[string]any) (any, error) {
		if err := a.svc.RevokeInvite(r.Context(), uid, r.PathValue("id")); err != nil {
			return nil, err
		}
		return a.summary(r, uid, body)
	})))
	mux.Handle("DELETE /api/delegation/managing/{userId}", changeLimit(a.handle(http.StatusOK, func(r *http.Request, uid int64, body map[string]any) (any, error) {
		managed, err := userIDParam(r.PathValue("userId"))
		if err != nil {
			return nil, err
		}
		if err := a.svc.Release(r.Context(), uid, managed); err != nil {
			return nil, err
		}
		return a.summary(r, uid, body)
	})))
	mux.Handle("PUT /api/delegation/managing/{userId}/permissions", changeLimit(a.handle(http.StatusOK, func(r *http.Request, uid int64, body map[string]any) (any, error) {
		managed, err := userIDParam(r.PathValue("userId"))
		if err != nil {
			return nil, err
		}
		if err := a.svc.SetPermission(r.Context(), uid, managed, body["permission"], body["allowed"]); err != nil {
			return nil, err
		}
		return a.summary(r, uid, body)
	})))
	mux.Handle("GET /api/delegation/audit", a.handle(http.StatusOK, func(r *http.Request, uid int64, _ map[string]any) (any, error) {
		if a.cfg.IsAdmin == nil || !a.cfg.IsAdmin(r.Context(), uid) {
			return nil, apperr.New(http.StatusForbidden, "Admin access required", "ADMIN_REQUIRED")
		}
		limit, err := strconv.Atoi(r.URL.Query().Get("limit"))
		if err != nil || limit == 0 {
			limit = 100
		}
		return a.svc.AccessEvents(r.Context(), min(max(limit, 1), 500))
	}))
}

func (a *API) summary(r *http.Request, uid int64, _ map[string]any) (any, error) {
	admin := a.cfg.IsAdmin != nil && a.cfg.IsAdmin(r.Context(), uid)
	return a.svc.Summary(r.Context(), uid, admin)
}

// userIDParam reads a users row id from the path: a positive integer.
func userIDParam(raw string) (int64, error) {
	id, err := strconv.ParseFloat(raw, 64)
	if err != nil || id <= 0 || id != float64(int64(id)) {
		return 0, apperr.New(http.StatusBadRequest, "Invalid user id", "INVALID_USER_ID")
	}
	return int64(id), nil
}

func (a *API) publicBaseURL(r *http.Request) string {
	if a.cfg.PublicURL != "" {
		return strings.TrimRight(a.cfg.PublicURL, "/")
	}
	proto := strings.TrimSpace(r.Header.Get("X-Forwarded-Proto"))
	if proto == "" {
		proto = "http"
		if r.TLS != nil {
			proto = "https"
		}
	}
	return proto + "://" + r.Host
}

// handle signs the caller in, reads the JSON body and writes the result or
// the error the way the Node routes did.
func (a *API) handle(status int, fn func(*http.Request, int64, map[string]any) (any, error)) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sess := sessionx.FromContext(r.Context())
		var uid int64
		if sess != nil {
			uid, _ = sess.Int64("userId")
		}
		if uid <= 0 {
			httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
			return
		}
		body := map[string]any{}
		if r.Body != nil {
			raw, _ := io.ReadAll(io.LimitReader(r.Body, 1<<20))
			_ = json.Unmarshal(raw, &body)
		}
		out, err := fn(r, uid, body)
		if err != nil {
			if e, ok := apperr.As(err); ok && e.Status < 500 {
				payload := jsonobj.New("error", e.Message)
				if e.Code != "" {
					payload.Set("code", e.Code)
				}
				httpx.WriteJSON(w, e.Status, payload)
				return
			}
			if a.cfg.Log != nil {
				a.cfg.Log.Error("delegation request failed", "path", r.URL.Path, "err", err)
			}
			httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
			return
		}
		httpx.WriteJSON(w, status, out)
	})
}
