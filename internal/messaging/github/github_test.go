package github

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

type recorder struct {
	mu       sync.Mutex
	messages []messaging.Inbound
	blocked  []messaging.BlockedSender
	disc     []messaging.Disconnect
}

func (r *recorder) Message(m messaging.Inbound) {
	r.mu.Lock()
	r.messages = append(r.messages, m)
	r.mu.Unlock()
}
func (r *recorder) QR(string)  {}
func (r *recorder) Connected() {}
func (r *recorder) Disconnected(d messaging.Disconnect) {
	r.mu.Lock()
	r.disc = append(r.disc, d)
	r.mu.Unlock()
}
func (r *recorder) LoggedOut()                {}
func (r *recorder) Error(messaging.ErrorInfo) {}
func (r *recorder) BlockedSender(b messaging.BlockedSender) {
	r.mu.Lock()
	r.blocked = append(r.blocked, b)
	r.mu.Unlock()
}
func (r *recorder) ApprovalResponse(messaging.ApprovalResponse) {}
func (r *recorder) Reaction(messaging.Reaction)                 {}
func (r *recorder) Membership(messaging.Membership)             {}

type creds struct{ token string }

func (c creds) MentionsToken(context.Context, int64, string) (string, error) { return c.token, nil }

type cursorStore struct {
	mu    sync.Mutex
	saved map[string]string
}

func (c *cursorStore) Load(context.Context, int64, string) (map[string]string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	out := map[string]string{}
	for k, v := range c.saved {
		out[k] = v
	}
	return out, nil
}

func (c *cursorStore) Save(_ context.Context, _ int64, _ string, m map[string]string) error {
	c.mu.Lock()
	c.saved = m
	c.mu.Unlock()
	return nil
}

type apiCall struct{ method, uri, body, auth string }

type fakeGitHub struct {
	srv   *httptest.Server
	mu    sync.Mutex
	calls []apiCall
	// routes maps "METHOD path" to a JSON answer.
	routes map[string]string
}

func newFake(t *testing.T, routes map[string]string) *fakeGitHub {
	f := &fakeGitHub{routes: routes}
	f.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		f.mu.Lock()
		f.calls = append(f.calls, apiCall{r.Method, r.URL.RequestURI(), string(b), r.Header.Get("Authorization")})
		answer, ok := f.routes[r.Method+" "+r.URL.Path]
		f.mu.Unlock()
		if !ok {
			w.WriteHeader(404)
			w.Write([]byte(`{"message":"Not Found"}`))
			return
		}
		if strings.HasPrefix(answer, "!") {
			status := int(answer[1]-'0')*100 + int(answer[2]-'0')*10 + int(answer[3]-'0')
			w.WriteHeader(status)
			w.Write([]byte(answer[4:]))
			return
		}
		w.Write([]byte(answer))
	}))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fakeGitHub) called(method, uri string) *apiCall {
	f.mu.Lock()
	defer f.mu.Unlock()
	for i := range f.calls {
		if f.calls[i].method == method && f.calls[i].uri == uri {
			return &f.calls[i]
		}
	}
	return nil
}

func setup(t *testing.T, f *fakeGitHub, policy map[string]any) (*Platform, *recorder, *cursorStore) {
	rec, store := &recorder{}, &cursorStore{saved: map[string]string{}}
	pol := messaging.NormalizeAccessPolicy("github", policy)
	plat, err := Factory(Deps{Credentials: creds{"tok"}, Cursors: store, APIURL: f.srv.URL, Client: http.DefaultClient, PollInterval: time.Hour})(
		messaging.Config{UserID: 1, AgentID: "a", AccessPolicy: pol}, rec)
	if err != nil {
		t.Fatal(err)
	}
	return plat.(*Platform), rec, store
}

var policyForRepo = map[string]any{
	"schemaVersion":    3.0,
	"sharedPolicy":     "allowlist",
	"sharedSpaceRules": []any{map[string]any{"scope": "group", "value": "Acme/Repo"}},
	"sharedActorRules": []any{map[string]any{"scope": "user", "value": "42"}},
}

