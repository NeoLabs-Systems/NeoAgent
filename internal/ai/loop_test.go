package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"iter"
	"slices"
	"strings"
	"sync"
	"testing"

	"github.com/NeoLabs-Systems/neolabs-go/llm"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
)

// turn is one scripted model answer: text, tool calls, or an error.
type turn struct {
	text   string
	tools  []scriptedCall
	tokens int
	err    error
	empty  bool
}

type scriptedCall struct {
	name string
	args dyn.Map
}

type request struct {
	messages []llm.Message
	tools    []llm.Tool
}

// fakeProvider replays a script, recording what it was asked.
type fakeProvider struct {
	mu       sync.Mutex
	script   []turn
	requests []request
	window   int
}

func (p *fakeProvider) Name() string                                { return "fake" }
func (p *fakeProvider) Models(context.Context) ([]llm.Model, error) { return nil, nil }
func (p *fakeProvider) SupportsVision() bool                        { return false }
func (p *fakeProvider) ContextWindow(string) int                    { return p.window }
func (p *fakeProvider) next(msgs []llm.Message, ts []llm.Tool) (turn, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.requests = append(p.requests, request{append([]llm.Message{}, msgs...), ts})
	if len(p.script) == 0 {
		return turn{}, fmt.Errorf("script exhausted after %d requests", len(p.requests))
	}
	t := p.script[0]
	p.script = p.script[1:]
	return t, t.err
}

func (p *fakeProvider) Chat(_ context.Context, msgs []llm.Message, ts []llm.Tool, _ llm.Options) (*llm.Result, error) {
	t, err := p.next(msgs, ts)
	if err != nil {
		return nil, err
	}
	return &llm.Result{Content: t.text, ToolCalls: t.calls(), Usage: &llm.Usage{InputTokens: t.tokens}}, nil
}

func (t turn) calls() []llm.ToolCall {
	var out []llm.ToolCall
	for i, c := range t.tools {
		args, _ := json.Marshal(c.args)
		out = append(out, llm.ToolCall{ID: fmt.Sprintf("call_%d", i+1), Type: "function", Function: llm.FunctionCall{Name: c.name, Arguments: string(args)}})
	}
	return out
}

func (p *fakeProvider) Stream(_ context.Context, msgs []llm.Message, ts []llm.Tool, _ llm.Options) iter.Seq2[llm.Event, error] {
	return func(yield func(llm.Event, error) bool) {
		t, err := p.next(msgs, ts)
		if err != nil {
			yield(llm.Event{}, err)
			return
		}
		if t.text != "" && !yield(llm.Event{Type: llm.EventContent, Content: t.text}, nil) {
			return
		}
		kind := llm.EventDone
		if len(t.tools) > 0 {
			kind = llm.EventToolCalls
		}
		yield(llm.Event{Type: kind, Content: t.text, ToolCalls: t.calls(), Usage: &llm.Usage{InputTokens: t.tokens}}, nil)
	}
}

type noControls struct{ pendingSteering bool }

func (noControls) Aborted() bool                             { return false }
func (noControls) Terminal() (bool, string)                  { return false, "" }
func (noControls) Heartbeat()                                {}
func (noControls) PendingControl() (string, string)          { return "", "" }
func (noControls) Checkpoint(context.Context, string) string { return "" }
func (noControls) Interrupt(string)                          {}
func (noControls) ApplySteering(*Session)                    {}
func (noControls) OpenSteeringIntake(bool)                   {}
func (c noControls) HasPendingSteering() bool                { return c.pendingSteering }

type fakeModels struct {
	failed   []string
	fallback *fakeProvider
}

func (m *fakeModels) Failed(_ context.Context, id string, err error) { m.failed = append(m.failed, id) }
func (m *fakeModels) Succeeded(context.Context, string)              {}
func (m *fakeModels) ShouldSwitch(err error) bool                    { return m.fallback != nil }
func (m *fakeModels) Switch(_ context.Context, s *Session, _ error) (bool, error) {
	if m.fallback == nil {
		return false, nil
	}
	s.Model = ModelHandle{Provider: m.fallback, ProviderName: "fake2", Model: "m2", SelectionID: "fake2::m2"}
	m.fallback = nil
	return true, nil
}

