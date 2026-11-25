package replaytest

import (
	"context"
	"encoding/json"
	"reflect"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/integrationstest"
)

// ProviderStep is a recorded tool call (Tool set) or setup operation (Op
// set: get, save or clear) with the rows the operation left behind.
type ProviderStep struct {
	Step
	Tool        string           `json:"tool"`
	Args        map[string]any   `json:"args"`
	Credentials map[string]any   `json:"credentials"`
	Metadata    map[string]any   `json:"metadata"`
	Op          string           `json:"op"`
	Config      map[string]any   `json:"config"`
	Rows        []map[string]any `json:"rows"`
}

// Now is the clock the Node recordings ran with (2026-01-01T12:00:00Z).
var Now = time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC)

// Stack is a test server whose outbound requests go to the transport.
func Stack(t *testing.T, providers func(*integrations.Services) []integrations.Provider) (*integrationstest.Stack, *Transport) {
	t.Helper()
	tr := &Transport{}
	s := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		svc.HTTP = tr.Client()
		svc.SelfHosted = tr.Client()
		svc.Now = func() time.Time { return Now }
		return providers(svc)
	}, integrations.Hooks{})
	return s, tr
}

// RunProvider replays every step against p.
func RunProvider(t *testing.T, s *integrationstest.Stack, tr *Transport, p integrations.Provider, appKey string, steps []ProviderStep) {
	t.Helper()
	ctx := context.Background()
	scope := integrations.Scope{UserID: 1, AgentID: s.MainAgent(t, 1)}
	for _, step := range steps {
		tr.Script(step.Answers)
		var got any
		var err error
		switch {
		case step.Tool != "":
			creds, _ := json.Marshal(step.Credentials)
			sealed, sealErr := s.Box.Seal(string(creds))
			if sealErr != nil {
				t.Fatal(sealErr)
			}
			meta, _ := json.Marshal(step.Metadata)
			conn := integrations.Connection{ID: 1, UserID: 1, AgentID: scope.AgentID, ProviderKey: p.Info().Key, AppKey: appKey,
				Status: "connected", AccountEmail: "acct", CredentialsJSON: sealed, MetadataJSON: string(meta)}
			var ex *integrations.Execution
			ex, err = p.ExecuteTool(ctx, step.Tool, step.Args, conn)
			if err == nil {
				got = ex.Result
			}
		case step.Op == "get":
			got, err = p.(integrations.SetupReader).SetupConfig(ctx, scope)
		case step.Op == "save":
			cfg := step.Config
			if cfg == nil {
				cfg = map[string]any{}
			}
			got, err = p.(integrations.SetupSaver).SaveSetup(ctx, scope, cfg)
		case step.Op == "clear":
			err = p.(integrations.SetupClearer).ClearSetup(ctx, scope)
			if err == nil {
				got = map[string]any{"cleared": true}
			}
		default:
			t.Fatalf("%s: step has neither tool nor op", step.Name)
		}
		Check(t, step.Step, got, err)
		CheckRequests(t, step.Step, tr.Requests())
		if step.Op != "" {
			checkRows(t, s, p.Info().Key, step)
		}
	}
}

func checkRows(t *testing.T, s *integrationstest.Stack, providerKey string, step ProviderStep) {
	t.Helper()
	rows, err := s.DB.R.Query(`SELECT app_key, status, account_email, scopes_json, metadata_json, credentials_json
		FROM integration_connections WHERE provider_key = ? ORDER BY id`, providerKey)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	var got []map[string]any
	for rows.Next() {
		var app, status, email, scopes, meta, creds string
		if err := rows.Scan(&app, &status, &email, &scopes, &meta, &creds); err != nil {
			t.Fatal(err)
		}
		row := map[string]any{"app_key": app, "status": status, "account_email": email}
		row["scopes_json"] = decodeText(scopes)
		row["metadata_json"] = decodeText(meta)
		if plain, err := s.Box.Open(creds); err == nil {
			row["credentials_json"] = decodeText(plain)
		} else {
			row["credentials_json"] = decodeText(creds)
		}
		got = append(got, row)
	}
	want := step.Rows
	if want == nil {
		want = []map[string]any{}
	}
	if got == nil {
		got = []map[string]any{}
	}
	g, w := normalizeAny(got), normalizeAny(want)
	if !reflect.DeepEqual(g, w) {
		t.Errorf("%s: rows\n got %s\nwant %s", step.Name, mustJSON(g), mustJSON(w))
	}
}

func decodeText(s string) any {
	var v any
	if json.Unmarshal([]byte(s), &v) != nil {
		return s
	}
	return v
}

func normalizeAny(v any) any {
	raw, _ := json.Marshal(v)
	var out any
	_ = json.Unmarshal(raw, &out)
	return out
}
