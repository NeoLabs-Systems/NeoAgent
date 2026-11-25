package handlers

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// coreOnlyMemory answers the one memory question the scenarios ask.
type coreOnlyMemory struct{ Memory }

func (coreOnlyMemory) CoreKeys() []string {
	return []string{"user_profile", "preferences", "ai_personality"}
}

func seededDB(t *testing.T) *dbx.DB {
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
		"INSERT INTO agents (id, user_id, slug, display_name) VALUES ('a1', 1, 'main', 'Main')",
		`INSERT INTO messages (id, user_id, role, content, platform, platform_chat_id, metadata, created_at) VALUES
    (1, 1, 'user', 'hello there', 'telegram', '100', '{"senderName":"Ann","isGroup":false}', '2026-01-01 10:00:00'),
    (2, 1, 'user', 'group talk', 'telegram', '-200', '{"groupName":"Family Chat","senderName":"Bob","isGroup":"true"}', '2026-01-01 11:00:00'),
    (3, 1, 'assistant', 'reply', 'telegram', '100', NULL, '2026-01-01 12:00:00'),
    (4, 1, 'user', 'web msg', 'web', 'w1', NULL, '2026-01-01 13:00:00'),
    (5, 1, 'user', 'wa hi', 'whatsapp', '4915@s.whatsapp.net', 'not json', '2026-01-01 14:00:00'),
    (6, 1, 'user', 'more family', 'telegram', '-200', '{"group_name":"Family Chat","sender_name":"Cy","isGroup":1}', '2026-01-02 09:00:00'),
    (7, 1, 'user', 'discord', 'discord', 'c9', '{"guildName":"  Guild  ","chatName":"x"}', '2026-01-02 10:00:00')`,
		`INSERT INTO mcp_servers (id, user_id, agent_id, name, command, config, enabled) VALUES
    (1, 1, 'a1', 'zeta', 'https://z.example/mcp', '{"args":["--x"]}', 1),
    (2, 1, 'a1', 'alpha', 'https://a.example/mcp', NULL, 0)`,
	} {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	return db
}

// TestHandlersMatchNodeScenarios replays the handler calls recorded from the
// Node handlers on the same seeded database (testdata/gen_scenarios.js).
func TestHandlersMatchNodeScenarios(t *testing.T) {
	raw, err := os.ReadFile("testdata/node_scenarios.json")
	if err != nil {
		t.Fatal(err)
	}
	var cases []struct {
		Tool   string          `json:"tool"`
		Args   dyn.Map         `json:"args"`
		Result json.RawMessage `json:"result"`
	}
	if err := json.Unmarshal(raw, &cases); err != nil {
		t.Fatal(err)
	}
	b := New(Deps{DB: seededDB(t)})
	run := &Run{UserID: 1, AgentID: "a1"}
	for i, c := range cases {
		backend := b
		if c.Tool == "memory_update_core" {
			backend = New(Deps{Memory: coreOnlyMemory{}})
		}
		got, err := backend.ExecuteFor(context.Background(), run, c.Tool, c.Args, "")
		if err != nil {
			got = dyn.Map{"thrown": err.Error()}
		}
		same(t, "#"+itoa(i)+" "+c.Tool, got, c.Result)
	}
}

func TestPublicRunsAreConfined(t *testing.T) {
	b := New(Deps{})
	run := &Run{UserID: 1, Public: &PublicScope{Platform: "slack", ChatID: "C1", ToolNames: map[string]bool{"send_message": true}}}
	ctx := context.Background()
	got, _ := b.ExecuteFor(ctx, run, "memory_save", dyn.Map{}, "")
	same(t, "tool", got, json.RawMessage(`{"error":"memory_save is not available when answering a public slack thread."}`))
	got, _ = b.ExecuteFor(ctx, run, "send_message", dyn.Map{"to": "C2"}, "")
	same(t, "target", got, json.RawMessage(`{"error":"Replies from this run can only go to slack C1."}`))
	got, _ = b.ExecuteFor(ctx, run, "send_message", dyn.Map{"media_path": "x"}, "")
	same(t, "media", got, json.RawMessage(`{"error":"Attachments cannot be sent into a public thread."}`))
}

func TestDiscardedArgumentsAndUnknownTools(t *testing.T) {
	b := New(Deps{})
	run := &Run{UserID: 1}
	ctx := context.Background()
	got, _ := b.ExecuteFor(ctx, run, "write_file", dyn.Map{"_discarded": "too long"}, "")
	same(t, "discarded", got, json.RawMessage(`{"success":false,"error":"too long"}`))
	got, _ = b.ExecuteFor(ctx, run, "nope", dyn.Map{}, "")
	same(t, "unknown", got, json.RawMessage(`{"error":"Unknown tool: nope. It is not part of this run's toolset.","recovery":"Use search_tools with a capability description, activate the result with activate_tools, then retry with the exact name."}`))
}
