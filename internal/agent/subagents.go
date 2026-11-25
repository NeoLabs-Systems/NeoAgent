package agent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
)

// Sub-agents are for real parallel work or isolated context. They are a tool
// the model chooses; nothing here runs on its own.

type subagentLimit struct{ fallback, ceiling int }

var (
	subagentTurns   = subagentLimit{30, 60}
	subagentTokens  = subagentLimit{300_000, 1_000_000}
	subagentSeconds = subagentLimit{600, 1_800}
)

func (l subagentLimit) of(requested float64) int {
	if requested > 0 {
		return min(int(requested), l.ceiling)
	}
	return l.fallback
}

// SubagentOptions are what the parent asks of a sub-agent.
type SubagentOptions struct {
	AgentID           string
	Context           string
	Model             string
	Write             bool
	AllowedTools      []string
	SelectedTools     []string
	RequiredArtifacts []any
	MaxTurns          float64
	MaxTokens         float64
	MaxSeconds        float64
}

type subagentRecord struct {
	handle, parentRunID, childRunID string
	userID                          int64
	agentID                         string
	task                            string
	write                           bool
	createdAt                       string
	cancel                          context.CancelCauseFunc
	done                            chan struct{}

	mu      sync.Mutex
	status  string
	result  map[string]any
	errText string
	settled bool
	drop    bool
}

func (r *subagentRecord) snapshot() (string, map[string]any, string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.status, r.result, r.errText
}

type subagentRegistry struct {
	e       *Engine
	mu      sync.Mutex
	records map[string]*subagentRecord
}

func newSubagentRegistry(e *Engine) *subagentRegistry {
	return &subagentRegistry{e: e, records: map[string]*subagentRecord{}}
}

func (g *subagentRegistry) forParent(parentRunID string) []*subagentRecord {
	g.mu.Lock()
	defer g.mu.Unlock()
	var out []*subagentRecord
	for _, r := range g.records {
		if parentRunID == "" || r.parentRunID == parentRunID {
			out = append(out, r)
		}
	}
	return out
}

// HasWritingSubagent says a sub-agent of the run is changing the workspace.
func (e *Engine) HasWritingSubagent(parentRunID string) bool {
	for _, r := range e.subagents.forParent(parentRunID) {
		r.mu.Lock()
		writing := r.write && !r.settled
		r.mu.Unlock()
		if writing {
			return true
		}
	}
	return false
}

func parentActive(e *Engine, parentRunID string, userID int64) (*Run, bool) {
	parent, ok := e.RunInfo(parentRunID)
	if !ok || parent.UserID != userID || parent.Status() != "running" || parent.Aborted() {
		return nil, false
	}
	return parent, true
}

var fenceStrip = regexp.MustCompile("(?i)^```(?:json)?\\s*|\\s*```$")

