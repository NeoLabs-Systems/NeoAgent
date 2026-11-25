// Package runledger is the durable record of agent runs: the run state machine
// with its leases, the append-only event ledger and the summaries computed from
// it, run checkpoints, and the outbox through which every message a run shows a
// user is committed exactly once.
package runledger

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"log/slog"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// Runtime states of a run. A run executes until the model answers, then
// delivers that answer. It can also wait for structured input, be paused, or end
// cancelled or failed.
const (
	StateAccepted   = "accepted"
	StateExecuting  = "executing"
	StateWaiting    = "waiting"
	StatePaused     = "paused"
	StateDelivering = "delivering"
	StateCompleted  = "completed"
	StateCancelled  = "cancelled"
	StateFailed     = "failed"
)

var productStatus = map[string]string{
	StateAccepted:   "running",
	StateExecuting:  "running",
	StateWaiting:    "running",
	StatePaused:     "paused",
	StateDelivering: "running",
	StateCompleted:  "completed",
	StateCancelled:  "stopped",
	StateFailed:     "failed",
}

var allowedTransitions = map[string][]string{
	StateAccepted:   {StateExecuting, StateCancelled, StateFailed},
	StateExecuting:  {StateWaiting, StatePaused, StateDelivering, StateCancelled, StateFailed},
	StateWaiting:    {StateExecuting, StatePaused, StateCancelled, StateFailed},
	StatePaused:     {StateExecuting, StateCancelled, StateFailed},
	StateDelivering: {StateCompleted, StateFailed},
}

// DefaultLease is how long a worker's claim on a run lasts without a heartbeat.
const DefaultLease = 60 * time.Second

// Ledger reads and writes the run tables.
type Ledger struct {
	DB  *dbx.DB
	Log *slog.Logger
	// Now is the clock; nil means time.Now.
	Now func() time.Time
}

func (l *Ledger) now() time.Time {
	if l.Now != nil {
		return l.Now()
	}
	return time.Now()
}

func (l *Ledger) log() *slog.Logger {
	if l.Log != nil {
		return l.Log
	}
	return slog.Default()
}

// ISO is a JavaScript Date.toISOString() rendering.
func ISO(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }

func parseISO(s string) (time.Time, bool) {
	if s == "" {
		return time.Time{}, false
	}
	for _, layout := range []string{"2006-01-02T15:04:05.000Z", time.RFC3339Nano, "2006-01-02 15:04:05"} {
		if t, err := time.Parse(layout, s); err == nil {
			return t, true
		}
	}
	return time.Time{}, false
}

// Run is one agent_runs row.
type Run struct {
	ID, Title, Status, RuntimeState string
	UserID                          int64
	AgentID                         string
	Version                         int64
	FinalDeliveryID                 string
	LeaseOwner, LeaseExpiresAt      string
	HeartbeatAt                     string
	Metadata                        map[string]any
	Error, FinalResponse, Model     string
	TotalTokens                     int64
	TriggerType, TriggerSource      string
	ConversationID, DeviceTarget    string
	CreatedAt, UpdatedAt            string
	CompletedAt                     string
}

// IsTerminal says whether a runtime state ends a run.
func IsTerminal(state string) bool {
	return state == StateCompleted || state == StateCancelled || state == StateFailed
}

// Terminal says whether the run has ended.
func (r *Run) Terminal() bool { return r != nil && IsTerminal(r.RuntimeState) }

// ParseObject decodes a JSON object column; anything else is an empty object.
func ParseObject(raw string) map[string]any {
	out := map[string]any{}
	if raw == "" {
		return out
	}
	var v any
	if json.Unmarshal([]byte(raw), &v) == nil {
		if m, ok := v.(map[string]any); ok {
			return m
		}
	}
	return out
}

type queryer interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

const runColumns = `id, user_id, agent_id, title, status, runtime_state, version,
	final_delivery_id, lease_owner, lease_expires_at, heartbeat_at,
	metadata_json, error, final_response, total_tokens, model,
	trigger_type, trigger_source, conversation_id, device_target, created_at, updated_at, completed_at`

