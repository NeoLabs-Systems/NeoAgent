package google

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"mime"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/integrationstest"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

type recorded struct {
	Method, URI, Auth, Type, Body string
}

// fakeGoogle serves canned answers by "METHOD path" and records every request.
type fakeGoogle struct {
	srv      *httptest.Server
	mu       sync.Mutex
	requests []recorded
	answers  map[string]func(r *http.Request, body string) (int, string)
}

func newFakeGoogle(t *testing.T) *fakeGoogle {
	f := &fakeGoogle{answers: map[string]func(*http.Request, string) (int, string){}}
	f.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		f.mu.Lock()
		f.requests = append(f.requests, recorded{r.Method, r.URL.RequestURI(), r.Header.Get("Authorization"), r.Header.Get("Content-Type"), string(raw)})
		answer := f.answers[r.Method+" "+r.URL.Path]
		f.mu.Unlock()
		if answer == nil {
			w.WriteHeader(404)
			w.Write([]byte(`{"error":{"code":404,"message":"no fake for ` + r.Method + " " + r.URL.Path + `"}}`))
			return
		}
		status, body := answer(r, string(raw))
		w.WriteHeader(status)
		w.Write([]byte(body))
	}))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fakeGoogle) on(route string, status int, body string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.answers[route] = func(*http.Request, string) (int, string) { return status, body }
}

func (f *fakeGoogle) onFunc(route string, fn func(r *http.Request, body string) (int, string)) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.answers[route] = fn
}

func (f *fakeGoogle) seen() []recorded {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]recorded(nil), f.requests...)
}

func (f *fakeGoogle) last() recorded {
	s := f.seen()
	return s[len(s)-1]
}

func (f *fakeGoogle) endpoints() endpoints {
	base := f.srv.URL
	return endpoints{
		auth: base + "/auth", token: base + "/token", revoke: base + "/revoke", userinfo: base + "/userinfo",
		api: base, gmail: base, docs: base, sheets: base, upload: base + "/upload",
		isAPIHost: func(host string) bool { return host == "127.0.0.1" },
	}
}

func setup(t *testing.T) (*integrationstest.Stack, *fakeGoogle) {
	fake := newFakeGoogle(t)
	s := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		return []integrations.Provider{newProvider(svc, fake.endpoints())}
	}, integrations.Hooks{})
	sealed, err := s.Box.Seal(`{"clientId":"cid","clientSecret":"csecret"}`)
	if err != nil {
		t.Fatal(err)
	}
	s.Exec(t, `INSERT INTO integration_oauth_apps (user_id, provider_key, config_json) VALUES (1, 'google_workspace', ?)`, sealed)
	return s, fake
}

func farFuture() string { return strconv.FormatInt(time.Now().Add(time.Hour).UnixMilli(), 10) }

func connect(t *testing.T, s *integrationstest.Stack, app, email string) int64 {
	return s.Connect(t, 1, "google_workspace", app, email,
		`{"access_token":"at","refresh_token":"rt","expiry_date":`+farFuture()+`,"scope":"openid"}`)
}

func run(t *testing.T, s *integrationstest.Stack, name string, args map[string]any) string {
	t.Helper()
	return runAs(t, s, integrations.ExecOptions{}, name, args)
}

