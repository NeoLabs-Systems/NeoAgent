package workspace

import (
	"context"
	"database/sql"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

type vectors struct {
	Edits []struct {
		Name    string
		Content string
		Edits   []Edit
		Result  struct {
			Content  string
			Modified bool
			Report   []map[string]any
		}
	}
	Coerce []struct {
		In  any
		Out string
	}
	CSV []struct {
		Text  string
		Comma []map[string]any
		Tab   []map[string]any
	}
}

func loadVectors(t *testing.T) vectors {
	t.Helper()
	raw, err := os.ReadFile("testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

// roundTrip makes a Go value comparable with Node's parsed JSON.
func roundTrip(t *testing.T, v any) any {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	var out any
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatal(err)
	}
	return out
}

func TestApplyEditsMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Edits {
		t.Run(c.Name, func(t *testing.T) {
			got := ApplyEdits(c.Content, c.Edits)
			if got.Content != c.Result.Content || got.Modified != c.Result.Modified {
				t.Fatalf("content/modified = %q/%v, want %q/%v", got.Content, got.Modified, c.Result.Content, c.Result.Modified)
			}
			want := roundTrip(t, c.Result.Report)
			if have := roundTrip(t, got.Report); !reflect.DeepEqual(have, want) {
				t.Fatalf("report = %v, want %v", have, want)
			}
		})
	}
}

func TestEditKeyOrderMatchesNode(t *testing.T) {
	res := ApplyEdits("a\nb\na", []Edit{{OldText: "a", NewText: "z"}})
	raw, _ := json.Marshal(res.Report)
	want := `[{"success":false,"error":"Target text matches 2 locations. Include more surrounding context or set replace_all: true.","edit":"a...","locations":["1: a","3: a"]}]`
	if string(raw) != want {
		t.Fatalf("%s", raw)
	}
}

func TestCoerceTextMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).Coerce {
		if got := CoerceText(c.In); got != c.Out {
			t.Errorf("CoerceText(%#v) = %q, want %q", c.In, got, c.Out)
		}
	}
}

func TestParseDelimitedMatchesNode(t *testing.T) {
	for _, c := range loadVectors(t).CSV {
		for _, tc := range []struct {
			delim rune
			text  string
			want  []map[string]any
		}{{',', c.Text, c.Comma}, {'\t', strings.ReplaceAll(c.Text, ",", "\t"), c.Tab}} {
			got := roundTrip(t, ParseDelimited(tc.text, tc.delim))
			if !reflect.DeepEqual(got, roundTrip(t, tc.want)) {
				t.Errorf("%q: got %v, want %v", tc.text, got, tc.want)
			}
		}
	}
}

func newManager(t *testing.T) *Manager {
	t.Helper()
	m, err := New(filepath.Join(t.TempDir(), "ws"), false)
	if err != nil {
		t.Fatal(err)
	}
	return m
}

func j(t *testing.T, v any) string {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return string(raw)
}

func TestPathConfinement(t *testing.T) {
	m := newManager(t)
	for _, p := range []string{"../x", "/etc/passwd", "a/../../x", "/workspace/../x"} {
		if _, err := m.Rel("1", p, "path"); err == nil || err.Error() != "path is outside the per-user workspace." {
			t.Errorf("%q: err = %v", p, err)
		}
	}
	for in, want := range map[string]string{"": ".", "/workspace": ".", "/workspace/a/b.txt": "a/b.txt", "a//b": "a/b", "/home/x/.neoagent/agent-data/workspaces/1/f.md": "1/f.md"} {
		if got, err := m.Rel("1", in, "path"); err != nil || got != want {
			t.Errorf("%q: got %q, %v want %q", in, got, err, want)
		}
	}
}

