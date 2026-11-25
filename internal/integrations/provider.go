// Package integrations serves the official integrations: accounts connected to
// Google, Microsoft, Slack, GitHub and friends, the tools the agent gets from
// them, and the /api/integrations routes the apps use to connect and manage
// those accounts. It reads and writes the tables of the Node server's
// services/integrations and routes/integrations.js.
//
// A provider is a small value implementing Provider; the Manager owns
// everything they share (stored connections, OAuth states, read-only mode,
// per-account locking, expiry handling).
package integrations

import (
	"context"
	"encoding/json"

	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

// Scope names the account and agent a call is about.
type Scope struct {
	UserID  int64
	AgentID string
}

// App is one connectable app of a provider (Gmail inside Google Workspace).
type App struct {
	ID          string `json:"id"`
	Label       string `json:"label"`
	Description string `json:"description"`
}

// Info is what never changes about a provider.
type Info struct {
	Key         string
	Label       string
	Description string
	Icon        string
	// RequiresRefreshToken makes a connection without a refresh token fail,
	// because it would expire within the hour.
	RequiresRefreshToken bool
	// Exclusive serialises tool calls per account even without a refresh token.
	Exclusive bool
	Apps      []App
}

// Tool is a tool definition exactly as the model sees it. Definition is the
// complete JSON object (description and account selectors included), generated
// from the Node server so it stays byte-identical.
type Tool struct {
	Name        string
	AppID       string
	Access      string // read, write or dynamic_http_method
	HasRequired bool   // the schema lists required arguments
	Definition  json.RawMessage
}

// ParseTool reads the fields the framework needs out of a definition.
func ParseTool(definition json.RawMessage) (Tool, error) {
	var d struct {
		Name       string `json:"name"`
		AppID      string `json:"appId"`
		Access     string `json:"access"`
		Parameters struct {
			Required []string `json:"required"`
		} `json:"parameters"`
	}
	if err := json.Unmarshal(definition, &d); err != nil {
		return Tool{}, err
	}
	return Tool{Name: d.Name, AppID: d.AppID, Access: d.Access, HasRequired: len(d.Parameters.Required) > 0, Definition: definition}, nil
}

// WithIntegration is the definition with "integration": key appended, the form
// the agent engine receives.
func (t Tool) WithIntegration(key string) json.RawMessage {
	trimmed := t.Definition
	for len(trimmed) > 0 && (trimmed[len(trimmed)-1] == ' ' || trimmed[len(trimmed)-1] == '\n') {
		trimmed = trimmed[:len(trimmed)-1]
	}
	if len(trimmed) < 2 || trimmed[len(trimmed)-1] != '}' {
		return t.Definition
	}
	k, _ := oauthclient.MarshalJS(key)
	out := append([]byte{}, trimmed[:len(trimmed)-1]...)
	out = append(out, `,"integration":`...)
	out = append(out, k...)
	return append(out, '}')
}

// Connection is a row of integration_connections.
type Connection struct {
	ID              int64
	UserID          int64
	AgentID         string
	ProviderKey     string
	AppKey          string
	Status          string
	AccountEmail    string
	ScopesJSON      string
	CredentialsJSON string
	MetadataJSON    string
	LastConnectedAt string
	CreatedAt       string
	UpdatedAt       string
}

// Provider is one integration. Beyond this, a provider may implement the
// optional interfaces below.
type Provider interface {
	Info() Info
	App(id string) (App, bool)
	EnvStatus(Scope) Env
	// Tools are the definitions of the connected apps; connections are the
	// connected rows when the caller has them (a provider may narrow to what
	// the granted scopes allow), nil otherwise.
	Tools(connectedApps []string, connections []Connection) []Tool
	ToolAppID(name string) string
	SupportsTool(name string) bool
	Snapshot(rows []Connection, scope Scope) Snapshot
	SummarizeForModel(Snapshot) string
	ExecuteTool(ctx context.Context, name string, args map[string]any, conn Connection) (*Execution, error)
}

// Execution is the outcome of a tool call. Credentials is set when the call
// refreshed them and they must be stored again.
type Execution struct {
	Result      any
	Credentials oauthclient.Credentials
}

// BeginParams start an OAuth redirect flow.
type BeginParams struct {
	State        string
	CodeVerifier string
	Scope        Scope
	AppKey       string
}

// BeginResult is where the person must go.
type BeginResult struct {
	URL   string
	AppID string
}

// FinishParams complete an OAuth redirect flow.
type FinishParams struct {
	Code         string
	CodeVerifier string
	State        string
	Scope        Scope
	AppKey       string
}

// FinishResult is the account the redirect flow produced.
type FinishResult struct {
	AppID        string
	AccountEmail string
	Credentials  oauthclient.Credentials
	Scopes       []string
	Metadata     map[string]any
	// AlsoConnectsAppIDs are other apps the same sign-in covers (Google
	// Workspace), each of which gets its own connection row.
	AlsoConnectsAppIDs []string
}

// OAuthProvider connects accounts through a browser redirect.
type OAuthProvider interface {
	BeginOAuth(ctx context.Context, p BeginParams) (BeginResult, error)
	FinishOAuth(ctx context.Context, p FinishParams) (FinishResult, error)
}

// Disconnector revokes access remotely when the last app of an account goes.
type Disconnector interface {
	Disconnect(ctx context.Context, conn Connection) error
}

// Tester checks a connection with a provider-specific call. It returns the
// credentials when the check refreshed them. HasTest is false for a provider
// that implements the method but has no check of its own; the Manager then
// falls back to a safe read tool.
type Tester interface {
	HasTest() bool
	TestConnection(ctx context.Context, conn Connection) (oauthclient.Credentials, error)
}

// WriteClassifier overrides the tool definition's access for one call: true
// for a write, false for a read, ok false to fall back to the definition.
type WriteClassifier interface {
	IsWriteTool(name string, args map[string]any) (write bool, ok bool)
}

// Configurable is a provider with per-user setup (its own OAuth app).
type Configurable interface {
	UserConfig(Scope) UserConfig
	SaveUserConfig(ctx context.Context, scope Scope, config map[string]any) (UserConfig, error)
	ClearUserConfig(ctx context.Context, scope Scope) error
}
