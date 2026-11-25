package gitproxy

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

type vectorParsed struct {
	Complete bool        `json:"complete"`
	Commands []vectorCmd `json:"commands"`
	Caps     []string    `json:"clientCapabilities"`
	Error    string      `json:"error"`
}

type vectorCmd struct {
	OldID string `json:"oldId"`
	NewID string `json:"newId"`
	Ref   string `json:"ref"`
}

type vector struct {
	Body    string       `json:"body"`
	Parsed  vectorParsed `json:"parsed"`
	Refusal struct{ Ref, Reason string }
	Report  string `json:"report"`
	// the "long" entry carries its input directly
	Commands []vectorCmd `json:"commands"`
	CapsIn   []string    `json:"caps"`
}

func loadVectors(t *testing.T) map[string]vector {
	t.Helper()
	raw, err := os.ReadFile("testdata/node_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]struct {
		vector
		Refusal struct {
			Ref    string `json:"ref"`
			Reason string `json:"reason"`
		} `json:"refusal"`
	}
	if err := json.Unmarshal(raw, &m); err != nil {
		t.Fatal(err)
	}
	out := map[string]vector{}
	for k, v := range m {
		v.vector.Refusal = struct{ Ref, Reason string }(v.Refusal)
		out[k] = v.vector
	}
	return out
}

func commands(in []vectorCmd) []PushCommand {
	var out []PushCommand
	for _, c := range in {
		out = append(out, PushCommand{OldID: c.OldID, NewID: c.NewID, Ref: c.Ref})
	}
	return out
}

func TestPushPolicyMatchesNode(t *testing.T) {
	for name, v := range loadVectors(t) {
		t.Run(name, func(t *testing.T) {
			cmds, caps := commands(v.Parsed.Commands), v.Parsed.Caps
			if name == "long" {
				cmds, caps = commands(v.Commands), v.CapsIn
			} else {
				body, _ := base64.StdEncoding.DecodeString(v.Body)
				got, err := parsePushCommands(body)
				if v.Parsed.Error != "" {
					if err == nil || err.Error() != v.Parsed.Error {
						t.Fatalf("error = %v, want %q", err, v.Parsed.Error)
					}
					return
				}
				if err != nil || got.complete != v.Parsed.Complete {
					t.Fatalf("complete = %v err %v, want %v", got.complete, err, v.Parsed.Complete)
				}
				if got.complete {
					if len(got.commands) != len(cmds) {
						t.Fatalf("commands = %v, want %v", got.commands, cmds)
					}
					for i := range cmds {
						if got.commands[i] != cmds[i] {
							t.Fatalf("command %d = %v, want %v", i, got.commands[i], cmds[i])
						}
					}
					if strings.Join(got.clientCapabilities, "|") != strings.Join(caps, "|") {
						t.Fatalf("caps = %q, want %q", got.clientCapabilities, caps)
					}
				}
			}
			if v.Report != "" {
				want, _ := base64.StdEncoding.DecodeString(v.Report)
				got := buildPushRefusalReport(cmds, caps, refusal{ref: v.Refusal.Ref, reason: v.Refusal.Reason})
				if string(got) != string(want) {
					t.Fatalf("report differs:\n got %q\nwant %q", got, want)
				}
			}
		})
	}
}

// fakeGitHub records what the proxy sends upstream.
type fakeGitHub struct {
	mu       sync.Mutex
	requests []string
	auth     []string
	bodies   []string
	branch   string
	status   int
}

func (f *fakeGitHub) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	body, _ := io.ReadAll(r.Body)
	f.mu.Lock()
	f.requests = append(f.requests, r.Method+" "+r.URL.RequestURI())
	f.auth = append(f.auth, r.Header.Get("Authorization"))
	f.bodies = append(f.bodies, string(body))
	f.mu.Unlock()
	switch {
	case strings.HasPrefix(r.URL.Path, "/repos/"):
		_, _ = io.WriteString(w, `{"default_branch":"`+f.branch+`"}`)
	case f.status != 0:
		w.WriteHeader(f.status)
	default:
		w.Header().Set("Content-Type", "application/x-git-upload-pack-advertisement")
		w.Header().Set("Cache-Control", "no-cache")
		_, _ = io.WriteString(w, "UPSTREAM")
	}
}

type env struct {
	proxy *Proxy
	mux   *http.ServeMux
	gh    *fakeGitHub
	db    *dbx.DB
	box   *secretbox.Box
}

