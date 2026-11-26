package taskwebhooks

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/reqx"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const (
	maxPayloadBytes = 256 << 10
	maxClockSkew    = 5 * time.Minute
)

// TaskRunner runs the task an authenticated delivery is for and returns the
// run's result once it has ended.
type TaskRunner interface {
	FireWebhookTask(taskID, userID int64, requestID string, at time.Time, payload any) (result any, failed bool)
}

// Config configures the /api/task-webhooks routes.
type Config struct {
	DB         *dbx.DB
	Box        *secretbox.Box
	Dispatcher TaskRunner
	UserID     func(*http.Request) (int64, bool)
}

// API serves /api/task-webhooks/*.
type API struct {
	cfg Config
}

// New creates a taskwebhooks API.
func New(cfg Config) *API { return &API{cfg: cfg} }

// Routes registers /api/task-webhooks endpoints on mux.
func (a *API) Routes(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/task-webhooks/{taskId}/deliver", a.handleDeliver)
	mux.HandleFunc("GET /api/task-webhooks/{taskId}", a.requireAuth(a.handleGetConfig))
	mux.HandleFunc("POST /api/task-webhooks/{taskId}/rotate", a.requireAuth(a.handleRotate))
	mux.HandleFunc("GET /api/task-webhooks/{taskId}/deliveries", a.requireAuth(a.handleListDeliveries))
}

func (a *API) requireAuth(next func(http.ResponseWriter, *http.Request, int64)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var uid int64
		var ok bool
		if a.cfg.UserID != nil {
			uid, ok = a.cfg.UserID(r)
		} else if sess := sessionx.FromContext(r.Context()); sess != nil {
			uid, ok = sess.Int64("userId")
		}
		if !ok || uid <= 0 {
			httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
			return
		}
		next(w, r, uid)
	}
}

func parseTaskID(raw string) (int64, bool) {
	id, err := strconv.ParseInt(raw, 10, 64)
	return id, err == nil && id > 0
}

func (a *API) ownedTrigger(ctx context.Context, userID, taskID int64) (string, error) {
	var trigger sql.NullString
	err := a.cfg.DB.R.QueryRowContext(ctx, `SELECT trigger_type FROM scheduled_tasks WHERE id = ? AND user_id = ?`, taskID, userID).Scan(&trigger)
	if errors.Is(err, sql.ErrNoRows) {
		return "", errors.New("Task not found.")
	}
	return trigger.String, err
}

// configuration describes a task's webhook. The secret is only ever returned
// by rotateSecret.
func (a *API) configuration(ctx context.Context, userID, taskID int64) (*jsonobj.Object, error) {
	if _, err := a.ownedTrigger(ctx, userID, taskID); err != nil {
		return nil, err
	}
	var fingerprint, rotatedAt, createdAt *string
	err := a.cfg.DB.R.QueryRowContext(ctx, `SELECT secret_fingerprint, rotated_at, created_at FROM task_webhook_secrets WHERE task_id = ? AND user_id = ?`, taskID, userID).
		Scan(&fingerprint, &rotatedAt, &createdAt)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return nil, err
	}
	return jsonobj.New("taskId", taskID, "configured", err == nil, "fingerprint", fingerprint, "rotatedAt", rotatedAt, "createdAt", createdAt), nil
}

func (a *API) rotateSecret(ctx context.Context, userID, taskID int64) (*jsonobj.Object, error) {
	trigger, err := a.ownedTrigger(ctx, userID, taskID)
	if err != nil {
		return nil, err
	}
	if trigger != "webhook" {
		return nil, errors.New("Task does not use the webhook trigger.")
	}
	if a.cfg.Box == nil {
		return nil, errors.New("encryption key is not configured")
	}
	random := make([]byte, 32)
	if _, err := rand.Read(random); err != nil {
		return nil, err
	}
	secret := base64.RawURLEncoding.EncodeToString(random)
	sum := sha256.Sum256([]byte(secret))
	fingerprint := hex.EncodeToString(sum[:8])
	sealed, err := a.cfg.Box.Seal(secret)
	if err != nil {
		return nil, err
	}
	if _, err := a.cfg.DB.W.ExecContext(ctx, `INSERT INTO task_webhook_secrets (task_id, user_id, secret_encrypted, secret_fingerprint)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(task_id) DO UPDATE SET secret_encrypted = excluded.secret_encrypted, secret_fingerprint = excluded.secret_fingerprint, rotated_at = datetime('now')`,
		taskID, userID, sealed, fingerprint); err != nil {
		return nil, err
	}
	return jsonobj.New("taskId", taskID, "secret", secret, "fingerprint", fingerprint), nil
}

