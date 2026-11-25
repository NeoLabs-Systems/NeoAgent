package agent

import (
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

// The state a long run must not lose: what it is doing, what it has verified
// and what it changed. The model keeps the ledger with task_ledger; the harness
// adds only what it saw itself. It survives compaction word for word.

var stepStatuses = map[string]bool{"pending": true, "active": true, "done": true, "blocked": true}

func textList(v any, limit, maxChars int) []any {
	out := []any{}
	for _, item := range dyn.List(v) {
		if len(out) >= limit {
			break
		}
		if text := ai.ClampRunContext(item, maxChars); text != "" {
			out = append(out, text)
		}
	}
	return out
}

func normalizeSteps(v any) []any {
	out := []any{}
	for i, step := range dyn.List(v) {
		if len(out) >= 24 {
			break
		}
		entry := dyn.Obj(step)
		if s, ok := step.(string); ok {
			entry = dyn.Map{"id": s}
		}
		id := firstOf(entry["id"], entry["step"], entry["title"])
		if id == nil {
			id = fmt.Sprintf("step_%d", i+1)
		}
		status := strings.ToLower(fmtAny(firstOf(entry["status"])))
		if !stepStatuses[status] {
			status = "pending"
		}
		out = append(out, map[string]any{"id": ai.ClampRunContext(id, 120), "status": status})
	}
	return out
}

// UpdateTaskLedger is task_ledger: sent fields replace what the ledger held,
// anything left out stays.
func (e *Engine) UpdateTaskLedger(runID string, args map[string]any) map[string]any {
	r, ok := e.RunInfo(runID)
	if !ok {
		return map[string]any{"error": "The run is no longer active."}
	}
	r.mu.Lock()
	next := map[string]any{}
	for k, v := range r.ledger {
		next[k] = v
	}
	if dyn.Truthy(args["goal"]) {
		next["goal"] = ai.ClampRunContext(args["goal"], 400)
	}
	if dyn.Truthy(args["constraints"]) {
		next["constraints"] = textList(args["constraints"], 12, 240)
	}
	if dyn.Truthy(args["steps"]) {
		next["steps"] = normalizeSteps(args["steps"])
	}
	if dyn.Truthy(args["observations"]) {
		next["observations"] = textList(args["observations"], 20, 240)
	}
	if dyn.Truthy(args["blockers"]) {
		next["blockers"] = textList(args["blockers"], 12, 240)
	}
	r.ledger = next
	r.mu.Unlock()
	e.PersistMetadata(runID, map[string]any{"ledger": next})
	return map[string]any{"recorded": true}
}

func joinTexts(v any, sep string) string {
	var parts []string
	for _, item := range dyn.List(v) {
		parts = append(parts, fmtAny(item))
	}
	return strings.Join(parts, sep)
}

func (r *Run) taskGoal(s *ai.Session) string {
	r.mu.Lock()
	goal := fmtAny(r.ledger["goal"])
	r.mu.Unlock()
	if goal != "" {
		return goal
	}
	request := r.Options.Context.RawUserMessage
	if request == "" {
		request = s.UserMessage
	}
	return ai.ClampRunContext(request, 400)
}

func (r *Run) taskStateLines() []string {
	r.mu.Lock()
	ledger := r.ledger
	changed := append([]string(nil), r.changedPaths...)
	r.mu.Unlock()
	for _, p := range r.checkpointChangedPaths() {
		if !contains(changed, p) {
			changed = append(changed, p)
		}
	}
	var lines []string
	if l := dyn.List(ledger["constraints"]); len(l) > 0 {
		lines = append(lines, "Constraints: "+joinTexts(l, "; "))
	}
	if steps := dyn.List(ledger["steps"]); len(steps) > 0 {
		var parts []string
		for _, step := range steps {
			m := dyn.Obj(step)
			parts = append(parts, fmt.Sprintf("%v [%v]", m["id"], m["status"]))
		}
		lines = append(lines, "Steps: "+strings.Join(parts, ", "))
	}
	if l := dyn.List(ledger["observations"]); len(l) > 0 {
		lines = append(lines, "Your notes (not checked by anything): "+joinTexts(l, "; "))
	}
	if l := dyn.List(ledger["blockers"]); len(l) > 0 {
		lines = append(lines, "Blockers: "+joinTexts(l, "; "))
	}
	if len(changed) > 0 {
		if len(changed) > 30 {
			changed = changed[len(changed)-30:]
		}
		lines = append(lines, "Recorded: files changed in this run: "+strings.Join(changed, ", "))
	}
	return lines
}

// NoteChangedPath records a file a run's tool changed.
func (e *Engine) NoteChangedPath(runID, path string) {
	r, ok := e.RunInfo(runID)
	if !ok || path == "" {
		return
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if !contains(r.changedPaths, path) {
		r.changedPaths = append(r.changedPaths, path)
	}
}

// CreatedAgentInRun says whether the run already created an agent.
func (e *Engine) CreatedAgentInRun(runID string) bool {
	r, ok := e.RunInfo(runID)
	if !ok {
		return false
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.createdAgent != ""
}

// AgentCreated records an agent create_agent made.
func (e *Engine) AgentCreated(runID string, userID int64, agentID, createdID string) {
	if r, ok := e.RunInfo(runID); ok {
		r.mu.Lock()
		r.createdAgent = createdID
		r.mu.Unlock()
	}
	e.RecordEvent(userID, runID, agentID, "agent.created", map[string]any{"agent_id": createdID})
	e.Emit(userID, "agents:changed", map[string]any{"agentId": createdID})
}
