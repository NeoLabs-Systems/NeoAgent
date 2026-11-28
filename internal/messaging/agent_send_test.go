package messaging

import (
	"context"
	"errors"
	"path/filepath"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

type toolPlatform struct {
	sent    []string
	fail    int
	shared  bool
	aliases []string
	reacted string
}

func (p *toolPlatform) Connect(context.Context) error    { return nil }
func (p *toolPlatform) Disconnect(context.Context) error { return nil }
func (p *toolPlatform) Status() string                   { return StatusConnected }
func (p *toolPlatform) AuthInfo() map[string]any         { return nil }
func (p *toolPlatform) SetAccessPolicy(AccessPolicy)     {}
func (p *toolPlatform) AccessPolicy() AccessPolicy       { return AccessPolicy{} }
func (p *toolPlatform) IsSharedRoute() bool              { return p.shared }
func (p *toolPlatform) OwnerChatID() string              { return "own-chat" }
func (p *toolPlatform) SendMessage(_ context.Context, to, content string, opts SendOptions) (SendResult, error) {
	if p.fail > 0 && len(p.sent) == p.fail {
		return SendResult{Success: false, Error: "too long"}, nil
	}
	p.sent = append(p.sent, to+"|"+content+"|"+opts.MediaPath)
	return SendResult{Success: true, MessageID: "m" + string(rune('0'+len(p.sent)))}, nil
}
func (p *toolPlatform) ConversationChatIDs(context.Context, string) ([]string, error) {
	return p.aliases, nil
}
func (p *toolPlatform) SendReaction(_ context.Context, chatID, messageID, emoji string) error {
	p.reacted = chatID + "|" + messageID + "|" + emoji
	return nil
}

type emitted struct{ events []string }

func (e *emitted) EmitToUser(_ int64, event string, _ any) { e.events = append(e.events, event) }

func agentToolsManager(t *testing.T, p *toolPlatform) (*Manager, *dbx.DB, *emitted) {
	t.Helper()
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	for _, q := range []string{
		"INSERT INTO users (id, username, password) VALUES (1, 'u', 'x')",
		"INSERT INTO agents (id, user_id, slug, display_name) VALUES ('main', 1, 'main', 'Main')",
	} {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	e := &emitted{}
	m := NewManager(ManagerConfig{DB: db, Emitter: e, ResolveMedia: func(_ context.Context, userID int64, ref string) (string, error) {
		if userID != 1 || ref != "a.png" {
			return "", errors.New("Message attachment does not exist.")
		}
		return "/resolved/a.png", nil
	}})
	m.conns[connKey{userID: 1, agentID: "main", platform: "whatsapp"}] = &managedConn{platform: p}
	return m, db, e
}

func TestSendAgentMessageStoresAndSplits(t *testing.T) {
	p := &toolPlatform{}
	m, db, e := agentToolsManager(t, p)
	ctx := context.Background()
	got, err := m.SendAgentMessage(ctx, AgentSend{UserID: 1, Platform: "whatsapp", To: "491@s.whatsapp.net", Content: "hello", RunID: "r1", MediaReference: "a.png"})
	if err != nil || got["success"] != true {
		t.Fatalf("%v %v", got, err)
	}
	if len(p.sent) != 1 || p.sent[0] != "491@s.whatsapp.net|hello|/resolved/a.png" {
		t.Fatalf("platform got %q", p.sent)
	}
	var content, media, run string
	if err := db.R.QueryRow(`SELECT content, media_path, run_id FROM messages WHERE platform_chat_id = ?`, "491@s.whatsapp.net").Scan(&content, &media, &run); err != nil {
		t.Fatal(err)
	}
	if content != "hello" || media != "a.png" || run != "r1" || len(e.events) != 1 || e.events[0] != "messaging:sent" {
		t.Fatalf("%q %q %q %v", content, media, run, e.events)
	}
	if got, _ := m.SendAgentMessage(ctx, AgentSend{UserID: 1, Platform: "whatsapp", To: "x", Content: "[no response]"}); got["suppressed"] != true {
		t.Fatalf("silence: %v", got)
	}
	tg := &toolPlatform{fail: 1}
	m.conns[connKey{userID: 1, agentID: "main", platform: "telegram"}] = &managedConn{platform: tg}
	long := strings.Repeat("word ", 2000)
	if _, err := m.SendAgentMessage(ctx, AgentSend{UserID: 1, Platform: "telegram", To: "x", Content: long}); err == nil {
		t.Fatal("rejected second part not reported")
	} else if se, ok := err.(*SendError); !ok || !se.Ambiguous {
		t.Fatalf("second-part failure must be ambiguous: %v", err)
	}
	if _, err := m.SendAgentMessage(ctx, AgentSend{UserID: 1, Platform: "slack", To: "x", Content: "y"}); err == nil || err.Error() != "Platform slack not connected" {
		t.Fatal(err)
	}
}

func TestOwnerReactionsAndConversations(t *testing.T) {
	p := &toolPlatform{aliases: []string{"123@lid", "491@s.whatsapp.net"}}
	m, db, _ := agentToolsManager(t, p)
	ctx := context.Background()
	if got := m.OwnerDestination(ctx, 1, "", "whatsapp"); got != "own-chat" {
		t.Fatalf("own %q", got)
	}
	p.shared = true
	if got := m.OwnerDestination(ctx, 1, "", "whatsapp"); got != "" {
		t.Fatalf("unlinked shared %q", got)
	}
	if _, err := db.W.Exec(`INSERT INTO messaging_identity_links (platform, external_id, chat_id, user_id, agent_id) VALUES ('whatsapp', '491', '491@s.whatsapp.net', 1, 'main')`); err != nil {
		t.Fatal(err)
	}
	if got := m.OwnerDestination(ctx, 1, "", "whatsapp"); got != "491@s.whatsapp.net" {
		t.Fatalf("linked shared %q", got)
	}
	if !m.SupportsReactions(ctx, 1, "", "whatsapp") || m.SupportsReactions(ctx, 1, "", "slack") {
		t.Fatal("reaction support")
	}
	if err := m.SendReaction(ctx, 1, "", "whatsapp", "c", "m1", "👍", "r"); err != nil || p.reacted != "c|m1|👍" {
		t.Fatal(err)
	}
	// The number's conversation is found under the LID too.
	if _, err := db.W.Exec(`INSERT INTO conversations (id, user_id, agent_id, platform, platform_chat_id, title) VALUES ('conv-1', 1, 'main', 'whatsapp', '491@s.whatsapp.net', 't')`); err != nil {
		t.Fatal(err)
	}
	if id, err := m.ConversationFor(ctx, 1, "", "whatsapp", "123@lid", ""); err != nil || id != "conv-1" {
		t.Fatalf("%q %v", id, err)
	}
	p.aliases = nil
	id, err := m.ConversationFor(ctx, 1, "", "whatsapp", "999@s.whatsapp.net", "")
	if err != nil || id == "conv-1" {
		t.Fatalf("%q %v", id, err)
	}
	var title string
	_ = db.R.QueryRow(`SELECT title FROM conversations WHERE id = ?`, id).Scan(&title)
	if title != "whatsapp — 999@s.whatsapp.net" {
		t.Fatalf("title %q", title)
	}
}

func TestSendsRefuseUnresolvedAttachments(t *testing.T) {
	p := &toolPlatform{}
	m, _, _ := agentToolsManager(t, p)
	ctx := context.Background()
	if _, err := m.SendMessage(ctx, 1, "", "whatsapp", "x", "hi", "/etc/passwd"); err == nil {
		t.Fatal("SendMessage accepted an unresolved attachment")
	}
	_, err := m.SendAgentMessage(ctx, AgentSend{UserID: 1, Platform: "whatsapp", To: "x", Content: "hi", MediaReference: "../../etc/passwd"})
	if se, ok := err.(*SendError); !ok || se.Ambiguous {
		t.Fatalf("SendAgentMessage: %v", err)
	}
	if _, err := m.SendMessage(ctx, 1, "", "whatsapp", "x", "hi", "a.png"); err != nil {
		t.Fatal(err)
	}
	if len(p.sent) != 1 || p.sent[0] != "x|hi|/resolved/a.png" {
		t.Fatalf("platform got %q", p.sent)
	}
	// Without a resolver nothing is attached at all.
	bare := NewManager(ManagerConfig{})
	bare.conns[connKey{userID: 1, agentID: "main", platform: "whatsapp"}] = &managedConn{platform: p}
	if _, err := bare.SendMessage(ctx, 1, "", "whatsapp", "x", "hi", "a.png"); err == nil {
		t.Fatal("attachment sent without a resolver")
	}
	if _, err := bare.SendMessage(ctx, 1, "", "whatsapp", "x", "plain", ""); err != nil {
		t.Fatal(err)
	}
}
