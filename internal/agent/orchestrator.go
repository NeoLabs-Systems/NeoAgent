package agent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/NeoLabs-Systems/neolabs-go/apperr"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// ErrRunIDConflict is a run id that already exists.
var errRunIDConflict = &codedError{code: "RUN_ID_CONFLICT", status: 409}

func runTitle(text string) string {
	text = strings.TrimSpace(whitespaceRun.ReplaceAllString(text, " "))
	if text == "" {
		return "Agent run"
	}
	if r := []rune(text); len(r) > 80 {
		return string(r[:77]) + "..."
	}
	return text
}

func publicErrorCode(err error) any {
	var coded interface{ Code() string }
	if errors.As(err, &coded) && coded.Code() != "" {
		return coded.Code()
	}
	if e, ok := apperr.As(err); ok && e.Code != "" {
		return e.Code
	}
	if e := llm.AsError(err); e != nil && e.Code != "" {
		return e.Code
	}
	return nil
}

// Run runs the agent for a request and returns when it has ended.
func (e *Engine) Run(ctx context.Context, userID int64, message string, o Options) (Result, error) {
	e.mu.Lock()
	if e.shuttingDown {
		e.mu.Unlock()
		return Result{}, ErrShuttingDown
	}
	e.work.Add(1)
	e.mu.Unlock()
	defer e.work.Done()
	if err := ctx.Err(); err != nil {
		return Result{}, err
	}
	return e.run(ctx, userID, message, o)
}

