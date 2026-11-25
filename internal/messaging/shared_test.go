package messaging

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/sharedmessaging"
	"github.com/NeoLabs-Systems/neolabs-go/apperr"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

type sharedLog struct {
	mu      sync.Mutex
	entries [][]any
}

func (l *sharedLog) add(e ...any) {
	l.mu.Lock()
	l.entries = append(l.entries, e)
	l.mu.Unlock()
}

func (l *sharedLog) take() [][]any {
	l.mu.Lock()
	defer l.mu.Unlock()
	out := l.entries
	l.entries = nil
	return out
}

type fakeShared struct {
	log *sharedLog
	ev  Events
}

func (f *fakeShared) Connect(context.Context) error { f.ev.Connected(); return nil }
func (f *fakeShared) Disconnect(context.Context) error {
	f.log.add("adapter_disconnected")
	return nil
}
func (f *fakeShared) Status() string               { return StatusConnected }
func (f *fakeShared) AuthInfo() map[string]any     { return map[string]any{"username": "neobot", "id": 5} }
func (f *fakeShared) SetAccessPolicy(AccessPolicy) {}
func (f *fakeShared) AccessPolicy() AccessPolicy   { return AccessPolicy{} }
func (f *fakeShared) SendMessage(_ context.Context, to, content string, _ SendOptions) (SendResult, error) {
	f.log.add("send", to, content)
	return SendResult{Success: true, MessageID: "m"}, nil
}
func (f *fakeShared) SendReaction(_ context.Context, chatID, messageID, emoji string) error {
	f.log.add("reaction", chatID, messageID, emoji)
	return nil
}

type logEmitter struct{ log *sharedLog }

func (e logEmitter) EmitToUser(userID int64, event string, payload any) {
	// gen_shared.js stubs ingestMessage, so Node's log has no inbound echo.
	if event == "messaging:message" {
		return
	}
	e.log.add("emit", fmt.Sprintf("user:%d", userID), event, payload)
}

type logEngine struct{ log *sharedLog }

func (e logEngine) HandleMessage(_ context.Context, userID int64, agentID string, m *Message) Outcome {
	e.log.add("ingest", userID, m.Platform, agentID, m.ChatID, m.Content, m.Metadata)
	return Outcome{}
}

func canon(v any) string {
	raw, _ := json.Marshal(v)
	var back any
	_ = json.Unmarshal(raw, &back)
	out, _ := json.Marshal(back)
	return string(out)
}

