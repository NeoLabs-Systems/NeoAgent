package commands

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

type scenario struct {
	Setup []struct {
		SQL    string
		Params []any
	}
	Parse []struct {
		Input  *string
		Source *string
		Result *struct {
			Command string
			Args    []string
			Raw     string
			Source  string
			Prefix  string
		}
	}
	Results []struct {
		Input   string
		Context struct {
			UserID   int64
			Source   string
			Platform string
			ChatID   string
			AgentID  string
		}
		Result       map[string]any
		Stopped      []string
		Released     []map[string]any
		Queues       map[string]map[string]any
		Conversation []string `json:"conversations"`
		History      int
	}
}

func load(t *testing.T) scenario {
	t.Helper()
	raw, err := os.ReadFile("testdata/scenario.json")
	if err != nil {
		t.Fatal(err)
	}
	var s scenario
	if err := json.Unmarshal(raw, &s); err != nil {
		t.Fatal(err)
	}
	return s
}

func TestParseMatchesNode(t *testing.T) {
	for _, c := range load(t).Parse {
		input, source := "", ""
		if c.Input != nil {
			input = *c.Input
		}
		if c.Source != nil {
			source = *c.Source
		}
		got, ok := Parse(input, source)
		if c.Result == nil {
			if ok {
				t.Errorf("Parse(%q, %q) = %+v, want none", input, source, got)
			}
			continue
		}
		want := Parsed{c.Result.Command, c.Result.Args, c.Result.Raw, c.Result.Source, c.Result.Prefix}
		if len(want.Args) == 0 {
			want.Args = got.Args
		}
		if !ok || !reflect.DeepEqual(got, want) {
			t.Errorf("Parse(%q, %q) = %+v, %v, want %+v", input, source, got, ok, want)
		}
	}
}

// fakes standing in for the other domains.

type fakeAgents struct{ main string }

func (f fakeAgents) Resolve(_ context.Context, _ int64, candidate string) (string, error) {
	return f.main, nil
}

type fakeMessages struct{}

func (fakeMessages) Fixed(_ context.Context, _ int64, _ string, key string, v map[string]string) string {
	switch key {
	case "stopped":
		return "Stopped."
	case "contextCleared":
		return "Context cleared. Fresh start."
	}
	return "Unknown command: /" + v["command"] + ". Type /help to see what’s available."
}

type run struct {
	id      string
	user    int64
	agentID string
}

type fakeEngine struct {
	runs    []run
	stopped []string
}

func (e *fakeEngine) StopRuns(user int64, agent string) {
	for _, r := range e.runs {
		if r.user == user && (agent == "" || r.agentID == agent) {
			e.stopped = append(e.stopped, r.id)
		}
	}
}

func (e *fakeEngine) ActiveRuns(user int64, agent string) int {
	n := 0
	for _, r := range e.runs {
		if r.user == user && (agent == "" || r.agentID == agent) {
			n++
		}
	}
	return n
}

func (*fakeEngine) Reply(context.Context, int64, string, string) (string, error) {
	return "fresh!", nil
}

type queue struct {
	running         bool
	pending         int
	cancelRequested *bool
}

// fakeQueues follows the key rules and cancel semantics of inbound_queue.js.
type fakeQueues struct {
	byKey    map[string]*queue
	released []map[string]any
}

func (q *fakeQueues) keys(user int64, agent string) []string {
	prefix := "1:" + agent + ":"
	var out []string
	for k := range q.byKey {
		if k == "1" || k == "1:"+agent || strings.HasPrefix(k, prefix) {
			out = append(out, k)
		}
	}
	return out
}

func (q *fakeQueues) Summary(user int64, agent string) (bool, int) {
	running, pending := false, 0
	for _, k := range q.keys(user, agent) {
		running = running || q.byKey[k].running
		pending += q.byKey[k].pending
	}
	return running, pending
}

func (q *fakeQueues) CancelAll(user int64, agent string) {
	yes := true
	for _, k := range q.keys(user, agent) {
		item := q.byKey[k]
		item.cancelRequested = &yes
		if !item.running {
			delete(q.byKey, k)
		}
	}
}

func (q *fakeQueues) ReleaseAbandonedJobs(user int64, agent string) {
	q.released = append(q.released, map[string]any{"userId": float64(user), "agentId": agent})
}

type fakeMessaging struct{}

func (fakeMessaging) FindConversations(context.Context, int64, string, string, string) ([]string, error) {
	return []string{"c1", "c2"}, nil
}
func (fakeMessaging) ConnectedPlatforms(int64, string) int { return 2 }

type fakeCatalog struct{}

func (fakeCatalog) ToolNames(int64, string) []string                       { return nil }
func (fakeCatalog) Models(context.Context, int64, string) ([]Model, error) { return nil, nil }
func (fakeCatalog) EnabledSkills() []string                                { return []string{"beta", "alpha"} }

type fakeSummaries struct{ cleared int }

func (f *fakeSummaries) ClearWebChat(context.Context, int64, string) error { f.cleared++; return nil }