func TestPollTurnsMentionsIntoMessages(t *testing.T) {
	f := newFake(t, map[string]string{
		"GET /user": `{"id":99,"login":"neo-bot"}`,
		"GET /repos/Acme/Repo/issues/comments": `[
		 {"id":1,"user":{"id":42,"login":"ann","type":"User"},"body":"hey @neo-bot please look","created_at":"2999-01-01T00:00:00Z","html_url":"https://github.com/Acme/Repo/issues/5#c1","issue_url":"https://api.github.com/repos/Acme/Repo/issues/5","author_association":"member"},
		 {"id":2,"user":{"id":42,"login":"ann","type":"User"},"body":"no mention","created_at":"2999-01-01T00:00:01Z","issue_url":"https://api.github.com/repos/Acme/Repo/issues/5"},
		 {"id":3,"user":{"id":7,"login":"eve","type":"User"},"body":"@NEO-BOT do it","created_at":"2999-01-01T00:00:02Z","html_url":"https://github.com/Acme/Repo/pull/6#c3","issue_url":"https://api.github.com/repos/Acme/Repo/issues/6","author_association":"NONE"},
		 {"id":4,"user":{"id":99,"login":"neo-bot","type":"Bot"},"body":"@neo-bot self","created_at":"2999-01-01T00:00:03Z","issue_url":"https://api.github.com/repos/Acme/Repo/issues/5"}]`,
		"GET /repos/Acme/Repo/pulls/comments": `[
		 {"id":10,"user":{"id":42,"login":"ann","type":"User"},"body":"@neo-bot why?","created_at":"2999-01-02T00:00:00Z","pull_request_url":"https://api.github.com/repos/Acme/Repo/pulls/6","in_reply_to_id":0,"path":"a.go","line":12,"diff_hunk":"@@ -1 +1 @@\n+x","author_association":"OWNER"},
		 {"id":11,"user":{"id":42,"login":"ann","type":"User"},"body":"and this?","created_at":"2999-01-02T00:00:01Z","pull_request_url":"https://api.github.com/repos/Acme/Repo/pulls/6","in_reply_to_id":77,"author_association":"OWNER"}]`,
		"GET /repos/Acme/Repo/pulls/comments/77": `{"id":77,"user":{"id":99}}`,
		"GET /repos/Acme/Repo/issues":            `[{"id":20,"number":9,"user":{"id":42,"login":"ann","type":"User"},"body":"@neo-bot new issue","created_at":"2999-01-03T00:00:00Z","html_url":"https://github.com/Acme/Repo/issues/9","author_association":"OWNER"}]`,
		"GET /notifications":                     `[]`,
	})
	p, rec, store := setup(t, f, policyForRepo)
	if err := p.Connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	defer p.Disconnect(context.Background())
	// Connect starts the poll loop; wait for its first pass.
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		store.mu.Lock()
		n := len(store.saved)
		store.mu.Unlock()
		if n > 0 {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	rec.mu.Lock()
	defer rec.mu.Unlock()
	got := map[string]messaging.Inbound{}
	for _, m := range rec.messages {
		got[m.MessageID] = m
	}
	if len(rec.messages) != 4 {
		t.Fatalf("emitted %d: %+v", len(rec.messages), rec.messages)
	}
	m := got["issue_comment:1"]
	if m.ChatID != "Acme/Repo#5" || m.Sender != "42" || m.SenderName != "@ann" || !m.WasMentioned || !m.IsGroup || m.GroupID != "Acme/Repo" ||
		m.ChannelName != "issue #5" || m.RoleIDs[0] != "MEMBER" || m.Metadata["threadKind"] != "issue" || m.Metadata["commentUrl"] != "https://github.com/Acme/Repo/issues/5#c1" {
		t.Fatalf("%+v", m)
	}
	r := got["review_comment:10"]
	if r.ChatID != "Acme/Repo#6:10" || r.ChannelName != "pull request #6" || len(r.ChannelContext) != 1 || r.ChannelContext[0].Content != "a.go:12\n@@ -1 +1 @@\n+x" || r.Metadata["threadKind"] != "pull_request" {
		t.Fatalf("%+v", r)
	}
	reply := got["review_comment:11"]
	if reply.ChatID != "Acme/Repo#6:77" || !reply.RepliedToAgent || reply.WasMentioned {
		t.Fatalf("%+v", reply)
	}
	if got["issue_body:20"].ChatID != "Acme/Repo#9" {
		t.Fatalf("%+v", got["issue_body:20"])
	}
	// eve (7) is not approved: one blocked sender, no message.
	if len(rec.blocked) != 1 || rec.blocked[0].Sender != "7" || rec.blocked[0].ChatID != "Acme/Repo#6" {
		t.Fatalf("%+v", rec.blocked)
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	if store.saved["acme/repo"] != "2999-01-03T00:00:00Z" || store.saved[notificationsCursor] == "" {
		t.Fatalf("cursors %v", store.saved)
	}
	if p.AuthInfo()["username"] != "neo-bot" {
		t.Fatal(p.AuthInfo())
	}
}

func TestSendEditsRunCommentAndMarkRead(t *testing.T) {
	f := newFake(t, map[string]string{
		"GET /user": `{"id":99,"login":"neo-bot"}`,
		"POST /repos/Acme/Repo/issues/5/comments":           `{"id":500}`,
		"PATCH /repos/Acme/Repo/issues/comments/500":        `{"id":500}`,
		"POST /repos/Acme/Repo/pulls/6/comments/10/replies": `{"id":600}`,
		"POST /repos/Acme/Repo/issues/comments/1/reactions": `{}`,
		"POST /repos/Acme/Repo/issues/9/reactions":          `{}`,
	})
	p, _, _ := setup(t, f, policyForRepo)
	ctx := context.Background()
	opts := messaging.SendOptions{RunID: "r1"}
	res, err := p.SendMessage(ctx, "Acme/Repo#5", "first", opts)
	if err != nil || res.MessageID != "500" {
		t.Fatal(res, err)
	}
	res, err = p.SendMessage(ctx, "Acme/Repo#5", "answer", opts)
	if err != nil || res.MessageID != "500" {
		t.Fatal(res, err)
	}
	if c := f.called("PATCH", "/repos/Acme/Repo/issues/comments/500"); c == nil || c.body != `{"body":"answer"}` || c.auth != "Bearer tok" {
		t.Fatalf("%+v", c)
	}
	if _, err := p.SendMessage(ctx, "Acme/Repo#5", "other run", messaging.SendOptions{RunID: "r2"}); err != nil {
		t.Fatal(err)
	}
	res, err = p.SendMessage(ctx, "Acme/Repo#6:10", "line", opts)
	if err != nil || res.MessageID != "600" {
		t.Fatal(res, err)
	}
	if !p.ownComment(600) {
		t.Fatal("review reply not remembered as own")
	}
	if _, err := p.SendMessage(ctx, "not-a-thread", "x", opts); err == nil || err.Error() != "Not a GitHub thread: not-a-thread. Use owner/repo#number." {
		t.Fatal(err)
	}
	if err := p.MarkRead(ctx, "Acme/Repo#5", "issue_comment:1"); err != nil {
		t.Fatal(err)
	}
	if err := p.MarkRead(ctx, "Acme/Repo#9", "issue_body:20"); err != nil {
		t.Fatal(err)
	}
	if c := f.called("POST", "/repos/Acme/Repo/issues/comments/1/reactions"); c == nil || c.body != `{"content":"eyes"}` {
		t.Fatalf("%+v", c)
	}
	if f.called("POST", "/repos/Acme/Repo/issues/9/reactions") == nil {
		t.Fatal("issue body reaction missing")
	}
}

func TestDiscoverMentionsInUnwatchedRepo(t *testing.T) {
	f := newFake(t, map[string]string{
		"GET /user": `{"id":99,"login":"neo-bot"}`,
		"GET /notifications": `[
		 {"updated_at":"2999-02-01T00:00:00Z","reason":"mention","repository":{"full_name":"Other/Thing"},"subject":{"latest_comment_url":"https://api.github.com/repos/Other/Thing/issues/comments/55"}},
		 {"updated_at":"2999-02-02T00:00:00Z","reason":"subscribed","repository":{"full_name":"Other/Thing"},"subject":{}}]`,
		"GET /repos/Other/Thing/issues/comments/55": `{"id":55,"user":{"id":7,"login":"eve","type":"User"},"body":"@neo-bot hi","created_at":"2999-01-31T00:00:00Z","issue_url":"https://api.github.com/repos/Other/Thing/issues/3","author_association":"NONE"}`,
	})
	approvedEverywhere := map[string]any{
		"schemaVersion": 3.0, "sharedPolicy": "allowlist",
		"sharedActorRules": []any{map[string]any{"scope": "user", "value": "7"}},
	}
	p, rec, _ := setup(t, f, approvedEverywhere)
	p.deps.PollInterval = time.Hour
	if err := p.Connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	defer p.Disconnect(context.Background())
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		rec.mu.Lock()
		n := len(rec.messages)
		rec.mu.Unlock()
		if n > 0 {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	rec.mu.Lock()
	defer rec.mu.Unlock()
	if len(rec.messages) != 1 || rec.messages[0].ChatID != "Other/Thing#3" || rec.messages[0].MessageID != "issue_comment:55" {
		t.Fatalf("%+v", rec.messages)
	}
}

func TestUnauthorizedPollNeedsUser(t *testing.T) {
	f := newFake(t, map[string]string{
		"GET /user":                            `{"id":99,"login":"neo-bot"}`,
		"GET /repos/Acme/Repo/issues/comments": `!401{"message":"Bad credentials"}`,
	})
	p, rec, _ := setup(t, f, policyForRepo)
	p.deps.PollInterval = time.Hour
	if err := p.Connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) && p.Status() == messaging.StatusConnected {
		time.Sleep(10 * time.Millisecond)
	}
	rec.mu.Lock()
	defer rec.mu.Unlock()
	if len(rec.disc) == 0 || !rec.disc[0].RequiresUserAction || rec.disc[0].Reason != "authentication_required" {
		t.Fatalf("%+v", rec.disc)
	}
}

func TestConnectWithoutAccount(t *testing.T) {
	f := newFake(t, nil)
	rec, store := &recorder{}, &cursorStore{}
	plat, _ := Factory(Deps{Credentials: creds{}, Cursors: store, APIURL: f.srv.URL, Client: http.DefaultClient})(messaging.Config{}, rec)
	if err := plat.Connect(context.Background()); err == nil || err.Error() != "Connect a GitHub account under Integrations → GitHub → Mentions first." {
		t.Fatal(err)
	}
}

func TestAccessTargetsAreCached(t *testing.T) {
	f := newFake(t, map[string]string{
		"GET /user":       `{"id":99,"login":"neo-bot"}`,
		"GET /user/repos": `[{"full_name":"Acme/Repo","private":true},{"full_name":"Acme/Pub","private":false}]`,
	})
	p, _, _ := setup(t, f, map[string]any{"schemaVersion": 3.0, "sharedPolicy": "disabled"})
	p.setStatus(messaging.StatusConnected)
	targets, err := p.ListAccessTargets(context.Background())
	if err != nil || len(targets) != 5 {
		t.Fatal(targets, err)
	}
	raw, _ := json.Marshal(targets[0])
	if string(raw) != `{"source":"live","bucket":"sharedActorRules","scope":"role","value":"OWNER","label":"Every owner","subtitle":"GitHub repository role"}` {
		t.Fatal(string(raw))
	}
	if targets[3].Subtitle != "Private repository" || targets[4].Subtitle != "Public repository" {
		t.Fatal(targets)
	}
	if _, err := p.ListAccessTargets(context.Background()); err != nil {
		t.Fatal(err)
	}
	n := 0
	f.mu.Lock()
	for _, c := range f.calls {
		if strings.HasPrefix(c.uri, "/user/repos") {
			n++
		}
	}
	f.mu.Unlock()
	if n != 1 {
		t.Fatalf("repos fetched %d times", n)
	}
}

func TestMentionPattern(t *testing.T) {
	for body, want := range map[string]bool{
		"@neo-bot hi": true, "hi @Neo-Bot": true, "x@neo-bot": false, "@neo-bot2": false, "@neo-bot-x": false,
		"(@neo-bot)": true, "email a@neo-bot.com": false, "@neo-bots then @neo-bot": true, "": false,
	} {
		if got := mentions(body, "neo-bot"); got != want {
			t.Errorf("%q: got %v", body, got)
		}
	}
}
