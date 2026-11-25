package slack

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

type recorder struct {
	messages []messaging.Inbound
	members  []messaging.Membership
	blocked  []messaging.BlockedSender
}

func (r *recorder) Message(m messaging.Inbound)                 { r.messages = append(r.messages, m) }
func (r *recorder) QR(string)                                   {}
func (r *recorder) Connected()                                  {}
func (r *recorder) Disconnected(messaging.Disconnect)           {}
func (r *recorder) LoggedOut()                                  {}
func (r *recorder) Error(messaging.ErrorInfo)                   {}
func (r *recorder) BlockedSender(b messaging.BlockedSender)     { r.blocked = append(r.blocked, b) }
func (r *recorder) ApprovalResponse(messaging.ApprovalResponse) {}
func (r *recorder) Reaction(messaging.Reaction)                 {}
func (r *recorder) Membership(m messaging.Membership)           { r.members = append(r.members, m) }

func fakeSlack(t *testing.T, posts *[]url.Values) *httptest.Server {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("content-type", "application/json")
		r.ParseForm()
		if r.Header.Get("Authorization") != "Bearer xoxb-1" && r.PostForm.Get("token") != "xoxb-1" {
			w.Write([]byte(`{"ok":false,"error":"invalid_auth"}`))
			return
		}
		switch r.URL.Path {
		case "/api/auth.test":
			w.Write([]byte(`{"ok":true,"user_id":"UBOT","bot_id":"BBOT"}`))
		case "/api/chat.postMessage":
			*posts = append(*posts, r.PostForm)
			w.Write([]byte(`{"ok":true,"ts":"1.2"}`))
		default:
			t.Errorf("unexpected %s", r.URL.Path)
		}
	}))
	return srv
}

func open() messaging.AccessPolicy {
	return messaging.NormalizeAccessPolicy("slack", map[string]any{"schemaVersion": 3.0, "directPolicy": "open", "sharedPolicy": "open"})
}

func sign(secret, ts, body string) string {
	m := hmac.New(sha256.New, []byte(secret))
	m.Write([]byte("v0:" + ts + ":" + body))
	return "v0=" + hex.EncodeToString(m.Sum(nil))
}

func call(p messaging.Platform, body, secret string, now time.Time) messaging.WebhookResult {
	ts := strconv.FormatInt(now.Unix(), 10)
	req := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(body))
	req.Header.Set("X-Slack-Request-Timestamp", ts)
	req.Header.Set("X-Slack-Signature", sign(secret, ts, body))
	return p.(messaging.WebhookHandler).HandleWebhook(req, []byte(body))
}