func runAs(t *testing.T, s *integrationstest.Stack, opts integrations.ExecOptions, name string, args map[string]any) string {
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

func TestOAuthRoundTripConnectsEveryGrantedApp(t *testing.T) {
	s, fake := setup(t)
	all := strings.Join(append(append([]string{}, identityScopes...), "https://mail.google.com/", "https://www.googleapis.com/auth/calendar",
		"https://www.googleapis.com/auth/drive", "https://www.googleapis.com/auth/documents", "https://www.googleapis.com/auth/spreadsheets"), " ")
	scopeGranted := all
	fake.onFunc("POST /token", func(r *http.Request, body string) (int, string) {
		form, _ := url.ParseQuery(body)
		if form.Get("code") != "the-code" || form.Get("code_verifier") == "" || form.Get("client_secret") != "csecret" || form.Get("grant_type") != "authorization_code" {
			return 400, `{"error":"invalid_grant"}`
		}
		return 200, `{"access_token":"at-1","refresh_token":"rt-1","expires_in":3600,"scope":"` + scopeGranted + `","token_type":"Bearer","id_token":"jwt"}`
	})
	fake.on("GET /userinfo", 200, `{"email":"zed@example.com","name":"Zed"}`)

	start, err := s.Mgr.BeginOAuth(context.Background(), 1, "google_workspace", integrations.BeginOptions{AppKey: "calendar"})
	if err != nil {
		t.Fatal(err)
	}
	u, _ := url.Parse(start.URL)
	q := u.Query()
	if q.Get("access_type") != "offline" || q.Get("prompt") != "consent" || q.Get("code_challenge_method") != "S256" || q.Get("include_granted_scopes") != "true" ||
		q.Get("client_id") != "cid" || q.Get("scope") != all || q.Get("response_type") != "code" {
		t.Fatalf("authorization url: %s", start.URL)
	}

	res, err := s.Mgr.FinishOAuth(context.Background(), start.State, "the-code")
	if err != nil {
		t.Fatal(err)
	}
	if res.AccountEmail != "zed@example.com" || res.AppID != "calendar" {
		t.Fatalf("result %+v", res)
	}
	rows, _ := s.Svc.ListConnections(context.Background(), 1, "google_workspace", s.MainAgent(t, 1))
	apps := map[string]bool{}
	for _, r := range rows {
		apps[r.AppKey] = true
		creds := s.Svc.Credentials(r)
		if creds.String("access_token") != "at-1" || creds.String("refresh_token") != "rt-1" || creds["expiry_date"] == nil || creds["expires_in"] != nil {
			t.Fatalf("credentials of %s: %v", r.AppKey, creds)
		}
	}
	if len(rows) != 5 || !apps["gmail"] || !apps["sheets"] {
		t.Fatalf("one sign-in must connect all five apps, got %v", apps)
	}
	var meta map[string]any
	for _, r := range rows {
		_ = json.Unmarshal([]byte(r.MetadataJSON), &meta)
		if meta["appId"] != r.AppKey {
			t.Fatalf("metadata of %s: %v", r.AppKey, meta)
		}
	}

	// Unticking Drive on the consent screen leaves Drive unconnected.
	scopeGranted = strings.ReplaceAll(all, " https://www.googleapis.com/auth/drive", "")
	s.Exec(t, `DELETE FROM integration_connections`)
	start, _ = s.Mgr.BeginOAuth(context.Background(), 1, "google_workspace", integrations.BeginOptions{AppKey: "gmail"})
	if _, err := s.Mgr.FinishOAuth(context.Background(), start.State, "the-code"); err != nil {
		t.Fatal(err)
	}
	rows, _ = s.Svc.ListConnections(context.Background(), 1, "google_workspace", s.MainAgent(t, 1))
	if len(rows) != 4 {
		t.Fatalf("expected four apps without drive, got %d", len(rows))
	}
	for _, r := range rows {
		if r.AppKey == "drive" {
			t.Fatal("drive connected without its scope")
		}
	}
}

func TestFinishRefusesGrantsThatWouldExpire(t *testing.T) {
	s, fake := setup(t)
	fake.on("POST /token", 200, `{"access_token":"at-1","expires_in":3600,"scope":"openid"}`)
	fake.on("GET /userinfo", 200, `{"email":"zed@example.com"}`)
	start, _ := s.Mgr.BeginOAuth(context.Background(), 1, "google_workspace", integrations.BeginOptions{AppKey: "gmail"})
	_, err := s.Mgr.FinishOAuth(context.Background(), start.State, "c")
	if err == nil || !strings.Contains(err.Error(), "did not return a refresh token") {
		t.Fatalf("got %v", err)
	}
	fake.on("POST /token", 200, `{"access_token":"at-1","refresh_token":"r","scope":"openid"}`)
	fake.on("GET /userinfo", 200, `{}`)
	start, _ = s.Mgr.BeginOAuth(context.Background(), 1, "google_workspace", integrations.BeginOptions{AppKey: "gmail"})
	if _, err := s.Mgr.FinishOAuth(context.Background(), start.State, "c"); err == nil || err.Error() != "Google OAuth did not return an account email address." {
		t.Fatalf("got %v", err)
	}
	fake.on("POST /token", 400, `{"error":"invalid_grant","error_description":"Bad Request"}`)
	start, _ = s.Mgr.BeginOAuth(context.Background(), 1, "google_workspace", integrations.BeginOptions{AppKey: "gmail"})
	if _, err := s.Mgr.FinishOAuth(context.Background(), start.State, "c"); err == nil || err.Error() != "invalid_grant" {
		t.Fatalf("token error: %v", err)
	}
}

func TestExpiringTokensAreRefreshedForEveryApp(t *testing.T) {
	s, fake := setup(t)
	soon := strconv.FormatInt(time.Now().Add(2*time.Minute).UnixMilli(), 10)
	gmail := s.Connect(t, 1, "google_workspace", "gmail", "zed@example.com", `{"access_token":"old","refresh_token":"rt","expiry_date":`+soon+`}`)
	cal := s.Connect(t, 1, "google_workspace", "calendar", "zed@example.com", `{"access_token":"old","refresh_token":"rt","expiry_date":`+soon+`}`)
	fake.onFunc("POST /token", func(r *http.Request, body string) (int, string) {
		form, _ := url.ParseQuery(body)
		if form.Get("grant_type") != "refresh_token" || form.Get("refresh_token") != "rt" {
			return 400, `{"error":"invalid_grant"}`
		}
		return 200, `{"access_token":"fresh","expires_in":3599,"scope":"openid","token_type":"Bearer"}`
	})
	fake.on("GET /gmail/v1/users/me/labels", 200, `{"labels":[{"id":"INBOX","name":"INBOX","type":"system","messagesTotal":4},{"id":"L1","name":"Work"}]}`)
	got := run(t, s, "google_workspace_gmail_list_labels", nil)
	if got != `{"count":2,"labels":[{"id":"INBOX","name":"INBOX","type":"system","messagesTotal":4,"threadsTotal":null},{"id":"L1","name":"Work","type":"user","messagesTotal":null,"threadsTotal":null}]}` {
		t.Fatalf("labels: %s", got)
	}
	if last := fake.last(); last.Auth != "Bearer fresh" {
		t.Fatalf("call used %q", last.Auth)
	}
	// The renewed token is shared by both apps of the account.
	for _, id := range []int64{gmail, cal} {
		c, _ := s.Svc.ConnectionByID(context.Background(), 1, id, s.MainAgent(t, 1))
		creds := s.Svc.Credentials(*c)
		if creds.String("access_token") != "fresh" || creds.String("refresh_token") != "rt" {
			t.Fatalf("connection %d credentials: %v", id, creds)
		}
	}
}

func TestRejectedTokenIsRefreshedOnce(t *testing.T) {
	s, fake := setup(t)
	connect(t, s, "gmail", "zed@example.com")
	fake.on("POST /token", 200, `{"access_token":"fresh","expires_in":3600}`)
	fake.onFunc("GET /gmail/v1/users/me/labels", func(r *http.Request, _ string) (int, string) {
		if r.Header.Get("Authorization") == "Bearer at" {
			return 401, `{"error":{"code":401,"message":"Invalid Credentials"}}`
		}
		return 200, `{"labels":[]}`
	})
	if got := run(t, s, "google_workspace_gmail_list_labels", nil); got != `{"count":0,"labels":[]}` {
		t.Fatalf("got %s", got)
	}
}

func TestGoogleErrorsKeepTheirMessageAndStatus(t *testing.T) {
	s, fake := setup(t)
	connect(t, s, "gmail", "zed@example.com")
	fake.on("GET /gmail/v1/users/me/labels", 403, `{"error":{"code":403,"message":"Request had insufficient authentication scopes."}}`)
	got := run(t, s, "google_workspace_gmail_list_labels", nil)
	want := `{"error":"Request had insufficient authentication scopes.","status":403,"next":"The service refused this account. Only the owner can change that, in the account or its organization; connected accounts' credentials are never available to you, so tell the owner what was refused."}`
	if got != want {
		t.Fatalf("got  %s\nwant %s", got, want)
	}
	fake.on("POST /token", 400, `{"error":"invalid_grant"}`)
	s.Exec(t, `UPDATE integration_connections SET credentials_json = ?`, mustSeal(t, s, `{"access_token":"x","refresh_token":"rt","expiry_date":1}`))
	got = run(t, s, "google_workspace_gmail_list_labels", nil)
	if !strings.Contains(got, `"expired":true`) {
		t.Fatalf("a revoked grant must mark the connection expired: %s", got)
	}
}

func mustSeal(t *testing.T, s *integrationstest.Stack, plain string) string {
	sealed, err := s.Box.Seal(plain)
	if err != nil {
		t.Fatal(err)
	}
	return sealed
}

func TestGmailSearchAndReadDecodeMail(t *testing.T) {
	s, fake := setup(t)
	connect(t, s, "gmail", "zed@example.com")
	fake.on("GET /gmail/v1/users/me/threads", 200, `{"threads":[{"id":"t1"},{"id":"t2"}]}`)
	fake.onFunc("GET /gmail/v1/users/me/threads/t1", func(r *http.Request, _ string) (int, string) {
		if r.URL.Query().Get("format") == "full" {
			body := base64.RawURLEncoding.EncodeToString([]byte("Hallo Welt"))
			return 200, `{"id":"t1","historyId":"9","snippet":"Gr&#39;","messages":[{"id":"m1","threadId":"t1","labelIds":["INBOX"],"snippet":"s","internalDate":"1700000000000",
				"payload":{"mimeType":"multipart/alternative","headers":[{"name":"Subject","value":"=?UTF-8?B?SGVsbG8gV8O2cmxk?="},{"name":"From","value":"a@x"}],
				"parts":[{"mimeType":"text/plain","headers":[],"body":{"data":"` + body + `"}}]}}]}`
		}
		return 200, `{"id":"t1","historyId":"7","snippet":"snip","messages":[{"payload":{"headers":[{"name":"subject","value":"Old"}]}},{"payload":{"headers":[{"name":"Subject","value":"Last"},{"name":"From","value":"b@x"},{"name":"Date","value":"Mon"}]}}]}`
	})
	fake.on("GET /gmail/v1/users/me/threads/t2", 200, `{"id":"t2","messages":[]}`)

	got := run(t, s, "google_workspace_gmail_search_threads", map[string]any{"query": "is:unread", "max_results": float64(500)})
	want := `{"query":"is:unread","count":2,"threads":[{"id":"t1","snippet":"snip","historyId":"7","messageCount":2,"subject":"Last","from":"b@x","date":"Mon"},{"id":"t2","snippet":"","historyId":null,"messageCount":0,"subject":null,"from":null,"date":null}]}`
	if got != want {
		t.Fatalf("got  %s\nwant %s", got, want)
	}
	list := fake.seen()[0]
	if !strings.Contains(list.URI, "maxResults=25") || !strings.Contains(list.URI, "q=is%3Aunread") {
		t.Fatalf("list request %s", list.URI)
	}
	var metadata string
	for _, r := range fake.seen() {
		if strings.HasPrefix(r.URI, "/gmail/v1/users/me/threads/t1") {
			metadata = r.URI
			break
		}
	}
	if !strings.Contains(metadata, "format=metadata") || strings.Count(metadata, "metadataHeaders=") != 3 {
		t.Fatalf("thread request %s", metadata)
	}

	got = run(t, s, "google_workspace_gmail_get_thread", map[string]any{"thread_id": "t1"})
	want = `{"id":"t1","historyId":"9","snippet":"Gr&#39;","messages":[{"id":"m1","threadId":"t1","labelIds":["INBOX"],"snippet":"s","internalDate":"2023-11-14T22:13:20.000Z","subject":"Hello Wörld","from":"a@x","to":null,"date":null,"bodyText":"Hallo Welt"}]}`
	if got != want {
		t.Fatalf("got  %s\nwant %s", got, want)
	}
}

func TestGmailSendAndLabels(t *testing.T) {
	s, fake := setup(t)
	connect(t, s, "gmail", "zed@example.com")
	fake.on("POST /gmail/v1/users/me/messages/send", 200, `{"id":"m9","threadId":"t9","labelIds":["SENT"]}`)
	got := run(t, s, "google_workspace_gmail_send_email", map[string]any{
		"to": "a@x, b@x", "cc": "c@x", "bcc": "d@x", "subject": "Grüße ✓", "body_text": "Hi\nthere", "thread_id": "t9",
	})
	if got != `{"id":"m9","threadId":"t9","labelIds":["SENT"]}` {
		t.Fatalf("got %s", got)
	}
	var sent struct{ Raw, ThreadID string }
	if err := json.Unmarshal([]byte(fake.last().Body), &sent); err != nil || sent.ThreadID != "t9" {
		t.Fatalf("body %s", fake.last().Body)
	}
	raw, _ := base64.RawURLEncoding.DecodeString(sent.Raw)
	wantRaw := "To: a@x, b@x\r\nCc: c@x\r\nBcc: d@x\r\nSubject: =?UTF-8?B?R3LDvMOfZSDinJM=?=\r\nContent-Type: text/plain; charset=utf-8\r\nMIME-Version: 1.0\r\n\r\nHi\nthere"
	if string(raw) != wantRaw {
		t.Fatalf("raw message:\n%q\nwant\n%q", raw, wantRaw)
	}
	if got := run(t, s, "google_workspace_gmail_send_email", map[string]any{"to": "a@x\r\nBcc: evil@x", "subject": "s", "body_text": "b"}); got != `{"error":"to must not contain newline characters."}` {
		t.Fatalf("header injection: %s", got)
	}

	fake.on("GET /gmail/v1/users/me/labels", 200, `{"labels":[{"id":"INBOX","name":"INBOX"},{"id":"L1","name":"Work"},{"id":"S","name":"STARRED"}]}`)
	fake.on("POST /gmail/v1/users/me/threads/t1/modify", 200, `{"id":"t1","historyId":"12"}`)
	got = run(t, s, "google_workspace_gmail_modify_thread_labels", map[string]any{"thread_id": "t1", "add_label_names": []any{"work", "nope"}, "archive": true})
	if got != `{"id":"t1","historyId":"12","added":["L1"],"removed":["INBOX"]}` {
		t.Fatalf("got %s", got)
	}
	if fake.last().Body != `{"addLabelIds":["L1"],"removeLabelIds":["INBOX"]}` {
		t.Fatalf("modify body %s", fake.last().Body)
	}
}

func TestCalendarListAppliesTheWindowRules(t *testing.T) {
	s, fake := setup(t)
	connect(t, s, "calendar", "zed@example.com")
	fake.on("GET /calendar/v3/calendars/primary/events", 200, `{"items":[
		{"id":"run","summary":"Running","start":{"dateTime":"2026-11-24T09:00:00Z"},"end":{"dateTime":"2026-11-24T11:00:00Z"}},
		{"id":"soon","summary":"Soon","start":{"dateTime":"2026-11-24T10:30:00Z"},"end":{"dateTime":"2026-11-24T11:00:00Z"},"attendees":[{"email":"a@x"},{}]},
		{"id":"bday","summary":"Birthday","start":{"date":"2026-11-24"},"end":{"date":"2026-11-25"}}]}`)

	args := map[string]any{"time_min": "2026-11-24T10:00:00Z", "time_max": "2026-11-24T12:00:00Z", "query": " standup ", "max_results": float64(900)}
	got := run(t, s, "google_workspace_calendar_list_events", args)
	var listed struct {
		Count, OverlapCount, OmittedOngoingTimedCount, OmittedAllDayCount int
		WindowMode                                                        string
		Events                                                            []struct{ ID string }
	}
	if err := json.Unmarshal([]byte(got), &listed); err != nil || listed.Count != 1 || listed.Events[0].ID != "soon" || listed.OverlapCount != 3 ||
		listed.OmittedOngoingTimedCount != 1 || listed.OmittedAllDayCount != 1 || listed.WindowMode != "starts_within_window" {
		t.Fatalf("bounded list: %s", got)
	}
	uri := fake.last().URI
	for _, part := range []string{"q=standup", "timeMin=2026-11-24T10%3A00%3A00Z", "singleEvents=true", "orderBy=startTime", "maxResults=50"} {
		if !strings.Contains(uri, part) {
			t.Fatalf("request %s lacks %s", uri, part)
		}
	}
	args["include_ongoing"], args["include_all_day"] = true, true
	if got := run(t, s, "google_workspace_calendar_list_events", args); !strings.Contains(got, `"windowMode":"overlap"`) || !strings.Contains(got, `"count":3`) {
		t.Fatalf("overlap list: %s", got)
	}

	// A scheduled task must bound the window itself.
	task := integrations.ExecOptions{Run: integrations.Run{TriggerSource: "schedule", TaskID: "7", ScheduledAt: "2026-11-24T10:15:00Z"}}
	if got := runAs(t, s, task, "google_workspace_calendar_list_events", map[string]any{"time_min": "2026-11-24T10:00:00Z"}); !strings.HasPrefix(got, `{"error":"Automatic calendar checks require both time_min and time_max.`) {
		t.Fatalf("unbounded automatic check: %s", got)
	}
	got = runAs(t, s, task, "google_workspace_calendar_list_events", map[string]any{"time_min": "2026-11-24T10:00:00Z", "time_max": "2026-11-24T12:00:00Z"})
	if !strings.Contains(got, `"id":"soon"`) || strings.Contains(got, `"id":"run"`) {
		t.Fatalf("automatic check keeps only events that have not started: %s", got)
	}
	if got := runAs(t, s, task, "google_workspace_calendar_api_request", map[string]any{"method": "get", "path": "/calendar/v3/calendars/primary/events?x=1"}); !strings.HasPrefix(got, `{"error":"Automatic calendar checks must use google_workspace_calendar_list_events`) {
		t.Fatalf("raw events query in a task: %s", got)
	}
}

func TestCalendarWrites(t *testing.T) {
	s, fake := setup(t)
	connect(t, s, "calendar", "zed@example.com")
	fake.on("POST /calendar/v3/calendars/work@x/events", 200, `{"id":"e1","summary":"Lunch","start":{"dateTime":"2026-11-25T12:00:00+01:00"},"end":{"dateTime":"2026-11-25T13:00:00+01:00"}}`)
	got := run(t, s, "google_workspace_calendar_create_event", map[string]any{
		"calendar_id": "work@x", "summary": "Lunch", "start": "2026-11-25T12:00:00", "end": "2026-11-25T13:00:00",
		"timezone": "Europe/Berlin", "attendees": "a@x, b@x", "location": "Cafe",
	})
	if !strings.Contains(got, `"id":"e1"`) || !strings.Contains(got, `"allDay":false`) {
		t.Fatalf("created: %s", got)
	}
	var body map[string]any
	_ = json.Unmarshal([]byte(fake.last().Body), &body)
	if body["location"] != "Cafe" || body["description"] != nil || body["start"].(map[string]any)["timeZone"] != "Europe/Berlin" || len(body["attendees"].([]any)) != 2 {
		t.Fatalf("create body: %s", fake.last().Body)
	}

	fake.on("GET /calendar/v3/calendars/primary/events/e1", 200, `{"id":"e1","summary":"Old","etag":"x","start":{"dateTime":"2026-11-25T12:00:00Z","timeZone":"UTC"},"end":{"dateTime":"2026-11-25T13:00:00Z"}}`)
	fake.on("PUT /calendar/v3/calendars/primary/events/e1", 200, `{"id":"e1","summary":"New"}`)
	run(t, s, "google_workspace_calendar_update_event", map[string]any{"event_id": "e1", "summary": "New", "start": "2026-11-25T14:00:00", "description": nil})
	body = nil
	_ = json.Unmarshal([]byte(fake.last().Body), &body)
	start := body["start"].(map[string]any)
	if body["summary"] != "New" || body["etag"] != "x" || start["timeZone"] != "UTC" || start["dateTime"] != "2026-11-25T14:00:00" || body["description"] != "" {
		t.Fatalf("update keeps the rest of the event and the old zone: %s", fake.last().Body)
	}
	if body["end"].(map[string]any)["dateTime"] != "2026-11-25T13:00:00Z" {
		t.Fatalf("end untouched: %s", fake.last().Body)
	}

	fake.on("DELETE /calendar/v3/calendars/primary/events/e1", 204, ``)
	if got := run(t, s, "google_workspace_calendar_delete_event", map[string]any{"event_id": "e1"}); got != `{"deleted":true,"eventId":"e1"}` {
		t.Fatalf("delete: %s", got)
	}
	fake.on("POST /calendar/v3/freeBusy", 200, `{"calendars":{"primary":{"busy":[]}}}`)
	if got := run(t, s, "google_workspace_calendar_free_busy", map[string]any{"time_min": "a", "time_max": "b"}); got != `{"calendars":{"primary":{"busy":[]}}}` {
		t.Fatalf("free busy: %s", got)
	}
	if fake.last().Body != `{"items":[{"id":"primary"}],"timeMax":"b","timeMin":"a"}` {
		t.Fatalf("free busy body: %s", fake.last().Body)
	}
}

func TestDriveFiles(t *testing.T) {
	s, fake := setup(t)
	connect(t, s, "drive", "zed@example.com")
	dir := t.TempDir()

	fake.on("GET /drive/v3/files", 200, `{"files":[{"id":"f1","name":"a.txt","mimeType":"text/plain","size":"12","parents":["p"]},{"id":"f2"}]}`)
	got := run(t, s, "google_workspace_drive_search_files", map[string]any{"query": "name contains 'a'"})
	want := `{"count":2,"files":[{"id":"f1","name":"a.txt","mimeType":"text/plain","modifiedTime":null,"size":12,"webViewLink":null,"webContentLink":null,"parents":["p"]},{"id":"f2","name":"","mimeType":null,"modifiedTime":null,"size":null,"webViewLink":null,"webContentLink":null,"parents":[]}]}`
	if got != want {
		t.Fatalf("got  %s\nwant %s", got, want)
	}

	src := filepath.Join(dir, "up.txt")
	os.WriteFile(src, []byte("hello drive"), 0o600)
	fake.on("POST /upload/drive/v3/files", 200, `{"id":"new","name":"renamed.txt"}`)
	got = run(t, s, "google_workspace_drive_upload_file", map[string]any{"file_path": src, "name": "renamed.txt", "mime_type": "text/plain", "parent_ids": []any{"folder"}})
	if !strings.Contains(got, `"id":"new"`) {
		t.Fatalf("upload: %s", got)
	}
	up := fake.last()
	mediaType, params, err := mime.ParseMediaType(up.Type)
	if err != nil || mediaType != "multipart/related" || !strings.Contains(up.URI, "uploadType=multipart") {
		t.Fatalf("upload request %s %s", up.URI, up.Type)
	}
	reader := multipart.NewReader(strings.NewReader(up.Body), params["boundary"])
	meta, _ := reader.NextPart()
	metaBody, _ := io.ReadAll(meta)
	media, _ := reader.NextPart()
	mediaBody, _ := io.ReadAll(media)
	if string(metaBody) != `{"name":"renamed.txt","parents":["folder"]}` && string(metaBody) != `{"parents":["folder"],"name":"renamed.txt"}` {
		t.Fatalf("metadata part %s", metaBody)
	}
	if media.Header.Get("Content-Type") != "text/plain" || string(mediaBody) != "hello drive" {
		t.Fatalf("media part %q %q", media.Header.Get("Content-Type"), mediaBody)
	}
	if got := run(t, s, "google_workspace_drive_upload_file", map[string]any{"file_path": "../secret"}); got != `{"error":"file_path must not contain parent traversal segments."}` {
		t.Fatalf("traversal: %s", got)
	}
	if got := run(t, s, "google_workspace_drive_upload_file", map[string]any{"file_path": dir}); got != `{"error":"file_path must point to a readable file."}` {
		t.Fatalf("directory: %s", got)
	}

	fake.on("GET /drive/v3/files/f1", 200, "file bytes")
	dest := filepath.Join(dir, "nested", "down.bin")
	got = run(t, s, "google_workspace_drive_download_file", map[string]any{"file_id": "f1", "destination_path": dest})
	if got != `{"fileId":"f1","destinationPath":"`+dest+`","bytesWritten":10}` {
		t.Fatalf("download: %s", got)
	}
	if data, _ := os.ReadFile(dest); string(data) != "file bytes" || !strings.Contains(fake.last().URI, "alt=media") {
		t.Fatalf("downloaded %q via %s", data, fake.last().URI)
	}
	fake.on("GET /drive/v3/files/f1/export", 200, "%PDF")
	run(t, s, "google_workspace_drive_export_file", map[string]any{"file_id": "f1", "mime_type": "application/pdf", "destination_path": filepath.Join(dir, "out.pdf")})
	if data, _ := os.ReadFile(filepath.Join(dir, "out.pdf")); string(data) != "%PDF" {
		t.Fatalf("export wrote %q", data)
	}

	fake.on("POST /drive/v3/files/f1/permissions", 200, `{}`)
	fake.on("GET /drive/v3/files/f1", 200, `{"id":"f1","name":"a","webViewLink":"https://drive/f1"}`)
	if got := run(t, s, "google_workspace_drive_create_share_link", map[string]any{"file_id": "f1", "type": "user"}); got != `{"error":"email_address is required."}` {
		t.Fatalf("share without email: %s", got)
	}
	got = run(t, s, "google_workspace_drive_create_share_link", map[string]any{"file_id": "f1", "type": "anyone"})
	if !strings.Contains(got, `"webViewLink":"https://drive/f1"`) {
		t.Fatalf("share: %s", got)
	}
}

func TestDocs(t *testing.T) {
	s, fake := setup(t)
	connect(t, s, "docs", "zed@example.com")
	fake.on("GET /v1/documents/d1", 200, `{"documentId":"d1","title":"T","body":{"content":[{"paragraph":{"elements":[{"textRun":{"content":"Hello "}},{"textRun":{"content":"world\n"}}]}},{"sectionBreak":{}}]}}`)
	if got := run(t, s, "google_workspace_docs_get_document", map[string]any{"document_id": "d1"}); got != `{"documentId":"d1","title":"T","text":"Hello world"}` {
		t.Fatalf("get: %s", got)
	}
	fake.on("POST /v1/documents", 200, `{"documentId":"d2","title":"New"}`)
	fake.on("POST /v1/documents/d2:batchUpdate", 500, `{"error":{"message":"boom"}}`)
	got := run(t, s, "google_workspace_docs_create_document", map[string]any{"title": "New", "initial_text": "text"})
	if got != `{"documentId":"d2","title":"New","created":true,"initialized":false,"error":"boom"}` {
		t.Fatalf("create with failing initial text: %s", got)
	}
	fake.on("POST /v1/documents/d2:batchUpdate", 200, `{"replies":[{"replaceAllText":{"occurrencesChanged":3}}]}`)
	if got := run(t, s, "google_workspace_docs_replace_text", map[string]any{"document_id": "d2", "search_text": "a", "replace_text": "b"}); got != `{"documentId":"d2","occurrencesChanged":3}` {
		t.Fatalf("replace: %s", got)
	}
	if fake.last().Body != `{"requests":[{"replaceAllText":{"containsText":{"matchCase":true,"text":"a"},"replaceText":"b"}}]}` {
		t.Fatalf("replace body: %s", fake.last().Body)
	}
	if got := run(t, s, "google_workspace_docs_append_text", map[string]any{"document_id": "d2", "text": "more"}); got != `{"documentId":"d2","appended":true}` {
		t.Fatalf("append: %s", got)
	}
	if got := run(t, s, "google_workspace_docs_get_document", map[string]any{}); got != `{"error":"document_id is required."}` {
		t.Fatalf("missing id: %s", got)
	}
}

func TestSheets(t *testing.T) {
	s, fake := setup(t)
	connect(t, s, "sheets", "zed@example.com")
	fake.on("GET /v4/spreadsheets/s1/values/A1:B2", 200, `{"range":"Sheet1!A1:B2","values":[["a","b"]]}`)
	if got := run(t, s, "google_workspace_sheets_get_values", map[string]any{"spreadsheet_id": "s1", "range": "A1:B2"}); got != `{"range":"Sheet1!A1:B2","majorDimension":"ROWS","values":[["a","b"]]}` {
		t.Fatalf("get: %s", got)
	}
	fake.on("PUT /v4/spreadsheets/s1/values/A1", 200, `{"updatedRange":"Sheet1!A1","updatedCells":1}`)
	if got := run(t, s, "google_workspace_sheets_update_values", map[string]any{"spreadsheet_id": "s1", "range": "A1", "values": []any{[]any{"x"}}}); got != `{"updatedRange":"Sheet1!A1","updatedRows":0,"updatedColumns":0,"updatedCells":1}` {
		t.Fatalf("update: %s", got)
	}
	if !strings.Contains(fake.last().URI, "valueInputOption=USER_ENTERED") {
		t.Fatalf("update request %s", fake.last().URI)
	}
	fake.on("POST /v4/spreadsheets", 200, `{"spreadsheetId":"n1","spreadsheetUrl":"https://s/n1","properties":{"title":"T"}}`)
	run(t, s, "google_workspace_sheets_create_spreadsheet", map[string]any{"title": "T", "sheet_titles": []any{" One ", "", "Two"}})
	if fake.last().Body != `{"properties":{"title":"T"},"sheets":[{"properties":{"title":"One"}},{"properties":{"title":"Two"}}]}` {
		t.Fatalf("create body: %s", fake.last().Body)
	}
	fake.on("POST /v4/spreadsheets/s1/values/A1:append", 403, `{"error":{"message":"The caller does not have permission"}}`)
	got := run(t, s, "google_workspace_sheets_append_rows", map[string]any{"spreadsheet_id": "s1", "range": "A1", "rows": []any{}})
	if got != `{"error":"Google Sheets request failed for google_workspace_sheets_append_rows (spreadsheet_id=s1, range=A1): The caller does not have permission"}` {
		t.Fatalf("wrapped error carries no status or guidance: %s", got)
	}
}

func TestAPIRequestStaysOnGoogle(t *testing.T) {
	s, fake := setup(t)
	connect(t, s, "gmail", "zed@example.com")
	fake.on("GET /gmail/v1/users/me/settings/sendAs", 200, `{"sendAs":[]}`)
	got := run(t, s, "google_workspace_gmail_api_request", map[string]any{
		"method": "get", "path": "/gmail/v1/users/me/settings/sendAs", "query": map[string]any{"b": "2", "a": []any{"x", "y"}},
	})
	if got != `{"status":200,"statusText":"OK","data":{"sendAs":[]}}` {
		t.Fatalf("got %s", got)
	}
	if uri := fake.last().URI; uri != "/gmail/v1/users/me/settings/sendAs?a=x&a=y&b=2" {
		t.Fatalf("query: %s", uri)
	}
	if got := run(t, s, "google_workspace_gmail_api_request", map[string]any{"method": "TRACE", "path": "/x"}); got != `{"error":"method must be one of GET, POST, PUT, PATCH, DELETE."}` {
		t.Fatalf("method: %s", got)
	}
	if got := run(t, s, "google_workspace_gmail_api_request", map[string]any{"method": "GET", "path": "https://evil.example/x"}); got != `{"error":"Google API request URL must target a googleapis.com host."}` {
		t.Fatalf("host: %s", got)
	}
	if got := run(t, s, "google_workspace_gmail_api_request", map[string]any{"method": "GET"}); got != `{"error":"path is required."}` {
		t.Fatalf("path: %s", got)
	}
	// The real host check, as configured for production.
	prod := newProvider(s.Svc, googleEndpoints())
	for _, bad := range []string{"https://googleapis.com.evil.example/x", "http://www.googleapis.com/x", "https://evilgoogleapis.com/x"} {
		if _, err := prod.requireAPIURL(bad, ""); err == nil {
			t.Errorf("%s was accepted", bad)
		}
	}
	for _, good := range []string{"https://www.googleapis.com/x", "/drive/v3/files", "https://sheets.googleapis.com/v4/spreadsheets"} {
		if _, err := prod.requireAPIURL(good, ""); err != nil {
			t.Errorf("%s: %v", good, err)
		}
	}
	fake.on("GET /drive/v3/files/x", 200, "AQID")
	got = run(t, s, "google_workspace_gmail_api_request", map[string]any{"method": "GET", "path": "/drive/v3/files/x", "response_type": "arraybuffer"})
	if got != `{"status":200,"statusText":"OK","data":"QVFJRA=="}` {
		t.Fatalf("binary: %s", got)
	}
}

func TestDisconnectRevokesOnlyWithTheLastApp(t *testing.T) {
	s, fake := setup(t)
	fake.on("POST /revoke", 200, `{}`)
	gmail := connect(t, s, "gmail", "zed@example.com")
	cal := connect(t, s, "calendar", "zed@example.com")
	disconnect := func(id int64) {
		t.Helper()
		if r := s.Call(t, "POST", "/api/integrations/google_workspace/disconnect", 1, `{"connectionId":`+strconv.FormatInt(id, 10)+`}`, nil); r.Status != 200 {
			t.Fatal(r.Raw)
		}
	}
	disconnect(gmail)
	if len(fake.seen()) != 0 {
		t.Fatalf("the grant is still used by Calendar: %v", fake.seen())
	}
	disconnect(cal)
	seen := fake.seen()
	if len(seen) != 1 || !strings.HasPrefix(seen[0].URI, "/revoke?token=rt") {
		t.Fatalf("expected the refresh token to be revoked: %v", seen)
	}
}

func TestConnectionTestCallsUserinfo(t *testing.T) {
	s, fake := setup(t)
	id := connect(t, s, "gmail", "zed@example.com")
	fake.on("GET /userinfo", 200, `{"email":"zed@example.com"}`)
	r := s.Call(t, "POST", "/api/integrations/google_workspace/test", 1, `{"connectionId":`+strconv.FormatInt(id, 10)+`}`, nil)
	if r.Status != 200 || !strings.Contains(r.Raw, `"message":"Google Workspace is connected and responding."`) {
		t.Fatalf("%d %s", r.Status, r.Raw)
	}
	fake.on("GET /userinfo", 401, `{"error":{"message":"Invalid Credentials"}}`)
	fake.on("POST /token", 400, `{"error":"invalid_grant"}`)
	r = s.Call(t, "POST", "/api/integrations/google_workspace/test", 1, `{"connectionId":`+strconv.FormatInt(id, 10)+`}`, nil)
	if r.Status != 400 || !strings.Contains(r.Raw, "Your Google Workspace connection has expired. Reconnect the account and try again.") {
		t.Fatalf("%d %s", r.Status, r.Raw)
	}
}

func TestSnapshotAndModelSummary(t *testing.T) {
	s, _ := setup(t)
	p := s.Mgr.Provider("google_workspace")
	scope := integrations.Scope{UserID: 1, AgentID: s.MainAgent(t, 1)}
	rows := func() []integrations.Connection {
		r, _ := s.Svc.ListConnections(context.Background(), 1, "google_workspace", scope.AgentID)
		return r
	}
	want := "Google Workspace: workspace setup is ready, but no app accounts are connected yet. If the user wants to use it, tell them to connect an account in Official Integrations first.\n" +
		"- Gmail: not connected yet.\n- Calendar: not connected yet.\n- Drive: not connected yet.\n- Docs: not connected yet.\n- Sheets: not connected yet."
	if got := p.SummarizeForModel(p.Snapshot(rows(), scope)); got != want {
		t.Fatalf("got\n%s", got)
	}
	connect(t, s, "gmail", "zed@example.com")
	snap := p.Snapshot(rows(), scope)
	got := p.SummarizeForModel(snap)
	if !strings.Contains(got, "Connected apps: Gmail: zed@example.com\n- Gmail: connected as zed@example.com. Use built-in tools: google_workspace_gmail_search_threads, ") {
		t.Fatalf("got\n%s", got)
	}
	raw, _ := json.Marshal(snap)
	if !strings.Contains(string(raw), `"signInCoversAllApps":true`) || strings.Contains(string(raw), "connectPrompt") {
		t.Fatalf("snapshot json: %s", raw)
	}
}
