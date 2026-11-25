package agent

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"unicode/utf16"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neolabs-go/apperr"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// ChatContext is the web chat's recent messages and rolling summary.
type ChatContext struct {
	Recent  []map[string]any
	Summary string
}

// APIDeps are what the run routes need beyond the engine.
type APIDeps struct {
	// Commands handles chat commands; handled reports whether task was one.
	Commands func(ctx context.Context, task string, userID int64, agentID string) (handled bool, content string, events any, err error)
	// Conversation resolves the conversation a web run goes to.
	OwnedConversation   func(ctx context.Context, userID int64, conversationID string) (string, error)
	DefaultConversation func(ctx context.Context, userID int64, agentID string) (string, error)
	WebContext          func(ctx context.Context, userID int64, agentID string) (ChatContext, int, error)
}

// API serves the run routes under /api/agents.
type API struct {
	e    *Engine
	deps APIDeps
}

// NewAPI creates the run routes.
func NewAPI(e *Engine, deps APIDeps) *API { return &API{e: e, deps: deps} }

// Routes registers the run routes.
func (a *API) Routes(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/agents", a.auth(a.handleRun))
	mux.HandleFunc("GET /api/agents/harness/report", a.auth(a.handleHarnessReport))
	mux.HandleFunc("POST /api/agents/multi-step", a.auth(a.handleMultiStep))
	mux.HandleFunc("GET /api/agents/{runId}", a.auth(a.handleGetRun))
	mux.HandleFunc("GET /api/agents/{runId}/steps", a.auth(a.handleSteps))
	mux.HandleFunc("GET /api/agents/{runId}/prompt", a.auth(a.handlePrompt))
	mux.HandleFunc("GET /api/agents/{runId}/prompt/{requestId}", a.auth(a.handlePromptTurn))
	mux.HandleFunc("POST /api/agents/{runId}/abort", a.auth(a.handleAbort))
	mux.HandleFunc("POST /api/agents/{runId}/pause", a.auth(a.handlePause))
	mux.HandleFunc("POST /api/agents/{runId}/resume", a.auth(a.handleResume))
	mux.HandleFunc("DELETE /api/agents/{runId}", a.auth(a.handleDelete))
}

func (a *API) auth(next func(http.ResponseWriter, *http.Request, int64)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		sess := sessionx.FromContext(r.Context())
		var uid int64
		ok := false
		if sess != nil {
			uid, ok = sess.Int64("userId")
		}
		if !ok || uid <= 0 {
			httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
			return
		}
		next(w, r, uid)
	}
}

func (a *API) agentFromRequest(r *http.Request, userID int64, body map[string]any) string {
	candidate := strings.TrimSpace(r.URL.Query().Get("agentId"))
	if candidate == "" {
		candidate = strings.TrimSpace(r.Header.Get("X-Agent-Id"))
	}
	if candidate == "" && body != nil {
		candidate = strings.TrimSpace(fmtAny(firstOf(body["agentId"], body["agent_id"])))
	}
	id, err := a.e.deps.Agents.Resolve(r.Context(), userID, candidate)
	if err != nil {
		return candidate
	}
	return id
}

func readJSON(r *http.Request) map[string]any {
	raw, _ := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	var body map[string]any
	_ = json.Unmarshal(raw, &body)
	if body == nil {
		body = map[string]any{}
	}
	return body
}

func utf16Length(s string) int { return len(utf16.Encode([]rune(s))) }

func (a *API) errorStatus(err error) int {
	var coded interface{ StatusCode() int }
	if errors.As(err, &coded) && coded.StatusCode() > 0 {
		return coded.StatusCode()
	}
	if e, ok := apperr.As(err); ok && e.Status > 0 {
		return e.Status
	}
	return http.StatusInternalServerError
}

func (a *API) sanitize(err error) string { return publicerr.Sanitize(err.Error(), "", "") }

