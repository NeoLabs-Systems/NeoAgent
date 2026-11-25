package integrations

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

var oauthStatePattern = regexp.MustCompile(`(?i)^[a-f0-9]{32,128}$`)

// ToolContext is what a provider's tool code works with: the connection, its
// decrypted credentials and the OAuth client. Credentials a call refreshes go
// through UpdateCredentials so the Manager stores them.
type ToolContext struct {
	AppID       string
	Connection  Connection
	Credentials oauthclient.Credentials
	Env         Env
	OAuth       OAuthConfig
	updated     bool
}

// UpdateCredentials replaces the credentials in effect and marks them to be
// stored.
func (c *ToolContext) UpdateCredentials(next oauthclient.Credentials) {
	if next == nil {
		return
	}
	c.Credentials, c.updated = next, true
}

// OAuthHooks is what a redirect-flow provider supplies beyond its spec.
type OAuthHooks struct {
	// Begin builds the authorization URL.
	Begin func(ctx context.Context, in BeginInput) (BeginResult, error)
	// Finish exchanges the code for credentials and names the account.
	Finish func(ctx context.Context, in FinishInput) (FinishResult, error)
	// Disconnect revokes access remotely; optional.
	Disconnect func(ctx context.Context, tc *ToolContext) error
	// Execute runs one tool.
	Execute func(ctx context.Context, name string, args map[string]any, tc *ToolContext) (any, error)
	// Test checks the connection without side effects; optional.
	Test func(ctx context.Context, tc *ToolContext) error
	// FilterTools narrows the tools to what the connections can use; optional.
	FilterTools func(tools []Tool, connections []Connection) []Tool
	// Sweep reads a connection's past mail for memory; optional.
	Sweep func(ctx context.Context, tc *ToolContext, req SweepInput) ([]any, error)
}

// SweepInput asks for the documents of one connection.
type SweepInput struct {
	SourceTypes   []string
	SkipObjectIDs map[string]bool
	// OnProgress reports documents read; total is nil while unknown.
	OnProgress func(done int, total *int)
}

// SweepOutput is what a sweep read, with credentials it refreshed.
type SweepOutput struct {
	Documents   []any
	Credentials oauthclient.Credentials
	Cursor      any
}

// MemorySweeper is a provider that can read a connection's past mail.
type MemorySweeper interface {
	CanSweep() bool
	CollectMemorySweep(ctx context.Context, conn Connection, req SweepInput) (SweepOutput, error)
}

// CanSweep reports a provider with a mail collector.
func (p *OAuthProviderImpl) CanSweep() bool { return p.hooks.Sweep != nil }

// CollectMemorySweep reads the connection's past mail for memory.
func (p *OAuthProviderImpl) CollectMemorySweep(ctx context.Context, conn Connection, req SweepInput) (SweepOutput, error) {
	if p.hooks.Sweep == nil {
		return SweepOutput{}, errors.New("this integration has no memory sweep")
	}
	tc := p.toolContext(ctx, conn)
	collectedAt := time.Now().UTC().Format("2006-01-02T15:04:05.000Z")
	docs, err := p.hooks.Sweep(ctx, tc, req)
	if err != nil {
		return SweepOutput{}, err
	}
	if docs == nil {
		docs = []any{}
	}
	out := SweepOutput{Documents: docs, Cursor: map[string]any{"collectedAt": collectedAt, "appKey": conn.AppKey, "sourceTypes": req.SourceTypes}}
	if tc.updated {
		out.Credentials = tc.Credentials
	}
	return out, nil
}

// BeginInput is what Begin receives.
type BeginInput struct {
	State        string
	CodeVerifier string
	Scope        Scope
	App          App
	Env          Env
	OAuth        OAuthConfig
}

// FinishInput is what Finish receives.
type FinishInput struct {
	Code         string
	CodeVerifier string
	State        string
	Scope        Scope
	App          App
	OAuth        OAuthConfig
}

// OAuthProviderImpl is the shared provider behind Slack, Figma, Notion and the
// like: a spec, an OAuth app and a few hooks.
type OAuthProviderImpl struct {
	svc   *Services
	spec  Spec
	app   *OAuthApp
	tools Toolset
	hooks OAuthHooks
	apps  map[string]App
}

// NewOAuthProvider builds a redirect-flow provider from its spec.
func NewOAuthProvider(svc *Services, spec Spec, app *OAuthApp, hooks OAuthHooks) *OAuthProviderImpl {
	apps := make(map[string]App, len(spec.Apps))
	for _, a := range spec.Apps {
		apps[a.ID] = a
	}
	return &OAuthProviderImpl{svc: svc, spec: spec, app: app, tools: NewToolset(spec.ToolList()), hooks: hooks, apps: apps}
}

func (p *OAuthProviderImpl) Info() Info { return p.spec.Info() }

func (p *OAuthProviderImpl) App(id string) (App, bool) {
	a, ok := p.apps[strings.TrimSpace(id)]
	return a, ok
}

func (p *OAuthProviderImpl) EnvStatus(scope Scope) Env { return p.app.EnvStatus(scope) }

