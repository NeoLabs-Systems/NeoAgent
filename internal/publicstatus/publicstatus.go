package publicstatus

import (
	"context"
	"net/http"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
)

// Config reports which subsystems are live for /api/public/status.
type Config struct {
	DB             *dbx.DB
	RuntimeReady   func() bool
	HasAI          func() bool
	HasComputer    func() bool
	HasMessaging   func() bool
	HasIntegration func() bool
	HasMCP         func() bool
	HasTasks       func() bool
	HasVoice       func() bool
	HasMemory      func() bool
	Now            func() time.Time
}

// API serves /api/public/status.
type API struct {
	cfg Config
}

// New creates a publicstatus API.
func New(cfg Config) *API {
	if cfg.Now == nil {
		cfg.Now = time.Now
	}
	return &API{cfg: cfg}
}

// Routes registers /api/public/status on mux.
func (a *API) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/public/status", a.handleStatus)
}

type component struct {
	Group       string `json:"group"`
	Name        string `json:"name"`
	Status      string `json:"status"`
	Description string `json:"description"`
}

func checkFlag(fn func() bool) bool {
	return fn != nil && fn()
}

func (a *API) dbReachable(ctx context.Context) bool {
	if a.cfg.DB == nil {
		return false
	}
	var one int
	return a.cfg.DB.R.QueryRowContext(ctx, `SELECT 1`).Scan(&one) == nil && one == 1
}

func (a *API) handleStatus(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")

	runtimeReady := checkFlag(a.cfg.RuntimeReady)
	hasAI := checkFlag(a.cfg.HasAI)
	hasComputer := checkFlag(a.cfg.HasComputer)
	hasMessaging := checkFlag(a.cfg.HasMessaging)
	hasIntegrations := checkFlag(a.cfg.HasIntegration)
	hasMCP := checkFlag(a.cfg.HasMCP)
	hasTasks := checkFlag(a.cfg.HasTasks)
	hasVoice := checkFlag(a.cfg.HasVoice)
	hasMemory := checkFlag(a.cfg.HasMemory)
	storageReady := a.dbReachable(r.Context())

	statusOf := func(ok bool, up, down string) (string, string) {
		if ok {
			return "operational", up
		}
		return "degraded", down
	}

	rtStatus, rtDesc := statusOf(runtimeReady, "Runtime checks are passing.", "Runtime is reachable, but one or more host capabilities need attention.")
	aiStatus, aiDesc := statusOf(hasAI, "AI routing is ready. Provider connections are configured per deployment or user.", "The AI routing service is starting or unavailable.")
	compStatus, compDesc := statusOf(hasComputer, "The unified cloud computer provider is ready.", "The cloud computer provider is not initialized.")
	msgStatus, msgDesc := statusOf(hasMessaging, "Messaging bridge manager is online.", "Messaging bridge manager is not initialized.")
	intStatus, intDesc := statusOf(hasIntegrations && hasMCP, "Integration and MCP services are available.", "Some integration plumbing is not initialized.")
	taskStatus, taskDesc := statusOf(hasTasks, "Task scheduling service is initialized.", "Task scheduling service is not initialized.")
	voiceStatus, voiceDesc := statusOf(hasVoice, "Voice runtime is initialized.", "Voice runtime is not initialized.")
	memStatus, memDesc := "unavailable", "Storage or memory services are not responding."
	if storageReady && hasMemory {
		memStatus, memDesc = "operational", "Database and memory services are responding."
	}

	components := []component{
		{Group: "Core", Name: "Web App & API", Status: "operational", Description: "The web server is responding to requests."},
		{Group: "Core", Name: "Accounts & Sessions", Status: "operational", Description: "Account routes are available; individual sign-ins are not tested."},
		{Group: "Automation", Name: "Agent Runtime", Status: rtStatus, Description: rtDesc},
		{Group: "Automation", Name: "AI Gateway", Status: aiStatus, Description: aiDesc},
		{Group: "Devices", Name: "Browser & Desktop Control", Status: compStatus, Description: compDesc},
		{Group: "Communication", Name: "Messaging Bridges", Status: msgStatus, Description: msgDesc},
		{Group: "Communication", Name: "Integrations & OAuth", Status: intStatus, Description: intDesc},
		{Group: "Automation", Name: "Tasks & Scheduling", Status: taskStatus, Description: taskDesc},
		{Group: "Communication", Name: "Voice Runtime", Status: voiceStatus, Description: voiceDesc},
		{Group: "Data", Name: "Storage & Memory", Status: memStatus, Description: memDesc},
	}

	overall := "operational"
	for _, c := range components {
		if c.Status == "unavailable" {
			overall = "unavailable"
			break
		}
		if c.Status == "degraded" {
			overall = "degraded"
		}
	}
	note := "All monitored services are operational."
	if overall != "operational" {
		note = "One or more monitored services need attention."
	}

	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"product":             "NeoAgent",
		"status":              overall,
		"updatedAt":           a.cfg.Now().UTC().Format("2006-01-02T15:04:05.000Z"),
		"refreshAfterSeconds": 60,
		"note":                note,
		"components":          components,
		"history":             []any{},
	})
}
