package tasks

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/replay"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

var isoInstant = regexp.MustCompile(`\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z`)

// recorder is the generator's engine and socket stand-in: it records what the
// runtime asks the engine to run and what it tells clients.
type recorder struct {
	mu     sync.Mutex
	db     *dbx.DB
	t      *testing.T
	runs   []string
	events []string
}

func (r *recorder) labels() map[string]string { return taskAgentLabels(r.t, r.db.W) }

func (r *recorder) RunTask(_ context.Context, req RunRequest) (RunResult, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var model any
	if req.Model != "" {
		model = req.Model
	}
	ctx := req.Context
	if ctx == nil {
		ctx = jsv.NewObject()
	}
	rec := jsv.NewObject().Set("userId", float64(req.UserID)).Set("model", model).
		Set("prompt", isoInstant.ReplaceAllString(req.Prompt, "<time>")).Set("title", req.Title).
		Set("triggerType", req.TriggerType).Set("triggerSource", req.TriggerSource).Set("agentId", req.AgentID).
		Set("taskId", float64(req.TaskID)).Set("allowMultipleProactiveMessages", req.AllowMultipleProactiveMessages).
		Set("priorSummary", req.PriorSummary).Set("context", ctx).Set("resumable", req.Resumable != nil)
	r.runs = append(r.runs, replay.Canonical(jsv.Stringify(rec), nil, r.labels()))
	n := len(r.runs)
	runID := "run-" + strconv.Itoa(n)
	content := "Done " + strconv.Itoa(n) + "."
	if strings.Contains(req.Prompt, "Say nothing") {
		content = ""
	}
	if strings.Contains(req.Prompt, "Explode") {
		return RunResult{}, errors.New("Model exploded")
	}
	return RunResult{RunID: runID, Result: jsv.NewObject().Set("runId", runID).Set("content", content)}, nil
}

func (r *recorder) EmitToUser(userID int64, event string, payload any) {
	r.mu.Lock()
	defer r.mu.Unlock()
	rec := jsv.NewObject().Set("room", "user:"+strconv.FormatInt(userID, 10)).Set("event", event).Set("payload", payload)
	text := replay.Canonical(jsv.Stringify(rec), []string{"timestamp", "scheduledAt"}, r.labels())
	r.events = append(r.events, isoInstant.ReplaceAllString(text, "<time>"))
}

func taskAgentLabels(t *testing.T, db *sql.DB) map[string]string {
	t.Helper()
	rows, err := db.Query(`SELECT id, user_id, slug FROM agents`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	labels := map[string]string{}
	for rows.Next() {
		var id, slug string
		var user int
		if err := rows.Scan(&id, &user, &slug); err != nil {
			t.Fatal(err)
		}
		labels[id] = "<agent:" + strconv.Itoa(user) + ":" + slug + ">"
	}
	return labels
}

// TestReplaysNodeConversation plays gen/scenario.js against the Go routes and
// runtime: the answers, the stored rows, the engine requests and the events.
func TestReplaysNodeConversation(t *testing.T) {
	saved := time.Local
	time.Local = time.UTC
	t.Cleanup(func() { time.Local = saved })

	sc := replay.Load(t, "testdata/scenario.json")
	var extra struct {
		EngineRuns []string `json:"engineRuns"`
		Events     []string `json:"events"`
	}
	replay.Unmarshal(t, replay.Raw(t, "testdata/scenario.json"), &extra)

	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'alice', 'x'), (2, 'bob', 'x')`); err != nil {
		t.Fatal(err)
	}
	box, err := secretbox.New("enc:v1:", "x")
	if err != nil {
		t.Fatal(err)
	}
	rec := &recorder{db: db, t: t}
	rt := New(Config{
		DB: db, Box: box, Agents: agentscope.Resolver{DB: db}, Emitter: rec, Engine: rec,
		UserID: func(r *http.Request) (int64, bool) {
			id, err := strconv.ParseInt(r.Header.Get("X-Test-User"), 10, 64)
			return id, err == nil
		},
	})
	mux := http.NewServeMux()
	rt.Routes(mux)
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)

	(&replay.Runner{
		T: t, BaseURL: srv.URL,
		Exec: func(query string, params []any) {
			if _, err := db.W.Exec(query, params...); err != nil {
				t.Fatalf("%s: %v", query, err)
			}
		},
		Labels: func() map[string]string { return taskAgentLabels(t, db.W) },
		MainAgent: func(user int) string {
			var id sql.NullString
			_ = db.W.QueryRow(`SELECT id FROM agents WHERE user_id = ? AND slug = 'main'`, user).Scan(&id)
			return id.String
		},
	}).Run(sc)

	// As the generator does: wait for the manual run, then run the silent,
	// the failing and the reporting task one after another.
	rt.Wait()
	for _, name := range []string{"create silent", "create exploder", "create reporter"} {
		var created struct {
			ID int64 `json:"id"`
		}
		for _, s := range sc.Steps {
			if s.Name == name {
				_ = json.Unmarshal([]byte(s.Expect.Raw), &created)
			}
		}
		if _, err := rt.RunTaskNow(ctx, created.ID, 1); err != nil {
			t.Fatal(err)
		}
		rt.Wait()
	}

	labels := taskAgentLabels(t, db.W)
	var got []replay.SnapshotRow
	got = append(got, replay.Snapshot(t, db.W, "scheduled_tasks", `SELECT id, user_id, agent_id, name, trigger_type, trigger_config, cron_expression, run_at, one_time, execution_mode, task_type, task_config, enabled, last_run IS NOT NULL AS ran, last_triggered_at IS NOT NULL AS triggered, last_trigger_fingerprint FROM scheduled_tasks ORDER BY id`, sc.Volatile, labels, nil)...)
	got = append(got, replay.Snapshot(t, db.W, "conversations", `SELECT user_id, agent_id, platform, platform_chat_id, title FROM conversations ORDER BY platform_chat_id`, sc.Volatile, labels, nil)...)
	if len(got) != len(sc.Snapshot) {
		t.Errorf("%d stored rows, node stored %d", len(got), len(sc.Snapshot))
	}
	for i := range min(len(got), len(sc.Snapshot)) {
		if got[i] != sc.Snapshot[i] {
			t.Errorf("row %d of %s\n got  %s\n want %s", i, got[i].Table, got[i].Row, sc.Snapshot[i].Row)
		}
	}
	compareLists(t, "engine run", rec.runs, extra.EngineRuns)
	compareLists(t, "event", rec.events, extra.Events)
}

func compareLists(t *testing.T, what string, got, want []string) {
	t.Helper()
	if len(got) != len(want) {
		t.Errorf("%d %ss, node had %d:\n got  %q\n want %q", len(got), what, len(want), got, want)
		return
	}
	for i := range got {
		if got[i] != want[i] {
			t.Errorf("%s %d\n got  %s\n want %s", what, i, got[i], want[i])
		}
	}
}
