package agent

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strings"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/prompts"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// What stops, pauses and resumes a run, from any surface.

var terminalStatuses = map[string]bool{"completed": true, "failed": true, "stopped": true, "interrupted": true}

var controlPriority = map[string]int{"pause": 1, "stop": 2, "interrupt": 3}

type runControl struct{ action, reason string }

func (e *Engine) pendingControl(ctx context.Context, runID string) *runControl {
	var action string
	var reason sql.NullString
	err := e.deps.DB.W.QueryRowContext(ctx, `SELECT action, reason FROM agent_run_controls WHERE run_id = ? AND consumed_at IS NULL`, runID).Scan(&action, &reason)
	if err != nil {
		return nil
	}
	return &runControl{action: action, reason: reason.String}
}

// requestControl records a control for a run unless a stronger one is pending.
func (e *Engine) requestControl(ctx context.Context, runID string, userID int64, action, reason string) bool {
	var status string
	if err := e.deps.DB.W.QueryRowContext(ctx, `SELECT status FROM agent_runs WHERE id = ? AND user_id = ?`, runID, userID).Scan(&status); err != nil {
		return false
	}
	if terminalStatuses[status] {
		return false
	}
	if existing := e.pendingControl(ctx, runID); existing != nil && controlPriority[existing.action] > controlPriority[action] {
		return false
	}
	if len(reason) > 1000 {
		reason = reason[:1000]
	}
	e.execDB(ctx, `INSERT INTO agent_run_controls (run_id, user_id, action, reason) VALUES (?, ?, ?, ?)
		ON CONFLICT(run_id) DO UPDATE SET action = excluded.action, reason = excluded.reason, requested_at = datetime('now'), consumed_at = NULL`,
		runID, userID, action, reason)
	return true
}

// transitionStatus moves the product status of a run among allowed ones.
func (e *Engine) transitionStatus(ctx context.Context, q interface {
	ExecContext(context.Context, string, ...any) (sql.Result, error)
}, runID, status string, errText *string, allowed ...string) bool {
	sets := "status = ?, updated_at = datetime('now')"
	args := []any{status}
	if errText != nil {
		sets += ", error = ?"
		if *errText == "" {
			args = append(args, nil)
		} else {
			args = append(args, *errText)
		}
	}
	if terminalStatuses[status] {
		sets += ", completed_at = COALESCE(completed_at, datetime('now'))"
	}
	placeholders := strings.TrimSuffix(strings.Repeat("?, ", len(allowed)), ", ")
	args = append(args, runID)
	for _, a := range allowed {
		args = append(args, a)
	}
	res, err := q.ExecContext(ctx, `UPDATE agent_runs SET `+sets+` WHERE id = ? AND status IN (`+placeholders+`)`, args...)
	if err != nil {
		e.log.Warn("Run status update failed", "run", runID, "error", err)
		return false
	}
	n, _ := res.RowsAffected()
	return n > 0
}

// closeRun ends a run's status, its running steps and its pending controls.
func (e *Engine) closeRun(runID, status, errText string, allowed ...string) bool {
	ctx := context.Background()
	tx, err := e.deps.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return false
	}
	defer tx.Rollback()
	if !e.transitionStatus(ctx, tx, runID, status, &errText, allowed...) {
		return false
	}
	var errValue any
	if errText != "" {
		errValue = errText
	}
	if _, err := tx.ExecContext(ctx, `UPDATE agent_steps SET status = ?, error = COALESCE(NULLIF(error, ''), ?), completed_at = COALESCE(completed_at, datetime('now'))
		WHERE run_id = ? AND status = 'running'`, status, errValue, runID); err != nil {
		return false
	}
	if _, err := tx.ExecContext(ctx, `UPDATE agent_run_controls SET consumed_at = datetime('now') WHERE run_id = ? AND consumed_at IS NULL`, runID); err != nil {
		return false
	}
	return tx.Commit() == nil
}