type recordingJournal struct {
	mu    sync.Mutex
	steps []StepEnd
	order []string
}

func (j *recordingJournal) Phase(string, string) {}
func (j *recordingJournal) Stream(string, int)   {}
func (j *recordingJournal) Publish(eventType string, _ map[string]any) {
	j.mu.Lock()
	j.order = append(j.order, "event:"+eventType)
	j.mu.Unlock()
}
func (j *recordingJournal) StepStart(_ *Session, step StepStart) string {
	return fmt.Sprintf("step-%d", step.Index)
}
func (j *recordingJournal) StepEnd(_ *Session, _ string, end StepEnd) {
	j.mu.Lock()
	j.steps = append(j.steps, end)
	j.mu.Unlock()
}
func (j *recordingJournal) ToolStart(*Session, string, Call)               {}
func (j *recordingJournal) ToolEnd(*Session, string, Call, string, string) {}

type fakeBackend struct {
	mu      sync.Mutex
	results map[string]func(dyn.Map) any
	calls   []Call
}

func (b *fakeBackend) Execute(_ context.Context, _ *Session, call Call, _ string) (any, error) {
	b.mu.Lock()
	b.calls = append(b.calls, call)
	b.mu.Unlock()
	if fn, ok := b.results[call.Name]; ok {
		return fn(call.Arguments), nil
	}
	return dyn.Map{"success": true}, nil
}

func (b *fakeBackend) names() []string {
	var out []string
	for _, c := range b.calls {
		out = append(out, c.Name)
	}
	return out
}

type testFormatting struct{}

func (testFormatting) Guide(string) string { return "Reply formatting guide:" }

type rig struct {
	session  *Session
	provider *fakeProvider
	backend  *fakeBackend
	models   *fakeModels
	journal  *recordingJournal
	controls noControls
}

func fixedResult(v any) func(dyn.Map) any { return func(dyn.Map) any { return v } }

func newRig(t *testing.T, script []turn, results map[string]func(dyn.Map) any) *rig {
	t.Helper()
	shaper := testShaper(t)
	provider := &fakeProvider{script: script, window: 128000}
	backend := &fakeBackend{results: results}
	models := &fakeModels{}
	journal := &recordingJournal{}
	r := &rig{provider: provider, backend: backend, models: models, journal: journal}
	user := int64(1)
	definitions := shaper.Tools.Available(tools.Options{UserID: &user, TriggerType: "user", TriggerSource: "web"})
	s := &Session{
		RunID: "run-1", UserID: 1, UserMessage: "do the thing", TriggerType: "user", TriggerSource: "web",
		Tools: definitions, Catalog: definitions,
		Model:          ModelHandle{Provider: provider, ProviderName: "fake", Model: "m1", SelectionID: "fake::m1"},
		Guards:         NewRunGuards(nil, nil),
		Pressure:       &ContextPressure{Summarize: func(context.Context, []llm.Message) (string, error) { return "summary", nil }},
		Repetition:     NewToolRepetitionGuard(0, nil),
		Shaper:         shaper,
		FailedModelIDs: map[string]bool{},
		Messages:       []llm.Message{{Role: "system", Content: "system prompt"}, {Role: "user", Content: "do the thing"}},
	}
	s.Env = Env{Controls: &r.controls, Models: models, Tools: backend, Journal: journal}
	r.session = s
	return r
}

func (r *rig) run(t *testing.T) LoopResult {
	t.Helper()
	result, err := RunAgentLoop(context.Background(), r.session)
	if err != nil {
		t.Fatal(err)
	}
	return result
}

func say(text string) turn                { return turn{text: text} }
func call(name string, args dyn.Map) turn { return turn{tools: []scriptedCall{{name, args}}} }
func lastToolMessage(s *Session) string {
	for i := len(s.Messages) - 1; i >= 0; i-- {
		if s.Messages[i].Role == "tool" {
			return dyn.Str(s.Messages[i].Content)
		}
	}
	return ""
}

