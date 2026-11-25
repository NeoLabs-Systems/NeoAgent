package slack

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/integrationstest"
)

// fakeSlack answers the few Web API methods the provider uses and records the
// requests.
type fakeSlack struct {
	srv      *httptest.Server
	mu       sync.Mutex
	requests []string
	auth     []string
	forms    []url.Values
	// failToken makes the next call with this access token answer an auth error.
	failToken string
}

func newFakeSlack(t *testing.T) *fakeSlack {
	f := &fakeSlack{}
	f.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		f.mu.Lock()
		f.requests = append(f.requests, r.Method+" "+r.URL.RequestURI())
		f.auth = append(f.auth, r.Header.Get("Authorization"))
		bodyBytes := make([]byte, 4096)
		n, _ := r.Body.Read(bodyBytes)
		body := string(bodyBytes[:n])
		if strings.Contains(r.Header.Get("Content-Type"), "form") {
			form, _ := url.ParseQuery(body)
			f.forms = append(f.forms, form)
		} else if body != "" {
			f.forms = append(f.forms, url.Values{"json": {body}})
		}
		failToken := f.failToken
		f.mu.Unlock()
		if failToken != "" && r.Header.Get("Authorization") == "Bearer "+failToken {
			w.Write([]byte(`{"ok":false,"error":"token_expired"}`))
			return
		}
		switch r.URL.Path {
		case "/api/oauth.v2.access":
			if r.Form == nil {
				r.ParseForm()
			}
			if strings.Contains(body, "grant_type=refresh_token") {
				w.Write([]byte(`{"ok":true,"access_token":"xoxb-bot","authed_user":{"id":"U1","access_token":"xoxp-new","refresh_token":"xoxe-new","expires_in":3600,"token_type":"user"},"team":{"id":"T1","name":"Acme"}}`))
				return
			}
			w.Write([]byte(`{"ok":true,"access_token":"xoxb-bot","token_type":"bot","team":{"id":"T1","name":"Acme"},"authed_user":{"id":"U1","access_token":"xoxp-1","refresh_token":"xoxe-1","expires_in":43200,"token_type":"user"}}`))
		case "/api/auth.test":
			w.Write([]byte(`{"ok":true,"user":"zed","user_id":"U1","team":"Acme","team_id":"T1"}`))
		case "/api/users.info":
			w.Write([]byte(`{"ok":true,"user":{"name":"zed","real_name":"Zed Z","profile":{"email":"zed@example.com","image_192":"https://img/z.png"}}}`))
		case "/api/conversations.list":
			w.Write([]byte(`{"ok":true,"channels":[{"id":"C1","name":"general"}]}`))
		case "/api/chat.postMessage":
			w.Write([]byte(`{"ok":true,"ts":"1.2"}`))
		default:
			w.Write([]byte(`{"ok":false,"error":"unknown_method"}`))
		}
	}))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fakeSlack) seen() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]string(nil), f.requests...)
}

func setup(t *testing.T, hooks integrations.Hooks) (*integrationstest.Stack, *fakeSlack) {
	fake := newFakeSlack(t)
	s := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		return []integrations.Provider{newProvider(svc, fake.srv.URL)}
	}, hooks)
	s.Exec(t, `INSERT INTO integration_oauth_apps (user_id, provider_key, config_json) VALUES (1, 'slack', ?)`, mustSeal(t, s, `{"clientId":"cid","clientSecret":"csecret"}`))
	return s, fake
}

func mustSeal(t *testing.T, s *integrationstest.Stack, plain string) string {
	sealed, err := s.Box.Seal(plain)
	if err != nil {
		t.Fatal(err)
	}
	return sealed
}

