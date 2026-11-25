// Package trello is the Trello integration: the person's own API key, one
// connected member token, and board, list, card and comment tools.
package trello

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/url"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

//go:embed provider.json
var specJSON []byte

const (
	key     = "trello"
	apiHost = "api.trello.com"
)

// Provider is the Trello integration.
type Provider struct {
	*integrations.AccountProvider
	svc *integrations.Services
}

// New builds the provider.
func New(svc *integrations.Services) *Provider {
	p := &Provider{svc: svc}
	p.AccountProvider = integrations.NewAccountProvider(svc, integrations.LoadSpec(specJSON), integrations.AccountHooks{
		Env:     p.env,
		Execute: p.execute,
		Summarize: func(s integrations.Snapshot) string {
			if !s.Env.Configured {
				return "Trello: setup is not complete for this user yet. Tell them to finish Trello setup in Official Integrations first."
			}
			if !s.Connection.Connected {
				return "Trello: setup is ready, but no Trello account is connected yet. Tell the user to open Official Integrations and connect a Trello account."
			}
			return "Trello: native Trello access is connected in this run with one Trello account for board, list, card, comment, and search tools."
		},
	})
	return p
}

func text(v any) string { return strings.TrimSpace(integrations.Str(v)) }

type setup struct{ apiKey, token string }

func (p *Provider) stored(ctx context.Context, scope integrations.Scope) setup {
	if scope.UserID <= 0 {
		return setup{}
	}
	c := p.svc.ProviderConfig(ctx, scope, key)
	return setup{apiKey: text(c["apiKey"]), token: text(c["token"])}
}

// resolved is the setup with TRELLO_API_KEY taking precedence.
func (p *Provider) resolved(ctx context.Context, scope integrations.Scope) setup {
	s := p.stored(ctx, scope)
	if envKey := strings.TrimSpace(p.svc.Env("TRELLO_API_KEY")); envKey != "" {
		s.apiKey = envKey
	}
	return s
}

func (p *Provider) env(scope integrations.Scope) integrations.Env {
	if p.resolved(context.Background(), scope).apiKey != "" {
		return integrations.Env{Configured: true, Missing: []string{}, Summary: "Trello is ready for account connections.", SetupMode: "user"}
	}
	return integrations.Env{Configured: false, Missing: []string{"apiKey"}, Summary: "Add your Trello API key in Official Integrations to enable Trello account connections.", SetupMode: "user"}
}

// apiURL is buildPinnedApiUrl('api.trello.com', ...) with the key and token
// appended.
func apiURL(path string, query oauthclient.Query, s setup) (string, error) {
	if s.apiKey == "" {
		return "", errors.New("Trello API key is required.")
	}
	if s.token == "" {
		return "", errors.New("Trello token is required.")
	}
	raw := strings.TrimSpace(path)
	if !strings.HasPrefix(raw, "http") {
		if !strings.HasPrefix(raw, "/") {
			raw = "/" + raw
		}
		raw = "https://" + apiHost + raw
	}
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.Hostname() != apiHost {
		return "", errors.New("Trello API request URL must target api.trello.com.")
	}
	var params oauthclient.Query
	for _, kv := range query {
		if strings.TrimSpace(kv[1]) != "" {
			params = append(params, kv)
		}
	}
	params = append(params, [2]string{"key", s.apiKey}, [2]string{"token", s.token})
	return oauthclient.SetParams(u.String(), params)
}

func (p *Provider) request(ctx context.Context, s setup, method, path string, query oauthclient.Query) (json.RawMessage, error) {
	target, err := apiURL(path, query, s)
	if err != nil {
		return nil, err
	}
	return p.svc.Client("Trello").JSON(ctx, oauthclient.Request{Method: strings.ToUpper(method), URL: target})
}

func (p *Provider) profile(ctx context.Context, s setup) (json.RawMessage, error) {
	return p.request(ctx, s, "GET", "/1/members/me", oauthclient.Query{{"fields", "id,username,fullName,url,initials"}})
}