func (r *Run) abortWith(status, reason string) {
	r.mu.Lock()
	r.status = status
	r.aborted = true
	cancel, turnCancel, resume := r.runCancel, r.turnCancel, r.resume
	r.resume = nil
	r.mu.Unlock()
	cause := errors.New(reason)
	if turnCancel != nil {
		turnCancel(cause)
	}
	if cancel != nil {
		cancel(cause)
	}
	if resume != nil {
		close(resume)
	}
}

// InterruptRun ends a run cut off by its caller or a shutdown; a restart may
// pick it up again.
func (e *Engine) InterruptRun(runID, reason string) {
	if reason == "" {
		reason = "Server shutting down while run was in progress."
	}
	ctx := context.Background()
	r, active := e.RunInfo(runID)
	var userID int64
	if active {
		userID = r.UserID
	} else {
		_ = e.deps.DB.R.QueryRowContext(ctx, `SELECT user_id FROM agent_runs WHERE id = ?`, runID).Scan(&userID)
	}
	if userID != 0 {
		e.requestControl(ctx, runID, userID, "interrupt", reason)
	}
	if active {
		r.abortWith("interrupted", reason)
		e.Emit(r.UserID, "run:stopping", map[string]any{"runId": runID})
	}
	e.closeRun(runID, "interrupted", reason, "running", "pausing", "paused", "resuming")
}

// InterruptAll interrupts every active run.
func (e *Engine) InterruptAll(reason string) {
	for _, r := range e.activeRuns() {
		e.InterruptRun(r.ID, reason)
	}
}

// StopRun stops a run on request.
func (e *Engine) StopRun(runID, reason string) bool {
	if reason == "" {
		reason = "Stopped by request."
	}
	if len(reason) > 1000 {
		reason = reason[:1000]
	}
	ctx := context.Background()
	r, active := e.RunInfo(runID)
	var userID int64
	var status string
	if active {
		userID, status = r.UserID, r.Status()
	} else if err := e.deps.DB.R.QueryRowContext(ctx, `SELECT user_id, status FROM agent_runs WHERE id = ?`, runID).Scan(&userID, &status); err != nil {
		return false
	}
	if terminalStatuses[status] {
		return false
	}
	e.requestControl(ctx, runID, userID, "stop", reason)
	if active {
		r.abortWith("stopped", reason)
		e.Emit(r.UserID, "run:stopping", map[string]any{"runId": runID, "reason": reason})
	}
	e.closeRun(runID, "stopped", reason, "running", "pausing", "paused", "resuming")
	return true
}

// Abort stops a run its owner asks to stop.
func (e *Engine) Abort(runID string, userID int64, reason string) bool {
	if runID == "" {
		return false
	}
	if reason == "" {
		reason = "Stopped by request."
	}
	var owner int64
	var status string
	if r, ok := e.RunInfo(runID); ok {
		owner, status = r.UserID, r.Status()
	} else if err := e.deps.DB.R.QueryRow(`SELECT user_id, status FROM agent_runs WHERE id = ?`, runID).Scan(&owner, &status); err != nil {
		return false
	}
	if terminalStatuses[status] || (userID != 0 && owner != userID) {
		return false
	}
	return e.StopRun(runID, reason)
}

// AbortAll stops every active run of a user.
func (e *Engine) AbortAll(userID int64) {
	for _, r := range e.activeRuns() {
		if r.UserID == userID {
			e.StopRun(r.ID, "")
		}
	}
}

