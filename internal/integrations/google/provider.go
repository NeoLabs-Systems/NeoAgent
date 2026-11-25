// Package google is the official Google Workspace integration: one OAuth
// sign-in that backs Gmail, Calendar, Drive, Docs and Sheets, with their tools
// served over plain REST.
package google

import (
	"context"
	_ "embed"
	"errors"
	"fmt"
	"net/url"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

//go:embed provider.json
var specJSON []byte

var identityScopes = []string{
	"openid",
	"https://www.googleapis.com/auth/userinfo.email",
	"https://www.googleapis.com/auth/userinfo.profile",
}

// appScopes are the scopes each app needs, in the order of the apps.
var appScopes = []struct {
	id     string
	scopes []string
}{
	{"gmail", []string{"https://mail.google.com/"}},
	{"calendar", []string{"https://www.googleapis.com/auth/calendar"}},
	{"drive", []string{"https://www.googleapis.com/auth/drive"}},
	{"docs", []string{"https://www.googleapis.com/auth/documents"}},
	{"sheets", []string{"https://www.googleapis.com/auth/spreadsheets"}},
}

func allWorkspaceScopes() []string {
	scopes := append([]string{}, identityScopes...)
	for _, a := range appScopes {
		scopes = append(scopes, a.scopes...)
	}
	return strings.Fields(oauthclient.JoinScopes(scopes...))
}

// grantedAppIDs are the apps a grant fully covers. One sign-in requests every
// workspace scope, but Google lets the person untick some, so only apps with
// all their scopes granted are connected by it.
func grantedAppIDs(granted []string) []string {
	have := map[string]bool{}
	for _, s := range granted {
		have[s] = true
	}
	var ids []string
	for _, a := range appScopes {
		all := true
		for _, s := range a.scopes {
			all = all && have[s]
		}
		if all {
			ids = append(ids, a.id)
		}
	}
	return ids
}

type provider struct {
	*integrations.OAuthProviderImpl
	svc *integrations.Services
	ep  endpoints
}

// New is the Google Workspace provider.
func New(svc *integrations.Services) integrations.Provider {
	return newProvider(svc, googleEndpoints())
}

func newProvider(svc *integrations.Services, ep endpoints) *provider {
	p := &provider{svc: svc, ep: ep}
	app := integrations.NewOAuthApp(svc, integrations.OAuthAppSpec{
		ProviderKey: "google_workspace",
		Label:       "Google Workspace",
		EnvPrefix:   "GOOGLE",
		// Enables all five APIs in one step, creating a project when there is none.
		ConsoleURL:   "https://console.cloud.google.com/flows/enableapi?apiid=gmail.googleapis.com,calendar-json.googleapis.com,drive.googleapis.com,docs.googleapis.com,sheets.googleapis.com",
		Notes:        "The console button enables the Gmail, Calendar, Drive, Docs and Sheets APIs. Then, under APIs & Services › Credentials, create an OAuth client ID of type Web application with the callback URL as an authorized redirect URI. Set the consent screen to In production: in Testing, Google signs accounts out every 7 days. Continue past the unverified-app warning when you connect.",
		Scopes:       allWorkspaceScopes(),
		Alternatives: []string{"email", "phone"},
	})
	p.OAuthProviderImpl = integrations.NewOAuthProvider(svc, integrations.LoadSpec(specJSON), app, integrations.OAuthHooks{
		Begin:      p.begin,
		Finish:     p.finish,
		Execute:    p.execute,
		Disconnect: p.revoke,
		Sweep:      p.sweep,
		Test: func(ctx context.Context, tc *integrations.ToolContext) error {
			_, err := (&session{p: p, tc: tc}).call(ctx, "GET", p.ep.userinfo, nil, nil)
			return err
		},
	})
	return p
}

func (p *provider) begin(_ context.Context, in integrations.BeginInput) (integrations.BeginResult, error) {
	u, err := oauthclient.AppendQuery(p.ep.auth,
		"access_type", "offline",
		"prompt", "consent",
		// Request the full workspace scope bundle so one durable Google grant
		// can back Gmail, Calendar, Drive, Docs and Sheets for the same account.
		"scope", strings.Join(allWorkspaceScopes(), " "),
		"include_granted_scopes", "true",
		"state", in.State,
		"code_challenge", oauthclient.CodeChallenge(in.CodeVerifier),
		"code_challenge_method", "S256",
		"response_type", "code",
		"client_id", in.OAuth.ClientID,
		"redirect_uri", in.OAuth.RedirectURI)
	// Google's own client writes spaces as %20; any "+" here is a space, since a
	// literal plus is encoded.
	return integrations.BeginResult{URL: strings.ReplaceAll(u, "+", "%20"), AppID: in.App.ID}, err
}

func (p *provider) finish(ctx context.Context, in integrations.FinishInput) (integrations.FinishResult, error) {
	res, err := p.svc.Client("Google").Do(ctx, oauthclient.Request{
		Method: "POST", URL: p.ep.token,
		Form: [][2]string{
			{"code", in.Code}, {"client_id", in.OAuth.ClientID}, {"client_secret", in.OAuth.ClientSecret},
			{"redirect_uri", in.OAuth.RedirectURI}, {"grant_type", "authorization_code"}, {"code_verifier", in.CodeVerifier},
		},
	})
	if err != nil {
		return integrations.FinishResult{}, err
	}
	if res.Status < 200 || res.Status > 299 {
		return integrations.FinishResult{}, tokenError(res)
	}
	tokens := p.tokensFrom(integrations.Object(res.Body))
	tc := &integrations.ToolContext{Credentials: tokens, OAuth: in.OAuth}
	profile, err := (&session{p: p, tc: tc}).call(ctx, "GET", p.ep.userinfo, nil, nil)
	if err != nil {
		return integrations.FinishResult{}, err
	}
	email := strings.TrimSpace(integrations.Str(profile.object()["email"]))
	if email == "" {
		return integrations.FinishResult{}, errors.New("Google OAuth did not return an account email address.")
	}
	scopes := strings.Fields(oauthclient.Credentials(tokens).String("scope"))
	scopes = strings.Fields(oauthclient.JoinScopes(scopes...))
	var also []string
	for _, id := range grantedAppIDs(scopes) {
		if id != in.App.ID {
			also = append(also, id)
		}
	}
	return integrations.FinishResult{
		AppID: in.App.ID, AccountEmail: email, Credentials: tokens, Scopes: scopes,
		Metadata: map[string]any{"appId": in.App.ID}, AlsoConnectsAppIDs: also,
	}, nil
}

// revoke withdraws the grant at Google, preferring the refresh token.
func (p *provider) revoke(ctx context.Context, tc *integrations.ToolContext) error {
	token := tc.Credentials.String("refresh_token")
	if token == "" {
		token = tc.Credentials.String("access_token")
	}
	if token == "" {
		return nil
	}
	res, err := p.svc.Client("Google").Do(ctx, oauthclient.Request{
		Method: "POST", URL: p.ep.revoke + "?token=" + url.QueryEscape(token), NoRetry: true,
	})
	if err != nil {
		return err
	}
	if res.Status < 200 || res.Status > 299 {
		return apiError(res)
	}
	return nil
}

func (p *provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	s := &session{p: p, tc: tc}
	switch tc.AppID {
	case "gmail":
		return s.gmail(ctx, name, args)
	case "calendar":
		return s.calendar(ctx, name, args)
	case "drive":
		return s.drive(ctx, name, args)
	case "docs":
		return s.docs(ctx, name, args)
	case "sheets":
		return s.sheets(ctx, name, args)
	}
	return nil, fmt.Errorf("Unknown tool: %s", name)
}

// Snapshot is the generic snapshot, marked as one sign-in covering every app.
func (p *provider) Snapshot(rows []integrations.Connection, scope integrations.Scope) integrations.Snapshot {
	snap := p.OAuthProviderImpl.Snapshot(rows, scope)
	snap.Extra = map[string]any{"signInCoversAllApps": true}
	return snap
}

func (p *provider) SummarizeForModel(s integrations.Snapshot) string {
	label := p.Info().Label
	if !s.Env.Configured {
		return integrations.DescribeIncompleteSetup(label, s.Env)
	}
	lines := make([]string, 0, len(s.Apps))
	for _, app := range s.Apps {
		switch {
		case app.Connection.Connected:
			names := strings.Join(p.Toolset().NamesForApp(app.ID), ", ")
			lines = append(lines, fmt.Sprintf("- %s: %s. Use built-in tools: %s", app.Label, integrations.FormatAccountSummary(app), names))
		case app.Connection.Status == "authorizing":
			lines = append(lines, fmt.Sprintf("- %s: connection is still being authorized.", app.Label))
		default:
			lines = append(lines, fmt.Sprintf("- %s: not connected yet.", app.Label))
		}
	}
	var head []string
	if !s.Connection.Connected {
		head = []string{label + ": workspace setup is ready, but no app accounts are connected yet. If the user wants to use it, tell them to connect an account in Official Integrations first."}
	} else {
		head = []string{
			label + ": some app-specific native access is connected on this server in this run. Only the listed connected apps are available through built-in tools.",
			"Connected apps: " + integrations.ConnectedAppSummary(s.Apps),
		}
	}
	return strings.Join(append(head, lines...), "\n")
}