func (e *Engine) run(ctx context.Context, userID int64, message string, o Options) (Result, error) {
	if o.TriggerType == "" {
		o.TriggerType = "user"
	}
	if o.TriggerSource == "" {
		o.TriggerSource = "web"
	}
	agentID, err := e.deps.Agents.Resolve(ctx, userID, o.AgentID)
	if err != nil {
		return Result{}, err
	}
	o.AgentID = agentID
	settings := e.aiSettings(ctx, userID, agentID)
	runID := o.RunID
	if runID == "" {
		runID = uuid.NewString()
	}
	if o.DeviceTarget != "local" && o.DeviceTarget != "cloud" {
		o.DeviceTarget = ""
	}
	o.WorkspaceRoot = strings.TrimSpace(o.WorkspaceRoot)
	title := o.Title
	if title == "" {
		title = message
	}
	title = runTitle(title)
	startedAt := time.Now()
	workerID := "worker_" + uuid.NewString()

	// Usage limits do not apply to a run whose explicit model is the account's
	// own provider: only the account pays for those calls.
	byok := false
	requestedModel := o.Model
	if requestedModel == "" {
		requestedModel = dyn.Str(settings["default_chat_model"])
	}
	if sel, ok := aimodels.ParseSelectionID(requestedModel); ok {
		byok = e.deps.Models.IsBYOK(ctx, userID, agentID, sel.Provider)
	}
	release := func() {}
	if e.deps.RateLimits != nil {
		_, rel, err := e.deps.RateLimits.Enforce(ctx, userID, o.BypassUserRateLimits || byok)
		if err != nil {
			return Result{}, err
		}
		if rel != nil {
			release = rel
		}
	}
	defer release()

	metadata := map[string]any{"runtimeKernel": "v2"}
	if o.TaskID != 0 {
		metadata["taskId"] = o.TaskID
	}
	if o.SessionBinding != nil {
		metadata["sessionBinding"] = o.SessionBinding
	}
	if o.LatencyPriority != "" {
		metadata["latencyPriority"] = o.LatencyPriority
	}
	if o.ConversationID != "" {
		metadata["conversationId"] = o.ConversationID
	}
	if o.DeviceTarget != "" {
		metadata["deviceTarget"] = o.DeviceTarget
	}
	if resume := buildResumeEnvelope(message, o); resume != nil {
		metadata["resume"] = resume
	}
	if o.ResumedFromRunID != "" {
		metadata["resumedFromRunId"] = o.ResumedFromRunID
	}
	storedModel := o.Model
	if storedModel == "" {
		storedModel = dyn.Str(settings["default_chat_model"])
	}
	if storedModel == "" {
		storedModel = "auto"
	}
	metaJSON, _ := json.Marshal(metadata)
	if _, err := e.deps.DB.W.ExecContext(ctx, `INSERT INTO agent_runs (id, user_id, agent_id, title, status, runtime_state, version, trigger_type, trigger_source, model,
		metadata_json, conversation_id, device_target) VALUES (?, ?, ?, ?, 'running', ?, 0, ?, ?, ?, ?, ?, ?)`,
		runID, userID, agentID, title, runledger.StateAccepted, o.TriggerType, o.TriggerSource, storedModel, string(metaJSON), nullString(o.ConversationID), nullString(o.DeviceTarget)); err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "unique") || strings.Contains(strings.ToLower(err.Error()), "constraint") {
			return Result{}, &codedError{msg: fmt.Sprintf(`A run with id "%s" already exists.`, runID), code: "RUN_ID_CONFLICT", status: 409}
		}
		return Result{}, err
	}

	lease, err := e.ledger.Acquire(ctx, runID, workerID, 0)
	if err != nil || lease == nil {
		return Result{}, errors.New("Failed to acquire run lease")
	}

	delivery := o.Delivery
	if delivery == nil {
		delivery = &Delivery{}
	}
	scope := o.ResumedFromRunID
	if scope == "" {
		scope = runID
	}
	request := o.Context.RawUserMessage
	if request == "" {
		request = message
	}
	request = strings.TrimSpace(request)
	if r := []rune(request); len(r) > 600 {
		request = string(r[:600])
	}
	runCtx, runCancel := context.WithCancelCause(context.WithoutCancel(ctx))
	turnCtx, turnCancel := context.WithCancelCause(runCtx)
	r := &Run{
		ID: runID, AgentID: agentID, Title: title, UserID: userID, TriggerType: o.TriggerType, TriggerSource: o.TriggerSource,
		ConversationID: o.ConversationID, DeviceTarget: o.DeviceTarget, WorkspaceRoot: o.WorkspaceRoot,
		VoiceSessionID: o.VoiceSessionID, SessionBinding: o.SessionBinding, LatencyPriority: o.LatencyPriority,
		Request: request, DeliveryScopeID: scope, Delivery: delivery, Options: o, SubagentDepth: max(0, o.SubagentDepth),
		BackgroundEligible: backgroundEligible(o.TriggerType, o.TriggerSource, o.MemoryAudience), Public: o.Public,
		StartedAt: startedAt, WorkerID: workerID, Capture: e.decideCapture(ctx, userID, agentID, o.CaptureContent),
		Repetition: ai.NewToolRepetitionGuard(0, nil),
		status:     "running", pauseAvailable: true, runCtx: runCtx, runCancel: runCancel, turnCtx: turnCtx, turnCancel: turnCancel,
	}
	if r.VoiceSessionID == "" {
		r.VoiceSessionID = fmtAny(o.SessionBinding["sessionId"])
	}
	if o.TriggerSource == "messaging" {
		r.MessagingPlatform, r.MessagingChatID = o.Source, o.ChatID
		if o.Context.Social != nil {
			r.MessagingBehavior = o.Context.Social.Behavior
		}
	} else if deliveryChannel(o.TriggerSource) == "voice_live" {
		r.MessagingChatID = o.ChatID
	}
	r.journal = newJournal(e, r)
	e.mu.Lock()
	e.runs[runID] = r
	e.mu.Unlock()

	session := &ai.Session{RunID: runID, AgentID: agentID, UserMessage: message, UserID: userID, TriggerType: o.TriggerType, TriggerSource: o.TriggerSource,
		Guards: ai.NewRunGuards(settings, o.guardOptions()), Repetition: r.Repetition, Shaper: &ai.Shaper{Tools: e.deps.Tools.Registry()}, FailedModelIDs: map[string]bool{}}
	session.Goal = func() string { return r.taskGoal(session) }
	session.TaskStateLines = r.taskStateLines
	r.mu.Lock()
	r.session = session
	r.mu.Unlock()

	result, err := e.runLoop(ctx, r, session, settings, startedAt)

	// Only a run the shutdown cut off is resumed; one that ended while the
	// process keeps going is finished, however it ended.
	bg := context.Background()
	if !e.ShuttingDown() {
		e.clearResumeEnvelope(runID)
	}
	r.mu.Lock()
	metrics := r.promptMetrics
	r.mu.Unlock()
	if metrics != nil {
		encoded, _ := json.Marshal(metrics)
		e.execDB(bg, `UPDATE agent_runs SET prompt_metrics = ? WHERE id = ?`, string(encoded), runID)
	}
	e.ledger.PersistRunMetrics(bg, runID, e.toolGroup)
	e.ledger.Release(bg, runID, workerID)
	if b := e.broker(r); b != nil {
		b.halt()
	}
	e.mu.Lock()
	delete(e.runs, runID)
	e.mu.Unlock()
	runCancel(errors.New("run ended"))
	e.announceBackgroundEnded(r)
	e.onAgentTaskRunEnded(r)
	e.subagents.cleanupForRun(runID)
	if e.deps.RunEnded != nil {
		e.deps.RunEnded(runID)
	}
	return result, err
}