func TestSymlinkEscapeIsRefused(t *testing.T) {
	m := newManager(t)
	root, _ := m.Root("1")
	outsideDir := t.TempDir()
	os.WriteFile(filepath.Join(outsideDir, "secret.txt"), []byte("secret"), 0o600)
	if err := os.Symlink(outsideDir, filepath.Join(root, "link")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(outsideDir, "secret.txt"), filepath.Join(root, "file-link")); err != nil {
		t.Fatal(err)
	}
	for _, p := range []string{"link/secret.txt", "file-link"} {
		res, err := m.ReadFile("1", Options{"path": p})
		if err != nil {
			t.Fatal(err)
		}
		if strings.Contains(j(t, res), "secret") && !strings.Contains(j(t, res), "error") {
			t.Fatalf("%s leaked: %s", p, j(t, res))
		}
	}
	res, _ := m.WriteFile("1", Options{"path": "file-link", "content": "x"})
	if b, _ := os.ReadFile(filepath.Join(outsideDir, "secret.txt")); string(b) != "secret" {
		t.Fatalf("write followed a link out of the workspace: %s %s", b, j(t, res))
	}
}

func TestFileTools(t *testing.T) {
	m := newManager(t)
	w, err := m.WriteFile("1", Options{"path": "/workspace/src/a.txt", "content": "one\ntwo\nthree\n"})
	if err != nil || j(t, w) != `{"success":true,"path":"src/a.txt"}` {
		t.Fatalf("%v %s", err, j(t, w))
	}
	if r, _ := m.WriteFile("1", Options{"path": "src/a.txt", "content": "four\n", "mode": "append"}); j(t, r) != `{"success":true,"path":"src/a.txt"}` {
		t.Fatal(j(t, r))
	}
	r, _ := m.ReadFile("1", Options{"path": "src/a.txt"})
	if j(t, r) != `{"path":"src/a.txt","content":"one\ntwo\nthree\nfour\n","byteSize":19}` {
		t.Fatal(j(t, r))
	}
	r, _ = m.ReadFile("1", Options{"path": "src/a.txt", "start_line": 2.0, "end_line": 3.0})
	if j(t, r) != `{"path":"src/a.txt","content":"two\nthree","totalLines":5,"rangeShown":[2,3]}` {
		t.Fatal(j(t, r))
	}
	r, _ = m.ReadFile("1", Options{"path": "src/a.txt", "start_line": 4.0, "end_line": 2.0})
	if j(t, r) != `{"error":"start_line must be less than or equal to end_line","path":"src/a.txt"}` {
		t.Fatal(j(t, r))
	}
	r, _ = m.ReadFile("1", Options{"path": "missing.txt"})
	if !strings.HasPrefix(j(t, r), `{"error":"Failed to read file: ENOENT`) {
		t.Fatal(j(t, r))
	}
	e := m.EditFile("1", "src/a.txt", []Edit{{OldText: "two", NewText: "2"}})
	if !strings.HasPrefix(j(t, e), `{"success":true,"report":[{"success":true,"replaced":1,"line":2,"edit":"two..."}],"path":"src/a.txt"}`) {
		t.Fatal(j(t, e))
	}
	if e := m.EditFile("1", "nope.txt", nil); j(t, e) != `{"error":"File not found: nope.txt"}` {
		t.Fatal(j(t, e))
	}
	rr := m.ReplaceFileRange("1", Options{"path": "src/a.txt", "start_line": 1.0, "end_line": 2.0, "content": "A\nB\nC"})
	if j(t, rr) != `{"success":true,"path":"src/a.txt","startLine":1,"endLine":2,"replacedLines":2,"insertedLines":3,"totalLines":5}` {
		t.Fatal(j(t, rr))
	}
	if b, _ := m.ReadFile("1", Options{"path": "src/a.txt"}); !strings.Contains(j(t, b), `"A\nB\nC\nthree\nfour\n"`) {
		t.Fatal(j(t, b))
	}
	rr = m.ReplaceFileRange("1", Options{"path": "src/a.txt", "start_line": 9.0})
	if !strings.Contains(j(t, rr), "line range 9-9 is outside file with 5 lines") {
		t.Fatal(j(t, rr))
	}
	info, _ := os.Stat(filepath.Join(must(m.Root("1")), "src/a.txt"))
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("mode %v", info.Mode())
	}
	if _, err := m.WriteFile("1", Options{"path": "../x", "content": "x"}); err == nil {
		t.Fatal("outside write accepted")
	}
}

