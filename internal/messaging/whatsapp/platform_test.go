package whatsapp

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"go.mau.fi/whatsmeow"
	"go.mau.fi/whatsmeow/proto/waCommon"
	"go.mau.fi/whatsmeow/proto/waE2E"
	"go.mau.fi/whatsmeow/types"
	"go.mau.fi/whatsmeow/types/events"
	"google.golang.org/protobuf/proto"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
)

// --- fakes ------------------------------------------------------------------------

type fakeClient struct {
	mu       sync.Mutex
	paired   bool
	handler  func(any)
	codes    chan qrItem
	jid, lid types.JID
	sent     []sentMessage
	reads    []string
	typing   []bool
	votes    [][]byte
	voteErr  error
	pnForLID map[string]types.JID
	lidForPN map[string]types.JID
	download []byte
	dlErr    error
	closed   bool
	connects int
}

type sentMessage struct {
	to  types.JID
	msg *waE2E.Message
}

func newFake() *fakeClient {
	return &fakeClient{
		paired: true, codes: make(chan qrItem, 4),
		jid: types.NewJID("491111", types.DefaultUserServer),
		lid: types.NewJID("777", types.HiddenUserServer),
	}
}

func (f *fakeClient) AddEventHandler(fn func(any)) { f.handler = fn }
func (f *fakeClient) IsPaired() bool               { return f.paired }
func (f *fakeClient) QRChannel(context.Context) (<-chan qrItem, error) {
	return f.codes, nil
}
func (f *fakeClient) Connect() error               { f.connects++; return nil }
func (f *fakeClient) Disconnect()                  {}
func (f *fakeClient) Logout(context.Context) error { f.paired = false; return nil }
func (f *fakeClient) Own() (types.JID, types.JID)  { return f.jid, f.lid }
func (f *fakeClient) Close() error                 { f.closed = true; return nil }
func (f *fakeClient) BuildPoll(name string, o []string) *waE2E.Message {
	return &waE2E.Message{PollCreationMessage: &waE2E.PollCreationMessage{Name: proto.String(name)}}
}
func (f *fakeClient) BuildReaction(chat, sender types.JID, id, emoji string) *waE2E.Message {
	return &waE2E.Message{ReactionMessage: &waE2E.ReactionMessage{Key: &waCommon.MessageKey{ID: proto.String(id)}, Text: proto.String(emoji)}}
}
func (f *fakeClient) BuildRevoke(chat, sender types.JID, id string) *waE2E.Message {
	return &waE2E.Message{ProtocolMessage: &waE2E.ProtocolMessage{Key: &waCommon.MessageKey{ID: proto.String(id)}}}
}
func (f *fakeClient) Send(_ context.Context, to types.JID, msg *waE2E.Message) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.sent = append(f.sent, sentMessage{to, msg})
	return "SENT" + string(rune('A'+len(f.sent))), nil
}
func (f *fakeClient) Upload(_ context.Context, data []byte, kind mediaKind) (uploaded, error) {
	return uploaded{URL: "u", DirectPath: "d", MediaKey: []byte{1}, Length: uint64(len(data))}, nil
}
func (f *fakeClient) MarkRead(_ context.Context, id string, chat, sender types.JID, _ time.Time) error {
	f.reads = append(f.reads, id+"@"+chat.String()+"/"+sender.String())
	return nil
}
func (f *fakeClient) SetTyping(_ context.Context, _ types.JID, typing bool) error {
	f.typing = append(f.typing, typing)
	return nil
}
func (f *fakeClient) DecryptVote(context.Context, *events.Message) ([][]byte, error) {
	return f.votes, f.voteErr
}
func (f *fakeClient) Download(context.Context, whatsmeow.DownloadableMessage) ([]byte, error) {
	return f.download, f.dlErr
}
func (f *fakeClient) LIDForPN(_ context.Context, pn types.JID) (types.JID, error) {
	return f.lidForPN[pn.User], nil
}
func (f *fakeClient) PNForLID(_ context.Context, lid types.JID) (types.JID, error) {
	return f.pnForLID[lid.User], nil
}
func (f *fakeClient) Groups(context.Context) ([]groupInfo, error) {
	return []groupInfo{{JID: "120363-1@g.us", Name: "Family"}}, nil
}
func (f *fakeClient) Contacts(context.Context) ([]contactInfo, error) {
	return []contactInfo{
		{JID: types.NewJID("491234", types.DefaultUserServer), Name: "Mum"},
		{JID: types.NewJID("55", types.HiddenUserServer), Name: "Lid person"},
	}, nil
}

type recorder struct {
	mu            sync.Mutex
	messages      []messaging.Inbound
	reactions     []messaging.Reaction
	approvals     []messaging.ApprovalResponse
	blocked       []messaging.BlockedSender
	disconnected  []messaging.Disconnect
	qrs           []string
	connected     int
	loggedOut     int
	memberships   []messaging.Membership
	errorsEmitted []messaging.ErrorInfo
}