func (a *API) handleRun(w http.ResponseWriter, r *http.Request, userID int64) {
	body := readJSON(r)
	options := dyn.Obj(body["options"])
	agentID := a.agentFromRequest(r, userID, options)
	task, ok := body["task"].(string)
	if !ok || task == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Task must be a non-empty string"})
		return
	}
	if utf16Length(task) > 50000 {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Task exceeds maximum length of 50,000 characters"})
		return
	}
	ctx := r.Context()
	if a.deps.Commands != nil {
		handled, content, events, err := a.deps.Commands(ctx, task, userID, agentID)
		if err == nil && handled {
			if content == "" {
				content = "Done."
			}
			if events == nil {
				events = []any{}
			}
			httpx.WriteJSON(w, http.StatusOK, map[string]any{"command": true, "content": content, "events": events})
			return
		}
	}
	var conversationID string
	var err error
	if requested := fmtAny(options["conversationId"]); requested != "" {
		conversationID, err = a.deps.OwnedConversation(ctx, userID, requested)
	} else {
		conversationID, err = a.deps.DefaultConversation(ctx, userID, agentID)
	}
	if err != nil {
		httpx.WriteJSON(w, a.errorStatus(err), map[string]any{"error": a.sanitize(err), "code": publicErrorCode(err)})
		return
	}
	a.e.execDB(ctx, `INSERT INTO conversation_history (user_id, agent_id, role, content, metadata) VALUES (?, ?, 'user', ?, '{"platform":"flutter"}')`, userID, agentID, task)
	var prior []map[string]any
	var summary string
	if a.deps.WebContext != nil {
		chat, window, err := a.deps.WebContext(ctx, userID, agentID)
		if err == nil {
			last := -1
			for i, m := range chat.Recent {
				if m["role"] == "user" && m["content"] == task {
					last = i
				}
			}
			for i, m := range chat.Recent {
				if i != last {
					prior = append(prior, m)
				}
			}
			if len(prior) > window {
				prior = prior[len(prior)-window:]
			}
			summary = chat.Summary
		}
	}
	result, err := a.e.Run(ctx, userID, task, Options{AgentID: agentID, ConversationID: conversationID, PriorMessages: messagesFromRows(prior), PriorSummary: summary})
	if err != nil {
		a.e.log.Error("Run failed", "error", err)
		httpx.WriteJSON(w, a.errorStatus(err), map[string]any{"error": a.sanitize(err), "code": publicErrorCode(err)})
		return
	}
	if a.e.StoreWebReply != nil {
		a.e.StoreWebReply(userID, agentID, "", result)
	}
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (a *API) handleMultiStep(w http.ResponseWriter, r *http.Request, userID int64) {
	body := readJSON(r)
	options := dyn.Obj(body["options"])
	agentID := a.agentFromRequest(r, userID, options)
	task, ok := body["task"].(string)
	if !ok || task == "" {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Task must be a non-empty string"})
		return
	}
	if utf16Length(task) > 50000 {
		httpx.WriteJSON(w, http.StatusBadRequest, map[string]any{"error": "Task exceeds maximum length of 50,000 characters"})
		return
	}
	steps := dyn.List(body["steps"])
	if steps == nil {
		steps = []any{}
	}
	id := newOrchestrationID()
	a.e.Emit(userID, "orchestration:start", map[string]any{"orchestrationId": id, "task": task, "requestedSteps": steps})
	result, err := a.e.Run(r.Context(), userID, task, Options{RunID: id, AgentID: agentID, ConversationID: fmtAny(options["conversationId"])})
	if err != nil {
		a.e.Emit(userID, "orchestration:error", map[string]any{"orchestrationId": id, "error": err.Error()})
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": a.sanitize(err)})
		return
	}
	a.e.Emit(userID, "orchestration:complete", map[string]any{"orchestrationId": id, "result": result.Content, "totalTokens": result.TotalTokens, "iterations": result.Iterations})
	httpx.WriteJSON(w, http.StatusOK, result)
}

func (a *API) handleHarnessReport(w http.ResponseWriter, r *http.Request, userID int64) {
	agentID := a.agentFromRequest(r, userID, nil)
	days := 7
	if v := r.URL.Query().Get("days"); v != "" {
		var n float64
		if err := json.Unmarshal([]byte(v), &n); err == nil && n >= 1 {
			days = int(n)
		}
	}
	report, err := a.e.ledger.HarnessReport(r.Context(), userID, agentID, days)
	if err != nil {
		httpx.WriteJSON(w, http.StatusInternalServerError, map[string]any{"error": a.sanitize(err)})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, report)
}

