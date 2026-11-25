package mobilesync_test

import (
	"context"
	"database/sql"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neoagent/internal/mobilesync"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/replay"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

type published struct {
	name  string
	event map[string]any
}

type recorder struct{ events []published }

func (r *recorder) PublishEvent(name string, event map[string]any) {
	r.events = append(r.events, published{name, event})
}

type stack struct {
	srv    *httptest.Server
	db     *dbx.DB
	box    *secretbox.Box
	events *recorder
}

func newStack(t *testing.T) *stack {
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
	// The scenario was recorded with SESSION_SECRET=x as the key material.
	box, err := secretbox.New(config.SecretPrefix, "x")
	if err != nil {
		t.Fatal(err)
	}
	events := &recorder{}
	api := mobilesync.New(mobilesync.Config{
		DB: db, Box: box, Agents: agentscope.Resolver{DB: db}, Events: events,
		Log: slog.New(slog.NewTextHandler(io.Discard, nil)),
		UserID: func(r *http.Request) (int64, bool) {
			id, err := strconv.ParseInt(r.Header.Get("X-Test-User"), 10, 64)
			return id, err == nil
		},
	})
	mux := http.NewServeMux()
	api.Routes(mux)
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'alice', 'x'), (2, 'bob', 'x')`); err != nil {
		t.Fatal(err)
	}
	return &stack{srv: srv, db: db, box: box, events: events}
}

func (s *stack) labels(t *testing.T) map[string]string {
	rows, err := s.db.W.Query(`SELECT id, user_id, slug FROM agents`)
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

func (s *stack) open(col string, v any) any {
	text, ok := v.(string)
	if !ok {
		return v
	}
	plain, err := s.box.Open(text)
	if err != nil {
		return text
	}
	return plain
}

// TestReplaysNodeConversation plays a conversation recorded from the Node
// server's own routers and requires the same answers and the same stored rows.
func TestReplaysNodeConversation(t *testing.T) {
	sc := replay.Load(t, "testdata/scenario.json")
	s := newStack(t)
	runner := &replay.Runner{
		T: t, BaseURL: s.srv.URL,
		Exec: func(query string, params []any) {
			if _, err := s.db.W.Exec(query, params...); err != nil {
				t.Fatalf("%s: %v", query, err)
			}
		},
		Labels: func() map[string]string { return s.labels(t) },
		MainAgent: func(user int) string {
			var id sql.NullString
			_ = s.db.W.QueryRow(`SELECT id FROM agents WHERE user_id = ? AND slug = 'main'`, user).Scan(&id)
			return id.String
		},
	}
	runner.Run(sc)

	sealed := map[string]bool{"credentials_json": true, "payload_json": true, "result_json": true}
	open := func(col string, v any) any {
		if sealed[col] {
			return s.open(col, v)
		}
		return v
	}
	var got []replay.SnapshotRow
	snap := func(table, query string, transform func(string, any) any) {
		got = append(got, replay.Snapshot(t, s.db.W, table, query, sc.Volatile, s.labels(t), transform)...)
	}
	snap("health_sync_runs", `SELECT user_id, source, provider, sync_window_start, sync_window_end, record_count, summary_json, payload_json FROM health_sync_runs ORDER BY rowid`, nil)
	snap("health_metric_samples", `SELECT user_id, metric_type, record_id, start_time, end_time, recorded_at, numeric_value, text_value, unit, source_app_id, source_device, last_modified_time, payload_json FROM health_metric_samples ORDER BY id`, nil)
	snap("integration_connections", `SELECT user_id, agent_id, provider_key, app_key, status, account_email, scopes_json, credentials_json, metadata_json FROM integration_connections ORDER BY id`, open)
	snap("device_sync_items", `SELECT user_id, agent_id, device_id, kind, item_key, starts_at, ends_at, payload_json FROM device_sync_items ORDER BY kind, item_key`, open)
	snap("device_sync_commands", `SELECT user_id, agent_id, device_id, action, payload_json, status, result_json, error FROM device_sync_commands ORDER BY id`, func(col string, v any) any {
		if v == nil {
			return nil
		}
		return open(col, v)
	})
	if len(got) != len(sc.Snapshot) {
		t.Fatalf("%d stored rows, node stored %d", len(got), len(sc.Snapshot))
	}
	for i := range got {
		if got[i] != sc.Snapshot[i] {
			t.Errorf("row %d of %s\n got  %s\n want %s", i, got[i].Table, got[i].Row, sc.Snapshot[i].Row)
		}
	}
}
