package agent

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
)

// A run cut off by a restart is picked up again only if it was alive this
// recently, by its last heartbeat.
const resumeWindow = "-60 minutes"

// StaleRunError is what a run the restart cut off records.
const StaleRunError = "Server restarted while run was in progress."

// Surfaces whose person or chat is still there after a restart.
var resumableSources = map[string]bool{"web": true, "messaging": true}

const resumableRunsWhere = `status = 'interrupted' AND final_delivery_id IS NULL
	AND json_extract(metadata_json, '$.resume') IS NOT NULL AND datetime(heartbeat_at) >= datetime('now', ?)`

// resumeRoute is the plain data a resumed run needs to work on the same surface
// and deliver to the same place.
type resumeRoute struct {
	Title              string       `json:"title,omitempty"`
	TriggerType        string       `json:"triggerType,omitempty"`
	TriggerSource      string       `json:"triggerSource,omitempty"`
	AgentID            string       `json:"agentId,omitempty"`
	ConversationID     string       `json:"conversationId,omitempty"`
	Source             string       `json:"source,omitempty"`
	ChatID             string       `json:"chatId,omitempty"`
	DeviceTarget       string       `json:"deviceTarget,omitempty"`
	WorkspaceRoot      string       `json:"workspaceRoot,omitempty"`
	Audience           string       `json:"audience,omitempty"`
	ApprovedSpeaker    bool         `json:"approvedSpeaker,omitempty"`
	MemoryAudience     string       `json:"memoryAudience,omitempty"`
	SkipGlobalRecall   bool         `json:"skipGlobalRecall,omitempty"`
	Context            *RunContext  `json:"context,omitempty"`
	MediaAttachments   []Attachment `json:"mediaAttachments,omitempty"`
	Model              string       `json:"model,omitempty"`
	LatencyProfile     string       `json:"latencyProfile,omitempty"`
	LatencyPriority    string       `json:"latencyPriority,omitempty"`
	ReasoningEffort    string       `json:"reasoningEffort,omitempty"`
	ModelCallTimeoutMs int64        `json:"modelCallTimeoutMs,omitempty"`
}

type resumeEnvelope struct {
	Message string         `json:"message,omitempty"`
	Options *resumeRoute   `json:"options,omitempty"`
	Task    *ResumableTask `json:"task,omitempty"`
}

func routeOf(o Options) *resumeRoute {
	route := &resumeRoute{Title: o.Title, TriggerType: o.TriggerType, TriggerSource: o.TriggerSource, AgentID: o.AgentID, ConversationID: o.ConversationID,
		Source: o.Source, ChatID: o.ChatID, DeviceTarget: o.DeviceTarget, WorkspaceRoot: o.WorkspaceRoot, Audience: o.Audience, ApprovedSpeaker: o.ApprovedSpeaker,
		MemoryAudience: o.MemoryAudience, SkipGlobalRecall: o.SkipGlobalRecall, MediaAttachments: o.MediaAttachments, Model: o.Model,
		LatencyProfile: o.LatencyProfile, LatencyPriority: o.LatencyPriority, ReasoningEffort: o.ReasoningEffort, ModelCallTimeoutMs: o.ModelCallTimeout.Milliseconds()}
	if o.Context != (RunContext{}) {
		c := o.Context
		c.Social = nil
		if o.Context.Social != nil {
			social := *o.Context.Social
			social.Behavior = nil
			c.Social = &social
		}
		route.Context = &c
	}
	return route
}

func (route *resumeRoute) options() Options {
	o := Options{Title: route.Title, TriggerType: route.TriggerType, TriggerSource: route.TriggerSource, AgentID: route.AgentID, ConversationID: route.ConversationID,
		Source: route.Source, ChatID: route.ChatID, DeviceTarget: route.DeviceTarget, WorkspaceRoot: route.WorkspaceRoot, Audience: route.Audience,
		ApprovedSpeaker: route.ApprovedSpeaker, MemoryAudience: route.MemoryAudience, SkipGlobalRecall: route.SkipGlobalRecall,
		MediaAttachments: route.MediaAttachments, Model: route.Model, LatencyProfile: route.LatencyProfile, LatencyPriority: route.LatencyPriority,
		ReasoningEffort: route.ReasoningEffort}
	if route.ModelCallTimeoutMs > 0 {
		o.ModelCallTimeout = msDuration(route.ModelCallTimeoutMs)
	}
	if route.Context != nil {
		o.Context = *route.Context
	}
	return o
}