func TestToolCallWrittenAsTextIsNotAnAnswer(t *testing.T) {
	r := newRig(t, []turn{say("assistant to=ls -la /tmp/project </rfl:parameter>"), say("The real answer.")}, nil)
	got := r.run(t)
	if got.Type != "answer" || got.Content != "The real answer." || len(r.provider.requests) != 2 {
		t.Errorf("%+v after %d requests", got, len(r.provider.requests))
	}
}

func TestRawToolCallNeverReachesTheUser(t *testing.T) {
	r := newRig(t, []turn{
		say(`<tool_call>{"name":"ls"}</tool_call>`),
		say(`{"name": "web_search", "arguments": {"query": "x"}}`),
		say(`assistant to=web_search {"query":"x"}`),
		say("I could not get that done: the model kept failing to call the tool."),
	}, nil)
	got := r.run(t)
	if got.Type != "wrap_up" || got.Reason != "malformed_output" {
		t.Fatalf("expected a wrap-up, got %+v", got)
	}
	text, err := WriteWrapUp(context.Background(), r.session, got.Reason, &llm.Message{Role: "user", Content: "Look it up"}, testFormatting{})
	if err != nil || !strings.Contains(text, "could not get that done") {
		t.Errorf("wrap-up %q %v", text, err)
	}
	last := r.provider.requests[len(r.provider.requests)-1]
	if len(last.tools) != 0 {
		t.Error("the wrap-up turn must offer no tools")
	}
}

func TestFailedActionIsRaisedBeforeFinishing(t *testing.T) {
	r := newRig(t, []turn{
		call("create_task", dyn.Map{"name": "x", "prompt": "y"}),
		say("Done, the reminder is set."),
		say("I could not set the reminder."),
	}, map[string]func(dyn.Map) any{"create_task": fixedResult(dyn.Map{"error": "scheduler offline"})})
	got := r.run(t)
	if got.Content != "I could not set the reminder." || len(r.provider.requests) != 3 {
		t.Fatalf("%+v after %d requests", got, len(r.provider.requests))
	}
	noted := false
	for _, m := range r.provider.requests[2].messages {
		text := dyn.Str(m.Content)
		noted = noted || strings.Contains(text, "scheduler offline") && strings.Contains(text, "Before you finish")
	}
	if !noted {
		t.Error("the failed action should have been raised in a system note")
	}
}

func TestHealthyRunGetsNoExtraTurn(t *testing.T) {
	r := newRig(t, []turn{call("create_task", dyn.Map{"name": "x", "prompt": "y"}), say("The reminder is set.")},
		map[string]func(dyn.Map) any{"create_task": fixedResult(dyn.Map{"success": true, "id": 1})})
	got := r.run(t)
	if got.Content != "The reminder is set." || len(r.provider.requests) != 2 {
		t.Errorf("%+v after %d requests", got, len(r.provider.requests))
	}
}

func TestALimitedRunCannotCallOtherTools(t *testing.T) {
	r := newRig(t, []turn{call("execute_command", dyn.Map{"command": "echo hi"}), say("done")},
		map[string]func(dyn.Map) any{"execute_command": fixedResult(dyn.Map{"stdout": "RAN", "exitCode": 0})})
	r.session.Options.Tools = tools.RunOptions{AllowedToolNames: []string{"read_file"}}
	r.run(t)
	if len(r.backend.calls) != 0 || !strings.Contains(lastToolMessage(r.session), "execute_command is not available to this run.") {
		t.Errorf("ran %v; told %q", r.backend.names(), lastToolMessage(r.session))
	}
}

func TestAReadOnlyRunCannotChangeAnything(t *testing.T) {
	r := newRig(t, []turn{
		{tools: []scriptedCall{{"execute_command", dyn.Map{"command": "rm -rf build"}}, {"execute_command", dyn.Map{"command": "ls -la"}}}},
		say("done"),
	}, map[string]func(dyn.Map) any{"execute_command": fixedResult(dyn.Map{"stdout": "RAN", "exitCode": 0})})
	r.session.Options.Tools = tools.RunOptions{ReadOnly: true}
	r.run(t)
	// No shell at all: nothing can tell for certain that a command only reads.
	if len(r.backend.calls) != 0 {
		t.Errorf("ran %v", r.backend.names())
	}
}

