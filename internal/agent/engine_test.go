package agent

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"iter"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// scriptedProvider answers model turns from a script: each turn is either text
// or tool calls.
type scriptedProvider struct {
	mu    sync.Mutex
	turns []llm.Event
	seen  [][]llm.Message
	block chan struct{}
}

func (p *scriptedProvider) Name() string                                { return "fake" }
func (p *scriptedProvider) Models(context.Context) ([]llm.Model, error) { return nil, nil }
func (p *scriptedProvider) ContextWindow(string) int                    { return 128000 }
func (p *scriptedProvider) SupportsVision() bool                        { return false }

func (p *scriptedProvider) next(msgs []llm.Message) (llm.Event, bool) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.seen = append(p.seen, append([]llm.Message(nil), msgs...))
	if len(p.turns) == 0 {
		return llm.Event{}, false
	}
	turn := p.turns[0]
	p.turns = p.turns[1:]
	return turn, true
}

func (p *scriptedProvider) Chat(ctx context.Context, msgs []llm.Message, _ []llm.Tool, _ llm.Options) (*llm.Result, error) {
	turn, ok := p.next(msgs)
	if !ok {
		return &llm.Result{Content: "summary"}, nil
	}
	return &llm.Result{Content: turn.Content, ToolCalls: turn.ToolCalls, Usage: turn.Usage}, nil
}

func (p *scriptedProvider) Stream(ctx context.Context, msgs []llm.Message, _ []llm.Tool, _ llm.Options) iter.Seq2[llm.Event, error] {
	return func(yield func(llm.Event, error) bool) {
		if p.block != nil {
			select {
			case <-p.block:
			case <-ctx.Done():
				yield(llm.Event{}, ctx.Err())
				return
			}
		}
		turn, ok := p.next(msgs)
		if !ok {
			yield(llm.Event{}, errors.New("script exhausted"))
			return
		}
		if turn.Content != "" && len(turn.ToolCalls) == 0 {
			if !yield(llm.Event{Type: llm.EventContent, Content: turn.Content}, nil) {
				return
			}
		}
		turn.Type = llm.EventDone
		if len(turn.ToolCalls) > 0 {
			turn.Type = llm.EventToolCalls
		}
		yield(turn, nil)
	}
}

type fakeSettings struct{}

func (fakeSettings) AISettings(context.Context, int64, string) (dyn.Map, error) {
	return dyn.Map{"chat_history_window": float64(20), "default_chat_model": "auto", "default_subagent_model": "auto", "cost_mode": "balanced_auto", "enabled_models": []any{}}, nil
}

type fakeModels struct{ provider llm.Provider }

func (m fakeModels) Catalog(context.Context, int64, string) ([]aimodels.Model, error) {
	tools := true
	return []aimodels.Model{{ID: "fake::model-1", ModelID: "model-1", Provider: "fake", Available: true, SupportsTools: &tools, Purpose: "general", ProviderStatus: "configured"}}, nil
}
func (m fakeModels) Provider(context.Context, int64, string, aimodels.Model) (llm.Provider, error) {
	return m.provider, nil
}
func (fakeModels) IsBYOK(context.Context, int64, string, string) bool { return false }

type registryEnv struct{}

func (registryEnv) HostTerminal() bool           { return true }
func (registryEnv) WebSharingEnabled(int64) bool { return false }

type fakeTools struct{ registry *tools.Registry }

func (t fakeTools) Registry() *tools.Registry { return t.registry }
func (t fakeTools) Available(ctx context.Context, req CatalogRequest) []tools.Definition {
	uid := req.UserID
	return t.registry.Available(tools.Options{UserID: &uid, AgentID: req.AgentID, TriggerType: req.TriggerType, TriggerSource: req.TriggerSource})
}
func (fakeTools) External(context.Context, int64, string) []tools.Definition { return nil }

type fakeBackend struct {
	calls []string
	mu    sync.Mutex
}

func (b *fakeBackend) Execute(ctx context.Context, s *ai.Session, call ai.Call, stepID string) (any, error) {
	b.mu.Lock()
	b.calls = append(b.calls, call.Name)
	b.mu.Unlock()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	return map[string]any{"thought": "noted", "ok": true}, nil
}

type recordedEvent struct {
	name    string
	payload map[string]any
}

type recorder struct {
	mu     sync.Mutex
	events []recordedEvent
}

func (r *recorder) EmitToUser(_ int64, event string, payload any) {
	r.mu.Lock()
	defer r.mu.Unlock()
	m, _ := payload.(map[string]any)
	r.events = append(r.events, recordedEvent{event, m})
}

