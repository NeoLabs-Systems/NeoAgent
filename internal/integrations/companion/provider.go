package companion

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

// Product is what differs between the companion servers.
type Product struct {
	Spec   integrations.Spec
	Server Server
	// Summaries for the setup state: ready and missing.
	ReadySummary, MissingSummary string
	// HealthCheck confirms baseURL is a healthy server of this product.
	HealthCheck func(ctx context.Context, s Server, baseURL string) error
	// AuthorizeScope is the scope the authorization URL asks for.
	AuthorizeScope func(boot map[string]any) string
	// GrantedScopes reads the scopes the token response granted; an error
	// stops the sign-in.
	GrantedScopes func(issued, info map[string]any) ([]string, string, error)
	// Execute runs a tool with an authenticated session.
	Execute func(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error)
	// FilterTools narrows the tools to what the connections may use; optional.
	FilterTools func(tools []integrations.Tool, connections []integrations.Connection) []integrations.Tool
	Summarize   func(integrations.Snapshot) string
}

// Provider is a companion integration.
type Provider struct {
	*integrations.AccountProvider
	svc *integrations.Services
	pr  Product
}

// NewProvider builds a companion provider.
func NewProvider(svc *integrations.Services, pr Product) *Provider {
	p := &Provider{svc: svc, pr: pr}
	p.AccountProvider = integrations.NewAccountProvider(svc, pr.Spec, integrations.AccountHooks{
		Env:     p.env,
		Execute: pr.Execute,
		Test:    p.test,
		Disconnect: func(ctx context.Context, tc *integrations.ToolContext) error {
			return pr.Server.Revoke(ctx, tc.Credentials)
		},
		Summarize: pr.Summarize,
	})
	return p
}

// Server is the product's server client.
func (p *Provider) Server() Server { return p.pr.Server }

// Tools narrows the tools to the connections' grants when the product does.
func (p *Provider) Tools(connectedApps []string, connections []integrations.Connection) []integrations.Tool {
	tools := p.AccountProvider.Tools(connectedApps, connections)
	if connections != nil && p.pr.FilterTools != nil {
		return p.pr.FilterTools(tools, connections)
	}
	return tools
}

func (p *Provider) key() string { return p.pr.Spec.Key }

func (p *Provider) storedBaseURL(ctx context.Context, scope integrations.Scope) string {
	if scope.UserID <= 0 {
		return ""
	}
	return Text(p.svc.ProviderConfig(ctx, scope, p.key())["baseUrl"])
}

func (p *Provider) env(scope integrations.Scope) integrations.Env {
	if p.storedBaseURL(context.Background(), scope) != "" {
		return integrations.Env{Configured: true, Missing: []string{}, Summary: p.pr.ReadySummary, SetupMode: "user"}
	}
	return integrations.Env{Missing: []string{"baseUrl"}, Summary: p.pr.MissingSummary, SetupMode: "user"}
}

func (p *Provider) callbackURL() string {
	return p.svc.PublicBaseURL() + "/api/integrations/oauth/callback"
}

// client is the companion client the server registered for this NeoAgent.
type client struct {
	baseURL, clientID, redirectURI string
	boot                           map[string]any
}

func (p *Provider) client(ctx context.Context, scope integrations.Scope) (client, error) {
	baseURL, err := p.pr.Server.NormalizeBaseURL(p.storedBaseURL(ctx, scope))
	if err != nil {
		return client{}, err
	}
	redirect := p.callbackURL()
	boot, err := p.pr.Server.Bootstrap(ctx, baseURL, redirect)
	if err != nil {
		return client{}, err
	}
	if r := Text(boot["redirectUri"]); r != "" {
		redirect = r
	}
	return client{baseURL: baseURL, clientID: Text(boot["clientId"]), redirectURI: redirect, boot: boot}, nil
}

