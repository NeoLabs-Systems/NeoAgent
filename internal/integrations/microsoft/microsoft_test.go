package microsoft

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/integrationstest"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

type recorded struct {
	Method, URI, Auth, Prefer, Body string
}

type fake struct {
	srv      *httptest.Server
	mu       sync.Mutex
	requests []recorded
	answers  map[string]func(r *http.Request, body string) (int, string)
}

func newFake(t *testing.T) *fake {
	f := &fake{answers: map[string]func(*http.Request, string) (int, string){}}
	f.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		f.mu.Lock()
		f.requests = append(f.requests, recorded{r.Method, r.URL.RequestURI(), r.Header.Get("Authorization"), r.Header.Get("Prefer"), string(raw)})
		answer := f.answers[r.Method+" "+r.URL.Path]
		f.mu.Unlock()
		if answer == nil {
			w.WriteHeader(404)
			w.Write([]byte(`{"error":{"message":"no fake"}}`))
			return
		}
		status, body := answer(r, string(raw))
		w.WriteHeader(status)
		w.Write([]byte(body))
	}))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fake) on(route string, status int, body string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.answers[route] = func(*http.Request, string) (int, string) { return status, body }
}

func (f *fake) last() recorded {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.requests[len(f.requests)-1]
}

func setup(t *testing.T) (*integrationstest.Stack, *fake) {
	f := newFake(t)
	s := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		return []integrations.Provider{newProvider(svc, endpoints{login: f.srv.URL, graph: f.srv.URL})}
	}, integrations.Hooks{})
	sealed, _ := s.Box.Seal(`{"clientId":"cid","clientSecret":"csecret","tenantId":"contoso"}`)
	s.Exec(t, `INSERT INTO integration_oauth_apps (user_id, provider_key, config_json) VALUES (1, 'microsoft_365', ?)`, sealed)
	return s, f
}

func later() string { return oauthclient.ISO(time.Now().Add(time.Hour)) }

func run(t *testing.T, s *integrationstest.Stack, opts integrations.ExecOptions, name string, args map[string]any) string {
	t.Helper()
	out, err := s.Mgr.ExecuteTool(context.Background(), 1, name, args, "", opts)
	if err != nil {
		t.Fatal(err)
	}
	raw, err := oauthclient.MarshalJS(out)
	if err != nil {
		t.Fatal(err)
	}
	return string(raw)
}

func TestOAuthRoundTrip(t *testing.T) {
	s, f := setup(t)
	f.on("POST /contoso/oauth2/v2.0/token", 200, `{"access_token":"at","refresh_token":"rt","expires_in":3600,"scope":"Mail.ReadWrite","token_type":"Bearer"}`)
	f.on("GET /v1.0/me", 200, `{"id":"u1","displayName":"Zed","mail":null,"userPrincipalName":"zed@corp.example"}`)

	start, err := s.Mgr.BeginOAuth(context.Background(), 1, "microsoft_365", integrations.BeginOptions{AppKey: "teams"})
	if err != nil {
		t.Fatal(err)
	}
	u, _ := url.Parse(start.URL)
	q := u.Query()
	if u.Path != "/contoso/oauth2/v2.0/authorize" || q.Get("response_mode") != "query" || q.Get("prompt") != "select_account" ||
		q.Get("scope") != "openid profile email offline_access User.Read Chat.ReadWrite ChannelMessage.Read.All" {
		t.Fatalf("authorization url %s", start.URL)
	}
	res, err := s.Mgr.FinishOAuth(context.Background(), start.State, "code")
	if err != nil || res.AccountEmail != "zed@corp.example" || res.AppID != "teams" {
		t.Fatalf("%+v %v", res, err)
	}
	form, _ := url.ParseQuery(f.requests[0].Body)
	if form.Get("grant_type") != "authorization_code" || form.Get("scope") != q.Get("scope") || form.Get("client_secret") != "csecret" {
		t.Fatalf("token request %v", form)
	}
	if f.requests[1].Auth != "Bearer at" || !strings.Contains(f.requests[1].URI, "$select=id,displayName,mail,userPrincipalName") {
		t.Fatalf("profile request %+v", f.requests[1])
	}
	conn, _ := s.Svc.ConnectionByID(context.Background(), 1, *res.ConnectionID, s.MainAgent(t, 1))
	creds := s.Svc.Credentials(*conn)
	if creds.String("refresh_token") != "rt" || creds["expires_at"] == nil || creds.String("scope") != "Mail.ReadWrite" {
		t.Fatalf("credentials %v", creds)
	}
	var meta map[string]any
	_ = json.Unmarshal([]byte(conn.MetadataJSON), &meta)
	if meta["mail"] != nil || meta["userPrincipalName"] != "zed@corp.example" {
		t.Fatalf("metadata %v", meta)
	}
}

