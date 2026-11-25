package wiring

import (
	"context"
	"errors"
	"path/filepath"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neoagent/internal/sockets"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
)

func TestWebHistoryContextAndCompletedReply(t *testing.T) {
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "history.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id,username,email,password) VALUES (1,'user','u@example.com','hash')`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO agents (id,user_id,slug,display_name,is_default) VALUES ('main',1,'main','Main',1)`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO agent_settings (user_id,agent_id,key,value) VALUES (1,'main','web_chat_summary','"prior context"')`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO conversation_history (user_id,agent_id,role,content,created_at) VALUES (1,'main','user','first','2026-01-01'),(1,'main','assistant','second','2026-01-02'),(1,'main','user','third','2026-01-03')`); err != nil {
		t.Fatal(err)
	}
	s := &socketServices{db: db}
	got, err := s.WebContext(1, 2, "main")
	if err != nil {
		t.Fatal(err)
	}
	if got.Summary != "prior context" || len(got.Recent) != 2 || got.Recent[0]["content"] != "second" || got.Recent[1]["content"] != "third" {
		t.Fatalf("context %#v", got)
	}
	if err := s.StoreWebReply(1, "main", "", sockets.RunResult{RunID: "r", Content: "ignored", Raw: map[string]any{"status": "failed"}}); err != nil {
		t.Fatal(err)
	}
	if err := s.StoreWebReply(1, "main", "", sockets.RunResult{RunID: "r", Content: "answer", TotalTokens: 12, Raw: map[string]any{"status": "completed"}}); err != nil {
		t.Fatal(err)
	}
	var count int
	if err := db.R.QueryRow(`SELECT COUNT(*) FROM conversation_history WHERE content='answer'`).Scan(&count); err != nil || count != 1 {
		t.Fatalf("count %d error %v", count, err)
	}
}

func TestCatalogVisibilityUsesModelGrants(t *testing.T) {
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "visibility.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err = db.W.Exec(`INSERT INTO users(id,username,email,password,allowed_models) VALUES(1,'user','u@example.com','hash','["openai::a"]')`); err != nil {
		t.Fatal(err)
	}
	t.Setenv("NEOAGENT_DISABLED_MODELS", "openai::a,b")
	c := settingsCatalogAdapter{store: &settings.Store{DB: db}}
	models := []map[string]any{{"id": "openai::a", "modelId": "a", "available": true}, {"id": "openai::b", "modelId": "b", "available": true}, {"id": "openai::c", "modelId": "c", "available": true}}
	c.applyVisibility(ctx, 1, models, false)
	if models[0]["available"] != true || models[0]["adminGranted"] != true || models[1]["available"] != false || models[2]["available"] != true {
		t.Fatal(models)
	}
	c.applyVisibility(ctx, 1, models, true)
	if models[0]["available"] != false {
		t.Fatal("decision model incorrectly granted", models)
	}
}

func TestNonAdminRunErrorsAreRedacted(t *testing.T) {
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "access.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err = db.W.Exec(`INSERT INTO users(id,username,email,password,is_admin) VALUES(1,'admin','a@example.com','hash',1),(2,'user','u@example.com','hash',0)`); err != nil {
		t.Fatal(err)
	}
	s := &socketServices{users: &accounts.Repo{DB: db}}
	original := map[string]any{"error": "secret technical failure", "result": "sensitive"}
	input := sockets.RunRecords{Run: original, Events: []any{map[string]any{"payload": map[string]any{"error": "private details"}}}}
	got := s.RunRecordsForUser(2, input)
	if got.Run["error"] != publicerr.Generic || got.Run["result"] != nil || got.Events[0].(map[string]any)["payload"].(map[string]any)["error"] != publicerr.Generic {
		t.Fatal(got)
	}
	if original["error"] != "secret technical failure" || s.RunRecordsForUser(1, input).Run["result"] != "sensitive" {
		t.Fatal("mutated admin record")
	}
	if got := s.ErrorMessageForUser(2, errors.New("internal details")); got != publicerr.Generic {
		t.Fatal(got)
	}
}

func TestRunEventsReadStoredPayloadsInSequence(t *testing.T) {
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "events.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users(id,username,email,password) VALUES(1,'user','u@example.com','hash')`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO agent_runs(id,user_id) VALUES('r',1)`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO agent_run_events(run_id,user_id,event_type,sequence_index,payload_json) VALUES('r',1,'second',2,'{"error":"private"}'),('r',1,'first',1,'{}')`); err != nil {
		t.Fatal(err)
	}
	events, err := (&socketServices{db: db}).List(ctx, "r")
	if err != nil {
		t.Fatal(err)
	}
	if len(events) != 2 || events[0].(map[string]any)["eventType"] != "first" || events[1].(map[string]any)["payload"].(map[string]any)["error"] != "private" {
		t.Fatal(events)
	}
}
