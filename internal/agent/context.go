package agent

import (
	"context"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"math"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/prompts"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

const (
	// The share of a model's input budget conversation history may start with.
	historyBudgetShare     = 0.5
	conversationToolRuns   = 3
	conversationToolLimit  = 8
	memoryMinSignal        = 0.35
	memoryRelativeFloor    = 0.7
	memoryBudgetShare      = 0.08
	maxActionArgumentChars = 1500
)

var letterOrDigit = regexp.MustCompile(`[\p{L}\p{N}]`)

// fitHistory cuts long history to a token budget: whole turns go, oldest
// first, rather than paying for a summary before the run has done anything.
func fitHistory(history []llm.Message, budget int) ([]llm.Message, int) {
	if ai.EstimateTokenCount(history, nil) <= budget {
		return history, 0
	}
	start, used := len(history), 0
	for start > 0 {
		next := ai.EstimateTokenCount(history[start-1:start], nil)
		if used+next > budget {
			break
		}
		used += next
		start--
	}
	for start < len(history) && history[start].Role != "user" {
		start++
	}
	return history[start:], start
}

func (e *Engine) recentConversationTools(ctx context.Context, conversationID, runID string) []string {
	if conversationID == "" {
		return nil
	}
	rows, err := e.deps.DB.R.QueryContext(ctx, `SELECT DISTINCT s.tool_name FROM agent_steps s WHERE s.tool_name IS NOT NULL AND s.run_id IN (
		SELECT id FROM agent_runs WHERE conversation_id = ? AND id != ? ORDER BY created_at DESC LIMIT ?) LIMIT ?`,
		conversationID, runID, conversationToolRuns, conversationToolLimit)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var name string
		if rows.Scan(&name) == nil {
			out = append(out, name)
		}
	}
	return out
}

type historyRow struct {
	ai.StoredMessageRow
	runID string
}

// conversationContext is the stored summary and recent messages of a
// conversation, with each earlier run's lasting actions after its request.
// ConversationContext is a conversation's summary and its latest messages as
// the model reads them.
func (e *Engine) ConversationContext(ctx context.Context, conversationID string, limit int) (string, []llm.Message) {
	return e.conversationContext(ctx, conversationID, limit)
}

func (e *Engine) conversationContext(ctx context.Context, conversationID string, limit int) (string, []llm.Message) {
	var summary sql.NullString
	_ = e.deps.DB.R.QueryRowContext(ctx, `SELECT summary FROM conversations WHERE id = ?`, conversationID).Scan(&summary)
	rows, err := e.deps.DB.R.QueryContext(ctx, `SELECT role, content, tool_calls, tool_call_id, name, run_id FROM conversation_messages
		WHERE conversation_id = ? ORDER BY created_at DESC, id DESC LIMIT ?`, conversationID, limit)
	if err != nil {
		return summary.String, nil
	}
	var recent []historyRow
	for rows.Next() {
		var role string
		var content, calls, callID, name, runID sql.NullString
		if rows.Scan(&role, &content, &calls, &callID, &name, &runID) != nil {
			continue
		}
		recent = append([]historyRow{{ai.StoredMessageRow{Role: role, Content: content.String, ToolCalls: calls.String, ToolCallID: callID.String, Name: name.String}, runID.String}}, recent...)
	}
	rows.Close()
	withActions := e.withRunActions(ctx, recent)
	return summary.String, ai.SanitizeConversationMessages(ai.NormalizeHistoryRows(withActions))
}

type actionStep struct {
	id, runID, tool, input, status, result, errText string
}

func (e *Engine) isLastingAction(step actionStep) bool {
	meta := e.deps.Tools.Registry().Meta(step.tool, nil)
	if meta.StepType == "note" {
		return false
	}
	if meta.SideEffect == "workspace" && !tools.IsShellCall(meta) {
		return false
	}
	var args map[string]any
	_ = json.Unmarshal([]byte(step.input), &args)
	return !canRepeat(meta, args)
}

// canRepeat: reads and run-local control or navigation repeat without
// reconciliation; appends, edits and commands may not be idempotent.
func canRepeat(meta tools.Meta, args map[string]any) bool {
	if tools.IsShellCall(meta) {
		return false
	}
	if tools.IsReadOnlyCall(meta, args) {
		return true
	}
	return meta.SideEffect == "none" || meta.SideEffect == "navigation"
}