// SpawnSubagent starts a bounded child run for part of the parent's work.
func (e *Engine) SpawnSubagent(ctx context.Context, userID int64, parentRunID, task string, o SubagentOptions) (map[string]any, error) {
	if e.ShuttingDown() {
		return nil, ErrShuttingDown
	}
	parent, ok := parentActive(e, parentRunID, userID)
	if !ok {
		return map[string]any{"error": "The parent run is no longer active, so a sub-agent cannot be started."}, nil
	}
	if parent.SubagentDepth >= 1 {
		return map[string]any{"error": "Sub-agents cannot spawn additional sub-agents. Continue the current child run or return results to the parent run."}, nil
	}
	if o.Write && e.HasWritingSubagent(parentRunID) {
		return map[string]any{"error": "Another sub-agent of this run is already changing the workspace. Wait for it, or start this one read-only."}, nil
	}
	maxChildren, _ := dyn.Int(e.aiSettings(ctx, userID, o.AgentID)["subagent_max_children_per_run"])
	if maxChildren < 1 {
		maxChildren = 10
	}
	if n := len(e.subagents.forParent(parentRunID)); n >= maxChildren {
		return map[string]any{"error": fmt.Sprintf("This run has already spawned %d sub-agents. The limit for one run is %d.", n, maxChildren)}, nil
	}
	var memories []memory.RecallResult
	if e.deps.Memory != nil {
		found, err := e.deps.Memory.RecallMemory(parent.Context(), userID, task, 4, memory.RecallOptions{AgentID: o.AgentID})
		if err != nil {
			if parent.Context().Err() != nil {
				return nil, err
			}
			e.log.Warn("Sub-agent memory recall failed", "error", err)
		}
		memories = found
	}
	parent, ok = parentActive(e, parentRunID, userID)
	if !ok || e.ShuttingDown() {
		return nil, errors.New("The parent run stopped before the sub-agent could start.")
	}
	if n := len(e.subagents.forParent(parentRunID)); n >= maxChildren {
		return map[string]any{"error": fmt.Sprintf("This run has already spawned %d sub-agents. The limit for one run is %d.", n, maxChildren)}, nil
	}
	parts := []string{"Goal: " + strings.TrimSpace(task)}
	if c := strings.TrimSpace(o.Context); c != "" {
		parts = append(parts, "Constraints and relevant context:\n"+c)
	}
	if len(memories) > 0 {
		list := make([]map[string]any, len(memories))
		for i, m := range memories {
			list[i] = map[string]any{"content": m.Content, "confidence": m.Confidence}
		}
		encoded, _ := json.Marshal(list)
		parts = append(parts, "Top relevant memories: "+string(encoded))
	}
	if len(o.RequiredArtifacts) > 0 {
		encoded, _ := json.Marshal(o.RequiredArtifacts)
		parts = append(parts, "Required artifacts: "+string(encoded))
	}
	if len(o.SelectedTools) > 0 {
		selected := o.SelectedTools
		if len(selected) > 20 {
			selected = selected[:20]
		}
		encoded, _ := json.Marshal(selected)
		parts = append(parts, "Selected tools: "+string(encoded))
	}
	parts = append(parts, "Return a single JSON object with exactly these top-level fields: status, findings, evidence, artifacts, confidence, remaining_blockers.",
		"status must be completed, partial, or blocked. findings, evidence, artifacts, and remaining_blockers must be arrays. confidence must be low, medium, or high.")
	contract := strings.Join(parts, "\n\n")

	childCtx, cancel := context.WithCancelCause(parent.Context())
	record := &subagentRecord{handle: uuid.NewString(), parentRunID: parentRunID, childRunID: uuid.NewString(), userID: userID, agentID: o.AgentID,
		task: contract, write: o.Write, createdAt: isoNow(), cancel: cancel, done: make(chan struct{}), status: "running"}
	e.subagents.mu.Lock()
	e.subagents.records[record.handle] = record
	e.subagents.mu.Unlock()
	e.Emit(userID, "run:subagent", map[string]any{"runId": parentRunID, "handle": record.handle, "childRunId": record.childRunID, "status": "running", "task": ai.ClampRunContext(task, 180)})

	timer := time.AfterFunc(time.Duration(subagentSeconds.of(o.MaxSeconds))*time.Second, func() { cancel(errors.New("The sub-agent ran out of time.")) })
	options := Options{RunID: record.childRunID, AgentID: o.AgentID, Title: task, TriggerType: "subagent", TriggerSource: "agent", SubagentDepth: parent.SubagentDepth + 1,
		DisallowedToolNames: []string{"spawn_subagent", "delegate_to_agent", "agent_task", "create_agent"}, DeviceTarget: parent.DeviceTarget, WorkspaceRoot: parent.WorkspaceRoot,
		AllowedToolNames: o.AllowedTools, ReadOnly: !o.Write, MaxIterations: subagentTurns.of(o.MaxTurns), MaxTotalTokens: subagentTokens.of(o.MaxTokens),
		ParentTrust: parent.Trust(), ParentRunID: parentRunID, Model: o.Model}
	e.work.Add(1)
	go func() {
		defer e.work.Done()
		defer close(record.done)
		defer timer.Stop()
		result, err := e.run(childCtx, userID, contract, options)
		record.mu.Lock()
		defer func() {
			record.settled = true
			drop := record.drop
			record.mu.Unlock()
			if drop {
				e.subagents.mu.Lock()
				if e.subagents.records[record.handle] == record {
					delete(e.subagents.records, record.handle)
				}
				e.subagents.mu.Unlock()
			}
		}()
		if record.status == "cancelled" {
			return
		}
		if err != nil || childCtx.Err() != nil {
			cancelled := childCtx.Err() != nil && context.Cause(childCtx) != nil && strings.Contains(context.Cause(childCtx).Error(), "cancelled")
			record.status = "failed"
			if err != nil {
				record.errText = err.Error()
			} else {
				record.errText = "The sub-agent was stopped."
				if cause := context.Cause(childCtx); cause != nil {
					record.errText = cause.Error()
				}
			}
			if cancelled {
				record.status, record.errText = "cancelled", ""
			}
			e.Emit(userID, "run:subagent", map[string]any{"runId": parentRunID, "handle": record.handle, "childRunId": record.childRunID, "status": record.status, "error": nullString(record.errText)})
			return
		}
		record.status = orText(result.Status, "completed")
		var structured map[string]any
		raw := fenceStrip.ReplaceAllString(strings.TrimSpace(result.Content), "")
		_ = json.Unmarshal([]byte(raw), &structured)
		list := func(key string, fallback []any) []any {
			if v, ok := structured[key].([]any); ok {
				return v
			}
			return fallback
		}
		findings := []any{}
		if c := strings.TrimSpace(result.Content); c != "" {
			findings = []any{c}
		}
		confidence := "medium"
		if c, _ := structured["confidence"].(string); c == "low" || c == "medium" || c == "high" {
			confidence = c
		}
		status := orText(fmtAny(structured["status"]), record.status)
		var recorded any
		if metrics, _ := e.ledger.SummarizeRun(context.Background(), record.childRunID, e.toolGroup); metrics != nil {
			recorded = metrics["outcome"]
		}
		record.result = map[string]any{"runId": result.RunID, "status": status, "findings": list("findings", findings), "evidence": list("evidence", []any{}),
			"artifacts": list("artifacts", []any{}), "confidence": confidence, "remainingBlockers": list("remaining_blockers", []any{}),
			"totalTokens": result.TotalTokens, "iterations": result.Iterations, "recorded": recorded}
		if record.write {
			if actions, _ := dyn.Float(dyn.Get(recorded, "evidence", "actions")); actions > 0 {
				// What it changed is not in the parent's ledger.
				e.RecordEvent(userID, parentRunID, o.AgentID, runledger.EventWorkspaceChanged, map[string]any{"untracked": true, "tool": "spawn_subagent", "reason": "subagent"})
			}
		}
		e.Emit(userID, "run:subagent", map[string]any{"runId": parentRunID, "handle": record.handle, "childRunId": record.childRunID, "status": record.status, "result": record.result})
	}()
	return map[string]any{"handle": record.handle, "status": "running", "childRunId": record.childRunID, "task": ai.ClampRunContext(task, 180)}, nil
}