// TestSharedAccountsMatchNode replays SharedMessagingConnections recorded
// from Node with a fake Telegram adapter (testdata/gen_shared.js).
func TestSharedAccountsMatchNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/shared_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors struct {
		Steps []struct {
			Label string
			Value json.RawMessage
			Log   json.RawMessage
		}
	}
	if err := json.Unmarshal(raw, &vectors); err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	dir := t.TempDir()
	db, err := dbx.Open(ctx, filepath.Join(dir, "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	for _, q := range []string{
		"INSERT INTO users (id, username, password) VALUES (1, 'u', 'x'), (2, 'v', 'x')",
		"INSERT INTO agents (id, user_id, slug, display_name) VALUES ('a1', 1, 'main', 'M'), ('a1b', 1, 'b', 'B'), ('a2', 2, 'main', 'M')",
	} {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	box, err := secretbox.New("enc:v1:", "x")
	if err != nil {
		t.Fatal(err)
	}
	log := &sharedLog{}
	var adapter *fakeShared
	factory := func(cfg Config, ev Events) (Platform, error) {
		token := 0
		if cfg.Settings["botToken"] != nil {
			token = 1
		}
		log.add("adapter_created", token)
		adapter = &fakeShared{log: log, ev: ev}
		return adapter, nil
	}
	m := NewManager(ManagerConfig{DB: db, Box: box, Emitter: logEmitter{log}, Engine: logEngine{log}, DataDir: dir,
		Factories: map[string]Factory{"telegram": factory, "whatsapp": factory}})
	store := &sharedmessaging.Store{DB: db, Box: box}
	shared := NewSharedConnections(m, store)

	got := map[string]any{}
	logs := map[string][][]any{}
	step := func(label string, v any) {
		time.Sleep(20 * time.Millisecond)
		got[label] = v
		logs[label] = log.take()
	}
	errValue := func(err error) any {
		e, ok := apperr.As(err)
		if !ok {
			return map[string]any{"message": fmt.Sprint(err)}
		}
		return map[string]any{"status": e.Status, "message": e.Message, "code": e.Code}
	}
	conn := func() any {
		var r struct {
			enabled, available, allow int
			status                    string
			reason, id, label, last   sql.NullString
		}
		err := db.R.QueryRow(`SELECT enabled, available, allow_personal, status, status_reason, account_id, account_label, last_connected FROM messaging_shared_connections WHERE platform = 'telegram'`).
			Scan(&r.enabled, &r.available, &r.allow, &r.status, &r.reason, &r.id, &r.label, &r.last)
		if err != nil {
			return nil
		}
		return map[string]any{"enabled": r.enabled, "available": r.available, "allow_personal": r.allow, "status": r.status,
			"status_reason": nullable(r.reason), "account_id": nullable(r.id), "account_label": nullable(r.label), "connected": r.last.Valid}
	}
	links := func() any {
		rows, _ := db.R.Query(`SELECT platform, external_id, chat_id, display_name, user_id, agent_id FROM messaging_identity_links ORDER BY user_id`)
		defer rows.Close()
		out := []any{}
		for rows.Next() {
			var p, e, c string
			var d sql.NullString
			var u int64
			var a string
			_ = rows.Scan(&p, &e, &c, &d, &u, &a)
			out = append(out, map[string]any{"platform": p, "external_id": e, "chat_id": c, "display_name": nullable(d), "user_id": u, "agent_id": a})
		}
		return out
	}
	gate := func(over func(*AccessContext)) any {
		c := AccessContext{IsDirect: true, SenderID: "77", ChatID: "dm_77", Text: "hello", MessageID: "9", SenderName: "Ann"}
		if over != nil {
			over(&c)
		}
		d := shared.gate("telegram", c)
		out := map[string]any{"allowed": d.Allowed}
		if d.Allowed {
			out["ownerUserId"] = d.OwnerUserID
		} else {
			out["reason"] = d.Reason
		}
		return out
	}
	opts, _ := shared.ListOptions(ctx, 1)
	step("options none", opts)
	_, err = shared.StartLink(ctx, 1, "a1", "telegram")
	step("start link unavailable", errValue(err))
	_, err = shared.StartLink(ctx, 1, "a1", "discord")
	step("start link discord", errValue(err))
	token := "123456:abcdefghijklmnopqrstuvwxyz"
	if err := store.Configure(ctx, "telegram", sharedmessaging.Input{BotToken: &token}, "app"); err != nil {
		t.Fatal(err)
	}
	if err := shared.Reconcile(ctx); err != nil {
		t.Fatal(err)
	}
	step("connected", conn())
	opts, _ = shared.ListOptions(ctx, 1)
	step("options", opts)
	started, err := shared.StartLink(ctx, 1, "a1b", "telegram")
	if err != nil {
		t.Fatal(err)
	}
	code := started["code"].(string)
	step("start link", map[string]any{"platform": started["platform"], "code": len(code), "expiresAt": "string", "accountLabel": started["accountLabel"], "url": strings.Replace(started["url"].(string), code, "CODE", 1)})
	step("gate group", gate(func(c *AccessContext) { c.IsDirect = false }))
	step("gate no sender", gate(func(c *AccessContext) { c.SenderID = "" }))
	step("gate not own chat", gate(func(c *AccessContext) { c.ChatID = "-100" }))
	step("gate unlinked", gate(nil))
	step("gate code", gate(func(c *AccessContext) { c.Text = "link " + code + " please" }))
	step("links after code", links())
	_, isRoute := m.conns[connKey{1, "a1b", "telegram"}].platform.(*SharedRoutePlatform)
	step("route installed", isRoute)
	step("gate linked", gate(nil))
	entries, _ := shared.StatusEntries(ctx, 1, "a1b")
	if e, ok := entries["telegram"].(map[string]any); ok && e["lastConnected"] != nil {
		e["lastConnected"] = "<time>"
	}
	step("status entries", entries)
	entries, _ = shared.StatusEntries(ctx, 1, "a1")
	step("status entries other agent", entries)
	adapter.ev.Message(Inbound{ChatID: "dm_77", Content: "hi there", Metadata: map[string]any{"a": 1}})
	time.Sleep(50 * time.Millisecond)
	step("message routed", nil)
	adapter.ev.Message(Inbound{ChatID: "dm_999", Content: "stranger"})
	step("stranger ignored", nil)
	reused := gate(func(c *AccessContext) { c.Text = code })
	step("code reused", map[string]any{"decision": reused, "links": links()})
	second, err := shared.StartLink(ctx, 2, "a2", "telegram")
	if err != nil {
		t.Fatal(err)
	}
	gate(func(c *AccessContext) { c.Text = second["code"].(string) })
	step("identity taken", links())
	for i := 0; i < 30; i++ {
		gate(nil)
	}
	step("gate rate limited", gate(nil))
	no := false
	if err := store.Configure(ctx, "telegram", sharedmessaging.Input{AllowPersonal: &no}, "app"); err != nil {
		t.Fatal(err)
	}
	step("personal refused", errValue(shared.BeforePersonalConnect(ctx, 2, "a2", "telegram")))
	res, _ := shared.Unlink(ctx, 1, "telegram", "a1")
	step("unlink other agent", res)
	res, _ = shared.Unlink(ctx, 1, "telegram", "")
	step("unlink", res)
	res, _ = shared.Unlink(ctx, 1, "telegram", "")
	step("unlink again", res)
	_, has := m.conns[connKey{1, "a1b", "telegram"}]
	step("route removed", has)
	if err := store.Configure(ctx, "telegram", sharedmessaging.Input{Enabled: &no}, "app"); err != nil {
		t.Fatal(err)
	}
	_ = shared.Reconcile(ctx)
	step("disabled", conn())
	if err := store.Remove(ctx, "telegram", "app"); err != nil {
		t.Fatal(err)
	}
	_ = shared.Reconcile(ctx)
	step("removed", conn())
	shared.Stop()

	if len(vectors.Steps) < 25 || len(got) < 25 {
		t.Fatalf("%d recorded steps, %d replayed", len(vectors.Steps), len(got))
	}
	for _, v := range vectors.Steps {
		want := v.Value
		if v.Label == "status entries" {
			var e map[string]map[string]any
			_ = json.Unmarshal(want, &e)
			e["telegram"]["lastConnected"] = "<time>"
			want, _ = json.Marshal(e)
		}
		var w any
		_ = json.Unmarshal(want, &w)
		if canon(got[v.Label]) != canon(w) {
			t.Errorf("%s:\n got: %s\nwant: %s", v.Label, canon(got[v.Label]), canon(w))
		}
		var wl any
		_ = json.Unmarshal(v.Log, &wl)
		if canon(logs[v.Label]) != canon(wl) && !(canon(wl) == "[]" && logs[v.Label] == nil) {
			t.Errorf("%s log:\n got: %s\nwant: %s", v.Label, canon(logs[v.Label]), canon(wl))
		}
	}
}
