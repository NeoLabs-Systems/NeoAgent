package integrations

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

// credentialPattern: client IDs, secrets and tenant IDs are opaque printable
// tokens; whitespace or control characters are a paste mistake.
var credentialPattern = regexp.MustCompile(`^[\x21-\x7e]{1,512}$`)

// AppField is an extra setting of an OAuth app, for example a Microsoft tenant.
type AppField struct {
	Name         string
	Label        string
	Env          string
	DefaultValue string
	Hint         string
}

// OAuthAppSpec describes the OAuth client an integration signs accounts in with.
type OAuthAppSpec struct {
	ProviderKey string
	Label       string
	EnvPrefix   string
	ConsoleURL  string
	Notes       string
	Scopes      []string
	Fields      []AppField
	// Alternatives name other integrations that reach the same data without
	// registering an app.
	Alternatives []string
}

// OAuthApp resolves, stores and describes the OAuth client of one provider. An
// app from <PREFIX>_OAUTH_* applies to every account and locks user setup;
// without one each user registers their own, stored sealed per account.
type OAuthApp struct {
	svc  *Services
	spec OAuthAppSpec
}

// NewOAuthApp builds the OAuth app of a provider.
func NewOAuthApp(svc *Services, spec OAuthAppSpec) *OAuthApp {
	return &OAuthApp{svc: svc, spec: spec}
}

func (a *OAuthApp) stored(ctx context.Context, userID int64) map[string]any {
	if userID <= 0 {
		return map[string]any{}
	}
	var raw sql.NullString
	err := a.svc.DB.R.QueryRowContext(ctx,
		`SELECT config_json FROM integration_oauth_apps WHERE user_id = ? AND provider_key = ?`, userID, a.spec.ProviderKey).Scan(&raw)
	if err != nil || !raw.Valid {
		return map[string]any{}
	}
	plain, err := a.svc.Box.Open(raw.String)
	if err != nil {
		return map[string]any{}
	}
	return map[string]any(ParseCredentials(plain))
}

// text is String(value ?? ”).trim() for a decoded JSON value.
func text(v any) string {
	switch t := v.(type) {
	case nil:
		return ""
	case string:
		return strings.TrimSpace(t)
	case bool:
		return strconv.FormatBool(t)
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64)
	case interface{ String() string }:
		return strings.TrimSpace(t.String())
	}
	return "[object Object]"
}

func (a *OAuthApp) fieldValues(read func(AppField) string) map[string]string {
	out := make(map[string]string, len(a.spec.Fields))
	for _, f := range a.spec.Fields {
		v := read(f)
		if v == "" {
			v = f.DefaultValue
		}
		out[f.Name] = v
	}
	return out
}

// Resolve is the full client config including the secret. It never leaves the
// server.
func (a *OAuthApp) Resolve(ctx context.Context, scope Scope) OAuthConfig {
	server := a.svc.serverOAuthConfig(a.spec.EnvPrefix)
	if server.Configured {
		server.Source = "server"
		server.Fields = a.fieldValues(func(f AppField) string { return a.svc.env(f.Env) })
		return server
	}
	stored := a.stored(ctx, scope.UserID)
	cfg := OAuthConfig{
		ClientID:     text(stored["clientId"]),
		ClientSecret: text(stored["clientSecret"]),
		RedirectURI:  server.RedirectURI,
		Fields:       a.fieldValues(func(f AppField) string { return text(stored[f.Name]) }),
		Source:       "user",
	}
	cfg.Configured = cfg.ClientID != "" && cfg.ClientSecret != ""
	cfg.Missing = []string{}
	return cfg
}

// EnvStatus says whether accounts can connect.
func (a *OAuthApp) EnvStatus(scope Scope) Env {
	cfg := a.Resolve(context.Background(), scope)
	if cfg.Source == "server" {
		return Env{Configured: true, Missing: []string{}, Summary: a.spec.Label + " is ready for account connections.", SetupMode: "server"}
	}
	missing := []string{}
	if !cfg.Configured {
		if cfg.ClientID == "" {
			missing = append(missing, "clientId")
		}
		if cfg.ClientSecret == "" {
			missing = append(missing, "clientSecret")
		}
	}
	summary := "Add your own " + a.spec.Label + " OAuth app to connect accounts."
	if cfg.Configured {
		summary = a.spec.Label + " is ready for account connections using your own OAuth app."
	}
	alternatives := a.spec.Alternatives
	if alternatives == nil {
		alternatives = []string{}
	}
	return Env{Configured: cfg.Configured, Missing: missing, Summary: summary, SetupMode: "user", Alternatives: alternatives}
}

// UserConfigField is a field in the setup dialog.
type UserConfigField struct {
	Name         string `json:"name"`
	Label        string `json:"label"`
	Hint         string `json:"hint,omitempty"`
	DefaultValue string `json:"defaultValue,omitempty"`
	Value        string `json:"value"`
}