func accountEmail(profile map[string]any) string {
	name := text(profile["username"])
	if name == "" {
		name = text(profile["id"])
	}
	if name == "" {
		name = text(profile["fullName"])
	}
	if name == "" {
		name = "member"
	}
	return "trello:" + name
}

func or(v, fallback string) string {
	if v == "" {
		return fallback
	}
	return v
}

func requireText(args map[string]any, name string) (string, error) {
	return integrations.RequireText(args[name], name)
}

// clamp is Math.max(lo, Math.min(Number(v) || def, hi)).
func clamp(v any, def, lo, hi float64) float64 {
	n, ok := integrations.JSNumber(v)
	if !ok || n == 0 {
		n = def
	}
	return math.Max(lo, math.Min(n, hi))
}

func decode(raw json.RawMessage) any {
	dec := json.NewDecoder(strings.NewReader(string(raw)))
	dec.UseNumber()
	var v any
	_ = dec.Decode(&v)
	return v
}

// slice is Array.isArray(value) ? value.slice(0, n) : [].
func slice(raw json.RawMessage, n float64) any {
	var items []json.RawMessage
	if json.Unmarshal(raw, &items) != nil || items == nil {
		return []any{}
	}
	if limit := int(math.Trunc(n)); !math.IsInf(n, 1) && limit < len(items) {
		items = items[:limit]
	}
	return items
}

func orNull(v any) any {
	if integrations.Truthy(v) {
		return v
	}
	return nil
}

func (p *Provider) credentials(ctx context.Context, tc *integrations.ToolContext) (setup, error) {
	cfg := p.resolved(ctx, integrations.Scope{UserID: tc.Connection.UserID, AgentID: tc.Connection.AgentID})
	s := setup{apiKey: or(text(tc.Credentials["apiKey"]), cfg.apiKey), token: or(text(tc.Credentials["token"]), cfg.token)}
	if s.apiKey == "" {
		return s, errors.New("Trello API key is required. Reopen Official Integrations and save the Trello setup again.")
	}
	if s.token == "" {
		return s, errors.New("Trello token is missing for this account. Reconnect the Trello account from Official Integrations.")
	}
	return s, nil
}

const cardFields = "name,desc,idList,closed,pos,due,dueComplete,url"