func (e *Engine) toolGroup(name string) string { return e.deps.Tools.Registry().Meta(name, nil).Group }

func (e *Engine) transition(r *Run, toState, reason string, patch runledger.Patch) runledger.TransitionResult {
	result, err := e.ledger.Transition(context.Background(), runledger.TransitionRequest{RunID: r.ID, ToState: toState, Reason: reason, WorkerID: r.WorkerID, Patch: patch, Publish: true})
	if err != nil || !result.OK {
		e.log.Warn("Run transition rejected", "run", r.ID, "to", toState, "reason", result.Reason, "error", err)
	}
	return result
}

func (e *Engine) runLoop(ctx context.Context, r *Run, s *ai.Session, settings dyn.Map, startedAt time.Time) (res Result, runErr error) {
	o := r.Options
	interruptedByCaller := false
	stopWatch := make(chan struct{})
	defer close(stopWatch)
	go func() {
		select {
		case <-ctx.Done():
			interruptedByCaller = true
			reason := "Agent run interrupted by its caller."
			if cause := context.Cause(ctx); cause != nil && cause != context.Canceled {
				reason = cause.Error()
			}
			e.InterruptRun(r.ID, reason)
		case <-stopWatch:
		}
	}()
	_ = interruptedByCaller
	defer func() {
		if runErr == nil {
			return
		}
		interrupted := r.Aborted() || errors.Is(runErr, context.Canceled)
		status := r.Status()
		toState, reason := runledger.StateFailed, "error"
		if interrupted {
			toState, reason = runledger.StateCancelled, "interrupted"
		}
		message := runErr.Error()
		transition := e.transition(r, toState, reason, runledger.Patch{Error: &message, TotalTokens: &s.TotalTokens})
		if status == "interrupted" && transition.OK {
			e.execDB(context.Background(), `UPDATE agent_runs SET status = 'interrupted' WHERE id = ? AND runtime_state = ?`, r.ID, runledger.StateCancelled)
		}
		short := message
		if len(short) > 500 {
			short = short[:500]
		}
		eventType := runledger.EventRunFailed
		if interrupted {
			eventType = runledger.EventRunCancelled
		}
		e.RecordEvent(r.UserID, r.ID, r.AgentID, eventType, map[string]any{"error": short, "error_code": publicErrorCode(runErr)})
		if !interrupted {
			e.captureFailure(r, s.Iterations, s.Messages, s.LLMTools())
		}
		event := "run:error"
		if interrupted {
			event = "run:stopped"
			if status == "interrupted" {
				event = "run:interrupted"
			}
		}
		e.Emit(r.UserID, event, map[string]any{"runId": r.ID, "error": message, "code": publicErrorCode(runErr)})
		if interrupted {
			if status != "interrupted" {
				status = "stopped"
			}
			res, runErr = Result{RunID: r.ID, TotalTokens: s.TotalTokens, Iterations: s.Iterations, Status: status}, nil
		}
	}()

	// The call that handed this off keeps talking while it works.
	if o.TriggerSource == "voice_live" {
		e.moveToBackground(r)
	}
	broker := newProgressBroker(e, r, func(since int) progressDelta {
		return collectProgressDelta(s, since)
	})
	r.mu.Lock()
	r.broker = broker
	r.mu.Unlock()
	broker.markAccepted()

	var resumedFrom any
	if o.ResumedFromRunID != "" {
		resumedFrom = o.ResumedFromRunID
	}
	e.ledger.Record(runledger.Event{RunID: r.ID, UserID: r.UserID, AgentID: r.AgentID, Type: runledger.EventRunStarted, Actor: r.WorkerID,
		Payload: map[string]any{"trigger_type": r.TriggerType, "trigger_source": r.TriggerSource, "resumed_from": resumedFrom, "capture": nullString(r.Capture.Reason)}})
	e.Emit(r.UserID, "run:start", map[string]any{"runId": r.ID, "agentId": r.AgentID, "conversationId": nullString(r.ConversationID), "title": r.Title,
		"triggerType": r.TriggerType, "triggerSource": r.TriggerSource, "deviceTarget": nullString(r.DeviceTarget), "runtimeKernel": "v2"})
	r.journal.Phase("model", "Choosing a model")

	turnCtx := r.Context()
	// Independent startup work runs while the model is chosen.
	promptCh := make(chan struct {
		sections ai.PromptSections
		err      error
	}, 1)
	go func() {
		sections, err := e.buildSystemPrompt(turnCtx, r, message(s))
		promptCh <- struct {
			sections ai.PromptSections
			err      error
		}{sections, err}
	}()
	var recall chan string
	if !o.SkipGlobalRecall {
		recall = make(chan string, 1)
		query := o.Context.RawUserMessage
		if query == "" {
			query = s.UserMessage
		}
		go func() { recall <- e.memoryRecall(turnCtx, r, query) }()
	}

	selected, err := e.selectModel(turnCtx, r.UserID, r.AgentID, r.TriggerType == "subagent", o.Model, aimodels.Hint{}, e.statusNotifier(r))
	if err != nil {
		return Result{}, err
	}
	s.Env = ai.Env{
		Controls: &runControls{e: e, r: r, s: s},
		Models:   &runModels{e: e, r: r},
		Tools:    e.deps.Backend,
		Journal:  r.journal,
		Resume:   e.resumeReviewer(r),
		Retain:   e.retainer(r),
		Sanitize: ai.SanitizeOptions{Model: selected.Model},
	}
	if e.deps.Gates != nil {
		s.Env.Gate = e.deps.Gates.Gate(r)
	}
	if e.deps.Commands != nil {
		s.Env.Checkpoints = checkpoints{e: e, r: r}
	}
	e.adoptModel(r, s, selected)
	providerMs := time.Since(startedAt).Milliseconds()
	s.Options = ai.RunOptions{MaxTokens: o.MaxTokens, ReasoningEffort: e.reasoningEffort(o), ModelCallTimeout: o.ModelCallTimeout, Tools: o.toolOptions(), Platform: o.Source}
	s.Pressure = &ai.ContextPressure{
		Summarize: func(ctx context.Context, messages []llm.Message) (string, error) {
			res, err := s.Model.Provider.Chat(ctx, messages, nil, llm.Options{Model: s.Model.Model, MaxTokens: 1600, ReasoningEffort: s.Options.ReasoningEffort,
				Extra: map[string]any{"phase": "context_compaction"}})
			if err != nil {
				return "", err
			}
			summary := strings.TrimSpace(res.Content)
			if summary == "" {
				return "", errors.New("Context compaction returned an empty summary.")
			}
			return summary, nil
		},
		OnEvent: func(ev ai.PressureEvent) {
			if ev.Kind == "pressure" {
				_, _ = e.ledger.SaveCheckpoint(context.Background(), r.ID, "pre_compaction", map[string]any{"iterations": s.Iterations}, r.UserID, r.AgentID)
				return
			}
			e.RecordEvent(r.UserID, r.ID, r.AgentID, runledger.EventContextCompacted, ev.Fields)
		},
	}
	base, explicit := selected.SelectionID, o.Model != ""
	unroutable := map[string]bool{}
	s.Env.AfterModelTurn = func() { broker.noteActivity("model_completed") }
	s.Env.AfterToolTurn = func(ctx context.Context, s *ai.Session, decision ai.Decision, turn ai.ToolTurnOutcome) {
		// Newly activated schemas only reach the model if the active set is re-read.
		r.mu.Lock()
		if len(r.activeTools) > 0 {
			s.Tools = append(s.Tools[:0:0], r.activeTools...)
		}
		if len(r.toolCatalog) > 0 {
			s.Catalog = append(s.Catalog[:0:0], r.toolCatalog...)
		}
		r.mu.Unlock()
		// A reply in the run's own chat stays its last word only while the model
		// does nothing else.
		sent := false
		for _, c := range decision.ToolCalls {
			sent = sent || c.Name == "send_message"
		}
		r.Delivery.Lock()
		if turn.TerminalAnswer != nil {
			r.Delivery.LastWordSent = true
		} else if r.Delivery.LastWordSent && !sent {
			r.Delivery.LastWordSent = false
		}
		r.Delivery.Unlock()
		e.applyTaskModel(ctx, r, s, decision.ToolCalls, base, explicit, unroutable)
		broker.maybePublish(r.Context())
	}

	prompt := <-promptCh
	if prompt.err != nil {
		return Result{}, prompt.err
	}
	r.mu.Lock()
	r.systemPrompt = strings.Join(nonEmpty(prompt.sections.Stable, prompt.sections.Dynamic), "\n\n")
	r.mu.Unlock()
	e.assembleContext(turnCtx, r, s, settings, prompt.sections, startedAt, providerMs, recall)
	if r.ConversationID != "" && o.ResumedFromRunID == "" {
		e.storeUserMessage(r, s.UserMessage)
	}
	e.transition(r, runledger.StateExecuting, "context_ready", runledger.Patch{})

	// The heartbeat keeps a run inside a long tool or model call from going
	// silent. Background automation reports through its own target.
	if o.TaskID == 0 && r.TriggerType != "subagent" {
		broker.start()
	}
	outcome, err := ai.RunAgentLoop(r.runCtx, s)
	broker.halt()
	if err != nil {
		return Result{}, err
	}
	switch outcome.Type {
	case "cancelled":
		return e.cancelledResult(r, s), nil
	case "ended":
		return Result{RunID: r.ID, TotalTokens: s.TotalTokens, Iterations: s.Iterations, Status: outcome.Status}, nil
	}
	answer := outcome.Content
	reason := "answer"
	if outcome.Type == "wrap_up" {
		r.Delivery.Lock()
		r.Delivery.WrappedUp = true
		r.Delivery.Unlock()
		reason = outcome.Reason
		answer, err = ai.WriteWrapUp(r.runCtx, s, outcome.Reason, r.requestTurn, e.formatting())
		if err != nil {
			return Result{}, err
		}
	}
	e.transition(r, runledger.StateDelivering, reason, runledger.Patch{})
	final := e.deliverFinal(r, s, answer)
	content := final.content
	if content == "" {
		content = answer
	}
	if !final.ok {
		status := "delivery_failed"
		if final.reason == "ambiguous" {
			status = "delivery_ambiguous"
		}
		errText := final.err
		if errText == "" {
			errText = status
		}
		e.RecordEvent(r.UserID, r.ID, r.AgentID, runledger.EventRunFailed, map[string]any{"error_code": status, "execution_completed": true})
		e.Emit(r.UserID, "run:error", map[string]any{"runId": r.ID, "error": errText, "content": content, "deliveryStatus": status, "executionCompleted": true})
		return Result{RunID: r.ID, Content: content, TotalTokens: s.TotalTokens, Iterations: s.Iterations, Status: "failed", Error: errText,
			DeliveryStatus: status, ExecutionComplete: true}, nil
	}
	e.finalizeSuccess(r, s, content, settings)
	return Result{RunID: r.ID, Content: content, TotalTokens: s.TotalTokens, Iterations: s.Iterations, Status: "completed"}, nil
}

