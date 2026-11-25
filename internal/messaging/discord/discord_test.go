package discord

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

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/gorilla/websocket"
)

type recorder struct {
	mu      sync.Mutex
	inbound []messaging.Inbound
	events  []string
	blocked []messaging.BlockedSender
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
func (r *recorder) Error(messaging.ErrorInfo)         { r.note("error") }
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

type call struct {
	method, path string
	body         map[string]any
}

// fakeDiscord serves Discord's REST API and a gateway on one server.
type fakeDiscord struct {
	srv          *httptest.Server
	mu           sync.Mutex
	calls        []call
	channels     map[string]map[string]any
	messages     map[string][]map[string]any // by channel, newest first
	events       chan map[string]any
	refuseIntent int // closes the first N identifies carrying the members intent
	identifies   []int
}

func newFakeDiscord(t *testing.T) *fakeDiscord {
	f := &fakeDiscord{
		channels: map[string]map[string]any{
			"C1":    {"id": "C1", "type": 0, "name": "general", "guild_id": "G1"},
			"dm900": {"id": "dm900", "type": 1},
			"dm11":  {"id": "dm11", "type": 1},
		},
		messages: map[string][]map[string]any{},
		events:   make(chan map[string]any, 16),
	}
	f.srv = httptest.NewServer(http.HandlerFunc(f.serve))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fakeDiscord) client() *http.Client {
	target, _ := url.Parse(f.srv.URL)
	return &http.Client{Transport: roundTripper(func(r *http.Request) (*http.Response, error) {
		r.URL.Scheme, r.URL.Host = "http", target.Host
		return http.DefaultTransport.RoundTrip(r)
	})}
}

type roundTripper func(*http.Request) (*http.Response, error)

func (fn roundTripper) RoundTrip(r *http.Request) (*http.Response, error) { return fn(r) }

var upgrader = websocket.Upgrader{}

func (f *fakeDiscord) serve(w http.ResponseWriter, r *http.Request) {
	if strings.HasPrefix(r.URL.Path, "/ws") {
		f.gateway(w, r)
		return
	}
	path := strings.TrimPrefix(r.URL.Path, "/api/v9")
	raw, _ := io.ReadAll(r.Body)
	var body map[string]any
	_ = json.Unmarshal(raw, &body)
	f.mu.Lock()
	f.calls = append(f.calls, call{r.Method, path, body})
	f.mu.Unlock()
	reply := func(v any) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(v)
	}
	parts := strings.Split(strings.Trim(path, "/"), "/")
	switch {
	case path == "/gateway":
		reply(map[string]any{"url": "ws://" + f.srv.Listener.Addr().String() + "/ws"})
	case r.Method == http.MethodPost && path == "/users/@me/channels":
		reply(map[string]any{"id": "dm" + body["recipient_id"].(string), "type": 1})
	case r.Method == http.MethodGet && len(parts) == 2 && parts[0] == "channels":
		if ch, ok := f.channels[parts[1]]; ok {
			reply(ch)
			return
		}
		w.WriteHeader(404)
	case r.Method == http.MethodGet && len(parts) == 3 && parts[2] == "messages":
		reply(f.messages[parts[1]])
	case r.Method == http.MethodGet && len(parts) == 4 && parts[2] == "messages":
		for _, m := range f.messages[parts[1]] {
			if m["id"] == parts[3] {
				reply(m)
				return
			}
		}
		w.WriteHeader(404)
	case r.Method == http.MethodPost && len(parts) == 3 && parts[2] == "messages":
		reply(map[string]any{"id": "M100", "channel_id": parts[1]})
	case r.Method == http.MethodGet && len(parts) == 2 && parts[0] == "guilds":
		reply(map[string]any{"id": parts[1], "name": "Neo Server", "system_channel_id": "C1"})
	case r.Method == http.MethodGet && len(parts) == 4 && parts[0] == "guilds" && parts[2] == "members":
		reply(map[string]any{"user": map[string]any{"id": parts[3], "username": "u"}, "roles": []string{"R7"}})
	case r.Method == http.MethodGet && len(parts) == 2 && parts[0] == "users":
		reply(map[string]any{"id": parts[1], "username": "alice", "global_name": "Alice", "discriminator": "0"})
	default:
		w.WriteHeader(204)
	}
}