func (p *Provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	s, err := p.credentials(ctx, tc)
	if err != nil {
		return nil, err
	}
	get := func(path string, q oauthclient.Query) (json.RawMessage, error) {
		return p.request(ctx, s, "GET", path, q)
	}
	switch name {
	case "trello_get_me":
		raw, err := p.profile(ctx, s)
		if err != nil {
			return nil, err
		}
		me, _ := decode(raw).(map[string]any)
		return dyn.Ordered{{Key: "id", Value: orNull(me["id"])}, {Key: "username", Value: orNull(me["username"])},
			{Key: "fullName", Value: orNull(me["fullName"])}, {Key: "initials", Value: orNull(me["initials"])}, {Key: "url", Value: orNull(me["url"])}}, nil
	case "trello_list_boards":
		raw, err := get("/1/members/me/boards", oauthclient.Query{{"fields", "name,url,closed,dateLastActivity"}, {"filter", or(text(args["filter"]), "open")}})
		if err != nil {
			return nil, err
		}
		return slice(raw, clamp(args["limit"], 50, 1, 200)), nil
	case "trello_get_board":
		id, err := requireText(args, "board_id")
		if err != nil {
			return nil, err
		}
		return get("/1/boards/"+encodeURIComponent(id), oauthclient.Query{
			{"fields", or(text(args["fields"]), "name,desc,url,closed,dateLastActivity")},
			{"lists", or(text(args["lists"]), "open")}, {"cards", or(text(args["cards"]), "none")}})
	case "trello_list_lists":
		id, err := requireText(args, "board_id")
		if err != nil {
			return nil, err
		}
		raw, err := get("/1/boards/"+encodeURIComponent(id)+"/lists", oauthclient.Query{{"fields", or(text(args["fields"]), "name,closed,pos")}})
		if err != nil {
			return nil, err
		}
		return slice(raw, math.Inf(1)), nil
	case "trello_list_cards":
		limit := clamp(args["limit"], 100, 1, 500)
		path := ""
		if listID := text(args["list_id"]); listID != "" {
			path = "/1/lists/" + encodeURIComponent(listID) + "/cards"
		} else {
			boardID, err := integrations.RequireText(text(args["board_id"]), "board_id")
			if err != nil {
				return nil, err
			}
			path = "/1/boards/" + encodeURIComponent(boardID) + "/cards"
		}
		raw, err := get(path, oauthclient.Query{{"fields", or(text(args["fields"]), cardFields)}, {"filter", or(text(args["filter"]), "open")}})
		if err != nil {
			return nil, err
		}
		return slice(raw, limit), nil
	case "trello_list_actions":
		id, err := requireText(args, "list_id")
		if err != nil {
			return nil, err
		}
		raw, err := get("/1/lists/"+encodeURIComponent(id)+"/actions", oauthclient.Query{
			{"filter", or(text(args["filter"]), "all")}, {"since", text(args["since"])},
			{"limit", dyn.Number(clamp(args["limit"], 50, 1, 1000))}})
		if err != nil {
			return nil, err
		}
		return slice(raw, math.Inf(1)), nil
	case "trello_get_card":
		id, err := requireText(args, "card_id")
		if err != nil {
			return nil, err
		}
		return get("/1/cards/"+encodeURIComponent(id), oauthclient.Query{{"fields", or(text(args["fields"]), cardFields)}})
	case "trello_search":
		query, err := requireText(args, "query")
		if err != nil {
			return nil, err
		}
		raw, err := get("/1/search", oauthclient.Query{{"query", query}, {"modelTypes", or(text(args["model_types"]), "cards,boards,lists,members,organizations")}})
		if err != nil {
			return nil, err
		}
		results := searchResults(raw)
		limit := int(math.Trunc(clamp(args["limit"], 20, 1, 100)))
		shown := results
		if limit < len(shown) {
			shown = shown[:limit]
		}
		return dyn.Ordered{{Key: "query", Value: query}, {Key: "count", Value: len(results)}, {Key: "results", Value: shown}}, nil
	case "trello_create_card":
		listID, err := requireText(args, "list_id")
		if err != nil {
			return nil, err
		}
		title, err := requireText(args, "name")
		if err != nil {
			return nil, err
		}
		q := oauthclient.Query{{"idList", listID}, {"name", title}}
		if v := text(args["desc"]); v != "" {
			q = append(q, [2]string{"desc", v})
		}
		if v := text(args["due"]); v != "" {
			q = append(q, [2]string{"due", v})
		}
		return p.request(ctx, s, "POST", "/1/cards", q)
	case "trello_update_card":
		var q oauthclient.Query
		for _, k := range []string{"name", "desc", "closed", "idList", "pos", "due", "dueComplete"} {
			v, ok := args[k]
			if !ok || v == nil {
				continue
			}
			if str, isStr := v.(string); isStr && strings.TrimSpace(str) == "" {
				continue
			}
			q = append(q, [2]string{k, integrations.Str(v)})
		}
		if len(q) == 0 {
			return nil, errors.New("At least one update field is required.")
		}
		id, err := requireText(args, "card_id")
		if err != nil {
			return nil, err
		}
		return p.request(ctx, s, "PUT", "/1/cards/"+encodeURIComponent(id), q)
	case "trello_add_comment":
		id, err := requireText(args, "card_id")
		if err != nil {
			return nil, err
		}
		comment, err := requireText(args, "text")
		if err != nil {
			return nil, err
		}
		return p.request(ctx, s, "POST", "/1/cards/"+encodeURIComponent(id)+"/actions/comments", oauthclient.Query{{"text", comment}})
	case "trello_api_request":
		path, err := requireText(args, "path")
		if err != nil {
			return nil, err
		}
		merged := map[string]any{}
		for _, field := range []string{"query", "body"} {
			if m, ok := args[field].(map[string]any); ok {
				for k, v := range m {
					merged[k] = v
				}
			}
		}
		var q oauthclient.Query
		for _, k := range integrations.SortedKeys(merged) {
			if merged[k] != nil {
				q = append(q, [2]string{k, integrations.Str(merged[k])})
			}
		}
		method := integrations.Str(args["method"])
		if method == "" {
			method = "GET"
		}
		return p.request(ctx, s, method, path, q)
	}
	return nil, fmt.Errorf("Unsupported Trello tool: %s", name)
}

