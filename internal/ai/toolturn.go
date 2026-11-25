package ai

import (
	"context"
	"fmt"
	"slices"
	"strings"
	"sync"

	"github.com/NeoLabs-Systems/neolabs-go/llm"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/prompts"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
)

// ToolBackend runs a tool: the built-in handlers, MCP servers, skills and
// integrations. It returns the tool's result (a JSON document), or an error for
// a failure the tool did not report in its result.
type ToolBackend interface {
	Execute(ctx context.Context, s *Session, call Call, stepID string) (any, error)
}

// Gate is the policy gate. Permission lives here and not in the model: the model
// may propose a call, but nothing it read can raise what the call is allowed to
// do. Hiding a tool from the model is not a limit, since a model can name any
// tool.
type Gate interface {
	// BeforeToolCall may block a call; reason is shown to the model.
	BeforeToolCall(ctx context.Context, s *Session, call Call, meta tools.Meta) (block bool, reason string)
	// WorkspaceBusy says a sub-agent of the run is changing the workspace.
	WorkspaceBusy(s *Session) bool
}

// Checkpointer tracks what mutating file and shell calls change in the
// workspace. Begin returns nil when the call is not tracked.
type Checkpointer interface {
	Begin(ctx context.Context, s *Session, call Call, meta tools.Meta) any
	Record(ctx context.Context, s *Session, started any)
}

// ResumeReview says a call of a resumed run must not run again.
type ResumeReview struct {
	// Reason is "outcome_unknown" or "already_done".
	Reason string
	// Completed: the earlier call finished, so its result stands.
	Completed bool
	Message   string
}

// ResumeReviewer reviews calls of a run resumed after an interruption: a call
// the run before it finished is not repeated, and a call whose outcome is
// unknown makes the owner decide.
type ResumeReviewer interface {
	Review(s *Session, call Call, meta tools.Meta) *ResumeReview
}

// StepStart describes a tool step about to run.
type StepStart struct {
	Index       int
	Type        string
	Description string
	ToolName    string
	Input       dyn.Map
}

// StepEnd is how a step ended.
type StepEnd struct {
	// Status is "completed", "failed" or "interrupted".
	Status string
	Result any
	Error  string
	// Blocked: the call never ran (refused, suppressed); Suppressed: an earlier
	// result stands for it.
	Blocked, Suppressed bool
	ReadOnly            bool
	Progressed          bool
	Fingerprint         string
	// Shown is the result as the model sees it; Test the test report, if any.
	Shown string
	Test  dyn.Ordered
}

type plannedCall struct {
	call        Call
	definition  *tools.Definition
	meta        tools.Meta
	isReadOnly  bool
	fingerprint string
	claimedRead bool
}

type reviewResult struct {
	allowed    bool
	suppressed bool
	message    string
	result     any
}

type callOutcome struct {
	call           Call
	meta           tools.Meta
	success        bool
	suppressed     bool
	progressed     bool
	execution      ToolExecution
	sentMessage    string
	answeredOrigin bool
	fingerprint    string
	toolMessage    llm.Message
}

// terminalSendPurposes are the purposes of a send_message that the model declares
// as the end of its work.
var terminalSendPurposes = []string{"final_result", "blocker", "no_response"}

func wireToolCall(call Call) llm.ToolCall { return call.Raw }

func (s *Session) definitionFor(name string) *tools.Definition {
	catalog := s.Catalog
	if catalog == nil {
		catalog = s.Tools
	}
	for i := range catalog {
		if catalog[i].Name == name {
			return &catalog[i]
		}
	}
	return nil
}

// dispatchRefusal is what this run may do at all, checked for every call.
func (s *Session) dispatchRefusal(planned *plannedCall) string {
	options := s.Options.Tools
	var catalog []tools.Definition
	if s.Catalog != nil {
		catalog = s.Catalog
	}
	if refusal := s.Shaper.Tools.RunToolRefusal(catalog, options, planned.call.Name, planned.call.Arguments); refusal != "" {
		return refusal
	}
	meta := planned.meta
	touchesWorkspace := meta.StateScope == "workspace" || meta.Group == "shell" || planned.call.Name == "delegate_to_agent"
	if !planned.isReadOnly && touchesWorkspace && s.Env.Gate != nil && s.Env.Gate.WorkspaceBusy(s) {
		return "A sub-agent of this run is changing the workspace. Wait for it before changing anything."
	}
	return ""
}

