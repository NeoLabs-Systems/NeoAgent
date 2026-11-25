package wiring

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
)

// The GitHub chat platform reads its token and polling cursors through these
// adapters; with none wired, restoring a GitHub connection crashed the server.
func TestGitHubMentionsTokenAndCursors(t *testing.T) {
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "github.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id,username,email,password) VALUES (1,'user','u@example.com','hash')`); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO agents (id,user_id,slug,display_name,is_default) VALUES ('main',1,'main','Main',1)`); err != nil {
		t.Fatal(err)
	}
	box, err := secretbox.New("enc:v1:", "test-key")
	if err != nil {
		t.Fatal(err)
	}
	creds := githubMentions{integrations.NewServices(db, box)}

	if token, err := creds.MentionsToken(ctx, 1, "main"); err != nil || token != "" {
		t.Fatalf("no connection: token=%q err=%v", token, err)
	}
	sealed, err := box.Seal(`{"access_token":"gho_test"}`)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO integration_connections (user_id, agent_id, provider_key, app_key, status, credentials_json)
		VALUES (1, 'main', 'github', 'mentions', 'connected', ?)`, sealed); err != nil {
		t.Fatal(err)
	}
	if token, err := creds.MentionsToken(ctx, 1, "main"); err != nil || token != "gho_test" {
		t.Fatalf("connected: token=%q err=%v", token, err)
	}

	cursors := githubCursors{db}
	if got, err := cursors.Load(ctx, 1, "main"); err != nil || len(got) != 0 {
		t.Fatalf("empty cursors: %v %v", got, err)
	}
	if err := cursors.Save(ctx, 1, "main", map[string]string{"o/r": "2026-11-25T00:00:00Z"}); err != nil {
		t.Fatal(err)
	}
	if got, err := cursors.Load(ctx, 1, "main"); err != nil || got["o/r"] != "2026-11-25T00:00:00Z" {
		t.Fatalf("saved cursors: %v %v", got, err)
	}
	if name := agentDisplayName(db)(1, "main"); name != "Main" {
		t.Fatalf("agent name %q", name)
	}
}