func TestConnectAndFinishOAuth(t *testing.T) {
	var connected []integrations.Connection
	var sweep []bool
	s, fake := setup(t, integrations.Hooks{OnConnected: func(c integrations.Connection, memorySweep bool) {
		connected = append(connected, c)
		sweep = append(sweep, memorySweep)
	}})
	ctx := context.Background()

	reply := s.Call(t, "POST", "/api/integrations/slack/connect", 1, `{"appId":"slack","memorySweep":true}`, nil)
	var start struct{ State, URL string }
	if err := json.Unmarshal([]byte(reply.Raw), &start); err != nil || reply.Status != 200 {
		t.Fatalf("connect: %d %s", reply.Status, reply.Raw)
	}
	u, _ := url.Parse(start.URL)
	if q := u.Query(); u.Host != strings.TrimPrefix(fake.srv.URL, "http://") || u.Path != "/oauth/v2/authorize" ||
		q.Get("client_id") != "cid" || q.Get("state") != start.State || q.Get("redirect_uri") != "https://neo.example/api/integrations/oauth/callback" ||
		!strings.Contains(q.Get("user_scope"), "chat:write") || q.Get("user_scope") != strings.Join(userScopes, " ") {
		t.Fatalf("authorize url: %s", start.URL)
	}
	if bound := s.Bound(); len(bound) != 1 || bound[0] != start.State {
		t.Fatalf("state not bound to the session: %v", bound)
	}

	pending, err := s.Mgr.DescribePendingOAuth(ctx, start.State)
	if err != nil || pending == nil || pending.ProviderLabel != "Slack" || pending.AppLabel != "Slack" || pending.Username != "alice" {
		t.Fatalf("pending: %+v %v", pending, err)
	}

	res, err := s.Mgr.FinishOAuth(ctx, start.State, "the-code")
	if err != nil {
		t.Fatal(err)
	}
	if res.Provider != "slack" || res.AppID != "slack" || res.AccountEmail != "zed@example.com" || res.ConnectionID == nil {
		t.Fatalf("result: %+v", res)
	}
	if len(connected) != 1 || !sweep[0] || connected[0].ID != *res.ConnectionID {
		t.Fatalf("hook: %+v %v", connected, sweep)
	}
	// The code exchange sent the app's client and the redirect.
	exchange := fake.forms[0]
	if exchange.Get("client_secret") != "csecret" || exchange.Get("code") != "the-code" || exchange.Get("grant_type") != "authorization_code" {
		t.Fatalf("exchange form: %v", exchange)
	}

	conn, _ := s.Svc.ConnectionByID(ctx, 1, *res.ConnectionID, s.MainAgent(t, 1))
	creds := s.Svc.Credentials(*conn)
	if creds.String("access_token") != "xoxp-1" || creds.String("refresh_token") != "xoxe-1" || creds.String("bot_access_token") != "xoxb-bot" || creds["expires_at"] == nil {
		t.Fatalf("credentials: %v", creds)
	}
	if !strings.HasPrefix(conn.CredentialsJSON, "enc:v1:") {
		t.Fatal("credentials are not sealed")
	}
	var meta map[string]any
	_ = json.Unmarshal([]byte(conn.MetadataJSON), &meta)
	if meta["name"] != "Zed Z" || meta["teamId"] != "T1" || meta["userId"] != "U1" || meta["image"] != "https://img/z.png" {
		t.Fatalf("metadata: %v", meta)
	}

	// A state works once.
	if _, err := s.Mgr.FinishOAuth(ctx, start.State, "again"); err == nil || err.Error() != "OAuth state is missing or expired." {
		t.Fatalf("reuse: %v", err)
	}
	if _, err := s.Mgr.FinishOAuth(ctx, "nothex", "c"); err == nil || err.Error() != "OAuth state is invalid or malformed." {
		t.Fatalf("malformed: %v", err)
	}
	if _, err := s.Mgr.FinishOAuth(ctx, strings.Repeat("a", 48), " "); err == nil || err.Error() != "OAuth authorization code is required." {
		t.Fatalf("no code: %v", err)
	}
}

func TestExpiredStateIsRefused(t *testing.T) {
	s, _ := setup(t, integrations.Hooks{})
	state := strings.Repeat("ab", 24)
	s.Exec(t, `INSERT INTO integration_oauth_states (user_id, agent_id, provider_key, app_key, state, code_verifier, expires_at)
		VALUES (1, ?, 'slack', 'slack', ?, ?, '2020-01-01T00:00:00.000Z')`, s.MainAgent(t, 1), state, mustSeal(t, s, "v"))
	if p, _ := s.Mgr.DescribePendingOAuth(context.Background(), state); p != nil {
		t.Fatal("expired state described")
	}
	if _, err := s.Mgr.FinishOAuth(context.Background(), state, "c"); err == nil || err.Error() != "OAuth state is missing or expired." {
		t.Fatalf("got %v", err)
	}
}

func runTool(t *testing.T, s *integrationstest.Stack, name string, args map[string]any) any {
	t.Helper()
	out, err := s.Mgr.ExecuteTool(context.Background(), 1, name, args, "", integrations.ExecOptions{})
	if err != nil {
		t.Fatal(err)
	}
	return out
}

func asJSON(t *testing.T, v any) string {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return string(raw)
}