func (r *recorder) Message(m messaging.Inbound) {
	r.mu.Lock()
	r.messages = append(r.messages, m)
	r.mu.Unlock()
}
func (r *recorder) QR(c string) { r.mu.Lock(); r.qrs = append(r.qrs, c); r.mu.Unlock() }
func (r *recorder) Connected()  { r.mu.Lock(); r.connected++; r.mu.Unlock() }
func (r *recorder) Disconnected(d messaging.Disconnect) {
	r.mu.Lock()
	r.disconnected = append(r.disconnected, d)
	r.mu.Unlock()
}
func (r *recorder) LoggedOut()                  { r.mu.Lock(); r.loggedOut++; r.mu.Unlock() }
func (r *recorder) Error(e messaging.ErrorInfo) { r.errorsEmitted = append(r.errorsEmitted, e) }
func (r *recorder) BlockedSender(b messaging.BlockedSender) {
	r.mu.Lock()
	r.blocked = append(r.blocked, b)
	r.mu.Unlock()
}
func (r *recorder) ApprovalResponse(a messaging.ApprovalResponse) {
	r.mu.Lock()
	r.approvals = append(r.approvals, a)
	r.mu.Unlock()
}
func (r *recorder) Reaction(x messaging.Reaction) {
	r.mu.Lock()
	r.reactions = append(r.reactions, x)
	r.mu.Unlock()
}
func (r *recorder) Membership(m messaging.Membership) {
	r.mu.Lock()
	r.memberships = append(r.memberships, m)
	r.mu.Unlock()
}

type mediaStore struct {
	saved []InboundMedia
	owner int64
}

func (m *mediaStore) SaveInboundMedia(_ context.Context, userID int64, media InboundMedia) (string, error) {
	m.saved = append(m.saved, media)
	m.owner = userID
	return "/media/" + media.FilenameBase + "." + media.Extension, nil
}

type rig struct {
	p     *Platform
	cl    *fakeClient
	ev    *recorder
	media *mediaStore
}

type rigOptions struct {
	selfChat bool
	policy   *messaging.AccessPolicy
	gate     func(messaging.AccessContext) messaging.AccessDecision
}

func newRig(t *testing.T, o rigOptions) *rig {
	t.Helper()
	cl, ev, media := newFake(), &recorder{}, &mediaStore{}
	cfg := messaging.Config{UserID: 7, AgentID: "agent-1", Settings: map[string]any{}, AuthDir: filepath.Join(t.TempDir(), "auth"), AccessGate: o.gate}
	if o.selfChat {
		cfg.Settings["selfChatMode"] = true
	}
	if o.policy != nil {
		cfg.AccessPolicy = *o.policy
	}
	deps := Deps{Media: media, AgentName: func(int64, string) string { return "Neo" },
		open: func(context.Context, string) (waClient, error) { return cl, nil }}
	p := newPlatform(cfg, ev, deps)
	if err := p.Connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = p.Disconnect(context.Background()) })
	cl.handler(&events.Connected{})
	return &rig{p: p, cl: cl, ev: ev, media: media}
}

func allowDirect(numbers ...string) *messaging.AccessPolicy {
	p := messaging.DefaultAccessPolicy("whatsapp")
	for _, n := range numbers {
		p.DirectRules = append(p.DirectRules, messaging.Rule{Scope: "phone_number", Value: n})
	}
	return &p
}

func dm(from string, id string, m *waE2E.Message) *events.Message {
	jid := types.NewJID(from, types.DefaultUserServer)
	return &events.Message{
		Info:    types.MessageInfo{MessageSource: types.MessageSource{Chat: jid, Sender: jid}, ID: id, PushName: "Alice", Timestamp: time.Date(2026, 11, 24, 10, 0, 0, 123e6, time.UTC)},
		Message: m,
	}
}

func text(s string) *waE2E.Message { return &waE2E.Message{Conversation: proto.String(s)} }

// --- address helpers ----------------------------------------------------------------

func TestAddressHelpersMatchNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/jid_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors []struct{ Input, Normalize, JID string }
	if err := json.Unmarshal(raw, &vectors); err != nil {
		t.Fatal(err)
	}
	for _, v := range vectors {
		if got := normalizeID(v.Input); got != v.Normalize {
			t.Errorf("normalizeID(%q) = %q, Node %q", v.Input, got, v.Normalize)
		}
		if got := toJID(v.Input); got != v.JID {
			t.Errorf("toJID(%q) = %q, Node %q", v.Input, got, v.JID)
		}
	}
}

// --- reading messages ---------------------------------------------------------------

func TestReadBody(t *testing.T) {
	doc := func(mime, name, caption string) *waE2E.Message {
		return &waE2E.Message{DocumentMessage: &waE2E.DocumentMessage{Mimetype: proto.String(mime), FileName: proto.String(name), Caption: proto.String(caption)}}
	}
	cases := []struct {
		name                  string
		m                     *waE2E.Message
		content, media, fname string
		voice                 map[string]any
	}{
		{"text", text("hi"), "hi", "", "", nil},
		{"extended", &waE2E.Message{ExtendedTextMessage: &waE2E.ExtendedTextMessage{Text: proto.String("link")}}, "link", "", "", nil},
		{"image without caption", &waE2E.Message{ImageMessage: &waE2E.ImageMessage{}}, "[Image]", "image", "", nil},
		{"video caption", &waE2E.Message{VideoMessage: &waE2E.VideoMessage{Caption: proto.String("look")}}, "look", "video", "", nil},
		{"voice note", &waE2E.Message{AudioMessage: &waE2E.AudioMessage{PTT: proto.Bool(true), Seconds: proto.Uint32(12),
			ContextInfo: &waE2E.ContextInfo{IsForwarded: proto.Bool(true)}}}, "", "audio", "",
			map[string]any{"source": "whatsapp_ptt", "durationSec": float64(12), "forwarded": true}},
		{"audio without duration", &waE2E.Message{AudioMessage: &waE2E.AudioMessage{}}, "", "audio", "",
			map[string]any{"source": "whatsapp_audio", "durationSec": nil, "forwarded": false}},
		{"audio as document", doc("audio/mpeg", "a.mp3", "listen"), "listen", "audio", "", map[string]any{"source": "whatsapp_audio", "durationSec": nil}},
		{"document falls back to the file name", doc("application/pdf", "plan.pdf", ""), "plan.pdf", "document", "plan.pdf", nil},
		{"document caption wins", doc("application/pdf", "plan.pdf", "read this"), "read this", "document", "plan.pdf", nil},
		{"sticker", &waE2E.Message{StickerMessage: &waE2E.StickerMessage{}}, "[Sticker]", "sticker", "", nil},
		{"nothing", &waE2E.Message{}, "", "", "", nil},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			b := readBody(c.m)
			if b.content != c.content || b.mediaType != c.media || b.mediaFileName != c.fname {
				t.Fatalf("got %q %q %q", b.content, b.mediaType, b.mediaFileName)
			}
			got, _ := json.Marshal(b.voiceNote)
			want, _ := json.Marshal(c.voice)
			if string(got) != string(want) {
				t.Fatalf("voice note %s, want %s", got, want)
			}
		})
	}
}

