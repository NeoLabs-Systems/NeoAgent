package wiring

import (
	"context"
	"path/filepath"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/commands"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

func TestCommandRouterReachesItsDomains(t *testing.T) {
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "commands.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	for _, q := range []string{`INSERT INTO users(id,username,password) VALUES(1,'owner','x')`,
		`INSERT INTO agents(id,user_id,slug,display_name,is_default) VALUES('a1',1,'main','Main',1)`,
		`INSERT INTO user_settings(user_id,key,value) VALUES(1,'ui_language','"de"')`,
		`INSERT INTO agent_settings(user_id,agent_id,key,value) VALUES(1,'a1','web_chat_summary','"old"')`} {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	store := &settings.Store{DB: db}
	router := commands.New(commands.Config{DB: db, Agents: agentscope.Resolver{DB: db}, Messages: fixedMessages{store}, Engine: commandEngine{link: &engineLink{}},
		Summaries: webSummaries{db: db}})

	stop, err := router.Dispatch(ctx, "/stop", commands.Context{UserID: 1, AgentID: "a1", Source: "messaging"})
	if err != nil || !stop.Handled || stop.Content != "Gestoppt." {
		t.Fatalf("stop: %+v %v", stop, err)
	}
	status, _ := router.Dispatch(ctx, "/status", commands.Context{UserID: 1, AgentID: "a1", Source: "web"})
	if !strings.HasPrefix(status.Content, "**Status**\n- Active runs: 0") {
		t.Fatalf("status: %q", status.Content)
	}
	cleared, _ := router.Dispatch(ctx, "!clear", commands.Context{UserID: 1, AgentID: "a1", Source: "messaging", Platform: "telegram", ChatID: "1"})
	if cleared.Content != "Kontext gelöscht. Neuer Anfang." {
		t.Fatalf("clear: %+v", cleared)
	}
	var n int
	_ = db.R.QueryRow(`SELECT COUNT(*) FROM agent_settings WHERE key = 'web_chat_summary'`).Scan(&n)
	cleared, _ = router.Dispatch(ctx, "/clear", commands.Context{UserID: 1, AgentID: "a1", Source: "http"})
	_ = db.R.QueryRow(`SELECT COUNT(*) FROM agent_settings WHERE key = 'web_chat_summary'`).Scan(&n)
	if !cleared.Handled || n != 0 {
		t.Fatalf("web summary kept: %d %+v", n, cleared)
	}
}