// searchResults flattens Trello's search answer into typed entries, keeping
// each item's own members after "type".
func searchResults(raw json.RawMessage) []json.RawMessage {
	var groups map[string]json.RawMessage
	if json.Unmarshal(raw, &groups) != nil {
		return nil
	}
	var out []json.RawMessage
	for _, typ := range objectKeys(raw) {
		var items []json.RawMessage
		if json.Unmarshal(groups[typ], &items) != nil {
			continue
		}
		t, _ := json.Marshal(typ)
		for _, item := range items {
			body := strings.TrimSpace(string(item))
			if !strings.HasPrefix(body, "{") {
				continue
			}
			inner := strings.TrimSpace(body[1:])
			entry := `{"type":` + string(t)
			if inner != "}" {
				entry += "," + inner
			} else {
				entry += "}"
			}
			out = append(out, json.RawMessage(entry))
		}
	}
	return out
}

// objectKeys lists an object's members in document order.
func objectKeys(raw json.RawMessage) []string {
	dec := json.NewDecoder(strings.NewReader(string(raw)))
	if tok, err := dec.Token(); err != nil || tok != json.Delim('{') {
		return nil
	}
	var keys []string
	for dec.More() {
		tok, err := dec.Token()
		if err != nil {
			return keys
		}
		k, _ := tok.(string)
		keys = append(keys, k)
		var skip json.RawMessage
		if dec.Decode(&skip) != nil {
			return keys
		}
	}
	return keys
}

// encodeURIComponent is JavaScript's encodeURIComponent.
func encodeURIComponent(s string) string {
	const keep = "-_.!~*'()"
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || strings.IndexByte(keep, c) >= 0 {
			b.WriteByte(c)
			continue
		}
		fmt.Fprintf(&b, "%%%02X", c)
	}
	return b.String()
}

// ---- setup ---------------------------------------------------------------------

func (p *Provider) connectedCount(ctx context.Context, scope integrations.Scope) int {
	var n int
	_ = p.svc.DB.R.QueryRowContext(ctx, `SELECT COUNT(*) FROM integration_connections
		WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND status = 'connected'`, scope.UserID, scope.AgentID, key).Scan(&n)
	return n
}

func (p *Provider) clientConfig(stored setup) dyn.Ordered {
	configured := strings.TrimSpace(p.svc.Env("TRELLO_API_KEY")) != "" || stored.apiKey != ""
	return dyn.Ordered{{Key: "apiKey", Value: stored.apiKey}, {Key: "apiKeyConfigured", Value: configured},
		{Key: "hasLegacyToken", Value: stored.token != ""}, {Key: "configured", Value: configured}}
}

// SetupConfig is what the setup dialog shows.
func (p *Provider) SetupConfig(ctx context.Context, scope integrations.Scope) (any, error) {
	out := p.clientConfig(p.stored(ctx, scope))
	authorize := ""
	if k := p.resolved(ctx, scope).apiKey; k != "" {
		authorize = "https://trello.com/1/authorize?expiration=never&scope=read,write,account&response_type=token&key=" + encodeURIComponent(k)
	}
	n := p.connectedCount(ctx, scope)
	return append(out, dyn.KV{Key: "authorizeUrl", Value: authorize}, dyn.KV{Key: "accountCount", Value: n}, dyn.KV{Key: "hasConnectedAccount", Value: n > 0}), nil
}

