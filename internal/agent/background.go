package agent

import (
	"context"
	"database/sql"
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
)

// A live owner chat run that told the user it is working on something keeps
// running in the background. The chat is free again: the next message starts a
// new foreground run that sees the background work and can check on, instruct
// or cancel it. A live voice call hands work off and keeps talking, so its runs
// are background work from the start.

var ownerSurfaces = map[string]bool{"web": true, "messaging": true, "voice_live": true}

func backgroundEligible(triggerType, triggerSource, memoryAudience string) bool {
	return triggerType == "user" && ownerSurfaces[triggerSource] && memoryAudience != "shared"
}

func (e *Engine) moveToBackground(r *Run) bool {
	if !r.BackgroundEligible {
		return false
	}
	r.Delivery.Lock()
	final := r.Delivery.FinalDelivered
	r.Delivery.Unlock()
	r.mu.Lock()
	if r.background != "" || r.aborted || final {
		r.mu.Unlock()
		return false
	}
	r.background = isoNow()
	since := r.background
	onBackground := r.Options.OnBackground
	r.mu.Unlock()
	e.PersistMetadata(r.ID, map[string]any{"background": map[string]any{"since": since}})
	e.RecordEvent(r.UserID, r.ID, r.AgentID, runledger.EventRunState, map[string]any{"to_state": "background"})
	e.Emit(r.UserID, "run:background", map[string]any{"runId": r.ID, "conversationId": nullString(r.ConversationID)})
	if onBackground != nil {
		onBackground()
	}
	return true
}

// BackgroundRun describes a run still working in the background.
type BackgroundRun struct {
	RunID              string           `json:"run_id"`
	Request            string           `json:"request"`
	Channel            string           `json:"channel"`
	StartedAt          any              `json:"started_at"`
	Status             string           `json:"status"`
	LastUpdateToUserAt any              `json:"last_update_to_user_at"`
	RecentSteps        []map[string]any `json:"recent_steps"`
}

func (e *Engine) recentSteps(runID string) []map[string]any {
	rows, err := e.deps.DB.R.Query(`SELECT description, status, started_at, completed_at, error FROM agent_steps WHERE run_id = ? ORDER BY step_index DESC LIMIT 5`, runID)
	if err != nil {
		return []map[string]any{}
	}
	defer rows.Close()
	var out []map[string]any
	for rows.Next() {
		var desc, status, started, completed, errText sql.NullString
		if rows.Scan(&desc, &status, &started, &completed, &errText) != nil {
			continue
		}
		step := map[string]any{"step": nullString(desc.String), "status": status.String, "started_at": nullString(started.String)}
		if completed.String != "" {
			step["completed_at"] = completed.String
		}
		if errText.String != "" {
			step["error"] = ai.ClampRunContext(errText.String, 200)
		}
		out = append([]map[string]any{step}, out...)
	}
	if out == nil {
		out = []map[string]any{}
	}
	return out
}

func (e *Engine) describeRun(r *Run) BackgroundRun {
	status := "running"
	if r.Status() == "paused" {
		status = "paused"
	}
	r.Delivery.Lock()
	if r.Delivery.AwaitingReply != nil {
		status = "waiting_for_user"
	}
	r.Delivery.Unlock()
	channel := r.MessagingPlatform
	if channel == "" {
		channel = r.TriggerSource
	}
	return BackgroundRun{RunID: r.ID, Request: r.Request, Channel: channel, StartedAt: r.StartedAt.UTC().Format("2006-01-02T15:04:05.000Z"),
		Status: status, LastUpdateToUserAt: nullString(r.LastUserVisibleAt()), RecentSteps: e.recentSteps(r.ID)}
}

// ListBackgroundRuns lists an agent's background runs (and, for a live call,
// the foreground chat run too).
func (e *Engine) ListBackgroundRuns(userID int64, agentID, excludeRunID string, includeForeground bool) []BackgroundRun {
	out := []BackgroundRun{}
	for _, r := range e.activeRuns() {
		if r.ID == excludeRunID || !r.BackgroundEligible || r.Aborted() {
			continue
		}
		if !r.InBackground() && !includeForeground {
			continue
		}
		if r.UserID != userID || r.AgentID != agentID {
			continue
		}
		out = append(out, e.describeRun(r))
	}
	return out
}

