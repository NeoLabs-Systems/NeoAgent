package wiring

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/systemone"
	"github.com/NeoLabs-Systems/neoagent/internal/neorouterapi"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
)

func TestSystemOneUsesOperatorNeoRouter(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer key" {
			t.Error("missing authorization")
		}
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/v1/models":
			_, _ = w.Write([]byte(`{"data":[{"id":"jev","neorouter":{"decision":true}}]}`))
		case "/v1/systemone":
			var input map[string]any
			_ = json.NewDecoder(r.Body).Decode(&input)
			if _, ok := input["questions"].(map[string]any); !ok {
				t.Errorf("questions are not an object: %v", input)
			}
			_, _ = w.Write([]byte(`{"model":"jev","answers":{"ready":{"type":"noul","noul":0.8}},"usage":{}}`))
		default:
			t.Errorf("unexpected path %s", r.URL.Path)
		}
	}))
	defer server.Close()
	t.Setenv("NEOROUTER_BASE_URL", server.URL)
	t.Setenv("NEOROUTER_API_KEY", "key")
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err = db.W.Exec(`INSERT INTO users(id,username,email,password) VALUES(1,'user','u@example.com','hash')`); err != nil {
		t.Fatal(err)
	}
	if _, err = db.W.Exec(`INSERT INTO agents(id,user_id,slug,display_name,is_default) VALUES('main',1,'main','Main',1)`); err != nil {
		t.Fatal(err)
	}
	if _, err = db.W.Exec(`INSERT INTO agent_settings(user_id,agent_id,key,value) VALUES(1,'main','system_one_model','"auto"')`); err != nil {
		t.Fatal(err)
	}
	box, err := secretbox.New("enc:v1:", "test-key")
	if err != nil {
		t.Fatal(err)
	}
	store := settings.New(settings.Config{DB: db, Box: box}).Store
	nr := neorouterapi.New(neorouterapi.Config{Env: envAdapter{getenv: func(k string) string {
		return map[string]string{"NEOROUTER_BASE_URL": server.URL, "NEOROUTER_API_KEY": "key"}[k]
	}}, Settings: nrSettingsAdapter{store: store}})
	defer nr.Stop()
	failures := &aimodels.Failures{Cooldowns: aimodels.DefaultCooldowns()}
	catalog := settingsCatalogAdapter{store: store, nr: nr}
	svc := systemone.Service{Source: systemOneSource{store: store, catalog: catalog, router: nr, failures: failures}}
	answers, err := svc.Decide(ctx, systemone.Request{UserID: 1, AgentID: "main", State: map[string]any{"x": 1}, Questions: map[string]any{"ready": map[string]any{"type": "noul"}}})
	if err != nil || answers["ready"].(map[string]any)["noul"] != 0.8 {
		t.Fatalf("answers %v error %v", answers, err)
	}
}