func TestQuotedTextAndUnwrap(t *testing.T) {
	for want, q := range map[string]*waE2E.Message{
		"[Image]":                    {ImageMessage: &waE2E.ImageMessage{}},
		"[Voice message]":            {AudioMessage: &waE2E.AudioMessage{PTT: proto.Bool(true)}},
		"[Audio]":                    {AudioMessage: &waE2E.AudioMessage{}},
		"[Document: a.pdf]":          {DocumentMessage: &waE2E.DocumentMessage{FileName: proto.String("a.pdf")}},
		"[Document]":                 {DocumentMessage: &waE2E.DocumentMessage{}},
		"caption wins over the kind": {ImageMessage: &waE2E.ImageMessage{Caption: proto.String("caption wins over the kind")}},
		"":                           {},
	} {
		if got := quotedText(q); got != want {
			t.Errorf("quotedText = %q, want %q", got, want)
		}
	}
	wrapped := &waE2E.Message{EphemeralMessage: &waE2E.FutureProofMessage{Message: &waE2E.Message{
		ViewOnceMessage: &waE2E.FutureProofMessage{Message: text("inner")}}}}
	if got := unwrap(wrapped).GetConversation(); got != "inner" {
		t.Fatalf("unwrap = %q", got)
	}
}

func TestMediaExtensions(t *testing.T) {
	cases := []struct{ media, name, mime, ext, contentType string }{
		{"image", "", "", "jpg", "image/jpeg"},
		{"video", "", "", "mp4", "video/mp4"},
		{"document", "Report.PDF", "", "pdf", "application/octet-stream"},
		{"document", "noext", "", "bin", "application/octet-stream"},
		{"audio", "", "audio/ogg; codecs=opus", "ogg", "audio/ogg"},
		{"audio", "", "", "ogg", "audio/ogg"},
		{"audio", "", "audio/mpeg", "mp3", "audio/mpeg"},
		{"audio", "", "audio/amr", "wav", "audio/amr"},
	}
	for _, c := range cases {
		if got := mediaExtension(c.media, c.name, c.mime); got != c.ext {
			t.Errorf("extension(%v) = %s, want %s", c, got, c.ext)
		}
		if got := mediaContentType(c.media, c.mime); got != c.contentType {
			t.Errorf("content type(%v) = %s, want %s", c, got, c.contentType)
		}
	}
}

// --- inbound flow ----------------------------------------------------------------------

func TestDirectMessageFromAllowedSender(t *testing.T) {
	r := newRig(t, rigOptions{policy: allowDirect("4912345")})
	r.cl.handler(dm("4912345", "M1", text("hello")))
	if len(r.ev.messages) != 1 {
		t.Fatalf("messages %d, blocked %d", len(r.ev.messages), len(r.ev.blocked))
	}
	m := r.ev.messages[0]
	if m.Platform != "whatsapp" || m.ChatID != "4912345@s.whatsapp.net" || m.Sender != "4912345@s.whatsapp.net" ||
		m.SenderName != "Alice" || m.SenderTag != "4912345" || m.Content != "hello" || m.IsGroup || m.MessageID != "M1" ||
		m.Timestamp != "2026-11-24T10:00:00.123Z" || m.Metadata != nil || m.GroupID != "" {
		t.Fatalf("%+v", m)
	}
	if len(r.cl.reads) != 1 || r.cl.reads[0] != "M1@4912345@s.whatsapp.net/4912345@s.whatsapp.net" {
		t.Fatalf("read receipts %v", r.cl.reads)
	}
}

func TestStrangerIsBlockedWithSuggestion(t *testing.T) {
	r := newRig(t, rigOptions{policy: allowDirect("4912345")})
	r.cl.handler(dm("999", "M1", text("hello")))
	if len(r.ev.messages) != 0 || len(r.ev.blocked) != 1 {
		t.Fatalf("messages %d blocked %d", len(r.ev.messages), len(r.ev.blocked))
	}
	b := r.ev.blocked[0]
	if b.Sender != "999" || b.SenderName != "Alice" || len(b.Suggestions) == 0 || b.Suggestions[0].Rule.Scope != "phone_number" {
		t.Fatalf("%+v", b)
	}
}