func message(s *ai.Session) string { return s.UserMessage }

func nonEmpty(values ...string) []string {
	var out []string
	for _, v := range values {
		if v != "" {
			out = append(out, v)
		}
	}
	return out
}

func (e *Engine) formatting() ai.Formatting {
	if e.deps.Messaging != nil {
		return e.deps.Messaging
	}
	return noFormatting{}
}

type noFormatting struct{}

func (noFormatting) Guide(string) string { return "" }

// collectProgressDelta: only what finished since the last update is news.
func collectProgressDelta(s *ai.Session, since int) progressDelta {
	executions := s.Executions
	if since > len(executions) {
		since = len(executions)
	}
	var fresh []ai.ToolExecution
	for _, item := range executions[since:] {
		if s.Shaper.IsSubstantiveProgressEvidence(item) {
			fresh = append(fresh, item)
		}
	}
	completed := []string{}
	for _, item := range fresh {
		status := "failed"
		if item.OK {
			status = "ok"
		}
		completed = append(completed, item.ToolName+":"+status)
	}
	return progressDelta{Completed: completed, Evidence: s.Shaper.SummarizeProgressToolExecutions(fresh, 5), Through: len(executions)}
}

func (e *Engine) buildSystemPrompt(ctx context.Context, r *Run, userMessage string) (ai.PromptSections, error) {
	o := r.Options
	audience := o.MemoryAudience
	if audience == "" {
		audience = "owner"
	}
	sections, err := e.deps.Prompts.Sections(ctx, r.UserID, ai.PromptContext{
		AgentID: r.AgentID, TriggerSource: r.TriggerSource, MemoryAudience: audience, Source: o.Source, ChatID: o.ChatID,
		LatencyProfile: o.LatencyProfile, DeviceTarget: r.DeviceTarget, WorkspaceRoot: r.WorkspaceRoot,
		AdditionalContext: o.Context.AdditionalContext, IncludeRuntimeDetails: o.Context.IncludeRuntimeDetails, PublicAudience: r.Public != nil,
	})
	if err != nil {
		return ai.PromptSections{}, err
	}
	if e.deps.Extras != nil {
		query := o.Context.RawUserMessage
		if query == "" {
			query = userMessage
		}
		if skills := e.deps.Extras.Skills(ctx, r.UserID); skills != "" {
			sections.Stable = strings.Join(nonEmpty(sections.Stable, skills), "\n\n")
		}
		if timeline := e.deps.Extras.Timeline(ctx, r.UserID, r.AgentID, query); timeline != "" {
			sections.Dynamic = strings.Join(nonEmpty(sections.Dynamic, timeline), "\n\n")
		}
	}
	if r.Public != nil && r.Public.PromptGuide != "" {
		sections.Dynamic = strings.Join(nonEmpty(sections.Dynamic, r.Public.PromptGuide), "\n\n")
	}
	return sections, nil
}