func newEnv(t *testing.T) *env {
	t.Helper()
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "n.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	box, _ := secretbox.New("enc:v1:", "key")
	gh := &fakeGitHub{branch: "main"}
	srv := httptest.NewServer(gh)
	t.Cleanup(srv.Close)
	p := New(Config{
		Connections: DBConnections{DB: db, Box: box}, Port: 3333, Log: slog.New(slog.DiscardHandler),
		Client: srv.Client(), BaseURL: srv.URL, APIBaseURL: srv.URL,
	})
	mux := http.NewServeMux()
	p.Routes(mux)
	return &env{proxy: p, mux: mux, gh: gh, db: db, box: box}
}

func (e *env) connect(t *testing.T, metadata string) {
	t.Helper()
	ctx := context.Background()
	mustExec(t, e.db, ctx, `INSERT INTO users (id, username, password) VALUES (1, 'u', 'x')`)
	mustExec(t, e.db, ctx, `INSERT INTO agents (id, user_id, slug, display_name) VALUES ('a1', 1, 'main', 'Main')`)
	sealed, _ := e.box.Seal(`{"access_token":"gho_secret"}`)
	mustExec(t, e.db, ctx, `INSERT INTO integration_connections (user_id, agent_id, provider_key, app_key, status, account_email, credentials_json, metadata_json)
		VALUES (1, 'a1', 'github', 'repos', 'connected', 'octo', ?, ?)`, sealed, metadata)
}

func mustExec(t *testing.T, db *dbx.DB, ctx context.Context, q string, args ...any) {
	t.Helper()
	if _, err := db.W.ExecContext(ctx, q, args...); err != nil {
		t.Fatal(err)
	}
}

func (e *env) do(method, path, capability string, body string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	if capability != "" {
		req.Header.Set(capabilityHeader, capability)
	}
	rec := httptest.NewRecorder()
	e.mux.ServeHTTP(rec, req)
	return rec
}

func (e *env) capability(t *testing.T) string {
	t.Helper()
	got, err := e.proxy.GuestEnv(context.Background(), GuestEnvRequest{UserID: 1, AgentID: "a1", RunID: "r1", GuestHost: "10.0.2.2", TTL: time.Minute})
	if err != nil || got == nil {
		t.Fatalf("GuestEnv = %v, %v", got, err)
	}
	return strings.TrimPrefix(got["GIT_CONFIG_VALUE_3"], "X-NeoAgent-Git-Capability: ")
}

func TestGuestEnv(t *testing.T) {
	e := newEnv(t)
	if got, err := e.proxy.GuestEnv(context.Background(), GuestEnvRequest{UserID: 1, AgentID: "a1", GuestHost: "h"}); got != nil || err != nil {
		t.Fatalf("without a connection: %v %v", got, err)
	}
	e.connect(t, `{"userId":4242}`)
	env, err := e.proxy.GuestEnv(context.Background(), GuestEnvRequest{UserID: 1, AgentID: "a1", GuestHost: "10.0.2.2", TTL: time.Minute})
	if err != nil {
		t.Fatal(err)
	}
	base := "http://10.0.2.2:3333/api/git-proxy/github.com/"
	want := map[string]string{
		"GIT_CONFIG_COUNT": "4", "GIT_TERMINAL_PROMPT": "0",
		"GIT_CONFIG_KEY_0": "url." + base + ".insteadOf", "GIT_CONFIG_VALUE_0": "https://github.com/",
		"GIT_CONFIG_KEY_1": "url." + base + ".insteadOf", "GIT_CONFIG_VALUE_1": "git@github.com:",
		"GIT_CONFIG_KEY_2": "url." + base + ".insteadOf", "GIT_CONFIG_VALUE_2": "ssh://git@github.com/",
		"GIT_CONFIG_KEY_3": "http." + base + ".extraHeader",
		"GIT_AUTHOR_NAME":  "octo", "GIT_AUTHOR_EMAIL": "4242+octo@users.noreply.github.com",
		"GIT_COMMITTER_NAME": "octo", "GIT_COMMITTER_EMAIL": "4242+octo@users.noreply.github.com",
	}
	for k, v := range want {
		if env[k] != v {
			t.Errorf("%s = %q, want %q", k, env[k], v)
		}
	}
	if !strings.HasPrefix(env["GIT_CONFIG_VALUE_3"], "X-NeoAgent-Git-Capability: ") || len(env["GIT_CONFIG_VALUE_3"]) != len("X-NeoAgent-Git-Capability: ")+43 {
		t.Errorf("capability header = %q", env["GIT_CONFIG_VALUE_3"])
	}
	if len(env) != len(want)+1 {
		t.Errorf("env = %v", env)
	}
}

