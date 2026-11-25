// Package homeassistant implements the Home Assistant integration: one
// user-managed HTTPS instance, reached with a Long-Lived Access Token, with
// state reads and service calls. Private and loopback targets are refused.
package homeassistant

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net"
	"net/http"
	"net/netip"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

//go:embed provider.json
var specJSON []byte

const (
	providerKey = "home_assistant"
	appID       = "home_assistant"
)

// Options are the network seams; the zero value is production.
type Options struct {
	// HTTP reaches the instance; nil is an SSRF-safe client that does not
	// follow redirects.
	HTTP *http.Client
	// Lookup resolves a host; nil is the system resolver.
	Lookup func(ctx context.Context, host string) ([]netip.Addr, error)
}

type provider struct {
	*integrations.AccountProvider
	svc    *integrations.Services
	http   *http.Client
	lookup func(ctx context.Context, host string) ([]netip.Addr, error)
}

// New builds the provider.
func New(svc *integrations.Services, o Options) integrations.Provider {
	p := &provider{svc: svc, http: o.HTTP, lookup: o.Lookup}
	if p.http == nil {
		p.http = ssrf.NewClient(ssrf.Options{})
		p.http.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	}
	if p.lookup == nil {
		p.lookup = func(ctx context.Context, host string) ([]netip.Addr, error) {
			return net.DefaultResolver.LookupNetIP(ctx, "ip", host)
		}
	}
	p.AccountProvider = integrations.NewAccountProvider(svc, integrations.LoadSpec(specJSON), integrations.AccountHooks{
		Env:       p.env,
		Execute:   p.execute,
		Summarize: summarize,
	})
	return p
}

// config is the stored setup: the instance URL and its token.
func parseConfig(source, existing map[string]any) credentials {
	c := credentials{BaseURL: text(source["baseUrl"]), Token: text(source["token"])}
	if c.BaseURL == "" {
		c.BaseURL = text(existing["baseUrl"])
	}
	if c.Token == "" {
		c.Token = text(existing["token"])
	}
	return c
}

func (p *provider) env(scope integrations.Scope) integrations.Env {
	c := credentials{}
	if scope.UserID > 0 {
		c = parseConfig(p.svc.ProviderConfig(context.Background(), scope, providerKey), nil)
	}
	missing := []string{}
	if c.BaseURL == "" {
		missing = append(missing, "baseUrl")
	}
	if c.Token == "" {
		missing = append(missing, "token")
	}
	env := integrations.Env{Configured: len(missing) == 0, Missing: missing, SetupMode: "user",
		Summary: "Add your Home Assistant HTTPS URL and a Long-Lived Access Token in Official Integrations."}
	if env.Configured {
		env.Summary = "Home Assistant is ready for account connections."
	}
	return env
}

func summarize(s integrations.Snapshot) string {
	switch {
	case !s.Env.Configured:
		return "Home Assistant: setup is not complete for this user yet. Tell them to finish Home Assistant setup in Official Integrations first."
	case !s.Connection.Connected:
		return "Home Assistant: setup is ready, but no Home Assistant instance is connected yet. Tell the user to open Official Integrations and connect it."
	}
	return "Home Assistant: native Home Assistant access is connected in this run with tools for config, states, entity state, service calls, and /api requests."
}

func connectionCredentials(creds map[string]any) (credentials, error) {
	baseURL, err := normalizeBaseURL(creds["baseUrl"])
	if err != nil {
		return credentials{}, err
	}
	token, err := requireText(creds["token"], "Home Assistant token")
	if err != nil {
		return credentials{}, err
	}
	return credentials{BaseURL: baseURL, Token: token}, nil
}

// state is one entity state as the list tool returns it.
type state struct {
	EntityID    any `json:"entity_id"`
	State       any `json:"state"`
	Attributes  any `json:"attributes"`
	LastChanged any `json:"last_changed"`
	LastUpdated any `json:"last_updated"`
}

func orNull(v any) any {
	if integrations.Truthy(v) {
		return v
	}
	return nil
}

func filterStates(states any, args map[string]any) []state {
	domain := strings.ToLower(text(args["entity_domain"]))
	n, ok := integrations.JSNumber(args["limit"])
	if !ok || n == 0 {
		n = 100
	}
	limit := int(math.Max(1, math.Min(n, 500)))
	out := []state{}
	list, _ := states.([]any)
	for _, raw := range list {
		s, _ := raw.(map[string]any)
		id := strings.ToLower(integrations.Str(s["entity_id"]))
		if domain != "" && !strings.HasPrefix(id, domain+".") {
			continue
		}
		if len(out) == limit {
			break
		}
		attrs := s["attributes"]
		if !integrations.Truthy(attrs) {
			attrs = map[string]any{}
		}
		out = append(out, state{orNull(s["entity_id"]), orNull(s["state"]), attrs, orNull(s["last_changed"]), orNull(s["last_updated"])})
	}
	return out
}