func TestScenarioMatchesNode(t *testing.T) {
	sc := load(t)
	var mainID string
	for _, r := range sc.Results {
		if len(r.Released) > 0 {
			mainID = r.Released[0]["agentId"].(string)
		}
	}
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "n.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	for _, q := range []string{
		`INSERT INTO users (id, username, password) VALUES (1, 'alice', 'x'), (2, 'bob', 'x')`,
	} {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := db.W.Exec(`INSERT INTO agents (id, user_id, slug, display_name, description, responsibilities, instructions, status, is_default, can_delegate, can_be_delegated_to, delegate_targets_json)
		VALUES (?, 1, 'main', 'Main', '', '', '', 'active', 1, 1, 0, '[]')`, mainID); err != nil {
		t.Fatal(err)
	}
	for _, s := range sc.Setup {
		params := make([]any, len(s.Params))
		for i, p := range s.Params {
			params[i] = p
			if p == "{agent}" {
				params[i] = mainID
			}
		}
		if _, err := db.W.Exec(s.SQL, params...); err != nil {
			t.Fatalf("%s: %v", s.SQL, err)
		}
	}

	engine := &fakeEngine{runs: []run{{"r1", 1, mainID}, {"r2", 1, "other"}, {"r3", 2, mainID}}}
	queues := &fakeQueues{byKey: map[string]*queue{
		"1:" + mainID + ":web": {running: true, pending: 2, cancelRequested: new(bool)},
		"1:" + mainID + ":tg":  {pending: 1},
		"2:x:y":                {running: true, pending: 1},
	}}
	summaries := &fakeSummaries{}
	router := New(Config{
		DB: db, Agents: fakeAgents{mainID}, Messages: fakeMessages{}, Engine: engine, Queues: queues,
		Messaging: fakeMessaging{}, Catalog: fakeCatalog{}, Summaries: summaries,
	})

	for _, step := range sc.Results {
		t.Run(step.Input, func(t *testing.T) {
			engine.stopped, queues.released = nil, nil
			c := step.Context
			got, err := router.Dispatch(ctx, step.Input, Context{UserID: c.UserID, AgentID: c.AgentID, Source: c.Source, Platform: c.Platform, ChatID: c.ChatID})
			if err != nil {
				t.Fatal(err)
			}
			raw, _ := json.Marshal(got)
			var have map[string]any
			json.Unmarshal(raw, &have)
			if !reflect.DeepEqual(have, step.Result) {
				t.Fatalf("result\n got %s\nwant %v", raw, step.Result)
			}
			if !reflect.DeepEqual(engine.stopped, orNil(step.Stopped)) {
				t.Errorf("stopped %v, want %v", engine.stopped, step.Stopped)
			}
			if len(queues.released) != len(step.Released) {
				t.Errorf("released %v, want %v", queues.released, step.Released)
			}
			for i := range queues.released {
				if i < len(step.Released) && !reflect.DeepEqual(queues.released[i], step.Released[i]) {
					t.Errorf("released %v, want %v", queues.released[i], step.Released[i])
				}
			}
			haveQueues := map[string]map[string]any{}
			for k, q := range queues.byKey {
				var cancel any
				if q.cancelRequested != nil {
					cancel = *q.cancelRequested
				}
				haveQueues[k] = map[string]any{"running": q.running, "pending": float64(q.pending), "cancelRequested": cancel}
			}
			wantQueues := map[string]map[string]any{}
			for k, q := range step.Queues {
				wantQueues[k] = q
			}
			if !reflect.DeepEqual(haveQueues, wantQueues) {
				t.Errorf("queues %v, want %v", haveQueues, wantQueues)
			}
			rows, _ := db.W.Query(`SELECT id FROM conversations ORDER BY id`)
			var ids []string
			for rows.Next() {
				var id string
				rows.Scan(&id)
				ids = append(ids, id)
			}
			rows.Close()
			if !reflect.DeepEqual(orNilS(ids), orNilS(step.Conversation)) {
				t.Errorf("conversations %v, want %v", ids, step.Conversation)
			}
			var history int
			db.W.QueryRow(`SELECT COUNT(*) FROM conversation_history`).Scan(&history)
			if history != step.History {
				t.Errorf("history rows %d, want %d", history, step.History)
			}
		})
	}
	if summaries.cleared != 1 {
		t.Errorf("web summary cleared %d times, want 1", summaries.cleared)
	}
}

func orNil(s []string) []string {
	if len(s) == 0 {
		return nil
	}
	return s
}

func orNilS(s []string) []string { return orNil(s) }

type failingEngine struct{ fakeEngine }

func (*failingEngine) Reply(context.Context, int64, string, string) (string, error) {
	return "", errors.New("model down")
}

func TestClearFallsBackWhenTheModelFails(t *testing.T) {
	ctx := context.Background()
	db, _ := dbx.Open(ctx, filepath.Join(t.TempDir(), "n.db"), dbx.Options{})
	defer db.Close()
	schema.Ensure(ctx, db.W)
	router := New(Config{DB: db, Agents: fakeAgents{"a"}, Messages: fakeMessages{}, Engine: &failingEngine{}})
	got, err := router.Dispatch(ctx, "/clear", Context{UserID: 1, Source: "web"})
	if err != nil || got.Content != "Context cleared. Fresh start." || got.Error != "model down" {
		t.Fatalf("%+v %v", got, err)
	}
}