func must(s string, err error) string {
	if err != nil {
		panic(err)
	}
	return s
}

func TestListAndSearch(t *testing.T) {
	m := newManager(t)
	m.WriteFile("1", Options{"path": "a/b/deep.md", "content": "Hello Needle\nnothing"})
	m.WriteFile("1", Options{"path": "a/top.txt", "content": "needle again"})
	m.WriteFile("1", Options{"path": ".hidden/x.txt", "content": "needle"})
	l, _ := m.ListDirectory("1", Options{"path": "a"})
	entries := l[1].Value.([]DirEntry)
	if len(entries) != 2 || entries[0].Name != "b" || entries[0].Type != "directory" || entries[1].Path != "a/top.txt" {
		t.Fatalf("%+v", entries)
	}
	l, _ = m.ListDirectory("1", Options{"path": "a", "recursive": true})
	if got := len(l[1].Value.([]DirEntry)); got != 3 {
		t.Fatalf("recursive entries = %d", got)
	}
	s, _ := m.SearchFiles("1", Options{"query": "NEEDLE"})
	if j(t, s) != `{"matches":[{"file":"a/b/deep.md","line":1,"content":"Hello Needle"},{"file":"a/top.txt","line":1,"content":"needle again"}],"count":2}` {
		t.Fatal(j(t, s))
	}
	s, _ = m.SearchFiles("1", Options{"query": "needle", "include": "*.TXT"})
	if !strings.Contains(j(t, s), `"count":1`) {
		t.Fatal(j(t, s))
	}
	s, _ = m.SearchFiles("1", Options{"query": " "})
	if j(t, s) != `{"results":[],"message":"query is required"}` {
		t.Fatal(j(t, s))
	}
}

func TestQuery(t *testing.T) {
	m := newManager(t)
	ctx := context.Background()
	m.WriteFile("1", Options{"path": "d.csv", "content": "name,age\nann,30\nbob,25\ncy,30\n"})
	m.WriteFile("1", Options{"path": "d.json", "content": `[{"z":1,"a":"x"},{"z":2,"a":"y"}]`})
	r, err := m.Query(ctx, "1", Options{"path": "d.csv", "equals": map[string]any{"age": "30"}, "columns": []any{"name", "nope"}})
	if err != nil || j(t, r) != `{"format":"csv","columns":["name","nope"],"rows":[{"name":"ann"},{"name":"cy"}]}` {
		t.Fatalf("%v %s", err, j(t, r))
	}
	r, _ = m.Query(ctx, "1", Options{"path": "d.json", "equals": map[string]any{"z": 2.0}})
	if j(t, r) != `{"format":"json","columns":["z","a"],"rows":[{"z":2,"a":"y"}]}` {
		t.Fatal(j(t, r))
	}
	m.WriteFile("1", Options{"path": "d.txt", "content": "x"})
	if _, err := m.Query(ctx, "1", Options{"path": "d.txt"}); err == nil || !strings.Contains(err.Error(), "Supported structured-data formats") {
		t.Fatal(err)
	}

	root := must(m.Root("1"))
	db, _ := sql.Open("sqlite", filepath.Join(root, "t.sqlite"))
	db.Exec(`CREATE TABLE t (id INTEGER, name TEXT); INSERT INTO t VALUES (1,'a'),(2,'b')`)
	db.Close()
	r, err = m.Query(ctx, "1", Options{"path": "t.sqlite", "sql": "SELECT id, name FROM t WHERE id > @min ORDER BY id", "parameters": map[string]any{"min": 0.0}})
	if err != nil || j(t, r) != `{"format":"sqlite","columns":["id","name"],"rows":[{"id":1,"name":"a"},{"id":2,"name":"b"}]}` {
		t.Fatalf("%v %s", err, j(t, r))
	}
	for _, bad := range []string{"DELETE FROM t", "ATTACH DATABASE '/etc/hosts' AS x", "PRAGMA writable_schema=1"} {
		if _, err := m.Query(ctx, "1", Options{"path": "t.sqlite", "sql": bad}); err == nil || err.Error() != "Only read-only queries are allowed." {
			t.Errorf("%q: %v", bad, err)
		}
	}
}
