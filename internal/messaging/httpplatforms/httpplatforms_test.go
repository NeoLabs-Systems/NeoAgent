package httpplatforms

import (
	"bufio"
	"context"
	"encoding/json"
	"io"
	"net"
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
	members  []messaging.Membership
	blocked  []messaging.BlockedSender
	conn     int
}

func (r *recorder) Message(m messaging.Inbound) {
	r.mu.Lock()
	r.messages = append(r.messages, m)
	r.mu.Unlock()
}
func (r *recorder) QR(string)                         {}
func (r *recorder) Connected()                        { r.mu.Lock(); r.conn++; r.mu.Unlock() }
func (r *recorder) Disconnected(messaging.Disconnect) {}
func (r *recorder) LoggedOut()                        {}
func (r *recorder) Error(messaging.ErrorInfo)         {}
func (r *recorder) BlockedSender(b messaging.BlockedSender) {
	r.mu.Lock()
	r.blocked = append(r.blocked, b)
	r.mu.Unlock()
}
func (r *recorder) ApprovalResponse(messaging.ApprovalResponse) {}
func (r *recorder) Reaction(messaging.Reaction)                 {}
func (r *recorder) Membership(m messaging.Membership) {
	r.mu.Lock()
	r.members = append(r.members, m)
	r.mu.Unlock()
}

func (r *recorder) first(t *testing.T) messaging.Inbound {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		r.mu.Lock()
		if len(r.messages) > 0 {
			m := r.messages[0]
			r.mu.Unlock()
			return m
		}
		r.mu.Unlock()
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatal("no message emitted")
	return messaging.Inbound{}
}

func openPolicy(platform string) messaging.AccessPolicy {
	return messaging.NormalizeAccessPolicy(platform, map[string]any{"schemaVersion": 3.0, "directPolicy": "open", "sharedPolicy": "open"})
}

func build(t *testing.T, name string, settings map[string]any) (messaging.Platform, *recorder) {
	t.Helper()
	rec := &recorder{}
	p, err := Factories(Deps{Client: http.DefaultClient, AllowPrivate: true})[name](messaging.Config{Settings: settings, AccessPolicy: openPolicy(name)}, rec)
	if err != nil {
		t.Fatal(err)
	}
	return p, rec
}

func webhook(t *testing.T, p messaging.Platform, body string, header map[string]string) messaging.WebhookResult {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/api/messaging/webhook/x", strings.NewReader(body))
	for k, v := range header {
		req.Header.Set(k, v)
	}
	return p.(messaging.WebhookHandler).HandleWebhook(req, []byte(body))
}

func TestGenericWebhook(t *testing.T) {
	p, rec := build(t, "webchat", map[string]any{"inboundSecret": "s3cret"})
	if r := webhook(t, p, `{"text":"hi"}`, nil); r.Handled || r.Status != 403 {
		t.Fatalf("no secret: %+v", r)
	}
	if r := webhook(t, p, `{"text":"hi"}`, map[string]string{"x-webhook-token": "wrong"}); r.Status != 403 {
		t.Fatalf("wrong secret: %+v", r)
	}
	if r := webhook(t, p, `{"text":"  "}`, map[string]string{"x-neoagent-token": "s3cret"}); r.Status != 202 || r.Body != "ignored" {
		t.Fatalf("empty content: %+v", r)
	}
	body := `{"token":"s3cret","message":{"text":"hello"},"channel":"c1","sender":7,"user":{"name":"Ann"},"messageId":"m1"}`
	if r := webhook(t, p, body, nil); r.Status != 200 || r.Body != "OK" {
		t.Fatalf("accepted: %+v", r)
	}
	m := rec.first(t)
	if m.Content != "hello" || m.ChatID != "c1" || m.Sender != "7" || m.SenderName != "Ann" || m.MessageID != "m1" || !m.IsGroup || m.Platform != "webchat" {
		t.Fatalf("message: %+v", m)
	}
}