func TestToolsPassTheAnswerThrough(t *testing.T) {
	s, fake := setup(t, integrations.Hooks{})
	s.Connect(t, 1, "slack", "slack", "zed@example.com", `{"access_token":"xoxp-1"}`)

	got := asJSON(t, runTool(t, s, "slack_list_conversations", map[string]any{"limit": float64(999)}))
	if got != `{"ok":true,"channels":[{"id":"C1","name":"general"}]}` {
		t.Fatalf("result: %s", got)
	}
	if seen := fake.seen(); len(seen) != 1 || seen[0] != "GET /api/conversations.list?types=public_channel%2Cprivate_channel%2Cim%2Cmpim&limit=200" {
		t.Fatalf("request: %v", seen)
	}
	if fake.auth[0] != "Bearer xoxp-1" {
		t.Fatalf("auth header %q", fake.auth[0])
	}

	runTool(t, s, "slack_post_message", map[string]any{"channel": "C1", "text": "hi <b>", "thread_ts": "1.1"})
	last := fake.forms[len(fake.forms)-1].Get("json")
	if last != `{"channel":"C1","text":"hi <b>","thread_ts":"1.1"}` {
		t.Fatalf("post body: %s", last)
	}
	runTool(t, s, "slack_post_message", map[string]any{"channel": "C1", "text": "x"})
	if got := fake.forms[len(fake.forms)-1].Get("json"); got != `{"channel":"C1","text":"x"}` {
		t.Fatalf("post body without thread: %s", got)
	}

	if got := asJSON(t, runTool(t, s, "slack_get_conversation_history", map[string]any{})); got != `{"error":"channel is required."}` {
		t.Fatalf("missing arg: %s", got)
	}
	if got := asJSON(t, runTool(t, s, "slack_api_request", map[string]any{"method_name": "x"})); !strings.Contains(got, "disabled by default") {
		t.Fatalf("dynamic request: %s", got)
	}
	enabled := "true"
	s.SetEnv("NEOAGENT_ENABLE_SLACK_DYNAMIC_API_REQUEST", &enabled)
	if got := asJSON(t, runTool(t, s, "slack_api_request", map[string]any{"method_name": "bad name"})); got != `{"error":"method_name must be a Slack Web API method name."}` {
		t.Fatalf("method name: %s", got)
	}
	if got := asJSON(t, runTool(t, s, "slack_api_request", map[string]any{"method_name": "unknown.thing", "http_method": "GET"})); !strings.Contains(got, "unknown_method") || !strings.Contains(got, `"error"`) {
		t.Fatalf("slack error: %s", got)
	}
	if got := asJSON(t, runTool(t, s, "no_such_tool", nil)); got != `{"error":"no_provider_support"}` {
		t.Fatalf("unknown tool: %s", got)
	}
}

func TestReadOnlyAccountsCannotWrite(t *testing.T) {
	s, fake := setup(t, integrations.Hooks{})
	id := s.Connect(t, 1, "slack", "slack", "zed@example.com", `{"access_token":"xoxp-1"}`)
	if r := s.Call(t, "POST", "/api/integrations/slack/access-mode", 1, `{"connectionId":`+itoa(id)+`,"accessMode":"read_only"}`, nil); r.Status != 200 {
		t.Fatal(r.Raw)
	}
	got := asJSON(t, runTool(t, s, "slack_post_message", map[string]any{"channel": "C1", "text": "x"}))
	if got != `{"error":"This Slack account is set to read-only access. Change the connection access mode to read/write to allow this action."}` {
		t.Fatalf("write on read-only: %s", got)
	}
	runTool(t, s, "slack_list_conversations", nil)
	if len(fake.seen()) != 1 {
		t.Fatalf("only the read may reach Slack: %v", fake.seen())
	}
	// The dynamic request is a write unless it names a GET. Like Node, a call
	// that names no HTTP method counts as a GET although Slack gets a POST.
	enabled := "true"
	s.SetEnv("NEOAGENT_ENABLE_SLACK_DYNAMIC_API_REQUEST", &enabled)
	if got := asJSON(t, runTool(t, s, "slack_api_request", map[string]any{"method_name": "chat.delete", "http_method": "POST"})); !strings.Contains(got, "read-only") {
		t.Fatalf("dynamic POST: %s", got)
	}
	if got := asJSON(t, runTool(t, s, "slack_api_request", map[string]any{"method_name": "conversations.list", "http_method": "GET"})); strings.Contains(got, "read-only") {
		t.Fatalf("dynamic GET: %s", got)
	}
}

func itoa(n int64) string { return strconv.FormatInt(n, 10) }