func (f *fakeDiscord) gateway(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()
	_ = conn.WriteJSON(map[string]any{"op": 10, "d": map[string]any{"heartbeat_interval": 60000}})
	var identify struct {
		Op int `json:"op"`
		D  struct {
			Intents int `json:"intents"`
		} `json:"d"`
	}
	if err := conn.ReadJSON(&identify); err != nil {
		return
	}
	f.mu.Lock()
	f.identifies = append(f.identifies, identify.D.Intents)
	refuse := identify.D.Intents&2 != 0 && f.refuseIntent > 0
	if refuse {
		f.refuseIntent--
	}
	f.mu.Unlock()
	if refuse {
		_ = conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(4014, "Disallowed intents"))
		return
	}
	_ = conn.WriteJSON(map[string]any{"op": 0, "t": "READY", "s": 1, "d": map[string]any{
		"v": 9, "session_id": "s1", "user": map[string]any{"id": "900", "username": "neobot", "discriminator": "0", "bot": true},
		"guilds": []any{},
	}})
	go func() {
		for {
			if _, _, err := conn.ReadMessage(); err != nil {
				return
			}
		}
	}()
	seq := 1
	for ev := range f.events {
		if ev["t"] == "DROP" {
			return
		}
		seq++
		_ = conn.WriteJSON(map[string]any{"op": 0, "t": ev["t"], "s": seq, "d": ev["d"]})
	}
}

func (f *fakeDiscord) push(kind string, data map[string]any) {
	f.events <- map[string]any{"t": kind, "d": data}
}

func (f *fakeDiscord) called(method, pathPrefix string) []call {
	f.mu.Lock()
	defer f.mu.Unlock()
	var out []call
	for _, c := range f.calls {
		if c.method == method && strings.HasPrefix(c.path, pathPrefix) {
			out = append(out, c)
		}
	}
	return out
}

func eventually(t *testing.T, what string, cond func() bool) {
	t.Helper()
	for range 300 {
		if cond() {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", what)
}

func openPolicy() messaging.AccessPolicy {
	p := messaging.DefaultAccessPolicy("discord")
	p.DirectPolicy, p.SharedPolicy = "open", "open"
	return p
}

type memoryMedia struct {
	mu    sync.Mutex
	saved []InboundMedia
}

func (m *memoryMedia) SaveInboundMedia(_ context.Context, userID int64, media InboundMedia) (string, error) {
	m.mu.Lock()
	m.saved = append(m.saved, media)
	m.mu.Unlock()
	return "/media/" + media.FilenameBase + "." + media.Extension, nil
}

func connect(t *testing.T, f *fakeDiscord, policy messaging.AccessPolicy, deps Deps) (*Platform, *recorder) {
	t.Helper()
	rec := &recorder{}
	deps.Client = f.client()
	cfg := messaging.Config{UserID: 5, Settings: map[string]any{"token": "tok"}, AccessPolicy: policy}
	p, err := Factory(deps)(cfg, rec)
	if err != nil {
		t.Fatal(err)
	}
	if err := p.Connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = p.Disconnect(context.Background()); close(f.events) })
	return p.(*Platform), rec
}

func TestConnectLifecycle(t *testing.T) {
	f := newFakeDiscord(t)
	p, rec := connect(t, f, openPolicy(), Deps{})
	if p.Status() != "connected" {
		t.Fatalf("status %s", p.Status())
	}
	if info := p.AuthInfo(); info["tag"] != "neobot" || info["id"] != "900" {
		t.Fatalf("auth info %v", info)
	}
	if err := p.Disconnect(context.Background()); err != nil {
		t.Fatal(err)
	}
	if p.Status() != "disconnected" || p.AuthInfo() != nil {
		t.Fatal("not reset")
	}
	if got := strings.Join(rec.events, ","); got != "connected,disconnected" {
		t.Fatalf("events %s", got)
	}
}

