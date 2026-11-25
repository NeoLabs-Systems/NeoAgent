package whatsapppersonal

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"go.mau.fi/whatsmeow/proto/waCommon"
	"go.mau.fi/whatsmeow/proto/waE2E"
	"go.mau.fi/whatsmeow/proto/waHistorySync"
	"go.mau.fi/whatsmeow/proto/waWeb"
	"go.mau.fi/whatsmeow/types"
	"go.mau.fi/whatsmeow/types/events"
	"google.golang.org/protobuf/proto"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/integrationstest"
)

// fakeDevice is a whatsmeow client that pairs when told to.
type fakeDevice struct {
	mu       sync.Mutex
	paired   bool
	handlers []func(any)
	codes    chan QRItem
	sent     []string
	loggedIn bool
	closed   bool
}

func (d *fakeDevice) AddEventHandler(fn func(any)) {
	d.mu.Lock()
	d.handlers = append(d.handlers, fn)
	d.mu.Unlock()
}
func (d *fakeDevice) emit(evt any) {
	d.mu.Lock()
	hs := append([]func(any){}, d.handlers...)
	d.mu.Unlock()
	for _, h := range hs {
		h(evt)
	}
}
func (d *fakeDevice) IsPaired() bool { d.mu.Lock(); defer d.mu.Unlock(); return d.paired }
func (d *fakeDevice) QRChannel(context.Context) (<-chan QRItem, error) {
	d.codes = make(chan QRItem, 4)
	return d.codes, nil
}
func (d *fakeDevice) Connect() error {
	d.mu.Lock()
	paired := d.paired
	d.mu.Unlock()
	if paired {
		go d.emit(&events.Connected{})
	}
	return nil
}
func (d *fakeDevice) Disconnect()                  {}
func (d *fakeDevice) Logout(context.Context) error { d.loggedIn = false; return nil }
func (d *fakeDevice) OwnJID() string               { return "491701234567:3@s.whatsapp.net" }
func (d *fakeDevice) Close() error                 { d.closed = true; return nil }
func (d *fakeDevice) SendText(_ context.Context, to types.JID, text string) error {
	d.mu.Lock()
	d.sent = append(d.sent, to.String()+" "+text)
	d.mu.Unlock()
	return nil
}
func (d *fakeDevice) ParseWebMessage(chat types.JID, msg *waWeb.WebMessageInfo) (*events.Message, error) {
	return &events.Message{Info: types.MessageInfo{MessageSource: types.MessageSource{Chat: chat, Sender: chat, IsFromMe: msg.GetKey().GetFromMe()},
		ID: msg.GetKey().GetID(), Timestamp: time.Unix(int64(msg.GetMessageTimestamp()), 0)}, Message: msg.GetMessage()}, nil
}

func waitFor(t *testing.T, what string, ok func() bool) {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for !ok() {
		if time.Now().After(deadline) {
			t.Fatalf("timed out waiting for %s", what)
		}
		time.Sleep(5 * time.Millisecond)
	}
}

func asJSON(t *testing.T, v any) string {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return string(raw)
}