var serviceSegment = regexp.MustCompile(`^[a-z0-9_]+$`)

func validateSegment(v any, label string) (string, error) {
	t, err := requireText(v, label)
	if err != nil {
		return "", err
	}
	t = strings.ToLower(t)
	if !serviceSegment.MatchString(t) {
		return "", fmt.Errorf("%s must contain only lowercase letters, numbers, and underscores.", label)
	}
	return t, nil
}

// encodeComponent is encodeURIComponent.
func encodeComponent(s string) string {
	var b strings.Builder
	for _, c := range []byte(s) {
		if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || strings.IndexByte("-_.!~*'()", c) >= 0 {
			b.WriteByte(c)
		} else {
			fmt.Fprintf(&b, "%%%02X", c)
		}
	}
	return b.String()
}

func (p *provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	c, err := connectionCredentials(tc.Credentials)
	if err != nil {
		return nil, err
	}
	switch name {
	case "home_assistant_get_config":
		return p.request(ctx, c, requestOptions{method: "GET", path: "/api/config"})
	case "home_assistant_list_states":
		states, err := p.request(ctx, c, requestOptions{method: "GET", path: "/api/states"})
		if err != nil {
			return nil, err
		}
		return filterStates(states, args), nil
	case "home_assistant_get_state":
		id, err := requireText(args["entity_id"], "entity_id")
		if err != nil {
			return nil, err
		}
		return p.request(ctx, c, requestOptions{method: "GET", path: "/api/states/" + encodeComponent(id)})
	case "home_assistant_call_service":
		domain, err := validateSegment(args["domain"], "domain")
		if err != nil {
			return nil, err
		}
		service, err := validateSegment(args["service"], "service")
		if err != nil {
			return nil, err
		}
		data, ok := args["service_data"].(map[string]any)
		if !ok {
			data = map[string]any{}
		}
		return p.request(ctx, c, requestOptions{method: "POST", path: "/api/services/" + domain + "/" + service, body: data})
	case "home_assistant_api_request":
		path, err := requireText(args["path"], "path")
		if err != nil {
			return nil, err
		}
		o := requestOptions{method: integrations.Str(args["method"]), path: path}
		switch q := args["query"].(type) {
		case map[string]any:
			o.query = q
		}
		switch b := args["body"].(type) {
		case map[string]any, []any:
			o.body = b
		}
		return p.request(ctx, c, o)
	}
	return nil, nil
}

// ---- setup -------------------------------------------------------------------

func (p *provider) storedCredentials(ctx context.Context, scope integrations.Scope) (map[string]any, *integrations.Connection, error) {
	conn, err := p.latestConnection(ctx, scope)
	if err != nil {
		return nil, nil, err
	}
	merged := p.svc.ProviderConfig(ctx, scope, providerKey)
	if conn != nil {
		for k, v := range p.svc.Credentials(*conn) {
			merged[k] = v
		}
	}
	return merged, conn, nil
}

func (p *provider) latestConnection(ctx context.Context, scope integrations.Scope) (*integrations.Connection, error) {
	rows, err := p.svc.ListConnections(ctx, scope.UserID, providerKey, scope.AgentID)
	if err != nil || len(rows) == 0 {
		return nil, err
	}
	return &rows[0], nil
}

// setupView is the setup document, members in the Node order.
type setupView struct {
	BaseURL             string `json:"baseUrl"`
	HasToken            bool   `json:"hasToken"`
	Configured          bool   `json:"configured"`
	AccountCount        int    `json:"accountCount"`
	HasConnectedAccount bool   `json:"hasConnectedAccount"`
}

// savedView is the setup document after a save.
type savedView struct {
	setupView
	AccountEmail *string `json:"accountEmail"`
	LocationName any     `json:"locationName"`
	Version      any     `json:"version"`
}

func view(c credentials, conn *integrations.Connection) setupView {
	connected := conn != nil && conn.Status == "connected"
	v := setupView{BaseURL: c.BaseURL, HasToken: c.Token != "", Configured: c.BaseURL != "" && c.Token != "", HasConnectedAccount: connected}
	if connected {
		v.AccountCount = 1
	}
	return v
}

// SetupConfig is the setup document; the token is never echoed.
func (p *provider) SetupConfig(ctx context.Context, scope integrations.Scope) (any, error) {
	stored, conn, err := p.storedCredentials(ctx, scope)
	if err != nil {
		return nil, err
	}
	return view(parseConfig(stored, nil), conn), nil
}