func TestConnectWithoutTokenNeedsUser(t *testing.T) {
	p, _ := Factory(Deps{})(messaging.Config{}, &recorder{})
	if _, ok := p.Connect(context.Background()).(*messaging.ConfigurationRequiredError); !ok {
		t.Fatal("expected a configuration error")
	}
}

func TestConnectRetriesWithoutMembersIntent(t *testing.T) {
	f := newFakeDiscord(t)
	f.refuseIntent = 1
	p, _ := connect(t, f, openPolicy(), Deps{})
	if p.Status() != "connected" {
		t.Fatalf("status %s", p.Status())
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if len(f.identifies) != 2 || f.identifies[0]&2 == 0 || f.identifies[1]&2 != 0 {
		t.Fatalf("identify intents %v", f.identifies)
	}
}

func TestGuildMessageWithMentionContextAndReply(t *testing.T) {
	f := newFakeDiscord(t)
	_, rec := connect(t, f, openPolicy(), Deps{})
	author := map[string]any{"id": "11", "username": "alice", "global_name": "Alice", "discriminator": "0"}
	botMsg := map[string]any{"id": "M1", "channel_id": "C1", "content": "earlier", "author": map[string]any{"id": "900", "username": "neobot", "discriminator": "0", "bot": true}, "timestamp": "2023-11-14T22:13:00.000000+00:00", "attachments": []any{}}
	incoming := map[string]any{"id": "M2", "channel_id": "C1", "guild_id": "G1", "content": "<@900>  what is  up", "author": author,
		"member": map[string]any{"nick": "Ally", "roles": []string{"R7"}}, "timestamp": "2023-11-14T22:13:20.123000+00:00",
		"mentions":      []any{map[string]any{"id": "900", "username": "neobot", "discriminator": "0", "bot": true}},
		"mention_roles": []any{}, "attachments": []any{},
		"message_reference": map[string]any{"message_id": "M1", "channel_id": "C1"}, "referenced_message": botMsg}
	f.messages["C1"] = []map[string]any{incoming, botMsg}
	f.push("MESSAGE_CREATE", incoming)
	eventually(t, "message", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.inbound) == 1 })
	got := rec.inbound[0]
	want := messaging.Inbound{
		Platform: "discord", ChatID: "C1", MessageID: "M2", Sender: "11",
		SenderName: "Ally in #general (Neo Server)", SenderDisplayName: "Ally", SenderUsername: "alice", SenderTag: "alice",
		ServerID: "G1", GuildID: "G1", GuildName: "Neo Server", GroupID: "C1", ChannelID: "C1", ChannelName: "general",
		RoleIDs: []string{"R7"}, WasMentioned: true, RepliedToAgent: true, ReplyToMessageID: "M1",
		ReplyTo: &messaging.ReplyRef{FromAgent: true, Content: "earlier"}, Content: "what is up", IsGroup: true,
		Timestamp: "2023-11-14T22:13:20.123Z", BotUsername: "neobot", BotDisplayName: "neobot", BotTag: "neobot",
		ChannelContext: []messaging.ContextEntry{
			{Author: "[bot] neobot <@900>", Content: "earlier", Mine: true},
			{Author: "Ally (alice) <@11>", Content: "<@900>  what is  up"},
		},
	}
	if a, b := jsonOf(got), jsonOf(want); a != b {
		t.Fatalf("inbound:\n got %s\nwant %s", a, b)
	}
}