// UserConfig is what the setup dialog shows. The client secret is write-only.
type UserConfig struct {
	ManagedBy       string            `json:"managedBy"`
	Configured      bool              `json:"configured"`
	ClientID        string            `json:"clientId"`
	HasClientSecret bool              `json:"hasClientSecret"`
	RedirectURI     string            `json:"redirectUri"`
	ConsoleURL      string            `json:"consoleUrl,omitempty"`
	Notes           string            `json:"notes,omitempty"`
	Scopes          []string          `json:"scopes"`
	Fields          []UserConfigField `json:"fields"`
}

func uniqueStrings(in []string) []string {
	seen := map[string]bool{}
	out := []string{}
	for _, s := range in {
		if !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	return out
}

// UserConfig describes the setup state for the account.
func (a *OAuthApp) UserConfig(scope Scope) UserConfig {
	ctx := context.Background()
	cfg := a.Resolve(ctx, scope)
	managedByServer := cfg.Source == "server"
	stored := map[string]any{}
	if !managedByServer {
		stored = a.stored(ctx, scope.UserID)
	}
	out := UserConfig{
		ManagedBy: cfg.Source, Configured: cfg.Configured, RedirectURI: cfg.RedirectURI,
		ConsoleURL: a.spec.ConsoleURL, Notes: a.spec.Notes, Scopes: uniqueStrings(a.spec.Scopes),
		HasClientSecret: text(stored["clientSecret"]) != "",
		Fields:          []UserConfigField{},
	}
	if !managedByServer {
		out.ClientID = text(stored["clientId"])
	}
	for _, f := range a.spec.Fields {
		field := UserConfigField{Name: f.Name, Label: f.Label, Hint: f.Hint, DefaultValue: f.DefaultValue}
		if !managedByServer {
			field.Value = text(stored[f.Name])
		}
		out.Fields = append(out.Fields, field)
	}
	return out
}

func (a *OAuthApp) assertUserManaged() error {
	if a.svc.serverOAuthConfig(a.spec.EnvPrefix).Configured {
		return fmt.Errorf("%s is configured globally on this server, so it cannot be changed here.", a.spec.Label)
	}
	return nil
}

func cleanCredential(value any, label string) (string, error) {
	cleaned := text(value)
	if cleaned != "" && !credentialPattern.MatchString(cleaned) {
		return "", fmt.Errorf("%s contains spaces or unsupported characters.", label)
	}
	return cleaned, nil
}

// SaveUserConfig stores the account's own OAuth app. A blank secret keeps the
// stored one so the dialog never has to echo it.
func (a *OAuthApp) SaveUserConfig(ctx context.Context, scope Scope, config map[string]any) (UserConfig, error) {
	if err := a.assertUserManaged(); err != nil {
		return UserConfig{}, err
	}
	if scope.UserID <= 0 {
		return UserConfig{}, fmt.Errorf("A valid user is required to configure %s.", a.spec.Label)
	}
	stored := a.stored(ctx, scope.UserID)
	clientID, err := cleanCredential(config["clientId"], "Client ID")
	if err != nil {
		return UserConfig{}, err
	}
	clientSecret, err := cleanCredential(config["clientSecret"], "Client secret")
	if err != nil {
		return UserConfig{}, err
	}
	if clientSecret == "" {
		clientSecret = text(stored["clientSecret"])
	}
	if clientID == "" {
		return UserConfig{}, errors.New("Client ID is required.")
	}
	if clientSecret == "" {
		return UserConfig{}, errors.New("Client secret is required.")
	}
	next := oauthclient.Credentials{"clientId": clientID, "clientSecret": clientSecret}
	for _, f := range a.spec.Fields {
		value, err := cleanCredential(config[f.Name], f.Label)
		if err != nil {
			return UserConfig{}, err
		}
		if value != "" {
			next[f.Name] = value
		}
	}
	sealed, err := a.svc.sealCredentials(next)
	if err != nil {
		return UserConfig{}, err
	}
	if _, err := a.svc.DB.W.ExecContext(ctx, `INSERT INTO integration_oauth_apps (user_id, provider_key, config_json)
		VALUES (?, ?, ?)
		ON CONFLICT(user_id, provider_key) DO UPDATE SET
			config_json = excluded.config_json,
			updated_at = datetime('now')`, scope.UserID, a.spec.ProviderKey, sealed); err != nil {
		return UserConfig{}, err
	}
	return a.UserConfig(Scope{UserID: scope.UserID}), nil
}

// ClearUserConfig removes the account's own OAuth app. Connected accounts
// stay; they work again once an app is added back.
func (a *OAuthApp) ClearUserConfig(ctx context.Context, scope Scope) error {
	if err := a.assertUserManaged(); err != nil {
		return err
	}
	if scope.UserID <= 0 {
		return fmt.Errorf("A valid user is required to configure %s.", a.spec.Label)
	}
	_, err := a.svc.DB.W.ExecContext(ctx, `DELETE FROM integration_oauth_apps WHERE user_id = ? AND provider_key = ?`, scope.UserID, a.spec.ProviderKey)
	return err
}
