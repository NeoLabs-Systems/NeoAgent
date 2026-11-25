package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"iter"
	"math"
	"sort"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

const (
	modelCallTimeout  = 5 * time.Minute
	streamIdleTimeout = 2 * time.Minute
	// A progress line is trimmed to 400 characters after the call; there is no
	// reason to let the model write more than that.
	narrationMaxTokens = 300
)

// meteredProvider is a run's model client: every call is recorded in the usage
// ledger and the run ledger, transient failures retry on the same model, a
// stream that goes silent is cut off, and runaway tool-call arguments come
// back as a discarded call the model can retry with the failure in view.
type meteredProvider struct {
	llm.Provider
	e            *Engine
	r            *Run
	providerName string
	retry        llm.RetryPolicy
	// phase names calls made through Chat when the caller did not.
	chatPhase string
}

func (e *Engine) meter(r *Run, provider llm.Provider, providerName string) llm.Provider {
	if provider == nil {
		return nil
	}
	if m, ok := provider.(*meteredProvider); ok {
		provider = m.Provider
	}
	return &meteredProvider{Provider: provider, e: e, r: r, providerName: providerName, retry: llm.RetryPolicyFromEnv(e.deps.Getenv), chatPhase: "wrap_up"}
}

func (m *meteredProvider) callTimeout() time.Duration {
	if t := m.r.Options.ModelCallTimeout; t > 0 {
		return t
	}
	if raw := strings.TrimSpace(m.e.deps.Getenv("NEOAGENT_MODEL_CALL_TIMEOUT_MS")); raw != "" {
		var ms float64
		if _, err := fmt.Sscan(raw, &ms); err == nil && ms > 0 {
			return time.Duration(math.Max(10, ms)) * time.Millisecond
		}
	}
	return modelCallTimeout
}