func (a *API) handleGetConfig(w http.ResponseWriter, r *http.Request, userID int64) {
	a.answerTask(w, r, userID, a.configuration)
}

func (a *API) handleRotate(w http.ResponseWriter, r *http.Request, userID int64) {
	a.answerTask(w, r, userID, a.rotateSecret)
}

func (a *API) answerTask(w http.ResponseWriter, r *http.Request, userID int64, action func(context.Context, int64, int64) (*jsonobj.Object, error)) {
	taskID, ok := parseTaskID(r.PathValue("taskId"))
	if !ok {
		httpx.Error(w, http.StatusBadRequest, "Invalid task id.")
		return
	}
	out, err := action(r.Context(), userID, taskID)
	if err != nil {
		reqx.Fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, out)
}

func (a *API) handleListDeliveries(w http.ResponseWriter, r *http.Request, userID int64) {
	taskID, ok := parseTaskID(r.PathValue("taskId"))
	if !ok {
		httpx.Error(w, http.StatusBadRequest, "Invalid task id.")
		return
	}
	limit := 50
	if n, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && n != 0 {
		limit = min(max(n, 1), 200)
	}
	rows, err := a.cfg.DB.R.QueryContext(r.Context(), `SELECT id, request_id, payload_hash, status, response_json, created_at, completed_at
		FROM task_webhook_deliveries WHERE task_id = ? AND user_id = ? ORDER BY created_at DESC LIMIT ?`, taskID, userID, limit)
	if err != nil {
		reqx.Fail(w, http.StatusBadRequest, err)
		return
	}
	defer rows.Close()
	out := []*jsonobj.Object{}
	for rows.Next() {
		var id, requestID, hash, status string
		var response, createdAt, completedAt *string
		if err := rows.Scan(&id, &requestID, &hash, &status, &response, &createdAt, &completedAt); err != nil {
			reqx.Fail(w, http.StatusBadRequest, err)
			return
		}
		parsed := json.RawMessage("{}")
		if response != nil && json.Valid([]byte(*response)) {
			parsed = json.RawMessage(*response)
		}
		out = append(out, jsonobj.New("id", id, "requestId", requestID, "payloadHash", hash,
			"status", status, "response", parsed, "createdAt", createdAt, "completedAt", completedAt))
	}
	if err := rows.Err(); err != nil {
		reqx.Fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, out)
}