func TestConfigurableSend(t *testing.T) {
	var got struct {
		method, path, auth, ctype, body string
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		got.method, got.path, got.auth, got.ctype, got.body = r.Method, r.URL.RequestURI(), r.Header.Get("Authorization"), r.Header.Get("Content-Type"), string(b)
		w.Write([]byte(`{}`))
	}))
	defer srv.Close()
	p, _ := build(t, "nostr", map[string]any{"outboundUrl": srv.URL + "/send/{to}?c={content}", "token": "tok", "recipientField": "rcpt"})
	res, err := p.SendMessage(context.Background(), "a b", "x&y <z>", messaging.SendOptions{})
	if err != nil || !res.Success {
		t.Fatal(res, err)
	}
	if got.method != "POST" || got.path != "/send/a%20b?c=x%26y%20%3Cz%3E" || got.auth != "Bearer tok" || got.ctype != "application/json" {
		t.Fatalf("request: %+v", got)
	}
	if got.body != `{"content":"x&y <z>","rcpt":"a b"}` {
		t.Fatalf("body %s", got.body)
	}

	p, _ = build(t, "tlon", map[string]any{"outboundUrl": srv.URL, "bodyTemplate": `{"m":"{content}","t":"{to}"}`, "authHeader": "none", "token": "tok"})
	if _, err := p.SendMessage(context.Background(), "r", "a b", messaging.SendOptions{}); err != nil {
		t.Fatal(err)
	}
	if got.body != `{"m":"a%20b","t":"r"}` || got.auth != "" {
		t.Fatalf("template: %+v", got)
	}
}

func TestSendFailureRedacts(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(429)
		w.Write([]byte(`{"error":"see https://x.test/a token=abc123"}`))
	}))
	defer srv.Close()
	p, _ := build(t, "zalo", map[string]any{"outboundUrl": srv.URL})
	_, err := p.SendMessage(context.Background(), "a", "b", messaging.SendOptions{})
	var re *RequestError
	if err == nil || !asRequestError(err, &re) || re.Status != 429 || !re.SafeToRetry {
		t.Fatal(err)
	}
	if want := `Zalo request failed (429): {"error":"see [redacted-url] token=[redacted]"}`; re.Message != want {
		t.Fatalf("%q", re.Message)
	}
}

func asRequestError(err error, target **RequestError) bool {
	re, ok := err.(*RequestError)
	*target = re
	return ok
}

func TestGoogleChatAndTeamsAndLine(t *testing.T) {
	hdr := map[string]string{"x-webhook-token": "k"}
	gc, rec := build(t, "google_chat", map[string]any{"inboundSecret": "k"})
	r := webhook(t, gc, `{"message":{"name":"spaces/A/messages/1","argumentText":" hi bot","text":"@bot hi bot","space":{"name":"spaces/A","type":"ROOM"},"sender":{"name":"users/1","displayName":"Ann"}}}`, hdr)
	if r.Status != 200 || r.Body.(map[string]any)["text"] != "Received." {
		t.Fatalf("%+v", r)
	}
	m := rec.first(t)
	if m.ChatID != "spaces/A" || m.Sender != "users/1" || !m.WasMentioned || !m.IsGroup || m.Content != " hi bot" || m.SenderDisplayName != "Ann" {
		t.Fatalf("%+v", m)
	}

	tm, rec := build(t, "teams", map[string]any{"inboundSecret": "k"})
	r = webhook(t, tm, `{"id":"i1","text":"<at>Bot</at> do it","recipient":{"id":"b1"},"from":{"id":"u1","name":"Bob"},"conversation":{"id":"cv","isGroup":false},"entities":[{"type":"mention","mentioned":{"id":"b1"}}],"timestamp":"2026-01-01T00:00:00.000Z"}`, hdr)
	if r.Status != 200 || r.Body.(map[string]any)["type"] != "message" {
		t.Fatalf("%+v", r)
	}
	m = rec.first(t)
	if m.Content != "Bot do it" || m.IsGroup || !m.WasMentioned || m.Timestamp != "2026-01-01T00:00:00.000Z" || m.ChatID != "cv" {
		t.Fatalf("%+v", m)
	}

	ln, rec := build(t, "line", map[string]any{"inboundSecret": "k"})
	r = webhook(t, ln, `{"events":[{"message":{"id":"7","text":"yo"},"source":{"groupId":"G","userId":"U"},"timestamp":1767225600000},{"message":{"type":"image"}}]}`, hdr)
	if r.Status != 200 || r.Body != "OK" {
		t.Fatalf("%+v", r)
	}
	m = rec.first(t)
	if m.ChatID != "G" || m.Sender != "U" || !m.IsGroup || m.Timestamp != "2026-01-01T00:00:00.000Z" || m.MessageID != "7" {
		t.Fatalf("%+v", m)
	}
	if len(rec.messages) != 1 {
		t.Fatal("image event emitted")
	}
}