// rows reads a query as column-keyed objects, the way better-sqlite3 returns them.
func rows(ctx context.Context, q interface {
	QueryContext(context.Context, string, ...any) (*sql.Rows, error)
}, query string, args ...any) ([]map[string]any, error) {
	result, err := q.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer result.Close()
	columns, _ := result.Columns()
	out := []map[string]any{}
	for result.Next() {
		values := make([]any, len(columns))
		pointers := make([]any, len(columns))
		for i := range values {
			pointers[i] = &values[i]
		}
		if err := result.Scan(pointers...); err != nil {
			return nil, err
		}
		row := make(map[string]any, len(columns))
		for i, c := range columns {
			if b, ok := values[i].([]byte); ok {
				row[c] = string(b)
			} else {
				row[c] = values[i]
			}
		}
		out = append(out, row)
	}
	return out, result.Err()
}

func (a *API) redact(userID int64, row map[string]any) map[string]any {
	if a.e.isAdmin(userID) || row == nil || !dyn.Truthy(row["error"]) {
		return row
	}
	out := make(map[string]any, len(row))
	for k, v := range row {
		out[k] = v
	}
	out["error"] = publicerr.Generic
	if _, ok := out["result"]; ok {
		out["result"] = nil
	}
	return out
}

func (a *API) redactAll(userID int64, list []map[string]any) []map[string]any {
	out := make([]map[string]any, len(list))
	for i, row := range list {
		out[i] = a.redact(userID, row)
	}
	return out
}

func (a *API) ownedRun(w http.ResponseWriter, r *http.Request, userID int64) map[string]any {
	found, err := rows(r.Context(), a.e.deps.DB.R, `SELECT * FROM agent_runs WHERE id = ? AND user_id = ?`, r.PathValue("runId"), userID)
	if err != nil || len(found) == 0 {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "Run not found"})
		return nil
	}
	return found[0]
}

func (a *API) usageSummary(ctx context.Context, runID string) map[string]any {
	list, _ := rows(ctx, a.e.deps.DB.R, `SELECT provider, model, phase, input_tokens, output_tokens, reasoning_tokens, cached_read_tokens, cache_write_tokens,
		total_tokens, estimated_cost_usd, latency_ms FROM agent_model_usage WHERE run_id = ? ORDER BY id ASC`, runID)
	keys := []string{"inputTokens", "outputTokens", "reasoningTokens", "cachedReadTokens", "cacheWriteTokens", "totalTokens", "latencyMs"}
	columns := []string{"input_tokens", "output_tokens", "reasoning_tokens", "cached_read_tokens", "cache_write_tokens", "total_tokens", "latency_ms"}
	totals := map[string]float64{}
	type aggregate struct {
		values          map[string]float64
		provider, model any
		calls, priced   int
		cost            float64
		phases          []string
	}
	var order []string
	models := map[string]*aggregate{}
	pricedTotal, costTotal := 0, 0.0
	for _, row := range list {
		key := fmtAny(row["provider"]) + ":" + fmtAny(row["model"])
		agg := models[key]
		if agg == nil {
			agg = &aggregate{values: map[string]float64{}, provider: row["provider"], model: row["model"]}
			models[key] = agg
			order = append(order, key)
		}
		agg.calls++
		for i, k := range keys {
			v := num(row[columns[i]])
			totals[k] += v
			agg.values[k] += v
		}
		cost := num(row["estimated_cost_usd"])
		costTotal += cost
		pricedTotal++
		agg.cost += cost
		agg.priced++
		phase := strings.TrimSpace(fmtAny(row["phase"]))
		if phase == "" {
			phase = "model_turn"
		}
		if !contains(agg.phases, phase) {
			agg.phases = append(agg.phases, phase)
		}
	}
	price := func(priced int, cost float64) any {
		if priced > 0 {
			return cost
		}
		return nil
	}
	totalsOut := map[string]any{"estimatedCostUsd": price(pricedTotal, costTotal), "pricedCallCount": pricedTotal}
	for _, k := range keys {
		totalsOut[k] = totals[k]
	}
	modelList := []map[string]any{}
	for _, key := range order {
		agg := models[key]
		entry := map[string]any{"provider": agg.provider, "model": agg.model, "callCount": agg.calls, "estimatedCostUsd": price(agg.priced, agg.cost),
			"pricedCallCount": agg.priced, "phases": agg.phases}
		for _, k := range keys {
			entry[k] = agg.values[k]
		}
		modelList = append(modelList, entry)
	}
	return map[string]any{"totals": totalsOut, "models": modelList}
}