func TestTokenBudgetEndsTheRun(t *testing.T) {
	r := newRig(t, []turn{
		{tools: []scriptedCall{{"read_file", dyn.Map{"path": "a"}}}, tokens: 120},
		{tools: []scriptedCall{{"read_file", dyn.Map{"path": "b"}}}, tokens: 120},
		say("Stopped: I ran out of budget."),
	}, map[string]func(dyn.Map) any{"read_file": fixedResult(dyn.Map{"content": "x"})})
	r.session.Guards = NewRunGuards(nil, dyn.Map{"maxTotalTokens": float64(100)})
	got := r.run(t)
	if got.Type != "wrap_up" || got.Reason != "token_budget" || len(r.backend.calls) != 1 {
		t.Fatalf("%+v with %d calls", got, len(r.backend.calls))
	}
	text, err := WriteWrapUp(context.Background(), r.session, got.Reason, nil, testFormatting{})
	if err != nil || !strings.Contains(text, "ran out") {
		t.Errorf("wrap-up %q %v", text, err)
	}
}

func TestAToolFailingTheSameWayRests(t *testing.T) {
	calls := 0
	r := newRig(t, []turn{
		call("web_search", dyn.Map{"query": "a"}), call("web_search", dyn.Map{"query": "b"}),
		call("web_search", dyn.Map{"query": "c"}), call("web_search", dyn.Map{"query": "d"}),
		say("Search is unavailable right now."),
	}, map[string]func(dyn.Map) any{"web_search": func(dyn.Map) any {
		calls++
		return dyn.Map{"error": "No search model can take this request right now."}
	}})
	got := r.run(t)
	if calls != 3 || got.Content != "Search is unavailable right now." {
		t.Errorf("ran %d times: %+v", calls, got)
	}
	if !strings.Contains(lastToolMessage(r.session), "failed 3 times in a row") {
		t.Errorf("the model should be told the tool rests: %s", lastToolMessage(r.session))
	}
}

func TestALocalToolFailingTheSameWayIsNotPutToRest(t *testing.T) {
	var asked []string
	r := newRig(t, []turn{
		call("read_file", dyn.Map{"path": "a.py"}), call("read_file", dyn.Map{"path": "b.py"}),
		call("read_file", dyn.Map{"path": "c.py"}), call("read_file", dyn.Map{"path": "src/main.py"}),
		say("Found it in src/main.py."),
	}, map[string]func(dyn.Map) any{"read_file": func(args dyn.Map) any {
		asked = append(asked, dyn.Str(args["path"]))
		if args["path"] == "src/main.py" {
			return dyn.Map{"path": "src/main.py", "content": "main()"}
		}
		return dyn.Map{"error": "Workspace path does not exist."}
	}})
	r.run(t)
	if len(asked) != 4 {
		t.Errorf("read %v", asked)
	}
}

func TestACallMissingARequiredArgumentIsAnsweredAndTheFixedOneRuns(t *testing.T) {
	script := strings.Repeat("import pcbnew\n", 200)
	var written []string
	r := newRig(t, []turn{
		call("write_file", dyn.Map{"content": script}),
		call("write_file", dyn.Map{"content": script + "# v2\n"}),
		call("write_file", dyn.Map{"content": script + "# v2\n"}),
		call("write_file", dyn.Map{"path": "pcbtest/gen_pcb.py", "content": script + "# v2\n"}),
		say("Wrote pcbtest/gen_pcb.py."),
	}, map[string]func(dyn.Map) any{"write_file": func(args dyn.Map) any {
		written = append(written, dyn.Str(args["path"]))
		return dyn.Map{"success": true, "path": args["path"]}
	}})
	r.run(t)
	if len(written) != 1 || written[0] != "pcbtest/gen_pcb.py" {
		t.Fatalf("tool ran for %v", written)
	}
	first := r.journal.steps[0].Error
	if !strings.Contains(first, "needs path") || !strings.Contains(first, "sent content") {
		t.Errorf("first answer: %s", first)
	}
}