func TestBlockedSenderRaisesSuggestions(t *testing.T) {
	rec := &recorder{}
	p, _ := Factories(Deps{Client: http.DefaultClient})["teams"](messaging.Config{Settings: map[string]any{"inboundSecret": "k"}}, rec)
	webhook(t, p, `{"text":"x","from":{"id":"u"},"conversation":{"id":"c","isGroup":false}}`, map[string]string{"x-webhook-token": "k"})
	if len(rec.messages) != 0 || len(rec.blocked) != 1 || rec.blocked[0].Sender != "u" {
		t.Fatalf("%+v %+v", rec.messages, rec.blocked)
	}
}

func TestMatrix(t *testing.T) {
	var mu sync.Mutex
	var sends []string
	var syncs []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer tk" {
			w.WriteHeader(401)
			return
		}
		mu.Lock()
		defer mu.Unlock()
		switch {
		case strings.HasSuffix(r.URL.Path, "/account/whoami"):
			w.Write([]byte(`{"user_id":"@bot:hs"}`))
		case strings.HasSuffix(r.URL.Path, "/sync"):
			syncs = append(syncs, r.URL.RawQuery)
			if len(syncs) == 1 {
				w.Write([]byte(`{"next_batch":"b1","rooms":{"join":{"!r:hs":{"timeline":{"events":[
				 {"type":"m.room.message","sender":"@ann:hs","event_id":"$e1","origin_server_ts":1767225600000,"content":{"body":"@bot:hs hello"}},
				 {"type":"m.room.message","sender":"@bot:hs","event_id":"$e0","content":{"body":"mine"}},
				 {"type":"m.room.member","state_key":"@x:hs","content":{"membership":"join"}}]}}}}}`))
				return
			}
			w.Write([]byte(`{"next_batch":"b2","rooms":{"join":{"!r:hs":{"timeline":{"events":[
			 {"type":"m.room.member","state_key":"@x:hs","origin_server_ts":1767225600000,"content":{"membership":"join","displayname":"X"}}]}}}}}`))
		case r.Method == http.MethodPut:
			b, _ := io.ReadAll(r.Body)
			sends = append(sends, r.URL.EscapedPath()+" "+string(b))
			w.Write([]byte(`{"event_id":"$s"}`))
		}
	}))
	defer srv.Close()
	p, rec := build(t, "matrix", map[string]any{"homeserver": srv.URL + "/", "accessToken": "tk", "pollIntervalMs": 1000.0})
	if err := p.Connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	defer p.Disconnect(context.Background())
	if p.AuthInfo()["username"] != "@bot:hs" {
		t.Fatal(p.AuthInfo())
	}
	m := rec.first(t)
	if m.Content != "hello" || !m.WasMentioned || m.ChatID != "!r:hs" || m.Sender != "@ann:hs" || m.Timestamp != "2026-01-01T00:00:00.000Z" || !m.IsGroup {
		t.Fatalf("%+v", m)
	}
	if _, err := p.SendMessage(context.Background(), "!r:hs", `a "b"`, messaging.SendOptions{}); err != nil {
		t.Fatal(err)
	}
	mu.Lock()
	defer mu.Unlock()
	if len(sends) != 1 || !strings.HasPrefix(sends[0], "/_matrix/client/v3/rooms/!r%3Ahs/send/m.room.message/") || !strings.HasSuffix(sends[0], `{"msgtype":"m.text","body":"a \"b\""}`) {
		t.Fatalf("%v", sends)
	}
	if syncs[0] != "timeout=1000" {
		t.Fatalf("first sync %q", syncs[0])
	}
}