func loadRun(ctx context.Context, q queryer, runID string) (*Run, error) {
	if runID == "" {
		return nil, nil
	}
	var r Run
	var agent, title, status, state, final, leaseOwner, leaseExp, heartbeat, meta, errText, finalResp, model,
		trigType, trigSource, conv, device, created, updated, completed sql.NullString
	var version, tokens sql.NullInt64
	err := q.QueryRowContext(ctx, `SELECT `+runColumns+` FROM agent_runs WHERE id = ?`, runID).Scan(
		&r.ID, &r.UserID, &agent, &title, &status, &state, &version, &final, &leaseOwner, &leaseExp, &heartbeat,
		&meta, &errText, &finalResp, &tokens, &model, &trigType, &trigSource, &conv, &device, &created, &updated, &completed)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	r.AgentID, r.Title, r.Status = agent.String, title.String, status.String
	r.RuntimeState = state.String
	if r.RuntimeState == "" {
		r.RuntimeState = StateAccepted
	}
	r.Version, r.FinalDeliveryID = version.Int64, final.String
	r.LeaseOwner, r.LeaseExpiresAt, r.HeartbeatAt = leaseOwner.String, leaseExp.String, heartbeat.String
	r.Metadata = ParseObject(meta.String)
	r.Error, r.FinalResponse, r.TotalTokens, r.Model = errText.String, finalResp.String, tokens.Int64, model.String
	r.TriggerType, r.TriggerSource = trigType.String, trigSource.String
	if r.TriggerType == "" {
		r.TriggerType = "user"
	}
	if r.TriggerSource == "" {
		r.TriggerSource = "web"
	}
	r.ConversationID, r.DeviceTarget = conv.String, device.String
	r.CreatedAt, r.UpdatedAt, r.CompletedAt = created.String, updated.String, completed.String
	return &r, nil
}

// LoadRun reads a run; nil when there is none.
func (l *Ledger) LoadRun(ctx context.Context, runID string) (*Run, error) {
	return loadRun(ctx, l.DB.R, runID)
}

// Patch are the columns a transition may also set; nil fields stay unchanged.
type Patch struct {
	Error         *string
	FinalResponse *string
	TotalTokens   *int
	Model         *string
	Metadata      map[string]any
}

// Str is a convenience for Patch fields.
func Str(s string) *string { return &s }

// Int is a convenience for Patch fields.
func Int(n int) *int { return &n }

// TransitionRequest asks for a state change.
type TransitionRequest struct {
	RunID, ToState, Reason string
	// ExpectedVersion, when set, makes the change conditional on the version.
	ExpectedVersion *int64
	WorkerID        string
	Patch           Patch
	// Publish records the change in the event ledger.
	Publish bool
}

// TransitionResult is how a transition went; Reason names a refusal.
type TransitionResult struct {
	OK        bool
	Reason    string
	Run       *Run
	FromState string
	ToState   string
	EventID   string
}

func leaseHeldByOther(r *Run, workerID string, now time.Time) bool {
	if workerID == "" || r.LeaseOwner == "" || r.LeaseOwner == workerID {
		return false
	}
	expires, ok := parseISO(r.LeaseExpiresAt)
	return ok && expires.After(now)
}

func nullable(s *string) any {
	if s == nil || *s == "" {
		return nil
	}
	return *s
}

// Transition changes a run's state under optimistic concurrency.
func (l *Ledger) Transition(ctx context.Context, req TransitionRequest) (TransitionResult, error) {
	if req.RunID == "" || req.ToState == "" {
		return TransitionResult{Reason: "invalid_args"}, nil
	}
	tx, err := l.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return TransitionResult{}, err
	}
	defer tx.Rollback()
	current, err := loadRun(ctx, tx, req.RunID)
	if err != nil {
		return TransitionResult{}, err
	}
	if current == nil {
		return TransitionResult{Reason: "not_found"}, nil
	}
	if current.Terminal() {
		return TransitionResult{Reason: "terminal", Run: current}, nil
	}
	if req.ExpectedVersion != nil && *req.ExpectedVersion != current.Version {
		return TransitionResult{Reason: "version_conflict", Run: current}, nil
	}
	allowed := false
	for _, s := range allowedTransitions[current.RuntimeState] {
		allowed = allowed || s == req.ToState
	}
	if !allowed {
		return TransitionResult{Reason: "illegal_transition", Run: current, FromState: current.RuntimeState, ToState: req.ToState}, nil
	}
	now := l.now()
	if leaseHeldByOther(current, req.WorkerID, now) {
		return TransitionResult{Reason: "lease_held", Run: current}, nil
	}
	metadata := current.Metadata
	for k, v := range req.Patch.Metadata {
		metadata[k] = v
	}
	if req.Reason != "" {
		metadata["lastTransitionReason"] = req.Reason
	} else {
		metadata["lastTransitionReason"] = nil
	}
	metadata["lastTransitionAt"] = ISO(now)
	metaJSON, _ := json.Marshal(metadata)
	status := productStatus[req.ToState]
	if status == "" {
		status = "running"
	}
	sets := []string{"runtime_state = ?", "status = ?", "version = ?", "updated_at = datetime('now')", "metadata_json = ?"}
	values := []any{req.ToState, status, current.Version + 1, string(metaJSON)}
	if req.Patch.Error != nil {
		sets, values = append(sets, "error = ?"), append(values, nullable(req.Patch.Error))
	}
	if req.Patch.FinalResponse != nil {
		sets, values = append(sets, "final_response = ?"), append(values, nullable(req.Patch.FinalResponse))
	}
	if req.Patch.TotalTokens != nil {
		sets, values = append(sets, "total_tokens = ?"), append(values, *req.Patch.TotalTokens)
	}
	if req.Patch.Model != nil {
		sets, values = append(sets, "model = ?"), append(values, nullable(req.Patch.Model))
	}
	if IsTerminal(req.ToState) {
		sets = append(sets, "completed_at = COALESCE(completed_at, datetime('now'))")
	}
	res, err := tx.ExecContext(ctx, `UPDATE agent_runs SET `+strings.Join(sets, ", ")+` WHERE id = ? AND COALESCE(version, 0) = ? AND runtime_state = ?`,
		append(values, req.RunID, current.Version, current.RuntimeState)...)
	if err != nil {
		return TransitionResult{}, err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		updated, _ := loadRun(ctx, tx, req.RunID)
		return TransitionResult{Reason: "cas_failed", Run: updated}, nil
	}
	updated, err := loadRun(ctx, tx, req.RunID)
	if err != nil {
		return TransitionResult{}, err
	}
	result := TransitionResult{OK: true, Run: updated, FromState: current.RuntimeState, ToState: req.ToState}
	if req.Publish {
		var reason any
		if req.Reason != "" {
			reason = req.Reason
		}
		event, err := appendEvent(ctx, tx, now, Event{
			RunID: req.RunID, UserID: updated.UserID, AgentID: updated.AgentID, Type: EventRunState, Actor: req.WorkerID,
			Payload: map[string]any{"from_state": current.RuntimeState, "to_state": req.ToState, "reason": reason, "version": updated.Version},
		})
		if err != nil {
			return TransitionResult{}, err
		}
		result.EventID = event.EventID
	}
	if err := tx.Commit(); err != nil {
		return TransitionResult{}, err
	}
	return result, nil
}

