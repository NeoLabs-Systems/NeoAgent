package ai

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/llm"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/prompts"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
)

const (
	maxBlankRecoveries   = 2
	maxTruncationRetries = 2
	maxStallRetries      = 2
	maxMarkupRetries     = 2
	modelCallTimeout     = 5 * time.Minute
	taskStatePrefix      = "[Task state]"
)

// ModelHandle is the model a run currently talks to.
type ModelHandle struct {
	Provider     llm.Provider
	ProviderName string
	Model        string
	SelectionID  string
}

// RunOptions are what a run was started with.
type RunOptions struct {
	MaxTokens            int
	ReasoningEffort      string
	ModelCallTimeout     time.Duration
	MaxParallelToolCalls int
	// Limits on which tools the run may call; see tools.RunOptions.
	Tools tools.RunOptions
	// Platform names the messaging platform the run answers on, for formatting.
	Platform string
}

// Controls are the lifecycle hooks of a run: pause, stop and interrupt are
// honoured between turns and while a turn is in flight, and follow-up messages
// are steered into a run only while it will still read them.
type Controls interface {
	Aborted() bool
	// Terminal reports a run that already ended, with its status.
	Terminal() (terminal bool, status string)
	Heartbeat()
	// PendingControl is the unconsumed control addressed to the run, if any.
	PendingControl() (action, reason string)
	// Checkpoint is a lifecycle boundary; it returns "stop" or "interrupt" when
	// the run must end there.
	Checkpoint(ctx context.Context, phase string) string
	Interrupt(reason string)
	// ApplySteering adds queued follow-up messages to the transcript.
	ApplySteering(s *Session)
	// OpenSteeringIntake says whether follow-ups may still be steered in.
	OpenSteeringIntake(open bool)
	HasPendingSteering() bool
}

// Models decides what a provider failure means for the run's model.
type Models interface {
	// Failed remembers a failure; Succeeded lifts the cooldown again.
	Failed(ctx context.Context, selectionID string, err error)
	Succeeded(ctx context.Context, selectionID string)
	ShouldSwitch(err error) bool
	// Switch moves the session to a fallback model; false means none is left.
	Switch(ctx context.Context, s *Session, cause error) (bool, error)
}

// Journal records what the run does: its events for clients, and its steps.
type Journal interface {
	Phase(kind, message string)
	// Stream replaces the text streamed so far for the iteration.
	Stream(content string, iteration int)
	Publish(eventType string, payload map[string]any)
	StepStart(s *Session, step StepStart) string
	StepEnd(s *Session, stepID string, end StepEnd)
	ToolStart(s *Session, stepID string, call Call)
	ToolEnd(s *Session, stepID string, call Call, compacted string, err string)
}

// Session is the state of one run's loop.
type Session struct {
	RunID, AgentID, UserMessage string
	UserID                      int64
	TriggerType, TriggerSource  string

	Messages []llm.Message
	// Tools are the definitions active for the next turn, Catalog every tool the
	// run is eligible for.
	Tools   []tools.Definition
	Catalog []tools.Definition
	Model   ModelHandle
	Options RunOptions

	Iterations, StepIndex, TotalTokens int
	Guards                             *RunGuards
	Pressure                           *ContextPressure
	Repetition                         *ToolRepetitionGuard
	Ager                               ResultAger
	Shaper                             *Shaper
	Executions                         []ToolExecution
	FailedModelIDs                     map[string]bool
	// Evidence is what the run's own last actions showed.
	Evidence        struct{ LastActionFailed, LastTestFailed string }
	EvidenceChecked bool
	LastCheck       string
	// Goal is the task the run is for, for the task-state note and recovery.
	Goal func() string
	// TaskStateLines are the ledger lines of the task-state note between the
	// goal and the last check (constraints, steps, notes, changed files).
	TaskStateLines func() []string

	Env Env

	recoveryNotes      int
	recoveryDisarmed   bool
	codingGuidanceSent bool
}