// BeginOAuth authorises against the configured URL, not one bootstrap
// advertises: the browser must reach the host NeoAgent was set up with.
func (p *Provider) BeginOAuth(ctx context.Context, bp integrations.BeginParams) (integrations.BeginResult, error) {
	app, err := p.checkFlow(bp.AppKey, bp.State)
	if err != nil {
		return integrations.BeginResult{}, err
	}
	if env := p.EnvStatus(bp.Scope); !env.Configured {
		return integrations.BeginResult{}, errors.New(env.Summary)
	}
	c, err := p.client(ctx, bp.Scope)
	if err != nil {
		return integrations.BeginResult{}, err
	}
	u, err := oauthclient.AppendQuery(c.baseURL+"/oauth/authorize",
		"response_type", "code", "client_id", c.clientID, "redirect_uri", c.redirectURI, "state", strings.TrimSpace(bp.State),
		"code_challenge", oauthclient.CodeChallenge(bp.CodeVerifier), "code_challenge_method", "S256",
		"scope", p.pr.AuthorizeScope(c.boot))
	return integrations.BeginResult{URL: u, AppID: app.ID}, err
}

func (p *Provider) checkFlow(appKey, state string) (integrations.App, error) {
	app, ok := p.App(appKey)
	if !ok {
		return integrations.App{}, fmt.Errorf("Unknown %s app: %s", p.pr.Spec.Label, appKey)
	}
	if !oauthState(strings.TrimSpace(state)) {
		return integrations.App{}, errors.New("Invalid OAuth state format. Please restart the connection flow.")
	}
	return app, nil
}

func oauthState(s string) bool {
	if len(s) < 32 || len(s) > 128 {
		return false
	}
	for _, c := range strings.ToLower(s) {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
			return false
		}
	}
	return true
}

// FinishOAuth exchanges the code and names the account.
func (p *Provider) FinishOAuth(ctx context.Context, fp integrations.FinishParams) (integrations.FinishResult, error) {
	app, err := p.checkFlow(fp.AppKey, fp.State)
	if err != nil {
		return integrations.FinishResult{}, err
	}
	s := p.pr.Server
	c, err := p.client(ctx, fp.Scope)
	if err != nil {
		return integrations.FinishResult{}, err
	}
	issued, err := s.Token(ctx, c.baseURL, [][2]string{{"grant_type", "authorization_code"}, {"client_id", c.clientID}, {"code", Text(fp.Code)},
		{"redirect_uri", c.redirectURI}, {"code_verifier", Text(fp.CodeVerifier)}})
	if err != nil {
		return integrations.FinishResult{}, err
	}
	access, refresh := Text(issued["access_token"]), Text(issued["refresh_token"])
	if access == "" || refresh == "" {
		return integrations.FinishResult{}, fmt.Errorf("%s did not return durable OAuth credentials.", s.Label)
	}
	info, err := s.Userinfo(ctx, c.baseURL, access)
	if err != nil {
		return integrations.FinishResult{}, err
	}
	scopes, scopeText, err := p.pr.GrantedScopes(issued, info)
	if err != nil {
		return integrations.FinishResult{}, err
	}
	account := Text(info["email"])
	if account == "" {
		account = Text(info["preferred_username"])
	}
	if account == "" {
		sub := Text(info["sub"])
		if sub == "" {
			sub = Host(c.baseURL)
		}
		account = p.key() + ":" + sub
	}
	var email any
	if e := Text(info["email"]); e != "" {
		email = e
	}
	return integrations.FinishResult{
		AppID: app.ID, AccountEmail: account, Scopes: scopes,
		Credentials: oauthclient.Credentials{
			"baseUrl": c.baseURL, "client_id": c.clientID, "access_token": access, "refresh_token": refresh,
			"scope": scopeText, "expires_at_ms": s.ExpiresAtMs(issued["expires_in"]),
		},
		Metadata: map[string]any{"baseUrl": c.baseURL, "username": Text(info["preferred_username"]), "email": email},
	}, nil
}

// test renews the token when needed and asks who the account is.
func (p *Provider) test(ctx context.Context, tc *integrations.ToolContext) error {
	auth, err := p.pr.Server.Authenticate(ctx, tc.Credentials)
	if err != nil {
		return err
	}
	if _, err := p.pr.Server.Userinfo(ctx, auth.BaseURL, auth.AccessToken); err != nil {
		return err
	}
	tc.UpdateCredentials(auth.Credentials)
	return nil
}

// ---- setup -------------------------------------------------------------------