func TestProxyRefusesWithoutValidCapability(t *testing.T) {
	e := newEnv(t)
	e.connect(t, `{}`)
	rec := e.do("GET", "/api/git-proxy/github.com/o/r.git/info/refs?service=git-upload-pack", "nope", "")
	if rec.Code != 403 || rec.Body.String() != "NeoAgent: git access for this command has expired. Run the git command again.\n" {
		t.Fatalf("%d %q", rec.Code, rec.Body.String())
	}
	if ct := rec.Header().Get("Content-Type"); ct != "text/plain; charset=utf-8" {
		t.Fatalf("content type %q", ct)
	}
	if len(e.gh.requests) != 0 {
		t.Fatal("reached GitHub")
	}
}

func TestProxyRequestShape(t *testing.T) {
	e := newEnv(t)
	e.connect(t, `{}`)
	c := e.capability(t)
	cases := []struct {
		method, path string
		code         int
		body         string
	}{
		{"GET", "/api/git-proxy/github.com/", 404, "NeoAgent: only GitHub repository clone, fetch, and push requests are proxied.\n"},
		{"GET", "/api/git-proxy/github.com/o/r/blob/x", 404, "NeoAgent: only GitHub repository clone, fetch, and push requests are proxied.\n"},
		{"GET", "/api/git-proxy/github.com/o/r.git/info/refs?service=other", 400, "NeoAgent: unsupported git request.\n"},
		{"POST", "/api/git-proxy/github.com/o/r.git/info/refs?service=git-upload-pack", 400, "NeoAgent: unsupported git request.\n"},
		{"GET", "/api/git-proxy/github.com/o/r.git/git-upload-pack", 400, "NeoAgent: unsupported git request.\n"},
	}
	for _, tc := range cases {
		rec := e.do(tc.method, tc.path, c, "")
		if rec.Code != tc.code || rec.Body.String() != tc.body {
			t.Errorf("%s %s = %d %q", tc.method, tc.path, rec.Code, rec.Body.String())
		}
	}
}

func TestProxyForwardsFetch(t *testing.T) {
	e := newEnv(t)
	e.connect(t, `{}`)
	rec := e.do("GET", "/api/git-proxy/github.com/octo/repo/info/refs?service=git-upload-pack", e.capability(t), "")
	if rec.Code != 200 || rec.Body.String() != "UPSTREAM" || rec.Header().Get("Cache-Control") != "no-cache" ||
		rec.Header().Get("Content-Type") != "application/x-git-upload-pack-advertisement" {
		t.Fatalf("%d %q %v", rec.Code, rec.Body.String(), rec.Header())
	}
	if got := e.gh.requests[0]; got != "GET /octo/repo.git/info/refs?service=git-upload-pack" {
		t.Fatalf("upstream request %q", got)
	}
	if got := e.gh.auth[0]; got != "Basic "+base64.StdEncoding.EncodeToString([]byte("x-access-token:gho_secret")) {
		t.Fatalf("auth %q", got)
	}

	e.gh.status = 401
	rec = e.do("GET", "/api/git-proxy/github.com/octo/repo/info/refs?service=git-upload-pack", e.capability(t), "")
	if rec.Code != 403 || !strings.Contains(rec.Body.String(), "GitHub rejected this agent's token.") {
		t.Fatalf("%d %q", rec.Code, rec.Body.String())
	}
}

func TestProxyConnectionRules(t *testing.T) {
	e := newEnv(t)
	e.connect(t, `{"access_mode":"read_only"}`)
	c := e.capability(t)
	rec := e.do("POST", "/api/git-proxy/github.com/o/r.git/git-receive-pack", c, "")
	if rec.Code != 403 || rec.Body.String() != "NeoAgent: this agent's GitHub connection is read-only.\n" {
		t.Fatalf("%d %q", rec.Code, rec.Body.String())
	}
	// Reads stay allowed.
	if rec := e.do("POST", "/api/git-proxy/github.com/o/r.git/git-upload-pack", c, "0000"); rec.Code != 200 {
		t.Fatalf("upload-pack %d", rec.Code)
	}
	mustExec(t, e.db, context.Background(), `DELETE FROM integration_connections`)
	rec = e.do("POST", "/api/git-proxy/github.com/o/r.git/git-upload-pack", c, "0000")
	if rec.Code != 403 || !strings.Contains(rec.Body.String(), "no connected GitHub account") {
		t.Fatalf("%d %q", rec.Code, rec.Body.String())
	}
}