func (s *Session) reviewCall(ctx context.Context, planned *plannedCall, stepIndex int) reviewResult {
	call, meta := planned.call, planned.meta
	if refusal := s.dispatchRefusal(planned); refusal != "" {
		s.Env.Journal.Publish("permission_decision", map[string]any{"tool": call.Name, "decision": "deny", "by": "run_limits"})
		return reviewResult{message: refusal, result: dyn.Map{"error": refusal, "blocked": true}}
	}
	// A call without an argument its tool requires is a mistake in that call
	// alone: it is answered here, before anything runs, so it never counts
	// against the tool. A discarded call carries its own reason to the tool.
	var missing []string
	if _, discarded := call.Arguments["_discarded"].(string); !discarded && planned.definition != nil {
		missing = tools.MissingRequiredArgs(call.Arguments, planned.definition.Parameters)
	}
	if len(missing) > 0 {
		sent := dyn.SortedKeys(call.Arguments)
		reason := fmt.Sprintf("%s needs %s, which this call left out", call.Name, strings.Join(missing, " and "))
		if len(sent) > 0 {
			reason += fmt.Sprintf(" (it sent %s)", strings.Join(sent, ", "))
		}
		pronoun := "it"
		if len(missing) > 1 {
			pronoun = "them"
		}
		reason += fmt.Sprintf(". Nothing ran; send the call again with %s.", pronoun)
		s.Env.Journal.Publish("tool_suppressed", map[string]any{"tool": map[string]any{"name": call.Name, "call_fingerprint": planned.fingerprint}, "reason": "missing_arguments"})
		return reviewResult{message: reason, result: dyn.Map{"error": reason}}
	}
	if s.Env.Resume != nil {
		if repeat := s.Env.Resume.Review(s, call, meta); repeat != nil {
			s.Env.Journal.Publish("tool_suppressed", map[string]any{"tool": map[string]any{"name": call.Name, "call_fingerprint": planned.fingerprint}, "reason": repeat.Reason})
			message := repeat.Message
			if repeat.Completed {
				message = ""
			}
			return reviewResult{suppressed: repeat.Completed, message: message, result: dyn.Map{"status": repeat.Reason, "reason": repeat.Message}}
		}
	}
	if s.Env.Gate != nil {
		if block, reason := s.Env.Gate.BeforeToolCall(ctx, s, call, meta); block {
			if reason == "" {
				reason = "Blocked by policy hook"
			}
			return reviewResult{message: reason, result: dyn.Map{"error": reason, "blocked": true}}
		}
	}

	guard := s.Repetition
	// Only a remote service fails the same way whatever it is asked: a quota, an
	// outage, a refused account. A tool on the agent's own computer fails because
	// of what it was asked, so its calls are judged one at a time.
	if meta.LatencyClass == "remote" {
		if resting := guard.ToolResting(call.Name); resting != nil {
			// A wait is worth naming only when the service named it: otherwise the
			// model sleeps it out and repeats a call that cannot work.
			when := "Waiting will not change that."
			if resting.ServiceWait {
				when = fmt.Sprintf("The service asked to wait about %d seconds.", int(resting.RetryIn.Seconds()+0.999))
			}
			reason := fmt.Sprintf("%s failed %d times in a row with the same error, whatever it was asked: %s %s Do not call it again for this; use another way or tell the owner what is blocked.", call.Name, resting.Count, resting.Failure, when)
			s.Env.Journal.Publish("tool_suppressed", map[string]any{"tool": map[string]any{"name": call.Name, "call_fingerprint": planned.fingerprint}, "reason": "tool_resting"})
			return reviewResult{message: reason, result: dyn.Map{"status": "blocked", "reason": reason}}
		}
	}

	readScope := ""
	if planned.isReadOnly {
		readScope = meta.StateScope
	}
	// A repeatable read is what polling looks like: what it reads can change
	// without this run doing anything, so it is only stopped when it fails.
	blockedAsRead := planned.isReadOnly && !meta.Repeatable
	if guard.ShouldBlock(call.Name, call.Arguments, blockedAsRead, readScope) {
		prior := guard.LastFailure(call.Name, call.Arguments, readScope)
		reason, kind := "The same read-only call already returned an unchanged result twice.", "unchanged_result"
		if prior != "" {
			reason, kind = "This exact call already failed twice with: "+prior, "repeated_failure"
		}
		s.Env.Journal.Publish("tool_suppressed", map[string]any{"tool": map[string]any{"name": call.Name, "call_fingerprint": planned.fingerprint}, "reason": kind})
		return reviewResult{message: reason, result: dyn.Map{"status": "blocked", "reason": reason}}
	}

	if planned.isReadOnly && meta.Known && !meta.Repeatable {
		if prior := guard.ClaimRead(planned.fingerprint, stepIndex); prior != nil {
			s.Env.Journal.Publish("tool_suppressed", map[string]any{"tool": map[string]any{"name": call.Name, "call_fingerprint": planned.fingerprint}, "reason": "duplicate_without_state_change", "previous_step": prior.StepIndex})
			return reviewResult{suppressed: true, result: dyn.Map{
				"status": "suppressed",
				"reason": fmt.Sprintf("This exact call already ran as step %d and nothing it depends on has changed, so that result stands. If it can change on its own, such as a file a running process writes, call it again.", prior.StepIndex),
			}}
		}
		planned.claimedRead = true
	}
	return reviewResult{allowed: true}
}