func (e *Engine) storeUserMessage(r *Run, userMessage string) {
	o := r.Options
	raw, speaker := "", ""
	group := false
	if r.TriggerSource == "messaging" {
		raw = o.Context.RawUserMessage
	}
	if social := o.Context.Social; social != nil {
		group = social.IsGroup
		if social.Message != nil {
			speaker = social.Message.SenderName
			if speaker == "" {
				speaker = social.Message.Sender
			}
		}
	}
	content := ai.StoredUserContent(userMessage, raw, o.Source, speaker, group)
	meta, _ := json.Marshal(map[string]any{"deviceTarget": nullString(r.DeviceTarget)})
	e.execDB(context.Background(), `INSERT INTO conversation_messages (conversation_id, run_id, agent_id, role, content, metadata_json) VALUES (?, ?, ?, 'user', ?, ?)`,
		r.ConversationID, r.ID, nullString(r.AgentID), content, string(meta))
}

func (e *Engine) deliverFinal(r *Run, s *ai.Session, content string) finalOutcome {
	r.mu.Lock()
	r.steeringClosed = true
	r.mu.Unlock()
	ctx := context.Background()
	result := e.requestFinalDelivery(ctx, r, content, s.TotalTokens)
	if !result.ok && result.reason == "already_committed" {
		return finalOutcome{ok: true, content: content}
	}
	if !result.ok && result.reason == "ambiguous" {
		errText := result.err
		if errText == "" {
			errText = "Final delivery state is ambiguous"
		}
		e.transition(r, runledger.StateFailed, "delivery_ambiguous", runledger.Patch{Error: &errText, FinalResponse: &content, TotalTokens: &s.TotalTokens,
			Metadata: map[string]any{"executionCompleted": true, "deliveryStatus": "ambiguous"}})
		return result
	}
	if !result.ok {
		if deliveryChannel(r.TriggerSource) == "web" {
			e.transition(r, runledger.StateCompleted, "local_final_without_external", runledger.Patch{FinalResponse: &content, TotalTokens: &s.TotalTokens})
			// The client still needs exactly one run:complete to close the run out.
			e.Emit(r.UserID, "run:complete", map[string]any{"runId": r.ID, "content": content, "totalTokens": s.TotalTokens})
			return finalOutcome{ok: true, content: content}
		}
		errText := result.err
		if errText == "" {
			errText = orText(result.reason, "delivery failed")
		}
		e.transition(r, runledger.StateFailed, "delivery_failed", runledger.Patch{Error: &errText, FinalResponse: &content, TotalTokens: &s.TotalTokens,
			Metadata: map[string]any{"executionCompleted": true, "deliveryStatus": "failed"}})
	}
	return result
}