func TestDirectMessageAndRefusals(t *testing.T) {
	f := newFakeDiscord(t)
	_, rec := connect(t, f, messaging.DefaultAccessPolicy("discord"), Deps{})
	author := map[string]any{"id": "11", "username": "alice", "global_name": "Alice", "discriminator": "0"}
	f.channels["D11"] = map[string]any{"id": "D11", "type": 1}
	bot := map[string]any{"id": "5", "username": "other", "bot": true}
	f.push("MESSAGE_CREATE", map[string]any{"id": "M1", "channel_id": "D11", "content": "beep", "author": bot, "timestamp": "2023-11-14T22:13:20.000000+00:00"})
	f.push("MESSAGE_CREATE", map[string]any{"id": "M2", "channel_id": "D11", "content": "let me in", "author": author, "timestamp": "2023-11-14T22:13:20.000000+00:00"})
	eventually(t, "blocked sender", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.blocked) == 1 })
	b := rec.blocked[0]
	if b.Sender != "11" || b.ChatID != "dm_11" || b.SenderName != "alice" || len(b.Suggestions) == 0 {
		t.Fatalf("blocked %+v", b)
	}
	if len(rec.inbound) != 0 {
		t.Fatal("refused message delivered")
	}
}

func TestDirectMessageDelivered(t *testing.T) {
	f := newFakeDiscord(t)
	_, rec := connect(t, f, openPolicy(), Deps{})
	f.channels["D11"] = map[string]any{"id": "D11", "type": 1}
	f.push("MESSAGE_CREATE", map[string]any{"id": "M2", "channel_id": "D11", "content": "hi", "author": map[string]any{"id": "11", "username": "alice", "global_name": "Alice", "discriminator": "0"},
		"timestamp": "2023-11-14T22:13:20.000000+00:00", "attachments": []map[string]any{{"id": "A1", "url": "https://cdn/x.png", "content_type": "image/png"}}})
	eventually(t, "message", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.inbound) == 1 })
	got := rec.inbound[0]
	if got.ChatID != "dm_11" || got.IsGroup || got.SenderName != "Alice" || got.SenderDisplayName != "Alice" || got.Content != "hi\n[Attachment: https://cdn/x.png]" || got.ChannelContext != nil || got.GroupID != "" {
		t.Fatalf("dm %s", jsonOf(got))
	}
}

func TestAudioAttachmentIsStored(t *testing.T) {
	audio := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("OGGDATA")) }))
	defer audio.Close()
	f := newFakeDiscord(t)
	media := &memoryMedia{}
	_, rec := connect(t, f, openPolicy(), Deps{Media: media, Download: audio.Client()})
	f.channels["D11"] = map[string]any{"id": "D11", "type": 1}
	f.push("MESSAGE_CREATE", map[string]any{"id": "M2", "channel_id": "D11", "content": "", "flags": 8192,
		"author":      map[string]any{"id": "11", "username": "alice", "discriminator": "0"},
		"timestamp":   "2023-11-14T22:13:20.000000+00:00",
		"attachments": []map[string]any{{"id": "A1", "url": audio.URL + "/voice.ogg", "content_type": "audio/ogg; codecs=opus", "duration_secs": 3.5}}})
	eventually(t, "audio message", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.inbound) == 1 })
	got := rec.inbound[0]
	if got.MediaType != "audio" || !strings.HasSuffix(got.LocalMediaPath, ".ogg") || got.Content != "" ||
		got.VoiceNote["source"] != "discord_voice_message" || got.VoiceNote["durationSec"] != 3.5 {
		t.Fatalf("audio %s", jsonOf(got))
	}
	if len(media.saved) != 1 || string(media.saved[0].Content) != "OGGDATA" || media.saved[0].ContentType != "audio/ogg" {
		t.Fatalf("saved %+v", media.saved)
	}
}

