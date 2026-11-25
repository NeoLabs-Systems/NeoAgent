package memory

import (
	"context"
	"database/sql"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"sync/atomic"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/replay"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

func agentLabels(t *testing.T, db *sql.DB) map[string]string {
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

// newReplayStack serves the memory routes on a fresh database the way the
// generators set Node up: two accounts, the given agent-data files, counting
// ids, the given embedding model and, when asked, a running ingestion
// service without collectors.
func newReplayStack(t *testing.T, seedFiles map[string]string, embedder Embedder, withIngestion bool) (*dbx.DB, *httptest.Server, *Manager) {
	t.Helper()
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
	dataDir := t.TempDir()
	for rel, content := range seedFiles {
		file := filepath.Join(dataDir, rel)
		if err := os.MkdirAll(filepath.Dir(file), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(file, []byte(content), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	box, err := secretbox.New(localSecretPrefix, "x")
	if err != nil {
		t.Fatal(err)
	}
	// Counting ids, as the generator uses: see gen/scenario.js.
	var nextID atomic.Int64
	newID := func() string { return fmt.Sprintf("00000000-0000-4000-8000-%012d", nextID.Add(1)) }
	mm, err := New(ctx, Config{DB: db, AgentDataDir: dataDir, LocalBox: box, NewID: newID, Embedder: embedder})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(mm.Stop)
	var ingestion *IngestionService
	if withIngestion {
		ingestion = NewIngestionService(IngestionConfig{Memory: mm})
	}
	api := NewAPI(APIConfig{Memory: mm, Ingestion: ingestion, UserID: func(r *http.Request) (int64, bool) {
		id, err := strconv.ParseInt(r.Header.Get("X-Test-User"), 10, 64)
		return id, err == nil
	}})
	mux := http.NewServeMux()
	api.Routes(mux)
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)

	return db, srv, mm
}

// TestReplaysNodeConversation plays a conversation recorded from the Node
// server's /api/memory router (gen/scenario.js) and requires the same answers
// and the same stored rows.
func TestReplaysNodeConversation(t *testing.T) {
	sc := replay.Load(t, "testdata/scenario.json")
	var extra struct {
		SeedFiles map[string]string `json:"seedFiles"`
		Probes    struct {
			Context       string             `json:"context"`
			SharedContext string             `json:"sharedContext"`
			BobContext    string             `json:"bobContext"`
			Recall        map[string]*string `json:"recall"`
		} `json:"probes"`
	}
	replay.Unmarshal(t, replay.Raw(t, "testdata/scenario.json"), &extra)

	db, srv, mm := newReplayStack(t, extra.SeedFiles, nil, false)
	defer probeAgentContext(t, mm, extra.Probes.Context, extra.Probes.SharedContext, extra.Probes.BobContext, extra.Probes.Recall)

	play(t, sc, db, srv)
	compareSnapshot(t, sc, db, [][2]string{
		{"memories", `SELECT user_id, agent_id, content, category, importance, archived, pinned, stale_after_days, memory_strength, access_count, confidence, metadata_json, source_type, source_id, source_label, scope_type, scope_id FROM memories ORDER BY content`},
		{"core_memory", `SELECT user_id, agent_id, key, value FROM core_memory ORDER BY user_id, key`},
		{"conversations", `SELECT id, user_id, agent_id, platform, title FROM conversations ORDER BY id`},
		{"memory_entities", `SELECT user_id, agent_id, entity_key, name, kind, aliases_json, summary, mention_count, metadata_json FROM memory_entities ORDER BY user_id, entity_key`},
		{"memory_entity_mentions", `SELECT e.entity_key, m.content, x.in_sentence FROM memory_entity_mentions x JOIN memory_entities e ON e.id = x.entity_id JOIN memories m ON m.id = x.memory_id ORDER BY e.entity_key, m.content`},
		{"memory_relations", `SELECT f.content AS from_content, t.content AS to_content, r.relation_type, r.confidence, r.metadata_json FROM memory_relations r JOIN memories f ON f.id = r.from_memory_id JOIN memories t ON t.id = r.to_memory_id ORDER BY from_content, to_content`},
		{"memory_facts", `SELECT user_id, agent_id, subject, predicate, object, category, confidence, status, valid_to, invalidated_at IS NOT NULL AS invalidated, metadata_json FROM memory_facts ORDER BY user_id, object, status`},
		{"materialized_knowledge_views", `SELECT user_id, agent_id, view_type, subject_key, title, summary, markdown_text, metadata_json FROM materialized_knowledge_views ORDER BY view_type, title`},
	})
}

// play runs a scenario's steps against srv, with db for its SQL steps.
func play(t *testing.T, sc replay.Scenario, db *dbx.DB, srv *httptest.Server) {
	t.Helper()
	(&replay.Runner{
		T: t, BaseURL: srv.URL,
		Exec: func(query string, params []any) {
			if _, err := db.W.Exec(query, params...); err != nil {
				t.Fatalf("%s: %v", query, err)
			}
		},
		Labels: func() map[string]string { return agentLabels(t, db.W) },
		MainAgent: func(user int) string {
			var id sql.NullString
			_ = db.W.QueryRow(`SELECT id FROM agents WHERE user_id = ? AND slug = 'main'`, user).Scan(&id)
			return id.String
		},
	}).Run(sc)
}

// compareSnapshot requires the rows of each {table, query} to equal the rows
// the Node run stored.
func compareSnapshot(t *testing.T, sc replay.Scenario, db *dbx.DB, tables [][2]string) {
	t.Helper()
	labels := agentLabels(t, db.W)
	var got []replay.SnapshotRow
	for _, tq := range tables {
		got = append(got, replay.Snapshot(t, db.W, tq[0], tq[1], sc.Volatile, labels, nil)...)
	}
	if len(got) != len(sc.Snapshot) {
		t.Errorf("%d stored rows, node stored %d", len(got), len(sc.Snapshot))
	}
	for i := range min(len(got), len(sc.Snapshot)) {
		if got[i] != sc.Snapshot[i] {
			t.Errorf("row %d of %s\n got  %s\n want %s", i, got[i].Table, got[i].Row, sc.Snapshot[i].Row)
		}
	}
}

// probeAgentContext requires the system-prompt context and the recall blocks
// the agent sees to equal what Node built from the same memory.
func probeAgentContext(t *testing.T, mm *Manager, context, shared, bob string, recall map[string]*string) {
	t.Helper()
	ctx := t.Context()
	for _, c := range []struct {
		name, want string
		user       int64
		audience   string
	}{{"context", context, 1, ""}, {"shared context", shared, 1, "shared"}, {"bob context", bob, 2, ""}} {
		got, err := mm.BuildContext(ctx, c.user, ContextOptions{Audience: c.audience})
		if err != nil {
			t.Fatal(err)
		}
		if got != c.want {
			t.Errorf("%s\n got  %q\n want %q", c.name, got, c.want)
		}
	}
	for query, want := range recall {
		got := mm.BuildRecallMessage(ctx, 1, query, RecallMessageOptions{})
		w := ""
		if want != nil {
			w = *want
		}
		if got != w {
			t.Errorf("recall message for %q\n got  %q\n want %q", query, got, w)
		}
	}
}
