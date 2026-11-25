package messaging

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

type sharedAdapter struct {
	toolPlatform
	calls [][]any
}

func (a *sharedAdapter) SendMessage(_ context.Context, to, content string, _ SendOptions) (SendResult, error) {
	a.calls = append(a.calls, []any{"send", to, content})
	return SendResult{Success: true, MessageID: "m1"}, nil
}
func (a *sharedAdapter) SendTyping(_ context.Context, to string, typing bool) error {
	a.calls = append(a.calls, []any{"typing", to, typing})
	return nil
}
func (a *sharedAdapter) ConversationChatIDs(_ context.Context, id string) ([]string, error) {
	return []string{id, "alias"}, nil
}

// TestSharedRouteMatchesNode replays SharedRoutePlatform recorded from Node
// (testdata/gen_shared_route.js) on the same identity links.
func TestSharedRouteMatchesNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/shared_route_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors []struct {
		Label  string
		Result any
		Error  *struct{ Message, Code string }
		Calls  [][]any
	}
	if err := json.Unmarshal(raw, &vectors); err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	for _, q := range []string{
		"INSERT INTO users (id, username, password) VALUES (1, 'u', 'x'), (2, 'v', 'x'), (3, 'w', 'x')",
		"INSERT INTO agents (id, user_id, slug, display_name) VALUES ('a1', 1, 'main', 'M'), ('a2', 2, 'main', 'M'), ('a3', 3, 'main', 'M'), ('a3b', 3, 'b', 'B')",
		`INSERT INTO messaging_identity_links (platform, external_id, chat_id, display_name, user_id, agent_id) VALUES
  ('telegram', '77', 'dm_77', 'Ann', 1, 'a1'), ('whatsapp', '4915', '4915@s.whatsapp.net', NULL, 2, 'a2'), ('whatsapp', '999', 'status@broadcast', NULL, 3, 'a3')`,
	} {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	adapter := &sharedAdapter{}
	connected := true
	get := func(string) Platform {
		if !connected {
			return nil
		}
		return noReactions{a: adapter}
	}
	route := func(platform string, user int64, agent string) *SharedRoutePlatform {
		return NewSharedRoute(db.R, platform, user, agent, get)
	}
	tg, wa := route("telegram", 1, "a1"), route("whatsapp", 2, "a2")
	limited := route("telegram", 1, "a1")
	run := map[string]func() (any, error){
		"tg send dm_77": func() (any, error) { return sendResult(tg.SendMessage(ctx, "dm_77", "hi", SendOptions{})) },
		"tg send 77":    func() (any, error) { return sendResult(tg.SendMessage(ctx, "77", "hi", SendOptions{})) },
		"tg send other": func() (any, error) { return sendResult(tg.SendMessage(ctx, "88", "hi", SendOptions{})) },
		"tg typing":     func() (any, error) { return nil, tg.SendTyping(ctx, "77", true) },
		"tg reaction":   func() (any, error) { return nil, tg.SendReaction(ctx, "77", "m", "👍") },
		"tg prompt": func() (any, error) {
			_, err := tg.SendApprovalPrompt(ctx, "77", ApprovalPrompt{Text: "Allow?", ReplyHint: "Reply yes"})
			return map[string]any{"success": true, "messageId": "m1"}, err
		},
		"tg status":   func() (any, error) { return tg.Status(), nil },
		"tg auth":     func() (any, error) { return tg.AuthInfo(), nil },
		"tg aliases":  func() (any, error) { return tg.ConversationChatIDs(ctx, "dm_77") },
		"wa send jid": func() (any, error) { return sendResult(wa.SendMessage(ctx, "4915@s.whatsapp.net", "x", SendOptions{})) },
		"wa send device jid": func() (any, error) {
			return sendResult(wa.SendMessage(ctx, "4915:3@s.whatsapp.net", "x", SendOptions{}))
		},
		"wa auth": func() (any, error) { return wa.AuthInfo(), nil },
		"broadcast refused": func() (any, error) {
			return sendResult(route("whatsapp", 3, "a3").SendMessage(ctx, "999", "x", SendOptions{}))
		},
		"other agent": func() (any, error) {
			return sendResult(route("whatsapp", 3, "a3b").SendMessage(ctx, "999", "x", SendOptions{}))
		},
		"other agent status": func() (any, error) { return route("whatsapp", 3, "a3b").Status(), nil },
		"unlinked": func() (any, error) {
			return sendResult(route("telegram", 2, "a2").SendMessage(ctx, "1", "x", SendOptions{}))
		},
		"not connected": func() (any, error) {
			connected = false
			return sendResult(tg.SendMessage(ctx, "77", "x", SendOptions{}))
		},
		"not connected status":  func() (any, error) { return tg.Status(), nil },
		"not connected aliases": func() (any, error) { defer func() { connected = true }(); return tg.ConversationChatIDs(ctx, "dm_77") },
		"rate limited": func() (any, error) {
			for i := 0; i < 60; i++ {
				if _, err := limited.SendMessage(ctx, "77", "n", SendOptions{}); err != nil {
					return nil, err
				}
			}
			return sendResult(limited.SendMessage(ctx, "77", "over", SendOptions{}))
		},
	}
	for _, v := range vectors {
		adapter.calls = nil
		got, err := run[v.Label]()
		if v.Error != nil {
			var coded *CodedError
			code := ""
			if errors.As(err, &coded) {
				code = coded.Code
			}
			if err == nil || err.Error() != v.Error.Message || code != v.Error.Code {
				t.Errorf("%s: error %v (code %q), want %q (%q)", v.Label, err, code, v.Error.Message, v.Error.Code)
			}
			continue
		}
		if err != nil {
			t.Errorf("%s: %v", v.Label, err)
			continue
		}
		if a, b := asJSON(got), asJSON(v.Result); a != b {
			t.Errorf("%s: %s, want %s", v.Label, a, b)
		}
		if v.Label != "rate limited" && asJSON(adapter.calls) != asJSON(v.Calls) && len(v.Calls) > 0 {
			t.Errorf("%s calls %v, want %v", v.Label, adapter.calls, v.Calls)
		}
	}
}

