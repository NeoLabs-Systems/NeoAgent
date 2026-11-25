// Package triggers serves the routes a phone calls to feed task triggers
// (/api/triggers): the geofences it should watch, a fence it entered or left,
// and a notification it received (which is also kept in notification_history).
// The tasks that react to them live in package tasks.
package triggers

import (
	"context"
	"database/sql"
	"errors"
	"log/slog"
	"math"
	"net/http"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/reqx"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
)

// GeofenceTask is an enabled geofence task: each task watches one place.
type GeofenceTask struct {
	ID int64
	// TriggerConfig is the task's stored trigger_config text.
	TriggerConfig string
}

// Tasks is what the routes need from the task system.
type Tasks interface {
	// GeofenceTasks lists the user's enabled geofence_event tasks on every agent.
	GeofenceTasks(ctx context.Context, userID int64) ([]GeofenceTask, error)
	// PublishEvent hands an event to the tasks waiting for it. The routes
	// publish "geofence" (userId, fenceId, transition, latitude, longitude,
	// occurredAt) and "android_notification" (userId, appPackage, title, body,
	// actionTaken, receivedAt).
	PublishEvent(name string, event map[string]any)
}

// Config wires the routes.
type Config struct {
	DB    *dbx.DB
	Tasks Tasks
	Log   *slog.Logger
	// UserID returns the signed-in account of a request. Nil reads "userId"
	// from the session.
	UserID func(*http.Request) (int64, bool)
}

// API serves /api/triggers.
type API struct {
	db     *dbx.DB
	tasks  Tasks
	log    *slog.Logger
	userID func(*http.Request) (int64, bool)
}

// New builds the API.
func New(cfg Config) *API {
	userID := cfg.UserID
	if userID == nil {
		userID = reqx.UserID
	}
	return &API{db: cfg.DB, tasks: cfg.Tasks, log: cfg.Log, userID: userID}
}

// Routes registers the routes on mux.
func (a *API) Routes(mux *http.ServeMux) {
	guard := func(h http.HandlerFunc) http.Handler { return reqx.Guard(a.userID, h) }
	mux.Handle("GET /api/triggers/geofences", guard(a.geofences))
	mux.Handle("POST /api/triggers/geofence", guard(a.geofence))
	mux.Handle("POST /api/triggers/notification", guard(a.notification))
}

func (a *API) geofences(w http.ResponseWriter, r *http.Request) {
	userID, _ := a.userID(r)
	tasks, err := a.tasks.GeofenceTasks(r.Context(), userID)
	if err != nil {
		a.log.Error("listing geofences failed", "error", err)
		reqx.Fail(w, http.StatusInternalServerError, err)
		return
	}
	fences := []any{}
	for _, task := range tasks {
		config := jsv.ParseObject(task.TriggerConfig)
		fence := jsv.NewObject().Set("id", float64(task.ID))
		for _, m := range [][2]string{{"label", "label"}, {"latitude", "latitude"}, {"longitude", "longitude"}, {"radius_meters", "radiusMeters"}} {
			if v, ok := config.Get(m[1]); ok {
				fence.Set(m[0], v)
			}
		}
		fences = append(fences, fence)
	}
	httpx.WriteJSON(w, http.StatusOK, jsv.NewObject().Set("geofences", fences))
}

// numberOrNil is `Number(v) || null`.
func numberOrNil(v any) any {
	if n := jsv.Number(v); n != 0 && !math.IsNaN(n) && !math.IsInf(n, 0) {
		return n
	}
	return nil
}

func (a *API) geofence(w http.ResponseWriter, r *http.Request) {
	userID, _ := a.userID(r)
	body, err := reqx.ReadBody(r)
	if err != nil {
		reqx.RefuseBody(w, err)
		return
	}
	obj := body.Object()
	fenceID := math.NaN()
	if obj != nil && obj.Has("fence_id") {
		fenceID = jsv.Number(obj.Val("fence_id"))
	}
	transition := "enter"
	if obj.Val("transition") == "exit" {
		transition = "exit"
	}
	if !jsv.IsInteger(fenceID) || fenceID <= 0 {
		httpx.Error(w, http.StatusBadRequest, "fence_id is required")
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]bool{"success": true})
	a.tasks.PublishEvent("geofence", map[string]any{
		"userId": userID, "fenceId": int64(fenceID), "transition": transition,
		"latitude": numberOrNil(obj.Val("latitude")), "longitude": numberOrNil(obj.Val("longitude")),
		"occurredAt": jsv.ISO(time.Now()),
	})
}

// errNoBody is the TypeError Node raised destructuring a request without a body.
const errNoBody = "Cannot destructure property 'app_package' of 'req.body' as it is undefined."

// orDefault is `value || fallback`.
func orDefault(v any, fallback string) any {
	if jsv.Truthy(v) {
		return v
	}
	return fallback
}

// bindable converts a value for a SQL parameter the way better-sqlite3 did:
// text and numbers bind, anything else (booleans, objects) is refused.
func bindable(v any) (any, bool) {
	switch v := v.(type) {
	case string:
		return v, true
	case float64:
		// better-sqlite3 binds every number as a double, so 7 is stored as "7.0".
		return v, true
	}
	return nil, false
}

func (a *API) notification(w http.ResponseWriter, r *http.Request) {
	userID, _ := a.userID(r)
	body, err := reqx.ReadBody(r)
	if err != nil {
		reqx.RefuseBody(w, err)
		return
	}
	obj := body.Object()
	if body.Value == nil {
		httpx.Error(w, http.StatusInternalServerError, errNoBody)
		return
	}
	notification := jsv.NewObject().
		Set("appPackage", orDefault(obj.Val("app_package"), "unknown")).
		Set("title", orDefault(obj.Val("title"), "")).
		Set("body", orDefault(obj.Val("body"), "")).
		Set("actionTaken", orDefault(obj.Val("action_taken"), "none"))
	status, message := a.store(r.Context(), userID, notification)
	if status != http.StatusOK {
		httpx.Error(w, status, message)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, jsv.NewObject().Set("success", true).Set("message", "Notification trigger processed and stored"))
	event := map[string]any{"userId": userID, "receivedAt": jsv.ISO(time.Now())}
	for _, k := range notification.Keys() {
		event[k] = notification.Val(k)
	}
	a.tasks.PublishEvent("android_notification", event)
}

// store keeps the notification and says how the route should answer: 200, 401
// when the account is gone, 500 when it could not be stored.
func (a *API) store(ctx context.Context, userID int64, n *jsv.Object) (int, string) {
	var id int64
	err := a.db.W.QueryRowContext(ctx, `SELECT id FROM users WHERE id = ?`, userID).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return http.StatusUnauthorized, "Unauthorized"
	}
	const failure = "Failed to process notification trigger"
	if err != nil {
		a.log.Error("notification trigger failed", "error", err)
		return http.StatusInternalServerError, failure
	}
	args := []any{userID}
	for _, k := range []string{"appPackage", "title", "body", "actionTaken"} {
		v, ok := bindable(n.Val(k))
		if !ok {
			return http.StatusInternalServerError, failure
		}
		args = append(args, v)
	}
	if _, err := a.db.W.ExecContext(ctx, `
      INSERT INTO notification_history (user_id, app_package, title, body, action_taken)
      VALUES (?, ?, ?, ?, ?)
    `, args...); err != nil {
		a.log.Error("notification trigger failed", "error", err)
		return http.StatusInternalServerError, failure
	}
	return http.StatusOK, ""
}