func TestSharedAccountGateDecidesAndOwnsMedia(t *testing.T) {
	gate := func(c messaging.AccessContext) messaging.AccessDecision {
		return messaging.AccessDecision{Allowed: c.IsDirect, OwnerUserID: 42}
	}
	r := newRig(t, rigOptions{gate: gate})
	r.cl.download = []byte("png")
	r.cl.handler(dm("4912345", "IMG-1", &waE2E.Message{ImageMessage: &waE2E.ImageMessage{Caption: proto.String("pic")}}))
	if len(r.ev.messages) != 1 || len(r.ev.blocked) != 0 {
		t.Fatalf("messages %d blocked %d", len(r.ev.messages), len(r.ev.blocked))
	}
	m := r.ev.messages[0]
	if r.media.owner != 42 {
		t.Fatalf("media stored for %d, want the linked sender 42", r.media.owner)
	}
	if m.MediaType != "image" || m.Content != "pic" || m.LocalMediaPath == "" || m.MediaError != "" {
		t.Fatalf("%+v", m)
	}
	if r.media.saved[0].Extension != "jpg" || r.media.saved[0].ContentType != "image/jpeg" {
		t.Fatalf("%+v", r.media.saved[0])
	}
}

func TestMediaFailureIsReportedNotFatal(t *testing.T) {
	r := newRig(t, rigOptions{policy: allowDirect("4912345")})
	r.cl.dlErr = errors.New("download failed")
	r.cl.handler(dm("4912345", "V1", &waE2E.Message{VideoMessage: &waE2E.VideoMessage{}}))
	m := r.ev.messages[0]
	if m.LocalMediaPath != "" || m.MediaError != "download failed" || m.Content != "[Video]" || m.VoiceNote != nil {
		t.Fatalf("%+v", m)
	}
}

func TestVoiceNoteDescriptorOnlyWithFile(t *testing.T) {
	r := newRig(t, rigOptions{policy: allowDirect("4912345")})
	r.cl.download = []byte("ogg")
	r.cl.handler(dm("4912345", "A1", &waE2E.Message{AudioMessage: &waE2E.AudioMessage{PTT: proto.Bool(true), Mimetype: proto.String("audio/ogg; codecs=opus")}}))
	m := r.ev.messages[0]
	if m.VoiceNote["source"] != "whatsapp_ptt" || r.media.saved[0].Extension != "ogg" {
		t.Fatalf("%+v %+v", m, r.media.saved)
	}
}

func groupMessage(from, id string, m *waE2E.Message) *events.Message {
	e := dm(from, id, m)
	e.Info.Chat = types.NewJID("120363-1", types.GroupServer)
	e.Info.IsGroup = true
	return e
}

func TestGroupMentionAndReply(t *testing.T) {
	p := messaging.DefaultAccessPolicy("whatsapp")
	p.SharedSpaceRules = []messaging.Rule{{Scope: "group", Value: "120363-1@g.us"}}
	r := newRig(t, rigOptions{policy: &p})

	mention := &waE2E.Message{ExtendedTextMessage: &waE2E.ExtendedTextMessage{Text: proto.String("@777 are you there"),
		ContextInfo: &waE2E.ContextInfo{MentionedJID: []string{"777@lid"}}}}
	r.cl.handler(groupMessage("4912345", "G1", mention))
	reply := &waE2E.Message{ExtendedTextMessage: &waE2E.ExtendedTextMessage{Text: proto.String("yes please"),
		ContextInfo: &waE2E.ContextInfo{StanzaID: proto.String("Q1"), Participant: proto.String("491111:5@s.whatsapp.net"),
			QuotedMessage: &waE2E.Message{ImageMessage: &waE2E.ImageMessage{}}}}}
	r.cl.handler(groupMessage("4912345", "G2", reply))
	plain := groupMessage("4912345", "G3", text("just chatting"))
	r.cl.handler(plain)

	if len(r.ev.messages) != 3 {
		t.Fatalf("messages %d", len(r.ev.messages))
	}
	a, b, c := r.ev.messages[0], r.ev.messages[1], r.ev.messages[2]
	if !a.IsGroup || a.GroupID != "120363-1@g.us" || !a.WasMentioned || a.Sender != "4912345@s.whatsapp.net" {
		t.Fatalf("mention %+v", a)
	}
	if !b.RepliedToAgent || b.ReplyTo == nil || !b.ReplyTo.FromAgent || b.ReplyTo.Content != "[Image]" || b.ReplyToMessageID != "Q1" || !b.WasMentioned {
		t.Fatalf("reply %+v %+v", b, b.ReplyTo)
	}
	if c.WasMentioned || c.RepliedToAgent || c.ReplyTo != nil {
		t.Fatalf("plain %+v", c)
	}
}

func TestGroupSenderResolvedFromLIDMapping(t *testing.T) {
	p := messaging.DefaultAccessPolicy("whatsapp")
	p.SharedSpaceRules = []messaging.Rule{{Scope: "group", Value: "120363-1@g.us"}}
	r := newRig(t, rigOptions{policy: &p})
	r.cl.pnForLID = map[string]types.JID{"55": types.NewJID("491234", types.DefaultUserServer)}
	e := groupMessage("55", "G1", text("hi"))
	e.Info.Sender = types.NewJID("55", types.HiddenUserServer)
	r.cl.handler(e)
	if m := r.ev.messages[0]; m.Sender != "491234@s.whatsapp.net" || m.SenderTag != "491234" {
		t.Fatalf("sender %q tag %q: the phone number wins when known", m.Sender, m.SenderTag)
	}
}

func TestOwnRepliesAreNotReadBack(t *testing.T) {
	r := newRig(t, rigOptions{policy: allowDirect("491111")})
	res, err := r.p.SendMessage(context.Background(), "4912345", "hi", messaging.SendOptions{})
	if err != nil || !res.Success || res.MessageID == "" {
		t.Fatalf("%+v %v", res, err)
	}
	echo := dm("4912345", res.MessageID, text("hi"))
	r.cl.handler(echo)
	own := dm("491111", "X", text("from me"))
	own.Info.IsFromMe = true
	r.cl.handler(own)
	if len(r.ev.messages) != 0 || len(r.ev.blocked) != 0 {
		t.Fatalf("messages %d blocked %d", len(r.ev.messages), len(r.ev.blocked))
	}
}