func TestConnectSendAndEvents(t *testing.T) {
	var posts []url.Values
	srv := fakeSlack(t, &posts)
	defer srv.Close()
	rec := &recorder{}
	p, _ := Factory(Deps{APIURL: srv.URL + "/api/"})(messaging.Config{
		Settings:     map[string]any{"botToken": "xoxb-1", "signingSecret": "sig"},
		AccessPolicy: open(),
	}, rec)
	if err := p.Connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	if p.AuthInfo()["username"] != "UBOT" || p.Status() != messaging.StatusConnected {
		t.Fatal(p.AuthInfo(), p.Status())
	}
	if _, err := p.SendMessage(context.Background(), "C1", "hello <b>", messaging.SendOptions{}); err != nil {
		t.Fatal(err)
	}
	if len(posts) != 1 || posts[0].Get("channel") != "C1" || posts[0].Get("text") != "hello <b>" {
		t.Fatalf("%v", posts)
	}

	now := time.Now()
	if r := call(p, `{"type":"url_verification","challenge":"abc"}`, "sig", now); r.Status != 200 || r.Body.(map[string]any)["challenge"] != "abc" {
		t.Fatalf("%+v", r)
	}
	if r := call(p, `{"type":"event_callback"}`, "bad", now); r.Handled || r.Status != 403 {
		t.Fatalf("%+v", r)
	}
	if r := call(p, `{"type":"event_callback"}`, "sig", now.Add(-10*time.Minute)); r.Status != 403 {
		t.Fatalf("stale: %+v", r)
	}

	ev := `{"event":{"type":"message","channel":"C9","channel_type":"channel","user":"U1","text":"<@UBOT> hi there","ts":"1700000000.000100","event_ts":"1700000000.000100","thread_ts":"1699999999.000000","parent_user_id":"UBOT","client_msg_id":"cm1"}}`
	if r := call(p, ev, "sig", now); r.Status != 200 || r.Body != "OK" {
		t.Fatalf("%+v", r)
	}
	m := rec.messages[0]
	want := messaging.Inbound{
		Platform: "slack", ChatID: "C9", Sender: "U1", SenderTag: "<@U1>", Content: "hi there", IsGroup: true,
		WasMentioned: true, RepliedToAgent: true, MessageID: "cm1", Timestamp: "2023-11-14T22:13:20.000Z",
		ThreadID: "1699999999.000000", ChannelID: "C9", GroupID: "C9",
	}
	if m.Platform != want.Platform || m.ChatID != want.ChatID || m.Sender != want.Sender || m.SenderTag != want.SenderTag || m.Content != want.Content ||
		m.IsGroup != want.IsGroup || m.WasMentioned != want.WasMentioned || m.RepliedToAgent != want.RepliedToAgent || m.MessageID != want.MessageID ||
		m.Timestamp != want.Timestamp || m.ThreadID != want.ThreadID || m.ChannelID != want.ChannelID || m.GroupID != want.GroupID {
		t.Fatalf("%+v", m)
	}

	for _, ignored := range []string{
		`{"event":{"type":"message","user":"UBOT","text":"mine"}}`,
		`{"event":{"type":"message","subtype":"bot_message","user":"U1","text":"x"}}`,
		`{"event":{"type":"reaction_added","user":"U1"}}`,
		`{"event":{"type":"message","user":"U1","text":"<@UBOT>"}}`,
	} {
		if r := call(p, ignored, "sig", now); r.Status != 202 || r.Body != "ignored" {
			t.Fatalf("%s: %+v", ignored, r)
		}
	}
	dm := `{"event":{"type":"message","channel":"D1","channel_type":"im","user":"U2","text":"psst"}}`
	call(p, dm, "sig", now)
	if d := rec.messages[1]; d.IsGroup || d.ChannelID != "" || d.WasMentioned {
		t.Fatalf("%+v", d)
	}

	call(p, `{"event":{"type":"member_joined_channel","user":"U3","channel":"C9","event_ts":"1700000000.5"}}`, "sig", now)
	if len(rec.members) != 1 || rec.members[0].Kind != "member_joined" || rec.members[0].MemberName != "<@U3>" || rec.members[0].DMChatID != "U3" || rec.members[0].OccurredAt != "2023-11-14T22:13:20.500Z" {
		t.Fatalf("%+v", rec.members)
	}
}

func TestInboundSecretAndBlocked(t *testing.T) {
	rec := &recorder{}
	p, _ := Factory(Deps{})(messaging.Config{Settings: map[string]any{"inboundSecret": "k"}}, rec)
	body := `{"event":{"type":"message","channel":"D1","channel_type":"im","user":"U2","text":"hi"}}`
	req := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(body))
	if r := p.(messaging.WebhookHandler).HandleWebhook(req, []byte(body)); r.Status != 403 {
		t.Fatalf("%+v", r)
	}
	req.Header.Set("x-webhook-token", "k")
	if r := p.(messaging.WebhookHandler).HandleWebhook(req, []byte(body)); r.Status != 202 || r.Body != "blocked" {
		t.Fatalf("%+v", r)
	}
	if len(rec.blocked) != 1 || rec.blocked[0].Sender != "U2" {
		t.Fatalf("%+v", rec.blocked)
	}
}

func TestConnectErrors(t *testing.T) {
	p, _ := Factory(Deps{})(messaging.Config{Settings: map[string]any{}}, &recorder{})
	if _, ok := p.Connect(context.Background()).(*messaging.ConfigurationRequiredError); !ok {
		t.Fatal("expected configuration error")
	}
	var posts []url.Values
	srv := fakeSlack(t, &posts)
	defer srv.Close()
	p, _ = Factory(Deps{APIURL: srv.URL + "/api/"})(messaging.Config{Settings: map[string]any{"botToken": "wrong"}}, &recorder{})
	if err := p.Connect(context.Background()); err == nil || err.Error() != "Slack auth failed: invalid_auth" {
		t.Fatal(err)
	}
}