func (r *recorder) names() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]string, len(r.events))
	for i, e := range r.events {
		out[i] = e.name
	}
	return out
}

func (r *recorder) first(name string) map[string]any {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, e := range r.events {
		if e.name == name {
			return e.payload
		}
	}
	return nil
}

type stack struct {
	db       *dbx.DB
	engine   *Engine
	provider *scriptedProvider
	events   *recorder
	backend  *fakeBackend
}

func newStack(t *testing.T, turns ...llm.Event) *stack {
	t.Helper()
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'owner', 'x')`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO agents (id, user_id, slug, display_name, is_default) VALUES ('main-agent', 1, 'main', 'Main', 1)`); err != nil {
		t.Fatal(err)
	}
	registry, err := tools.NewRegistry(registryEnv{})
	if err != nil {
		t.Fatal(err)
	}
	provider := &scriptedProvider{turns: turns}
	events := &recorder{}
	backend := &fakeBackend{}
	sources := &PromptSources{DB: db}
	engine := New(Deps{
		DB: db, Emitter: events, Settings: fakeSettings{}, Models: fakeModels{provider}, Tools: fakeTools{registry},
		Agents: agentscope.Resolver{DB: db}, Prompts: &ai.SystemPrompts{Sources: sources},
		Failures: &aimodels.Failures{Store: &aimodels.HealthStore{DB: db}, Cooldowns: aimodels.DefaultCooldowns()},
		Backend:  backend, Getenv: func(string) string { return "" },
	})
	t.Cleanup(func() { engine.Shutdown("test over", time.Second) })
	return &stack{db: db, engine: engine, provider: provider, events: events, backend: backend}
}

func toolCall(id, name string, args map[string]any) llm.ToolCall {
	raw, _ := json.Marshal(args)
	return llm.ToolCall{ID: id, Type: "function", Function: llm.FunctionCall{Name: name, Arguments: string(raw)}}
}

func (s *stack) scalar(t *testing.T, query string, args ...any) string {
	t.Helper()
	var v sql.NullString
	if err := s.db.R.QueryRow(query, args...).Scan(&v); err != nil {
		t.Fatalf("%s: %v", query, err)
	}
	return v.String
}

func TestRunWithToolTurnCompletesAndDelivers(t *testing.T) {
	st := newStack(t,
		llm.Event{ToolCalls: []llm.ToolCall{toolCall("c1", "task_ledger", map[string]any{"goal": "plan"})}, Usage: &llm.Usage{InputTokens: 100, OutputTokens: 10}},
		llm.Event{Content: "All done.", Usage: &llm.Usage{InputTokens: 120, OutputTokens: 5}},
	)
	result, err := st.engine.Run(context.Background(), 1, "Do the thing", Options{RunID: "run-1"})
	if err != nil {
		t.Fatal(err)
	}
	if result.Status != "completed" || result.Content != "All done." {
		t.Fatalf("result = %+v", result)
	}
	if result.TotalTokens != 235 {
		t.Fatalf("tokens = %d", result.TotalTokens)
	}
	if got := st.scalar(t, `SELECT status || '/' || runtime_state FROM agent_runs WHERE id = 'run-1'`); got != "completed/completed" {
		t.Fatalf("run state = %s", got)
	}
	if got := st.scalar(t, `SELECT final_response FROM agent_runs WHERE id = 'run-1'`); got != "All done." {
		t.Fatalf("final_response = %q", got)
	}
	if got := st.scalar(t, `SELECT tool_name || '/' || status || '/' || COALESCE(error, '') FROM agent_steps WHERE run_id = 'run-1'`); got != "task_ledger/completed/" {
		t.Fatalf("step = %s", got)
	}
	if got := st.scalar(t, `SELECT COUNT(*) FROM agent_model_usage WHERE run_id = 'run-1'`); got != "2" {
		t.Fatalf("usage rows = %s", got)
	}
	if got := st.scalar(t, `SELECT status FROM agent_outbox WHERE run_id = 'run-1' AND message_kind = 'final'`); got != "delivered" {
		t.Fatalf("outbox = %s", got)
	}
	if st.scalar(t, `SELECT metrics_json FROM agent_runs WHERE id = 'run-1'`) == "" {
		t.Fatal("metrics were not stored")
	}
	names := strings.Join(st.events.names(), ",")
	for _, want := range []string{"run:start", "run:phase", "run:tool_start", "run:tool_end", "run:stream", "run:complete"} {
		if !strings.Contains(names, want) {
			t.Fatalf("missing %s in %s", want, names)
		}
	}
	if n := strings.Count(names, "run:complete"); n != 1 {
		t.Fatalf("run:complete sent %d times", n)
	}
	complete := st.events.first("run:complete")
	if complete["content"] != "All done." || complete["runId"] != "run-1" {
		t.Fatalf("run:complete = %v", complete)
	}
	// The ledger has the run's whole story.
	types := st.scalar(t, `SELECT group_concat(event_type, ',') FROM (SELECT event_type FROM agent_run_events WHERE run_id = 'run-1' ORDER BY sequence_index)`)
	for _, want := range []string{runledger.EventRunStarted, runledger.EventToolsSelected, runledger.EventContextBuilt, runledger.EventModelRequest,
		runledger.EventModelResponse, runledger.EventToolCall, runledger.EventToolResult, runledger.EventDeliverySent, runledger.EventRunCompleted} {
		if !strings.Contains(types, want) {
			t.Fatalf("missing %s in %s", want, types)
		}
	}
	// The model saw the persona and the request.
	first := st.provider.seen[0]
	if !strings.Contains(dyn.Str(first[0].Content), "you're texting with owner") {
		t.Fatalf("system prompt = %.200q", dyn.Str(first[0].Content))
	}
	if last := first[len(first)-1]; last.Role != "user" || last.Content != "Do the thing" {
		t.Fatalf("last message = %+v", last)
	}
}