func TestAccountSelection(t *testing.T) {
	s, _ := setup(t, integrations.Hooks{})
	a := s.Connect(t, 1, "slack", "slack", "a@example.com", `{"access_token":"ta"}`)
	s.Connect(t, 1, "slack", "slack", "b@example.com", `{"access_token":"tb"}`)
	got := asJSON(t, runTool(t, s, "slack_list_conversations", nil))
	want := `{"error":"Multiple Slack Slack accounts are connected: b@example.com (connection_id 2), a@example.com (connection_id 1). Re-run the tool with connection_id or account_email."}`
	if got != want {
		t.Fatalf("got  %s\nwant %s", got, want)
	}
	if got := asJSON(t, runTool(t, s, "slack_list_conversations", map[string]any{"connection_id": float64(a)})); strings.Contains(got, "error") {
		t.Fatalf("by id: %s", got)
	}
	if got := asJSON(t, runTool(t, s, "slack_list_conversations", map[string]any{"account_email": " B@Example.com "})); strings.Contains(got, "error") {
		t.Fatalf("by email: %s", got)
	}
	if got := asJSON(t, runTool(t, s, "slack_list_conversations", map[string]any{"connection_id": float64(77)})); got != `{"error":"No connected Slack Slack account matches connection_id 77. Connected: b@example.com (connection_id 2), a@example.com (connection_id 1)."}` {
		t.Fatalf("unknown id: %s", got)
	}
}

func TestExpiredAccessTokenIsRefreshedAndStored(t *testing.T) {
	s, fake := setup(t, integrations.Hooks{})
	id := s.Connect(t, 1, "slack", "slack", "zed@example.com",
		`{"access_token":"stale","refresh_token":"xoxe-old","expires_at":"2020-01-01T00:00:00.000Z","team":{"id":"T0"}}`)
	got := asJSON(t, runTool(t, s, "slack_list_conversations", nil))
	if strings.Contains(got, "error") {
		t.Fatalf("result: %s", got)
	}
	seen := fake.seen()
	if len(seen) != 2 || seen[0] != "POST /api/oauth.v2.access" || fake.auth[1] != "Bearer xoxp-new" {
		t.Fatalf("expected a refresh then the call with the new token: %v %v", seen, fake.auth)
	}
	wantBasic := "Basic " + base64.StdEncoding.EncodeToString([]byte("cid:csecret"))
	if fake.auth[0] != wantBasic || fake.forms[0].Get("grant_type") != "refresh_token" || fake.forms[0].Get("refresh_token") != "xoxe-old" {
		t.Fatalf("refresh request: %q %v", fake.auth[0], fake.forms[0])
	}
	conn, _ := s.Svc.ConnectionByID(context.Background(), 1, id, s.MainAgent(t, 1))
	creds := s.Svc.Credentials(*conn)
	if creds.String("access_token") != "xoxp-new" || creds.String("refresh_token") != "xoxe-new" || creds["expires_at"] == "2020-01-01T00:00:00.000Z" {
		t.Fatalf("stored credentials: %v", creds)
	}
}

func TestRejectedTokenRefreshesOnceAndRetries(t *testing.T) {
	s, fake := setup(t, integrations.Hooks{})
	s.Connect(t, 1, "slack", "slack", "zed@example.com", `{"access_token":"revoked","refresh_token":"xoxe-old"}`)
	fake.failToken = "revoked"
	got := asJSON(t, runTool(t, s, "slack_list_conversations", nil))
	if strings.Contains(got, "error") || len(fake.seen()) != 3 {
		t.Fatalf("got %s after %v", got, fake.seen())
	}
}

func TestMissingRefreshTokenMarksTheConnectionExpired(t *testing.T) {
	s, _ := setup(t, integrations.Hooks{})
	id := s.Connect(t, 1, "slack", "slack", "zed@example.com", `{"access_token":"stale","expires_at":"2020-01-01T00:00:00.000Z"}`)
	got := asJSON(t, runTool(t, s, "slack_list_conversations", nil))
	want := `{"error":"Your Slack account connection has expired and needs to be reconnected. Open Official Integrations to reconnect your account.","expired":true,"connectionId":` + itoa(id) + `}`
	if got != want {
		t.Fatalf("got  %s\nwant %s", got, want)
	}
	conn, _ := s.Svc.ConnectionByID(context.Background(), 1, id, s.MainAgent(t, 1))
	if conn.Status != "expired" {
		t.Fatalf("status %s", conn.Status)
	}
	// An expired connection is no longer offered.
	if got := asJSON(t, runTool(t, s, "slack_list_conversations", nil)); got != `{"error":"Slack Slack is not connected for this user."}` {
		t.Fatalf("after expiry: %s", got)
	}
}

