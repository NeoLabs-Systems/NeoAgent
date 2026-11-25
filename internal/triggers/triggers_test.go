package triggers_test

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"sync"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/replay"
	"github.com/NeoLabs-Systems/neoagent/internal/triggers"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// fakeTasks lists geofence tasks straight from the table and records events.
type fakeTasks struct {
	db     *dbx.DB
	mu     sync.Mutex
	events []string
}

func (f *fakeTasks) GeofenceTasks(ctx context.Context, userID int64) ([]triggers.GeofenceTask, error) {
	rows, err := f.db.W.QueryContext(ctx, `SELECT id, trigger_config FROM scheduled_tasks
       WHERE enabled = 1 AND user_id = ? AND trigger_type = 'geofence_event'`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []triggers.GeofenceTask
	for rows.Next() {
		var t triggers.GeofenceTask
		if err := rows.Scan(&t.ID, &t.TriggerConfig); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (f *fakeTasks) PublishEvent(name string, event map[string]any) {
	f.mu.Lock()
	defer f.mu.Unlock()
	obj := jsv.NewObject()
	obj.Set("name", name)
	inner := jsv.NewObject()
	// Node lists the members in the order its route built them.
	order := []string{"userId", "fenceId", "transition", "latitude", "longitude", "occurredAt", "appPackage", "title", "body", "actionTaken", "receivedAt"}
	for _, k := range order {
		if v, ok := event[k]; ok {
			switch n := v.(type) {
			case int64:
				v = float64(n)
			case int:
				v = float64(n)
			}
			inner.Set(k, v)
		}
	}
	obj.Set("event", inner)
	f.events = append(f.events, replay.Canonical(jsv.Stringify(obj), []string{"occurredAt", "receivedAt"}, nil))
}

func TestReplaysNodeConversation(t *testing.T) {
	sc := replay.Load(t, "testdata/scenario.json")
	var recorded struct {
		Events        []string `json:"events"`
		Notifications []string `json:"notifications"`
	}
	raw := replay.Raw(t, "testdata/scenario.json")
	replay.Unmarshal(t, raw, &recorded)

	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	tasks := &fakeTasks{db: db}
	api := triggers.New(triggers.Config{
		DB: db, Tasks: tasks, Log: slog.New(slog.NewTextHandler(io.Discard, nil)),
		UserID: func(r *http.Request) (int64, bool) {
			id, err := strconv.ParseInt(r.Header.Get("X-Test-User"), 10, 64)
			return id, err == nil
		},
	})
	mux := http.NewServeMux()
	api.Routes(mux)
	srv := httptest.NewServer(mux)
	defer srv.Close()
	for _, q := range []string{
		`INSERT INTO users (id, username, password) VALUES (1, 'alice', 'x'), (2, 'bob', 'x')`,
		`INSERT INTO agents (id, user_id, slug, display_name, is_default) VALUES ('a1', 1, 'main', 'Main', 1), ('a2', 1, 'other', 'Other', 0), ('b1', 2, 'main', 'Main', 1)`,
	} {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	(&replay.Runner{
		T: t, BaseURL: srv.URL,
		Exec: func(query string, params []any) {
			if _, err := db.W.Exec(query, params...); err != nil {
				t.Fatalf("%s: %v", query, err)
			}
		},
	}).Run(sc)

	if len(tasks.events) != len(recorded.Events) {
		t.Fatalf("%d events published, node published %d: %v", len(tasks.events), len(recorded.Events), tasks.events)
	}
	for i, want := range recorded.Events {
		if got := tasks.events[i]; got != replay.Canonical(want, sc.Volatile, nil) {
			t.Errorf("event %d\n got  %s\n want %s", i, got, want)
		}
	}
	rows := replay.Snapshot(t, db.W, "notification_history",
		`SELECT user_id, app_package, title, body, action_taken, typeof(title) AS title_type FROM notification_history ORDER BY id`, nil, nil, nil)
	if len(rows) != len(recorded.Notifications) {
		t.Fatalf("%d stored notifications, node stored %d", len(rows), len(recorded.Notifications))
	}
	for i, want := range recorded.Notifications {
		if rows[i].Row != want {
			t.Errorf("notification %d\n got  %s\n want %s", i, rows[i].Row, want)
		}
	}
}
