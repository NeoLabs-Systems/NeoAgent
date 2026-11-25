package mcpserver

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/mcp"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	sdk "github.com/modelcontextprotocol/go-sdk/mcp"
)

//go:embed testdata/node_vectors.json
var vectorsJSON []byte

func TestNodeVectors(t *testing.T) {
	var v struct {
		Endpoints []struct{ Input, Ok, Error string }
		Slugs     []struct {
			Name string
			ID   int64
			Slug string
		}
		Errors []struct{ Message, Out string }
	}
	if err := json.Unmarshal(vectorsJSON, &v); err != nil {
		t.Fatal(err)
	}
	for _, c := range v.Endpoints {
		got, err := ValidateEndpoint(c.Input)
		if c.Error != "" {
			if err == nil || err.Error() != c.Error {
				t.Errorf("endpoint %q: err %v, want %q", c.Input, err, c.Error)
			}
		} else if err != nil || got != c.Ok {
			t.Errorf("endpoint %q: got %q (%v), want %q", c.Input, got, err, c.Ok)
		}
	}
	for _, c := range v.Slugs {
		if got := slugFor(c.Name, c.ID); got != c.Slug {
			t.Errorf("slug %q: got %q want %q", c.Name, got, c.Slug)
		}
	}
	for _, c := range v.Errors {
		var err error = errors.New(c.Message)
		if strings.Contains(c.Message, "ECONNREFUSED 127") {
			err = errors.New("Get \"x\": dial tcp 127.0.0.1:3000: connect: connection refused")
		} else if c.Message == "ECONNREFUSED" {
			err = errors.New("connection refused")
		}
		if got := errorMessage(err); got != c.Out {
			t.Errorf("error %q: got %q want %q", c.Message, got, c.Out)
		}
	}
}

type env struct {
	db     *dbx.DB
	store  *Store
	mgr    *Manager
	api    *API
	srv    *httptest.Server
	events chan StatusEvent
}