func TestSelfChatMode(t *testing.T) {
	r := newRig(t, rigOptions{selfChat: true})
	note := func(chat types.JID, id string, at time.Time) *events.Message {
		e := dm("491111", id, text("remember milk"))
		e.Info.Chat, e.Info.IsFromMe, e.Info.Timestamp = chat, true, at
		return e
	}
	own := types.NewJID("491111", types.DefaultUserServer)
	ownLID := types.NewJID("777", types.HiddenUserServer)
	now := time.Now()

	r.cl.handler(note(own, "N-old", now.Add(-time.Hour)))                                                 // backlog from before this connection
	r.cl.handler(note(types.NewJID("4912345", types.DefaultUserServer), "N-other", now.Add(time.Second))) // not the own chat
	r.cl.handler(note(own, "N1", now.Add(time.Second)))
	r.cl.handler(note(ownLID, "N2", now.Add(time.Second))) // the self chat addressed by LID
	if len(r.ev.messages) != 2 {
		t.Fatalf("messages %d", len(r.ev.messages))
	}
	if m := r.ev.messages[0]; m.Metadata["selfChat"] != true || m.MessageID != "N1" || len(r.ev.blocked) != 0 {
		t.Fatalf("%+v blocked %d", m, len(r.ev.blocked))
	}
	if got := r.p.OwnerChatID(); got != "491111@s.whatsapp.net" {
		t.Fatalf("owner chat %q", got)
	}

	// The agent's own labelled reply is not a new note and is recognised when quoted.
	res, _ := r.p.SendMessage(context.Background(), "491111", "done", messaging.SendOptions{})
	echo := note(own, res.MessageID, now.Add(2*time.Second))
	r.cl.handler(echo)
	if len(r.ev.messages) != 2 {
		t.Fatal("own reply read back")
	}
	sent := r.cl.sent[0].msg.GetExtendedTextMessage().GetText()
	if sent != "(Neo): done" {
		t.Fatalf("label: %q", sent)
	}
	quoting := &waE2E.Message{ExtendedTextMessage: &waE2E.ExtendedTextMessage{Text: proto.String("thanks"), ContextInfo: &waE2E.ContextInfo{
		StanzaID: proto.String("S"), Participant: proto.String("491111@s.whatsapp.net"), QuotedMessage: text("(Neo): done")}}}
	other := note(own, "N3", now.Add(3*time.Second))
	other.Message = quoting
	r.cl.handler(other)
	if m := r.ev.messages[2]; !m.RepliedToAgent {
		t.Fatalf("quote of the agent's labelled reply: %+v", m.ReplyTo)
	}
	notLabelled := note(own, "N4", now.Add(4*time.Second))
	notLabelled.Message = &waE2E.Message{ExtendedTextMessage: &waE2E.ExtendedTextMessage{Text: proto.String("re"), ContextInfo: &waE2E.ContextInfo{
		StanzaID: proto.String("S"), Participant: proto.String("491111@s.whatsapp.net"), QuotedMessage: text("my own note")}}}
	r.cl.handler(notLabelled)
	if m := r.ev.messages[3]; m.RepliedToAgent {
		t.Fatal("a quote of the user's own note is not a reply to the agent")
	}
}

func TestSyncTrafficAndEmptyMessagesAreIgnored(t *testing.T) {
	r := newRig(t, rigOptions{policy: allowDirect("4912345")})
	r.cl.handler(dm("4912345", "P", &waE2E.Message{ProtocolMessage: &waE2E.ProtocolMessage{}}))
	r.cl.handler(dm("4912345", "E", &waE2E.Message{}))
	if len(r.ev.messages) != 0 || len(r.ev.blocked) != 0 {
		t.Fatal("ignored traffic produced events")
	}
}

func TestReactionsAreContextOnlyAndPolicyChecked(t *testing.T) {
	r := newRig(t, rigOptions{policy: allowDirect("4912345")})
	react := func(from, emoji string) *events.Message {
		return dm(from, "R-"+from, &waE2E.Message{ReactionMessage: &waE2E.ReactionMessage{Text: proto.String(emoji), Key: &waCommon.MessageKey{ID: proto.String("TARGET")}}})
	}
	r.cl.handler(react("4912345", "👍"))
	r.cl.handler(react("4912345", "")) // removed
	r.cl.handler(react("999", "👍"))    // stranger: quiet
	if len(r.ev.reactions) != 1 || len(r.ev.blocked) != 0 || len(r.ev.messages) != 0 {
		t.Fatalf("reactions %d blocked %d messages %d", len(r.ev.reactions), len(r.ev.blocked), len(r.ev.messages))
	}
	if x := r.ev.reactions[0]; x.TargetMessageID != "TARGET" || x.Emoji != "👍" || x.ChatID != "4912345@s.whatsapp.net" {
		t.Fatalf("%+v", x)
	}
}

func TestGroupMembershipSkipsOwnAccount(t *testing.T) {
	r := newRig(t, rigOptions{})
	r.cl.handler(&events.GroupInfo{JID: types.NewJID("120363-1", types.GroupServer),
		Join:  []types.JID{types.NewJID("4912345", types.DefaultUserServer), types.NewJID("491111", types.DefaultUserServer)},
		Leave: []types.JID{types.NewJID("777", types.HiddenUserServer), types.NewJID("55", types.DefaultUserServer)}})
	if len(r.ev.memberships) != 2 {
		t.Fatalf("%+v", r.ev.memberships)
	}
	if m := r.ev.memberships[0]; m.Kind != "member_joined" || m.MemberName != "4912345" || m.DMChatID != "4912345@s.whatsapp.net" || m.SpaceID != "120363-1@g.us" {
		t.Fatalf("%+v", m)
	}
	if r.ev.memberships[1].Kind != "member_left" {
		t.Fatalf("%+v", r.ev.memberships[1])
	}
}

