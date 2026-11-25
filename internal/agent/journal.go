package agent

import (
	"context"
	"encoding/json"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
)

type stepRecord struct {
	tool      string
	args      map[string]any
	started   time.Time
	callEvent string
}

// runJournal records what a run does: its steps, its ledger events and the
// realtime events its clients follow.
type runJournal struct {
	e *Engine
	r *Run

	mu    sync.Mutex
	steps map[string]*stepRecord
}

func newJournal(e *Engine, r *Run) *runJournal {
	return &runJournal{e: e, r: r, steps: map[string]*stepRecord{}}
}

func (j *runJournal) publish(eventType string, payload map[string]any, stepID, parent string) string {
	stored := j.e.ledger.Record(runledger.Event{RunID: j.r.ID, UserID: j.r.UserID, AgentID: j.r.AgentID, Type: eventType, Payload: payload, StepID: stepID, ParentEventID: parent})
	if stored == nil {
		return ""
	}
	return stored.EventID
}

func (j *runJournal) Phase(kind, message string) {
	j.e.Emit(j.r.UserID, "run:phase", map[string]any{"runId": j.r.ID, "conversationId": nullString(j.r.ConversationID), "phase": kind, "label": message})
	if kind == "thinking" {
		if b := j.e.broker(j.r); b != nil {
			b.noteActivity("model_started")
		}
	}
}

func (j *runJournal) Stream(content string, iteration int) {
	shown := ""
	if !ai.MayBeRawToolCall(content) {
		shown = ai.SanitizeModelOutput(content, ai.SanitizeOptions{Model: j.r.Model().Model})
	}
	j.e.Emit(j.r.UserID, "run:stream", map[string]any{"runId": j.r.ID, "content": shown, "iteration": iteration})
}

// Publish records a loop event ("tool_suppressed" is tool.suppressed).
func (j *runJournal) Publish(eventType string, payload map[string]any) {
	j.publish(strings.Replace(eventType, "_", ".", 1), payload, "", "")
}

func (j *runJournal) StepStart(s *ai.Session, step ai.StepStart) string {
	id := uuid.NewString()
	input, _ := json.Marshal(step.Input)
	if step.Input == nil {
		input = []byte("{}")
	}
	stepType := step.Type
	if stepType == "" {
		stepType = "tool"
	}
	j.e.execDB(context.Background(), `INSERT INTO agent_steps (id, run_id, step_index, type, description, status, tool_name, tool_input, started_at)
		VALUES (?, ?, ?, ?, ?, 'running', ?, ?, datetime('now'))`, id, j.r.ID, step.Index, stepType, step.Description, step.ToolName, string(input))
	j.mu.Lock()
	j.steps[id] = &stepRecord{tool: step.ToolName, args: step.Input, started: time.Now()}
	j.mu.Unlock()
	j.e.Emit(j.r.UserID, "run:tool_start", map[string]any{"runId": j.r.ID, "stepId": id, "stepIndex": step.Index, "toolName": step.ToolName, "toolArgs": step.Input, "type": stepType})
	return id
}

func (j *runJournal) toolIdentity(s *ai.Session, name string, args map[string]any, readOnly bool, fingerprint string) map[string]any {
	var family, group string
	if s != nil {
		var def *aiDefinition
		for i := range s.Catalog {
			if s.Catalog[i].Name == name {
				def = &s.Catalog[i]
				break
			}
		}
		meta := s.Shaper.Tools.Meta(name, def)
		group = meta.Group
		family = group
		if def != nil && def.Family != "" {
			family = def.Family
		}
	}
	return map[string]any{"name": name, "family": family, "group": group, "read_only": readOnly, "call_fingerprint": fingerprint, "args_digest": runledger.ArgsDigest(args)}
}

func (j *runJournal) ToolStart(s *ai.Session, stepID string, call ai.Call) {
	j.mu.Lock()
	rec := j.steps[stepID]
	j.mu.Unlock()
	if rec == nil {
		return
	}
	var selection any
	if c, ok := j.r.selectionFor(call.Name); ok {
		selection = map[string]any{"rank": c.Rank, "source": c.Source, "score": c.Score}
	}
	identity := j.toolIdentity(s, call.Name, call.Arguments, false, "")
	identity["args_redacted"] = runledger.RedactArgs(call.Arguments)
	iteration := 0
	if s != nil {
		iteration = s.Iterations
	}
	rec.callEvent = j.publish(runledger.EventToolCall, map[string]any{"tool": identity, "selection": selection, "step_index": stepIndexOf(s), "iteration": iteration}, stepID, j.r.lastModelEvent())
	if b := j.e.broker(j.r); b != nil {
		b.noteToolStarted()
	}
}

