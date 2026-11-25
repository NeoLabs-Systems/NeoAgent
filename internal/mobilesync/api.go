package mobilesync

import (
	"context"
	"log/slog"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/reqx"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

// AgentResolver finds the agent a request is about: the agent named by
// candidate (an id or a slug) among the user's agents, or their default agent.
type AgentResolver interface {
	Resolve(ctx context.Context, userID int64, candidate string) (string, error)
}

// EventPublisher announces events to the task triggers. A phone's health sync
// is published as "health_sync" with the members userID (int64), records
// ([]HealthRecord) and syncedAt (an ISO time).
type EventPublisher interface {
	PublishEvent(name string, event map[string]any)
}

// Config wires the routes.
type Config struct {
	DB     *dbx.DB
	Box    *secretbox.Box
	Agents AgentResolver
	// Events receives the health_sync event; nil announces nothing.
	Events EventPublisher
	Log    *slog.Logger
	// UserID returns the signed-in account of a request. Nil reads "userId"
	// from the session.
	UserID func(*http.Request) (int64, bool)
}

// API serves /api/mobile/health and /api/mobile/device-sync.
type API struct {
	health *Health
	phone  *Phone
	agents AgentResolver
	events EventPublisher
	userID func(*http.Request) (int64, bool)
	log    *slog.Logger
}

// New builds the API.
func New(cfg Config) *API {
	userID := cfg.UserID
	if userID == nil {
		userID = reqx.UserID
	}
	return &API{
		health: &Health{DB: cfg.DB},
		phone:  &Phone{DB: cfg.DB, Box: cfg.Box},
		agents: cfg.Agents, events: cfg.Events, userID: userID, log: cfg.Log,
	}
}

// Health is the health store, for the agent's health tool.
func (a *API) Health() *Health { return a.health }

// Phone is the phone store, for the phone integration's tools.
func (a *API) Phone() *Phone { return a.phone }

// Routes registers the routes on mux.
func (a *API) Routes(mux *http.ServeMux) {
	guard := func(h http.HandlerFunc) http.Handler { return reqx.Guard(a.userID, h) }
	mux.Handle("GET /api/mobile/health/status", guard(a.healthStatus))
	mux.Handle("POST /api/mobile/health/sync", guard(a.healthSync))
	mux.Handle("POST /api/mobile/device-sync/register", guard(a.deviceRegister))
	mux.Handle("DELETE /api/mobile/device-sync/register", guard(a.deviceForget))
	mux.Handle("POST /api/mobile/device-sync/sync", guard(a.deviceSync))
}

func (a *API) healthStatus(w http.ResponseWriter, r *http.Request) {
	userID, _ := a.userID(r)
	status, err := a.health.Status(r.Context(), userID)
	if err != nil {
		a.log.Error("health status failed", "error", err)
		reqx.Fail(w, http.StatusInternalServerError, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, status)
}

var clientFault = regexp.MustCompile(`(?i)payload|Missing user`)

func (a *API) healthSync(w http.ResponseWriter, r *http.Request) {
	userID, _ := a.userID(r)
	body, err := reqx.ReadBody(r)
	if err != nil {
		reqx.RefuseBody(w, err)
		return
	}
	result, err := a.health.Ingest(r.Context(), userID, body.Value)
	if err != nil {
		status := http.StatusInternalServerError
		if clientFault.MatchString(err.Error()) {
			status = http.StatusBadRequest
		} else {
			a.log.Error("health sync failed", "error", err)
		}
		reqx.Fail(w, status, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, struct {
		Success bool `json:"success"`
		*SyncResult
	}{true, result})
	if a.events != nil {
		a.events.PublishEvent("health_sync", map[string]any{
			"userId": userID, "records": result.Records, "syncedAt": jsv.ISO(time.Now()),
		})
	}
}

// scoped reads the body and resolves the agent the request is about.
func (a *API) scoped(w http.ResponseWriter, r *http.Request) (userID int64, agentID string, body *jsv.Object, ok bool) {
	userID, _ = a.userID(r)
	parsed, err := reqx.ReadBody(r)
	if err != nil {
		reqx.RefuseBody(w, err)
		return 0, "", nil, false
	}
	body = parsed.ObjectOrEmpty()
	agentID, err = a.agents.Resolve(r.Context(), userID, reqx.AgentCandidate(r, body))
	if err != nil {
		a.fail(w, err)
		return 0, "", nil, false
	}
	return userID, agentID, body, true
}

func (a *API) fail(w http.ResponseWriter, err error) {
	a.log.Error("device sync failed", "error", err)
	httpx.Error(w, http.StatusInternalServerError, "Something went wrong. Please try again.")
}

func (a *API) deviceRegister(w http.ResponseWriter, r *http.Request) {
	userID, agentID, body, ok := a.scoped(w, r)
	if !ok {
		return
	}
	device := jsv.NewObject().Set("id", body.Val("deviceId")).Set("name", body.Val("deviceName")).Set("platform", body.Val("platform"))
	registration, err := a.phone.Register(r.Context(), userID, agentID, device, body.Val("kinds"))
	if err != nil {
		reqx.Fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, registration)
}

func (a *API) deviceForget(w http.ResponseWriter, r *http.Request) {
	userID, agentID, _, ok := a.scoped(w, r)
	if !ok {
		return
	}
	if err := a.phone.Forget(r.Context(), userID, agentID, strings.Join(r.URL.Query()["deviceId"], ",")); err != nil {
		reqx.Fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]bool{"connected": false})
}

func (a *API) deviceSync(w http.ResponseWriter, r *http.Request) {
	userID, agentID, body, ok := a.scoped(w, r)
	if !ok {
		return
	}
	state, err := a.phone.Sync(r.Context(), userID, agentID, body)
	if err != nil {
		reqx.Fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, state)
}