// buildResumeEnvelope is what a run records so it can start again after a
// restart, or nil when it is not work a restart should pick back up. A resumed
// run records none: if it keeps bringing the server down, the next boot must
// not start it a third time.
func buildResumeEnvelope(message string, o Options) *resumeEnvelope {
	if o.ResumedFromRunID != "" {
		return nil
	}
	if o.TaskID != 0 {
		if o.ResumableTask != nil {
			task := *o.ResumableTask
			return &resumeEnvelope{Task: &task}
		}
		return nil
	}
	source := o.TriggerSource
	if source == "" {
		source = "web"
	}
	if !resumableSources[source] || o.SubagentDepth > 0 || o.TriggerType == "agent_delegation" || o.Audience == "public" || o.Public != nil {
		return nil
	}
	return &resumeEnvelope{Message: message, Options: routeOf(o)}
}

func (e *Engine) clearResumeEnvelope(runID string) {
	e.execDB(context.Background(), `UPDATE agent_runs SET metadata_json = json_remove(metadata_json, '$.resume') WHERE id = ? AND json_extract(metadata_json, '$.resume') IS NOT NULL`, runID)
}

func (e *Engine) hasResumeEnvelope(ctx context.Context, runID string) bool {
	var one int
	return e.deps.DB.W.QueryRowContext(ctx, `SELECT 1 FROM agent_runs WHERE id = ? AND json_extract(metadata_json, '$.resume') IS NOT NULL`, runID).Scan(&one) == nil
}

// routeOfRun is where a run still going answers its user, or nil.
func (e *Engine) routeOfRun(ctx context.Context, runID string) *resumeRoute {
	var raw sql.NullString
	if e.deps.DB.R.QueryRowContext(ctx, `SELECT json_extract(metadata_json, '$.resume.options') FROM agent_runs WHERE id = ?`, runID).Scan(&raw) != nil || raw.String == "" {
		return nil
	}
	var route resumeRoute
	if json.Unmarshal([]byte(raw.String), &route) != nil {
		return nil
	}
	return &route
}

// claimRun takes the envelope and names the successor in one write, so a run
// resumes at most once.
func (e *Engine) claimRun(ctx context.Context, runID, resumedAs string) *resumeEnvelope {
	tx, err := e.deps.DB.W.BeginTx(ctx, nil)
	if err != nil {
		return nil
	}
	defer tx.Rollback()
	var raw sql.NullString
	if tx.QueryRowContext(ctx, `SELECT json_extract(metadata_json, '$.resume') FROM agent_runs WHERE id = ?`, runID).Scan(&raw) != nil || raw.String == "" {
		return nil
	}
	if _, err := tx.ExecContext(ctx, `UPDATE agent_runs SET metadata_json = json_set(json_remove(metadata_json, '$.resume'), '$.resumedAs', ?), updated_at = datetime('now') WHERE id = ?`,
		resumedAs, runID); err != nil {
		return nil
	}
	if tx.Commit() != nil {
		return nil
	}
	var envelope resumeEnvelope
	if json.Unmarshal([]byte(raw.String), &envelope) != nil {
		return nil
	}
	return &envelope
}