func (s *Session) observeOutcome(planned *plannedCall, result any, failure string, blocked bool) *UnchangedObservation {
	if blocked {
		return nil
	}
	meta := planned.meta
	if planned.claimedRead && failure != "" {
		s.Repetition.ReleaseRead(planned.fingerprint)
	}
	scope := ""
	if planned.isReadOnly {
		scope = meta.StateScope
	}
	observed := s.Repetition.Observe(planned.call.Name, planned.call.Arguments, result, failure, scope)
	// A write that came out exactly like the last one changed nothing, so the
	// reads that depend on it still stand.
	repeated := !planned.isReadOnly && observed.UnchangedCount >= 2
	if !planned.isReadOnly && !repeated {
		s.Repetition.NoteStateChanged(meta.StateScope)
		// Sub-agents work in the same workspace.
		if meta.Group == "agents" {
			s.Repetition.NoteStateChanged("workspace")
		}
	} else if meta.SideEffect == "navigation" && !repeated {
		s.Repetition.NoteStateChanged(meta.StateScope)
	}
	return &observed
}

// sentMessageText is what a send_message put in front of the user, for the run's
// terminal answer.
func sentMessageText(call Call, result any) (text string, noResponse bool) {
	sent := textx.Trim(dyn.Str(or(call.Arguments["content"], call.Arguments["message"], call.Arguments["text"], dyn.Get(result, "content"), "")))
	if sent == "[NO RESPONSE]" || dyn.Get(result, "reason") == "no_response" || call.Arguments["purpose"] == "no_response" {
		return "", true
	}
	return sent, false
}