func TestConversationRunStoresTurnsAndHistory(t *testing.T) {
	st := newStack(t, llm.Event{Content: "Hi there."}, llm.Event{Content: "Second answer."})
	if _, err := st.db.W.Exec(`INSERT INTO conversations (id, user_id, agent_id, platform) VALUES ('conv-1', 1, 'main-agent', 'web')`); err != nil {
		t.Fatal(err)
	}
	if _, err := st.engine.Run(context.Background(), 1, "Hello", Options{ConversationID: "conv-1"}); err != nil {
		t.Fatal(err)
	}
	if got := st.scalar(t, `SELECT group_concat(role || ':' || content, '|') FROM (SELECT role, content FROM conversation_messages WHERE conversation_id = 'conv-1' ORDER BY id)`); got != "user:Hello|assistant:Hi there." {
		t.Fatalf("conversation = %s", got)
	}
	if _, err := st.engine.Run(context.Background(), 1, "Again", Options{ConversationID: "conv-1", SkipGlobalRecall: true}); err != nil {
		t.Fatal(err)
	}
	second := st.provider.seen[len(st.provider.seen)-1]
	var transcript []string
	for _, m := range second {
		if m.Role != "system" {
			transcript = append(transcript, m.Role+":"+dyn.Str(m.Content))
		}
	}
	if got := strings.Join(transcript, "|"); got != "user:Hello|assistant:Hi there.|user:Again" {
		t.Fatalf("history = %s", got)
	}
}