func stepIndexOf(s *ai.Session) int {
	if s == nil {
		return 0
	}
	return s.StepIndex
}

func (j *runJournal) StepEnd(s *ai.Session, stepID string, end ai.StepEnd) {
	j.mu.Lock()
	rec := j.steps[stepID]
	j.mu.Unlock()
	if rec == nil {
		rec = &stepRecord{started: time.Now()}
	}
	encoded, _ := json.Marshal(end.Result)
	stored := string(encoded)
	if len(stored) > 20000 {
		stored = stored[:20000]
	}
	var errValue, screenshot any
	if end.Error != "" {
		errValue = end.Error
	}
	if p := dyn.Str(dyn.Get(end.Result, "screenshotPath")); p != "" {
		screenshot = p
	}
	j.e.execDB(context.Background(), `UPDATE agent_steps SET status = ?, result = ?, error = ?, screenshot_path = ?, completed_at = datetime('now') WHERE id = ?`,
		end.Status, stored, errValue, screenshot, stepID)

	success := end.Error == ""
	if !end.Blocked {
		var def *aiDefinition
		if s != nil {
			for i := range s.Catalog {
				if s.Catalog[i].Name == rec.tool {
					def = &s.Catalog[i]
				}
			}
		}
		j.r.Trust().RecordToolOutput(j.e.deps.Tools.Registry(), rec.tool, def)
	}
	if rec.tool == "send_message" && success {
		content := strings.TrimSpace(dyn.Str(firstOf(rec.args["content"], rec.args["message"], rec.args["text"], dyn.Get(end.Result, "content"))))
		if content == "[NO RESPONSE]" || dyn.Get(end.Result, "reason") == "no_response" || rec.args["purpose"] == "no_response" {
			j.r.Delivery.Lock()
			j.r.Delivery.NoResponse = true
			j.r.Delivery.Unlock()
		}
	}

	elapsed := time.Since(rec.started).Milliseconds()
	identity := j.toolIdentity(s, rec.tool, rec.args, end.ReadOnly, end.Fingerprint)
	identity["result_bytes"] = len(encoded)
	identity["result_compacted_bytes"] = len(end.Shown)
	receipt := map[string]any{"mutating": !end.Blocked && !end.ReadOnly, "ok": !end.Blocked && success}
	if end.Test != nil {
		exitCode, hasExit := dyn.Float(dyn.Get(end.Result, "exitCode"))
		receipt["test"] = map[string]any{"runner": end.Test.Get("runner"), "passed": end.Test.Get("passed"), "failed": end.Test.Get("failed"),
			"exit_ok": success && (!hasExit || exitCode == 0)}
	}
	status := "failed"
	if end.Suppressed {
		status = "suppressed"
	} else if success {
		status = "success"
	}
	var outcomeErr any
	if end.Error != "" {
		text := end.Error
		if len(text) > 300 {
			text = text[:300]
		}
		outcomeErr = text
	}
	payload := map[string]any{
		"tool": identity, "duration_ms": elapsed, "receipt": receipt, "progressed": end.Progressed,
		"outcome": map[string]any{"status": status, "error": outcomeErr},
		"privacy": map[string]any{"content_stored": false, "redaction_policy": "metadata-default"},
	}
	if commandMs, ok := dyn.Float(dyn.Get(end.Result, "durationMs")); ok && identity["group"] == "shell" {
		payload["sandbox_ms"] = max(0, float64(elapsed)-commandMs)
	}
	if id := dyn.Str(dyn.Get(end.Result, "outputArtifact", "artifactId")); id != "" {
		payload["artifact"] = map[string]any{"id": id, "bytes": dyn.Get(end.Result, "outputArtifact", "byteSize")}
	}
	j.publish(runledger.EventToolResult, payload, stepID, rec.callEvent)
}

func (j *runJournal) ToolEnd(s *ai.Session, stepID string, call ai.Call, compacted string, errText string) {
	status := "completed"
	var errValue any
	if errText != "" {
		status, errValue = "failed", errText
	}
	j.e.Emit(j.r.UserID, "run:tool_end", map[string]any{"runId": j.r.ID, "stepId": stepID, "toolName": call.Name, "result": compacted, "status": status, "error": errValue})
	if b := j.e.broker(j.r); b != nil {
		b.noteToolFinished()
	}
	j.mu.Lock()
	delete(j.steps, stepID)
	j.mu.Unlock()
}

func firstOf(values ...any) any {
	for _, v := range values {
		if dyn.Truthy(v) {
			return v
		}
	}
	return nil
}
