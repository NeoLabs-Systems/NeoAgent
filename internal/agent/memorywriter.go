package agent

import (
	"context"
	"database/sql"
	"encoding/json"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// The background writer of long-term memory after a run answered: the thread's
// working state, and the durable facts it stated. Run receipts stay in
// agent_runs; memory only gets facts.

var conversationStateSchema = dyn.Ordered{
	{Key: "summary", Value: ""},
	{Key: "open_commitments", Value: []any{}},
	{Key: "unresolved_questions", Value: []any{}},
	{Key: "referenced_entities", Value: []any{}},
	{Key: "last_verified_facts", Value: []any{}},
	{Key: "memory_candidates", Value: []any{dyn.Ordered{
		{Key: "memory", Value: "Concise standalone fact for future context."},
		{Key: "subject", Value: "Canonical entity or person."},
		{Key: "predicate", Value: "Normalized relationship or attribute."},
		{Key: "object", Value: "Current atomic value."},
		{Key: "relation", Value: "new | updates | extends | derives"},
		{Key: "category", Value: "identity | preferences | projects | contacts | events | tasks | episodic | assistant_self"},
		{Key: "confidence", Value: 0.9},
		{Key: "importance", Value: 7},
		{Key: "is_static", Value: false},
		{Key: "valid_from", Value: nil},
		{Key: "valid_to", Value: nil},
		{Key: "forget_after", Value: nil},
		{Key: "evidence", Value: "The exact words from the thread that state it."},
	}}},
}

// runToolEvidence is what the run's tools returned, to check claims against.
// Memory tools are left out: finding a fact in memory proves nothing new.
func (e *Engine) runToolEvidence(ctx context.Context, runID string) ([]any, bool) {
	rows, err := e.deps.DB.R.QueryContext(ctx, `SELECT tool_name, result FROM agent_steps WHERE run_id = ? AND status = 'completed' AND result IS NOT NULL ORDER BY step_index DESC LIMIT 40`, runID)
	if err != nil {
		return nil, false
	}
	defer rows.Close()
	registry := e.deps.Tools.Registry()
	var results []any
	tainted := false
	for rows.Next() {
		var name, result sql.NullString
		if rows.Scan(&name, &result) != nil {
			continue
		}
		meta := registry.Meta(name.String, nil)
		if meta.Group == "memory" {
			continue
		}
		results = append(results, result.String)
		tainted = tainted || meta.Untrusted
	}
	return results, tainted
}

func stringList(v any, limit int) []any {
	out := []any{}
	for _, item := range dyn.List(v) {
		if len(out) >= limit {
			break
		}
		text := ""
		if item != nil {
			text = strings.TrimSpace(dyn.String(item))
		}
		if text != "" {
			out = append(out, text)
		}
	}
	return out
}

func (e *Engine) refreshConversationState(ctx context.Context, r *Run, model ai.ModelHandle, finalReply string, window int) error {
	if r.ConversationID == "" || model.Provider == nil {
		return nil
	}
	o := r.Options
	summary, messages := e.conversationContext(ctx, r.ConversationID, max(window, 8))
	existing, _ := e.deps.Memory.ConversationState(ctx, r.ConversationID)
	thread := messages
	if len(thread) > 8 {
		thread = thread[len(thread)-8:]
	}
	results, toolsTainted := e.runToolEvidence(ctx, r.ID)
	var userText []string
	var memMessages []memory.Message
	for _, m := range thread {
		text := dyn.Str(m.Content)
		memMessages = append(memMessages, memory.Message{Role: m.Role, Content: text})
		if m.Role == "user" {
			userText = append(userText, text)
		}
	}
	known, _ := e.deps.Memory.KnownFacts(ctx, r.UserID, r.AgentID, strings.Join(userText, "\n"), 0)

	shared := o.MemoryAudience == "shared"
	instructions := []string{
		"Return JSON only. Distill the current thread working state. Keep it concise and concrete.",
		"Track summary, open_commitments, unresolved_questions, referenced_entities, and last_verified_facts. Do not invent facts.",
	}
	room := ""
	if shared {
		parts := []string{"This is a shared room. Extract only durable room or participant facts that are safe and useful in engine room.",
			"Do not infer or store facts about the authenticated owner from another participant’s message."}
		if social := o.Context.Social; social != nil && social.Message != nil && social.Message.Sender != "" {
			parts = append(parts, `For facts about the current speaker, use the canonical subject "`+o.Source+":"+social.Message.Sender+`".`)
		}
		room = strings.Join(parts, " ")
	}
	instructions = append(instructions, room, memory.ConsolidationInstructions(isoNow()), "Schema:", dyn.StringifyIndent(conversationStateSchema))

	existingText := "Existing state: none"
	if existing != nil && existing.String("summary") != "" {
		existingText = "Existing state:\n" + jsx.MarshalIndent(existing)
	}
	summaryText := "Conversation summary: none"
	if summary != "" {
		summaryText = "Conversation summary:\n" + summary
	}
	knownText := "Known facts: none found"
	if len(known) > 0 {
		lines := make([]string, len(known))
		for i, f := range known {
			lines[i] = "- " + f.Subject + " | " + f.Predicate + " | " + f.Object
		}
		knownText = "Known facts:\n" + strings.Join(lines, "\n")
	}
	threadJSON, _ := json.MarshalIndent(thread, "", "  ")
	reply := finalReply
	if reply == "" {
		reply = "(empty)"
	}
	prompt := []llm.Message{
		{Role: "system", Content: strings.Join(instructions, "\n\n")},
		{Role: "user", Content: strings.Join([]string{existingText, summaryText, knownText, "Recent thread messages:\n" + string(threadJSON), "Latest final reply:\n" + reply}, "\n\n")},
	}
	started := time.Now()
	callCtx, cancel := context.WithTimeout(ctx, modelCallTimeout)
	defer cancel()
	provider := model.Provider
	if m, ok := provider.(*meteredProvider); ok {
		provider = m.Provider
	}
	res, err := provider.Chat(callCtx, prompt, nil, llm.Options{Model: model.Model, MaxTokens: 800, ReasoningEffort: e.reasoningEffort(o)})
	if err != nil {
		return err
	}
	_, _ = aimodels.RecordUsage(ctx, e.deps.DB, aimodels.UsageRecord{RunID: r.ID, UserID: r.UserID, AgentID: r.AgentID, Provider: model.ProviderName,
		Model: model.Model, Phase: "memory_extraction", Usage: aimodels.FromLLM(res.Usage), LatencyMs: time.Since(started).Milliseconds()})
	parsed := extractJSONObject(res.Content)
	if parsed == nil {
		parsed = map[string]any{}
	}
	nextSummary := strings.TrimSpace(dyn.String(parsed["summary"]))
	if nextSummary == "" && existing != nil {
		nextSummary = strings.TrimSpace(existing.String("summary"))
	}
	var statements []string
	for _, s := range stringList(parsed["last_verified_facts"], 10) {
		statements = append(statements, s.(string))
	}
	verified := []any{}
	for _, s := range memory.KeepSupportedStatements(statements, memMessages) {
		verified = append(verified, s)
	}
	state := jsx.O("summary", nextSummary, "open_commitments", stringList(parsed["open_commitments"], 8), "unresolved_questions", stringList(parsed["unresolved_questions"], 8),
		"referenced_entities", stringList(parsed["referenced_entities"], 12), "last_verified_facts", verified)
	if err := e.deps.Memory.UpdateConversationState(ctx, r.ConversationID, state); err != nil {
		return err
	}
	grounded, dropped := memory.GroundMemoryCandidates(memory.NormalizeCandidates(toJSX(parsed).Value("memory_candidates"), 0), memMessages, results)
	outside := NewTrust(orText(o.Audience, "owner"), false, r.TriggerSource, nil, nil, nil).Tainted()
	for _, g := range grounded {
		trust := g.TrustLevel
		switch {
		case trust == "model_inference":
		case shared:
			trust = "shared_room_conversation"
		case outside:
			trust = "external_source"
		case trust == "tool_observed" && toolsTainted:
			trust = "external_source"
		}
		meta := jsx.O("trustLevel", trust)
		if shared {
			meta.Set("platform", nullString(o.Source)).Set("chatId", nullString(o.ChatID))
		}
		if _, err := e.deps.Memory.ConsolidateMemoryCandidates(ctx, r.UserID, []memory.Candidate{g.Candidate},
			memory.ConsolidateOptions{AgentID: r.AgentID, ConversationID: r.ConversationID, RunID: r.ID, Metadata: meta}); err != nil {
			return err
		}
	}
	if len(grounded) > 0 || dropped > 0 {
		e.RecordEvent(r.UserID, r.ID, r.AgentID, runledger.EventMemoryWrite, map[string]any{"count": len(grounded), "dropped": dropped, "source": "conversation_state"})
	}
	if len(grounded) > 0 && e.deps.Prompts != nil {
		e.deps.Prompts.Invalidate(r.UserID, r.AgentID)
	}
	return nil
}
