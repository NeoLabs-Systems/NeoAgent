package agentsapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"slices"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// The chat reads oldest first, merges other platforms' messages and pages
// backwards with the cursor the previous page returned.
func TestChatHistoryOrderMergeAndPaging(t *testing.T) {
	ctx := context.Background()
	db, err := dbx.Open(ctx, t.TempDir()+"/chat.db", dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	for _, statement := range []string{
		`INSERT INTO users (id, username, password) VALUES (1, 'alice', 'x')`,
		`INSERT INTO agents (id, user_id, slug, display_name, is_default) VALUES ('a1', 1, 'main', 'Main', 1)`,
		// Both stored time formats, and a tie between the two tables.
		`INSERT INTO conversation_history (user_id, agent_id, role, content, created_at) VALUES
			(1, 'a1', 'user', 'one', '2026-01-01 10:00:00'),
			(1, 'a1', 'assistant', 'three', '2026-01-01 10:02:00'),
			(1, 'a1', 'user', 'five', '2026-01-01 10:04:00')`,
		`INSERT INTO messages (user_id, agent_id, role, content, platform, metadata, created_at) VALUES
			(1, 'a1', 'user', 'two', 'telegram', '{"senderName":"Sam"}', '2026-01-01T10:01:00.000Z'),
			(1, 'a1', 'user', 'four', 'telegram', NULL, '2026-01-01 10:02:00'),
			(1, 'a1', 'user', 'web copy', 'web', NULL, '2026-01-01 10:05:00')`,
	} {
		if _, err := db.W.ExecContext(ctx, statement); err != nil {
			t.Fatal(err)
		}
	}
	mux := http.NewServeMux()
	New(Config{DB: db, UserID: func(*http.Request) (int64, bool) { return 1, true }}).Routes(mux)

	type page struct {
		Messages            []map[string]any `json:"messages"`
		HasMore             bool             `json:"hasMore"`
		NextBeforeCreatedAt string           `json:"nextBeforeCreatedAt"`
		NextBeforeSource    string           `json:"nextBeforeSource"`
		NextBeforeID        string           `json:"nextBeforeId"`
	}
	get := func(params url.Values) (p page, contents []string) {
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, httptest.NewRequest("GET", "/api/agents/chat-history?"+params.Encode(), nil))
		if rec.Code != http.StatusOK {
			t.Fatalf("status %d: %s", rec.Code, rec.Body)
		}
		if err := json.Unmarshal(rec.Body.Bytes(), &p); err != nil {
			t.Fatal(err)
		}
		for _, m := range p.Messages {
			contents = append(contents, m["content"].(string))
		}
		return p, contents
	}

	var pages [][]string
	params := url.Values{"limit": {"2"}}
	for range 3 {
		p, contents := get(params)
		pages = append(pages, contents)
		if p.HasMore != (len(pages) < 3) {
			t.Fatalf("page %d: hasMore = %v", len(pages), p.HasMore)
		}
		params = url.Values{"limit": {"2"}, "beforeCreatedAt": {p.NextBeforeCreatedAt},
			"beforeSource": {p.NextBeforeSource}, "beforeId": {p.NextBeforeID}}
	}
	want := [][]string{{"four", "five"}, {"two", "three"}, {"one"}}
	if !slices.EqualFunc(pages, want, slices.Equal[[]string]) {
		t.Fatalf("pages = %v, want %v", pages, want)
	}
	all, _ := get(url.Values{})
	if m := all.Messages[1]; m["platform"] != "telegram" || m["sender_name"] != "Sam" || m["history_source"] != "message" {
		t.Fatalf("telegram message = %v", m)
	}
}