func backgroundRunsNote(runs []BackgroundRun) string {
	if len(runs) == 0 {
		return ""
	}
	lines := []string{"[Background tasks]",
		"These tasks the user started earlier are still running in the background. Each reports its own progress and delivers its own result to the user."}
	for _, run := range runs {
		activity := ""
		if n := len(run.RecentSteps); n > 0 {
			latest := run.RecentSteps[n-1]
			activity = fmt.Sprintf(" Latest step (%s): %s.", latest["status"], ai.ClampRunContext(latest["step"], 160))
		}
		lines = append(lines, fmt.Sprintf("- run_id %s (%s, started %v, %s): %s%s", run.RunID, run.Channel, run.StartedAt, run.Status, ai.ClampRunContext(run.Request, 300), activity))
	}
	lines = append(lines,
		`Treat the user's new message as its own request unless it is about one of these tasks. When it is, use background_task: "status" for a fresh look, "instruct" to pass on a change or addition, "cancel" to stop it.`,
		"Do not redo a background task's work yourself, and never say one has finished before its result arrives.")
	return strings.Join(lines, "\n")
}

// ManageBackgroundRun is background_task: status, instruct or cancel one of
// the caller's background runs.
func (e *Engine) ManageBackgroundRun(callerRunID string, args map[string]any) map[string]any {
	caller, ok := e.RunInfo(callerRunID)
	if !ok || !caller.BackgroundEligible {
		return map[string]any{"error": "Background tasks can only be managed from the owner's own chat."}
	}
	runs := e.ListBackgroundRuns(caller.UserID, caller.AgentID, callerRunID, false)
	return e.ApplyBackgroundAction(caller.UserID, caller.AgentID, runs, map[string]any{"fromRunId": callerRunID}, args)
}

// ApplyBackgroundAction is status, instruct or cancel on one of the listed runs.
func (e *Engine) ApplyBackgroundAction(userID int64, agentID string, runs []BackgroundRun, origin map[string]any, args map[string]any) map[string]any {
	action := strings.TrimSpace(fmtAny(args["action"]))
	target := strings.TrimSpace(fmtAny(args["run_id"]))
	if action == "status" && target == "" {
		return map[string]any{"background_tasks": runs}
	}
	var found *BackgroundRun
	for i := range runs {
		if runs[i].RunID == target {
			found = &runs[i]
		}
	}
	if found == nil {
		return map[string]any{"error": fmt.Sprintf(`No background task with run_id "%s" is running.`, target), "background_tasks": runs}
	}
	switch action {
	case "status":
		return map[string]any{"background_task": found}
	case "instruct":
		instruction := strings.TrimSpace(fmtAny(args["instruction"]))
		if instruction == "" {
			return map[string]any{"error": "The instruct action needs an instruction."}
		}
		queued := e.EnqueueSystemSteering(target, strings.Join([]string{
			"The user sent a new instruction for this task from their ongoing conversation.",
			"Apply it from your next step on:",
			instruction,
		}, "\n"), "background_instruction")
		payload := map[string]any{"to_state": "instructed"}
		for k, v := range origin {
			payload[k] = v
		}
		e.RecordEvent(userID, target, agentID, runledger.EventRunState, payload)
		note := "The same instruction is already waiting for the task."
		if queued {
			note = "The task applies the instruction at its next step."
		}
		return map[string]any{"instructed": queued, "run_id": target, "note": note}
	case "cancel":
		return map[string]any{"cancelled": e.Abort(target, userID, "Cancelled by the user from their ongoing conversation."), "run_id": target}
	}
	return map[string]any{"error": "action must be status, instruct, or cancel."}
}

// announceBackgroundEnded tells the agent's foreground runs that background
// work ended, so they do not keep describing it as running.
func (e *Engine) announceBackgroundEnded(r *Run) {
	if !r.InBackground() {
		return
	}
	outcome := "ended without delivering a result"
	r.Delivery.Lock()
	final, finalContent := r.Delivery.FinalDelivered, r.Delivery.FinalContent
	r.Delivery.Unlock()
	if r.Aborted() {
		outcome = "was cancelled"
	} else if final {
		outcome = "finished and its result was delivered to the user"
	}
	result := ""
	if final {
		if finalContent == "" {
			finalContent = r.Delivery.LastSent()
		}
		result = ai.ClampRunContext(finalContent, 1500)
	}
	note := fmt.Sprintf("Background task %s (%s) %s.", r.ID, ai.ClampRunContext(r.Request, 200), outcome)
	if result != "" {
		note += "\nIts result:\n" + result
	}
	for _, other := range e.activeRuns() {
		if other.ID == r.ID || other.InBackground() || other.Aborted() || !other.BackgroundEligible || other.UserID != r.UserID || other.AgentID != r.AgentID {
			continue
		}
		e.EnqueueSystemSteering(other.ID, note, "background_task_ended")
	}
}

var _ = context.Background