// TurnContexts is implemented by Controls whose pause ends the turn in flight
// while the run lives on: model requests and tool calls get the turn context,
// lifecycle boundaries the run's.
type TurnContexts interface {
	TurnContext(run context.Context) context.Context
}

// Env bundles the collaborators the loop calls out to.
type Env struct {
	Controls Controls
	Models   Models
	Tools    ToolBackend
	Journal  Journal
	Gate     Gate
	Resume   ResumeReviewer
	Retain   func(s *Session, call Call, stepID string, payload any) *RetainedResult
	Sanitize SanitizeOptions
	Now      func() time.Time
	// Checkpoints tracks what mutating calls change in the workspace.
	Checkpoints Checkpointer
	// AfterModelTurn is told when a model turn returned; AfterToolTurn after
	// each tool turn (model pins, progress updates). Both may be nil.
	AfterModelTurn func()
	AfterToolTurn  func(ctx context.Context, s *Session, decision Decision, turn ToolTurnOutcome)
}

func (s *Session) turnContext(ctx context.Context) context.Context {
	if tc, ok := s.Env.Controls.(TurnContexts); ok {
		if turn := tc.TurnContext(ctx); turn != nil {
			return turn
		}
	}
	return ctx
}

// LoopResult is how the loop ended.
type LoopResult struct {
	// Type is "answer", "wrap_up", "cancelled", "stopped" or "ended".
	Type    string
	Content string
	Reason  string
	Status  string
}

func (s *Session) goal() string {
	if s.Goal != nil {
		return s.Goal()
	}
	return ClampRunContext(s.UserMessage, 400)
}

// llmTools is the tool list as providers see it.
func (s *Session) llmTools() []llm.Tool {
	out := make([]llm.Tool, 0, len(s.Tools))
	for _, def := range s.Tools {
		if compact, ok := tools.Compact(def, true); ok {
			out = append(out, compact.ToLLM())
		}
	}
	return out
}

func usageTokens(u *llm.Usage) int {
	if u == nil {
		return 0
	}
	return u.InputTokens + u.OutputTokens
}

func dropReasoningState(messages []llm.Message) bool {
	dropped := false
	for i := range messages {
		if messages[i].ReasoningState != nil {
			messages[i].ReasoningState = nil
			dropped = true
		}
		if messages[i].ProviderContentBlocks != nil {
			messages[i].ProviderContentBlocks = nil
			dropped = true
		}
	}
	return dropped
}

// isReasoningReplayError: an endpoint that refuses replayed reasoning still gets
// the turn, without it.
func isReasoningReplayError(err error) bool {
	if e := llm.AsError(err); e != nil && e.Status != 0 && e.Status != 400 && e.Status != 422 {
		return false
	}
	message := strings.ToLower(err.Error())
	for _, word := range []string{"reasoning", "thinking", "thought", "signature"} {
		if strings.Contains(message, word) {
			return true
		}
	}
	return false
}

func isModelCallTimeout(err error) bool {
	e := llm.AsError(err)
	return e != nil && e.Code == "MODEL_CALL_TIMEOUT"
}

// What survives a compaction has to be re-established around it: the task state
// goes back in, and reads the model can no longer see may run again.
func (s *Session) adoptCompacted(messages []llm.Message) {
	s.Messages = messages
	s.Ager.Reset()
	s.Repetition.NoteCompaction()
	s.placeTaskStateNote()
}