// PauseRun asks a running run to pause at its next boundary.
func (e *Engine) PauseRun(runID string, userID int64, reason string) bool {
	r, ok := e.RunInfo(runID)
	if !ok || r.UserID != userID {
		return false
	}
	r.mu.Lock()
	ready := r.status == "running" && r.pauseAvailable
	r.mu.Unlock()
	if !ready {
		return false
	}
	ctx := context.Background()
	if !e.requestControl(ctx, runID, userID, "pause", reason) {
		return false
	}
	e.transitionStatus(ctx, e.deps.DB.W, runID, "pausing", nil, "running")
	r.mu.Lock()
	r.status = "pausing"
	turnCancel := r.turnCancel
	r.mu.Unlock()
	if turnCancel != nil {
		turnCancel(errors.New("Run paused."))
	}
	var why any
	if reason != "" {
		why = reason
	}
	e.Emit(userID, "run:pausing", map[string]any{"runId": runID, "reason": why})
	return true
}

// ResumeRun continues a paused run.
func (e *Engine) ResumeRun(runID string, userID int64) bool {
	r, ok := e.RunInfo(runID)
	if !ok || r.UserID != userID || r.Status() != "paused" {
		return false
	}
	ctx := context.Background()
	if !e.transitionStatus(ctx, e.deps.DB.W, runID, "resuming", nil, "paused") {
		return false
	}
	e.execDB(ctx, `UPDATE agent_run_controls SET consumed_at = datetime('now') WHERE run_id = ? AND action = 'pause' AND consumed_at IS NULL`, runID)
	e.transitionStatus(ctx, e.deps.DB.W, runID, "running", nil, "resuming")
	e.Emit(userID, "run:resumed", map[string]any{"runId": runID})
	e.ledger.Record(runledger.Event{RunID: runID, UserID: userID, AgentID: r.AgentID, Type: runledger.EventRunState, Payload: map[string]any{"to_state": "running", "reason": "resumed"}})
	r.mu.Lock()
	resume := r.resume
	r.resume = nil
	r.mu.Unlock()
	if resume != nil {
		close(resume)
	}
	return true
}

// checkpoint is a lifecycle boundary: it returns "stop" or "interrupt" when the
// run must end there, and blocks while the run is paused.
func (e *Engine) checkpoint(ctx context.Context, r *Run, phase string, iteration, stepIndex int) string {
	if _, ok := e.RunInfo(r.ID); !ok {
		return "stop"
	}
	control := e.pendingControl(ctx, r.ID)
	if control == nil {
		return ""
	}
	if control.action != "pause" {
		return control.action
	}
	names := []string{}
	for _, t := range r.ActiveTools() {
		names = append(names, t.Name)
	}
	state, _ := json.Marshal(map[string]any{"iteration": iteration, "stepIndex": stepIndex, "currentPhase": phase, "activeTools": names})
	e.execDB(ctx, `INSERT INTO agent_run_checkpoints (run_id, version, phase, state_json) VALUES (?, 1, ?, ?)
		ON CONFLICT(run_id) DO UPDATE SET version = 1, phase = excluded.phase, state_json = excluded.state_json, updated_at = datetime('now')`,
		r.ID, phase, string(state))
	// The stored status and the in-memory one change under the run's lock, so a
	// resume never sees a paused row while the run is not yet waiting for it.
	resume := make(chan struct{})
	r.mu.Lock()
	e.transitionStatus(ctx, e.deps.DB.W, r.ID, "paused", nil, "running", "pausing")
	r.status = "paused"
	r.resume = resume
	if r.turnCancel != nil {
		r.turnCancel(errors.New("Run paused."))
	}
	runCtx := r.runCtx
	r.mu.Unlock()
	if tx, err := e.deps.DB.W.BeginTx(ctx, nil); err == nil {
		_, _ = tx.ExecContext(ctx, `UPDATE agent_steps SET status = 'paused', error = COALESCE(NULLIF(error, ''), 'Paused by request.'), completed_at = COALESCE(completed_at, datetime('now'))
			WHERE run_id = ? AND status = 'running'`, r.ID)
		_, _ = tx.ExecContext(ctx, `UPDATE pending_approvals SET status = 'expired', decided_at = COALESCE(decided_at, datetime('now')), updated_at = datetime('now')
			WHERE run_id = ? AND status = 'pending'`, r.ID)
		_ = tx.Commit()
	}
	var why any
	if control.reason != "" {
		why = control.reason
	}
	e.Emit(r.UserID, "run:paused", map[string]any{"runId": r.ID, "reason": why})
	e.ledger.Record(runledger.Event{RunID: r.ID, UserID: r.UserID, AgentID: r.AgentID, Type: runledger.EventRunState, Payload: map[string]any{"to_state": "paused", "phase": phase, "reason": why}})

	select {
	case <-resume:
	case <-runCtx.Done():
	}
	r.mu.Lock()
	status := r.status
	r.mu.Unlock()
	if status == "stopped" || status == "interrupted" {
		if status == "interrupted" {
			return "interrupt"
		}
		return "stop"
	}
	var persisted string
	_ = e.deps.DB.W.QueryRowContext(context.Background(), `SELECT status FROM agent_runs WHERE id = ?`, r.ID).Scan(&persisted)
	if persisted != "running" {
		r.mu.Lock()
		if persisted == "" {
			persisted = "stopped"
		}
		r.status = persisted
		r.mu.Unlock()
		if persisted == "interrupted" {
			return "interrupt"
		}
		return "stop"
	}
	r.mu.Lock()
	r.turnCtx, r.turnCancel = context.WithCancelCause(r.runCtx)
	r.status = "running"
	r.mu.Unlock()
	return ""
}