func actionReceipt(step actionStep) string {
	status := step.status
	var result map[string]any
	_ = json.Unmarshal([]byte(step.result), &result)
	if status == "completed" && (result["ambiguous"] == true || result["deliveryAmbiguous"] == true) {
		status = "ambiguous"
	}
	if status == "running" || status == "pending" || status == "interrupted" {
		status = "unknown"
	}
	out := dyn.Ordered{{Key: "status", Value: status}}
	if step.errText != "" {
		out = append(out, dyn.KV{Key: "error", Value: ai.ClampRunContext(step.errText, 300)})
	}
	return dyn.Stringify(out)
}

func clampArguments(text string) string {
	var args any
	if json.Unmarshal([]byte(text), &args) != nil {
		return "{}"
	}
	obj, ok := args.(map[string]any)
	if !ok {
		return "{}"
	}
	out := map[string]any{}
	for k, v := range obj {
		if s, ok := v.(string); ok {
			out[k] = ai.ClampRunContext(s, maxActionArgumentChars)
		} else {
			out[k] = v
		}
	}
	return dyn.Stringify(out)
}

// withRunActions puts each earlier run's lasting actions right after the
// request that started it: a later run sees what was done from the ledger.
func (e *Engine) withRunActions(ctx context.Context, rows []historyRow) []ai.StoredMessageRow {
	var runIDs []any
	seen := map[string]bool{}
	for _, row := range rows {
		if row.Role == "user" && row.runID != "" && !seen[row.runID] {
			seen[row.runID] = true
			runIDs = append(runIDs, row.runID)
		}
	}
	plain := func() []ai.StoredMessageRow {
		out := make([]ai.StoredMessageRow, len(rows))
		for i, r := range rows {
			out[i] = r.StoredMessageRow
		}
		return out
	}
	if len(runIDs) == 0 {
		return plain()
	}
	q, err := e.deps.DB.R.QueryContext(ctx, `SELECT id, run_id, tool_name, tool_input, status, result, error FROM agent_steps
		WHERE tool_name IS NOT NULL AND run_id IN (`+strings.TrimSuffix(strings.Repeat("?, ", len(runIDs)), ", ")+`) ORDER BY step_index`, runIDs...)
	if err != nil {
		return plain()
	}
	byRun := map[string][]actionStep{}
	for q.Next() {
		var s actionStep
		var input, status, result, errText sql.NullString
		if q.Scan(&s.id, &s.runID, &s.tool, &input, &status, &result, &errText) != nil {
			continue
		}
		s.input, s.status, s.result, s.errText = input.String, status.String, result.String, errText.String
		if e.isLastingAction(s) {
			byRun[s.runID] = append(byRun[s.runID], s)
		}
	}
	q.Close()
	var out []ai.StoredMessageRow
	for _, row := range rows {
		out = append(out, row.StoredMessageRow)
		steps := byRun[row.runID]
		if row.Role != "user" || len(steps) == 0 {
			continue
		}
		delete(byRun, row.runID)
		calls := make([]map[string]any, len(steps))
		for i, s := range steps {
			calls[i] = map[string]any{"id": s.id, "type": "function", "function": map[string]any{"name": s.tool, "arguments": clampArguments(s.input)}}
		}
		encoded, _ := json.Marshal(calls)
		out = append(out, ai.StoredMessageRow{Role: "assistant", Content: "", ToolCalls: string(encoded)})
		for _, s := range steps {
			out = append(out, ai.StoredMessageRow{Role: "tool", ToolCallID: s.id, Name: s.tool, Content: actionReceipt(s)})
		}
	}
	return out
}

func directSignal(b memory.ScoreBreakdown) float64 {
	return math.Max(math.Max(b.Semantic, b.Lexical), math.Max(b.Entity, b.Relation))
}

func memoryTokens(message string) int {
	if message == "" {
		return 0
	}
	return ai.EstimateTokenCount([]llm.Message{{Role: "system", Content: message}}, nil)
}