// noReactions hides the fake's reaction method, as the Node adapter had none.
type noReactions struct{ a *sharedAdapter }

func (n noReactions) Connect(context.Context) error    { return nil }
func (n noReactions) Disconnect(context.Context) error { return nil }
func (n noReactions) Status() string                   { return StatusConnected }
func (n noReactions) AuthInfo() map[string]any         { return nil }
func (n noReactions) SetAccessPolicy(AccessPolicy)     {}
func (n noReactions) AccessPolicy() AccessPolicy       { return AccessPolicy{} }
func (n noReactions) SendMessage(ctx context.Context, to, c string, o SendOptions) (SendResult, error) {
	return n.a.SendMessage(ctx, to, c, o)
}
func (n noReactions) SendTyping(ctx context.Context, to string, typing bool) error {
	return n.a.SendTyping(ctx, to, typing)
}
func (n noReactions) ConversationChatIDs(ctx context.Context, id string) ([]string, error) {
	return n.a.ConversationChatIDs(ctx, id)
}

func sendResult(r SendResult, err error) (any, error) {
	if err != nil {
		return nil, err
	}
	return map[string]any{"success": r.Success, "messageId": r.MessageID}, nil
}

func asJSON(v any) string {
	raw, _ := json.Marshal(v)
	var back any
	_ = json.Unmarshal(raw, &back)
	out, _ := json.Marshal(back)
	return string(out)
}

func TestSyncSharedRoutesInstallsAndDropsRoutes(t *testing.T) {
	p := &toolPlatform{}
	m, db, _ := agentToolsManager(t, p)
	ctx := context.Background()
	if _, err := db.W.Exec(`INSERT INTO messaging_identity_links (platform, external_id, chat_id, user_id, agent_id) VALUES ('telegram', '77', 'dm_77', 1, 'main'), ('whatsapp', '1', '1@s.whatsapp.net', 1, 'main')`); err != nil {
		t.Fatal(err)
	}
	if err := m.SyncSharedRoutes(ctx, func(string) Platform { return nil }); err != nil {
		t.Fatal(err)
	}
	if _, ok := m.conns[connKey{1, "main", "telegram"}].platform.(*SharedRoutePlatform); !ok {
		t.Fatal("no route for the telegram link")
	}
	if m.conns[connKey{1, "main", "whatsapp"}].platform != p {
		t.Fatal("a personal connection was replaced")
	}
	if got := m.OwnerDestination(ctx, 1, "main", "telegram"); got != "dm_77" {
		t.Fatalf("owner %q", got)
	}
	_, _ = db.W.Exec(`DELETE FROM messaging_identity_links WHERE platform = 'telegram'`)
	if err := m.SyncSharedRoutes(ctx, nil); err != nil {
		t.Fatal(err)
	}
	if _, ok := m.conns[connKey{1, "main", "telegram"}]; ok {
		t.Fatal("route of a removed link kept")
	}
}