func (s *Session) runToolCall(ctx context.Context, planned *plannedCall, shaped *sync.Mutex) callOutcome {
	call, definition, meta := planned.call, planned.definition, planned.meta
	shaped.Lock()
	s.StepIndex++
	stepIndex := s.StepIndex
	shaped.Unlock()

	// What is approved, logged and run must be what a person can read, in the
	// types the tool declared.
	args := ScrubInvisibleDeep(call.Arguments).(map[string]any)
	if definition != nil {
		args = tools.CoerceArgs(args, definition.Parameters)
	}
	call.Arguments, planned.call.Arguments = args, args
	planned.isReadOnly = tools.IsReadOnlyCall(meta, args)
	scope := meta.StateScope
	planned.fingerprint = s.Repetition.Fingerprint(call.Name, args, scope)

	stepID := s.Env.Journal.StepStart(s, StepStart{
		Index: stepIndex, Type: s.Shaper.Tools.StepType(call.Name, definition), ToolName: call.Name, Input: args,
		Description: call.Name + ": " + textx.Head(dyn.Stringify(args), 200),
	})
	s.Env.Journal.ToolStart(s, stepID, call)

	var (
		result       any
		errorMessage string
		blocked      bool
		suppressed   bool
	)
	review := s.reviewCall(ctx, planned, stepIndex)
	if review.allowed {
		// Rollback undoing itself would only confuse what the run owns.
		var started any
		if s.Env.Checkpoints != nil && !planned.isReadOnly && (meta.Group == "files" || meta.Group == "shell") && call.Name != "workspace_rollback" {
			started = s.Env.Checkpoints.Begin(ctx, s, call, meta)
		}
		var err error
		result, err = s.Env.Tools.Execute(ctx, s, call, stepID)
		if err != nil {
			errorMessage = err.Error()
			result = dyn.Map{"error": errorMessage}
		}
		if started != nil {
			s.Env.Checkpoints.Record(ctx, s, started)
		}
	} else {
		result, errorMessage, suppressed, blocked = review.result, review.message, review.suppressed, true
	}

	// Tools report most failures in the result rather than by throwing.
	reported := ""
	if errorMessage == "" && !suppressed {
		reported = s.Shaper.inferToolFailureMessage(call.Name, result)
		if reported != "" {
			errorMessage = reported
		}
	}
	success := errorMessage == ""

	execution := s.Shaper.ClassifyToolExecution(call.Name, args, result, errorMessage, definition)
	if !blocked && !planned.isReadOnly {
		s.Evidence.LastActionFailed = ""
		if !success {
			s.Evidence.LastActionFailed = call.Name + ": " + textx.Head(errorMessage, 200)
		}
	}
	// A blocked call never ran; observing it would reset the streak and let the
	// next identical call through.
	failure := reported
	if failure == "" && errorMessage != "" && !blocked {
		failure = errorMessage
	}
	observed := s.observeOutcome(planned, result, failure, blocked)
	// A mutation repeated with identical arguments and an identical result
	// changed nothing: the first call already made that change.
	repeatedMutation := execution.StateChanged && observed != nil && observed.UnchangedCount >= 2
	progressed := !blocked && !repeatedMutation && (execution.StateChanged || GatheredNewEvidence(&execution, observed))

	testResult := s.testResult(meta, args, result)
	if testResult != nil {
		failed, _ := dyn.Int(testResult.Get("failed"))
		s.Evidence.LastTestFailed = ""
		if failed > 0 {
			s.Evidence.LastTestFailed = dyn.String(testResult.Get("summary"))
		}
		s.LastCheck = textx.Head(dyn.Str(or(args["command"], dyn.Get(result, "command"), call.Name)), 120) + ": " + dyn.String(testResult.Get("summary"))
	}

	shown := result
	if repeatedMutation {
		merged := dyn.Map{}
		for k, v := range dyn.Obj(result) {
			merged[k] = v
		}
		merged["repeated_call"] = "Identical to your previous call: same arguments, same result, nothing changed."
		shown = merged
	}
	limits := s.Guards.Policy.ResolveToolResultLimits(meta)
	compacted := s.Shaper.CompactToolResult(call.Name, args, shown, ResultOptions{
		SoftLimit: limits.Soft, HardLimit: limits.Hard,
		RetainFullResult: func(payload any) *RetainedResult {
			if s.Env.Retain == nil {
				return nil
			}
			return s.Env.Retain(s, call, stepID, payload)
		},
	})

	status := "completed"
	if !success {
		status = "failed"
		if ctx.Err() != nil {
			status = "interrupted" // cut off by a restart or a stop, it may or may not have taken effect
		}
	}
	stored := result
	if call.Name == "execute_command" {
		stored = compacted
	}
	s.Env.Journal.StepEnd(s, stepID, StepEnd{Status: status, Result: stored, Error: errorMessage, Blocked: blocked, Suppressed: suppressed,
		ReadOnly: planned.isReadOnly, Progressed: progressed, Fingerprint: planned.fingerprint, Shown: compacted, Test: testResult})
	s.Env.Journal.ToolEnd(s, stepID, call, compacted, errorMessage)

	outcome := callOutcome{call: call, meta: meta, success: success, suppressed: suppressed, progressed: progressed, execution: execution, fingerprint: planned.fingerprint}
	if call.Name == "send_message" && success {
		outcome.sentMessage, _ = sentMessageText(call, result)
	}
	// A text reply in the very chat a messaging run answers. Files can come as a
	// series of sends, so a reply that carries one does not end the run.
	outcome.answeredOrigin = success && dyn.Get(result, "originDelivery") == true && s.TriggerSource == "messaging" &&
		!dyn.Truthy(args["media_path"]) && !dyn.Truthy(args["media_url"])
	outcome.toolMessage = llm.Message{Role: "tool", Name: call.Name, ToolCallID: call.ID, Content: ScrubInvisible(compacted)}
	return outcome
}