// FindSteerableRun is the user's newest foreground run on a surface that still
// takes follow-up messages.
func (e *Engine) FindSteerableRun(userID int64, triggerSource, conversationID string) *Run {
	var found *Run
	for _, r := range e.activeRuns() {
		r.mu.Lock()
		ok := r.UserID == userID && !r.aborted && r.TriggerSource == triggerSource && r.TriggerType == "user" &&
			r.background == "" && !r.steeringClosed && (conversationID == "" || r.ConversationID == conversationID)
		r.mu.Unlock()
		if ok && (found == nil || !r.StartedAt.Before(found.StartedAt)) {
			found = r
		}
	}
	return found
}

// EnqueueSteering adds a follow-up message for a run to read at its next turn;
// it returns the pending count, or 0 when the run no longer takes follow-ups.
func (e *Engine) EnqueueSteering(runID, content string, metadata map[string]any) int {
	r, ok := e.RunInfo(runID)
	text := strings.TrimSpace(content)
	if !ok || text == "" {
		return 0
	}
	r.mu.Lock()
	if r.aborted || r.steeringClosed {
		r.mu.Unlock()
		return 0
	}
	r.steering = append(r.steering, steeringItem{id: uuid.NewString(), content: text, metadata: metadata, createdAt: isoNow()})
	pending := len(r.steering)
	r.mu.Unlock()
	e.Emit(r.UserID, "run:steer_queued", map[string]any{"runId": runID, "conversationId": nullString(r.ConversationID), "content": text, "pendingCount": pending})
	return pending
}

// EnqueueSystemSteering adds a harness note a run reads at its next turn; the
// same note is queued once.
func (e *Engine) EnqueueSystemSteering(runID, content, reason string) bool {
	r, ok := e.RunInfo(runID)
	text := strings.TrimSpace(content)
	if !ok || text == "" {
		return false
	}
	signature, _ := json.Marshal(map[string]any{"content": text, "reason": reason})
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.aborted {
		return false
	}
	for _, item := range r.systemSteering {
		if item.signature == string(signature) {
			return false
		}
	}
	r.systemSteering = append(r.systemSteering, steeringItem{id: uuid.NewString(), content: text, reason: reason, signature: string(signature), createdAt: isoNow()})
	return true
}

