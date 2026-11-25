package webshares

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

type vectors struct {
	Slugs []struct{ Name, Slug string }
	Ports []struct {
		Port  any
		Valid any
	}
	Locations []struct {
		Location string
		Port     int64
		Result   string
	}
	Tool []struct {
		Label  string
		Result map[string]any
	}
	HTTP []struct {
		Method, Path    string
		Headers         map[string]string
		Status          int
		ResponseHeaders map[string]string
		Body            string
	}
	Guest map[string]struct {
		Status  int
		Headers map[string]string
		Body    string
		Gzip    bool
	}
	List []map[string]any
}

func load(t *testing.T) vectors {
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

func TestStoreHelpersMatchNode(t *testing.T) {
	v := load(t)
	for _, c := range v.Slugs {
		if got := SlugFor(c.Name); got != c.Slug {
			t.Errorf("SlugFor(%q) = %q, want %q", c.Name, got, c.Slug)
		}
	}
	for _, c := range v.Ports {
		want := 0
		if f, ok := c.Valid.(float64); ok {
			want = int(f)
		}
		if got := ValidatePort(c.Port); got != want {
			t.Errorf("ValidatePort(%v) = %d, want %d", c.Port, got, want)
		}
	}
	for _, c := range v.Locations {
		if got := rewriteLocation(c.Location, "/neo/app", c.Port); got != c.Result {
			t.Errorf("rewriteLocation(%q) = %q, want %q", c.Location, got, c.Result)
		}
	}
	for _, p := range []string{"/..", "/%2e%2E/x", "/a/%2fb", "/a\\..\\b", "/%zz"} {
		if !hasDotSegment(p) {
			t.Errorf("%s should be refused", p)
		}
	}
	if hasDotSegment("/a/b.c/") {
		t.Error("ordinary path refused")
	}
}

type guests struct {
	url     string
	running bool
}

func (g *guests) RunningGuest(key string) (string, string, bool) {
	switch {
	case !g.running:
		return "", "", false
	case key == "1":
		return g.url, "tok", true
	case key == "2":
		return g.url, "t", true
	}
	return "", "", false
}

// stable drops what differs between runs: ids and timestamps.
func stable(m map[string]any) map[string]any {
	out := map[string]any{}
	for k, v := range m {
		if k == "id" || k == "created_at" || k == "updated_at" {
			continue
		}
		out[k] = v
	}
	return out
}

func asJSON(v any) string {
	raw, _ := json.Marshal(v)
	var back any
	_ = json.Unmarshal(raw, &back)
	out, _ := json.Marshal(back)
	return string(out)
}

// TestShareToolAndProxyMatchNode replays the Node tool calls and public
// requests (testdata/gen_vectors.js) against the same guest answers.
func TestShareToolAndProxyMatchNode(t *testing.T) {
	v := load(t)
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	for _, q := range []string{
		"INSERT INTO users (id, username, password) VALUES (1, 'Neo', 'x'), (2, 'api', 'x'), (3, 'off', 'x')",
		"INSERT INTO user_settings (user_id, key, value) VALUES (3, 'web_sharing_enabled', 'false')",
	} {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	guest := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		entry, ok := v.Guest[r.URL.Path]
		if !ok {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(404)
			_, _ = io.WriteString(w, "nope")
			return
		}
		for k, val := range entry.Headers {
			w.Header().Set(k, val)
		}
		body := []byte(entry.Body)
		if entry.Gzip {
			var buf bytes.Buffer
			zw := gzip.NewWriter(&buf)
			_, _ = zw.Write(body)
			_ = zw.Close()
			body = buf.Bytes()
		}
		w.WriteHeader(entry.Status)
		_, _ = w.Write(body)
	}))
	defer guest.Close()
	g := &guests{url: guest.URL, running: true}
	store := &Store{DB: db, Getenv: func(string) string { return "" }}
	sharer := &Sharer{Store: store, Guests: g}

	tools := map[string]func() (map[string]any, error){
		"share closed port": func() (map[string]any, error) {
			return sharer.Share(ctx, 1, "", "Closed", 4000.0, "https://agent.example")
		},
		"share bad port":      func() (map[string]any, error) { return sharer.Share(ctx, 1, "", "X", 8421.0, "") },
		"share no name":       func() (map[string]any, error) { return sharer.Share(ctx, 1, "", " ", 3000.0, "") },
		"share reserved user": func() (map[string]any, error) { return sharer.Share(ctx, 2, "", "A", 3000.0, "https://agent.example") },
		"share off":           func() (map[string]any, error) { return sharer.Share(ctx, 3, "", "A", 3000.0, "") },
		"share not running": func() (map[string]any, error) {
			g.running = false
			defer func() { g.running = true }()
			return sharer.Share(ctx, 1, "", "A", 3000.0, "")
		},
		"share": func() (map[string]any, error) {
			return sharer.Share(ctx, 1, "", "My App", 3000.0, "https://agent.example")
		},
		"share again": func() (map[string]any, error) {
			return sharer.Share(ctx, 1, "", "my app", "3000", "https://agent.example/")
		},
		"share symbols": func() (map[string]any, error) { return sharer.Share(ctx, 1, "", "!!!", 3000.0, "") },
		"stop unknown":  func() (map[string]any, error) { return sharer.Stop(ctx, 1, "Nope") },
		"stop by name":  func() (map[string]any, error) { return sharer.Stop(ctx, 1, "MY APP") },
	}
	check := func(label string, want map[string]any) {
		got, err := tools[label]()
		if err != nil {
			t.Fatalf("%s: %v", label, err)
		}
		if asJSON(stable(got)) != asJSON(stable(want)) {
			t.Errorf("%s:\n got: %s\nwant: %s", label, asJSON(stable(got)), asJSON(stable(want)))
		}
	}
	var last map[string]any
	for _, c := range v.Tool {
		if c.Label == "stop by name" {
			last = c.Result
			continue
		}
		check(c.Label, c.Result)
	}
	list, err := store.List(ctx, 1, "https://agent.example")
	if err != nil {
		t.Fatal(err)
	}
	for i := range list {
		if asJSON(stable(map[string]any{"name": list[i].Name, "slug": list[i].Slug, "port": list[i].Port, "url": list[i].URL})) != asJSON(stable(v.List[i])) {
			t.Errorf("list %d: %+v vs %v", i, list[i], v.List[i])
		}
	}

	proxy := &Proxy{Store: store, Guests: g, PublicURL: "https://agent.example"}
	server := httptest.NewServer(proxy.Wrap(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(418)
		_, _ = io.WriteString(w, "fallthrough")
	})))
	defer server.Close()
	client := &http.Client{CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	run := func(i int, method, path string, headers map[string]string, status int, wantHeaders map[string]string, wantBody string) {
		var body io.Reader
		if method == "POST" {
			body = strings.NewReader("payload")
		}
		req, _ := http.NewRequest(method, server.URL+path, body)
		for k, val := range headers {
			req.Header.Set(k, val)
		}
		req.Header.Set("Accept-Encoding", "identity")
		resp, err := client.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		got, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		if resp.StatusCode != status || string(got) != wantBody {
			t.Errorf("#%d %s %s: %d %q, want %d %q", i, method, path, resp.StatusCode, got, status, wantBody)
		}
		have := map[string]string{}
		for k, vals := range resp.Header {
			lower := strings.ToLower(k)
			switch lower {
			case "date", "content-length", "ratelimit", "ratelimit-policy", "etag":
				continue
			}
			have[lower] = strings.Join(vals, ", ")
		}
		if asJSON(have) != asJSON(wantHeaders) {
			keys := func(m map[string]string) []string {
				out := []string{}
				for k := range m {
					out = append(out, k+"="+m[k])
				}
				sort.Strings(out)
				return out
			}
			t.Errorf("#%d %s %s headers:\n got: %v\nwant: %v", i, method, path, keys(have), keys(wantHeaders))
		}
	}
	for i, c := range v.HTTP {
		if i == len(v.HTTP)-1 {
			g.running = false
		}
		run(i, c.Method, c.Path, c.Headers, c.Status, c.ResponseHeaders, c.Body)
	}
	g.running = true
	if len(v.HTTP) < 16 || len(v.Tool) < 11 {
		t.Fatalf("vectors missing: %d requests, %d tool calls", len(v.HTTP), len(v.Tool))
	}
	check("stop by name", last)
}
