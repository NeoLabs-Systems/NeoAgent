package telegram

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

type recorder struct {
	mu      sync.Mutex
	inbound []messaging.Inbound
	events  []string
	blocked []messaging.BlockedSender
	errs    []messaging.ErrorInfo
	reacts  []messaging.Reaction
	members []messaging.Membership
	answers []messaging.ApprovalResponse
}

func (r *recorder) note(s string) { r.mu.Lock(); r.events = append(r.events, s); r.mu.Unlock() }
func (r *recorder) Message(m messaging.Inbound) {
	r.mu.Lock()
	r.inbound = append(r.inbound, m)
	r.mu.Unlock()
}
func (r *recorder) QR(string)                         { r.note("qr") }
func (r *recorder) Connected()                        { r.note("connected") }
func (r *recorder) Disconnected(messaging.Disconnect) { r.note("disconnected") }
func (r *recorder) LoggedOut()                        { r.note("logged_out") }
func (r *recorder) Error(e messaging.ErrorInfo) {
	r.mu.Lock()
	r.errs = append(r.errs, e)
	r.mu.Unlock()
}
func (r *recorder) BlockedSender(b messaging.BlockedSender) {
	r.mu.Lock()
	r.blocked = append(r.blocked, b)
	r.mu.Unlock()
}
func (r *recorder) ApprovalResponse(a messaging.ApprovalResponse) {
	r.mu.Lock()
	r.answers = append(r.answers, a)
	r.mu.Unlock()
}
func (r *recorder) Reaction(x messaging.Reaction) {
	r.mu.Lock()
	r.reacts = append(r.reacts, x)
	r.mu.Unlock()
}
func (r *recorder) Membership(m messaging.Membership) {
	r.mu.Lock()
	r.members = append(r.members, m)
	r.mu.Unlock()
}

// fakeAPI is a Telegram Bot API that serves queued updates once and records
// every other call.
type fakeAPI struct {
	srv     *httptest.Server
	mu      sync.Mutex
	updates []map[string]any
	calls   []call
	meCode  int
}

type call struct {
	method string
	body   map[string]any
}

func newFakeAPI(t *testing.T) *fakeAPI {
	f := &fakeAPI{}
	f.srv = httptest.NewServer(http.HandlerFunc(f.serve))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fakeAPI) serve(w http.ResponseWriter, r *http.Request) {
	method := r.URL.Path[strings.LastIndex(r.URL.Path, "/")+1:]
	body := map[string]any{}
	if err := r.ParseMultipartForm(1 << 20); err == nil {
		for k, v := range r.MultipartForm.Value {
			body[k] = v[0]
		}
		if markup, ok := body["reply_markup"].(string); ok {
			var decoded any
			_ = json.Unmarshal([]byte(markup), &decoded)
			body["reply_markup"] = decoded
		}
	}
	reply := func(result any) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{"ok": true, "result": result})
	}
	switch method {
	case "getMe":
		if f.meCode != 0 {
			w.WriteHeader(f.meCode)
			_, _ = w.Write([]byte(`{"ok":false,"error_code":401,"description":"Unauthorized"}`))
			return
		}
		reply(map[string]any{"id": 777, "is_bot": true, "first_name": "Neo", "username": "NeoBot"})
	case "getUpdates":
		f.mu.Lock()
		updates := f.updates
		f.updates = nil
		f.mu.Unlock()
		if updates == nil {
			time.Sleep(50 * time.Millisecond)
			updates = []map[string]any{}
		}
		reply(updates)
	case "sendMessage":
		f.record(method, body)
		reply(map[string]any{"message_id": 4242, "date": 1, "chat": map[string]any{"id": 1, "type": "private"}})
	default:
		f.record(method, body)
		reply(true)
	}
}

func (f *fakeAPI) record(method string, body map[string]any) {
	f.mu.Lock()
	f.calls = append(f.calls, call{method, body})
	f.mu.Unlock()
}

func (f *fakeAPI) queue(update map[string]any) {
	f.mu.Lock()
	f.updates = append(f.updates, update)
	f.mu.Unlock()
}