func newEnv(t *testing.T, mod func(*ManagerConfig)) *env {
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
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'a', 'x'), (2, 'b', 'x')`); err != nil {
		t.Fatal(err)
	}
	box, _ := secretbox.New("enc:v1:", "k")
	store := &Store{DB: db, Box: box}
	events := make(chan StatusEvent, 64)
	cfg := ManagerConfig{Store: store, Log: slog.New(slog.NewTextHandler(io.Discard, nil)), HTTPClient: &http.Client{},
		RedirectURL: "http://localhost/api/mcp/oauth/callback", OnStatus: func(e StatusEvent) { events <- e }}
	if mod != nil {
		mod(&cfg)
	}
	mgr := NewManager(cfg)
	t.Cleanup(mgr.Shutdown)
	api := New(Config{Manager: mgr, Agents: agentscope.Resolver{DB: db}, Log: cfg.Log, PublicBaseURL: "https://agent.example.com/",
		UserID: func(r *http.Request) (int64, bool) {
			if r.Header.Get("X-Test-User") == "" {
				return 0, false
			}
			return map[string]int64{"1": 1, "2": 2}[r.Header.Get("X-Test-User")], true
		}})
	mux := http.NewServeMux()
	api.Routes(mux)
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	return &env{db, store, mgr, api, srv, events}
}

func (e *env) do(t *testing.T, user, method, path, payload string) (int, string) {
	t.Helper()
	req, _ := http.NewRequest(method, e.srv.URL+path, strings.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	if user != "" {
		req.Header.Set("X-Test-User", user)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return res.StatusCode, string(b)
}

func mcpBackend() http.Handler {
	s := sdk.NewServer(&sdk.Implementation{Name: "t", Version: "1"}, nil)
	type in struct {
		Text string `json:"text"`
	}
	sdk.AddTool(s, &sdk.Tool{Name: "echo", Description: "echoes"}, func(_ context.Context, _ *sdk.CallToolRequest, a in) (*sdk.CallToolResult, any, error) {
		return &sdk.CallToolResult{Content: []sdk.Content{&sdk.TextContent{Text: a.Text}}}, nil, nil
	})
	return sdk.NewStreamableHTTPHandler(func(*http.Request) *sdk.Server { return s }, nil)
}

func jsonOf(t *testing.T, s string) map[string]any {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal([]byte(s), &m); err != nil {
		t.Fatalf("not an object: %s", s)
	}
	return m
}

func TestRoutesEndToEnd(t *testing.T) {
	e := newEnv(t, nil)
	backend := httptest.NewServer(mcpBackend())
	defer backend.Close()

	if code, _ := e.do(t, "", "GET", "/api/mcp", ""); code != 401 {
		t.Fatalf("anonymous: %d", code)
	}
	code, out := e.do(t, "1", "POST", "/api/mcp", `{"name":"Echo Box","command":"`+backend.URL+`","config":{"transport":"streamable-http","headers":{"X-Api-Key":"sekret"},"auth":{"type":"bearer","token":"tok"}}}`)
	if code != 201 {
		t.Fatalf("create: %d %s", code, out)
	}
	if got := jsonOf(t, out); got["id"] != float64(1) || got["name"] != "Echo Box" || got["command"] != backend.URL+"/" {
		t.Fatalf("create body %v", got)
	}
	if code, out := e.do(t, "1", "POST", "/api/mcp", `{"name":"x"}`); code != 400 || out != `{"error":"name and command are required"}` {
		t.Fatalf("missing command: %d %s", code, out)
	}
	if code, out := e.do(t, "1", "POST", "/api/mcp", `{"name":"x","command":"npx foo"}`); code != 400 || !strings.Contains(out, "valid remote http(s) URL") {
		t.Fatalf("bad command: %d %s", code, out)
	}

	var raw string
	if err := e.db.W.QueryRow(`SELECT config FROM mcp_servers WHERE id = 1`).Scan(&raw); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(raw, "sekret") || strings.Contains(raw, `"tok"`) || !strings.Contains(raw, "enc:v1:") {
		t.Fatalf("secrets stored in the clear: %s", raw)
	}

	_, list := e.do(t, "1", "GET", "/api/mcp", "")
	var servers []map[string]any
	_ = json.Unmarshal([]byte(list), &servers)
	if len(servers) != 1 || servers[0]["status"] != "stopped" || servers[0]["enabled"] != true || servers[0]["toolCount"] != float64(0) || servers[0]["error"] != nil {
		t.Fatalf("list %s", list)
	}
	if servers[0]["config"].(map[string]any)["headers"].(map[string]any)["X-Api-Key"] != "sekret" {
		t.Fatalf("config not unsealed in the API: %s", list)
	}
	if _, other := e.do(t, "2", "GET", "/api/mcp", ""); other != "[]" {
		t.Fatalf("other account sees %s", other)
	}
	if code, _ := e.do(t, "2", "POST", "/api/mcp/1/start", ""); code != 404 {
		t.Fatalf("foreign start: %d", code)
	}

	code, out = e.do(t, "1", "POST", "/api/mcp/1/start", "")
	if code != 200 || jsonOf(t, out)["status"] != "running" {
		t.Fatalf("start: %d %s", code, out)
	}
	_, all := e.do(t, "1", "GET", "/api/mcp/tools/all", "")
	var tools []map[string]any
	_ = json.Unmarshal([]byte(all), &tools)
	if len(tools) != 1 || tools[0]["name"] != "mcp_echo_box_echo" || tools[0]["originalName"] != "echo" || tools[0]["serverId"] != float64(1) || tools[0]["parameters"] == nil {
		t.Fatalf("tools/all %s", all)
	}
	code, out = e.do(t, "1", "POST", "/api/mcp/tools/call", `{"serverId":1,"toolName":"echo","args":{"text":"hi"}}`)
	if code != 200 || !strings.Contains(out, `"text":"hi"`) {
		t.Fatalf("call: %d %s", code, out)
	}
	if code, _ := e.do(t, "1", "POST", "/api/mcp/tools/call", `{"serverId":99,"toolName":"echo"}`); code != 404 {
		t.Fatalf("call unknown: %d", code)
	}
	if code, out := e.do(t, "1", "POST", "/api/mcp/tools/call", `{"serverId":1}`); code != 400 || out != `{"error":"serverId and toolName required"}` {
		t.Fatalf("call missing: %d %s", code, out)
	}
	if code, out := e.do(t, "1", "POST", "/api/mcp/tools/call", `{"serverId":1,"toolName":"nope"}`); code != 500 || !strings.Contains(out, `MCP tool \"nope\" failed`) {
		t.Fatalf("call bad tool: %d %s", code, out)
	}
	res, found, err := e.mgr.CallToolByName("mcp_echo_box_echo", map[string]any{"text": "yo"}, 1, "")
	if err != nil || !found || !strings.Contains(toJSON(res), "yo") {
		t.Fatalf("by name: %v %v %v", res, found, err)
	}
	if _, found, _ := e.mgr.CallToolByName("mcp_other_echo", nil, 1, ""); found {
		t.Fatal("unknown server matched")
	}
	if code, out := e.do(t, "1", "GET", "/api/mcp/1/tools", ""); code != 200 || !strings.Contains(out, `"name":"echo"`) {
		t.Fatalf("tools: %d %s", code, out)
	}

	_, list = e.do(t, "1", "GET", "/api/mcp", "")
	_ = json.Unmarshal([]byte(list), &servers)
	if servers[0]["status"] != "running" || servers[0]["toolCount"] != float64(1) {
		t.Fatalf("live list %s", list)
	}

	code, out = e.do(t, "1", "PUT", "/api/mcp/1", `{"name":"Renamed","enabled":false}`)
	if code != 200 || out != `{"success":true,"status":"stopped"}` {
		t.Fatalf("put: %d %s", code, out)
	}
	if e.mgr.IsLive(1) {
		t.Fatal("update left the server running")
	}
	var name, status string
	var enabled int
	_ = e.db.W.QueryRow(`SELECT name, status, enabled FROM mcp_servers WHERE id = 1`).Scan(&name, &status, &enabled)
	if name != "Renamed" || status != "stopped" || enabled != 0 {
		t.Fatalf("row after put: %s %s %d", name, status, enabled)
	}
	if code, out := e.do(t, "1", "POST", "/api/mcp/1/stop", ""); code != 200 || out != `{"status":"stopped"}` {
		t.Fatalf("stop: %d %s", code, out)
	}
	if code, _ := e.do(t, "1", "GET", "/api/mcp/1/tools", ""); code != 500 {
		t.Fatalf("tools of stopped server: %d", code)
	}
	if code, out := e.do(t, "1", "DELETE", "/api/mcp/1", ""); code != 200 || out != `{"success":true}` {
		t.Fatalf("delete: %d %s", code, out)
	}
	if code, out := e.do(t, "1", "DELETE", "/api/mcp/1", ""); code != 404 || out != `{"error":"Server not found"}` {
		t.Fatalf("delete again: %d %s", code, out)
	}
}

