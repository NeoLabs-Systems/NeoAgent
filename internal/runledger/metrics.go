package runledger

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"sort"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
)

// ToolGroup names a tool's group ("control" tools are how a run reaches other
// tools, not what it set out to use).
type ToolGroup func(name string) string

func eventMs(e Stored) int64 {
	t, ok := parseISO(dyn.Str(e.Payload["timestamp"]))
	if !ok {
		return 0
	}
	return t.UnixMilli()
}

func num(v any) float64 {
	f, _ := dyn.Float(v)
	if math.IsNaN(f) || math.IsInf(f, 0) {
		return 0
	}
	return f
}

func ofType(events []Stored, types ...string) []Stored {
	var out []Stored
	for _, e := range events {
		for _, t := range types {
			if e.EventType == t {
				out = append(out, e)
				break
			}
		}
	}
	return out
}

func sumOf(events []Stored, pick func(Stored) any) float64 {
	total := 0.0
	for _, e := range events {
		total += num(pick(e))
	}
	return total
}

// UsageRow is one agent_model_usage row's token columns.
type UsageRow struct {
	Input, Output, Reasoning, CachedRead, CacheWrite, Total float64
}

// SummarizeRunEvents is one run's summary computed from its ledger: the numbers
// the Runs tab shows and the eval gate compares.
func SummarizeRunEvents(events []Stored, usage []UsageRow, status string, group ToolGroup) map[string]any {
	var started, ended int64
	if len(events) > 0 {
		started = eventMs(events[0])
		ended = eventMs(events[len(events)-1])
	}
	modelResponses := ofType(events, EventModelResponse)
	var loopResponses []Stored
	for _, e := range modelResponses {
		phase := dyn.Str(e.Payload["phase"])
		if phase == "" || phase == "model_turn" {
			loopResponses = append(loopResponses, e)
		}
	}
	toolResults := ofType(events, EventToolResult)
	suppressed := ofType(events, EventToolSuppressed)
	var recalls []Stored
	for _, e := range ofType(events, EventMemoryRecall) {
		if e.Payload["recalled"] != false {
			recalls = append(recalls, e)
		}
	}
	compactions := ofType(events, EventContextCompacted)
	deliveries := ofType(events, EventDeliverySent, EventDeliveryFailed, EventDeliverySuppressed)
	selections := ofType(events, EventToolsSelected)
	var initialSelection *Stored
	for i := range selections {
		if selections[i].Payload["kind"] == "initial" {
			initialSelection = &selections[i]
			break
		}
	}
	var contextBuilt *Stored
	if built := ofType(events, EventContextBuilt); len(built) > 0 {
		contextBuilt = &built[0]
	}
	var firstAction *Stored
	if first := ofType(events, EventToolCall, EventDeliverySent); len(first) > 0 {
		firstAction = &first[0]
	}

	toolMs := sumOf(toolResults, func(e Stored) any { return e.Payload["duration_ms"] })
	sandboxMs := sumOf(toolResults, func(e Stored) any { return e.Payload["sandbox_ms"] })
	modelMs := sumOf(modelResponses, func(e Stored) any { return e.Payload["duration_ms"] })
	deliveryMs := sumOf(ofType(events, EventDeliverySent), func(e Stored) any { return e.Payload["duration_ms"] })
	queueMs := 0.0
	if contextBuilt != nil {
		queueMs = num(contextBuilt.Payload["startup_ms"])
	}
	var tokens UsageRow
	for _, row := range usage {
		tokens.Input += row.Input
		tokens.Output += row.Output
		tokens.Reasoning += row.Reasoning
		tokens.CachedRead += row.CachedRead
		tokens.CacheWrite += row.CacheWrite
		tokens.Total += row.Total
	}
	var toolNames []string
	for _, e := range toolResults {
		if name := dyn.Str(dyn.Get(e.Payload, "tool", "name")); name != "" {
			toolNames = append(toolNames, name)
		}
	}
	finalSent := 0
	for _, e := range deliveries {
		if e.Payload["purpose"] == "final" && e.EventType == EventDeliverySent {
			finalSent++
		}
	}
	memoryTokens := sumOf(recalls, func(e Stored) any { return e.Payload["tokens"] })
	sections := dyn.Obj(nil)
	if contextBuilt != nil {
		sections = dyn.Obj(contextBuilt.Payload["sections"])
	}
	peak := 0.0
	for _, e := range ofType(events, EventModelRequest) {
		peak = math.Max(peak, num(dyn.Get(e.Payload, "context", "estimated_tokens")))
	}
	taskClass := aimodels.InferTaskKind(toolNames)
	if taskClass == "" {
		taskClass = "answer"
		if len(toolNames) > 0 {
			taskClass = "general"
		}
	}
	var firstActionMs any
	if firstAction != nil && started != 0 {
		firstActionMs = max(0, eventMs(*firstAction)-started)
	}
	failed := 0
	for _, e := range toolResults {
		if dyn.Get(e.Payload, "outcome", "status") == "failed" {
			failed++
		}
	}
	var selection any
	if initialSelection != nil {
		activated, searched := 0, 0
		for _, e := range selections {
			switch e.Payload["kind"] {
			case "activate":
				activated++
			case "search":
				searched++
			}
		}
		sel := dyn.Obj(initialSelection.Payload["selection"])
		used, missed := selectionRecall(*initialSelection, toolNames, group)
		selection = map[string]any{
			"catalog_size": orNull(sel["catalog_size"]), "eligible_count": orNull(sel["eligible_count"]), "active_count": orNull(sel["active_count"]),
			"activated_later": activated, "searched": searched, "tools_used": used, "missed_first_turn": missed,
		}
	}
	shareOfPrompt := 0.0
	if peak > 0 {
		shareOfPrompt = round4(memoryTokens / peak)
	}
	deliveryFailed := ofType(events, EventDeliveryFailed)
	ambiguous := 0
	for _, e := range deliveryFailed {
		if e.Payload["ambiguous"] == true {
			ambiguous++
		}
	}
	denied := 0
	for _, e := range ofType(events, EventPermissionDecision) {
		if e.Payload["decision"] == "deny" {
			denied++
		}
	}
	var statusValue any
	if status != "" {
		statusValue = status
	}
	var promptVersion any
	if contextBuilt != nil {
		promptVersion = orNull(contextBuilt.Payload["prompt_version"])
	}
	return map[string]any{
		"schema_version":  1,
		"status":          statusValue,
		"task_class":      taskClass,
		"prompt_version":  promptVersion,
		"duration_ms":     max(0, ended-started),
		"first_action_ms": firstActionMs,
		"latency": map[string]any{
			"queue_ms": queueMs, "model_ms": modelMs, "tool_ms": math.Max(0, toolMs-sandboxMs), "sandbox_ms": sandboxMs, "delivery_ms": deliveryMs,
		},
		"turns":      len(loopResponses),
		"side_calls": len(modelResponses) - len(loopResponses),
		"retries":    sumOf(modelResponses, func(e Stored) any { return e.Payload["retry_count"] }),
		"tools": map[string]any{
			"calls": len(toolResults), "failed": failed, "suppressed": len(suppressed), "used": uniqueStrings(toolNames),
			"duplicate_calls": duplicateCalls(toolResults), "suppressed_then_ran": suppressedThenRan(suppressed, toolResults),
		},
		"selection": selection,
		"context": map[string]any{
			"total_tokens": num(sections["total_tokens"]), "system_tokens": num(sections["system_tokens"]),
			"tool_tokens":    num(sections["tool_schema_tokens"]) + num(sections["tool_catalog_tokens"]),
			"history_tokens": num(sections["history_tokens"]), "memory_tokens": num(sections["memory_tokens"]),
		},
		"tokens": map[string]any{"input": tokens.Input, "output": tokens.Output, "reasoning": tokens.Reasoning, "cachedRead": tokens.CachedRead, "cacheWrite": tokens.CacheWrite, "total": tokens.Total},
		"prompt": map[string]any{"peak_estimated_tokens": peak},
		"memory": map[string]any{
			"recalls": len(recalls), "tokens": memoryTokens, "share_of_prompt": shareOfPrompt,
			"writes": sumOf(ofType(events, EventMemoryWrite), func(e Stored) any { return e.Payload["count"] }),
		},
		"outcome":            taskOutcome(status, events, toolResults),
		"compactions":        len(compactions),
		"recoveries":         len(ofType(events, EventRecoveryTriggered)),
		"checkpoints":        len(ofType(events, EventCheckpointCreated)),
		"permissions_denied": denied,
		"delivery": map[string]any{
			"sent": len(ofType(events, EventDeliverySent)), "failed": len(deliveryFailed), "suppressed": len(ofType(events, EventDeliverySuppressed)),
			"ambiguous": ambiguous, "final_sent": finalSent,
		},
	}
}