func (f *fakeAPI) called(method string) []map[string]any {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []map[string]any
	for _, c := range f.calls {
		if c.method == method {
			out = append(out, c.body)
		}
	}
	return out
}

func eventually(t *testing.T, what string, cond func() bool) {
	t.Helper()
	for range 200 {
		if cond() {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", what)
}

func openPolicy() messaging.AccessPolicy {
	p := messaging.DefaultAccessPolicy("telegram")
	p.DirectPolicy, p.SharedPolicy = "open", "open"
	return p
}

func connect(t *testing.T, f *fakeAPI, policy messaging.AccessPolicy) (*Platform, *recorder) {
	t.Helper()
	rec := &recorder{}
	cfg := messaging.Config{Settings: map[string]any{"botToken": "123:abc"}, AccessPolicy: policy}
	p, err := Factory(Deps{APIBase: f.srv.URL})(cfg, rec)
	if err != nil {
		t.Fatal(err)
	}
	if err := p.Connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = p.Disconnect(context.Background()) })
	return p.(*Platform), rec
}

func TestConnectLifecycle(t *testing.T) {
	f := newFakeAPI(t)
	p, rec := connect(t, f, openPolicy())
	if p.Status() != "connected" {
		t.Fatalf("status %s", p.Status())
	}
	info := p.AuthInfo()
	if info["username"] != "NeoBot" || info["id"] != int64(777) {
		t.Fatalf("auth info %v", info)
	}
	if err := p.Disconnect(context.Background()); err != nil {
		t.Fatal(err)
	}
	if p.Status() != "disconnected" || p.AuthInfo() != nil {
		t.Fatalf("not reset: %s", p.Status())
	}
	if got := strings.Join(rec.events, ","); got != "connected,disconnected" {
		t.Fatalf("events %s", got)
	}
	if _, err := p.SendMessage(context.Background(), "1", "x", messaging.SendOptions{}); err == nil {
		t.Fatal("send after disconnect succeeded")
	}
}

func TestConnectWithoutTokenNeedsUser(t *testing.T) {
	p, _ := Factory(Deps{})(messaging.Config{}, &recorder{})
	var need *messaging.ConfigurationRequiredError
	if err := p.Connect(context.Background()); !asConfigErr(err, &need) {
		t.Fatalf("got %v", err)
	}
}

func asConfigErr(err error, target **messaging.ConfigurationRequiredError) bool {
	e, ok := err.(*messaging.ConfigurationRequiredError)
	*target = e
	return ok
}

func TestConnectRejectedToken(t *testing.T) {
	f := newFakeAPI(t)
	f.meCode = 401
	rec := &recorder{}
	p, _ := Factory(Deps{APIBase: f.srv.URL})(messaging.Config{Settings: map[string]any{"botToken": "123:bad"}}, rec)
	if err := p.Connect(context.Background()); err == nil {
		t.Fatal("expected login failure")
	}
	if p.Status() != "error" {
		t.Fatalf("status %s", p.Status())
	}
}

func message(id int, chat map[string]any, from map[string]any, extra map[string]any) map[string]any {
	m := map[string]any{"message_id": id, "date": 1700000000, "chat": chat, "from": from}
	for k, v := range extra {
		m[k] = v
	}
	return map[string]any{"update_id": id, "message": m}
}

var (
	alice   = map[string]any{"id": 11, "is_bot": false, "first_name": "Alice", "last_name": "Lee", "username": "alice"}
	private = map[string]any{"id": 11, "type": "private"}
	group   = map[string]any{"id": -100, "type": "supergroup", "title": "Team"}
)

