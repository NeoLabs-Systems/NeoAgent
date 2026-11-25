package tasks

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

type stubAgents struct{}

func (stubAgents) Resolve(_ context.Context, _ int64, candidate string) (string, error) {
	if candidate == "" {
		return "main", nil
	}
	return candidate, nil
}
func (stubAgents) IsMain(_ context.Context, _ int64, agentID string) (bool, error) {
	return agentID == "" || agentID == "main", nil
}

type stubEmitter struct {
	mu     sync.Mutex
	events []string
}

func (e *stubEmitter) EmitToUser(_ int64, event string, _ any) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.events = append(e.events, event)
}

type stubEngine struct {
	mu   sync.Mutex
	runs []RunRequest
	resp RunResult
	err  error
}

func (e *stubEngine) RunTask(_ context.Context, req RunRequest) (RunResult, error) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.runs = append(e.runs, req)
	if e.err != nil {
		return RunResult{}, e.err
	}
	return e.resp, nil
}

func newTestRuntime(t *testing.T, eng Engine) (*Runtime, *dbx.DB, *stubEmitter) {
	t.Helper()
	ctx := context.Background()
	db, err := dbx.Open(ctx, t.TempDir()+"/tasks.db", dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	_, err = db.W.ExecContext(ctx, `INSERT INTO users (id, username, email, password) VALUES (1, 'alice', 'alice@example.com', 'hash')`)
	if err != nil {
		t.Fatal(err)
	}
	_, err = db.W.ExecContext(ctx, `INSERT INTO agents (id, user_id, slug, display_name, is_default) VALUES ('main', 1, 'main', 'Main', 1)`)
	if err != nil {
		t.Fatal(err)
	}
	box, err := secretbox.New("test-secret-key-for-tasks-32bytes!", "fallback-secret-key-32bytes!")
	if err != nil {
		t.Fatal(err)
	}
	em := &stubEmitter{}
	rt := New(Config{
		DB:      db,
		Box:     box,
		Agents:  stubAgents{},
		Emitter: em,
		Engine:  eng,
		UserID:  func(*http.Request) (int64, bool) { return 1, true },
	})
	return rt, db, em
}

func TestTasksCRUDAndRunNow(t *testing.T) {
	eng := &stubEngine{resp: RunResult{RunID: "run-1", Result: jsv.NewObject().Set("content", "All good")}}
	rt, _, _ := newTestRuntime(t, eng)
	ctx := context.Background()
	if err := rt.Start(ctx); err != nil {
		t.Fatal(err)
	}
	defer rt.Stop()

	// Create a scheduled task
	created, err := rt.CreateTask(ctx, 1, "main", jsv.NewObject().
		Set("name", "Morning check").
		Set("triggerType", "schedule").
		Set("triggerConfig", jsv.NewObject().Set("cronExpression", "0 9 * * *")).
		Set("taskType", "agent_prompt").
		Set("taskConfig", jsv.NewObject().Set("prompt", "Check status")).
		Set("enabled", true))
	if err != nil {
		t.Fatalf("CreateTask: %v", err)
	}
	taskID := int64(jsv.Number(created.Val("id")))
	if taskID <= 0 {
		t.Fatalf("unexpected created task: %v", created)
	}

	// List tasks
	listed, err := rt.ListTasks(ctx, 1, "main")
	if err != nil || len(listed) != 1 || jsv.Text(listed[0].Val("name")) != "Morning check" {
		t.Fatalf("ListTasks: %v, %v", listed, err)
	}

	// Run task now
	res, err := rt.RunTaskNow(ctx, taskID, 1)
	if err != nil || !jsv.Truthy(res.Val("running")) {
		t.Fatalf("RunTaskNow: %v, %v", res, err)
	}
	rt.Wait()

	eng.mu.Lock()
	runCount := len(eng.runs)
	eng.mu.Unlock()
	if runCount != 1 {
		t.Fatalf("expected 1 run, got %d", runCount)
	}
}

func TestHandleEventDeduplicatesFingerprint(t *testing.T) {
	eng := &stubEngine{resp: RunResult{RunID: "run-2", Result: jsv.NewObject().Set("content", "Welcomed")}}
	rt, _, _ := newTestRuntime(t, eng)
	if err := rt.Start(context.Background()); err != nil {
		t.Fatal(err)
	}
	defer rt.Stop()

	ctx := context.Background()
	_, err := rt.repo.create(ctx, 1, normalizedTask{
		AgentID:       "main",
		Name:          "Welcome",
		TriggerType:   "messaging_member_joined",
		TriggerConfig: jsv.NewObject().Set("platform", "discord"),
		TaskType:      "agent_prompt",
		TaskConfig:    jsv.NewObject().Set("prompt", "Say hi"),
		Enabled:       true,
	})
	if err != nil {
		t.Fatal(err)
	}

	ev := map[string]any{
		"userId":     float64(1),
		"platform":   "discord",
		"spaceId":    "guild-1",
		"memberId":   "user-9",
		"occurredAt": time.Now().UTC().Format(time.RFC3339),
	}
	rt.HandleEvent("messaging", "member_joined", ev)
	rt.Wait()
	// Same fingerprint should be skipped
	rt.HandleEvent("messaging", "member_joined", ev)
	rt.Wait()

	eng.mu.Lock()
	defer eng.mu.Unlock()
	if len(eng.runs) != 1 {
		t.Fatalf("expected 1 run (deduped), got %d", len(eng.runs))
	}
}

func TestCreateTaskFromHTTPJSON(t *testing.T) {
	rt, _, _ := newTestRuntime(t, &stubEngine{})
	mux := http.NewServeMux()
	rt.Routes(mux)
	req := httptest.NewRequest(http.MethodPost, "/api/tasks", strings.NewReader(`{"name":"Check","triggerType":"schedule","triggerConfig":{"mode":"recurring","cronExpression":"*/15 * * * *"},"taskConfig":{"loopPaused":true},"prompt":"Check status","enabled":true}`))
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusCreated {
		t.Fatalf("status %d: %s", rec.Code, rec.Body.String())
	}
	if !strings.Contains(rec.Body.String(), `"cronExpression":"*/15 * * * *"`) {
		t.Fatalf("missing schedule: %s", rec.Body.String())
	}
}
