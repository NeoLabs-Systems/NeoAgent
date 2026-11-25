package accounterase

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

type vectors struct {
	Seed          []string `json:"seed"`
	Export        string   `json:"export"`
	TablesCleared int      `json:"tablesCleared"`
	After         struct {
		Users, Conversations, Messages []json.RawMessage
		Delegations                    []map[string]any `json:"delegations"`
		Invites                        []map[string]any `json:"invites"`
		Audit                          []map[string]any `json:"audit"`
	} `json:"after"`
	Errors struct{ Invalid, Missing string } `json:"errors"`
}

func loadVectors(t *testing.T) vectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/node_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

type env struct {
	eraser   *Eraser
	dir      string
	sessions *sessionx.Store
	mgr      *sessionx.Manager
}

func newEnv(t *testing.T, seed []string) *env {
	t.Helper()
	ctx := context.Background()
	dir := t.TempDir()
	db, err := dbx.Open(ctx, filepath.Join(dir, "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	for _, s := range seed {
		if _, err := db.W.Exec(s); err != nil {
			t.Fatalf("seed %q: %v", s, err)
		}
	}
	sdb, err := dbx.Open(ctx, filepath.Join(dir, "sessions.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { sdb.Close() })
	store, err := sessionx.NewStore(ctx, sdb.W)
	if err != nil {
		t.Fatal(err)
	}
	mgr, err := sessionx.NewManager(store, sessionx.Options{Name: "neoagent.sid", Secrets: []string{"s"}, MaxAge: time.Hour})
	if err != nil {
		t.Fatal(err)
	}
	return &env{dir: dir, sessions: store, mgr: mgr, eraser: &Eraser{
		DB: db, DataDir: filepath.Join(dir, "data"), AgentDataDir: filepath.Join(dir, "agent"), Sessions: store,
	}}
}

func TestExportMatchesNode(t *testing.T) {
	v := loadVectors(t)
	e := newEnv(t, v.Seed)
	got, err := e.eraser.Export(context.Background(), 1)
	if err != nil {
		t.Fatal(err)
	}
	var g, w map[string]any
	if err := json.Unmarshal(got, &g); err != nil {
		t.Fatalf("not JSON: %v\n%s", err, got)
	}
	if err := json.Unmarshal([]byte(v.Export), &w); err != nil {
		t.Fatal(err)
	}
	if _, err := time.Parse("2006-01-02T15:04:05.000Z", g["exportedAt"].(string)); err != nil {
		t.Errorf("exportedAt: %v", err)
	}
	delete(g, "exportedAt")
	delete(w, "exportedAt")
	// The table order is the schema's creation order, which differs between a
	// migrated and a fresh database; the content of every table must match.
	if !reflect.DeepEqual(g, w) {
		t.Errorf("export differs:\n got  %v\n want %v", g, w)
	}
	// Layout: identical to JSON.stringify(x, null, 2), which json.Indent
	// reproduces. Compare the Node text and ours after normalising exportedAt.
	var compact bytes.Buffer
	if err := json.Compact(&compact, got); err != nil {
		t.Fatal(err)
	}
	var indented bytes.Buffer
	if err := json.Indent(&indented, compact.Bytes(), "", "  "); err != nil {
		t.Fatal(err)
	}
	if indented.String() != string(got) {
		t.Errorf("layout differs from JSON.stringify(..., null, 2):\n%s", got)
	}
	if !strings.Contains(string(got), `"password": "[redacted]"`) || strings.Contains(string(got), "hash") && !strings.Contains(string(got), "redacted") {
		t.Error("credential columns must be redacted")
	}
	if !strings.Contains(string(got), "<&>") {
		t.Error("HTML characters must not be escaped")
	}
}

func TestEraseMatchesNode(t *testing.T) {
	v := loadVectors(t)
	e := newEnv(t, v.Seed)
	ctx := context.Background()
	for _, p := range []string{"data/artifacts/1/a.txt", "data/artifacts/2/b.txt", "agent/workspaces/1/f", "agent/workspaces/2/f"} {
		abs := filepath.Join(e.dir, p)
		if err := os.MkdirAll(filepath.Dir(abs), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(abs, []byte("x"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	outside := filepath.Join(e.dir, "outside.txt")
	os.WriteFile(outside, []byte("keep"), 0o600)
	e.eraser.DB.W.Exec(`UPDATE artifacts SET storage_path = ? WHERE id = 'a1'`, outside)

	if _, err := e.eraser.Erase(ctx, 0); err == nil || err.Error() != v.Errors.Invalid {
		t.Errorf("invalid id: %v want %q", err, v.Errors.Invalid)
	}
	if _, err := e.eraser.Erase(ctx, 99); err == nil || err.Error() != v.Errors.Missing {
		t.Errorf("missing id: %v want %q", err, v.Errors.Missing)
	}
	n, err := e.eraser.Erase(ctx, 1)
	if err != nil {
		t.Fatal(err)
	}
	if n != v.TablesCleared {
		t.Errorf("tables cleared %d, node %d", n, v.TablesCleared)
	}

	col := func(q string) []string {
		rows, err := e.eraser.DB.W.Query(q)
		if err != nil {
			t.Fatal(err)
		}
		defer rows.Close()
		var out []string
		for rows.Next() {
			var s string
			rows.Scan(&s)
			out = append(out, s)
		}
		return out
	}
	if got := col(`SELECT id FROM users ORDER BY id`); !reflect.DeepEqual(got, []string{"2", "3"}) {
		t.Errorf("users left: %v", got)
	}
	if got := col(`SELECT conversation_id FROM conversation_messages`); !reflect.DeepEqual(got, []string{"c2"}) {
		t.Errorf("messages left: %v", got)
	}
	// Bob moved under Carol, the invite is revoked, and the audit log matches.
	if got := col(`SELECT managed_user_id || '>' || manager_user_id FROM user_delegations`); !reflect.DeepEqual(got, []string{"2>3"}) {
		t.Errorf("delegations: %v", got)
	}
	rows, _ := e.eraser.DB.W.Query(`SELECT action, actor_user_id, subject_user_id, detail_json FROM access_audit_log ORDER BY id`)
	defer rows.Close()
	var audit []map[string]any
	for rows.Next() {
		var action, detail string
		var actor, subject *int64
		rows.Scan(&action, &actor, &subject, &detail)
		m := map[string]any{"action": action, "detail_json": detail, "actor_user_id": nil, "subject_user_id": nil}
		if actor != nil {
			m["actor_user_id"] = float64(*actor)
		}
		if subject != nil {
			m["subject_user_id"] = float64(*subject)
		}
		audit = append(audit, m)
	}
	// Erasing alice sets her id to NULL in earlier audit rows: Node saw the
	// same, so compare the whole log.
	if !reflect.DeepEqual(audit, v.After.Audit) {
		t.Errorf("audit log:\n got  %v\n want %v", audit, v.After.Audit)
	}

	for p, want := range map[string]bool{
		"data/artifacts/1": false, "data/artifacts/2/b.txt": true,
		"agent/workspaces/1": false, "agent/workspaces/2/f": true, "outside.txt": true,
	} {
		_, err := os.Stat(filepath.Join(e.dir, p))
		if (err == nil) != want {
			t.Errorf("%s exists=%v want %v", p, err == nil, want)
		}
	}
}

func TestEraseKeepsPathsInside(t *testing.T) {
	e := newEnv(t, []string{
		`INSERT INTO users (id, username, password) VALUES (1, 'a', 'x')`,
		`INSERT INTO artifacts (id, user_id, kind, backend, storage_path) VALUES ('a', 1, 'f', 'l', '../../victim.txt')`,
	})
	victim := filepath.Join(e.dir, "victim.txt")
	os.WriteFile(victim, []byte("x"), 0o600)
	os.MkdirAll(filepath.Join(e.dir, "data", "artifacts"), 0o700)
	if _, err := e.eraser.Erase(context.Background(), 1); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(victim); err != nil {
		t.Error("a stored path escaped the artifacts directory")
	}
}

// ---- routes -----------------------------------------------------------------

func routeServer(t *testing.T, e *env) *httptest.Server {
	mux := http.NewServeMux()
	New(Config{Eraser: e.eraser}).Routes(mux)
	mux.HandleFunc("POST /test/login/{id}", func(w http.ResponseWriter, r *http.Request) {
		id, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
		sess := sessionx.FromContext(r.Context())
		sess.Regenerate()
		sess.Set("userId", id)
	})
	srv := httptest.NewServer(e.mgr.Middleware(mux))
	t.Cleanup(srv.Close)
	return srv
}

func do(t *testing.T, c *http.Client, method, url, body string) (int, http.Header, string) {
	t.Helper()
	req, _ := http.NewRequest(method, url, strings.NewReader(body))
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := c.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, resp.Header, string(raw)
}

func TestRoutes(t *testing.T) {
	e := newEnv(t, []string{
		`INSERT INTO users (id, username, password, is_admin) VALUES (1, 'admin', 'x', 1)`,
		`INSERT INTO users (id, username, password, is_admin) VALUES (2, 'bob', 'x', 0)`,
	})
	srv := routeServer(t, e)
	jar, _ := cookiejar.New(nil)
	c := &http.Client{Jar: jar}

	if code, _, body := do(t, c, "GET", srv.URL+"/api/account/export", ""); code != 401 || body != `{"error":"Unauthorized"}` {
		t.Fatalf("anonymous export: %d %s", code, body)
	}
	do(t, c, "POST", srv.URL+"/test/login/1", "")
	if code, _, body := do(t, c, "POST", srv.URL+"/api/account/delete", `{"confirmUsername":"admin"}`); code != 403 ||
		!strings.HasSuffix(body, `first.","code":"ADMIN_SELF_DELETE"}`) {
		t.Fatalf("admin delete: %d %s", code, body)
	}

	jar2, _ := cookiejar.New(nil)
	c2 := &http.Client{Jar: jar2}
	do(t, c2, "POST", srv.URL+"/test/login/2", "")
	code, h, body := do(t, c2, "GET", srv.URL+"/api/account/export", "")
	if code != 200 || h.Get("Content-Disposition") != `attachment; filename="neoagent-data-export-2.json"` ||
		h.Get("Content-Type") != "application/json; charset=utf-8" || !strings.Contains(body, `"userId": 2`) {
		t.Fatalf("export: %d %v %s", code, h, body)
	}
	if code, _, body := do(t, c2, "POST", srv.URL+"/api/account/delete", `{"confirmUsername":"nope"}`); code != 400 ||
		body != `{"error":"Confirmation does not match your username."}` {
		t.Fatalf("wrong confirmation: %d %s", code, body)
	}
	if code, _, body := do(t, c2, "POST", srv.URL+"/api/account/delete", `{"confirmUsername":" bob "}`); code != 200 ||
		!strings.HasPrefix(body, `{"ok":true,"tablesCleared":`) {
		t.Fatalf("delete: %d %s", code, body)
	}
	if code, _, _ := do(t, c2, "GET", srv.URL+"/api/account/export", ""); code != 401 {
		t.Errorf("the session must end with the account, got %d", code)
	}
	var n int
	e.eraser.DB.W.QueryRow(`SELECT COUNT(*) FROM users WHERE id = 2`).Scan(&n)
	if n != 0 {
		t.Error("account row still there")
	}
}
