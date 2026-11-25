// Package companiontest replays the recorded Node calls of a companion
// provider (NeoCloud, NeoRecall).
package companiontest

import (
	"context"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/integrationstest"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/replaytest"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

// ReplayVectors are the recorded steps of a companion provider.
type ReplayVectors struct {
	Now      int64  `json:"now"`
	State    string `json:"state"`
	Verifier string `json:"verifier"`
	Steps    []struct {
		replaytest.Step
		Op          string         `json:"op"`
		Config      map[string]any `json:"config"`
		Code        string         `json:"code"`
		Tool        string         `json:"tool"`
		Args        map[string]any `json:"args"`
		Credentials map[string]any `json:"credentials"`
		Scopes      []string       `json:"scopes"`
		Metadata    map[string]any `json:"metadata"`
	} `json:"steps"`
}

// Replay runs a companion provider's recorded steps; build makes the provider
// with the given HTTP client and clock. It is shared by the provider tests.
func Replay(t *testing.T, build func(svc *integrations.Services, tr *replaytest.Transport, now func() time.Time) integrations.Provider) {
	t.Helper()
	var v ReplayVectors
	replaytest.Load(t, &v)
	now := func() time.Time { return time.UnixMilli(v.Now) }
	tr := &replaytest.Transport{}
	var p integrations.Provider
	st := integrationstest.New(t, func(svc *integrations.Services) []integrations.Provider {
		p = build(svc, tr, now)
		return []integrations.Provider{p}
	}, integrations.Hooks{})
	ctx := context.Background()
	agent, err := st.Svc.ResolveAgent(ctx, 1, "")
	if err != nil {
		t.Fatal(err)
	}
	scope := integrations.Scope{UserID: 1, AgentID: agent}
	app := p.Info().Apps[0].ID
	conn := func(creds map[string]any, scopes []string, meta map[string]any) integrations.Connection {
		sealed, _ := st.Svc.Seal(string(must(oauthclient.MarshalJS(creds))))
		if scopes == nil {
			scopes = []string{}
		}
		if meta == nil {
			meta = map[string]any{}
		}
		return integrations.Connection{ID: 1, UserID: 1, AgentID: agent, ProviderKey: p.Info().Key, AppKey: app, Status: "connected",
			AccountEmail: "acct", ScopesJSON: string(must(oauthclient.MarshalJS(scopes))), MetadataJSON: string(must(oauthclient.MarshalJS(meta))), CredentialsJSON: sealed}
	}
	setup := p.(interface {
		integrations.SetupReader
		integrations.SetupSaver
		integrations.SetupClearer
	})
	oauth := p.(integrations.OAuthProvider)
	for _, step := range v.Steps {
		tr.Script(step.Answers)
		var got any
		var err error
		switch step.Op {
		case "get":
			got, err = setup.SetupConfig(ctx, scope)
		case "env":
			got = p.EnvStatus(scope)
		case "save":
			got, err = setup.SaveSetup(ctx, scope, step.Config)
		case "clear":
			err = setup.ClearSetup(ctx, scope)
			got = map[string]any{"cleared": true}
		case "begin":
			var r integrations.BeginResult
			r, err = oauth.BeginOAuth(ctx, integrations.BeginParams{State: v.State, CodeVerifier: v.Verifier, Scope: scope, AppKey: app})
			got = map[string]any{"url": r.URL}
		case "finish":
			var r integrations.FinishResult
			r, err = oauth.FinishOAuth(ctx, integrations.FinishParams{Code: step.Code, CodeVerifier: v.Verifier, State: v.State, Scope: scope, AppKey: app})
			got = map[string]any{"accountEmail": r.AccountEmail, "scopes": r.Scopes, "credentials": r.Credentials, "metadata": r.Metadata}
		case "exec":
			var ex *integrations.Execution
			ex, err = p.ExecuteTool(ctx, step.Tool, step.Args, conn(step.Credentials, step.Scopes, nil))
			if ex != nil {
				creds := map[string]any(ex.Credentials)
				if creds == nil {
					creds = step.Credentials
				}
				got = map[string]any{"result": ex.Result, "credentials": creds}
			}
		case "test":
			var creds oauthclient.Credentials
			creds, err = p.(integrations.Tester).TestConnection(ctx, conn(step.Credentials, nil, nil))
			got = map[string]any{"credentials": creds}
		case "disconnect":
			err = p.(integrations.Disconnector).Disconnect(ctx, conn(step.Credentials, nil, nil))
		case "filter":
			var names []string
			for _, tool := range p.Tools([]string{app}, []integrations.Connection{conn(map[string]any{}, step.Scopes, step.Metadata)}) {
				names = append(names, tool.Name)
			}
			if names == nil {
				names = []string{}
			}
			got = names
		case "upsert":
			sealed, _ := st.Svc.Seal(string(must(oauthclient.MarshalJS(step.Credentials))))
			if err := st.Svc.UpsertConnection(ctx, integrations.ConnectedAccount{UserID: 1, AgentID: agent, ProviderKey: p.Info().Key, AppKey: app,
				AccountEmail: "u@example.com", Scopes: []string{}, CredentialsJSON: sealed, Metadata: map[string]any{}}); err != nil {
				t.Fatal(err)
			}
			continue
		default:
			t.Fatalf("unknown op %q", step.Op)
		}
		replaytest.Check(t, step.Step, got, err)
		replaytest.CheckRequests(t, step.Step, tr.Requests())
	}
}

func must(raw []byte, err error) []byte {
	if err != nil {
		panic(err)
	}
	return raw
}