func sortedTools(list []llm.Tool) []llm.Tool {
	out := append([]llm.Tool(nil), list...)
	sort.SliceStable(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}

func (m *meteredProvider) options(opt llm.Options) llm.Options {
	extra := map[string]any{}
	for k, v := range opt.Extra {
		if k != "phase" {
			extra[k] = v
		}
	}
	if _, ok := extra["sessionId"]; !ok {
		session := m.r.ConversationID
		if session == "" {
			session = m.r.ID
		}
		extra["sessionId"] = session
	}
	opt.Extra = extra
	return opt
}

func phaseOf(opt llm.Options, fallback string) string {
	if p, _ := opt.Extra["phase"].(string); p != "" {
		return p
	}
	return fallback
}

func classifyModelError(err error) string {
	if e := llm.AsError(err); e != nil {
		switch {
		case e.Code == "MODEL_CALL_TIMEOUT":
			return "timeout"
		case e.Status == 429:
			return "rate_limited"
		case e.Status >= 500:
			return "provider_unavailable"
		case e.Status == 401 || e.Status == 403:
			return "auth"
		case e.Status == 400:
			return "bad_request"
		case e.Code != "":
			return strings.ToLower(e.Code)
		}
	}
	return "unknown"
}

func usagePayload(u *llm.Usage) any {
	norm := aimodels.FromLLM(u)
	if norm == nil {
		return nil
	}
	return map[string]any{"input_tokens": norm.InputTokens, "output_tokens": norm.OutputTokens, "reasoning_tokens": norm.ReasoningTokens,
		"cached_read_tokens": norm.CachedReadTokens, "cache_write_tokens": norm.CacheWriteTokens}
}

func (m *meteredProvider) recordRequest(phase string, iteration int, model string, messages []llm.Message, list []llm.Tool) {
	metrics := estimatePromptMetrics(messages, list)
	if phase == "model_turn" {
		m.r.mergePromptMetrics(metrics, iteration, len(list))
	}
	requestID := m.e.captureRequest(m.r, phase, iteration, m.providerName, model, 0, "", messages, list)
	m.e.ledger.Record(runledger.Event{RunID: m.r.ID, UserID: m.r.UserID, AgentID: m.r.AgentID, Type: runledger.EventModelRequest, RequestID: requestID,
		Payload: map[string]any{
			"phase": phase, "iteration": iteration, "model": map[string]any{"provider": m.providerName, "model": model},
			"context": map[string]any{
				"estimated_tokens": metrics.Total, "system_tokens": metrics.System, "tool_schema_tokens": metrics.ToolSchema,
				"tool_catalog_tokens": metrics.ToolCatalog, "history_tokens": metrics.History, "memory_tokens": metrics.Memory,
				"runtime_note_tokens": metrics.RuntimeNotes, "tool_replay_tokens": metrics.ToolReplay, "active_tool_count": len(list),
			},
			"privacy": map[string]any{"content_stored": requestID != "", "redaction_policy": "metadata-default"},
		}})
}

func (m *meteredProvider) recordResponse(phase string, iteration int, model string, started time.Time, res *llm.Result, retries int, err error) {
	ctx := context.Background()
	payload := map[string]any{"phase": phase, "iteration": iteration, "model": map[string]any{"provider": m.providerName, "model": model},
		"duration_ms": time.Since(started).Milliseconds(), "retry_count": retries}
	if err != nil {
		payload["outcome"] = map[string]any{"status": "failed", "error_class": classifyModelError(err)}
		m.e.ledger.Record(runledger.Event{RunID: m.r.ID, UserID: m.r.UserID, AgentID: m.r.AgentID, Type: runledger.EventModelResponse, Payload: payload})
		return
	}
	_, _ = aimodels.RecordUsage(ctx, m.e.deps.DB, aimodels.UsageRecord{RunID: m.r.ID, UserID: m.r.UserID, AgentID: m.r.AgentID, Provider: m.providerName,
		Model: model, Phase: phase, Usage: aimodels.FromLLM(res.Usage), LatencyMs: time.Since(started).Milliseconds(), Metadata: map[string]any{"iteration": iteration}})
	if res.Model != "" && res.Model != model {
		payload["served_model"] = res.Model
	}
	names := []string{}
	for _, c := range res.ToolCalls {
		if c.Function.Name != "" {
			names = append(names, c.Function.Name)
		}
	}
	var finish any
	if res.FinishReason != "" {
		finish = res.FinishReason
	}
	payload["usage"] = usagePayload(res.Usage)
	payload["finish_reason"] = finish
	payload["truncated"] = res.Truncated
	payload["tool_call_names"] = names
	payload["outcome"] = map[string]any{"status": "success", "retry_count": retries}
	if stored := m.e.ledger.Record(runledger.Event{RunID: m.r.ID, UserID: m.r.UserID, AgentID: m.r.AgentID, Type: runledger.EventModelResponse, Payload: payload}); stored != nil {
		m.r.mu.Lock()
		m.r.modelEventID = stored.EventID
		m.r.mu.Unlock()
	}
}

func (m *meteredProvider) retryable(ctx context.Context, err error) bool {
	if ctx.Err() != nil {
		return false
	}
	if e := llm.AsError(err); e != nil && e.Code == "MODEL_CALL_TIMEOUT" {
		return false
	}
	return llm.IsTransient(err)
}

func (m *meteredProvider) announceRetry(info llm.RetryInfo, iteration int, stream bool) {
	if stream {
		m.e.Emit(m.r.UserID, "run:stream", map[string]any{"runId": m.r.ID, "content": "", "iteration": iteration})
	}
	m.e.Emit(m.r.UserID, "run:interim", map[string]any{"runId": m.r.ID,
		"message": fmt.Sprintf("Model service busy; retrying (attempt %d) in %ds.", info.Attempt, max(1, int(math.Round(info.Delay.Seconds())))),
		"phase":   "recovering"})
}

// discardedCall turns arguments that ran away into that same call with them
// discarded: the tool rejects it with the reason, and the model's next turn is
// the retry, with the failure in context.
func discardedCall(err *llm.DegenerateOutputError, list []llm.Tool, iteration int) llm.Event {
	var declared []string
	for _, t := range list {
		if t.Name == err.ToolName {
			props := dyn.Obj(t.Parameters["properties"])
			declared = dyn.SortedKeys(props)
			if ordered, ok := t.Parameters["properties"].(map[string]any); ok && len(ordered) == len(declared) {
				declared = dyn.SortedKeys(ordered)
			}
		}
	}
	why := fmt.Sprintf("The arguments streamed for this call degenerated into %s after %d bytes and were discarded. Resend the call with complete, well-formed arguments.",
		strings.ReplaceAll(err.Reason, "_", " "), err.OutputBytes)
	if err.ArgumentKey != "" && len(declared) > 0 {
		why = fmt.Sprintf("%s has no argument \"%s\"; its arguments are %s. The call was discarded; send it again with those names.", err.ToolName, err.ArgumentKey, strings.Join(declared, ", "))
	}
	args, _ := json.Marshal(map[string]any{"_discarded": why})
	return llm.Event{Type: llm.EventToolCalls, FinishReason: "tool_calls", ToolCalls: []llm.ToolCall{{
		ID: fmt.Sprintf("discarded_%d", iteration), Type: "function", Function: llm.FunctionCall{Name: err.ToolName, Arguments: string(args)},
	}}}
}

func (m *meteredProvider) iteration() int {
	m.r.mu.Lock()
	defer m.r.mu.Unlock()
	if m.r.session != nil {
		return m.r.session.Iterations
	}
	return 0
}

// Stream is a loop turn.
func (m *meteredProvider) Stream(ctx context.Context, msgs []llm.Message, list []llm.Tool, opt llm.Options) iter.Seq2[llm.Event, error] {
	return func(yield func(llm.Event, error) bool) {
		phase := phaseOf(opt, "model_turn")
		iteration := m.iteration()
		list = sortedTools(list)
		opt = m.options(opt)
		started := time.Now()
		m.recordRequest(phase, iteration, opt.Model, msgs, list)
		idle := min(m.callTimeout(), streamIdleTimeout)
		retries := 0
		for attempt := 1; ; attempt++ {
			final, emitted, err := m.streamOnce(ctx, msgs, list, opt, idle, iteration, yield)
			if err == nil {
				if final == nil {
					return // the consumer stopped
				}
				res := &llm.Result{Content: final.Content, ToolCalls: final.ToolCalls, FinishReason: final.FinishReason, Truncated: final.Truncated,
					Usage: final.Usage, Model: final.Model, ReasoningState: final.ReasoningState}
				m.recordResponse(phase, iteration, opt.Model, started, res, retries, nil)
				yield(*final, nil)
				return
			}
			// A retry after text reached the transcript would repeat it.
			if !emitted && attempt < max(1, m.retry.MaxAttempts) && m.retryable(ctx, err) {
				wait := llm.BackoffDelay(attempt, m.retry.BaseDelay, m.retry.MaxDelay)
				if e := llm.AsError(err); e != nil && e.RetryAfter > 0 {
					if e.RetryAfter > m.retry.MaxRetryAfter {
						m.recordResponse(phase, iteration, opt.Model, started, nil, retries, err)
						yield(llm.Event{}, err)
						return
					}
					wait = e.RetryAfter
				}
				retries = attempt
				m.announceRetry(llm.RetryInfo{Attempt: attempt, Delay: wait, Err: err}, iteration, true)
				timer := time.NewTimer(wait)
				select {
				case <-ctx.Done():
					timer.Stop()
					m.recordResponse(phase, iteration, opt.Model, started, nil, retries, ctx.Err())
					yield(llm.Event{}, ctx.Err())
					return
				case <-timer.C:
				}
				continue
			}
			m.recordResponse(phase, iteration, opt.Model, started, nil, retries, err)
			yield(llm.Event{}, err)
			return
		}
	}
}

// streamOnce runs one streamed request, passing content deltas on and returning
// the final event.
func (m *meteredProvider) streamOnce(ctx context.Context, msgs []llm.Message, list []llm.Tool, opt llm.Options, idle time.Duration, iteration int,
	yield func(llm.Event, error) bool) (*llm.Event, bool, error) {
	callCtx, cancel := context.WithCancelCause(ctx)
	defer cancel(nil)
	timeoutErr := &llm.Error{Provider: m.providerName, Code: "MODEL_CALL_TIMEOUT", Message: fmt.Sprintf("Model stream iteration %d timed out after %s.", iteration, formatElapsed(idle))}
	timer := time.AfterFunc(idle, func() { cancel(timeoutErr) })
	defer timer.Stop()
	var content strings.Builder
	emitted := false
	for event, err := range m.Provider.Stream(callCtx, msgs, list, opt) {
		timer.Reset(idle)
		if err != nil {
			if degenerate, ok := llm.AsDegenerateOutput(err); ok && degenerate.ToolName != "" {
				final := discardedCall(degenerate, list, iteration)
				return &final, emitted, nil
			}
			if cause := context.Cause(callCtx); cause != nil && ctx.Err() == nil {
				return nil, emitted, cause
			}
			return nil, emitted, err
		}
		switch event.Type {
		case llm.EventContent:
			content.WriteString(event.Content)
			emitted = true
			if !yield(event, nil) {
				return nil, emitted, nil
			}
		case llm.EventToolCalls, llm.EventDone:
			e := event
			if e.Content == "" {
				e.Content = content.String()
			}
			return &e, emitted, nil
		}
	}
	if cause := context.Cause(callCtx); cause != nil && ctx.Err() == nil {
		return nil, emitted, cause
	}
	if err := ctx.Err(); err != nil {
		return nil, emitted, err
	}
	final := llm.Event{Type: llm.EventDone, Content: content.String(), FinishReason: "stop"}
	return &final, emitted, nil
}

// Chat is a side call (wrap-up, compaction, narration, structured answers).
func (m *meteredProvider) Chat(ctx context.Context, msgs []llm.Message, list []llm.Tool, opt llm.Options) (*llm.Result, error) {
	phase := phaseOf(opt, m.chatPhase)
	iteration := m.iteration()
	list = sortedTools(list)
	opt = m.options(opt)
	started := time.Now()
	m.recordRequest(phase, iteration, opt.Model, msgs, list)
	retries := 0
	policy := m.retry
	policy.IsRetryable = func(err error) bool { return m.retryable(ctx, err) }
	policy.OnRetry = func(info llm.RetryInfo) {
		retries = info.Attempt
		m.announceRetry(info, iteration, false)
	}
	timeout := m.callTimeout()
	res, err := llm.Retry(ctx, policy, func(int) (*llm.Result, error) {
		callCtx, cancel := context.WithCancelCause(ctx)
		defer cancel(nil)
		timer := time.AfterFunc(timeout, func() {
			cancel(&llm.Error{Provider: m.providerName, Code: "MODEL_CALL_TIMEOUT", Message: fmt.Sprintf("%s model call timed out after %s.", phase, formatElapsed(timeout))})
		})
		defer timer.Stop()
		out, err := m.Provider.Chat(callCtx, msgs, list, opt)
		if err != nil {
			if cause := context.Cause(callCtx); cause != nil && ctx.Err() == nil {
				return nil, cause
			}
		}
		return out, err
	})
	m.recordResponse(phase, iteration, opt.Model, started, res, retries, err)
	return res, err
}

func formatElapsed(d time.Duration) string {
	total := max(1, int(d.Seconds()))
	if total < 60 {
		return fmt.Sprintf("%ds", total)
	}
	minutes, seconds := total/60, total%60
	if seconds == 0 {
		return fmt.Sprintf("%dm", minutes)
	}
	return fmt.Sprintf("%dm %ds", minutes, seconds)
}

// promptMetrics is where a request's context goes: estimates for comparing
// harness changes, not billing.
type promptMetrics struct {
	System, ToolSchema, ToolCatalog, History, Memory, RuntimeNotes, ToolReplay, Total int
}

func estimatePromptMetrics(messages []llm.Message, list []llm.Tool) promptMetrics {
	m := promptMetrics{ToolSchema: ai.EstimateTokenCount(nil, list)}
	for i, msg := range messages {
		tokens := ai.EstimateMessageTokens(msg)
		switch {
		case msg.Role == "tool":
			m.ToolReplay += tokens
		case msg.Role == "system":
			text, _ := msg.Content.(string)
			switch {
			case strings.HasPrefix(text, "[Recalled context"):
				m.Memory += tokens
			case strings.HasPrefix(text, "[Tool discovery]"):
				m.ToolCatalog += tokens
			case strings.HasPrefix(text, ai.SummaryPrefix):
				m.History += tokens
			case i <= 1:
				m.System += tokens
			default:
				m.RuntimeNotes += tokens
			}
		default:
			m.History += tokens
		}
	}
	m.Total = m.System + m.ToolSchema + m.ToolCatalog + m.History + m.Memory + m.RuntimeNotes + m.ToolReplay
	return m
}

func (p promptMetrics) object() map[string]any {
	return map[string]any{"systemPromptTokens": p.System, "toolSchemaTokens": p.ToolSchema, "toolCatalogTokens": p.ToolCatalog,
		"historyTokens": p.History, "recalledMemoryTokens": p.Memory, "runtimeNoteTokens": p.RuntimeNotes, "toolReplayTokens": p.ToolReplay,
		"totalEstimatedTokens": p.Total}
}

func (r *Run) mergePromptMetrics(m promptMetrics, iteration, toolCount int) {
	r.mu.Lock()
	defer r.mu.Unlock()
	prev := r.promptMetrics
	get := func(k string) int {
		v, _ := dyn.Int(prev[k])
		return v
	}
	r.promptMetrics = map[string]any{
		"iterationsObserved":      max(get("iterationsObserved"), iteration),
		"toolCount":               toolCount,
		"maxEstimatedTokens":      max(get("maxEstimatedTokens"), m.Total),
		"maxSystemPromptTokens":   max(get("maxSystemPromptTokens"), m.System),
		"maxToolSchemaTokens":     max(get("maxToolSchemaTokens"), m.ToolSchema),
		"maxHistoryTokens":        max(get("maxHistoryTokens"), m.History),
		"maxRecalledMemoryTokens": max(get("maxRecalledMemoryTokens"), m.Memory),
		"maxToolReplayTokens":     max(get("maxToolReplayTokens"), m.ToolReplay),
		"lastEstimate":            m.object(),
	}
}

// StructuredRequest asks a model for a JSON object.
type StructuredRequest struct {
	UserID    int64
	AgentID   string
	ModelID   string
	Purpose   string
	System    string
	Prompt    string
	MaxTokens int
	RunID     string
	Phase     string
}

// StructuredAnswer is the model's JSON object and how it was produced.
type StructuredAnswer struct {
	Parsed           map[string]any
	OK               bool
	Raw              string
	Usage            int
	Model            string
	ModelSelectionID string
	ProviderName     string
}

// InferStructured asks a fast model for a JSON object, moving to a fallback
// model on failures.
func (e *Engine) InferStructured(ctx context.Context, req StructuredRequest) (StructuredAnswer, error) {
	if req.MaxTokens <= 0 {
		req.MaxTokens = 400
	}
	if req.Phase == "" {
		req.Phase = "behavior_inference"
	}
	purpose, cost := "fast", "economy"
	if req.Purpose == "general" {
		purpose, cost = "general", "balanced_auto"
	}
	failed := map[string]bool{}
	requested := req.ModelID
	var lastErr error
	for attempt := 0; attempt < 3; attempt++ {
		selected, err := e.selectModel(ctx, req.UserID, req.AgentID, false, requested, aimodels.Hint{Purpose: purpose, CostMode: cost}, nil)
		if err != nil {
			return StructuredAnswer{}, err
		}
		var messages []llm.Message
		if req.System != "" {
			messages = append(messages, llm.Message{Role: "system", Content: req.System})
		}
		messages = ai.SanitizeConversationMessages(append(messages, llm.Message{Role: "system", Content: req.Prompt}))
		provider := selected.Provider
		if r, ok := e.RunInfo(req.RunID); ok {
			provider = e.meter(r, provider, selected.ProviderName)
		}
		res, err := provider.Chat(ctx, messages, nil, llm.Options{Model: selected.Model, MaxTokens: req.MaxTokens, ReasoningEffort: e.reasoningEffort(Options{}),
			Extra: map[string]any{"structured": true, "phase": req.Phase}})
		if err == nil {
			e.deps.Failures.RecordSuccess(ctx, req.UserID, req.AgentID, selected.SelectionID)
			parsed := extractJSONObject(res.Content)
			norm := aimodels.FromLLM(res.Usage)
			total := 0
			if norm != nil {
				total = norm.TotalTokens
			}
			return StructuredAnswer{Parsed: parsed, OK: parsed != nil, Raw: res.Content, Usage: total, Model: selected.Model, ModelSelectionID: selected.SelectionID, ProviderName: selected.ProviderName}, nil
		}
		if ctx.Err() != nil {
			return StructuredAnswer{}, err
		}
		lastErr = err
		e.deps.Failures.RecordFailure(ctx, req.UserID, req.AgentID, selected.SelectionID, err)
		failed[selected.SelectionID] = true
		if attempt >= 2 {
			break
		}
		next, ferr := e.fallbackModelID(ctx, req.UserID, req.AgentID, selected.SelectionID, err, failed)
		if ferr != nil || next == "" {
			break
		}
		requested = next
	}
	return StructuredAnswer{}, lastErr
}

// extractJSONObject finds the first JSON object in model text.
func extractJSONObject(text string) map[string]any {
	text = strings.TrimSpace(text)
	if text == "" {
		return nil
	}
	var direct map[string]any
	if json.Unmarshal([]byte(text), &direct) == nil {
		return direct
	}
	for start := strings.Index(text, "{"); start >= 0; {
		depth, inString, escaped := 0, false, false
		for i := start; i < len(text); i++ {
			c := text[i]
			if inString {
				switch {
				case escaped:
					escaped = false
				case c == '\\':
					escaped = true
				case c == '"':
					inString = false
				}
				continue
			}
			switch c {
			case '"':
				inString = true
			case '{':
				depth++
			case '}':
				depth--
				if depth == 0 {
					var obj map[string]any
					if json.Unmarshal([]byte(text[start:i+1]), &obj) == nil {
						return obj
					}
					i = len(text)
				}
			}
		}
		next := strings.Index(text[start+1:], "{")
		if next < 0 {
			break
		}
		start += next + 1
	}
	return nil
}