func TestExpiredTokenIsRefreshedWithTheStoredScope(t *testing.T) {
	s, f := setup(t)
	id := s.Connect(t, 1, "microsoft_365", "teams", "zed@corp.example",
		`{"access_token":"old","refresh_token":"rt","expires_at":"2020-01-01T00:00:00.000Z","scope":"Chat.ReadWrite"}`)
	f.on("POST /contoso/oauth2/v2.0/token", 200, `{"access_token":"new","expires_in":3600}`)
	f.on("GET /v1.0/me/chats", 200, `{"value":[]}`)
	if got := run(t, s, integrations.ExecOptions{}, "microsoft_365_teams_list_chats", map[string]any{"top": float64(500)}); got != `{"value":[]}` {
		t.Fatalf("got %s", got)
	}
	form, _ := url.ParseQuery(f.requests[0].Body)
	if form.Get("refresh_token") != "rt" || form.Get("scope") != "Chat.ReadWrite" || form.Get("grant_type") != "refresh_token" {
		t.Fatalf("refresh request %v", form)
	}
	if last := f.last(); last.Auth != "Bearer new" || (last.URI != "/v1.0/me/chats?%24top=50" && last.URI != "/v1.0/me/chats?$top=50") {
		t.Fatalf("call %+v", last)
	}
	conn, _ := s.Svc.ConnectionByID(context.Background(), 1, id, s.MainAgent(t, 1))
	creds := s.Svc.Credentials(*conn)
	if creds.String("access_token") != "new" || creds.String("refresh_token") != "rt" || creds.String("scope") != "Chat.ReadWrite" {
		t.Fatalf("stored %v", creds)
	}
}

func TestOutlook(t *testing.T) {
	s, f := setup(t)
	s.Connect(t, 1, "microsoft_365", "outlook", "zed@corp.example", `{"access_token":"at","refresh_token":"rt","expires_at":"`+later()+`"}`)
	f.on("GET /v1.0/me/mailFolders/inbox/messages", 200, `{"value":[{"id":"m"}]}`)
	run(t, s, integrations.ExecOptions{}, "microsoft_365_outlook_list_messages", nil)
	if f.last().URI != "/v1.0/me/mailFolders/inbox/messages?%24top=10&%24orderby=receivedDateTime%20desc" &&
		f.last().URI != "/v1.0/me/mailFolders/inbox/messages?%24top=10&%24orderby=receivedDateTime+desc" &&
		f.last().URI != "/v1.0/me/mailFolders/inbox/messages?$top=10&$orderby=receivedDateTime%20desc" &&
		f.last().URI != "/v1.0/me/mailFolders/inbox/messages?$top=10&$orderby=receivedDateTime+desc" {
		t.Fatalf("plain listing %s", f.last().URI)
	}
	run(t, s, integrations.ExecOptions{}, "microsoft_365_outlook_list_messages", map[string]any{"query": `say "hi"`})
	if uri := f.last().URI; strings.Contains(uri, "orderby") || !strings.Contains(uri, "%24search") && !strings.Contains(uri, "$search") {
		t.Fatalf("search listing %s", uri)
	}
	u, _ := url.Parse("http://x" + f.last().URI)
	if u.Query().Get("$search") != `"say \"hi\""` {
		t.Fatalf("search term %q", u.Query().Get("$search"))
	}
	f.on("GET /v1.0/me/mailFolders/Archive%2FOld/messages", 200, `{}`)
	f.on("GET /v1.0/me/mailFolders/Archive/Old/messages", 200, `{}`)
	run(t, s, integrations.ExecOptions{}, "microsoft_365_outlook_list_messages", map[string]any{"folder_id": "Archive/Old"})
	if !strings.HasPrefix(f.last().URI, "/v1.0/me/mailFolders/Archive%2FOld/messages") {
		t.Fatalf("folder escaping %s", f.last().URI)
	}

	f.on("POST /v1.0/me/sendMail", 202, ``)
	got := run(t, s, integrations.ExecOptions{}, "microsoft_365_outlook_send_mail", map[string]any{"to": "a@x, b@x,", "cc": []any{"c@x", " "}, "subject": "Hi", "body_text": "Text", "save_to_sent_items": false})
	if got != `{"sent":true}` {
		t.Fatalf("got %s", got)
	}
	var body struct {
		Message struct {
			Subject      string
			ToRecipients []struct{ EmailAddress struct{ Address string } }
			CcRecipients []any
		}
		SaveToSentItems bool
	}
	if err := json.Unmarshal([]byte(f.last().Body), &body); err != nil || body.Message.Subject != "Hi" || len(body.Message.ToRecipients) != 2 || len(body.Message.CcRecipients) != 1 || body.SaveToSentItems {
		t.Fatalf("send body %s", f.last().Body)
	}
	if got := run(t, s, integrations.ExecOptions{}, "microsoft_365_outlook_send_mail", map[string]any{"to": "a@x"}); got != `{"error":"subject is required."}` {
		t.Fatalf("got %s", got)
	}
}