func TestMatrixMembershipOnContinuedSync(t *testing.T) {
	calls := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/whoami") {
			w.Write([]byte(`{"user_id":"@bot:hs"}`))
			return
		}
		calls++
		if r.URL.Query().Get("since") != "s0" {
			t.Errorf("since %q", r.URL.RawQuery)
		}
		w.Write([]byte(`{"next_batch":"s1","rooms":{"join":{"!r:hs":{"timeline":{"events":[{"type":"m.room.member","state_key":"@x:hs","origin_server_ts":1767225600000,"content":{"membership":"join","displayname":"X"}}]}}}}}`))
	}))
	defer srv.Close()
	p, rec := build(t, "matrix", map[string]any{"homeserver": srv.URL, "accessToken": "tk", "since": "s0"})
	if err := p.Connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	defer p.Disconnect(context.Background())
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		rec.mu.Lock()
		n := len(rec.members)
		rec.mu.Unlock()
		if n > 0 {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if len(rec.members) == 0 || rec.members[0].Kind != "member_joined" || rec.members[0].MemberName != "X" || rec.members[0].DMChatID != "" {
		t.Fatalf("%+v", rec.members)
	}
}

func TestSignal(t *testing.T) {
	var sent string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.Method == http.MethodGet && r.URL.EscapedPath() == "/v1/receive/%2B49100":
			w.Write([]byte(`[{"envelope":{"sourceNumber":"+49200","sourceName":"Ann","timestamp":1767225600000,"dataMessage":{"message":"hi","groupInfo":{"groupId":"g=="},"mentions":[{"number":"+49100"}],"quote":{"authorNumber":"+49100"}}}}]`))
		case r.URL.Path == "/v2/send":
			b, _ := io.ReadAll(r.Body)
			sent = string(b)
			w.Write([]byte(`{}`))
		}
	}))
	defer srv.Close()
	p, rec := build(t, "signal", map[string]any{"restUrl": srv.URL, "account": "+49100", "pollEnabled": true})
	if err := p.Connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	defer p.Disconnect(context.Background())
	m := rec.first(t)
	if m.ChatID != "g==" || !m.IsGroup || !m.WasMentioned || !m.RepliedToAgent || m.Sender != "+49200" || m.MessageID != "1767225600000" {
		t.Fatalf("%+v", m)
	}
	if _, err := p.SendMessage(context.Background(), "+49200", "yo", messaging.SendOptions{}); err != nil {
		t.Fatal(err)
	}
	if sent != `{"message":"yo","number":"+49100","recipients":["+49200"]}` {
		t.Fatal(sent)
	}
}

func TestMattermostAndBlueBubblesSend(t *testing.T) {
	var path, auth, body string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		path, auth, body = r.URL.Path, r.Header.Get("Authorization"), string(b)
		if r.URL.Query().Get("guid") != "" {
			path = r.URL.Path + "?guid=" + r.URL.Query().Get("guid") + "&pw=" + r.URL.Query().Get("password") + "&t=" + r.URL.Query().Get("tempGuid")[:0]
		}
		w.Write([]byte(`{}`))
	}))
	defer srv.Close()
	p, _ := build(t, "mattermost", map[string]any{"baseUrl": srv.URL + "/", "token": "mt"})
	if _, err := p.SendMessage(context.Background(), "chan", "m", messaging.SendOptions{}); err != nil {
		t.Fatal(err)
	}
	if path != "/api/v4/posts" || auth != "Bearer mt" || body != `{"channel_id":"chan","message":"m"}` {
		t.Fatal(path, auth, body)
	}
	p, _ = build(t, "imessage", map[string]any{"serverUrl": srv.URL, "password": "pw"})
	if _, err := p.SendMessage(context.Background(), "chat;1", "m", messaging.SendOptions{}); err != nil {
		t.Fatal(err)
	}
	if path != "/api/v1/message/text?guid=chat;1&pw=pw&t=" || body != `{"message":"m"}` {
		t.Fatal(path, body)
	}
}