func (e *Engine) applySteering(r *Run, s *ai.Session) {
	r.mu.Lock()
	system := r.systemSteering
	r.systemSteering = nil
	queued := r.steering
	r.steering = nil
	trust := r.trust
	r.mu.Unlock()
	if len(queued) > 0 {
		s.Messages = append(s.Messages, llm.Message{Role: "system", Content: prompts.Render("runtime/steering.md", nil)})
		for _, item := range queued {
			s.Messages = append(s.Messages, llm.Message{Role: "user", Content: item.content})
			trust.AddTrustedText(item.content)
			trust.AddOwnerStatement(item.content)
			if r.ConversationID != "" {
				e.execDB(context.Background(), `INSERT INTO conversation_messages (conversation_id, run_id, agent_id, role, content, metadata_json) VALUES (?, ?, ?, 'user', ?, ?)`,
					r.ConversationID, r.ID, nullString(r.AgentID), item.content, `{"steering":true}`)
			}
		}
		r.mu.Lock()
		pending := len(r.steering)
		r.mu.Unlock()
		e.Emit(r.UserID, "run:steer_applied", map[string]any{"runId": r.ID, "conversationId": nullString(r.ConversationID), "count": len(queued),
			"pendingCount": pending, "latestContent": queued[len(queued)-1].content})
	}
	for _, item := range system {
		s.Messages = append(s.Messages, llm.Message{Role: "system", Content: item.content})
	}
}

func nullString(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// runControls are the ai.Controls of one run.
type runControls struct {
	e *Engine
	r *Run
	s *ai.Session
}

func (c *runControls) Aborted() bool { return c.r.Aborted() }

func (c *runControls) Terminal() (bool, string) {
	run, err := c.e.ledger.LoadRun(context.Background(), c.r.ID)
	if err != nil {
		return false, ""
	}
	if run == nil {
		return true, ""
	}
	return run.Terminal(), run.Status
}

func (c *runControls) Heartbeat() {
	c.e.ledger.Heartbeat(context.Background(), c.r.ID, c.r.WorkerID)
	if b := c.e.broker(c.r); b != nil {
		b.noteActivity("loop_tick")
	}
}

func (c *runControls) PendingControl() (string, string) {
	if control := c.e.pendingControl(context.Background(), c.r.ID); control != nil {
		return control.action, control.reason
	}
	return "", ""
}

func (c *runControls) Checkpoint(ctx context.Context, phase string) string {
	iteration, step := 0, 0
	if c.s != nil {
		iteration, step = c.s.Iterations, c.s.StepIndex
	}
	return c.e.checkpoint(context.Background(), c.r, phase, iteration, step)
}

func (c *runControls) Interrupt(reason string) { c.e.InterruptRun(c.r.ID, reason) }

func (c *runControls) ApplySteering(s *ai.Session) { c.e.applySteering(c.r, s) }

func (c *runControls) OpenSteeringIntake(open bool) {
	c.r.mu.Lock()
	c.r.steeringClosed = !open
	c.r.mu.Unlock()
}

func (c *runControls) HasPendingSteering() bool {
	c.r.mu.Lock()
	defer c.r.mu.Unlock()
	return len(c.r.steering) > 0
}

// TurnContext is the context of the turn in flight: a pause ends it while the
// run lives on.
func (c *runControls) TurnContext(context.Context) context.Context { return c.r.Context() }

// StopUserRuns stops every active run of a user, restricted to one agent when
// agentID is set (/stop).
func (e *Engine) StopUserRuns(userID int64, agentID string) {
	for _, r := range e.activeRuns() {
		if r.UserID == userID && (agentID == "" || r.AgentID == agentID) {
			e.StopRun(r.ID, "")
		}
	}
}

// ActiveRunCount counts a user's active runs, restricted to one agent when
// agentID is set.
func (e *Engine) ActiveRunCount(userID int64, agentID string) int {
	n := 0
	for _, r := range e.activeRuns() {
		if r.UserID == userID && (agentID == "" || r.AgentID == agentID) {
			n++
		}
	}
	return n
}