func (e *Engine) interruptedRunNote(ctx context.Context, runID, situation, request string) string {
	var steps []string
	rows, err := e.deps.DB.R.QueryContext(ctx, `SELECT description, status FROM agent_steps WHERE run_id = ? AND status IN ('completed', 'interrupted') ORDER BY step_index DESC LIMIT 40`, runID)
	if err == nil {
		for rows.Next() {
			var desc, status sql.NullString
			if rows.Scan(&desc, &status) == nil {
				state := "cut off mid-call"
				if status.String == "completed" {
					state = "done"
				}
				steps = append([]string{"- " + state + ": " + desc.String}, steps...)
			}
		}
		rows.Close()
	}
	var sent []string
	rows, err = e.deps.DB.R.QueryContext(ctx, `SELECT payload_json FROM agent_outbox WHERE run_id = ? AND message_kind != 'final' AND status IN ('delivered', 'ambiguous') ORDER BY created_at DESC LIMIT 10`, runID)
	if err == nil {
		for rows.Next() {
			var payload sql.NullString
			if rows.Scan(&payload) == nil {
				content := fmtAny(runledger.ParseObject(payload.String)["content"])
				if r := []rune(content); len(r) > 400 {
					content = string(r[:400])
				}
				if content != "" {
					sent = append([]string{"- " + content}, sent...)
				}
			}
		}
		rows.Close()
	}
	log := "It had not finished any tool calls."
	if len(steps) > 0 {
		log = "Tool calls (oldest first):\n" + strings.Join(steps, "\n")
	}
	if len(sent) > 0 {
		log += "\n\nMessages it already sent to the user:\n" + strings.Join(sent, "\n")
	}
	return strings.Join(nonEmpty("[Resumed after a restart]", situation, request,
		"What the interrupted run already did:\n"+ai.FenceUntrusted("external_interrupted_run", log),
		"Pick up where it stopped. Do not repeat completed actions or resend messages already sent. A call that was cut off may or may not have taken effect, so check before redoing it. Then finish as you normally would."), "\n\n")
}

// StoreWebReply writes a web run's answer into the chat transcript, which the
// caller of a web run normally does.
type StoreWebReply func(userID int64, agentID, conversationID string, result Result)

// RunOnRoute starts a run on a recorded surface with no caller waiting.
func (e *Engine) RunOnRoute(ctx context.Context, userID int64, message string, o Options) (Result, error) {
	result, err := e.Run(ctx, userID, message, o)
	if err == nil && (o.TriggerSource == "" || o.TriggerSource == "web") && e.StoreWebReply != nil {
		e.StoreWebReply(userID, o.AgentID, o.ConversationID, result)
	}
	return result, err
}

// ResumeInterruptedRuns starts a new run for every recent run a restart cut
// off. Runs start concurrently; boot never waits on agent work.
func (e *Engine) ResumeInterruptedRuns(ctx context.Context) int {
	rows, err := e.deps.DB.R.QueryContext(ctx, `SELECT id, user_id, agent_id, json_extract(metadata_json, '$.resume.task') IS NOT NULL FROM agent_runs WHERE `+resumableRunsWhere+` ORDER BY heartbeat_at ASC`, resumeWindow)
	if err != nil {
		e.log.Warn("Listing resumable runs failed", "error", err)
		return 0
	}
	type candidate struct {
		id      string
		userID  int64
		agentID string
		isTask  bool
	}
	var candidates []candidate
	for rows.Next() {
		var c candidate
		var agent sql.NullString
		if rows.Scan(&c.id, &c.userID, &agent, &c.isTask) == nil {
			c.agentID = agent.String
			candidates = append(candidates, c)
		}
	}
	rows.Close()
	var resumed []string
	for _, c := range candidates {
		if c.isTask && e.deps.Tasks == nil {
			continue
		}
		runID := uuid.NewString()
		envelope := e.claimRun(ctx, c.id, runID)
		if envelope == nil {
			continue
		}
		e.RecordEvent(c.userID, c.id, c.agentID, runledger.EventRunState, map[string]any{"to_state": "resumed", "resumed_as": runID})
		if envelope.Task != nil {
			task := *envelope.Task
			note := e.interruptedRunNote(ctx, c.id, "NeoAgent restarted while this task was running, which ended that run early. This run continues the same occurrence of the task.", "")
			fromID := c.id
			go func(userID int64) {
				if err := e.deps.Tasks.ResumeInterruptedTask(e.lifecycle, task.TaskID, userID, task.ScheduledAt, task.TriggerSource, runID, fromID, note); err != nil {
					e.log.Error("Resumed task run failed", "run", shortID(runID), "from", shortID(fromID), "error", err)
				}
			}(c.userID)
		} else if envelope.Options != nil {
			o := envelope.Options.options()
			if o.AgentID == "" {
				o.AgentID = c.agentID
			}
			if o.Title == "" {
				o.Title = envelope.Message
			}
			if o.Context.RawUserMessage == "" {
				o.Context.RawUserMessage = envelope.Message
			}
			o.RunID, o.ResumedFromRunID = runID, c.id
			note := e.interruptedRunNote(ctx, c.id, "NeoAgent restarted while you were working on the request below, which ended that run early. This run continues the same task; nothing new has come from the user.",
				"Original request:\n"+envelope.Message)
			userID, fromID := c.userID, c.id
			go func() {
				if _, err := e.RunOnRoute(e.lifecycle, userID, note, o); err != nil {
					e.log.Error("Resumed run failed", "run", shortID(runID), "from", shortID(fromID), "error", err)
				}
			}()
		}
		resumed = append(resumed, shortID(c.id)+"->"+shortID(runID))
	}
	if len(resumed) > 0 {
		e.log.Info(fmt.Sprintf("Resuming %d run(s) a restart interrupted: %s", len(resumed), strings.Join(resumed, ", ")))
	}
	return len(resumed)
}