func TestReactionsAndMembership(t *testing.T) {
	f := newFakeDiscord(t)
	_, rec := connect(t, f, openPolicy(), Deps{})
	reaction := map[string]any{"user_id": "11", "message_id": "M9", "channel_id": "dm11", "emoji": map[string]any{"name": "🔥"}}
	f.push("MESSAGE_REACTION_ADD", map[string]any{"user_id": "900", "message_id": "M9", "channel_id": "dm11", "emoji": map[string]any{"name": "👍"}})
	f.push("MESSAGE_REACTION_ADD", reaction)
	f.push("GUILD_MEMBER_ADD", map[string]any{"guild_id": "G1", "user": map[string]any{"id": "31", "username": "bo", "global_name": "Bo", "discriminator": "0"}, "roles": []any{}, "joined_at": "2023-11-14T22:13:20.000000+00:00"})
	f.push("GUILD_MEMBER_ADD", map[string]any{"guild_id": "G1", "user": map[string]any{"id": "32", "username": "bot", "bot": true, "discriminator": "0"}, "roles": []any{}})
	eventually(t, "reaction and join", func() bool {
		rec.mu.Lock()
		defer rec.mu.Unlock()
		return len(rec.reacts) == 1 && len(rec.members) == 1
	})
	want := messaging.Reaction{Platform: "discord", ChatID: "dm_11", Sender: "11", SenderName: "Alice", TargetMessageID: "M9", Emoji: "🔥"}
	got := rec.reacts[0]
	if got.Timestamp == "" {
		t.Fatal("no timestamp")
	}
	got.Timestamp = ""
	if got != want {
		t.Fatalf("reaction %+v", got)
	}
	m := rec.members[0]
	want2 := messaging.Membership{Kind: "member_joined", SpaceID: "G1", SpaceName: "Neo Server", ChatID: "C1", MemberID: "31", MemberName: "Bo", DMChatID: "dm_31", OccurredAt: "2023-11-14T22:13:20.000Z"}
	if m != want2 {
		t.Fatalf("membership %+v", m)
	}
}

func TestOutbound(t *testing.T) {
	f := newFakeDiscord(t)
	p, _ := connect(t, f, openPolicy(), Deps{})
	ctx := context.Background()

	res, err := p.SendMessage(ctx, "dm_11", "hello", messaging.SendOptions{})
	if err != nil || !res.Success || res.MessageID != "M100" {
		t.Fatalf("send %+v %v", res, err)
	}
	if posts := f.called("POST", "/channels/dm11/messages"); len(posts) != 1 || posts[0].body["content"] != "hello" {
		t.Fatalf("dm post %+v", posts)
	}
	if _, err := p.SendMessage(ctx, "C1", "to channel", messaging.SendOptions{}); err != nil {
		t.Fatal(err)
	}
	if len(f.called("POST", "/channels/C1/messages")) != 1 {
		t.Fatal("channel post missing")
	}
	f.channels["FORUM"] = map[string]any{"id": "FORUM", "type": 15}
	if _, err := p.SendMessage(ctx, "FORUM", "x", messaging.SendOptions{}); err == nil || !strings.Contains(err.Error(), "not text-based") {
		t.Fatalf("forum send: %v", err)
	}

	_ = p.SendTyping(ctx, "dm_11", false)
	_ = p.SendTyping(ctx, "C1", true)
	if typing := f.called("POST", "/channels/"); len(typing) < 3 {
		t.Fatal("expected posts")
	}
	if got := f.called("POST", "/channels/C1/typing"); len(got) != 1 {
		t.Fatalf("typing %v", got)
	}
	if got := f.called("POST", "/channels/dm11/typing"); len(got) != 0 {
		t.Fatal("typing=false must not call Discord")
	}

	f.messages["C1"] = []map[string]any{{"id": "M5", "channel_id": "C1", "content": "x", "author": map[string]any{"id": "11", "username": "a"}}}
	if err := p.SendReaction(ctx, "C1", "M5", "👍"); err != nil {
		t.Fatal(err)
	}
	if got := f.called("PUT", "/channels/C1/messages/M5/reactions/"); len(got) != 1 {
		t.Fatalf("reaction %v", got)
	}
}