// SaveSetup checks the instance and the token, then connects it.
func (p *provider) SaveSetup(ctx context.Context, scope integrations.Scope, config map[string]any) (any, error) {
	if scope.UserID <= 0 {
		return nil, errors.New("A valid user is required to save Home Assistant configuration.")
	}
	stored, _, err := p.storedCredentials(ctx, scope)
	if err != nil {
		return nil, err
	}
	parsed := parseConfig(config, map[string]any{"baseUrl": parseConfig(stored, nil).BaseURL, "token": parseConfig(stored, nil).Token})
	baseURL, err := normalizeBaseURL(parsed.BaseURL)
	if err != nil {
		return nil, err
	}
	if parsed.Token == "" {
		return nil, errors.New("Home Assistant Long-Lived Access Token is required.")
	}
	creds := credentials{BaseURL: baseURL, Token: parsed.Token}
	if err := p.assertPublicEndpoint(ctx, baseURL); err != nil {
		return nil, err
	}
	haConfig, err := p.request(ctx, creds, requestOptions{method: "GET", path: "/api/config"})
	if err != nil {
		msg := strings.ToLower(err.Error())
		if strings.Contains(msg, "401") || strings.Contains(msg, "unauthorized") {
			return nil, errors.New("Home Assistant rejected the token. Create a new Long-Lived Access Token and try again.")
		}
		return nil, err
	}
	info, _ := haConfig.(map[string]any)
	if info == nil {
		info = map[string]any{}
	}
	if err := p.svc.SetProviderConfig(ctx, scope, providerKey, map[string]any{"baseUrl": baseURL, "token": parsed.Token}); err != nil {
		return nil, err
	}
	conn, err := p.upsertConnection(ctx, scope, creds, info)
	if err != nil {
		return nil, err
	}
	saved := savedView{setupView: view(creds, conn), LocationName: orNull(info["location_name"]), Version: orNull(info["version"])}
	if conn != nil && conn.AccountEmail != "" {
		saved.AccountEmail = &conn.AccountEmail
	}
	return saved, nil
}

func accountEmail(baseURL string, info map[string]any) string {
	if location := text(info["location_name"]); location != "" {
		return "home_assistant:" + location
	}
	host := strings.TrimPrefix(baseURL, "https://")
	if i := strings.IndexByte(host, '/'); i >= 0 {
		host = host[:i]
	}
	return "home_assistant:" + host
}

// upsertConnection stores the one instance of the agent; a renamed instance
// replaces the old row.
func (p *provider) upsertConnection(ctx context.Context, scope integrations.Scope, c credentials, info map[string]any) (*integrations.Connection, error) {
	existing, err := p.latestConnection(ctx, scope)
	if err != nil {
		return nil, err
	}
	email := accountEmail(c.BaseURL, info)
	metadata := map[string]any{"access_mode": integrations.AccessMode(existing), "locationName": orNull(info["location_name"]), "version": orNull(info["version"]), "timeZone": orNull(info["time_zone"])}
	if existing != nil {
		var prev map[string]any
		if json.Unmarshal([]byte(existing.MetadataJSON), &prev) == nil {
			for k, v := range metadata {
				prev[k] = v
			}
			metadata = prev
		}
	}
	sealed, err := p.svc.Seal(mustJSON(map[string]any{"baseUrl": c.BaseURL, "token": c.Token}))
	if err != nil {
		return nil, err
	}
	if err := p.svc.UpsertConnection(ctx, integrations.ConnectedAccount{
		UserID: scope.UserID, AgentID: scope.AgentID, ProviderKey: providerKey, AppKey: appID,
		AccountEmail: email, Scopes: []string{"home_assistant:api"}, CredentialsJSON: sealed, Metadata: metadata,
	}); err != nil {
		return nil, err
	}
	if existing != nil && existing.AccountEmail != email {
		if _, err := p.svc.DB.W.ExecContext(ctx, `DELETE FROM integration_connections WHERE id = ? AND user_id = ? AND agent_id = ?`, existing.ID, scope.UserID, scope.AgentID); err != nil {
			return nil, err
		}
	}
	return p.latestConnection(ctx, scope)
}

func mustJSON(v any) string {
	raw, _ := oauthclient.MarshalJS(v)
	return string(raw)
}

// ClearSetup forgets the instance and its connection.
func (p *provider) ClearSetup(ctx context.Context, scope integrations.Scope) error {
	if scope.UserID <= 0 {
		return errors.New("A valid user is required to clear Home Assistant configuration.")
	}
	if err := p.svc.DeleteProviderConfig(ctx, scope, providerKey); err != nil {
		return err
	}
	return p.svc.DeleteProviderConnections(ctx, scope, providerKey)
}
