package wiring

import (
	"net/http"
	"os"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"

	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
	"github.com/NeoLabs-Systems/neoagent/internal/versioninfo"
)

type miscRoutes struct {
	rateLimits *aimodels.RateLimiter
}

func (m miscRoutes) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/version", m.handleVersion)
	mux.HandleFunc("GET /api/account/usage", m.handleAccountUsage)
}

func authUser(r *http.Request) (int64, bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}

func (m miscRoutes) handleVersion(w http.ResponseWriter, r *http.Request) {
	if uid, ok := authUser(r); !ok || uid <= 0 {
		httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, versioninfo.Info(os.Getenv))
}

func (m miscRoutes) handleAccountUsage(w http.ResponseWriter, r *http.Request) {
	uid, ok := authUser(r)
	if !ok || uid <= 0 {
		httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
		return
	}
	snap, err := m.rateLimits.Snapshot(r.Context(), uid, false)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "Internal server error"})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, usagePayload(snap))
}

// usagePayload is the account's rate-limit snapshot as the Node server sent it.
func usagePayload(s aimodels.RateLimitSnapshot) *jsonobj.Object {
	return jsonobj.New(
		"limits", jsonobj.New(
			"fourHour", s.Limits.FourHour,
			"weekly", s.Limits.Weekly,
			"fourHourIsCustom", s.Limits.FourHourIsCustom,
			"weeklyIsCustom", s.Limits.WeeklyIsCustom,
		),
		"usage", jsonobj.New("fourHour", s.Usage.FourHour, "weekly", s.Usage.Weekly),
		"remaining", jsonobj.New("fourHour", s.Remaining.FourHour, "weekly", s.Remaining.Weekly),
		"reached", jsonobj.New("fourHour", s.Reached.FourHour, "weekly", s.Reached.Weekly, "any", s.Reached.Any),
		"recoversAt", jsonobj.New("fourHour", s.RecoversAt.FourHour, "weekly", s.RecoversAt.Weekly),
		"fullResetAt", jsonobj.New("fourHour", s.FullResetAt.FourHour, "weekly", s.FullResetAt.Weekly),
	)
}