// CountResumableRuns is how many runs the next boot will resume.
func (e *Engine) CountResumableRuns(ctx context.Context) int {
	var n int
	_ = e.deps.DB.R.QueryRowContext(ctx, `SELECT COUNT(*) FROM agent_runs WHERE `+resumableRunsWhere, resumeWindow).Scan(&n)
	return n
}

// RecoverOrphanedRuns closes the runs a process that died left non-terminal. A
// run with a resume envelope is closed as interrupted and left for
// ResumeInterruptedRuns; any other is closed as failed. Paused runs keep their
// state.
func (e *Engine) RecoverOrphanedRuns(ctx context.Context) (int64, []string) {
	expired, _ := e.ledger.ExpireDeadLeases(ctx, 0)
	rows, err := e.deps.DB.R.QueryContext(ctx, `SELECT id, user_id, agent_id, runtime_state FROM agent_runs
		WHERE runtime_state NOT IN ('completed', 'cancelled', 'failed') AND (lease_owner IS NULL OR lease_expires_at IS NULL OR lease_expires_at < datetime('now'))
		ORDER BY updated_at ASC LIMIT 200`)
	if err != nil {
		return expired, nil
	}
	type orphan struct {
		id, agentID, state string
		userID             int64
	}
	var orphans []orphan
	for rows.Next() {
		var o orphan
		var agent, state sql.NullString
		if rows.Scan(&o.id, &o.userID, &agent, &state) == nil {
			o.agentID, o.state = agent.String, state.String
			orphans = append(orphans, o)
		}
	}
	rows.Close()
	var recovered []string
	for _, o := range orphans {
		if o.state == runledger.StatePaused {
			continue
		}
		resumable := e.hasResumeEnvelope(ctx, o.id)
		toState, status, errText := runledger.StateFailed, "failed", "Run was interrupted by a service restart and could not be resumed."
		if resumable {
			toState, status, errText = runledger.StateCancelled, "interrupted", StaleRunError
		}
		checkpoint, _ := e.ledger.LatestCheckpoint(ctx, o.id)
		res, err := e.deps.DB.W.ExecContext(ctx, `UPDATE agent_runs SET runtime_state = ?, status = ?, version = COALESCE(version, 0) + 1, error = COALESCE(error, ?),
			completed_at = COALESCE(completed_at, datetime('now')), updated_at = datetime('now') WHERE id = ? AND runtime_state NOT IN ('completed', 'cancelled', 'failed')`,
			toState, status, errText, o.id)
		if err != nil {
			continue
		}
		if n, _ := res.RowsAffected(); n == 0 {
			continue
		}
		stepStatus := "failed"
		if resumable {
			stepStatus = "interrupted"
		}
		e.execDB(ctx, `UPDATE agent_steps SET status = ?, completed_at = datetime('now') WHERE run_id = ? AND status = 'running'`, stepStatus, o.id)
		_ = e.ledger.SettleOrphanedReservations(ctx, o.id)
		var version any
		if checkpoint != nil {
			version = checkpoint.Version
		}
		eventType := runledger.EventRunFailed
		if resumable {
			eventType = runledger.EventRunCancelled
		}
		e.RecordEvent(o.userID, o.id, o.agentID, eventType, map[string]any{"reason": "process_restart", "interrupted_state": o.state, "checkpoint_version": version, "resumable": resumable})
		recovered = append(recovered, o.id)
	}
	if expired > 0 || len(recovered) > 0 {
		e.log.Warn(fmt.Sprintf("Recovered %d interrupted run(s), released %d stale lease(s)", len(recovered), expired))
	}
	return expired, recovered
}