func TestCalendarWindowsAndReminders(t *testing.T) {
	s, f := setup(t)
	s.Connect(t, 1, "microsoft_365", "calendar", "zed@corp.example", `{"access_token":"at","refresh_token":"rt","expires_at":"`+later()+`"}`)
	f.on("GET /v1.0/me/calendarView", 200, `{"value":[
		{"id":"a","subject":"Soon","start":{"dateTime":"2026-11-24T10:30:00.0000000","timeZone":"UTC"},"end":{"dateTime":"2026-11-24T11:00:00.0000000","timeZone":"UTC"},"attendees":[{"emailAddress":{"address":"x@y"}}],"isCancelled":true,"location":{"displayName":"Room"}},
		{"id":"b","subject":"Day","isAllDay":true,"start":{"dateTime":"2026-11-24T00:00:00","timeZone":"UTC"},"end":{"dateTime":"2026-11-25T00:00:00","timeZone":"UTC"}}]}`)
	got := run(t, s, integrations.ExecOptions{}, "microsoft_365_calendar_list_events", map[string]any{"start": "2026-11-24T10:00:00Z", "end": "2026-11-24T12:00:00Z"})
	var listed struct {
		Count  int
		Events []struct {
			ID, Summary string
			Status      string
			Start       string
			Location    string
			Attendees   []string
		}
	}
	if err := json.Unmarshal([]byte(got), &listed); err != nil || listed.Count != 1 || listed.Events[0].ID != "a" || listed.Events[0].Status != "cancelled" ||
		listed.Events[0].Start != "2026-11-24T10:30:00.0000000Z" || listed.Events[0].Location != "Room" || len(listed.Events[0].Attendees) != 1 {
		t.Fatalf("listed %s", got)
	}
	last := f.last()
	if last.Prefer != `outlook.timezone="UTC"` || !strings.Contains(last.URI, "startDateTime=2026-11-24T10%3A00%3A00Z") {
		t.Fatalf("calendar view request %+v", last)
	}

	f.on("GET /v1.0/me/events", 200, `{"value":[]}`)
	run(t, s, integrations.ExecOptions{}, "microsoft_365_calendar_list_events", nil)
	if !strings.Contains(f.last().URI, "/v1.0/me/events?%24top=10&%24orderby=start%2FdateTime") && !strings.Contains(f.last().URI, "/v1.0/me/events?$top=10&$orderby=start%2FdateTime") {
		t.Fatalf("unbounded request %s", f.last().URI)
	}
	task := integrations.ExecOptions{Run: integrations.Run{TriggerSource: "tasks", TaskID: "3", ScheduledAt: "2026-11-24T10:00:00Z"}}
	if got := run(t, s, task, "microsoft_365_calendar_list_events", map[string]any{"start": "x"}); !strings.HasPrefix(got, `{"error":"Automatic calendar checks require both start and end.`) {
		t.Fatalf("got %s", got)
	}

	f.on("POST /v1.0/me/events", 201, `{"id":"new"}`)
	got = run(t, s, integrations.ExecOptions{}, "microsoft_365_calendar_create_event", map[string]any{
		"subject": "Lunch", "start": "2026-11-25T12:00:00", "end": "2026-11-25T13:00:00", "attendees": "a@x", "timezone": "Europe/Berlin",
	})
	if got != `{"id":"new"}` || !strings.Contains(f.last().Body, `"type":"required"`) || !strings.Contains(f.last().Body, `"timeZone":"Europe/Berlin"`) {
		t.Fatalf("create %s %s", got, f.last().Body)
	}
}

