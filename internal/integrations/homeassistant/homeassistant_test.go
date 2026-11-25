package homeassistant

import (
	"context"
	"encoding/json"
	"net"
	"net/netip"
	"reflect"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/integrationstest"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/replaytest"
)

type vectors struct {
	Steps []struct {
		replaytest.Step
		Tool        string         `json:"tool"`
		Args        map[string]any `json:"args"`
		Credentials map[string]any `json:"credentials"`
		Op          string         `json:"op"`
		Config      map[string]any `json:"config"`
	} `json:"steps"`
	RowsAfterSave []map[string]any `json:"rowsAfterSave"`
}

func lookup(_ context.Context, host string) ([]netip.Addr, error) {
	switch host {
	case "ha.example":
		return []netip.Addr{netip.MustParseAddr("93.184.216.34")}, nil
	case "private.example":
		return []netip.Addr{netip.MustParseAddr("10.0.0.5")}, nil
	}
	return nil, &net.DNSError{Err: "no such host", Name: host, IsNotFound: true}
}

// TestMatchesNode replays the Node provider's recorded calls.
func TestMatchesNode(t *testing.T) {
	var v vectors
	replaytest.Load(t, &v)
	tr := &replaytest.Transport{}
	var p *provider
	st := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		p = New(svc, Options{HTTP: tr.Client(), Lookup: lookup}).(*provider)
		return []integrations.Provider{p}
	}, integrations.Hooks{})
	ctx := context.Background()
	agent, err := st.Svc.ResolveAgent(ctx, 1, "")
	if err != nil {
		t.Fatal(err)
	}
	scope := integrations.Scope{UserID: 1, AgentID: agent}
	for _, step := range v.Steps {
		tr.Script(step.Answers)
		var got any
		var err error
		switch {
		case step.Tool != "":
			sealed, _ := st.Svc.Seal(mustJSON(step.Credentials))
			var ex *integrations.Execution
			ex, err = p.ExecuteTool(ctx, step.Tool, step.Args, integrations.Connection{ID: 1, UserID: 1, AgentID: agent, ProviderKey: providerKey, AppKey: appID, Status: "connected", CredentialsJSON: sealed})
			if ex != nil {
				got = ex.Result
			}
		case step.Op == "get":
			got, err = p.SetupConfig(ctx, scope)
		case step.Op == "save":
			got, err = p.SaveSetup(ctx, scope, step.Config)
			if step.Name == "save keeps token, renamed instance" {
				checkRows(t, st, v.RowsAfterSave)
			}
		case step.Op == "clear":
			err = p.ClearSetup(ctx, scope)
			got = map[string]any{"cleared": true}
		}
		replaytest.Check(t, step.Step, got, err)
		replaytest.CheckRequests(t, step.Step, tr.Requests())
	}
}

func checkRows(t *testing.T, st *integrationstest.Stack, want []map[string]any) {
	t.Helper()
	all, err := st.DB.R.Query(`SELECT app_key, status, account_email, scopes_json, metadata_json, credentials_json FROM integration_connections WHERE provider_key = ? ORDER BY id`, providerKey)
	if err != nil {
		t.Fatal(err)
	}
	defer all.Close()
	var got []map[string]any
	for all.Next() {
		var app, status, email, scopes, meta, creds string
		if err := all.Scan(&app, &status, &email, &scopes, &meta, &creds); err != nil {
			t.Fatal(err)
		}
		plain, _ := st.Box.Open(creds)
		got = append(got, map[string]any{"app_key": app, "status": status, "account_email": email,
			"scopes_json": decode(scopes), "metadata_json": decode(meta), "credentials_json": decode(plain)})
	}
	for _, w := range want {
		w["scopes_json"] = decode(w["scopes_json"].(string))
		w["metadata_json"] = decode(w["metadata_json"].(string))
	}
	if !reflect.DeepEqual(replaytest.Normalize(t, got), replaytest.Normalize(t, want)) {
		t.Errorf("rows\n got %s\nwant %s", mustJSON(got), mustJSON(want))
	}
}

func decode(s string) any {
	var v any
	_ = json.Unmarshal([]byte(s), &v)
	return v
}