func TestInboundPrivateAndGroup(t *testing.T) {
	f := newFakeAPI(t)
	_, rec := connect(t, f, openPolicy())
	f.queue(message(1, private, alice, map[string]any{"text": "hello"}))
	eventually(t, "private message", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.inbound) == 1 })
	want := messaging.Inbound{
		Platform: "telegram", ChatID: "dm_11", MessageID: "1", Sender: "11", SenderName: "Alice Lee",
		SenderDisplayName: "Alice Lee", SenderUsername: "@alice", SenderTag: "@alice",
		Content: "hello", Timestamp: "2023-11-14T22:13:20.000Z", BotUsername: "NeoBot", BotDisplayName: "Neo", BotTag: "@NeoBot",
	}
	if got := rec.inbound[0]; !equalJSON(got, want) {
		t.Fatalf("private:\n got %s\nwant %s", jsonOf(got), jsonOf(want))
	}

	text := "@NeoBot  what is up"
	entities := []map[string]any{{"type": "mention", "offset": 0, "length": 7}}
	reply := map[string]any{"message_id": 5, "date": 1, "chat": group, "from": map[string]any{"id": 777, "is_bot": true, "first_name": "Neo"}, "text": "earlier"}
	f.queue(message(2, group, alice, map[string]any{"text": text, "entities": entities, "reply_to_message": reply}))
	eventually(t, "group message", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.inbound) == 2 })
	got := rec.inbound[1]
	if got.ChatID != "-100" || got.GroupID != "-100" || got.Content != "what is up" || !got.WasMentioned || !got.RepliedToAgent ||
		got.SenderName != "Alice Lee in Team" || got.ChannelName != "Team" || got.GroupName != "Team" || got.ReplyToMessageID != "5" {
		t.Fatalf("group: %s", jsonOf(got))
	}
	if got.ReplyTo == nil || !got.ReplyTo.FromAgent || got.ReplyTo.Sender != nil || got.ReplyTo.Content != "earlier" {
		t.Fatalf("reply %+v", got.ReplyTo)
	}
	if len(got.ChannelContext) != 1 || got.ChannelContext[0].Author != "Alice Lee" || got.ChannelContext[0].Mine {
		t.Fatalf("context %+v", got.ChannelContext)
	}
}

func TestPlaceholdersAndEmptyMessages(t *testing.T) {
	f := newFakeAPI(t)
	_, rec := connect(t, f, openPolicy())
	f.queue(message(1, private, alice, map[string]any{"photo": []map[string]any{{"file_id": "x"}}}))
	f.queue(message(2, private, alice, map[string]any{"document": map[string]any{"file_id": "d"}}))
	f.queue(message(3, private, alice, map[string]any{"sticker": map[string]any{"file_id": "s"}}))
	f.queue(message(4, private, alice, map[string]any{"text": "end"}))
	eventually(t, "messages", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.inbound) == 3 })
	contents := []string{}
	for _, m := range rec.inbound {
		contents = append(contents, m.Content)
	}
	got := strings.Join(contents, "|")
	if !(strings.Contains(got, "[photo]") && strings.Contains(got, "[document: file]") && strings.Contains(got, "end")) || strings.Contains(got, "sticker") {
		t.Fatalf("contents %s", got)
	}
}

func TestBotsAreIgnoredAndRefusalReportsBlockedSender(t *testing.T) {
	f := newFakeAPI(t)
	_, rec := connect(t, f, messaging.DefaultAccessPolicy("telegram"))
	f.queue(message(1, private, map[string]any{"id": 5, "is_bot": true, "first_name": "B"}, map[string]any{"text": "beep"}))
	f.queue(message(2, private, alice, map[string]any{"text": "let me in"}))
	eventually(t, "blocked sender", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.blocked) == 1 })
	b := rec.blocked[0]
	if b.Sender != "11" || b.ChatID != "dm_11" || b.SenderName != "Alice Lee" || len(b.Suggestions) == 0 {
		t.Fatalf("blocked %+v", b)
	}
	if len(rec.inbound) != 0 {
		t.Fatal("refused message was delivered")
	}
}