func TestAReplyInTheChatEndsTheRun(t *testing.T) {
	r := newRig(t, []turn{
		call("send_message", dyn.Map{"platform": "telegram", "to": "chat-1", "content": "Hey, alles gut hier."}),
		say("Hey, alles gut hier."),
	}, map[string]func(dyn.Map) any{"send_message": fixedResult(dyn.Map{"success": true, "originDelivery": true})})
	r.session.TriggerSource = "messaging"
	got := r.run(t)
	if got.Type != "answer" || got.Content != "Hey, alles gut hier." || len(r.provider.requests) != 1 {
		t.Errorf("%+v after %d requests", got, len(r.provider.requests))
	}
}

func TestATerminalPurposeSendIsTheAnswer(t *testing.T) {
	r := newRig(t, []turn{
		call("send_message", dyn.Map{"platform": "telegram", "to": "chat-1", "content": "Report ready.", "purpose": "final_result"}),
	}, nil)
	got := r.run(t)
	if got.Type != "answer" || got.Content != "Report ready." {
		t.Errorf("%+v", got)
	}
}

func TestBlankTurnsRecoverOnAnotherModel(t *testing.T) {
	second := &fakeProvider{script: []turn{say("Recovered answer.")}, window: 128000}
	r := newRig(t, []turn{{empty: true}}, nil)
	r.models.fallback = second
	got := r.run(t)
	if got.Content != "Recovered answer." || !slices.Equal(r.models.failed, []string{"fake::m1"}) || r.session.Model.SelectionID != "fake2::m2" {
		t.Errorf("%+v failed=%v model=%s", got, r.models.failed, r.session.Model.SelectionID)
	}
	nudged := false
	for _, m := range second.requests[0].messages {
		nudged = nudged || strings.Contains(dyn.Str(m.Content), "returned no user-facing answer")
	}
	if !nudged {
		t.Error("the fallback model should be told the turn was empty")
	}
}

func TestBlankOutputWrapsUpAfterRepeatedBlanks(t *testing.T) {
	r := newRig(t, []turn{{empty: true}, {empty: true}, {empty: true}}, nil)
	if got := r.run(t); got.Type != "wrap_up" || got.Reason != "blank_output" {
		t.Errorf("%+v", got)
	}
}

func TestProviderFailureSwitchesModel(t *testing.T) {
	second := &fakeProvider{script: []turn{say("Answer from the fallback.")}, window: 128000}
	r := newRig(t, []turn{{err: &llm.Error{Status: 503, Message: "overloaded", Retryable: true}}}, nil)
	r.models.fallback = second
	got := r.run(t)
	if got.Content != "Answer from the fallback." || !slices.Equal(r.models.failed, []string{"fake::m1"}) {
		t.Errorf("%+v failed=%v", got, r.models.failed)
	}
}

func TestProviderFailureWithoutFallbackIsReturned(t *testing.T) {
	r := newRig(t, []turn{{err: &llm.Error{Status: 400, Message: "bad request"}}}, nil)
	if _, err := RunAgentLoop(context.Background(), r.session); err == nil || !strings.Contains(err.Error(), "bad request") {
		t.Errorf("error %v", err)
	}
}

func TestTruncatedAnswerAsksForContinuation(t *testing.T) {
	r := newRig(t, []turn{say("half a thou"), say("A complete thought.")}, nil)
	r.provider.script[0] = turn{text: "half a thou"}
	// Mark the first turn truncated through the streamed final event.
	got, err := func() (LoopResult, error) {
		truncating := &truncatingProvider{fakeProvider: r.provider}
		r.session.Model.Provider = truncating
		return RunAgentLoop(context.Background(), r.session)
	}()
	if err != nil || got.Content != "A complete thought." || len(r.provider.requests) != 2 {
		t.Errorf("%+v %v after %d requests", got, err, len(r.provider.requests))
	}
}

type truncatingProvider struct {
	*fakeProvider
	done bool
}

func (p *truncatingProvider) Stream(ctx context.Context, msgs []llm.Message, ts []llm.Tool, o llm.Options) iter.Seq2[llm.Event, error] {
	inner := p.fakeProvider.Stream(ctx, msgs, ts, o)
	first := !p.done
	p.done = true
	return func(yield func(llm.Event, error) bool) {
		for e, err := range inner {
			if first && e.Type == llm.EventDone {
				e.Truncated = true
			}
			if !yield(e, err) {
				return
			}
		}
	}
}