// testResult is the readable test report of a call, if it ran tests.
func (s *Session) testResult(meta tools.Meta, args dyn.Map, result any) dyn.Ordered {
	if report := dyn.Obj(dyn.Get(result, "test_result")); report != nil {
		ordered := dyn.Ordered{}
		for _, k := range dyn.SortedKeys(report) {
			ordered = append(ordered, dyn.KV{Key: k, Value: report[k]})
		}
		return ordered
	}
	if meta.Group != "shell" {
		return nil
	}
	return ParseTestOutput(dyn.Str(args["command"]), dyn.Str(dyn.Get(result, "stdout")), dyn.Str(dyn.Get(result, "stderr")))
}

// executeToolTurn runs one assistant turn's tool calls and appends the calls and
// results to the transcript. Read-only calls overlap only while they are
// contiguous in model order; a mutation is a barrier, so read, edit, verify-read
// keeps the order the model asked for.
func (s *Session) executeToolTurn(ctx context.Context, decision Decision) (ToolTurnOutcome, error) {
	assistant := llm.Message{Role: "assistant", ReasoningState: decision.ReasoningState, ProviderContentBlocks: decision.ProviderContentBlocks}
	if decision.Content != "" {
		assistant.Content = SanitizeModelOutput(decision.Content, s.Env.Sanitize)
	} else {
		assistant.Content = ""
	}
	for _, call := range decision.ToolCalls {
		assistant.ToolCalls = append(assistant.ToolCalls, wireToolCall(call))
	}
	s.Messages = append(s.Messages, assistant)

	planned := make([]*plannedCall, len(decision.ToolCalls))
	for i, call := range decision.ToolCalls {
		def := s.definitionFor(call.Name)
		planned[i] = &plannedCall{call: call, definition: def, meta: s.Shaper.Tools.Meta(call.Name, def)}
	}

	var outcomes []callOutcome
	var mu sync.Mutex
	err := ScheduleToolCalls(ctx, planned,
		func(p *plannedCall) bool { return tools.IsParallelSafeCall(p.meta, p.call.Arguments) },
		func(ctx context.Context, p *plannedCall) (callOutcome, error) { return s.runToolCall(ctx, p, &mu), nil },
		func(outcome callOutcome, _ *plannedCall) {
			outcomes = append(outcomes, outcome)
			s.Executions = append(s.Executions, outcome.execution)
			s.Messages = append(s.Messages, outcome.toolMessage)
		}, s.Options.MaxParallelToolCalls)
	if err != nil {
		return ToolTurnOutcome{}, err
	}

	// Coding guidance costs nothing until a run actually touches the workspace.
	if !s.codingGuidanceSent {
		for _, o := range outcomes {
			if o.meta.Group == "files" || o.meta.Group == "shell" {
				s.codingGuidanceSent = true
				s.Messages = append(s.Messages, llm.Message{Role: "system", Content: prompts.Render("capabilities/coding.md", nil)})
				break
			}
		}
	}

	// A turn that only delivers a message the model marked as the end of its work,
	// or that only replies in the chat the run answers, is that run's answer: the
	// message already reached the user, and a status that is not the end goes
	// through send_interim_update. Without this every chat reply cost a second
	// model call that could only repeat it.
	terminalSend := len(outcomes) > 0
	for _, o := range outcomes {
		purpose := strings.ToLower(textx.Trim(dyn.Str(o.call.Arguments["purpose"])))
		terminalSend = terminalSend && o.call.Name == "send_message" && o.success && (o.answeredOrigin || slices.Contains(terminalSendPurposes, purpose))
	}

	out := ToolTurnOutcome{AllFailed: len(outcomes) > 0}
	var keys, sent []string
	for _, o := range outcomes {
		out.Progressed = out.Progressed || o.progressed
		out.AllFailed = out.AllFailed && !o.success && !o.suppressed
		keys = append(keys, o.fingerprint)
		if o.sentMessage != "" {
			sent = append(sent, o.sentMessage)
		}
	}
	slices.Sort(keys)
	out.ActionKey = strings.Join(keys, ",")
	if terminalSend {
		// A no_response send is the model choosing silence, which the delivery
		// paths already know as the [NO RESPONSE] answer.
		answer := strings.Join(sent, "\n\n")
		if answer == "" {
			answer = "[NO RESPONSE]"
		}
		out.TerminalAnswer = &answer
	}
	return out, nil
}