func toJSON(v any) string { b, _ := json.Marshal(v); return string(b) }

func TestSSRFRefusesPrivateByDefault(t *testing.T) {
	e := newEnv(t, func(c *ManagerConfig) { c.HTTPClient = mcp.DefaultHTTPClient() })
	backend := httptest.NewServer(mcpBackend())
	defer backend.Close()
	_, _ = e.do(t, "1", "POST", "/api/mcp", `{"name":"L","command":"`+backend.URL+`","config":{"transport":"streamable-http"}}`)
	if code, _ := e.do(t, "1", "POST", "/api/mcp/1/start", ""); code != 500 {
		t.Fatalf("loopback MCP endpoint reached: %d", code)
	}
}

type fakeSession struct {
	calls  atomic.Int32
	failIn atomic.Bool
}

func (f *fakeSession) Tools(context.Context) ([]map[string]any, error) {
	return []map[string]any{{"name": "t", "inputSchema": map[string]any{"type": "object"}}}, nil
}
func (f *fakeSession) Call(context.Context, string, map[string]any) (map[string]any, error) {
	f.calls.Add(1)
	if f.failIn.Load() {
		return nil, errors.New("boom\nstack")
	}
	return map[string]any{"ok": true}, nil
}
func (f *fakeSession) Close() error { return nil }