func TestContextOverflowCompactsAndRetries(t *testing.T) {
	r := newRig(t, []turn{{err: &llm.Error{Code: "context_length_exceeded", Message: "prompt is too long"}}, say("Answer after compaction.")}, nil)
	var messages []llm.Message
	messages = append(messages, llm.Message{Role: "system", Content: "system prompt"})
	for i := 0; i < 6; i++ {
		messages = append(messages, llm.Message{Role: "user", Content: fmt.Sprintf("question %d %s", i, strings.Repeat("q", 400))},
			llm.Message{Role: "assistant", Content: fmt.Sprintf("answer %d %s", i, strings.Repeat("a", 400))})
	}
	r.session.Messages = messages
	r.provider.window = 128000
	got := r.run(t)
	if got.Content != "Answer after compaction." {
		t.Fatalf("%+v", got)
	}
	compacted := false
	for _, m := range r.provider.requests[1].messages {
		compacted = compacted || strings.HasPrefix(dyn.Str(m.Content), SummaryPrefix)
	}
	if !compacted {
		t.Error("the retry should carry a summary in place of the old turns")
	}
}

func TestPersistentStallRetriesTheSameModelThenFails(t *testing.T) {
	timeout := &llm.Error{Code: "MODEL_CALL_TIMEOUT", Message: "timed out"}
	r := newRig(t, []turn{{err: timeout}, {err: timeout}, say("Finally.")}, nil)
	got := r.run(t)
	if got.Content != "Finally." || len(r.provider.requests) != 3 {
		t.Errorf("%+v after %d requests", got, len(r.provider.requests))
	}
}

func TestParallelReadsRunTogetherAndOutcomesKeepModelOrder(t *testing.T) {
	r := newRig(t, []turn{
		{tools: []scriptedCall{{"read_file", dyn.Map{"path": "a"}}, {"read_file", dyn.Map{"path": "b"}}, {"write_file", dyn.Map{"path": "c", "content": "x"}}, {"read_file", dyn.Map{"path": "c"}}}},
		say("done"),
	}, map[string]func(dyn.Map) any{"read_file": func(args dyn.Map) any {
		return dyn.Map{"path": args["path"], "content": "text of " + dyn.Str(args["path"])}
	}})
	r.run(t)
	var order []string
	for _, m := range r.session.Messages {
		if m.Role == "tool" {
			order = append(order, m.ToolCallID)
		}
	}
	if !slices.Equal(order, []string{"call_1", "call_2", "call_3", "call_4"}) {
		t.Errorf("tool results out of order: %v", order)
	}
}

func TestRecoveryNoteAfterRepeatedFailures(t *testing.T) {
	r := newRig(t, []turn{
		call("create_task", dyn.Map{"name": "a", "prompt": "y"}), call("create_task", dyn.Map{"name": "b", "prompt": "y"}),
		call("create_task", dyn.Map{"name": "c", "prompt": "y"}), say("Giving up: the scheduler is offline."), say("Giving up: the scheduler is offline."),
	}, map[string]func(dyn.Map) any{"create_task": fixedResult(dyn.Map{"error": "scheduler offline"})})
	r.session.Goal = func() string { return "set a reminder" }
	r.run(t)
	found := false
	for _, m := range r.session.Messages {
		text := dyn.Str(m.Content)
		found = found || strings.HasPrefix(text, "[Recovery]") && strings.Contains(text, "set a reminder") && strings.Contains(text, "scheduler offline")
	}
	if !found {
		t.Error("two failed turns in a row should add a recovery note")
	}
}

func TestToolsAreOfferedToTheProviderAsCompactDefinitions(t *testing.T) {
	r := newRig(t, []turn{say("hi")}, nil)
	r.run(t)
	offered := r.provider.requests[0].tools
	if len(offered) == 0 || offered[0].Name == "" || offered[0].Description == "" {
		t.Errorf("tools %+v", offered)
	}
}