func num(v any) float64 {
	f, _ := dyn.Float(v)
	switch n := v.(type) {
	case int64:
		return float64(n)
	}
	return f
}

func (a *API) handleGetRun(w http.ResponseWriter, r *http.Request, userID int64) {
	run := a.ownedRun(w, r, userID)
	if run == nil {
		return
	}
	ctx := r.Context()
	id := fmtAny(run["id"])
	steps, _ := rows(ctx, a.e.deps.DB.R, `SELECT * FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC`, id)
	history, _ := rows(ctx, a.e.deps.DB.R, `SELECT * FROM conversation_history WHERE agent_run_id = ? ORDER BY created_at ASC`, id)
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"run": a.redact(userID, run), "steps": a.redactAll(userID, steps), "history": history, "usage": a.usageSummary(ctx, id)})
}

func (a *API) handleSteps(w http.ResponseWriter, r *http.Request, userID int64) {
	run := a.ownedRun(w, r, userID)
	if run == nil {
		return
	}
	ctx := r.Context()
	id := fmtAny(run["id"])
	steps, _ := rows(ctx, a.e.deps.DB.R, `SELECT * FROM agent_steps WHERE run_id = ? ORDER BY step_index ASC`, id)
	history, _ := rows(ctx, a.e.deps.DB.R, `SELECT content, metadata FROM conversation_history WHERE user_id = ? AND agent_run_id = ? AND role = 'assistant' ORDER BY created_at ASC`, userID, id)
	sent, _ := rows(ctx, a.e.deps.DB.R, `SELECT content, metadata FROM messages WHERE user_id = ? AND run_id = ? AND role = 'assistant' ORDER BY created_at ASC, id ASC`, userID, id)
	trimmed := func(v any) string { return strings.TrimSpace(fmtAny(v)) }
	var latestHistory, historyResponse, latestSent any
	for i := len(history) - 1; i >= 0; i-- {
		if latestHistory == nil && trimmed(history[i]["content"]) != "" {
			latestHistory = history[i]["content"]
		}
		if historyResponse == nil && !ai.IsInterimAssistantMetadata(history[i]["metadata"]) {
			historyResponse = history[i]["content"]
		}
	}
	var sentParts []string
	for i := len(sent) - 1; i >= 0; i-- {
		if latestSent == nil && trimmed(sent[i]["content"]) != "" {
			latestSent = sent[i]["content"]
		}
	}
	for _, row := range sent {
		if !ai.IsInterimAssistantMetadata(row["metadata"]) {
			if text := trimmed(row["content"]); text != "" {
				sentParts = append(sentParts, text)
			}
		}
	}
	var response any
	for _, candidate := range []any{strings.Join(sentParts, "\n\n"), historyResponse, latestSent, latestHistory, run["final_response"]} {
		if dyn.Truthy(candidate) {
			response = candidate
			break
		}
	}
	lifecycle, _ := rows(ctx, a.e.deps.DB.R, `SELECT c.action, c.reason, c.requested_at, c.consumed_at, p.phase AS checkpoint_phase, p.updated_at AS checkpoint_updated_at
		FROM agent_runs r LEFT JOIN agent_run_controls c ON c.run_id = r.id LEFT JOIN agent_run_checkpoints p ON p.run_id = r.id WHERE r.id = ?`, id)
	var life any
	if len(lifecycle) > 0 {
		life = lifecycle[0]
	}
	events, _ := a.e.ledger.List(ctx, id, 0, 5000)
	eventList := make([]any, len(events))
	for i, ev := range events {
		item := map[string]any{"id": ev.ID, "runId": ev.RunID, "userId": ev.UserID, "agentId": ev.AgentID, "eventType": ev.EventType, "requestId": ev.RequestID,
			"stepId": ev.StepID, "sequenceIndex": ev.SequenceIndex, "payload": ev.Payload, "createdAt": ev.CreatedAt}
		if !a.e.isAdmin(userID) && dyn.Truthy(ev.Payload["error"]) {
			item["payload"] = a.redact(userID, ev.Payload)
		}
		eventList[i] = item
	}
	metrics := a.e.ledger.ReadRunMetrics(ctx, id, fmtAny(run["metrics_json"]), a.e.toolGroup)
	var ledger any
	if l, ok := runledger.ParseObject(fmtAny(run["metadata_json"]))["ledger"]; ok && l != nil {
		ledger = l
	}
	var metricsOut any
	if metrics != nil {
		metricsOut = metrics
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"run": a.redact(userID, run), "steps": a.redactAll(userID, steps), "events": eventList,
		"metrics": metricsOut, "diagnostics": runledger.DiagnoseRun(metrics), "ledger": ledger, "response": response,
		"usage": a.usageSummary(ctx, id), "lifecycle": life,
	})
}