func waitFor(t *testing.T, what string, ok func() bool) {
	t.Helper()
	for i := 0; i < 400; i++ {
		if ok() {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", what)
}

func TestFailureThresholdAndReconnect(t *testing.T) {
	sess := &fakeSession{}
	var dials atomic.Int32
	e := newEnv(t, func(c *ManagerConfig) {
		c.ReconnectDelay = 20 * time.Millisecond
		c.MaxReconnectDelay = 50 * time.Millisecond
		c.Connect = func(context.Context, mcp.Config) (Session, error) { dials.Add(1); return sess, nil }
	})
	id, _ := e.store.Insert(context.Background(), 1, "", "Fake", "http://x.example/mcp", nil, true)
	if _, err := e.mgr.Start(context.Background(), id, "http://x.example/mcp", "Fake", 1, ""); err != nil {
		t.Fatal(err)
	}
	sess.failIn.Store(true)
	for i := 1; i <= 3; i++ {
		_, err := e.mgr.CallTool(id, "t", nil, 1)
		if err == nil || err.Error() != `MCP tool "t" failed: boom` {
			t.Fatalf("call %d: %v", i, err)
		}
		st := e.mgr.Status(1, "")[id]
		if i < 3 && st.Status != "running" {
			t.Fatalf("flipped early after %d failures: %v", i, st)
		}
	}
	sess.failIn.Store(false)
	waitFor(t, "reconnect", func() bool { return dials.Load() >= 2 && e.mgr.Status(1, "")[id].Status == "running" })
	if st := e.mgr.Status(1, "")[id]; st.ConsecutiveFails != 0 || st.Error != "" {
		t.Fatalf("not reset after reconnect: %+v", st)
	}
	if _, err := e.mgr.CallTool(id, "t", nil, 2); err == nil || err.Error() != "Server 1 not found" {
		t.Fatalf("foreign call: %v", err)
	}
}

func TestStartTimeoutAndStopPersist(t *testing.T) {
	e := newEnv(t, func(c *ManagerConfig) {
		c.OperationTimeout = 50 * time.Millisecond
		c.Connect = func(ctx context.Context, _ mcp.Config) (Session, error) { <-ctx.Done(); return nil, ctx.Err() }
	})
	id, _ := e.store.Insert(context.Background(), 1, "", "Slow", "http://x.example/", nil, true)
	_, err := e.mgr.Start(context.Background(), id, "http://x.example/", "Slow", 1, "")
	if err == nil || err.Error() != `Connecting to MCP server "Slow" timed out after 50 ms` {
		t.Fatalf("got %v", err)
	}
	if st := e.mgr.Status(1, "")[id]; st.Status != "error" || st.ConsecutiveFails != 1 {
		t.Fatalf("status %+v", st)
	}
	var persisted string
	_ = e.db.W.QueryRow(`SELECT status FROM mcp_servers WHERE id = ?`, id).Scan(&persisted)
	if persisted != "error" {
		t.Fatalf("persisted %q", persisted)
	}
	e.mgr.Stop(id)
	_ = e.db.W.QueryRow(`SELECT status FROM mcp_servers WHERE id = ?`, id).Scan(&persisted)
	if persisted != "stopped" || e.mgr.IsLive(id) {
		t.Fatalf("after stop: %q live=%v", persisted, e.mgr.IsLive(id))
	}
}

func TestOAuthStateAndCallback(t *testing.T) {
	e := newEnv(t, nil)
	ctx := context.Background()
	id, _ := e.store.Insert(ctx, 1, "", "O", "http://x.example/", map[string]any{"auth": map[string]any{"type": "oauth"}}, true)
	state := newState(id)
	if err := e.store.SaveAuthState(ctx, id, state); err != nil {
		t.Fatal(err)
	}
	cfg, _ := e.store.ServerConfig(ctx, id)
	if cfg["auth"].(map[string]any)["oauthStateHash"] != hashState(state) {
		t.Fatalf("hash not stored: %v", cfg)
	}
	if ok, _ := e.store.ConsumeState(ctx, id, newState(id)); ok {
		t.Fatal("wrong state accepted")
	}
	// callback guards, in Node's order
	for _, c := range []struct {
		user, path string
		code       int
		body       string
	}{
		{"1", "/api/mcp/oauth/callback", 400, "Missing state parameter"},
		{"1", "/api/mcp/oauth/callback?state=zzz", 400, "Invalid state format"},
		{"2", "/api/mcp/oauth/callback?state=" + state + "&code=c", 404, "Server not found"},
		{"1", "/api/mcp/oauth/callback?state=" + state, 400, "Missing code parameter"},
		{"1", "/api/mcp/oauth/callback?state=" + state + "&code=c", 500, "Failed to finish OAuth: Server 1 transport not initialized"},
		{"1", "/api/mcp/oauth/callback?state=" + state + "&code=c", 400, "Invalid or expired OAuth state"},
	} {
		code, body := e.do(t, c.user, "GET", c.path, "")
		if code != c.code || body != c.body {
			t.Errorf("%s: got %d %q want %d %q", c.path, code, body, c.code, c.body)
		}
	}
	state2 := newState(id)
	_ = e.store.SaveAuthState(ctx, id, state2)
	if code, body := e.do(t, "1", "GET", "/api/mcp/oauth/callback?state="+state2+"&error=access_denied", ""); code != 400 || body != "OAuth error: access_denied" {
		t.Errorf("oauth error: %d %q", code, body)
	}
}

func TestSuccessPageMatchesNode(t *testing.T) {
	got := strings.TrimSpace(strings.ReplaceAll(strings.ReplaceAll(successPage, "%d", "5"), "%s", `"https://a.example"`))
	want := "<html><body>\n      <script>\n        if (window.opener) {\n          window.opener.postMessage({ type: 'mcp_oauth_success', serverId: 5 }, \"https://a.example\");"
	if !strings.Contains(got, want) {
		t.Fatalf("page differs from Node's:\n%s", got)
	}
}

func TestLoadFromDB(t *testing.T) {
	e := newEnv(t, func(c *ManagerConfig) {
		c.ReconnectDelay = time.Hour
		c.Connect = func(_ context.Context, cfg mcp.Config) (Session, error) {
			if strings.Contains(cfg.Endpoint, "bad") {
				return nil, errors.New("nope")
			}
			return &fakeSession{}, nil
		}
	})
	ctx := context.Background()
	_, _ = e.store.Insert(ctx, 1, "", "Good", "http://good.example/", nil, true)
	_, _ = e.store.Insert(ctx, 1, "", "Bad", "http://bad.example/", nil, true)
	_, _ = e.store.Insert(ctx, 1, "", "Off", "http://off.example/", nil, false)
	res, err := e.mgr.LoadFromDB(ctx, 1)
	if err != nil || len(res) != 2 {
		t.Fatalf("%v %v", res, err)
	}
	if res[0].Status != "running" || res[1].Status != "reconnecting" && res[1].Status != "error" || res[1].Error != "nope" {
		t.Fatalf("%+v", res)
	}
	if bytes.Contains([]byte(toJSON(e.mgr.Status(1, ""))), []byte("Off")) {
		t.Fatal("disabled server started")
	}
}