// placeTaskStateNote puts the task state right behind the summary it complements,
// in the leading section that later compactions keep as it is.
func (s *Session) placeTaskStateNote() {
	kept := make([]llm.Message, 0, len(s.Messages)+1)
	for _, m := range s.Messages {
		if !(m.Role == "system" && strings.HasPrefix(dyn.Str(m.Content), taskStatePrefix)) {
			kept = append(kept, m)
		}
	}
	index := 0
	for index < len(kept) && kept[index].Role == "system" {
		index++
	}
	note := taskStatePrefix + "\nGoal: " + s.goal()
	if s.TaskStateLines != nil {
		for _, line := range s.TaskStateLines() {
			note += "\n" + line
		}
	}
	if s.LastCheck != "" {
		note += "\nRecorded: last check: " + s.LastCheck
	}
	kept = append(kept[:index], append([]llm.Message{{Role: "system", Content: note}}, kept[index:]...)...)
	s.Messages = kept
}

type modelTurn struct {
	Response *llm.Result
	Streamed string
}

// callModel makes one request, streaming the text to the journal. A turn that
// takes longer than the model call budget fails with MODEL_CALL_TIMEOUT.
func (s *Session) callModel(ctx context.Context) (modelTurn, error) {
	timeout := s.Options.ModelCallTimeout
	if timeout <= 0 {
		timeout = modelCallTimeout
	}
	callCtx, cancel := context.WithCancelCause(ctx)
	defer cancel(nil)
	timer := time.AfterFunc(timeout, func() {
		cancel(&llm.Error{Provider: s.Model.ProviderName, Code: "MODEL_CALL_TIMEOUT", Message: fmt.Sprintf("Model call timed out after %s.", timeout)})
	})
	defer timer.Stop()

	messages := SanitizeConversationMessages(s.Messages)
	opt := llm.Options{Model: s.Model.Model, MaxTokens: s.Options.MaxTokens, ReasoningEffort: s.Options.ReasoningEffort}
	var streamed strings.Builder
	var final *llm.Event
	for event, err := range s.Model.Provider.Stream(callCtx, messages, s.llmTools(), opt) {
		if err != nil {
			if cause := context.Cause(callCtx); cause != nil && ctx.Err() == nil {
				return modelTurn{}, cause
			}
			return modelTurn{}, err
		}
		switch event.Type {
		case llm.EventContent:
			streamed.WriteString(event.Content)
			s.Env.Journal.Stream(streamed.String(), s.Iterations)
		case llm.EventToolCalls, llm.EventDone:
			e := event
			final = &e
		}
	}
	if cause := context.Cause(callCtx); cause != nil && ctx.Err() == nil {
		return modelTurn{}, cause
	}
	if final == nil {
		return modelTurn{Streamed: streamed.String(), Response: &llm.Result{Content: streamed.String()}}, nil
	}
	return modelTurn{Streamed: streamed.String(), Response: &llm.Result{
		Content: final.Content, ToolCalls: final.ToolCalls, FinishReason: final.FinishReason, Truncated: final.Truncated,
		Usage: final.Usage, Model: final.Model, ReasoningState: final.ReasoningState,
	}}, nil
}

type requested struct {
	turn    modelTurn
	result  *LoopResult
	aborted bool
}

