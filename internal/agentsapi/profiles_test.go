package agentsapi

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"regexp"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

var (
	uuidPattern  = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`)
	slugTemplate = regexp.MustCompile(`\{([^}]+)\}`)
)

// stable replaces ids and timestamps, which differ between runs, by what
// they are: an agent id is shown as its slug.
func stable(v any, idToSlug map[string]string) any {
	switch x := v.(type) {
	case map[string]any:
		out := map[string]any{}
		for k, val := range x {
			switch {
			case k == "createdAt" || k == "updatedAt":
				if val != nil {
					out[k] = "<time>"
				}
			default:
				out[k] = stable(val, idToSlug)
			}
		}
		return out
	case []any:
		out := make([]any, len(x))
		for i, val := range x {
			out[i] = stable(val, idToSlug)
		}
		return out
	case string:
		if slug, ok := idToSlug[x]; ok {
			return "<id:" + slug + ">"
		}
		if uuidPattern.MatchString(x) {
			return "<uuid>"
		}
	}
	return v
}

func canonical(v any) string {
	raw, _ := json.Marshal(v)
	var back any
	_ = json.Unmarshal(raw, &back)
	out, _ := json.Marshal(back)
	return string(out)
}

// TestProfilesMatchNode replays /api/agent-profiles recorded from Node
// (testdata/gen_profiles.js) on a fresh database.
func TestProfilesMatchNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/profiles.json")
	if err != nil {
		t.Fatal(err)
	}
	var steps []map[string]any
	if err := json.Unmarshal(raw, &steps); err != nil {
		t.Fatal(err)
	}
	// The request bodies are sent as Node sent them, key order included.
	var rawBodies []struct {
		Body json.RawMessage `json:"body"`
	}
	if err := json.Unmarshal(raw, &rawBodies); err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec("INSERT INTO users (id, username, password) VALUES (1, 'u', 'x')"); err != nil {
		t.Fatal(err)
	}
	mux := http.NewServeMux()
	New(Config{DB: db, UserID: func(*http.Request) (int64, bool) { return 1, true }}).Routes(mux)
	srv := httptest.NewServer(mux)
	defer srv.Close()

	idOf := func(slug string) string {
		var id string
		if err := db.R.QueryRow(`SELECT id FROM agents WHERE user_id = 1 AND slug = ?`, slug).Scan(&id); err != nil {
			return "none"
		}
		return id
	}
	slugs := func() map[string]string {
		out := map[string]string{}
		rows, _ := db.R.Query(`SELECT id, slug FROM agents`)
		defer rows.Close()
		for rows.Next() {
			var id, slug string
			_ = rows.Scan(&id, &slug)
			out[id] = slug
		}
		return out
	}
	// Node's ids map to the slugs they had in Node's run.
	nodeSlugs := map[string]string{}
	for _, step := range steps {
		if step["rows"] != nil {
			continue
		}
		collect(step["response"], nodeSlugs)
	}
	goSlugs := map[string]string{}
	for i, step := range steps {
		if rows, ok := step["rows"]; ok {
			var got []map[string]any
			q, _ := db.R.Query(`SELECT slug, display_name, description, responsibilities, instructions, status, is_default, can_delegate, can_be_delegated_to, delegate_targets_json, tool_restrictions_json, created_by_agent_id, creation_reason FROM agents ORDER BY slug`)
			cols, _ := q.Columns()
			for q.Next() {
				vals := make([]any, len(cols))
				ptrs := make([]any, len(cols))
				for j := range vals {
					ptrs[j] = &vals[j]
				}
				_ = q.Scan(ptrs...)
				m := map[string]any{}
				for j, c := range cols {
					if b, ok := vals[j].([]byte); ok {
						vals[j] = string(b)
					}
					m[c] = vals[j]
				}
				got = append(got, m)
			}
			q.Close()
			want, _ := rows.([]any)
			for j := range got {
				if j >= len(want) || canonical(got[j]) != canonical(want[j]) {
					t.Errorf("row %d:\n got: %s\nwant: %v", j, canonical(got[j]), canonical(want[min(j, len(want)-1)]))
				}
			}
			continue
		}
		path := slugTemplate.ReplaceAllStringFunc(step["path"].(string), func(m string) string { return idOf(m[1 : len(m)-1]) })
		var reqBody io.Reader
		if step["body"] != nil {
			reqBody = bytes.NewReader(rawBodies[i].Body)
		}
		req, _ := http.NewRequest(step["method"].(string), srv.URL+path, reqBody)
		if reqBody != nil {
			req.Header.Set("Content-Type", "application/json")
		}
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		var got any
		_ = json.NewDecoder(resp.Body).Decode(&got)
		resp.Body.Close()
		if int(step["status"].(float64)) != resp.StatusCode {
			t.Errorf("#%d %s %s: status %d, want %v", i, step["method"], step["path"], resp.StatusCode, step["status"])
		}
		for id, slug := range slugs() {
			if _, seen := goSlugs[id]; !seen {
				goSlugs[id] = slug
			}
		}
		if g, w := canonical(stable(got, goSlugs)), canonical(stable(step["response"], nodeSlugs)); g != w {
			t.Errorf("#%d %s %s:\n got: %s\nwant: %s", i, step["method"], step["path"], g, w)
		}
	}
}

// collect maps each agent id in a response to its slug at the time.
func collect(v any, out map[string]string) {
	switch x := v.(type) {
	case map[string]any:
		if id, ok := x["id"].(string); ok {
			if slug, ok := x["slug"].(string); ok {
				if _, seen := out[id]; !seen {
					out[id] = slug
				}
			}
		}
		for _, val := range x {
			collect(val, out)
		}
	case []any:
		for _, val := range x {
			collect(val, out)
		}
	}
}
