package taskwebhooks

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// EventDispatcher delivers accepted webhook payloads to the task runtime.
type EventDispatcher interface {
	HandleEvent(source, name string, event map[string]any)
}

// Config configures the /api/task-webhooks routes.
type Config struct {
	DB         *dbx.DB
	Box        *secretbox.Box
	Dispatcher EventDispatcher
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

func randomHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func (a *API) seal(plain string) (string, error) {
	if a.cfg.Box == nil {
		return "", errors.New("encryption key is not configured")
	}
	return a.cfg.Box.Seal(plain)
}

func (a *API) open(sealed string) (string, error) {
	if a.cfg.Box == nil {
		return "", errors.New("encryption key is not configured")
	}
	return a.cfg.Box.Open(sealed)
}

func (a *API) ensureSecret(ctx context.Context, userID, taskID int64) (secret, fingerprint, rotatedAt string, err error) {
	var sealed string
	err = a.cfg.DB.R.QueryRowContext(ctx, `SELECT secret_encrypted, secret_fingerprint, rotated_at FROM task_webhook_secrets WHERE task_id = ? AND user_id = ?`, taskID, userID).
		Scan(&sealed, &fingerprint, &rotatedAt)
	if err == nil {
		plain, openErr := a.open(sealed)
		return plain, fingerprint, rotatedAt, openErr
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", "", "", err
	}
	return a.rotateSecret(ctx, userID, taskID)
}

func (a *API) rotateSecret(ctx context.Context, userID, taskID int64) (secret, fingerprint, rotatedAt string, err error) {
	var owner int64
	if err := a.cfg.DB.R.QueryRowContext(ctx, `SELECT user_id FROM scheduled_tasks WHERE id = ?`, taskID).Scan(&owner); err != nil || owner != userID {
		return "", "", "", errors.New("Task not found.")
	}
	secret = "whsec_" + randomHex(24)
	sum := sha256.Sum256([]byte(secret))
	fingerprint = hex.EncodeToString(sum[:8])
	sealed, err := a.seal(secret)
	if err != nil {
		return "", "", "", err
	}
	_, err = a.cfg.DB.W.ExecContext(ctx, `INSERT INTO task_webhook_secrets (task_id, user_id, secret_encrypted, secret_fingerprint, rotated_at, created_at)
		VALUES (?, ?, ?, ?, datetime('now'), datetime('now'))
		ON CONFLICT(task_id) DO UPDATE SET secret_encrypted = excluded.secret_encrypted, secret_fingerprint = excluded.secret_fingerprint, rotated_at = datetime('now')`,
		taskID, userID, sealed, fingerprint)
	if err != nil {
		return "", "", "", err
	}
	_ = a.cfg.DB.R.QueryRowContext(ctx, `SELECT rotated_at FROM task_webhook_secrets WHERE task_id = ?`, taskID).Scan(&rotatedAt)
	return secret, fingerprint, rotatedAt, nil
}

func (a *API) handleGetConfig(w http.ResponseWriter, r *http.Request, userID int64) {
	taskID, ok := parseTaskID(r.PathValue("taskId"))
	if !ok {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid task id."})
		return
	}
	secret, fp, rotatedAt, err := a.ensureSecret(r.Context(), userID, taskID)
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"taskId":      taskID,
		"secret":      secret,
		"fingerprint": fp,
		"rotatedAt":   rotatedAt,
		"endpoint":    "/api/task-webhooks/" + strconv.FormatInt(taskID, 10) + "/deliver",
	})
}

func (a *API) handleRotate(w http.ResponseWriter, r *http.Request, userID int64) {
	taskID, ok := parseTaskID(r.PathValue("taskId"))
	if !ok {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid task id."})
		return
	}
	secret, fp, rotatedAt, err := a.rotateSecret(r.Context(), userID, taskID)
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"taskId":      taskID,
		"secret":      secret,
		"fingerprint": fp,
		"rotatedAt":   rotatedAt,
	})
}

func (a *API) handleListDeliveries(w http.ResponseWriter, r *http.Request, userID int64) {
	taskID, ok := parseTaskID(r.PathValue("taskId"))
	if !ok {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid task id."})
		return
	}
	limit := 25
	if n, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && n > 0 {
		limit = min(n, 100)
	}
	rows, err := a.cfg.DB.R.QueryContext(r.Context(), `SELECT id, request_id, payload_hash, status, response_json, created_at, COALESCE(completed_at, '')
		FROM task_webhook_deliveries WHERE user_id = ? AND task_id = ? ORDER BY created_at DESC LIMIT ?`, userID, taskID, limit)
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": publicerr.Sanitize(err.Error(), "", "")})
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, reqID, hash, status, respJSON, createdAt, completedAt string
		if rows.Scan(&id, &reqID, &hash, &status, &respJSON, &createdAt, &completedAt) == nil {
			out = append(out, map[string]any{
				"id": id, "requestId": reqID, "payloadHash": hash,
				"status": status, "responseJson": respJSON,
				"createdAt": createdAt, "completedAt": completedAt,
			})
		}
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"deliveries": out})
}

func (a *API) handleDeliver(w http.ResponseWriter, r *http.Request) {
	taskID, ok := parseTaskID(r.PathValue("taskId"))
	if !ok {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid task id."})
		return
	}
	rawBody, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Invalid webhook body."})
		return
	}
	var userID int64
	var sealed string
	if err := a.cfg.DB.R.QueryRowContext(r.Context(), `SELECT user_id, secret_encrypted FROM task_webhook_secrets WHERE task_id = ?`, taskID).Scan(&userID, &sealed); err != nil {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "Webhook not configured."})
		return
	}
	secret, err := a.open(sealed)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": "Webhook verification unavailable."})
		return
	}

	sig := strings.TrimPrefix(strings.TrimSpace(r.Header.Get("X-NeoAgent-Signature")), "sha256=")
	if sig == "" {
		sig = strings.TrimPrefix(strings.TrimSpace(r.Header.Get("X-Webhook-Signature")), "sha256=")
	}
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(rawBody)
	expected := hex.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(strings.ToLower(sig)), []byte(expected)) {
		httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Invalid webhook signature."})
		return
	}

	reqID := strings.TrimSpace(r.Header.Get("X-Request-Id"))
	if reqID == "" {
		reqID = randomHex(12)
	}
	sum := sha256.Sum256(rawBody)
	payloadHash := hex.EncodeToString(sum[:])
	deliveryID := randomHex(16)
	if _, err := a.cfg.DB.W.ExecContext(r.Context(), `INSERT INTO task_webhook_deliveries (id, task_id, user_id, request_id, payload_hash, status)
		VALUES (?, ?, ?, ?, ?, 'accepted')`, deliveryID, taskID, userID, reqID, payloadHash); err != nil {
		httpx.WriteJSON(w, http.StatusAccepted, map[string]any{"accepted": true, "duplicate": true, "requestId": reqID})
		return
	}

	var payload any
	_ = json.Unmarshal(rawBody, &payload)
	if a.cfg.Dispatcher != nil {
		a.cfg.Dispatcher.HandleEvent("webhook", "task_webhook", map[string]any{
			"userId":    float64(userID),
			"taskId":    float64(taskID),
			"requestId": reqID,
			"payload":   payload,
		})
	}
	httpx.WriteJSON(w, http.StatusAccepted, map[string]any{"accepted": true, "deliveryId": deliveryID, "requestId": reqID})
}