func pkt(s string) string { return string(pktLine([]byte(s))) }

func TestProxyPushPolicy(t *testing.T) {
	zero, a, b := strings.Repeat("0", 40), strings.Repeat("a", 40), strings.Repeat("b", 40)
	push := func(commands ...string) string { return strings.Join(commands, "") + "0000PACK" }
	cases := []struct {
		name      string
		body      string
		forwarded bool
		reason    string
	}{
		{"new branch", push(pkt(zero + " " + a + " refs/heads/feat\x00 report-status\n")), true, ""},
		{"update feature branch", push(pkt(a + " " + b + " refs/heads/feat\x00 report-status\n")), true, ""},
		{"update default branch", push(pkt(a + " " + b + " refs/heads/main\x00 report-status\n")), false,
			"pushes to the default branch main are blocked; push a feature branch and open a pull request"},
		{"create default branch", push(pkt(zero + " " + a + " refs/heads/main\x00 report-status\n")), true, ""},
		{"delete tag", push(pkt(a + " " + zero + " refs/tags/v1\x00 report-status\n")), false, "agents may not delete remote branches or tags"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			e := newEnv(t)
			e.connect(t, `{}`)
			rec := e.do("POST", "/api/git-proxy/github.com/o/r.git/git-receive-pack", e.capability(t), tc.body)
			upstream := 0
			for _, r := range e.gh.requests {
				if strings.Contains(r, "git-receive-pack") {
					upstream++
				}
			}
			if tc.forwarded {
				if upstream != 1 || e.gh.bodies[len(e.gh.bodies)-1] != tc.body || rec.Body.String() != "UPSTREAM" {
					t.Fatalf("not forwarded intact: upstream=%d body=%q", upstream, rec.Body.String())
				}
				return
			}
			if upstream != 0 || rec.Code != 200 || rec.Header().Get("Content-Type") != "application/x-git-receive-pack-result" ||
				!strings.Contains(rec.Body.String(), tc.reason) {
				t.Fatalf("refusal wrong: upstream=%d %d %q", upstream, rec.Code, rec.Body.String())
			}
		})
	}
}

func TestProxyPushErrors(t *testing.T) {
	e := newEnv(t)
	e.connect(t, `{}`)
	c := e.capability(t)
	req := httptest.NewRequest("POST", "/api/git-proxy/github.com/o/r.git/git-receive-pack", strings.NewReader("0000"))
	req.Header.Set(capabilityHeader, c)
	req.Header.Set("Content-Encoding", "gzip")
	rec := httptest.NewRecorder()
	e.mux.ServeHTTP(rec, req)
	if rec.Code != 415 || rec.Body.String() != "NeoAgent: Compressed push requests are not supported.\n" {
		t.Fatalf("%d %q", rec.Code, rec.Body.String())
	}
	rec = e.do("POST", "/api/git-proxy/github.com/o/r.git/git-receive-pack", c, "0003xx")
	if rec.Code != 502 || rec.Body.String() != "NeoAgent: Malformed receive-pack request.\n" {
		t.Fatalf("%d %q", rec.Code, rec.Body.String())
	}
	rec = e.do("POST", "/api/git-proxy/github.com/o/r.git/git-receive-pack", c, "")
	if rec.Code != 502 || rec.Body.String() != "NeoAgent: Push request ended before its command list.\n" {
		t.Fatalf("%d %q", rec.Code, rec.Body.String())
	}
}

func TestCapabilitiesExpire(t *testing.T) {
	now := time.Unix(1000, 0)
	c := newCapabilities(func() time.Time { return now })
	token, err := c.mint(Grant{UserID: 1, AgentID: "a"}, time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	if g, ok := c.resolve(token); !ok || g.AgentID != "a" {
		t.Fatal("fresh capability not found")
	}
	now = now.Add(time.Minute + capabilityGrace - time.Second)
	if _, ok := c.resolve(token); !ok {
		t.Fatal("grace period not honoured")
	}
	now = now.Add(2 * time.Second)
	if _, ok := c.resolve(token); ok {
		t.Fatal("expired capability resolved")
	}
	if _, ok := c.resolve(""); ok {
		t.Fatal("empty token resolved")
	}
}