// ClaimFinalDelivery lets exactly one delivery become a run's final answer, by
// compare-and-swap on final_delivery_id.
func (l *Ledger) ClaimFinalDelivery(ctx context.Context, runID, deliveryID string, expectedVersion *int64, workerID string) (TransitionResult, error) {
	if runID == "" || deliveryID == "" {
		return TransitionResult{Reason: "invalid_args"}, nil
	}
	tx, err := l.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return TransitionResult{}, err
	}
	defer tx.Rollback()
	current, err := loadRun(ctx, tx, runID)
	if err != nil {
		return TransitionResult{}, err
	}
	switch {
	case current == nil:
		return TransitionResult{Reason: "not_found"}, nil
	case current.FinalDeliveryID != "":
		return TransitionResult{Reason: "already_committed", Run: current}, nil
	case current.Terminal() && current.RuntimeState != StateDelivering:
		return TransitionResult{Reason: "terminal", Run: current}, nil
	case expectedVersion != nil && *expectedVersion != current.Version:
		return TransitionResult{Reason: "version_conflict", Run: current}, nil
	case leaseHeldByOther(current, workerID, l.now()):
		return TransitionResult{Reason: "lease_held", Run: current}, nil
	}
	res, err := tx.ExecContext(ctx, `UPDATE agent_runs
		SET final_delivery_id = ?, runtime_state = ?, status = 'running', version = ?, updated_at = datetime('now')
		WHERE id = ? AND final_delivery_id IS NULL AND COALESCE(version, 0) = ?
		  AND runtime_state NOT IN ('completed', 'cancelled', 'failed')`,
		deliveryID, StateDelivering, current.Version+1, runID, current.Version)
	if err != nil {
		return TransitionResult{}, err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		updated, _ := loadRun(ctx, tx, runID)
		return TransitionResult{Reason: "cas_failed", Run: updated}, nil
	}
	updated, err := loadRun(ctx, tx, runID)
	if err != nil {
		return TransitionResult{}, err
	}
	if err := tx.Commit(); err != nil {
		return TransitionResult{}, err
	}
	return TransitionResult{OK: true, Run: updated}, nil
}

// SetMetadata merges keys into a run's metadata_json (a nil value removes the
// key, as JSON.stringify drops undefined).
func (l *Ledger) SetMetadata(ctx context.Context, runID string, patch map[string]any) error {
	tx, err := l.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var raw sql.NullString
	if err := tx.QueryRowContext(ctx, `SELECT metadata_json FROM agent_runs WHERE id = ?`, runID).Scan(&raw); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil
		}
		return err
	}
	meta := ParseObject(raw.String)
	for k, v := range patch {
		meta[k] = v
	}
	encoded, _ := json.Marshal(meta)
	if _, err := tx.ExecContext(ctx, `UPDATE agent_runs SET metadata_json = ?, updated_at = datetime('now') WHERE id = ?`, string(encoded), runID); err != nil {
		return err
	}
	return tx.Commit()
}