// SaveSetup stores the API key and, given a token, connects the member it
// belongs to.
func (p *Provider) SaveSetup(ctx context.Context, scope integrations.Scope, config map[string]any) (any, error) {
	if scope.UserID <= 0 {
		return nil, errors.New("A valid user is required to save Trello configuration.")
	}
	existing := p.stored(ctx, scope)
	envKey := strings.TrimSpace(p.svc.Env("TRELLO_API_KEY"))
	apiKey := or(envKey, or(text(config["apiKey"]), existing.apiKey))
	token := text(config["token"])
	if apiKey == "" {
		return nil, errors.New("Trello API key is required before you can connect an account.")
	}
	if envKey == "" {
		if err := p.svc.SetProviderConfig(ctx, scope, key, map[string]any{"apiKey": apiKey}); err != nil {
			return nil, err
		}
	}
	if token == "" {
		n := p.connectedCount(ctx, scope)
		return append(p.clientConfig(setup{apiKey: apiKey}), dyn.KV{Key: "accountCount", Value: n}, dyn.KV{Key: "hasConnectedAccount", Value: n > 0}), nil
	}
	raw, err := p.profile(ctx, setup{apiKey: apiKey, token: token})
	if err != nil {
		m := strings.ToLower(err.Error())
		if strings.Contains(m, "invalid key") || strings.Contains(m, "invalid token") || strings.Contains(m, "unauthorized") || strings.Contains(m, "401") {
			return nil, errors.New("Trello rejected the API key/token pair. If you changed the API key, paste the matching token too.")
		}
		return nil, err
	}
	profile, _ := decode(raw).(map[string]any)
	if profile == nil {
		profile = map[string]any{}
	}
	email := accountEmail(profile)
	// The access mode is looked up under the app key, as Node does.
	var metaJSON string
	_ = p.svc.DB.R.QueryRowContext(ctx, `SELECT metadata_json FROM integration_connections
		WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND lower(account_email) = lower(?)`,
		scope.UserID, scope.AgentID, key, email).Scan(&metaJSON)
	mode := integrations.AccessMode(&integrations.Connection{MetadataJSON: metaJSON})
	sealed, err := p.svc.Seal(string(must(oauthclient.MarshalJS(map[string]any{"apiKey": apiKey, "token": token}))))
	if err != nil {
		return nil, err
	}
	if err := p.svc.UpsertConnection(ctx, integrations.ConnectedAccount{
		UserID: scope.UserID, AgentID: scope.AgentID, ProviderKey: key, AppKey: key, AccountEmail: email,
		Scopes: []string{"trello:api"}, CredentialsJSON: sealed,
		Metadata: map[string]any{"access_mode": mode, "trelloMemberId": orNull(profile["id"]), "username": orNull(profile["username"]),
			"fullName": orNull(profile["fullName"]), "url": orNull(profile["url"])},
	}); err != nil {
		return nil, err
	}
	return dyn.Ordered{{Key: "apiKey", Value: apiKey}, {Key: "apiKeyConfigured", Value: true}, {Key: "configured", Value: true},
		{Key: "accountEmail", Value: email}, {Key: "memberId", Value: orNull(profile["id"])},
		{Key: "username", Value: orNull(profile["username"])}, {Key: "fullName", Value: orNull(profile["fullName"])}}, nil
}

func must(b []byte, _ error) []byte { return b }

// ClearSetup removes the key and every Trello connection.
func (p *Provider) ClearSetup(ctx context.Context, scope integrations.Scope) error {
	if scope.UserID <= 0 {
		return errors.New("A valid user is required to clear Trello configuration.")
	}
	if err := p.svc.DeleteProviderConfig(ctx, scope, key); err != nil {
		return err
	}
	return p.svc.DeleteProviderConnections(ctx, scope, key)
}