func (e *Engine) finalizeSuccess(r *Run, s *ai.Session, content string, settings dyn.Map) {
	ctx := context.Background()
	if r.ConversationID != "" && content != "" {
		e.execDB(ctx, `INSERT INTO conversation_messages (conversation_id, run_id, agent_id, role, content, metadata_json) VALUES (?, ?, ?, 'assistant', ?, '{"final":true}')`,
			r.ConversationID, r.ID, nullString(r.AgentID), content)
	}
	// The running sum only sees the loop's calls; the usage ledger has every
	// recorded call of the run (narration, compaction, ...).
	var ledgerTokens int
	_ = e.deps.DB.W.QueryRowContext(ctx, `SELECT COALESCE(SUM(total_tokens), 0) FROM agent_model_usage WHERE run_id = ?`, r.ID).Scan(&ledgerTokens)
	s.TotalTokens = max(s.TotalTokens, ledgerTokens)
	e.execDB(ctx, `UPDATE agent_runs SET total_tokens = ?, final_response = COALESCE(final_response, ?), updated_at = datetime('now') WHERE id = ?`,
		s.TotalTokens, nullString(content), r.ID)
	e.RecordEvent(r.UserID, r.ID, r.AgentID, runledger.EventRunCompleted, map[string]any{"total_tokens": s.TotalTokens, "iterations": s.Iterations, "answer_chars": len([]rune(content))})
	// No run:complete here: the delivery committed it already.
	// Conversation learning runs after delivery, one at a time per thread. A run
	// a saved task started opens on that task's instructions, not the owner's words.
	if r.ConversationID != "" && r.Options.TaskID == 0 && e.deps.Memory != nil {
		model := r.Model()
		key := fmt.Sprintf("conversation-learning:%d:%s:%s", r.UserID, orText(r.AgentID, "main"), r.ConversationID)
		window, _ := dyn.Int(settings["chat_history_window"])
		_ = e.Background(key, false, func(ctx context.Context) error {
			return e.refreshConversationState(ctx, r, model, content, window)
		})
	}
	e.log.Info("Run completed", "run", shortID(r.ID), "steps", s.Iterations, "tokens", s.TotalTokens, "finalResponse", content != "")
	if e.deps.SkillLearning != nil {
		e.deps.SkillLearning.EnqueueCompletedRun(r.UserID, r.AgentID, r.ID, r.TriggerType, r.TriggerSource, s.UserMessage, r.Options.TaskID, content, s.Iterations, s.Messages)
	}
}