func TestGateSuppressesSeenTargets(t *testing.T) {
	f := newFakeAPI(t)
	rec := &recorder{}
	cfg := messaging.Config{
		Settings: map[string]any{"botToken": "123:abc"},
		AccessGate: func(messaging.AccessContext) messaging.AccessDecision {
			return messaging.AccessDecision{Reason: "unlinked"}
		},
	}
	p, _ := Factory(Deps{APIBase: f.srv.URL})(cfg, rec)
	if err := p.Connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	defer p.Disconnect(context.Background())
	f.queue(message(1, private, alice, map[string]any{"text": "hi"}))
	time.Sleep(300 * time.Millisecond)
	targets, _ := p.(*Platform).ListAccessTargets(context.Background())
	if len(targets) != 0 || len(rec.blocked) != 0 || len(rec.inbound) != 0 {
		t.Fatalf("gate leaked: %v %v %v", targets, rec.blocked, rec.inbound)
	}
}

func TestAccessTargets(t *testing.T) {
	f := newFakeAPI(t)
	p, rec := connect(t, f, openPolicy())
	f.queue(message(1, group, alice, map[string]any{"text": "hi"}))
	eventually(t, "message", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.inbound) == 1 })
	targets, _ := p.ListAccessTargets(context.Background())
	want := []messaging.AccessTarget{
		{Source: "live", Bucket: "directRules", Scope: "user", Value: "11", Label: "Alice Lee", Subtitle: "Telegram user"},
		{Source: "live", Bucket: "sharedSpaceRules", Scope: "group", Value: "-100", Label: "Team", Subtitle: "Telegram group"},
	}
	if !equalJSON(targets, want) {
		t.Fatalf("targets %s", jsonOf(targets))
	}
}

func TestMembership(t *testing.T) {
	f := newFakeAPI(t)
	_, rec := connect(t, f, openPolicy())
	joined := []map[string]any{{"id": 31, "is_bot": false, "first_name": "Bo"}, {"id": 32, "is_bot": true, "first_name": "Bot"}}
	f.queue(map[string]any{"update_id": 1, "message": map[string]any{"message_id": 1, "date": 1700000000, "chat": group, "new_chat_members": joined}})
	left := map[string]any{"id": 31, "is_bot": false, "first_name": "Bo", "username": "bo"}
	f.queue(map[string]any{"update_id": 2, "message": map[string]any{"message_id": 2, "date": 1700000000, "chat": group, "left_chat_member": left}})
	eventually(t, "membership", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.members) == 2 })
	members := append([]messaging.Membership(nil), rec.members...)
	if members[0].Kind == "member_left" {
		members[0], members[1] = members[1], members[0]
	}
	if m := members[0]; m.Kind != "member_joined" || m.SpaceID != "-100" || m.SpaceName != "Team" || m.MemberID != "31" || m.MemberName != "Bo" || m.DMChatID != "dm_31" || m.OccurredAt != "2023-11-14T22:13:20.000Z" {
		t.Fatalf("join %+v", m)
	}
	if m := members[1]; m.Kind != "member_left" {
		t.Fatalf("leave %+v", m)
	}
}

func TestReactions(t *testing.T) {
	f := newFakeAPI(t)
	_, rec := connect(t, f, openPolicy())
	reaction := func(id int, chat map[string]any, now []map[string]any) map[string]any {
		return map[string]any{"update_id": id, "message_reaction": map[string]any{
			"chat": chat, "message_id": 9, "user": alice, "date": 1700000000, "old_reaction": []any{}, "new_reaction": now}}
	}
	f.queue(reaction(1, group, []map[string]any{{"type": "emoji", "emoji": "👍"}}))
	f.queue(reaction(2, private, []map[string]any{}))
	f.queue(reaction(3, private, []map[string]any{{"type": "emoji", "emoji": "🔥"}}))
	eventually(t, "reaction", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.reacts) == 1 })
	want := messaging.Reaction{Platform: "telegram", ChatID: "dm_11", Sender: "11", SenderName: "Alice Lee", TargetMessageID: "9", Emoji: "🔥", Timestamp: "2023-11-14T22:13:20.000Z"}
	if rec.reacts[0] != want {
		t.Fatalf("reaction %+v", rec.reacts[0])
	}
}