func TestConnectRequirements(t *testing.T) {
	for name, want := range map[string]string{
		"webchat":    "WebChat requires an outbound URL/token or an inbound secret",
		"matrix":     "Matrix homeserver is required.",
		"signal":     "Signal REST API URL is required.",
		"irc":        "irc server is required.",
		"imessage":   "iMessage server URL is required.",
		"line":       "LINE channel access token or inbound secret is required",
		"mattermost": "Mattermost webhook URL, base URL, or inbound secret is required",
	} {
		p, _ := build(t, name, map[string]any{})
		if err := p.Connect(context.Background()); err == nil || err.Error() != want {
			t.Errorf("%s: %v", name, err)
		}
	}
	p, _ := build(t, "line", map[string]any{})
	if _, ok := p.Connect(context.Background()).(*messaging.ConfigurationRequiredError); !ok {
		t.Error("line should need configuration")
	}
}

func TestIRC(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	lines := make(chan string, 16)
	go func() {
		c, err := ln.Accept()
		if err != nil {
			return
		}
		defer c.Close()
		r := bufio.NewReader(c)
		for i := 0; i < 4; i++ {
			l, _ := r.ReadString('\n')
			lines <- strings.TrimSpace(l)
		}
		io.WriteString(c, "PING :x\r\n:ann!u@h PRIVMSG #chan :neo: hello there\r\n:ann!u@h PRIVMSG neo :private\r\n:neo!u@h PRIVMSG #chan :self\r\n")
		for {
			l, err := r.ReadString('\n')
			if err != nil {
				return
			}
			lines <- strings.TrimSpace(l)
		}
	}()
	host, port, _ := net.SplitHostPort(ln.Addr().String())
	p, rec := build(t, "irc", map[string]any{"server": host, "port": port, "nick": "neo", "password": "pw", "channels": "chan, #two"})
	_ = port
	if err := p.Connect(context.Background()); err == nil {
		t.Log("connected")
	}
	for _, want := range []string{"PASS pw", "NICK neo", "USER neo 0 * :neo", "JOIN #chan"} {
		if got := <-lines; got != want {
			t.Fatalf("got %q want %q", got, want)
		}
	}
	m := rec.first(t)
	if m.Content != "hello there" || !m.WasMentioned || !m.IsGroup || m.ChatID != "#chan" || m.Sender != "ann" {
		t.Fatalf("%+v", m)
	}
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		rec.mu.Lock()
		n := len(rec.messages)
		rec.mu.Unlock()
		if n == 2 {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if len(rec.messages) != 2 || rec.messages[1].IsGroup || rec.messages[1].Content != "private" {
		t.Fatalf("%+v", rec.messages)
	}
	if _, err := p.SendMessage(context.Background(), "#chan", "a\nb", messaging.SendOptions{}); err != nil {
		t.Fatal(err)
	}
	for {
		got := <-lines
		if strings.HasPrefix(got, "PONG") || strings.HasPrefix(got, "JOIN") {
			continue
		}
		if got != "PRIVMSG #chan :a b" {
			t.Fatalf("got %q", got)
		}
		break
	}
	p.Disconnect(context.Background())
}

func TestJSONRoundTripKeepsOrder(t *testing.T) {
	c := &Configurable{base: newBase("x", messaging.Config{Settings: map[string]any{"bodyTemplate": `{ "b" : 1, "a": "{content}" }`}}, &recorder{}, Deps{}), d: defaults{}}
	body, err := c.requestBody("t", "v", "")
	if err != nil {
		t.Fatal(err)
	}
	var v map[string]any
	if json.Unmarshal(body, &v) != nil || v["a"] != "v" {
		t.Fatal(string(body))
	}
}