// requestTurn makes one model request. A context overflow is compacted and
// retried once; other provider failures switch to a fallback model, and a
// timeout with no fallback left retries the same model.
func (s *Session) requestTurn(ctx context.Context) (requested, error) {
	env := s.Env
	overflowRetried, reasoningRetried, stallRetries := false, false, 0
	for {
		turn, err := s.callModel(ctx)
		if err == nil {
			env.Models.Succeeded(ctx, s.Model.SelectionID)
			return requested{turn: turn}, nil
		}
		if ctx.Err() != nil || llm.IsAbort(err) && !isModelCallTimeout(err) {
			return requested{aborted: true}, nil
		}
		if IsContextOverflowError(err) {
			wrap := requested{result: &LoopResult{Type: "wrap_up", Reason: "context_overflow"}}
			if overflowRetried || !s.Pressure.ClaimOverflowRecovery() {
				return wrap, nil
			}
			recovered, perr := s.Pressure.Prepare(ctx, PrepareRequest{
				ContextWindow: s.Model.Provider.ContextWindow(s.Model.Model), Messages: s.Messages, Tools: s.llmTools(),
				MaxOutputTokens: s.Options.MaxTokens, Force: true, Reason: "provider_overflow",
			})
			if perr != nil {
				if ctx.Err() != nil {
					return requested{}, perr
				}
				return wrap, nil
			}
			if !recovered.Changed {
				return wrap, nil
			}
			s.adoptCompacted(recovered.Messages)
			overflowRetried = true
			continue
		}
		if !reasoningRetried && isReasoningReplayError(err) && dropReasoningState(s.Messages) {
			reasoningRetried = true
			continue
		}
		env.Models.Failed(ctx, s.Model.SelectionID, err)
		s.FailedModelIDs[s.Model.SelectionID] = true
		if env.Models.ShouldSwitch(err) {
			switched, serr := env.Models.Switch(ctx, s, err)
			if serr != nil {
				return requested{}, serr
			}
			if switched {
				dropReasoningState(s.Messages) // signatures belong to the model that wrote them
				continue
			}
		}
		if isModelCallTimeout(err) && stallRetries < maxStallRetries {
			stallRetries++
			// Drop the partial text the stalled stream already showed.
			env.Journal.Stream("", s.Iterations)
			continue
		}
		return requested{}, err
	}
}

// honorControls applies pause, stop and interrupt at a boundary; it returns a
// loop result when the run must end here.
func (s *Session) honorControls(ctx context.Context, phase string) *LoopResult {
	if s.Env.Controls.Aborted() {
		return &LoopResult{Type: "cancelled"}
	}
	if action := s.Env.Controls.Checkpoint(ctx, phase); action == "stop" || action == "interrupt" {
		return &LoopResult{Type: "cancelled"}
	}
	return nil
}

const (
	recoveryTriggerTurns = 2
	maxRecoveryNotes     = 3
)

var recoveryReasonText = map[string]string{
	"tool_failures": "every call in the last steps failed",
	"same_action":   "the same call keeps being repeated",
	"no_progress":   "the last steps changed nothing and found nothing new",
}

func recoveryReason(st Streaks) string {
	switch {
	case st.FailedTurns >= recoveryTriggerTurns:
		return "tool_failures"
	case st.SameActionTurns >= recoveryTriggerTurns:
		return "same_action"
	case st.IdleTurns >= recoveryTriggerTurns:
		return "no_progress"
	}
	return ""
}

// applyRecovery adds a note when a run has just become stuck. Reflection happens
// only when something actually went wrong: a failing or spinning run gets a note
// on its next regular turn, so a healthy run pays nothing and even a struggling
// one pays no extra model call. It re-arms once the run gets moving again, so a
// second, separate problem can get its own note.
func (s *Session) applyRecovery() {
	reason := recoveryReason(s.Guards.Streaks())
	if reason == "" {
		s.recoveryDisarmed = false
		return
	}
	if s.recoveryDisarmed || s.recoveryNotes >= maxRecoveryNotes {
		return
	}
	s.recoveryDisarmed = true
	s.recoveryNotes++

	last := s.Executions
	if len(last) > 4 {
		last = last[len(last)-4:]
	}
	var actions []string
	for _, item := range last {
		status := "ok"
		if !item.OK {
			status = "failed (" + ClampRunContext(item.Error, 160) + ")"
		}
		actions = append(actions, fmt.Sprintf("- %s: %s", item.ToolName, status))
	}
	recent := s.Executions
	if len(recent) > 6 {
		recent = recent[len(recent)-6:]
	}
	var failures []string
	for _, item := range recent {
		if text := ClampRunContext(item.Error, 200); !item.OK && !contains(failures, text) {
			failures = append(failures, text)
		}
	}
	if len(failures) > 3 {
		failures = failures[:3]
	}
	failureBlock := ""
	if len(failures) > 0 {
		lines := make([]string, len(failures))
		for i, f := range failures {
			lines[i] = "- " + f
		}
		failureBlock = "Failures:\n" + strings.Join(lines, "\n") + "\n"
	}
	s.Messages = append(s.Messages, llm.Message{Role: "system", Content: prompts.Render("runtime/recovery.md", map[string]string{
		"reason": recoveryReasonText[reason], "goal": s.goal(), "actions": strings.Join(actions, "\n"), "failures": failureBlock,
	})})
	st := s.Guards.Streaks()
	s.Env.Journal.Publish("recovery_triggered", map[string]any{
		"reason": reason, "note_number": s.recoveryNotes, "iteration": s.Iterations,
		"idleTurns": st.IdleTurns, "failedTurns": st.FailedTurns, "sameActionTurns": st.SameActionTurns,
	})
}

