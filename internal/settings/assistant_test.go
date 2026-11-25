package settings_test

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"os"
	"path/filepath"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

type fixedModels struct{ chat, decisions []map[string]any }

func (m fixedModels) ChatModels(context.Context, int64, string) ([]map[string]any, error) {
	return m.chat, nil
}
func (m fixedModels) SystemOneModels(context.Context, int64, string) ([]map[string]any, error) {
	return m.decisions, nil
}

type fixedIntegrations struct{}

func (fixedIntegrations) List(context.Context, int64, string) ([]settings.Integration, error) {
	return []settings.Integration{{Key: "google", Label: "Google", Connected: true, Available: true}, {Key: "notion", Label: "Notion"}}, nil
}
func (fixedIntegrations) Keys() []string { return []string{"google", "notion"} }

func canon(t *testing.T, v any) string {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	var back any
	_ = json.Unmarshal(raw, &back)
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(back)
	return buf.String()
}

// TestAssistantToolsMatchNode replays settings_read/update/link recorded from
// Node on the same seeded database (testdata/gen_assistant.js).
func TestAssistantToolsMatchNode(t *testing.T) {
	raw, err := os.ReadFile("testdata/assistant_vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var v struct {
		Models, Decisions []map[string]any
		Cases             []struct {
			Tool    string          `json:"tool"`
			Args    map[string]any  `json:"args"`
			Result  json.RawMessage `json:"result"`
			Emitted []struct {
				Payload struct {
					Keys []string `json:"keys"`
				} `json:"payload"`
			} `json:"emitted"`
		}
	}
	if err := json.Unmarshal(raw, &v); err != nil {
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
		"INSERT INTO users (id, username, password) VALUES (1, 'u', 'x')",
		"INSERT INTO agents (id, user_id, slug, display_name, is_default) VALUES ('a1', 1, 'main', 'Main', 1)",
	} {
		if _, err := db.W.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	store := settings.New(settings.Config{DB: db, Log: slog.Default(), RuntimeBackend: settings.RuntimeBackendFor("")}).Store
	var changed []string
	tools := &settings.AssistantTools{
		Assistant:    &settings.Assistant{Store: store, Models: fixedModels{v.Models, v.Decisions}, BaseURL: func() string { return "https://agent.example" }},
		Integrations: fixedIntegrations{},
		Changed:      func(_ int64, _ string, key string) { changed = append(changed, key) },
	}
	for i, c := range v.Cases {
		changed = nil
		var got any
		switch c.Tool {
		case "settings_read":
			got, err = tools.Read(ctx, 1, "a1", c.Args)
		case "settings_update":
			got, err = tools.Update(ctx, 1, "a1", c.Args)
		case "settings_link":
			got, err = tools.Link(ctx, c.Args)
		}
		if err != nil {
			t.Fatalf("#%d %s: %v", i, c.Tool, err)
		}
		var want any
		_ = json.Unmarshal(c.Result, &want)
		if g, w := canon(t, got), canon(t, want); g != w {
			t.Errorf("#%d %s:\n got: %s\nwant: %s", i, c.Tool, g, w)
		}
		var wantChanged []string
		for _, e := range c.Emitted {
			wantChanged = append(wantChanged, e.Payload.Keys...)
		}
		if canon(t, changed) != canon(t, wantChanged) {
			t.Errorf("#%d changed %v want %v", i, changed, wantChanged)
		}
	}
}