func TestProviderErrorsCarryStatusAndGuidance(t *testing.T) {
	var calls int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		w.Header().Set("Retry-After", "3")
		w.Header().Set("Retry-After-Ms", "1")
		w.WriteHeader(429)
		w.Write([]byte(`{"ok":false,"error":"ratelimited"}`))
	}))
	defer srv.Close()
	s := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		return []integrations.Provider{newProvider(svc, srv.URL)}
	}, integrations.Hooks{})
	s.Exec(t, `INSERT INTO integration_oauth_apps (user_id, provider_key, config_json) VALUES (1, 'slack', ?)`, mustSeal(t, s, `{"clientId":"c","clientSecret":"s"}`))
	s.Connect(t, 1, "slack", "slack", "zed@example.com", `{"access_token":"t"}`)
	got := asJSON(t, runTool(t, s, "slack_list_conversations", nil))
	want := `{"error":"Slack request failed: ratelimited","status":429,"retryAfterSeconds":3,"next":"The service is busy or failing; it may work later."}`
	if got != want {
		t.Fatalf("got  %s\nwant %s", got, want)
	}
	if calls != 2 {
		t.Fatalf("a GET retries once: %d", calls)
	}
}

func TestConnectionTestAndDisconnect(t *testing.T) {
	s, fake := setup(t, integrations.Hooks{})
	id := s.Connect(t, 1, "slack", "slack", "zed@example.com", `{"access_token":"t"}`)
	r := s.Call(t, "POST", "/api/integrations/slack/test", 1, `{"connectionId":`+itoa(id)+`}`, nil)
	var res map[string]any
	_ = json.Unmarshal([]byte(r.Raw), &res)
	if r.Status != 200 || res["ok"] != true || res["message"] != "Slack is connected and responding." || res["accountEmail"] != "zed@example.com" {
		t.Fatalf("test: %d %s", r.Status, r.Raw)
	}
	if seen := fake.seen(); len(seen) != 1 || seen[0] != "GET /api/auth.test" {
		t.Fatalf("seen %v", seen)
	}
	conn, _ := s.Svc.ConnectionByID(context.Background(), 1, id, s.MainAgent(t, 1))
	var meta map[string]any
	_ = json.Unmarshal([]byte(conn.MetadataJSON), &meta)
	if meta["last_connection_test_status"] != "passed" || meta["last_connection_test_at"] == nil {
		t.Fatalf("metadata %v", meta)
	}
	if r := s.Call(t, "POST", "/api/integrations/slack/disconnect", 1, `{"connectionId":`+itoa(id)+`}`, nil); r.Status != 200 {
		t.Fatal(r.Raw)
	}
	if c, _ := s.Svc.ConnectionByID(context.Background(), 1, id, s.MainAgent(t, 1)); c != nil {
		t.Fatal("connection still stored")
	}
}

func TestToolDefinitionsAreTheNodeOnes(t *testing.T) {
	s, _ := setup(t, integrations.Hooks{})
	if defs, _ := s.Mgr.ToolDefinitions(context.Background(), 1, ""); len(defs) != 0 {
		t.Fatalf("nothing connected, yet %d tools", len(defs))
	}
	s.Connect(t, 1, "slack", "slack", "zed@example.com", `{"access_token":"t"}`)
	defs, err := s.Mgr.ToolDefinitions(context.Background(), 1, "")
	if err != nil || len(defs) != 6 {
		t.Fatalf("%d tools, %v", len(defs), err)
	}
	var first map[string]any
	if err := json.Unmarshal(defs[0], &first); err != nil {
		t.Fatal(err)
	}
	if first["name"] != "slack_list_conversations" || first["integration"] != "slack" || first["appId"] != "slack" ||
		!strings.HasSuffix(first["description"].(string), "When multiple Slack accounts are connected, set connection_id or account_email to choose which account to use.") {
		t.Fatalf("first tool: %s", defs[0])
	}
	props := first["parameters"].(map[string]any)["properties"].(map[string]any)
	if _, ok := props["connection_id"]; !ok {
		t.Fatalf("account selectors missing: %v", props)
	}
	if !strings.HasSuffix(string(defs[0]), `,"integration":"slack"}`) {
		t.Fatalf("integration is appended last: %s", defs[0])
	}
}