func orNull(v any) any { return v }

func round4(f float64) float64 { return math.Round(f*10000) / 10000 }

func uniqueStrings(list []string) []string {
	out := []string{}
	seen := map[string]bool{}
	for _, s := range list {
		if !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	return out
}

func selectionRecall(initial Stored, toolNames []string, group ToolGroup) (int, []string) {
	surfaced := map[string]bool{}
	for _, c := range dyn.List(initial.Payload["candidates"]) {
		surfaced[dyn.Str(dyn.Get(c, "name"))] = true
	}
	used := 0
	missed := []string{}
	for _, name := range uniqueStrings(toolNames) {
		if group != nil && group(name) == "control" {
			continue
		}
		used++
		if !surfaced[name] {
			missed = append(missed, name)
		}
	}
	return used, missed
}

func taskOutcome(status string, events, toolResults []Stored) map[string]any {
	receipt := func(e Stored) map[string]any { return dyn.Obj(e.Payload["receipt"]) }
	var actions, tests []Stored
	for _, e := range toolResults {
		if receipt(e)["mutating"] == true {
			actions = append(actions, e)
		}
		if receipt(e)["test"] != nil {
			tests = append(tests, e)
		}
	}
	located := ofType(events, EventWorkspaceChanged)
	var changes, tracked []Stored
	for _, e := range located {
		if e.Payload["reason"] != "not_a_repository" {
			changes = append(changes, e)
			if !dyn.Truthy(e.Payload["untracked"]) {
				tracked = append(tracked, e)
			}
		}
	}
	restores := ofType(events, EventCheckpointRestored)
	var lastTest, lastChange *Stored
	if len(tests) > 0 {
		lastTest = &tests[len(tests)-1]
	}
	if len(changes) > 0 {
		lastChange = &changes[len(changes)-1]
	}
	var test map[string]any
	if lastTest != nil {
		test = dyn.Obj(receipt(*lastTest)["test"])
	}
	files := map[string]bool{}
	for _, e := range tracked {
		for _, p := range dyn.List(e.Payload["paths"]) {
			files[dyn.Str(p)] = true
		}
	}
	actionsFailed := 0
	for _, e := range actions {
		if receipt(e)["ok"] != true {
			actionsFailed++
		}
	}
	messages := 0
	for _, e := range ofType(events, EventDeliverySent) {
		if e.Payload["purpose"] != "final" {
			messages++
		}
	}
	var lastTestValue any
	if test != nil {
		lastTestValue = test
	}
	evidence := map[string]any{
		"actions": len(actions), "actions_failed": actionsFailed, "files_changed": len(files),
		"changes_untracked": len(changes) - len(tracked), "outside_repositories": len(located) - len(changes),
		"tests_run": len(tests), "last_test": lastTestValue, "messages_sent": messages, "rolled_back": len(restores) > 0,
	}
	var lastAction map[string]any
	if len(actions) > 0 {
		lastAction = receipt(actions[len(actions)-1])
	}
	rolledBackLast := len(restores) > 0 && (lastChange == nil || restores[len(restores)-1].SequenceIndex > lastChange.SequenceIndex)
	outcome := "answered"
	switch {
	case status != "" && status != "completed":
		outcome = status
	case rolledBackLast:
		outcome = "rolled_back"
	case test != nil && (num(test["failed"]) > 0 || test["exit_ok"] == false):
		outcome = "tests_failing"
	case lastAction != nil && lastAction["ok"] != true:
		outcome = "action_failed"
	case lastChange != nil && (lastTest == nil || lastTest.SequenceIndex < lastChange.SequenceIndex):
		outcome = "unverified"
	case lastChange != nil && test != nil && num(test["passed"]) > 0:
		outcome = "verified"
	case len(actions) > 0:
		outcome = "actions_done"
	}
	return map[string]any{"task_outcome": outcome, "evidence": evidence}
}

func suppressedThenRan(suppressed, results []Stored) int {
	n := 0
	for _, s := range suppressed {
		for _, r := range results {
			if r.SequenceIndex > s.SequenceIndex &&
				dyn.Get(r.Payload, "tool", "name") == dyn.Get(s.Payload, "tool", "name") &&
				dyn.Get(r.Payload, "tool", "call_fingerprint") == dyn.Get(s.Payload, "tool", "call_fingerprint") {
				n++
				break
			}
		}
	}
	return n
}

func duplicateCalls(results []Stored) int {
	seen := map[string]bool{}
	n := 0
	for _, e := range results {
		fp := dyn.Str(dyn.Get(e.Payload, "tool", "call_fingerprint"))
		if fp == "" {
			continue
		}
		if seen[fp] {
			n++
		}
		seen[fp] = true
	}
	return n
}

// SummarizeRun computes a run's summary from the ledger and usage records.
func (l *Ledger) SummarizeRun(ctx context.Context, runID string, group ToolGroup) (map[string]any, error) {
	var status sql.NullString
	err := l.DB.R.QueryRowContext(ctx, `SELECT status FROM agent_runs WHERE id = ?`, runID).Scan(&status)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	rows, err := l.DB.R.QueryContext(ctx, `SELECT input_tokens, output_tokens, reasoning_tokens, cached_read_tokens, cache_write_tokens, total_tokens FROM agent_model_usage WHERE run_id = ?`, runID)
	if err != nil {
		return nil, err
	}
	var usage []UsageRow
	for rows.Next() {
		var a, b, c, d, e, f sql.NullFloat64
		if err := rows.Scan(&a, &b, &c, &d, &e, &f); err != nil {
			rows.Close()
			return nil, err
		}
		usage = append(usage, UsageRow{a.Float64, b.Float64, c.Float64, d.Float64, e.Float64, f.Float64})
	}
	rows.Close()
	events, err := l.List(ctx, runID, 0, 5000)
	if err != nil {
		return nil, err
	}
	return SummarizeRunEvents(events, usage, status.String, group), nil
}

// PersistRunMetrics stores a run's summary on its row.
func (l *Ledger) PersistRunMetrics(ctx context.Context, runID string, group ToolGroup) map[string]any {
	metrics, err := l.SummarizeRun(ctx, runID, group)
	if err != nil || metrics == nil {
		if err != nil {
			l.log().Warn("Could not store run metrics", "error", err)
		}
		return nil
	}
	encoded, _ := json.Marshal(metrics)
	if _, err := l.DB.W.ExecContext(ctx, `UPDATE agent_runs SET metrics_json = ? WHERE id = ?`, string(encoded), runID); err != nil {
		l.log().Warn("Could not store run metrics", "error", err)
	}
	return metrics
}

// ReadRunMetrics is the stored summary, or the live one for a run in progress.
func (l *Ledger) ReadRunMetrics(ctx context.Context, runID, stored string, group ToolGroup) map[string]any {
	if stored != "" {
		return ParseObject(stored)
	}
	metrics, _ := l.SummarizeRun(ctx, runID, group)
	return metrics
}

// DiagnoseRun says why a run was slow, wasteful or uncertain, from its summary.
func DiagnoseRun(metrics map[string]any) []map[string]any {
	found := []map[string]any{}
	if metrics == nil {
		return found
	}
	add := func(code string, values map[string]any) {
		entry := map[string]any{"code": code}
		for k, v := range values {
			entry[k] = v
		}
		found = append(found, entry)
	}
	switch outcome := dyn.Str(dyn.Get(metrics, "outcome", "task_outcome")); outcome {
	case "action_failed", "tests_failing", "unverified", "rolled_back":
		add("outcome_"+outcome, nil)
	}
	if n := num(dyn.Get(metrics, "outcome", "evidence", "changes_untracked")); n > 0 {
		add("changes_not_tracked", map[string]any{"count": n})
	}
	if n := num(dyn.Get(metrics, "delivery", "ambiguous")); n > 0 {
		add("delivery_ambiguous", map[string]any{"count": n})
	}
	if n := num(dyn.Get(metrics, "tools", "suppressed_then_ran")); n > 0 {
		add("suppression_overruled", map[string]any{"count": n})
	}
	if n := num(dyn.Get(metrics, "tools", "duplicate_calls")); n >= 2 {
		add("repeated_calls", map[string]any{"count": n})
	}
	if n := num(dyn.Get(metrics, "tools", "failed")); n >= 2 {
		add("failed_tools", map[string]any{"count": n})
	}
	if missed := dyn.List(dyn.Get(metrics, "selection", "missed_first_turn")); len(missed) > 0 {
		add("tool_not_on_first_turn", map[string]any{"tools": missed})
	}
	duration := num(metrics["duration_ms"])
	model := num(dyn.Get(metrics, "latency", "model_ms"))
	if duration >= 10000 && model/duration >= 0.7 {
		add("slow_model_loop", map[string]any{"share": math.Round(model/duration*100) / 100})
	}
	toolTokens := num(dyn.Get(metrics, "context", "tool_tokens"))
	total := num(dyn.Get(metrics, "context", "total_tokens"))
	if toolTokens >= 5000 && total > 0 && toolTokens/total >= 0.5 {
		add("tools_fill_context", map[string]any{"share": math.Round(toolTokens/total*100) / 100, "tokens": toolTokens})
	}
	return found
}

func spread(values []float64) map[string]any {
	sorted := make([]float64, 0, len(values))
	for _, v := range values {
		if !math.IsNaN(v) {
			sorted = append(sorted, v)
		}
	}
	sort.Float64s(sorted)
	pct := func(share float64) any {
		if len(sorted) == 0 {
			return nil
		}
		i := int(math.Floor(float64(len(sorted)) * share))
		if i > len(sorted)-1 {
			i = len(sorted) - 1
		}
		return sorted[i]
	}
	return map[string]any{"p50": pct(0.5), "p95": pct(0.95), "samples": len(sorted)}
}

func rate(part, whole float64) float64 {
	if whole <= 0 {
		return 0
	}
	return round4(part / whole)
}

// HarnessReport is what recent runs looked like, from their stored summaries.
func (l *Ledger) HarnessReport(ctx context.Context, userID int64, agentID string, days int) (map[string]any, error) {
	if days <= 0 {
		days = 7
	}
	rows, err := l.DB.R.QueryContext(ctx, `SELECT status, metrics_json FROM agent_runs
		WHERE user_id = ? AND agent_id = ? AND metrics_json IS NOT NULL AND datetime(created_at) >= datetime('now', ?)
		ORDER BY created_at DESC LIMIT 2000`, userID, agentID, fmt.Sprintf("-%d days", days))
	if err != nil {
		return nil, err
	}
	type runRow struct {
		status string
		m      map[string]any
	}
	var runs []runRow
	for rows.Next() {
		var status, metrics sql.NullString
		if err := rows.Scan(&status, &metrics); err != nil {
			rows.Close()
			return nil, err
		}
		runs = append(runs, runRow{status.String, ParseObject(metrics.String)})
	}
	rows.Close()
	g := func(r runRow, path ...string) float64 { return num(dyn.Get(r.m, path...)) }
	var t struct{ calls, failed, suppressed, dup, dupDel, failedDel, input, cached, output, recov, compact, recalls, memTok, denied, ambig, supRan, used, missed float64 }
	noTool, completed := 0.0, 0.0
	collect := func(path ...string) []float64 {
		var out []float64
		for _, r := range runs {
			if v, ok := dyn.Float(dyn.Get(r.m, path...)); ok {
				out = append(out, v)
			}
		}
		return out
	}
	for _, r := range runs {
		t.calls += g(r, "tools", "calls")
		t.failed += g(r, "tools", "failed")
		t.suppressed += g(r, "tools", "suppressed")
		t.dup += g(r, "tools", "duplicate_calls")
		t.dupDel += g(r, "delivery", "suppressed")
		t.failedDel += g(r, "delivery", "failed")
		t.input += g(r, "tokens", "input")
		t.cached += g(r, "tokens", "cachedRead")
		t.output += g(r, "tokens", "output")
		t.recov += g(r, "recoveries")
		t.compact += g(r, "compactions")
		t.recalls += g(r, "memory", "recalls")
		t.memTok += g(r, "memory", "tokens")
		t.denied += g(r, "permissions_denied")
		t.ambig += g(r, "delivery", "ambiguous")
		t.supRan += g(r, "tools", "suppressed_then_ran")
		t.used += g(r, "selection", "tools_used")
		t.missed += float64(len(dyn.List(dyn.Get(r.m, "selection", "missed_first_turn"))))
		if g(r, "tools", "calls") == 0 {
			noTool++
		}
		if r.status == "completed" {
			completed++
		}
	}
	n := float64(len(runs))
	var recall any
	if t.used > 0 {
		recall = rate(t.used-t.missed, t.used)
	}
	return map[string]any{
		"window_days":  days,
		"runs":         len(runs),
		"success_rate": rate(completed, n),
		"latency_ms": map[string]any{
			"total": spread(collect("duration_ms")), "first_action": spread(collect("first_action_ms")),
			"model": spread(collect("latency", "model_ms")), "tool": spread(collect("latency", "tool_ms")), "sandbox": spread(collect("latency", "sandbox_ms")),
		},
		"per_run": map[string]any{
			"turns": spread(collect("turns")), "tool_calls": spread(collect("tools", "calls")),
			"input_tokens": spread(collect("tokens", "input")), "output_tokens": spread(collect("tokens", "output")),
		},
		"rates": map[string]any{
			"no_tool_runs":                               rate(noTool, n),
			"tool_failure":                               rate(t.failed, t.calls),
			"tool_selection_recall":                      recall,
			"suppressed_calls_that_ran_later":            rate(t.supRan, t.suppressed),
			"ambiguous_deliveries_per_1000_runs":         rate(t.ambig*1000, n),
			"tool_suppressed":                            rate(t.suppressed, t.calls+t.suppressed),
			"duplicate_tool_calls":                       rate(t.dup, t.calls),
			"duplicate_deliveries_stopped_per_1000_runs": rate(t.dupDel*1000, n),
			"delivery_failures_per_1000_runs":            rate(t.failedDel*1000, n),
			"prompt_cache_hit":                           math.Min(1, rate(t.cached, t.input)),
			"memory_tokens_per_recall":                   rate(t.memTok, t.recalls),
			"recoveries_per_run":                         rate(t.recov, n),
			"compactions_per_run":                        rate(t.compact, n),
			"permission_denials_per_run":                 rate(t.denied, n),
		},
	}, nil
}

var _ = time.Now