// handleDeliver accepts a delivery signed as
// HMAC-SHA256(secret, "<timestamp ms>.<raw body>"), runs the task and answers
// with the run's result.
func (a *API) handleDeliver(w http.ResponseWriter, r *http.Request) {
	taskID, ok := parseTaskID(r.PathValue("taskId"))
	if !ok {
		httpx.Error(w, http.StatusBadRequest, "Invalid task id.")
		return
	}
	body, err := reqx.ReadBody(r)
	if err != nil {
		reqx.RefuseBody(w, err)
		return
	}
	// Without a JSON body, what is signed and delivered is an empty object.
	raw, payload := body.Raw, body.Value
	if payload == nil {
		raw, payload = []byte("{}"), jsv.NewObject()
	}
	if len(raw) > maxPayloadBytes {
		httpx.Error(w, http.StatusRequestEntityTooLarge, "Webhook payload exceeds 256 KiB.")
		return
	}
	timestamp := math.NaN()
	if values := r.Header.Values("X-NeoAgent-Timestamp"); len(values) > 0 {
		timestamp = jsv.Number(values[0])
	}
	requestID := strings.TrimSpace(r.Header.Get("X-NeoAgent-Request-Id"))
	supplied := strings.TrimPrefix(r.Header.Get("X-NeoAgent-Signature"), "sha256=")
	if requestID == "" || math.IsNaN(timestamp) || math.IsInf(timestamp, 0) || supplied == "" {
		httpx.Error(w, http.StatusUnauthorized, "Missing webhook authentication headers.")
		return
	}
	if math.Abs(float64(time.Now().UnixMilli())-timestamp) > float64(maxClockSkew.Milliseconds()) {
		httpx.Error(w, http.StatusUnauthorized, "Webhook timestamp is outside the allowed window.")
		return
	}

	var userID int64
	var sealed string
	var enabled sql.NullBool
	var trigger sql.NullString
	err = a.cfg.DB.R.QueryRowContext(r.Context(), `SELECT secrets.user_id, secrets.secret_encrypted, tasks.enabled, tasks.trigger_type
		FROM task_webhook_secrets AS secrets JOIN scheduled_tasks AS tasks ON tasks.id = secrets.task_id
		WHERE secrets.task_id = ?`, taskID).Scan(&userID, &sealed, &enabled, &trigger)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		reqx.Fail(w, http.StatusBadRequest, err)
		return
	}
	if err != nil || !enabled.Bool || trigger.String != "webhook" || a.cfg.Dispatcher == nil {
		httpx.Error(w, http.StatusNotFound, "Webhook task is unavailable.")
		return
	}
	if a.cfg.Box == nil {
		httpx.Error(w, http.StatusBadRequest, "encryption key is not configured")
		return
	}
	secret, err := a.cfg.Box.Open(sealed)
	if err != nil {
		reqx.Fail(w, http.StatusBadRequest, err)
		return
	}
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(jsv.NumberString(timestamp) + "."))
	mac.Write(raw)
	if !hmac.Equal([]byte(supplied), []byte(hex.EncodeToString(mac.Sum(nil)))) {
		httpx.Error(w, http.StatusUnauthorized, "Invalid webhook signature.")
		return
	}

	deliveryID, err := reqx.NewUUID()
	if err != nil {
		reqx.Fail(w, http.StatusBadRequest, err)
		return
	}
	sum := sha256.Sum256(raw)
	// The unique (task_id, request_id) pair is the replay protection.
	if _, err := a.cfg.DB.W.ExecContext(r.Context(), `INSERT INTO task_webhook_deliveries (id, task_id, user_id, request_id, payload_hash, status)
		VALUES (?, ?, ?, ?, ?, 'accepted')`, deliveryID, taskID, userID, requestID, hex.EncodeToString(sum[:])); err != nil {
		if strings.Contains(err.Error(), "UNIQUE constraint failed") {
			httpx.Error(w, http.StatusConflict, "Webhook request ID was already used.")
			return
		}
		reqx.Fail(w, http.StatusBadRequest, err)
		return
	}

	result, failed := a.cfg.Dispatcher.FireWebhookTask(taskID, userID, requestID, time.UnixMilli(int64(timestamp)), payload)
	status := "completed"
	if failed {
		status = "failed"
	}
	response, err := json.Marshal(result)
	if err != nil || result == nil {
		response = []byte("{}")
	}
	// The run happened, so it is recorded even if the sender has hung up.
	if _, err := a.cfg.DB.W.ExecContext(context.WithoutCancel(r.Context()), `UPDATE task_webhook_deliveries
		SET status = ?, response_json = ?, completed_at = datetime('now') WHERE id = ?`, status, string(response), deliveryID); err != nil {
		reqx.Fail(w, http.StatusBadRequest, err)
		return
	}
	httpx.WriteJSON(w, http.StatusAccepted, jsonobj.New("deliveryId", deliveryID, "accepted", !failed, "result", json.RawMessage(response)))
}
