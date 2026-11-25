package settings_test

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/cloudsec"
	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

type testLog struct{ t *testing.T }

func (l testLog) Write(p []byte) (int, error) {
	l.t.Log(strings.TrimSpace(string(p)))
	return len(p), nil
}

type stack struct {
	srv *httptest.Server
	db  *dbx.DB
	box *secretbox.Box
	api *settings.API
}

// newStack serves the settings routes over a real SQLite file with the real
// schema. A request is signed in as the account named by X-Test-User.
func newStack(t *testing.T, mutate func(*settings.Config)) *stack {
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
	// The scenario was recorded with SESSION_SECRET=x as the key material.
	box, err := secretbox.New(config.SecretPrefix, "x")
	if err != nil {
		t.Fatal(err)
	}
	cfg := settings.Config{
		DB: db, Box: box, Log: slog.New(slog.NewTextHandler(testLog{t}, nil)),
		RuntimeBackend: settings.RuntimeBackendFor(""),
		UserID: func(r *http.Request) (int64, bool) {
			id, err := strconv.ParseInt(r.Header.Get("X-Test-User"), 10, 64)
			return id, err == nil
		},
	}
	if mutate != nil {
		mutate(&cfg)
	}
	api := settings.New(cfg)
	mux := http.NewServeMux()
	api.Routes(mux)
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	s := &stack{srv: srv, db: db, box: box, api: api}
	s.exec(t, `INSERT INTO users (id, username, password) VALUES (1, 'alice', 'x'), (2, 'bob', 'x')`)
	return s
}

func (s *stack) exec(t *testing.T, query string, args ...any) {
	t.Helper()
	if _, err := s.db.W.Exec(query, args...); err != nil {
		t.Fatalf("%s: %v", query, err)
	}
}

type reply struct {
	status int
	body   any
	raw    string
}