// memoryRecall is the memory relevant to the request, found by direct search
// and handed to the agent before its first turn.
func (e *Engine) memoryRecall(ctx context.Context, r *Run, query string) string {
	started := time.Now()
	record := func(payload map[string]any) {
		payload["duration_ms"] = time.Since(started).Milliseconds()
		e.RecordEvent(r.UserID, r.ID, r.AgentID, runledger.EventMemoryRecall, payload)
	}
	if !letterOrDigit.MatchString(strings.TrimSpace(query)) {
		record(map[string]any{"trigger": "no_content", "recalled": false, "candidates": 0, "kept": 0, "tokens": 0})
		return ""
	}
	if e.deps.Memory == nil {
		return ""
	}
	found, err := e.deps.Memory.RecallMemory(ctx, r.UserID, query, 5, memory.RecallOptions{AgentID: r.AgentID, NoReinforce: true})
	if err != nil {
		if ctx.Err() == nil {
			e.log.Warn("Memory recall failed", "error", err)
		}
		return ""
	}
	best := 0.0
	for _, m := range found {
		best = math.Max(best, directSignal(m.ScoreBreakdown))
	}
	var kept []memory.RecallResult
	for _, m := range found {
		signal := directSignal(m.ScoreBreakdown)
		if signal >= memoryMinSignal && signal >= best*memoryRelativeFloor {
			kept = append(kept, m)
		}
	}
	message := e.deps.Memory.BuildRecallMessage(ctx, r.UserID, query, memory.RecallMessageOptions{AgentID: r.AgentID, Recalled: emptyIfNil(kept)})
	scores := make([]float64, len(kept))
	for i, m := range kept {
		scores[i] = math.Round(m.Score*1000) / 1000
	}
	cosines := make([]float64, len(found))
	for i, m := range found {
		cosines[i] = math.Round(m.ScoreBreakdown.Cosine*1000) / 1000
	}
	record(map[string]any{"trigger": "default", "recalled": true, "candidates": len(found), "kept": len(kept), "dropped": len(found) - len(kept),
		"scores": scores, "cosines": cosines, "tokens": memoryTokens(message)})
	return message
}

func emptyIfNil(list []memory.RecallResult) []memory.RecallResult {
	if list == nil {
		return []memory.RecallResult{}
	}
	return list
}

// userTurn is the request as the model sees it, with any images attached.
func userTurn(message string, attachments []Attachment) llm.Message {
	if len(attachments) == 0 {
		return llm.Message{Role: "user", Content: message}
	}
	parts := []any{map[string]any{"type": "text", "text": message}}
	for _, a := range attachments {
		if (a.Type != "image" && a.Type != "video") || a.Path == "" {
			continue
		}
		data, err := os.ReadFile(a.Path)
		if err != nil {
			continue
		}
		mime := "image/jpeg"
		switch {
		case strings.HasSuffix(a.Path, ".png"):
			mime = "image/png"
		case strings.HasSuffix(a.Path, ".gif"):
			mime = "image/gif"
		}
		parts = append(parts, map[string]any{"type": "image_url", "image_url": map[string]any{"url": "data:" + mime + ";base64," + base64.StdEncoding.EncodeToString(data)}})
	}
	if len(parts) == 1 {
		return llm.Message{Role: "user", Content: message}
	}
	return llm.Message{Role: "user", Content: parts}
}

// openTasksNote is implemented with agent tasks.