// --- approvals ---------------------------------------------------------------------------

func TestApprovalPollVote(t *testing.T) {
	r := newRig(t, rigOptions{policy: allowDirect("4912345")})
	prompt := messaging.ApprovalPrompt{Text: "Allow?", Options: []messaging.ApprovalOption{
		{ID: "allow", Label: "✅ Allow", Decision: "approved", Scope: "once"},
		{ID: "deny", Label: "🚫 Deny", Decision: "denied", Scope: "once"},
	}}
	ref, err := r.p.SendApprovalPrompt(context.Background(), "4912345@s.whatsapp.net", prompt)
	if err != nil || ref.PromptID == "" {
		t.Fatalf("%+v %v", ref, err)
	}
	poll := r.cl.sent[0].msg.GetPollCreationMessage()
	if poll.GetName() != "Allow?" {
		t.Fatalf("poll %v", poll)
	}
	vote := func(from string) *events.Message {
		return dm(from, "VOTE-"+from, &waE2E.Message{PollUpdateMessage: &waE2E.PollUpdateMessage{
			PollCreationMessageKey: &waCommon.MessageKey{ID: proto.String(ref.PromptID)}}})
	}
	hash := sha256.Sum256([]byte("🚫 Deny"))
	r.cl.votes = [][]byte{hash[:]}
	r.cl.handler(vote("4912345"))
	if len(r.ev.approvals) != 1 {
		t.Fatalf("approvals %d", len(r.ev.approvals))
	}
	a := r.ev.approvals[0]
	if a.ChoiceID != "deny" || a.PromptID != ref.PromptID || a.ChatID != "4912345@s.whatsapp.net" || a.Actor.Sender != "4912345@s.whatsapp.net" || a.Actor.IsAccountHolder {
		t.Fatalf("%+v", a)
	}
	r.cl.votes = nil // vote taken back
	r.cl.handler(vote("4912345"))
	r.cl.voteErr = errors.New("cannot decrypt")
	r.cl.handler(vote("4912345"))
	if len(r.ev.approvals) != 1 || len(r.ev.messages) != 0 {
		t.Fatal("withdrawn or unreadable votes must not answer")
	}

	if err := r.p.DeleteApprovalPrompt(context.Background(), "4912345@s.whatsapp.net", ref.PromptID); err != nil {
		t.Fatal(err)
	}
	if got := r.cl.sent[len(r.cl.sent)-1].msg.GetProtocolMessage().GetKey().GetID(); got != ref.PromptID {
		t.Fatalf("revoked %q", got)
	}
	r.cl.votes, r.cl.voteErr = [][]byte{hash[:]}, nil
	r.cl.handler(vote("4912345"))
	if len(r.ev.approvals) != 1 {
		t.Fatal("a deleted prompt is no longer answerable")
	}
}

func TestSelfChatApprovalOnlyFromTheOwnersOwnChat(t *testing.T) {
	r := newRig(t, rigOptions{selfChat: true})
	ref, _ := r.p.SendApprovalPrompt(context.Background(), "491111@s.whatsapp.net", messaging.ApprovalPrompt{Text: "?", Options: []messaging.ApprovalOption{{ID: "allow", Label: "Allow"}}})
	hash := sha256.Sum256([]byte("Allow"))
	r.cl.votes = [][]byte{hash[:]}
	vote := func(chat string, fromMe bool) *events.Message {
		e := dm("491111", "V", &waE2E.Message{PollUpdateMessage: &waE2E.PollUpdateMessage{PollCreationMessageKey: &waCommon.MessageKey{ID: proto.String(ref.PromptID)}}})
		e.Info.Chat = types.NewJID(chat, types.DefaultUserServer)
		e.Info.IsFromMe = fromMe
		return e
	}
	r.cl.handler(vote("4912345", true))
	r.cl.handler(vote("491111", false))
	if len(r.ev.approvals) != 0 {
		t.Fatal("answered from the wrong place")
	}
	r.cl.handler(vote("491111", true))
	if len(r.ev.approvals) != 1 || !r.ev.approvals[0].Actor.IsAccountHolder || r.ev.approvals[0].Actor.Metadata["selfChat"] != true {
		t.Fatalf("%+v", r.ev.approvals)
	}
}

func TestGatedAccountIgnoresAccountHolderVotes(t *testing.T) {
	gate := func(messaging.AccessContext) messaging.AccessDecision { return messaging.AccessDecision{Allowed: true} }
	r := newRig(t, rigOptions{gate: gate})
	ref, _ := r.p.SendApprovalPrompt(context.Background(), "4912345@s.whatsapp.net", messaging.ApprovalPrompt{Text: "?", Options: []messaging.ApprovalOption{{ID: "allow", Label: "Allow"}}})
	hash := sha256.Sum256([]byte("Allow"))
	r.cl.votes = [][]byte{hash[:]}
	e := dm("4912345", "V", &waE2E.Message{PollUpdateMessage: &waE2E.PollUpdateMessage{PollCreationMessageKey: &waCommon.MessageKey{ID: proto.String(ref.PromptID)}}})
	e.Info.IsFromMe = true
	r.cl.handler(e)
	if len(r.ev.approvals) != 0 {
		t.Fatal("the shared account's holder is not the linked user")
	}
}