// Toolset exposes the provider's tool index for its own code.
func (p *OAuthProviderImpl) Toolset() Toolset { return p.tools }

func (p *OAuthProviderImpl) Tools(connectedApps []string, connections []Connection) []Tool {
	tools := p.tools.ForApps(connectedApps)
	if connections != nil && p.hooks.FilterTools != nil {
		return p.hooks.FilterTools(tools, connections)
	}
	return tools
}

func (p *OAuthProviderImpl) ToolAppID(name string) string { return p.tools.AppID(name) }

func (p *OAuthProviderImpl) SupportsTool(name string) bool { return p.tools.Supports(name) }

func (p *OAuthProviderImpl) Snapshot(rows []Connection, scope Scope) Snapshot {
	return specSnapshot(p.spec, p.tools, rows, p.EnvStatus(scope))
}

func (p *OAuthProviderImpl) SummarizeForModel(s Snapshot) string {
	return specSummary(p.spec, p.tools, s)
}

func (p *OAuthProviderImpl) UserConfig(scope Scope) UserConfig { return p.app.UserConfig(scope) }

func (p *OAuthProviderImpl) SaveUserConfig(ctx context.Context, scope Scope, config map[string]any) (UserConfig, error) {
	return p.app.SaveUserConfig(ctx, scope, config)
}

func (p *OAuthProviderImpl) ClearUserConfig(ctx context.Context, scope Scope) error {
	return p.app.ClearUserConfig(ctx, scope)
}

func (p *OAuthProviderImpl) BeginOAuth(ctx context.Context, bp BeginParams) (BeginResult, error) {
	app, ok := p.App(bp.AppKey)
	if !ok {
		return BeginResult{}, fmt.Errorf("Unknown %s app: %s", p.spec.Label, bp.AppKey)
	}
	state := strings.TrimSpace(bp.State)
	if !oauthStatePattern.MatchString(state) {
		return BeginResult{}, fmt.Errorf("Invalid OAuth state format. Please restart the connection flow.")
	}
	env := p.EnvStatus(bp.Scope)
	if !env.Configured {
		return BeginResult{}, fmt.Errorf("%s", env.Summary)
	}
	return p.hooks.Begin(ctx, BeginInput{
		State: state, CodeVerifier: bp.CodeVerifier, Scope: bp.Scope, App: app, Env: env,
		OAuth: p.app.Resolve(ctx, bp.Scope),
	})
}

func (p *OAuthProviderImpl) FinishOAuth(ctx context.Context, fp FinishParams) (FinishResult, error) {
	app, ok := p.App(fp.AppKey)
	if !ok {
		return FinishResult{}, fmt.Errorf("Unknown %s app: %s", p.spec.Label, fp.AppKey)
	}
	state := strings.TrimSpace(fp.State)
	if !oauthStatePattern.MatchString(state) {
		return FinishResult{}, fmt.Errorf("Invalid OAuth state format. Please restart the connection flow.")
	}
	return p.hooks.Finish(ctx, FinishInput{
		Code: fp.Code, CodeVerifier: fp.CodeVerifier, State: state, Scope: fp.Scope, App: app,
		OAuth: p.app.Resolve(ctx, fp.Scope),
	})
}

// toolContext opens a connection's credentials for a call.
func (p *OAuthProviderImpl) toolContext(ctx context.Context, conn Connection) *ToolContext {
	scope := Scope{UserID: conn.UserID, AgentID: conn.AgentID}
	return &ToolContext{
		AppID: conn.AppKey, Connection: conn, Credentials: p.svc.Credentials(conn),
		Env: p.EnvStatus(scope), OAuth: p.app.Resolve(ctx, scope),
	}
}

func (tc *ToolContext) execution(result any) *Execution {
	ex := &Execution{Result: result}
	if tc.updated {
		ex.Credentials = tc.Credentials
	}
	return ex
}

func (p *OAuthProviderImpl) ExecuteTool(ctx context.Context, name string, args map[string]any, conn Connection) (*Execution, error) {
	tc := p.toolContext(ctx, conn)
	if app := p.tools.AppID(name); app != "" {
		tc.AppID = app
	}
	result, err := p.hooks.Execute(ctx, name, args, tc)
	if err != nil {
		return nil, err
	}
	return tc.execution(result), nil
}

// Disconnect revokes access remotely when the provider can.
func (p *OAuthProviderImpl) Disconnect(ctx context.Context, conn Connection) error {
	if p.hooks.Disconnect == nil {
		return nil
	}
	return p.hooks.Disconnect(ctx, p.toolContext(ctx, conn))
}

// TestConnection runs the provider's own check; it is only reachable when the
// provider has one (see HasTest).
func (p *OAuthProviderImpl) TestConnection(ctx context.Context, conn Connection) (oauthclient.Credentials, error) {
	tc := p.toolContext(ctx, conn)
	if err := p.hooks.Test(ctx, tc); err != nil {
		return nil, err
	}
	if tc.updated {
		return tc.Credentials, nil
	}
	return nil, nil
}

// HasTest reports whether the provider has its own connection check.
func (p *OAuthProviderImpl) HasTest() bool { return p.hooks.Test != nil }