type setupView struct {
	BaseURL             string `json:"baseUrl"`
	Configured          bool   `json:"configured"`
	AccountCount        int    `json:"accountCount"`
	HasConnectedAccount bool   `json:"hasConnectedAccount"`
}

// SetupConfig is the setup document.
func (p *Provider) SetupConfig(ctx context.Context, scope integrations.Scope) (any, error) {
	rows, err := p.svc.ListConnections(ctx, scope.UserID, p.key(), scope.AgentID)
	if err != nil {
		return nil, err
	}
	count := 0
	for _, r := range rows {
		if r.Status == "connected" {
			count++
		}
	}
	base := p.storedBaseURL(ctx, scope)
	return setupView{BaseURL: base, Configured: base != "", AccountCount: count, HasConnectedAccount: count > 0}, nil
}

// SaveSetup checks the server and its companion contract before storing it;
// accounts of a previous server are revoked and removed.
func (p *Provider) SaveSetup(ctx context.Context, scope integrations.Scope, config map[string]any) (any, error) {
	s := p.pr.Server
	existing := p.storedBaseURL(ctx, scope)
	candidate := Text(config["baseUrl"])
	if candidate == "" {
		candidate = existing
	}
	baseURL, err := s.NormalizeBaseURL(candidate)
	if err != nil {
		return nil, err
	}
	if err := p.pr.HealthCheck(ctx, s, baseURL); err != nil {
		return nil, err
	}
	boot, err := s.Bootstrap(ctx, baseURL, p.callbackURL())
	if err != nil {
		detail := Text(err.Error())
		if detail == "" {
			detail = "companion bootstrap failed"
		}
		return nil, fmt.Errorf("%s rejected NeoAgent OAuth setup (%s). Confirm NeoAgent PUBLIC_URL is reachable from this browser and uses HTTPS, or HTTP on a private/loopback address, ending at /api/integrations/oauth/callback.", s.Label, detail)
	}
	if Text(boot["companion"]) != "neoagent" || Text(boot["clientId"]) == "" {
		return nil, fmt.Errorf("The %s server does not expose the NeoAgent companion OAuth contract.", s.Label)
	}
	if err := p.svc.SetProviderConfig(ctx, scope, p.key(), map[string]any{"baseUrl": baseURL}); err != nil {
		return nil, err
	}
	if existing != "" && existing != baseURL {
		if err := p.removeAccounts(ctx, scope); err != nil {
			return nil, err
		}
	}
	return p.SetupConfig(ctx, scope)
}

// ClearSetup revokes and removes the accounts, then forgets the server.
func (p *Provider) ClearSetup(ctx context.Context, scope integrations.Scope) error {
	rows, err := p.svc.ListConnections(ctx, scope.UserID, p.key(), scope.AgentID)
	if err != nil {
		return err
	}
	p.revokeAll(ctx, rows)
	if err := p.svc.DeleteProviderConfig(ctx, scope, p.key()); err != nil {
		return err
	}
	return p.svc.DeleteProviderConnections(ctx, scope, p.key())
}

func (p *Provider) removeAccounts(ctx context.Context, scope integrations.Scope) error {
	rows, err := p.svc.ListConnections(ctx, scope.UserID, p.key(), scope.AgentID)
	if err != nil {
		return err
	}
	p.revokeAll(ctx, rows)
	return p.svc.DeleteProviderConnections(ctx, scope, p.key())
}

// revokeAll tries every connection; failures do not stop the removal.
func (p *Provider) revokeAll(ctx context.Context, rows []integrations.Connection) {
	for _, r := range rows {
		_ = p.pr.Server.Revoke(ctx, p.svc.Credentials(r))
	}
}

// DecodeScopes reads a connection's granted scopes (scopes_json).
func DecodeScopes(conn integrations.Connection) map[string]bool {
	var stored []any
	out := map[string]bool{}
	if json.Unmarshal([]byte(conn.ScopesJSON), &stored) != nil {
		return out
	}
	for _, s := range stored {
		if t := Text(s); t != "" {
			out[t] = true
		}
	}
	return out
}

// SplitScopes splits a space-separated scope string.
func SplitScopes(v any) []string {
	return strings.Fields(Text(v))
}