// cancelledResult closes a run a stop noticed between steps; clients still need
// the terminal event.
func (e *Engine) cancelledResult(r *Run, s *ai.Session) Result {
	ctx := context.Background()
	run, _ := e.ledger.LoadRun(ctx, r.ID)
	if run != nil && !run.Terminal() {
		cancelled := e.transition(r, runledger.StateCancelled, "cancelled", runledger.Patch{TotalTokens: &s.TotalTokens})
		// An interruption (a shutdown) stays recorded as one, so a restart can tell.
		if cancelled.OK && r.Status() == "interrupted" {
			e.execDB(ctx, `UPDATE agent_runs SET status = 'interrupted' WHERE id = ? AND runtime_state = ?`, r.ID, runledger.StateCancelled)
		}
	}
	if run != nil {
		e.Emit(run.UserID, "run:stopped", map[string]any{"runId": r.ID, "conversationId": nullString(r.ConversationID)})
	}
	status := "stopped"
	if r.Status() == "interrupted" {
		status = "interrupted"
	}
	return Result{RunID: r.ID, TotalTokens: s.TotalTokens, Iterations: s.Iterations, Status: status}
}

// retainer saves a payload a compacted tool result had to cut, so the model can
// read the rest with read_artifact.
func (e *Engine) retainer(r *Run) func(s *ai.Session, call ai.Call, stepID string, payload any) *ai.RetainedResult {
	if e.deps.Artifacts == nil {
		return nil
	}
	return func(s *ai.Session, call ai.Call, stepID string, payload any) *ai.RetainedResult {
		text := ai.ToRetainedText(payload)
		id, err := e.deps.Artifacts.CreateTextArtifact(r.Context(), r.UserID, "tool-result", call.Name, "text/plain; charset=utf-8", text,
			map[string]any{"runId": r.ID, "stepId": stepID, "tool": call.Name})
		if err != nil {
			e.log.Warn("Could not retain a cut tool result", "error", err)
			return nil
		}
		return &ai.RetainedResult{ArtifactID: id, TotalLines: strings.Count(text, "\n") + 1}
	}
}

var _ = errRunIDConflict
