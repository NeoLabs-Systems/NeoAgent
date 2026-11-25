package agentscope

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

func newResolver(t *testing.T) Resolver {
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
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'a', 'x'), (2, 'b', 'x')`); err != nil {
		t.Fatal(err)
	}
	return Resolver{DB: db}
}

func TestResolve(t *testing.T) {
	ctx := context.Background()
	r := newResolver(t)

	main, err := r.Resolve(ctx, 1, "")
	if err != nil || main == "" {
		t.Fatalf("main agent: %q, %v", main, err)
	}
	again, _ := r.Resolve(ctx, 1, "  ")
	if again != main {
		t.Fatal("the main agent must be created once")
	}
	if isMain, err := r.IsMain(ctx, 1, main); err != nil || !isMain {
		t.Fatalf("IsMain = %v, %v", isMain, err)
	}

	if _, err := r.DB.W.Exec(`INSERT INTO agents (id, user_id, slug, display_name) VALUES ('h1', 1, 'my-helper', 'Helper'), ('o1', 2, 'other', 'Other')`); err != nil {
		t.Fatal(err)
	}
	for candidate, want := range map[string]string{
		"h1": "h1", "my-helper": "h1", "  My Helper!  ": "h1", "MY-HELPER": "h1", "main": main,
		"o1": main, "other": main, "unknown": main, "!!!": main,
	} {
		if got, err := r.Resolve(ctx, 1, candidate); err != nil || got != want {
			t.Errorf("Resolve(%q) = %q, %v; want %q", candidate, got, err, want)
		}
	}
	if isMain, _ := r.IsMain(ctx, 1, "h1"); isMain {
		t.Error("a helper is not the main agent")
	}
	if isMain, _ := r.IsMain(ctx, 2, main); isMain {
		t.Error("another account's agent is not main for this one")
	}
	if isMain, _ := r.IsMain(ctx, 1, ""); isMain {
		t.Error("no agent is not main")
	}
}

func TestResolveRepairsDefaultAndSkipsArchived(t *testing.T) {
	ctx := context.Background()
	r := newResolver(t)
	main, _ := r.Resolve(ctx, 1, "")
	r.DB.W.Exec(`INSERT INTO agents (id, user_id, slug, display_name, is_default) VALUES ('h1', 1, 'h', 'H', 0)`)
	r.DB.W.Exec(`UPDATE agents SET is_default = 0 WHERE id = ?`, main)
	if got, _ := r.Resolve(ctx, 1, ""); got != main {
		t.Fatalf("without a default the main agent is restored, got %q", got)
	}
	r.DB.W.Exec(`UPDATE agents SET status = 'archived' WHERE id = ?`, main)
	r.DB.W.Exec(`UPDATE agents SET is_default = 1 WHERE id = 'h1'`)
	if got, _ := r.Resolve(ctx, 1, ""); got != "h1" {
		t.Fatalf("got %q", got)
	}
}

func TestCandidatePrecedence(t *testing.T) {
	body := func(s string) map[string]json.RawMessage {
		var m map[string]json.RawMessage
		if err := json.Unmarshal([]byte(s), &m); err != nil {
			t.Fatal(err)
		}
		return m
	}
	req := func(target string, header string) *http.Request {
		r := httptest.NewRequest("GET", target, nil)
		if header != "" {
			r.Header.Set("X-Agent-Id", header)
		}
		return r
	}
	for name, tc := range map[string]struct {
		r    *http.Request
		body map[string]json.RawMessage
		want string
	}{
		"body agentId wins":      {req("/?agentId=q", "h"), body(`{"agentId":"b","agent_id":"c"}`), "b"},
		"snake case":             {req("/?agentId=q", "h"), body(`{"agent_id":"c"}`), "c"},
		"options":                {req("/?agentId=q", "h"), body(`{"options":{"agentId":"o"}}`), "o"},
		"options snake":          {req("/", ""), body(`{"options":{"agent_id":"o2"}}`), "o2"},
		"query":                  {req("/?agentId=q&agentId=r", "h"), body(`{}`), "q,r"},
		"query snake":            {req("/?agent_id=s", "h"), nil, "s"},
		"header":                 {req("/", "h"), nil, "h"},
		"nothing":                {req("/", ""), nil, ""},
		"falsy body values skip": {req("/?agentId=q", ""), body(`{"agentId":"","agent_id":0,"options":null}`), "q"},
		"number":                 {req("/", ""), body(`{"agentId":7}`), "7"},
		"object never matches":   {req("/?agentId=q", ""), body(`{"agentId":{}}`), "[object Object]"},
	} {
		if got := Candidate(tc.r, tc.body); got != tc.want {
			t.Errorf("%s: %q, want %q", name, got, tc.want)
		}
	}
}