// ListSubagents lists the sub-agents of a run (or of every run).
func (e *Engine) ListSubagents(parentRunID string) []map[string]any {
	out := []map[string]any{}
	for _, r := range e.subagents.forParent(parentRunID) {
		status, result, errText := r.snapshot()
		out = append(out, map[string]any{"handle": r.handle, "parentRunId": r.parentRunID, "childRunId": r.childRunID, "status": status,
			"task": ai.ClampRunContext(r.task, 180), "result": result, "error": nullString(errText), "createdAt": r.createdAt})
	}
	return out
}

func (e *Engine) subagent(handle, parentRunID string) (*subagentRecord, map[string]any) {
	e.subagents.mu.Lock()
	r := e.subagents.records[handle]
	e.subagents.mu.Unlock()
	if r == nil {
		return nil, map[string]any{"error": "Unknown sub-agent handle: " + handle}
	}
	if parentRunID != "" && r.parentRunID != parentRunID {
		return nil, map[string]any{"error": "That sub-agent does not belong to the current parent run."}
	}
	return r, nil
}

// WaitForSubagent waits up to timeout for a sub-agent's result.
func (e *Engine) WaitForSubagent(ctx context.Context, handle, parentRunID string, timeout time.Duration) map[string]any {
	r, refusal := e.subagent(handle, parentRunID)
	if refusal != nil {
		return refusal
	}
	if timeout < time.Second {
		timeout = 30 * time.Second
	}
	status, _, _ := r.snapshot()
	if status == "running" {
		select {
		case <-r.done:
		case <-time.After(timeout):
			return map[string]any{"handle": handle, "status": "running", "timedOut": true}
		case <-ctx.Done():
			return map[string]any{"handle": handle, "status": "running", "timedOut": true}
		}
	}
	status, result, errText := r.snapshot()
	return map[string]any{"handle": handle, "status": status, "result": result, "error": nullString(errText)}
}

// CancelSubagent stops a sub-agent.
func (e *Engine) CancelSubagent(handle, parentRunID string) map[string]any {
	r, refusal := e.subagent(handle, parentRunID)
	if refusal != nil {
		return refusal
	}
	r.mu.Lock()
	if r.status != "running" {
		status, result, errText := r.status, r.result, r.errText
		r.mu.Unlock()
		return map[string]any{"handle": handle, "status": status, "result": result, "error": nullString(errText)}
	}
	r.status = "cancelled"
	r.mu.Unlock()
	e.Emit(r.userID, "run:subagent", map[string]any{"runId": r.parentRunID, "handle": handle, "childRunId": r.childRunID, "status": "cancelled"})
	e.StopRun(r.childRunID, "Sub-agent cancelled by its parent run.")
	r.cancel(errors.New("Sub-agent cancelled by its parent run."))
	timedOut := false
	select {
	case <-r.done:
	case <-time.After(10 * time.Second):
		timedOut = true
	}
	return map[string]any{"handle": handle, "status": "cancelled", "timedOut": timedOut}
}

// cleanupForRun: sub-agents report only to their parent; once it ends nothing
// reads them.
func (g *subagentRegistry) cleanupForRun(parentRunID string) {
	for _, r := range g.forParent(parentRunID) {
		r.mu.Lock()
		r.drop = true
		running := r.status == "running"
		if running {
			r.status = "cancelled"
		}
		settled := r.settled
		r.mu.Unlock()
		if running {
			g.e.Emit(r.userID, "run:subagent", map[string]any{"runId": r.parentRunID, "handle": r.handle, "childRunId": r.childRunID, "status": "cancelled"})
			g.e.StopRun(r.childRunID, "Parent run finished before the sub-agent completed.")
			r.cancel(errors.New("Parent run finished before the sub-agent completed."))
		}
		if settled {
			g.mu.Lock()
			if g.records[r.handle] == r {
				delete(g.records, r.handle)
			}
			g.mu.Unlock()
		}
	}
}