func TestOutbound(t *testing.T) {
	f := newFakeAPI(t)
	p, _ := connect(t, f, openPolicy())
	ctx := context.Background()

	res, err := p.SendMessage(ctx, "dm_11", "hi there", messaging.SendOptions{})
	if err != nil || !res.Success || res.MessageID != "4242" {
		t.Fatalf("send %+v %v", res, err)
	}
	if sent := f.called("sendMessage"); len(sent) != 1 || sent[0]["chat_id"] != "11" || sent[0]["text"] != "hi there" {
		t.Fatalf("sendMessage %v", sent)
	}
	ctxEntries := p.context.get("11")
	if len(ctxEntries) != 1 || ctxEntries[0].Author != "[bot] NeoBot" || !ctxEntries[0].Mine {
		t.Fatalf("context %+v", ctxEntries)
	}

	if err := p.SendReaction(ctx, "dm_11", "9", "👍"); err != nil {
		t.Fatal(err)
	}
	react := f.called("setMessageReaction")[0]
	if react["chat_id"] != "11" || react["message_id"] != "9" {
		t.Fatalf("reaction call %v", react)
	}

	typer := p
	_ = typer.SendTyping(ctx, "dm_11", false)
	_ = typer.SendTyping(ctx, "-100", true)
	actions := f.called("sendChatAction")
	if len(actions) != 1 || actions[0]["chat_id"] != "-100" || actions[0]["action"] != "typing" {
		t.Fatalf("typing %v", actions)
	}
}

func TestApprovalPromptAndAnswer(t *testing.T) {
	f := newFakeAPI(t)
	p, rec := connect(t, f, openPolicy())
	ctx := context.Background()
	prompt := messaging.ApprovalPrompt{
		Title: "Neo <needs> OK", Action: "Run a command", Detail: "ls & rm", Reason: "because", Note: "Answer within 5 minutes",
		Options: []messaging.ApprovalOption{{ID: "allow", Label: "✅ Allow"}, {ID: "deny", Label: "🚫 Deny"}},
	}
	ref, err := p.SendApprovalPrompt(ctx, "dm_11", prompt)
	if err != nil || ref.PromptID != "4242" {
		t.Fatalf("prompt %+v %v", ref, err)
	}
	body := f.called("sendMessage")[0]
	wantText := "🔐 <b>Neo &lt;needs&gt; OK</b>\n\nRun a command\n<pre>ls &amp; rm</pre>\n<i>because</i>\n\n<i>Answer within 5 minutes</i>"
	if body["text"] != wantText || body["parse_mode"] != "HTML" {
		t.Fatalf("text %q", body["text"])
	}
	rows := body["reply_markup"].(map[string]any)["inline_keyboard"].([]any)
	first := rows[0].([]any)[0].(map[string]any)
	if len(rows) != 2 || first["callback_data"] != "approval:allow" || first["text"] != "✅ Allow" {
		t.Fatalf("keyboard %v", rows)
	}

	f.queue(map[string]any{"update_id": 1, "callback_query": map[string]any{
		"id": "cb1", "from": alice, "data": "approval:deny", "chat_instance": "x",
		"message": map[string]any{"message_id": 4242, "date": 1700000000, "chat": private},
	}})
	eventually(t, "approval answer", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.answers) == 1 })
	a := rec.answers[0]
	if a.ChatID != "dm_11" || a.PromptID != "4242" || a.ChoiceID != "deny" || a.Actor.Sender != "11" || a.Actor.SenderName != "Alice Lee" || a.Actor.SenderUsername != "alice" || a.Actor.IsGroup {
		t.Fatalf("answer %+v", a)
	}
	if len(f.called("answerCallbackQuery")) != 1 {
		t.Fatal("button spinner not answered")
	}

	if err := p.DeleteApprovalPrompt(ctx, "dm_11", "4242"); err != nil {
		t.Fatal(err)
	}
	if del := f.called("deleteMessage")[0]; del["chat_id"] != "11" || del["message_id"] != "4242" {
		t.Fatalf("delete %v", del)
	}
}

func jsonOf(v any) string     { b, _ := json.Marshal(v); return string(b) }
func equalJSON(a, b any) bool { return jsonOf(a) == jsonOf(b) }