func TestApprovalPromptAndAnswer(t *testing.T) {
	f := newFakeDiscord(t)
	p, rec := connect(t, f, openPolicy(), Deps{})
	ctx := context.Background()
	prompt := messaging.ApprovalPrompt{
		Title: "Neo needs your OK", Action: "Run a command", Detail: "echo `x`", Reason: "because", Note: "Answer within 5 minutes",
		Options: []messaging.ApprovalOption{
			{ID: "allow", Label: "✅ Allow", Emoji: "✅", Decision: "approved", Scope: "once"},
			{ID: "deny", Label: "🚫 Deny", Emoji: "🚫", Decision: "denied", Scope: "once"},
		},
	}
	ref, err := p.SendApprovalPrompt(ctx, "dm_11", prompt)
	if err != nil || ref.PromptID != "M100" {
		t.Fatalf("prompt %+v %v", ref, err)
	}
	post := f.called("POST", "/channels/dm11/messages")[0].body
	wantText := "🔐 **Neo needs your OK**\nRun a command\n```\necho ˋxˋ\n```\n> because\n\n✅ Allow   ·   🚫 Deny\n-# Answer within 5 minutes"
	if post["content"] != wantText {
		t.Fatalf("content %q", post["content"])
	}
	if mentions := post["allowed_mentions"].(map[string]any); len(mentions["parse"].([]any)) != 0 {
		t.Fatalf("mentions %v", mentions)
	}
	if got := f.called("PUT", "/channels/dm11/messages/M100/reactions/"); len(got) != 2 {
		t.Fatalf("reactions %v", got)
	}

	f.push("MESSAGE_REACTION_ADD", map[string]any{"user_id": "11", "message_id": "M100", "channel_id": "dm11", "emoji": map[string]any{"name": "🚫"}})
	f.push("MESSAGE_REACTION_ADD", map[string]any{"user_id": "11", "message_id": "M100", "channel_id": "dm11", "emoji": map[string]any{"name": "🎉"}})
	eventually(t, "approval answer", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.answers) == 1 })
	a := rec.answers[0]
	if a.ChatID != "dm_11" || a.PromptID != "M100" || a.ChoiceID != "deny" || a.Actor.Sender != "11" || a.Actor.SenderName != "Alice" || a.Actor.IsGroup {
		t.Fatalf("answer %+v", a)
	}
	time.Sleep(50 * time.Millisecond)
	if len(rec.reacts) != 0 || len(rec.answers) != 1 {
		t.Fatal("prompt reactions leaked into other events")
	}

	if err := p.DeleteApprovalPrompt(ctx, "dm_11", "M100"); err != nil {
		t.Fatal(err)
	}
	if len(f.called("DELETE", "/channels/dm11/messages/M100")) != 1 {
		t.Fatal("prompt not deleted")
	}
}

func TestGroupApprovalAnswerCarriesRoles(t *testing.T) {
	f := newFakeDiscord(t)
	p, rec := connect(t, f, openPolicy(), Deps{})
	prompt := messaging.ApprovalPrompt{Title: "t", Action: "a", Note: "n", Options: []messaging.ApprovalOption{{ID: "allow", Label: "Allow", Emoji: "✅"}}}
	if _, err := p.SendApprovalPrompt(context.Background(), "C1", prompt); err != nil {
		t.Fatal(err)
	}
	f.push("MESSAGE_REACTION_ADD", map[string]any{"user_id": "11", "message_id": "M100", "channel_id": "C1", "guild_id": "G1", "emoji": map[string]any{"name": "✅"}})
	eventually(t, "answer", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.answers) == 1 })
	a := rec.answers[0]
	roles := a.Actor.RoleIDs
	if a.ChatID != "C1" || !a.Actor.IsGroup || a.Actor.GroupID != "C1" || a.Actor.GuildID != "G1" || len(roles) != 1 || roles[0] != "R7" {
		t.Fatalf("answer %+v", a)
	}
}

func jsonOf(v any) string { b, _ := json.Marshal(v); return string(b) }

func TestGatewayDropReconnects(t *testing.T) {
	f := newFakeDiscord(t)
	p, rec := connect(t, f, openPolicy(), Deps{})
	f.events <- map[string]any{"t": "DROP"}
	eventually(t, "disconnect report", func() bool { rec.mu.Lock(); defer rec.mu.Unlock(); return len(rec.events) >= 2 })
	if rec.events[1] != "disconnected" {
		t.Fatalf("events %v", rec.events)
	}
	eventually(t, "reconnect", func() bool { return p.Status() == "connected" })
	rec.mu.Lock()
	defer rec.mu.Unlock()
	if got := strings.Join(rec.events, ","); got != "connected,disconnected,connected" {
		t.Fatalf("events %s", got)
	}
}