func TestGraphRequestIsGatedAndPinned(t *testing.T) {
	s, f := setup(t)
	s.Connect(t, 1, "microsoft_365", "outlook", "zed@corp.example", `{"access_token":"at","refresh_token":"rt","expires_at":"`+later()+`"}`)
	args := map[string]any{"method": "get", "path": "/v1.0/me/messages", "query": map[string]any{"$top": float64(1), "blank": " "}}
	if got := run(t, s, integrations.ExecOptions{}, "microsoft_365_outlook_graph_request", args); !strings.Contains(got, "disabled by default") {
		t.Fatalf("got %s", got)
	}
	yes := "true"
	s.SetEnv("NEOAGENT_ENABLE_MICROSOFT_DYNAMIC_GRAPH_REQUEST", &yes)
	f.on("GET /v1.0/me/messages", 200, `{"value":[]}`)
	if got := run(t, s, integrations.ExecOptions{}, "microsoft_365_outlook_graph_request", args); got != `{"value":[]}` {
		t.Fatalf("got %s", got)
	}
	if f.last().URI != "/v1.0/me/messages?%24top=1" && f.last().URI != "/v1.0/me/messages?$top=1" {
		t.Fatalf("blank query values are dropped: %s", f.last().URI)
	}
	args["path"] = "https://evil.example/v1.0/me"
	if got := run(t, s, integrations.ExecOptions{}, "microsoft_365_outlook_graph_request", args); got != `{"error":"Microsoft Graph request URL must target graph.microsoft.com."}` {
		t.Fatalf("got %s", got)
	}
	s.Connect(t, 1, "microsoft_365", "calendar", "zed@corp.example", `{"access_token":"at","refresh_token":"rt","expires_at":"`+later()+`"}`)
	task := integrations.ExecOptions{Run: integrations.Run{TriggerSource: "schedule", TaskID: "3"}}
	args["path"] = "/v1.0/me/calendarView?x=1"
	if got := run(t, s, task, "microsoft_365_calendar_graph_request", args); got != `{"error":"Microsoft Graph request URL must target graph.microsoft.com."}` && !strings.Contains(got, "Automatic calendar checks") {
		t.Fatalf("got %s", got)
	}
	prod := &provider{ep: endpoints{login: "https://login.microsoftonline.com", graph: "https://graph.microsoft.com"}}
	for _, bad := range []string{"http://graph.microsoft.com/v1.0/me", "https://graph.microsoft.com.evil.io/x", "https://evil.io/graph.microsoft.com"} {
		if _, err := prod.graphURL(bad, nil); err == nil {
			t.Errorf("%s accepted", bad)
		}
	}
	for _, good := range []string{"/v1.0/me", "v1.0/me", "https://graph.microsoft.com/v1.0/me"} {
		if _, err := prod.graphURL(good, nil); err != nil {
			t.Errorf("%s: %v", good, err)
		}
	}
}

func TestGraphErrorsCarryTheirMessage(t *testing.T) {
	s, f := setup(t)
	s.Connect(t, 1, "microsoft_365", "teams", "zed@corp.example", `{"access_token":"at","refresh_token":"rt","expires_at":"`+later()+`"}`)
	f.on("GET /v1.0/me/chats", 403, `{"error":{"code":"Forbidden","message":"Insufficient privileges"}}`)
	got := run(t, s, integrations.ExecOptions{}, "microsoft_365_teams_list_chats", nil)
	// An error object has no readable text, exactly as in the Node server.
	if !strings.HasPrefix(got, `{"error":"Microsoft Graph request failed: [object Object]","status":403`) {
		t.Fatalf("got %s", got)
	}
}

func TestConnectionTestAndSummary(t *testing.T) {
	s, f := setup(t)
	id := s.Connect(t, 1, "microsoft_365", "outlook", "zed@corp.example", `{"access_token":"at","refresh_token":"rt","expires_at":"`+later()+`"}`)
	f.on("GET /v1.0/me", 200, `{"id":"u"}`)
	r := s.Call(t, "POST", "/api/integrations/microsoft_365/test", 1, `{"connectionId":`+string(rune('0'+id))+`}`, nil)
	if r.Status != 200 || !strings.Contains(r.Raw, "Microsoft 365 is connected and responding.") {
		t.Fatalf("%d %s", r.Status, r.Raw)
	}
	if !strings.Contains(f.last().URI, "select=id,displayName,userPrincipalName") && !strings.Contains(f.last().URI, "%24select=id%2CdisplayName%2CuserPrincipalName") {
		t.Fatalf("test request %s", f.last().URI)
	}
	p := s.Mgr.Provider("microsoft_365")
	scope := integrations.Scope{UserID: 1, AgentID: s.MainAgent(t, 1)}
	rows, _ := s.Svc.ListConnections(context.Background(), 1, "microsoft_365", scope.AgentID)
	got := p.SummarizeForModel(p.Snapshot(rows, scope))
	if !strings.HasPrefix(got, "Microsoft 365: native account access is connected in this run.\nConnected apps: Outlook: zed@corp.example\n- Outlook: microsoft_365_outlook_list_messages, microsoft_365_outlook_send_mail") {
		t.Fatalf("summary\n%s", got)
	}
}