func renderBlock(block any) string {
	switch b := block.(type) {
	case string:
		return b
	case map[string]any:
		if b["type"] == "text" {
			if text, ok := b["text"].(string); ok {
				return text
			}
		}
		return dyn.StringifyIndent(b)
	}
	return ""
}

func renderContent(message map[string]any) string {
	var parts []string
	switch c := message["content"].(type) {
	case string:
		parts = append(parts, c)
	case []any:
		for _, block := range c {
			if text := renderBlock(block); text != "" {
				parts = append(parts, text)
			}
		}
	case nil:
	default:
		if dyn.Truthy(c) {
			parts = append(parts, dyn.StringifyIndent(c))
		}
	}
	if calls := dyn.List(message["tool_calls"]); len(calls) > 0 {
		parts = append(parts, "[Tool calls]\n"+dyn.StringifyIndent(calls))
	}
	return strings.Join(parts, "\n\n")
}

func sectionLabel(message map[string]any, index int) string {
	role := fmtAny(message["role"])
	if role == "" {
		role = "unknown"
	}
	switch role {
	case "system":
		text, _ := message["content"].(string)
		text = strings.TrimLeft(text, " \t\n\r")
		if strings.HasPrefix(text, "[") {
			if end := strings.Index(text, "]"); end > 0 {
				if tag := text[1:end]; utf16Length(tag) <= 80 && tag != "" {
					return tag
				}
			}
		}
		if index == 0 {
			return "System prompt"
		}
		return "System"
	case "user":
		return "User message"
	case "assistant":
		return "Assistant turn"
	case "tool":
		if name := fmtAny(message["name"]); name != "" {
			return "Tool result — " + name
		}
		return "Tool result"
	}
	return role
}

func (a *API) handlePrompt(w http.ResponseWriter, r *http.Request, userID int64) {
	run := a.ownedRun(w, r, userID)
	if run == nil {
		return
	}
	id := fmtAny(run["id"])
	list, _ := rows(r.Context(), a.e.deps.DB.R, `SELECT request_id, phase, iteration, provider, model, reason, payload_json, created_at FROM agent_run_captures
		WHERE run_id = ? AND datetime(expires_at) > datetime('now') ORDER BY id ASC`, id)
	turns := []map[string]any{}
	for i, row := range list {
		request := runledger.ParseObject(fmtAny(row["payload_json"]))
		header := dyn.Obj(request["header"])
		messages := dyn.List(request["messages"])
		characters := 0
		for _, m := range messages {
			characters += utf16Length(renderContent(dyn.Obj(m)))
		}
		maxTokens, _ := dyn.Float(header["maxTokens"])
		iteration, _ := dyn.Float(row["iteration"])
		turns = append(turns, map[string]any{
			"requestId": row["request_id"], "sequenceIndex": i + 1, "createdAt": row["created_at"], "captureReason": firstOf(row["reason"]),
			"phase": orText(fmtAny(firstOf(row["phase"], header["phase"])), "model_turn"), "iteration": iteration,
			"provider": firstOf(row["provider"], header["provider"]), "model": firstOf(row["model"], header["model"]),
			"maxTokens": maxTokens, "reasoningEffort": firstOf(header["reasoningEffort"]), "messageCount": len(messages),
			"toolCount": len(dyn.List(request["tools"])), "characters": characters,
		})
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"runId": id, "turns": turns})
}

