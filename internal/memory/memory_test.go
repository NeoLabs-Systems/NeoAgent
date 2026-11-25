package memory

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

func newTestMemory(t *testing.T) (*Manager, *API, *http.ServeMux) {
	t.Helper()
	ctx := context.Background()
	db, err := dbx.Open(ctx, t.TempDir()+"/memory.db", dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.ExecContext(ctx, `INSERT INTO users (id, username, email, password) VALUES (1, 'alice', 'alice@example.com', 'hash')`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.ExecContext(ctx, `INSERT INTO agents (id, user_id, slug, display_name, is_default) VALUES ('main', 1, 'main', 'Main', 1)`); err != nil {
		t.Fatal(err)
	}
	box, err := secretbox.New(localSecretPrefix, "fallback-secret-key-32bytes!")
	if err != nil {
		t.Fatal(err)
	}
	mm, err := New(ctx, Config{
		DB:           db,
		AgentDataDir: t.TempDir(),
		LocalBox:     box,
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(mm.Stop)

	api := NewAPI(APIConfig{
		Memory: mm,
		UserID: func(*http.Request) (int64, bool) { return 1, true },
	})
	mux := http.NewServeMux()
	api.Routes(mux)
	return mm, api, mux
}

func doJSON(t *testing.T, mux *http.ServeMux, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	var req *http.Request
	if body != "" {
		req = httptest.NewRequest(method, path, strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
	} else {
		req = httptest.NewRequest(method, path, nil)
	}
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	return rec
}

func TestMemoryCRUDRecallAndCoreRoutes(t *testing.T) {
	_, _, mux := newTestMemory(t)

	// Save a memory
	rec := doJSON(t, mux, http.MethodPost, "/api/memory/memories", `{
		"content":"Alice prefers dark roast coffee in the morning.",
		"category":"preferences",
		"importance":0.8
	}`)
	if rec.Code != http.StatusOK && rec.Code != http.StatusCreated {
		t.Fatalf("save memory status %d: %s", rec.Code, rec.Body.String())
	}
	var saved map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &saved); err != nil {
		t.Fatalf("unmarshal save: %v", err)
	}
	memID, _ := saved["id"].(string)
	if memID == "" {
		t.Fatalf("expected memory id in %s", rec.Body.String())
	}

	// List memories
	rec = doJSON(t, mux, http.MethodGet, "/api/memory/memories", "")
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "dark roast coffee") {
		t.Fatalf("list status %d: %s", rec.Code, rec.Body.String())
	}

	// Recall via FTS5
	rec = doJSON(t, mux, http.MethodPost, "/api/memory/memories/recall", `{"query":"coffee"}`)
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), memID) {
		t.Fatalf("recall status %d: %s", rec.Code, rec.Body.String())
	}

	// Update memory
	rec = doJSON(t, mux, http.MethodPut, "/api/memory/memories/"+memID, `{"content":"Alice prefers espresso."}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("update status %d: %s", rec.Code, rec.Body.String())
	}

	// Delete memory
	rec = doJSON(t, mux, http.MethodDelete, "/api/memory/memories/"+memID, "")
	if rec.Code != http.StatusOK {
		t.Fatalf("delete status %d: %s", rec.Code, rec.Body.String())
	}

	// Core memory put / get / delete
	rec = doJSON(t, mux, http.MethodPut, "/api/memory/core/timezone", `{"value":"Europe/Berlin"}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("put core status %d: %s", rec.Code, rec.Body.String())
	}
	rec = doJSON(t, mux, http.MethodGet, "/api/memory/core", "")
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "Europe/Berlin") {
		t.Fatalf("get core status %d: %s", rec.Code, rec.Body.String())
	}
	rec = doJSON(t, mux, http.MethodDelete, "/api/memory/core/timezone", "")
	if rec.Code != http.StatusOK {
		t.Fatalf("delete core status %d: %s", rec.Code, rec.Body.String())
	}
}