func (s *stack) call(t *testing.T, method, path string, user int, body string, headers map[string]string) reply {
	t.Helper()
	var rdr io.Reader
	if body != "" {
		rdr = strings.NewReader(body)
	}
	req, _ := http.NewRequest(method, s.srv.URL+path, rdr)
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	if user != 0 {
		req.Header.Set("X-Test-User", strconv.Itoa(user))
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	var parsed any
	_ = json.Unmarshal(raw, &parsed)
	return reply{status: resp.StatusCode, body: parsed, raw: string(raw)}
}

// ---- replaying what the Node server answered -------------------------------

type step struct {
	Name    string            `json:"name"`
	Method  string            `json:"method"`
	Path    string            `json:"path"`
	User    int               `json:"user"`
	Headers map[string]string `json:"headers"`
	Body    string            `json:"body"`
	SQL     string            `json:"sql"`
	Expect  *struct {
		Status int `json:"status"`
		Body   any `json:"body"`
	} `json:"expect"`
}

type scenario struct {
	Providers []struct {
		ID              string `json:"id"`
		Authentication  string `json:"authentication"`
		SupportsAPIKey  bool   `json:"supportsApiKey"`
		SupportsBaseURL bool   `json:"supportsBaseUrl"`
		RequiresBaseURL bool   `json:"requiresBaseUrl"`
		DefaultEnabled  bool   `json:"defaultEnabled"`
		DefaultBaseURL  string `json:"defaultBaseUrl"`
	} `json:"providers"`
	SealedByNode string `json:"sealedByNode"`
	Steps        []step `json:"steps"`
	Snapshot     []struct {
		User  int64   `json:"user"`
		Agent *string `json:"agent"`
		Key   string  `json:"key"`
		Value any     `json:"value"`
	} `json:"snapshot"`
}

func loadScenario(t *testing.T) scenario {
	t.Helper()
	raw, err := os.ReadFile("testdata/scenario.json")
	if err != nil {
		t.Fatal(err)
	}
	var sc scenario
	if err := json.Unmarshal(raw, &sc); err != nil {
		t.Fatal(err)
	}
	return sc
}

var dayStamp = regexp.MustCompile(`"date":"\d{4}-\d{2}-\d{2}"`)

// agentLabels names the random agent ids "<agent:user:slug>", as the recorded
// answers do.
func (s *stack) agentLabels(t *testing.T) map[string]string {
	t.Helper()
	rows, err := s.db.W.Query(`SELECT id, user_id, slug FROM agents`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	labels := map[string]string{}
	for rows.Next() {
		var id, slug string
		var user int64
		if err := rows.Scan(&id, &user, &slug); err != nil {
			t.Fatal(err)
		}
		labels[id] = "<agent:" + strconv.FormatInt(user, 10) + ":" + slug + ">"
	}
	return labels
}

func (s *stack) normalize(t *testing.T, text string) string {
	text = dayStamp.ReplaceAllString(text, `"date":"<day>"`)
	for id, label := range s.agentLabels(t) {
		text = strings.ReplaceAll(text, id, label)
	}
	return text
}

func (s *stack) mainAgent(t *testing.T, user int) string {
	var id string
	_ = s.db.W.QueryRow(`SELECT id FROM agents WHERE user_id = ? AND slug = 'main'`, user).Scan(&id)
	return id
}

func pretty(v any) string {
	out, _ := json.Marshal(v)
	if len(out) > 1500 {
		return string(out[:1500]) + "..."
	}
	return string(out)
}

// TestRoutesMatchNode replays 147 requests recorded from the Node server's
// settings router (gen/scenario.js) and requires the same status and body for
// each, and the same settings rows at the end.
func TestRoutesMatchNode(t *testing.T) {
	sc := loadScenario(t)
	s := newStack(t, nil)
	replacer := func() *strings.Replacer {
		return strings.NewReplacer("$main1", s.mainAgent(t, 1), "$main2", s.mainAgent(t, 2), "$helper", "helper-agent-id")
	}
	compared := 0
	for _, st := range sc.Steps {
		if st.SQL != "" {
			s.exec(t, replacer().Replace(st.SQL))
			continue
		}
		compared++
		got := s.call(t, st.Method, st.Path, st.User, st.Body, st.Headers)
		var body any
		if err := json.Unmarshal([]byte(s.normalize(t, got.raw)), &body); err != nil {
			t.Fatalf("%s: answer is not JSON: %q", st.Name, got.raw)
		}
		if got.status != st.Expect.Status || !reflect.DeepEqual(body, st.Expect.Body) {
			t.Errorf("%s: %s %s\n  got  %d %s\n  node %d %s", st.Name, st.Method, st.Path,
				got.status, pretty(body), st.Expect.Status, pretty(st.Expect.Body))
		}
	}

	if compared < 120 {
		t.Fatalf("only %d requests replayed", compared)
	}
	labels := s.agentLabels(t)
	type key struct {
		user  int64
		agent string
		key   string
	}
	rows := map[key]any{}
	collect := func(query string, withAgent bool) {
		res, err := s.db.W.Query(query)
		if err != nil {
			t.Fatal(err)
		}
		defer res.Close()
		for res.Next() {
			var user int64
			var agent, k string
			var value sql.NullString
			if withAgent {
				err = res.Scan(&user, &agent, &k, &value)
			} else {
				err = res.Scan(&user, &k, &value)
			}
			if err != nil {
				t.Fatal(err)
			}
			var v any
			if value.Valid {
				v = value.String
				if withAgent && k == "ai_provider_api_keys" {
					plain, err := s.box.Open(value.String)
					if err != nil {
						t.Fatalf("stored keys are not readable: %v", err)
					}
					var secrets any
					_ = json.Unmarshal([]byte(plain), &secrets)
					v = map[string]any{"decrypted": secrets}
				}
			}
			rows[key{user, labels[agent], k}] = v
		}
	}
	collect(`SELECT user_id, agent_id, key, value FROM agent_settings`, true)
	collect(`SELECT user_id, key, value FROM user_settings`, false)

	want := map[key]any{}
	for _, r := range sc.Snapshot {
		agent := ""
		if r.Agent != nil {
			agent = *r.Agent
		}
		want[key{r.User, agent, r.Key}] = r.Value
	}
	for k, w := range want {
		if g, ok := rows[k]; !ok || !reflect.DeepEqual(g, w) {
			t.Errorf("row %+v: got %s (present %v), node %s", k, pretty(g), ok, pretty(w))
		}
	}
	for k := range rows {
		if _, ok := want[k]; !ok {
			t.Errorf("row %+v exists only in Go", k)
		}
	}
}

// A key sealed by the Node server must open here, and the key set must survive
// being rewritten by Go.
func TestNodeSealedKeysSurviveRewrite(t *testing.T) {
	sc := loadScenario(t)
	s := newStack(t, nil)
	s.call(t, "GET", "/api/settings", 1, "", nil)
	agent := s.mainAgent(t, 1)
	s.exec(t, `INSERT INTO agent_settings (user_id, agent_id, key, value) VALUES (1, ?, 'ai_provider_api_keys', ?)`, agent, sc.SealedByNode)

	if r := s.call(t, "PUT", "/api/settings/byok/google", 1, `{"apiKey":"g-key"}`, nil); r.status != 200 {
		t.Fatalf("%d %s", r.status, r.raw)
	}
	var stored string
	if err := s.db.W.QueryRow(`SELECT value FROM agent_settings WHERE user_id = 1 AND agent_id = ? AND key = 'ai_provider_api_keys'`, agent).Scan(&stored); err != nil {
		t.Fatal(err)
	}
	plain, err := s.box.OpenSealed(stored)
	if err != nil {
		t.Fatal(err)
	}
	if plain != `{"google":"g-key","openai":"sk-from-node"}` {
		t.Fatalf("key set = %s", plain)
	}
}

func TestProvidersMatchNode(t *testing.T) {
	sc := loadScenario(t)
	if len(sc.Providers) != 16 {
		t.Fatalf("%d providers recorded", len(sc.Providers))
	}
	s := newStack(t, nil)
	r := s.call(t, "GET", "/api/settings", 1, "", nil)
	configs := r.body.(map[string]any)["ai_provider_configs"].(map[string]any)
	if len(configs) != len(sc.Providers) {
		t.Fatalf("%d configs for %d providers", len(configs), len(sc.Providers))
	}
	// Order in the stored text, which Node wrote in definition order.
	var stored string
	agent := s.mainAgent(t, 1)
	if err := s.db.W.QueryRow(`SELECT value FROM agent_settings WHERE agent_id = ? AND key = 'ai_provider_configs'`, agent).Scan(&stored); err != nil {
		t.Fatal(err)
	}
	last := -1
	for _, p := range sc.Providers {
		at := strings.Index(stored, `"`+p.ID+`":{`)
		if at <= last {
			t.Fatalf("provider %s out of order in %s", p.ID, stored)
		}
		last = at
		entry := configs[p.ID].(map[string]any)
		wantURL := ""
		if p.SupportsBaseURL {
			wantURL = p.DefaultBaseURL
		}
		if entry["enabled"] != p.DefaultEnabled || entry["baseUrl"] != wantURL {
			t.Errorf("%s default = %v, want enabled=%v baseUrl=%q", p.ID, entry, p.DefaultEnabled, wantURL)
		}
	}
	// Which providers accept a pasted key follows the recorded definitions.
	for _, p := range sc.Providers {
		resp := s.call(t, "PUT", "/api/settings/byok/"+p.ID, 1, `{"apiKey":"k","baseUrl":"https://8.8.8.8/v1"}`, nil)
		eligible := p.Authentication != "oauth" && p.ID != "minimax" && (p.SupportsAPIKey || p.SupportsBaseURL)
		if (resp.status == 404) == eligible {
			t.Errorf("PUT byok/%s answered %d, eligible=%v", p.ID, resp.status, eligible)
		}
		// Restart the limiter window cheaply: 20 calls per minute is plenty for
		// 16 providers.
	}
}

func TestRuntimeBackendFor(t *testing.T) {
	for in, want := range map[string]string{
		"": "qemu", "qemu": "qemu", "weird": "qemu", "Docker": "docker", " containers ": "docker",
		"host": "host", "LOCAL": "host", "server": "host",
	} {
		if got := settings.RuntimeBackendFor(in); got != want {
			t.Errorf("RuntimeBackendFor(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestRuntimeBackendFollowsDeployment(t *testing.T) {
	s := newStack(t, func(c *settings.Config) { c.RuntimeBackend = "docker" })
	got := s.call(t, "GET", "/api/settings", 1, "", nil).body.(map[string]any)
	if got["runtime_backend"] != "docker" || got["runtime_profile"] != "cloud-computer" {
		t.Fatalf("%v", got)
	}
}

// ---- behaviour that differs from Node on purpose, or that Node could not do -

func TestSettingWithoutValueIsRefused(t *testing.T) {
	// Node answered 500 here (it tried to bind undefined); a clear 400 is kinder.
	s := newStack(t, nil)
	r := s.call(t, "PUT", "/api/settings/some_key", 1, `{}`, nil)
	if r.status != 400 || r.body.(map[string]any)["success"] != false {
		t.Fatalf("%d %s", r.status, r.raw)
	}
	if got := s.call(t, "GET", "/api/settings/some_key", 1, "", nil); got.raw != `{"value":null}` {
		t.Fatalf("%s", got.raw)
	}
}

func TestPrototypeProviderNamesAreUnknown(t *testing.T) {
	// Node let DELETE /byok/constructor through as if it were a provider.
	s := newStack(t, nil)
	for _, name := range []string{"constructor", "__proto__", "toString", "OpenAI", ""} {
		for _, method := range []string{"PUT", "DELETE"} {
			if r := s.call(t, method, "/api/settings/byok/"+name, 1, `{"apiKey":"k"}`, nil); r.status != 404 && name != "" {
				t.Errorf("%s byok/%s: %d %s", method, name, r.status, r.raw)
			}
		}
	}
}

func TestUnportedRoutesAreNotFound(t *testing.T) {
	s := newStack(t, nil)
	for _, path := range []string{"/api/settings/byok", "/api/settings/meta/models", "/api/settings/meta/ai-providers", "/api/settings/meta/system-one-models"} {
		if r := s.call(t, "GET", path, 1, "", nil); r.status != 404 {
			t.Errorf("GET %s = %d", path, r.status)
		}
	}
	if r := s.call(t, "POST", "/api/settings/byok/openai/test", 1, `{}`, nil); r.status != 404 && r.status != 405 {
		t.Errorf("POST byok test = %d", r.status)
	}
}

func TestBodyHandling(t *testing.T) {
	s := newStack(t, nil)
	for name, tc := range map[string]struct {
		body   string
		status int
	}{
		"invalid json":    {`{"theme":`, 400},
		"scalar":          {`5`, 400},
		"list is ignored": {`["a","b"]`, 200},
		"null":            {`null`, 400},
		"empty object":    {`{}`, 200},
	} {
		if r := s.call(t, "PUT", "/api/settings", 1, tc.body, nil); r.status != tc.status {
			t.Errorf("%s: %d %s", name, r.status, r.raw)
		}
	}
	var n int
	if err := s.db.W.QueryRow(`SELECT COUNT(*) FROM user_settings`).Scan(&n); err != nil || n != 0 {
		t.Fatalf("user_settings rows = %d, %v", n, err)
	}
}

func TestSessionGuardWithoutAccessor(t *testing.T) {
	// With no accessor wired the guard reads the session, and a request that
	// has none is not signed in.
	s := newStack(t, func(c *settings.Config) { c.UserID = nil })
	for _, path := range []string{"/api/settings", "/api/settings/x", "/api/settings/token-usage/summary"} {
		if r := s.call(t, "GET", path, 1, "", nil); r.status != 401 || r.raw != `{"error":"Unauthorized"}` {
			t.Errorf("%s: %d %s", path, r.status, r.raw)
		}
	}
}

func TestProviderAddressesAreCheckedThroughDNS(t *testing.T) {
	lookup := func(_ context.Context, host string) ([]netip.Addr, error) {
		switch host {
		case "rebind.example.com":
			return []netip.Addr{netip.MustParseAddr("10.0.0.5")}, nil
		case "gone.example.com":
			return nil, errors.New("lookup failed")
		}
		return []netip.Addr{netip.MustParseAddr("93.184.216.34")}, nil
	}
	s := newStack(t, func(c *settings.Config) { c.URLChecker = cloudsec.Checker{Lookup: lookup, Timeout: time.Second} })
	for _, tc := range []struct {
		url    string
		status int
		error  string
	}{
		{"https://rebind.example.com/v1", 400, "rebind.example.com resolves to a local or private network address, which is not reachable from here."},
		{"https://gone.example.com", 400, "Could not resolve gone.example.com. Check that the domain is spelled correctly and exists."},
		{"https://api.example.com/v1", 200, ""},
	} {
		r := s.call(t, "PUT", "/api/settings/byok/openai", 1, `{"apiKey":"k","baseUrl":"`+tc.url+`"}`, nil)
		body := r.body.(map[string]any)
		if r.status != tc.status || (tc.error != "" && body["error"] != tc.error) {
			t.Errorf("%s: %d %s", tc.url, r.status, r.raw)
		}
	}
	got := s.call(t, "GET", "/api/settings", 1, "", nil).body.(map[string]any)["ai_provider_configs"].(map[string]any)["openai"].(map[string]any)
	if got["baseUrl"] != "https://api.example.com/v1" {
		t.Fatalf("stored address = %v", got["baseUrl"])
	}
}

func TestHooksRunAfterChanges(t *testing.T) {
	var mu sync.Mutex
	var prompts []string
	rescheduled := make(chan int64, 4)
	s := newStack(t, func(c *settings.Config) {
		c.Hooks = settings.Hooks{
			PromptChanged: func(user int64, agent string) {
				mu.Lock()
				defer mu.Unlock()
				prompts = append(prompts, strconv.FormatInt(user, 10)+":"+agent)
			},
			RescheduleTasks: func(user int64) error { rescheduled <- user; return nil },
			VoiceCapabilities: func(_ context.Context, user int64, agent string) (any, error) {
				return map[string]any{"user": user, "ready": true}, nil
			},
		}
	})
	if r := s.call(t, "PUT", "/api/settings", 1, `{"theme":"dark"}`, nil); r.status != 200 {
		t.Fatal(r.raw)
	}
	s.call(t, "PUT", "/api/settings/assistant_behavior_notes", 1, `{"value":"hi"}`, nil)
	s.call(t, "PUT", "/api/settings", 1, `{"timezone":"Europe/Berlin"}`, nil)
	s.call(t, "DELETE", "/api/settings/timezone", 1, "", nil)
	s.call(t, "DELETE", "/api/settings/theme", 1, "", nil)

	for i := 0; i < 2; i++ {
		select {
		case <-rescheduled:
		case <-time.After(2 * time.Second):
			t.Fatal("tasks were not rescheduled")
		}
	}
	mu.Lock()
	defer mu.Unlock()
	agent := s.mainAgent(t, 1)
	want := []string{"1:" + agent, "1:" + agent, "1:" + agent}
	if !reflect.DeepEqual(prompts, want) {
		t.Fatalf("prompt cache dropped %v, want %v", prompts, want)
	}
	voice := s.call(t, "GET", "/api/settings", 1, "", nil).body.(map[string]any)["voice_capabilities"]
	if !reflect.DeepEqual(voice, map[string]any{"user": 1.0, "ready": true}) {
		t.Fatalf("voice_capabilities = %v", voice)
	}
}

func TestVoiceCapabilitiesFailureIsAnError(t *testing.T) {
	s := newStack(t, func(c *settings.Config) {
		c.Hooks.VoiceCapabilities = func(context.Context, int64, string) (any, error) { return nil, io.ErrUnexpectedEOF }
	})
	if r := s.call(t, "GET", "/api/settings", 1, "", nil); r.status != 500 || strings.Contains(r.raw, "EOF") {
		t.Fatalf("%d %s", r.status, r.raw)
	}
}

func TestFirstRequestsRace(t *testing.T) {
	s := newStack(t, nil)
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if r := s.call(t, "GET", "/api/settings", 1, "", nil); r.status != 200 {
				t.Errorf("%d %s", r.status, r.raw)
			}
		}()
	}
	wg.Wait()
	var agents int
	if err := s.db.W.QueryRow(`SELECT COUNT(*) FROM agents WHERE user_id = 1`).Scan(&agents); err != nil || agents != 1 {
		t.Fatalf("agents = %d, %v", agents, err)
	}
}

func TestUpdateReportsRefusalsAsValidationErrors(t *testing.T) {
	s := newStack(t, nil)
	s.call(t, "GET", "/api/settings", 1, "", nil)
	err := s.api.Store.Update(context.Background(), 1, s.mainAgent(t, 1), settings.Patch{"ui_language": json.RawMessage(`"xx"`)}, "test")
	var invalid *settings.ValidationError
	if !errors.As(err, &invalid) || invalid.Message != "Unknown language." {
		t.Fatalf("%v", err)
	}
}