func TestPollNameIsCutAtTheLimit(t *testing.T) {
	long := ""
	for range 300 {
		long += "é"
	}
	if got := []rune(truncateUTF16(long, pollNameLimit)); len(got) != pollNameLimit {
		t.Fatalf("%d", len(got))
	}
	if got := truncateUTF16("a😀b", 2); got != "a" {
		t.Fatalf("surrogate pair split: %q", got)
	}
}

// --- outbound ----------------------------------------------------------------------------

func TestSendMessageRules(t *testing.T) {
	r := newRig(t, rigOptions{})
	ctx := context.Background()
	if _, err := r.p.SendMessage(ctx, "", "x", messaging.SendOptions{}); err == nil || err.Error() != "Invalid WhatsApp recipient" {
		t.Fatalf("%v", err)
	}
	if _, err := r.p.SendMessage(ctx, "+49 1234", "hello", messaging.SendOptions{}); err != nil {
		t.Fatal(err)
	}
	if to := r.cl.sent[0].to.String(); to != "491234@s.whatsapp.net" {
		t.Fatalf("to %s", to)
	}
	if text := r.cl.sent[0].msg.GetExtendedTextMessage().GetText(); text != "hello" {
		t.Fatalf("no label outside self-chat mode: %q", text)
	}

	_ = r.p.Disconnect(ctx)
	if _, err := r.p.SendMessage(ctx, "4912", "x", messaging.SendOptions{}); err == nil || err.Error() != "WhatsApp not connected" {
		t.Fatalf("%v", err)
	}
}

func TestAttachmentKinds(t *testing.T) {
	r := newRig(t, rigOptions{})
	dir := t.TempDir()
	send := func(name, caption string) *waE2E.Message {
		path := filepath.Join(dir, name)
		if err := os.WriteFile(path, []byte("data"), 0o600); err != nil {
			t.Fatal(err)
		}
		if _, err := r.p.SendMessage(context.Background(), "4912", caption, messaging.SendOptions{MediaPath: path}); err != nil {
			t.Fatal(err)
		}
		return r.cl.sent[len(r.cl.sent)-1].msg
	}
	if m := send("a.PNG", "look"); m.GetImageMessage().GetCaption() != "look" || m.GetImageMessage().GetMimetype() != "image/png" {
		t.Fatalf("%v", m)
	}
	if m := send("a.mov", ""); m.GetVideoMessage() == nil || m.GetVideoMessage().Caption != nil {
		t.Fatalf("%v", m)
	}
	if m := send("a.mp3", "ignored"); m.GetAudioMessage().GetMimetype() != "audio/mp4" {
		t.Fatalf("%v", m)
	}
	if m := send("plan.pdf", "doc"); m.GetDocumentMessage().GetFileName() != "plan.pdf" || m.GetDocumentMessage().GetMimetype() != "application/pdf" || m.GetDocumentMessage().GetCaption() != "doc" {
		t.Fatalf("%v", m)
	}
}

func TestMarkReadAndTyping(t *testing.T) {
	r := newRig(t, rigOptions{})
	ctx := context.Background()
	if err := r.p.MarkRead(ctx, "4912@s.whatsapp.net", "M"); err != nil {
		t.Fatal(err)
	}
	if err := r.p.MarkRead(ctx, "120363-1@g.us", "M"); err != nil {
		t.Fatal(err)
	}
	if len(r.cl.reads) != 1 || r.cl.reads[0] != "M@4912@s.whatsapp.net/4912@s.whatsapp.net" {
		t.Fatalf("%v", r.cl.reads)
	}
	_ = r.p.SendTyping(ctx, "4912", true)
	_ = r.p.SendTyping(ctx, "4912", false)
	if len(r.cl.typing) != 2 || !r.cl.typing[0] || r.cl.typing[1] {
		t.Fatalf("%v", r.cl.typing)
	}
	if err := r.p.SendReaction(ctx, "4912", "MSG", "👍"); err != nil {
		t.Fatal(err)
	}
	if got := r.cl.sent[0].msg.GetReactionMessage().GetKey().GetID(); got != "MSG" {
		t.Fatalf("%q", got)
	}
}

func TestAccessTargetsAndAliases(t *testing.T) {
	r := newRig(t, rigOptions{})
	targets, err := r.p.ListAccessTargets(context.Background())
	if err != nil || len(targets) != 2 {
		t.Fatalf("%+v %v", targets, err)
	}
	if targets[0].Scope != "phone_number" || targets[0].Value != "491234" || targets[0].Label != "Mum" || targets[1].Value != "120363-1@g.us" || targets[1].Bucket != "sharedSpaceRules" {
		t.Fatalf("%+v", targets)
	}

	r.cl.pnForLID = map[string]types.JID{"55": types.NewJID("491234", types.DefaultUserServer)}
	r.cl.lidForPN = map[string]types.JID{"491234": types.NewJID("55", types.HiddenUserServer)}
	for in, want := range map[string][]string{
		"55@lid":                {"55@lid", "491234@s.whatsapp.net"},
		"491234@s.whatsapp.net": {"55@lid", "491234@s.whatsapp.net"},
		"999@s.whatsapp.net":    {"999@s.whatsapp.net"},
		"120363-1@g.us":         {"120363-1@g.us"},
	} {
		got, _ := r.p.ConversationChatIDs(context.Background(), in)
		if len(got) != len(want) || got[0] != want[0] || got[len(got)-1] != want[len(want)-1] {
			t.Errorf("%s -> %v, want %v", in, got, want)
		}
	}
}

// --- connection lifecycle ------------------------------------------------------------------