func TestLinkReadSendAndDisconnect(t *testing.T) {
	dataDir := t.TempDir()
	dev := &fakeDevice{}
	var events_ []MessageEvent
	var mu sync.Mutex
	var p *Provider
	st := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		p = New(svc, Options{AgentDataDir: dataDir, Open: func(_ context.Context, authDir string) (Device, error) {
			if err := os.MkdirAll(authDir, 0o700); err != nil {
				return nil, err
			}
			return dev, nil
		}, OnMessage: func(e MessageEvent) {
			mu.Lock()
			events_ = append(events_, e)
			mu.Unlock()
		}})
		return []integrations.Provider{p}
	}, integrations.Hooks{})
	ctx := context.Background()
	agent, _ := st.Svc.ResolveAgent(ctx, 1, "")
	scope := integrations.Scope{UserID: 1, AgentID: agent}

	if _, err := p.BeginConnection(ctx, scope, "work"); err == nil || err.Error() != "Unknown WhatsApp app: work" {
		t.Fatalf("bad app: %v", err)
	}
	start, err := p.BeginConnection(ctx, scope, "personal")
	if err != nil {
		t.Fatal(err)
	}
	if start.Status != "interactive_connect" || len(start.SessionID) != 36 || start.URL != "/api/integrations/whatsapp_personal/connect/"+start.SessionID {
		t.Fatalf("start %+v", start)
	}
	waitFor(t, "QR channel", func() bool { dev.mu.Lock(); defer dev.mu.Unlock(); return dev.codes != nil })
	dev.codes <- QRItem{Event: "code", Code: "2@abc"}
	waitFor(t, "QR code", func() bool { s, _ := p.ConnectionSession(scope, start.SessionID); return s.Status == "awaiting_qr" })
	s, _ := p.ConnectionSession(scope, start.SessionID)
	if got := asJSON(t, s); got != `{"id":"`+start.SessionID+`","provider":"whatsapp_personal","appId":"personal","status":"awaiting_qr","connectionId":null,"accountEmail":null,"error":null,"qr":"2@abc"}` {
		t.Fatalf("session %s", got)
	}
	if _, ok := p.ConnectionSession(integrations.Scope{UserID: 2, AgentID: agent}, start.SessionID); ok {
		t.Fatal("another account must not see the session")
	}
	dev.mu.Lock()
	dev.paired = true
	dev.mu.Unlock()
	dev.emit(&events.Connected{})
	waitFor(t, "link", func() bool { s, _ := p.ConnectionSession(scope, start.SessionID); return s.Status == "connected" })
	s, _ = p.ConnectionSession(scope, start.SessionID)
	if s.AccountEmail != "491701234567" || s.ConnectionID == nil || s.QR != "" {
		t.Fatalf("linked session %+v", s)
	}
	rows, _ := st.Svc.ListConnections(ctx, 1, providerKey, agent)
	if len(rows) != 1 || rows[0].AccountEmail != "491701234567" || rows[0].ScopesJSON != `["personal_whatsapp"]` {
		t.Fatalf("rows %+v", rows)
	}
	authDir := st.Svc.Credentials(rows[0])["authDir"].(string)
	if filepath.Dir(authDir) != filepath.Join(dataDir, "integrations", "whatsapp-personal", "1", agent) {
		t.Fatalf("auth dir %s", authDir)
	}

	// History and live messages fill the cache; incoming ones fire tasks.
	dev.emit(&events.HistorySync{Data: &waHistorySync.HistorySync{Conversations: []*waHistorySync.Conversation{{
		ID: proto.String("4915550000@s.whatsapp.net"), Name: proto.String("Anna"), UnreadCount: proto.Uint32(2), ConversationTimestamp: proto.Uint64(1767225600),
		Messages: []*waHistorySync.HistorySyncMsg{{Message: &waWeb.WebMessageInfo{Key: &waCommon.MessageKey{ID: proto.String("m1")}, MessageTimestamp: proto.Uint64(1767225600),
			Message: &waE2E.Message{Conversation: proto.String("Hi there")}}}},
	}}}})
	anna := types.NewJID("4915550000", types.DefaultUserServer)
	dev.emit(&events.Message{Info: types.MessageInfo{MessageSource: types.MessageSource{Chat: anna, Sender: anna}, ID: "m2", Timestamp: time.Unix(1767229200, 0)},
		Message: &waE2E.Message{ImageMessage: &waE2E.ImageMessage{}}})
	mu.Lock()
	if len(events_) != 1 || events_[0].Text != "[image]" || events_[0].ConnectionID != rows[0].ID || events_[0].SenderTag != "4915550000" {
		t.Fatalf("events %+v", events_)
	}
	mu.Unlock()

	exec := func(name string, args map[string]any) string {
		t.Helper()
		ex, err := p.ExecuteTool(ctx, name, args, rows[0])
		if err != nil {
			t.Fatal(err)
		}
		return asJSON(t, ex.Result)
	}
	if got := exec("whatsapp_personal_get_profile", nil); got != `{"account":"491701234567","connected":true,"chatCount":1,"cachedMessageChats":1,"syncNote":"This account is linked and connected. Read tools expose only chats and messages currently available in this session cache."}` {
		t.Fatalf("profile %s", got)
	}
	if got := exec("whatsapp_personal_list_chats", map[string]any{"limit": 5.0}); got != `{"account":"491701234567","connected":true,"chats":[{"id":"4915550000@s.whatsapp.net","name":"Anna","isGroup":false,"unreadCount":2,"archived":false,"muteEndTime":null,"lastMessageAt":"2026-01-01T01:00:00.000Z"}],"count":1,"syncNote":"Chats shown here come from the current personal WhatsApp cache."}` {
		t.Fatalf("chats %s", got)
	}
	if got := exec("whatsapp_personal_get_messages", map[string]any{"chat_id": "+49 1555-0000"}); got != `{"chatId":"4915550000@s.whatsapp.net","messages":[{"id":"m2","chatId":"4915550000@s.whatsapp.net","sender":"4915550000@s.whatsapp.net","senderTag":"4915550000","fromMe":false,"kind":"image","text":"[image]","timestamp":"2026-01-01T01:00:00.000Z"},{"id":"m1","chatId":"4915550000@s.whatsapp.net","sender":"4915550000@s.whatsapp.net","senderTag":"4915550000","fromMe":false,"kind":"text","text":"Hi there","timestamp":"2026-01-01T00:00:00.000Z"}],"count":2,"syncNote":"Only messages synchronized through this personal integration session are readable here."}` {
		t.Fatalf("messages %s", got)
	}
	if got := exec("whatsapp_personal_send_message", map[string]any{"to": "4915550000", "text": "On my way"}); got != `{"sent":true,"to":"4915550000@s.whatsapp.net"}` {
		t.Fatalf("send %s", got)
	}
	if _, err := p.ExecuteTool(ctx, "whatsapp_personal_send_message", map[string]any{"to": "4915550000"}, rows[0]); err == nil || err.Error() != "text is required." {
		t.Fatalf("missing text: %v", err)
	}

	snap := asJSON(t, p.Snapshot(rows, scope))
	var decoded map[string]any
	_ = json.Unmarshal([]byte(snap), &decoded)
	if decoded["availableToolCount"] != 4.0 || decoded["connectionMethod"] != nil || decoded["connectPrompt"] == nil {
		t.Fatalf("snapshot %s", snap)
	}

	if err := p.Disconnect(ctx, rows[0]); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(authDir); !os.IsNotExist(err) {
		t.Fatalf("auth dir kept: %v", err)
	}
}