func TestStopEndsARunningRun(t *testing.T) {
	st := newStack(t, llm.Event{Content: "never"})
	st.provider.block = make(chan struct{})
	done := make(chan Result, 1)
	go func() {
		result, err := st.engine.Run(context.Background(), 1, "Wait", Options{RunID: "run-stop"})
		if err != nil {
			t.Error(err)
		}
		done <- result
	}()
	deadline := time.Now().Add(5 * time.Second)
	for {
		if _, ok := st.engine.RunInfo("run-stop"); ok && st.scalar(t, `SELECT COUNT(*) FROM agent_run_events WHERE run_id = 'run-stop' AND event_type = 'model.request'`) != "0" {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("run never reached the model")
		}
		time.Sleep(10 * time.Millisecond)
	}
	if !st.engine.Abort("run-stop", 1, "") {
		t.Fatal("abort refused")
	}
	select {
	case result := <-done:
		if result.Status != "stopped" {
			t.Fatalf("status = %s", result.Status)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("run did not stop")
	}
	if got := st.scalar(t, `SELECT status FROM agent_runs WHERE id = 'run-stop'`); got != "stopped" {
		t.Fatalf("stored status = %s", got)
	}
	if !strings.Contains(strings.Join(st.events.names(), ","), "run:stopping") {
		t.Fatal("no run:stopping")
	}
}

func TestPauseAndResume(t *testing.T) {
	st := newStack(t, llm.Event{Content: "resumed answer"})
	st.provider.block = make(chan struct{})
	done := make(chan Result, 1)
	go func() {
		result, _ := st.engine.Run(context.Background(), 1, "Long job", Options{RunID: "run-pause"})
		done <- result
	}()
	deadline := time.Now().Add(5 * time.Second)
	for st.scalar(t, `SELECT COUNT(*) FROM agent_run_events WHERE event_type = 'model.request'`) == "0" {
		if time.Now().After(deadline) {
			t.Fatal("run never reached the model")
		}
		time.Sleep(10 * time.Millisecond)
	}
	if !st.engine.PauseRun("run-pause", 1, "hold on") {
		t.Fatal("pause refused")
	}
	for st.scalar(t, `SELECT status FROM agent_runs WHERE id = 'run-pause'`) != "paused" {
		if time.Now().After(deadline) {
			t.Fatal("run never paused")
		}
		time.Sleep(10 * time.Millisecond)
	}
	st.provider.block = nil
	if !st.engine.ResumeRun("run-pause", 1) {
		t.Fatal("resume refused")
	}
	select {
	case result := <-done:
		if result.Status != "completed" || result.Content != "resumed answer" {
			t.Fatalf("result = %+v", result)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("run did not finish after resume")
	}
}

func TestSteeringReachesTheRunningModel(t *testing.T) {
	st := newStack(t,
		llm.Event{ToolCalls: []llm.ToolCall{toolCall("c1", "task_ledger", map[string]any{"goal": "a"})}},
		llm.Event{Content: "answer with follow-up"},
	)
	st.provider.block = make(chan struct{})
	done := make(chan Result, 1)
	go func() {
		result, _ := st.engine.Run(context.Background(), 1, "First", Options{RunID: "run-steer"})
		done <- result
	}()
	deadline := time.Now().Add(5 * time.Second)
	for st.engine.FindSteerableRun(1, "web", "") == nil {
		if time.Now().After(deadline) {
			t.Fatal("no steerable run")
		}
		time.Sleep(10 * time.Millisecond)
	}
	if n := st.engine.EnqueueSteering("run-steer", "Also do B", nil); n != 1 {
		t.Fatalf("pending = %d", n)
	}
	close(st.provider.block)
	result := <-done
	if result.Status != "completed" {
		t.Fatalf("result = %+v", result)
	}
	final := st.provider.seen[len(st.provider.seen)-1]
	found := false
	for _, m := range final {
		found = found || (m.Role == "user" && m.Content == "Also do B")
	}
	if !found {
		t.Fatal("the follow-up never reached the model")
	}
	if !strings.Contains(strings.Join(st.events.names(), ","), "run:steer_applied") {
		t.Fatal("no run:steer_applied")
	}
}

func TestRecoverAndResumeInterruptedRun(t *testing.T) {
	st := newStack(t, llm.Event{Content: "picked up"})
	meta := `{"runtimeKernel":"v2","resume":{"message":"Original ask","options":{"triggerSource":"web","agentId":"main-agent"}}}`
	if _, err := st.db.W.Exec(`INSERT INTO agent_runs (id, user_id, agent_id, title, status, runtime_state, version, trigger_type, trigger_source, metadata_json, heartbeat_at)
		VALUES ('old-run', 1, 'main-agent', 'x', 'running', 'executing', 1, 'user', 'web', ?, datetime('now'))`, meta); err != nil {
		t.Fatal(err)
	}
	_, recovered := st.engine.RecoverOrphanedRuns(context.Background())
	if len(recovered) != 1 {
		t.Fatalf("recovered = %v", recovered)
	}
	if got := st.scalar(t, `SELECT status FROM agent_runs WHERE id = 'old-run'`); got != "interrupted" {
		t.Fatalf("status = %s", got)
	}
	if n := st.engine.ResumeInterruptedRuns(context.Background()); n != 1 {
		t.Fatalf("resumed = %d", n)
	}
	deadline := time.Now().Add(5 * time.Second)
	for st.scalar(t, `SELECT COUNT(*) FROM agent_runs WHERE json_extract(metadata_json, '$.resumedFromRunId') = 'old-run' AND status = 'completed'`) != "1" {
		if time.Now().After(deadline) {
			t.Fatal("the resumed run did not complete")
		}
		time.Sleep(20 * time.Millisecond)
	}
	if st.engine.ResumeInterruptedRuns(context.Background()) != 0 {
		t.Fatal("a run resumed twice")
	}
	user := st.provider.seen[0][len(st.provider.seen[0])-1]
	if !strings.Contains(dyn.Str(user.Content), "[Resumed after a restart]") || !strings.Contains(dyn.Str(user.Content), "Original ask") {
		t.Fatalf("continuation = %.200q", dyn.Str(user.Content))
	}
}