func TestPairingPublishesTheQRCode(t *testing.T) {
	cl, ev := newFake(), &recorder{}
	cl.paired = false
	cl.jid = types.EmptyJID
	p := newPlatform(messaging.Config{AuthDir: t.TempDir()}, ev, Deps{open: func(context.Context, string) (waClient, error) { return cl, nil }})
	if err := p.Connect(context.Background()); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = p.Disconnect(context.Background()) })
	cl.codes <- qrItem{Event: "code", Code: "2@abc,def"}
	waitFor(t, func() bool {
		ev.mu.Lock()
		defer ev.mu.Unlock()
		return p.Status() == messaging.StatusAwaitingQR && len(ev.qrs) == 1
	})
	info := p.AuthInfo()
	if info["qrCode"] != "2@abc,def" || info["status"] != "awaiting_qr" || info["number"] != nil {
		t.Fatalf("%v", info)
	}
	ev.mu.Lock()
	qrs := append([]string(nil), ev.qrs...)
	ev.mu.Unlock()
	if len(qrs) != 1 {
		t.Fatalf("qr events %v", qrs)
	}

	cl.jid = types.NewJID("491111", types.DefaultUserServer)
	cl.handler(&events.Connected{})
	info = p.AuthInfo()
	if info["qrCode"] != nil || info["status"] != "connected" || info["number"] != "491111" {
		t.Fatalf("%v", info)
	}
	raw, _ := json.Marshal(info)
	var decoded map[string]any
	_ = json.Unmarshal(raw, &decoded)
	if len(decoded) != 3 {
		t.Fatalf("the QR screen reads qrCode, status and number: %s", raw)
	}
}

func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for !cond() {
		if time.Now().After(deadline) {
			t.Fatal("condition not met")
		}
		time.Sleep(5 * time.Millisecond)
	}
}

func TestConnectionLossDecisions(t *testing.T) {
	r := newRig(t, rigOptions{})
	r.cl.handler(&events.Disconnected{})
	d := r.ev.disconnected[0]
	if d.ShouldReconnect == nil || !*d.ShouldReconnect || !d.WillReconnect || d.Reason != "connection_lost" || d.Manual || d.RequiresUserAction {
		t.Fatalf("%+v", d)
	}
	if r.p.Status() != messaging.StatusDisconnected {
		t.Fatalf("status %s", r.p.Status())
	}
	r.p.mu.Lock()
	timer, attempts := r.p.timer, r.p.attempts
	r.p.mu.Unlock()
	if timer == nil || attempts != 1 {
		t.Fatalf("a reconnect is scheduled with backoff: timer %v attempts %d", timer, attempts)
	}
}

func TestRepeatedConnectFailuresAskTheUser(t *testing.T) {
	r := newRig(t, rigOptions{})
	r.p.mu.Lock()
	r.p.attempts = badSessionRetryLimit
	r.p.mu.Unlock()
	r.cl.handler(&events.ConnectFailure{Reason: events.ConnectFailureGeneric})
	d := r.ev.disconnected[0]
	if !d.RequiresUserAction || d.Reason != "bad_session" || *d.ShouldReconnect || d.WillReconnect {
		t.Fatalf("%+v", d)
	}
	r.p.mu.Lock()
	timer := r.p.timer
	r.p.mu.Unlock()
	if timer != nil {
		t.Fatal("must not retry a session WhatsApp keeps rejecting")
	}
}

func TestDisconnectIsFinal(t *testing.T) {
	r := newRig(t, rigOptions{})
	if err := r.p.Disconnect(context.Background()); err != nil {
		t.Fatal(err)
	}
	if !r.cl.closed || r.ev.disconnected[0].Manual != true {
		t.Fatalf("%+v closed=%v", r.ev.disconnected, r.cl.closed)
	}
	r.cl.handler(&events.Disconnected{}) // a late event from the dropped client
	if len(r.ev.disconnected) != 1 {
		t.Fatal("events of a dropped client must be ignored")
	}
}

func TestLoggedOutRemovesTheLogin(t *testing.T) {
	r := newRig(t, rigOptions{})
	if err := os.WriteFile(filepath.Join(r.p.cfg.AuthDir, "whatsmeow.db"), []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	r.cl.handler(&events.LoggedOut{})
	if r.ev.loggedOut != 1 || len(r.ev.disconnected) != 1 || *r.ev.disconnected[0].ShouldReconnect {
		t.Fatalf("loggedOut %d disconnected %+v", r.ev.loggedOut, r.ev.disconnected)
	}
	if _, err := os.Stat(r.p.cfg.AuthDir); !os.IsNotExist(err) {
		t.Fatalf("auth dir survived the logout: %v", err)
	}
	if !r.cl.closed {
		t.Fatal("store left open")
	}
}

func TestLogoutUnlinksAndDeletesTheLogin(t *testing.T) {
	r := newRig(t, rigOptions{})
	if err := r.p.Logout(context.Background()); err != nil {
		t.Fatal(err)
	}
	if r.cl.paired {
		t.Fatal("device still linked on WhatsApp's side")
	}
	if _, err := os.Stat(r.p.cfg.AuthDir); !os.IsNotExist(err) {
		t.Fatal("auth dir survived")
	}
}

func TestConnectErrorsAreReturned(t *testing.T) {
	boom := errors.New("store locked")
	p := newPlatform(messaging.Config{AuthDir: t.TempDir()}, &recorder{}, Deps{open: func(context.Context, string) (waClient, error) { return nil, boom }})
	if err := p.Connect(context.Background()); !errors.Is(err, boom) {
		t.Fatalf("%v", err)
	}
}