// TestReconnectsAStoredLink: after a restart the stored device connects again
// on the first tool call.
func TestReconnectsAStoredLink(t *testing.T) {
	dataDir := t.TempDir()
	dev := &fakeDevice{paired: true}
	var opened []string
	var p *Provider
	st := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		p = New(svc, Options{AgentDataDir: dataDir, Open: func(_ context.Context, authDir string) (Device, error) {
			opened = append(opened, authDir)
			return dev, nil
		}})
		return []integrations.Provider{p}
	}, integrations.Hooks{})
	ctx := context.Background()
	agent, _ := st.Svc.ResolveAgent(ctx, 1, "")
	authDir := filepath.Join(dataDir, "old")
	conn, err := st.Svc.UpsertAccountApp(ctx, integrations.AccountApp{Scope: integrations.Scope{UserID: 1, AgentID: agent}, ProviderKey: providerKey, AppKey: "personal",
		AccountEmail: "491701234567", Credentials: map[string]any{"authDir": authDir}})
	if err != nil {
		t.Fatal(err)
	}
	ex, err := p.ExecuteTool(ctx, "whatsapp_personal_get_profile", nil, *conn)
	if err != nil {
		t.Fatal(err)
	}
	if len(opened) != 1 || opened[0] != authDir || asJSON(t, ex.Result) == "" {
		t.Fatalf("opened %v", opened)
	}
	// A link without a stored device directory cannot reconnect.
	broken, _ := st.Svc.UpsertAccountApp(ctx, integrations.AccountApp{Scope: integrations.Scope{UserID: 1, AgentID: agent}, ProviderKey: providerKey, AppKey: "personal",
		AccountEmail: "other", Credentials: map[string]any{}})
	if _, err := p.ExecuteTool(ctx, "whatsapp_personal_get_profile", nil, *broken); err == nil || err.Error() != "WhatsApp account credentials are missing." {
		t.Fatalf("broken: %v", err)
	}
}