// assembleContext builds what the model sees on its first turn, in the order
// that keeps the most of it cacheable: stable policy, per-run state, the tool
// catalog, history, the memory relevant to this request, and the request.
func (e *Engine) assembleContext(ctx context.Context, r *Run, s *ai.Session, settings dyn.Map, sections ai.PromptSections, startedAt time.Time, providerMs int64, recall <-chan string) {
	o := r.Options
	r.journal.Phase("context", "Gathering context")
	window := o.HistoryWindow
	if window <= 0 {
		window, _ = dyn.Int(settings["chat_history_window"])
	}
	if window <= 0 {
		window = 20
	}

	builtIn := e.deps.Tools.Available(ctx, CatalogRequest{UserID: r.UserID, AgentID: r.AgentID, TriggerType: r.TriggerType, TriggerSource: r.TriggerSource, Public: r.Public})
	var external []tools.Definition
	if r.Public == nil {
		external = e.deps.Tools.External(ctx, r.UserID, r.AgentID)
	}
	registry := e.deps.Tools.Registry()
	var all []tools.Definition
	for _, t := range append(builtIn, external...) {
		if contains(o.DisallowedToolNames, t.Name) {
			continue
		}
		if o.AllowedToolNames != nil && !contains(o.AllowedToolNames, t.Name) && t.Name != "task_ledger" {
			continue
		}
		if o.ReadOnly && t.Name != "task_ledger" && !tools.IsReadOnlyCall(registry.Meta(t.Name, &t), nil) {
			continue
		}
		all = append(all, t)
	}

	recalled := ""
	if recall != nil {
		recalled = <-recall
	}

	var summary string
	var stored []llm.Message
	takePrior := func() []llm.Message {
		prior := o.PriorMessages
		if len(prior) > window {
			prior = prior[len(prior)-window:]
		}
		var out []llm.Message
		for _, m := range prior {
			if m.Role != "" && dyn.Truthy(m.Content) {
				out = append(out, m)
			}
		}
		return out
	}
	if r.ConversationID != "" && !o.SkipConversationHistory {
		summary, stored = e.conversationContext(ctx, r.ConversationID, window)
		if summary == "" {
			summary = o.PriorSummary
		}
		if len(stored) == 0 {
			stored = takePrior()
		}
	} else {
		summary, stored = o.PriorSummary, takePrior()
	}
	budget := ai.ContextBudgetFor(s.Model.Provider.ContextWindow(s.Model.Model), o.MaxTokens)
	history, dropped := fitHistory(stored, int(math.Floor(float64(budget.InputBudget)*historyBudgetShare)))
	overBudget := memoryTokens(recalled) > max(120, int(math.Floor(float64(budget.InputBudget)*memoryBudgetShare)))
	if overBudget {
		recalled = ""
	}

	var runtimeStatus *llm.Message
	if r.Public == nil {
		capability := ""
		if e.deps.Health != nil {
			platform := ""
			if r.TriggerSource == "messaging" {
				platform = o.Source
			}
			capability = e.deps.Health.Summary(ctx, r.UserID, r.AgentID, r.TriggerSource, platform, r.DeviceTarget)
		}
		connected := ""
		if e.deps.Integrations != nil {
			connected = e.deps.Integrations.ConnectedProviderLabels(ctx, r.UserID, r.AgentID)
		}
		if capability != "" || connected != "" {
			lines := []string{"[Runtime status]"}
			if connected != "" {
				lines = append(lines, "Connected integrations: "+connected+". search_tools returns their tools with usage notes.")
			}
			if capability != "" {
				lines = append(lines, "Needs attention:\n"+capability)
			}
			runtimeStatus = &llm.Message{Role: "system", Content: strings.Join(lines, "\n")}
		}
	}
	var background []BackgroundRun
	if r.BackgroundEligible {
		background = e.ListBackgroundRuns(r.UserID, r.AgentID, r.ID, false)
	}

	request := o.Context.RawUserMessage
	if request == "" {
		request = s.UserMessage
	}
	var preferred []string
	for _, name := range []string{"neorecall_list_daily_summaries", "neorecall_search", "neorecall_list_conversations"} {
		if containsTool(all, name) {
			preferred = append(preferred, name)
		}
	}
	if len(background) > 0 {
		preferred = append(preferred, "background_task")
	}
	sel := selector{registry}
	selectStarted := time.Now()
	retrieved := e.retrieveTools(ctx, registry, all, request, r.UserID, r.AgentID)
	active, candidates := sel.selectCandidates(all, request, e.recentConversationTools(ctx, r.ConversationID, r.ID), preferred, retrieved)
	selection := map[string]Candidate{}
	candidatePayload := make([]map[string]any, len(candidates))
	for i, c := range candidates {
		c.Rank = i + 1
		selection[c.Name] = c
		entry := map[string]any{"name": c.Name, "rank": c.Rank, "source": c.Source, "score": c.Score}
		if c.Similarity != nil {
			entry["similarity"] = *c.Similarity
		}
		candidatePayload[i] = entry
	}
	r.mu.Lock()
	r.toolCatalog, r.activeTools, r.selection = all, active, selection
	r.mu.Unlock()
	s.Tools, s.Catalog = active, all
	unknown := 0
	for i := range all {
		if !registry.Meta(all[i].Name, &all[i]).Known {
			unknown++
		}
	}
	e.RecordEvent(r.UserID, r.ID, r.AgentID, runledger.EventToolsSelected, map[string]any{
		"kind": "initial", "duration_ms": time.Since(selectStarted).Milliseconds(), "retrieval_ms": 0,
		"selection": map[string]any{"catalog_size": len(registry.StaticNames()) + unknown, "eligible_count": len(all), "candidate_count": len(candidates),
			"active_count": len(active), "schema_limit": maxTools},
		"candidates": candidatePayload,
	})

	discovery := []string{"[Tool discovery]"}
	if summary := sel.discoverySummary(all, active); summary != "" {
		discovery = append(discovery, summary)
	}
	discovery = append(discovery, prompts.Render("runtime/tool_discovery.md", nil))
	if notes := e.DescribeIntegrations(r.ID, active); notes != "" {
		discovery = append(discovery, notes)
	}
	discoveryNote := llm.Message{Role: "system", Content: strings.Join(discovery, "\n")}

	var messages []llm.Message
	systemCount := 0
	if sections.Stable != "" {
		messages = append(messages, llm.Message{Role: "system", Content: sections.Stable})
		systemCount++
	}
	if sections.Dynamic != "" {
		messages = append(messages, llm.Message{Role: "system", Content: sections.Dynamic})
		systemCount++
	}
	notes := []llm.Message{discoveryNote}
	if runtimeStatus != nil {
		notes = append(notes, *runtimeStatus)
	}
	if note := backgroundRunsNote(background); note != "" {
		notes = append(notes, llm.Message{Role: "system", Content: note})
	}
	tasksNote := e.openTasksNote(ctx, r.UserID, r.AgentID, r.ID)
	if tasksNote != "" {
		notes = append(notes, llm.Message{Role: "system", Content: tasksNote})
	}
	messages = append(messages, notes...)
	if carrier := ai.SummaryCarrier(summary); carrier != nil {
		messages = append(messages, *carrier)
	}
	messages = append(messages, history...)
	if recalled != "" {
		messages = append(messages, llm.Message{Role: "system", Content: recalled})
	}
	turn := userTurn(s.UserMessage, o.MediaAttachments)
	messages = append(messages, turn)
	r.requestTurn = &turn
	s.Messages = ai.SanitizeConversationMessages(messages)

	// The trust record reads only what the owner wrote: the tool catalog and the
	// agents' task notes are third-party or harness text.
	var trustMessages []llm.Message
	for _, m := range messages {
		if text, _ := m.Content.(string); m.Role == "system" && (text == discoveryNote.Content || (tasksNote != "" && text == tasksNote)) {
			continue
		}
		trustMessages = append(trustMessages, m)
	}
	trust := o.ParentTrust
	if trust == nil {
		audience := o.Audience
		if r.Public != nil {
			audience = "public"
		}
		var origin *TrustOrigin
		if r.TriggerSource == "messaging" {
			origin = &TrustOrigin{Platform: o.Source, ChatID: o.ChatID}
			if social := o.Context.Social; social != nil {
				origin.IsGroup = social.IsGroup
				if social.Message != nil {
					origin.SenderID = social.Message.Sender
				}
			}
		}
		var media []string
		for _, a := range o.MediaAttachments {
			media = append(media, a.Path)
		}
		trust = NewTrust(audience, r.Public == nil && o.ApprovedSpeaker, r.TriggerSource, trustMessages, origin, media)
	}
	r.mu.Lock()
	r.trust = trust
	r.mu.Unlock()

	metrics := estimatePromptMetrics(s.Messages, s.LLMTools())
	var version any
	if sections.PromptVersion.Digest != "" {
		version = sections.PromptVersion.Digest
		e.PersistMetadata(r.ID, map[string]any{"promptVersion": sections.PromptVersion})
	}
	e.RecordEvent(r.UserID, r.ID, r.AgentID, runledger.EventContextBuilt, map[string]any{
		"startup_ms": time.Since(startedAt).Milliseconds(), "provider_ms": providerMs, "prompt_version": version,
		"sections": map[string]any{"system_tokens": metrics.System, "tool_schema_tokens": metrics.ToolSchema, "tool_catalog_tokens": metrics.ToolCatalog,
			"history_tokens": metrics.History, "memory_tokens": metrics.Memory, "runtime_note_tokens": metrics.RuntimeNotes, "total_tokens": metrics.Total},
		"budget": map[string]any{"input_tokens": budget.InputBudget, "history_messages": len(history), "history_dropped": dropped, "memory_over_budget": overBudget},
	})
	_ = systemCount
}

func containsTool(list []tools.Definition, name string) bool {
	for _, t := range list {
		if t.Name == name {
			return true
		}
	}
	return false
}