// resumeReviewer keeps a resumed run from blindly doing again what its
// interrupted run may already have done.
type resumeReviewer struct {
	e           *Engine
	resumedFrom string
	loaded      bool
	completed   map[string]bool
	uncertain   map[string]any
}

func (e *Engine) resumeReviewer(r *Run) ai.ResumeReviewer {
	if r.Options.ResumedFromRunID == "" {
		return nil
	}
	return &resumeReviewer{e: e, resumedFrom: r.Options.ResumedFromRunID}
}

func operationKey(name string, args map[string]any) string {
	if args == nil {
		args = map[string]any{}
	}
	return ai.StableHash(map[string]any{"name": name, "args": args})
}

func (v *resumeReviewer) load() {
	v.loaded = true
	v.completed, v.uncertain = map[string]bool{}, map[string]any{}
	rows, err := v.e.deps.DB.R.Query(`SELECT tool_name, tool_input, result, status FROM agent_steps WHERE run_id = ? AND tool_name IS NOT NULL AND status IN ('completed', 'interrupted', 'running', 'failed')`, v.resumedFrom)
	if err != nil {
		return
	}
	defer rows.Close()
	registry := v.e.deps.Tools.Registry()
	for rows.Next() {
		var name string
		var input, result, status sql.NullString
		if rows.Scan(&name, &input, &result, &status) != nil {
			continue
		}
		if !input.Valid {
			v.uncertain[name] = map[string]any{"receipt": "expired"}
			continue
		}
		if runledger.ParseObject(result.String)["blocked"] == true {
			continue
		}
		var args map[string]any
		if json.Unmarshal([]byte(input.String), &args) != nil {
			args = map[string]any{}
		}
		if canRepeat(registry.Meta(name, nil), args) {
			continue
		}
		if status.String == "completed" {
			v.completed[operationKey(name, args)] = true
		} else {
			v.uncertain[name] = args
		}
	}
}

func (v *resumeReviewer) Review(s *ai.Session, call ai.Call, meta tools.Meta) *ai.ResumeReview {
	if !v.loaded {
		v.load()
	}
	if prior, ok := v.uncertain[call.Name]; ok {
		encoded, _ := json.Marshal(prior)
		text := string(encoded)
		if len(text) > 300 {
			text = text[:300]
		}
		return &ai.ResumeReview{Reason: "outcome_unknown", Message: fmt.Sprintf("A %s call was in flight when the previous run was interrupted, so it may already have taken effect: %s. This resumed run will not make more %s calls. Tell the owner what is uncertain so they can check it and ask again.",
			call.Name, text, call.Name)}
	}
	if canRepeat(meta, call.Arguments) {
		return nil
	}
	if v.completed[operationKey(call.Name, call.Arguments)] {
		return &ai.ResumeReview{Reason: "already_done", Completed: true, Message: fmt.Sprintf("This exact %s call already succeeded before the run was interrupted. It was not repeated.", call.Name)}
	}
	return nil
}