func (a *API) handlePromptTurn(w http.ResponseWriter, r *http.Request, userID int64) {
	run := a.ownedRun(w, r, userID)
	if run == nil {
		return
	}
	requestID := r.PathValue("requestId")
	list, _ := rows(r.Context(), a.e.deps.DB.R, `SELECT request_id, payload_json FROM agent_run_captures WHERE run_id = ? AND request_id = ?`, fmtAny(run["id"]), requestID)
	if len(list) == 0 {
		httpx.WriteJSON(w, http.StatusNotFound, map[string]any{"error": "Prompt not found for this run"})
		return
	}
	request := runledger.ParseObject(fmtAny(list[0]["payload_json"]))
	sections := []map[string]any{}
	for i, m := range dyn.List(request["messages"]) {
		message := dyn.Obj(m)
		text := renderContent(message)
		role := fmtAny(message["role"])
		if role == "" {
			role = "unknown"
		}
		sections = append(sections, map[string]any{"role": role, "label": sectionLabel(message, i), "text": text, "characters": utf16Length(text)})
	}
	toolList := []map[string]any{}
	for _, t := range dyn.List(request["tools"]) {
		tool := dyn.Obj(t)
		name := fmtAny(firstOf(tool["name"], dyn.Get(tool, "function", "name")))
		if name == "" {
			name = "tool"
		}
		description := fmtAny(firstOf(tool["description"], dyn.Get(tool, "function", "description")))
		toolList = append(toolList, map[string]any{"name": name, "description": strings.SplitN(description, "\n", 2)[0]})
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"requestId": requestID, "header": request["header"], "sections": sections, "tools": toolList})
}

func (a *API) handleAbort(w http.ResponseWriter, r *http.Request, userID int64) {
	if a.ownedRun(w, r, userID) == nil {
		return
	}
	a.e.Abort(r.PathValue("runId"), userID, "")
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"success": true})
}

func (a *API) handlePause(w http.ResponseWriter, r *http.Request, userID int64) {
	body := readJSON(r)
	if !a.e.PauseRun(r.PathValue("runId"), userID, fmtAny(body["reason"])) {
		httpx.WriteJSON(w, http.StatusConflict, map[string]any{"error": "Run is not active or cannot be paused."})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"success": true, "status": "pausing"})
}

func (a *API) handleResume(w http.ResponseWriter, r *http.Request, userID int64) {
	if !a.e.ResumeRun(r.PathValue("runId"), userID) {
		httpx.WriteJSON(w, http.StatusConflict, map[string]any{"error": "Run is not paused or cannot be resumed."})
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"success": true, "status": "running"})
}

func (a *API) handleDelete(w http.ResponseWriter, r *http.Request, userID int64) {
	run := a.ownedRun(w, r, userID)
	if run == nil {
		return
	}
	id := fmtAny(run["id"])
	ctx := r.Context()
	a.e.execDB(ctx, `DELETE FROM agent_steps WHERE run_id = ?`, id)
	a.e.execDB(ctx, `DELETE FROM conversation_history WHERE agent_run_id = ?`, id)
	a.e.execDB(ctx, `DELETE FROM agent_runs WHERE id = ?`, id)
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"success": true})
}

func messagesFromRows(rows []map[string]any) []llmMessage {
	out := make([]llmMessage, 0, len(rows))
	for _, row := range rows {
		out = append(out, llmMessage{Role: fmtAny(row["role"]), Content: row["content"]})
	}
	return out
}

type llmMessage = llm.Message

func newOrchestrationID() string { return uuid.NewString() }