func contains(list []string, v string) bool {
	for _, item := range list {
		if item == v {
			return true
		}
	}
	return false
}

// RunAgentLoop is the agent loop. The model works with tools until it answers
// without calling one; that answer is what the user receives. The runtime only
// keeps the loop alive and safe: lifecycle controls, steering, context
// compaction, provider recovery and runaway guards.
func RunAgentLoop(ctx context.Context, s *Session) (LoopResult, error) {
	env := s.Env
	markupRetries, blankRecoveries, truncationRetries := 0, 0, 0
	if s.FailedModelIDs == nil {
		s.FailedModelIDs = map[string]bool{}
	}
	for {
		if env.Controls.Aborted() {
			return LoopResult{Type: "cancelled"}, nil
		}
		if ctx.Err() != nil {
			if ended := s.honorControls(ctx, "signal_boundary"); ended != nil {
				return *ended, nil
			}
			return LoopResult{Type: "cancelled"}, nil
		}
		if turn := s.turnContext(ctx); turn.Err() != nil {
			if ended := s.honorControls(ctx, "signal_boundary"); ended != nil {
				return *ended, nil
			}
			continue
		}
		env.Controls.Heartbeat()
		if terminal, status := env.Controls.Terminal(); terminal {
			if status == "" {
				status = "completed"
			}
			return LoopResult{Type: "ended", Status: status}, nil
		}
		switch action, reason := env.Controls.PendingControl(); action {
		case "pause":
			if ended := s.honorControls(ctx, "loop_boundary"); ended != nil {
				return *ended, nil
			}
			continue
		case "stop", "interrupt":
			if reason == "" {
				reason = action
			}
			env.Controls.Interrupt(reason)
			return LoopResult{Type: "cancelled"}, nil
		}

		if reason := s.Guards.StopReason(); reason != "" {
			return LoopResult{Type: "wrap_up", Reason: reason}, nil
		}

		env.Controls.OpenSteeringIntake(true)
		env.Controls.ApplySteering(s)

		turnCtx := s.turnContext(ctx)
		pressure, err := s.Pressure.Prepare(turnCtx, PrepareRequest{
			ContextWindow: s.Model.Provider.ContextWindow(s.Model.Model), Messages: s.Messages, Tools: s.llmTools(), MaxOutputTokens: s.Options.MaxTokens,
		})
		switch {
		case err != nil && ctx.Err() != nil:
			return LoopResult{Type: "cancelled"}, nil
		case err != nil && turnCtx.Err() != nil:
			continue
		case err == nil && pressure.Changed:
			s.adoptCompacted(pressure.Messages)
		}

		if s.Ager.Age(s.Messages) {
			// The answers these calls gave are no longer in view, so asking again is not a repeat.
			s.Repetition.NoteCompaction()
		}
		s.Iterations++
		s.Guards.RecordModelTurn()
		env.Journal.Phase("thinking", "Thinking")

		req, err := s.requestTurn(turnCtx)
		if err != nil {
			return LoopResult{}, err
		}
		if req.aborted {
			if ended := s.honorControls(ctx, "model_boundary"); ended != nil {
				return *ended, nil
			}
			if ctx.Err() != nil {
				return LoopResult{Type: "cancelled"}, nil
			}
			continue
		}
		if req.result != nil {
			return *req.result, nil
		}

		if env.AfterModelTurn != nil {
			env.AfterModelTurn()
		}
		response := req.turn.Response
		tokens := usageTokens(response.Usage)
		s.TotalTokens += tokens
		s.Guards.RecordTokens(tokens)
		content := response.Content
		if content == "" {
			content = req.turn.Streamed
		}
		decision := DecisionFromResponse(content, response.ToolCalls, response.ReasoningState, nil)

		switch decision.Kind {
		case DecisionBlank:
			// A blank turn is a provider hiccup, not an answer: nudge, then move to
			// another model, and wrap up only if that keeps happening.
			blankRecoveries++
			if blankRecoveries > maxBlankRecoveries {
				return LoopResult{Type: "wrap_up", Reason: "blank_output"}, nil
			}
			blank := &llm.Error{Provider: s.Model.ProviderName, Code: "MODEL_EMPTY_RESPONSE", Message: "Model returned no content and no tool calls"}
			env.Models.Failed(ctx, s.Model.SelectionID, blank)
			s.FailedModelIDs[s.Model.SelectionID] = true
			if switched, serr := env.Models.Switch(ctx, s, blank); serr != nil {
				return LoopResult{}, serr
			} else if switched {
				dropReasoningState(s.Messages)
			}
			s.Messages = append(s.Messages, llm.Message{Role: "system", Content: BuildBlankOutputGuidance(s.Executions)})
			continue

		case DecisionAnswer:
			// Some models write a tool call out as text. That is not an answer.
			if IsRawToolCall(decision.Content) {
				markupRetries++
				if markupRetries > maxMarkupRetries {
					return LoopResult{Type: "wrap_up", Reason: "malformed_output"}, nil
				}
				s.Messages = append(s.Messages, llm.Message{Role: "system", Content: prompts.Render("runtime/raw_tool_call.md", nil)})
				continue
			}
			// Once, if what the run last did failed: the answer should deal with that.
			if unresolved := firstNonEmpty(s.Evidence.LastActionFailed, s.Evidence.LastTestFailed); unresolved != "" && !s.EvidenceChecked {
				s.EvidenceChecked = true
				s.Messages = append(s.Messages, llm.Message{Role: "system", Content: prompts.Render("runtime/evidence_check.md", map[string]string{"finding": unresolved})})
				continue
			}
			// Text cut off at the token limit is an unfinished thought, not an
			// answer; ask for a real continuation a couple of times.
			if response.Truncated && truncationRetries < maxTruncationRetries {
				truncationRetries++
				s.Messages = append(s.Messages, llm.Message{Role: "system", Content: prompts.Render("runtime/truncated_output.md", nil)})
				continue
			}
			answer := SanitizeModelOutput(decision.Content, env.Sanitize)
			s.Messages = append(s.Messages, llm.Message{Role: "assistant", Content: answer})
			// Follow-ups that arrived while the model wrote this are answered before
			// anything is delivered.
			if env.Controls.HasPendingSteering() {
				continue
			}
			env.Controls.OpenSteeringIntake(false)
			return LoopResult{Type: "answer", Content: answer}, nil
		}

		truncationRetries = 0
		turn, err := s.executeToolTurn(turnCtx, decision)
		if err != nil {
			return LoopResult{}, err
		}
		s.Guards.RecordToolTurn(turn)
		s.applyRecovery()
		if env.AfterToolTurn != nil {
			env.AfterToolTurn(ctx, s, decision, turn)
		}
		if turn.TerminalAnswer != nil && !env.Controls.HasPendingSteering() {
			env.Controls.OpenSteeringIntake(false)
			return LoopResult{Type: "answer", Content: *turn.TerminalAnswer}, nil
		}
	}
}

// LLMTools is the active tool list as providers see it.
func (s *Session) LLMTools() []llm.Tool { return s.llmTools() }
