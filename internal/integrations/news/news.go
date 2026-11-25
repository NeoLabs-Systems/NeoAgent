// Package news is the World News integration: GNews top headlines with the
// person's own API key.
package news

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"math"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

//go:embed provider.json
var specJSON []byte

const (
	providerKey  = "news"
	appID        = "headlines"
	accountLabel = "news:gnews"
	headlinesURL = "https://gnews.io/api/v4/top-headlines"
)

// Categories are the GNews categories a headline query may name.
var Categories = []string{"general", "world", "nation", "business", "technology", "entertainment", "sports", "science", "health"}

// Provider is the World News integration.
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
				return "World News: setup is not complete. Tell the user to add a GNews API key in Official Integrations."
			}
			if !s.Connection.Connected {
				return "World News: API key saved but not connected. Ask the user to reconnect it in Official Integrations."
			}
			return "World News: connected with a top-headlines tool (news_get_headlines)."
		},
	})
	return p
}

func (p *Provider) storedKey(ctx context.Context, scope integrations.Scope) string {
	return strings.TrimSpace(integrations.Str(p.svc.ProviderConfig(ctx, scope, providerKey)["apiKey"]))
}

func (p *Provider) env(scope integrations.Scope) integrations.Env {
	if scope.UserID > 0 && p.storedKey(context.Background(), scope) != "" {
		return integrations.Env{Configured: true, Missing: []string{}, Summary: "World News is ready for account connections.", SetupMode: "user"}
	}
	return integrations.Env{Configured: false, Missing: []string{"apiKey"}, Summary: "Add a GNews API key in Official Integrations.", SetupMode: "user"}
}

func contains(list []string, s string) bool {
	for _, v := range list {
		if v == s {
			return true
		}
	}
	return false
}

func text(v any) string { return strings.TrimSpace(integrations.Str(v)) }

// Headlines fetches the top headlines; the World News trigger uses it too.
func (p *Provider) Headlines(ctx context.Context, apiKey string, args map[string]any) ([]dyn.Ordered, error) {
	category := strings.ToLower(text(args["category"]))
	if !contains(Categories, category) {
		category = "world"
	}
	lang := strings.ToLower(text(args["lang"]))
	if lang == "" {
		lang = "en"
	}
	n, ok := integrations.JSNumber(args["max"])
	if _, present := args["max"]; !present || !ok || n == 0 {
		n = 10
	}
	q := oauthclient.Query{{"category", category}, {"lang", lang}, {"max", dyn.Number(math.Max(1, math.Min(n, 10)))}}
	if v := text(args["query"]); v != "" {
		q = append(q, [2]string{"q", v})
	}
	if v := text(args["country"]); v != "" {
		q = append(q, [2]string{"country", strings.ToLower(v)})
	}
	q = append(q, [2]string{"apikey", apiKey})
	target, err := oauthclient.SetParams(headlinesURL, q)
	if err != nil {
		return nil, err
	}
	raw, err := p.svc.Client("GNews").JSON(ctx, oauthclient.Request{URL: target})
	if err != nil {
		return nil, err
	}
	var result map[string]any
	_ = json.Unmarshal(raw, &result)
	articles, _ := result["articles"].([]any)
	out := make([]dyn.Ordered, 0, len(articles))
	for _, a := range articles {
		article, _ := a.(map[string]any)
		id := text(article["id"])
		if id == "" {
			id = text(article["url"])
		}
		out = append(out, dyn.Ordered{
			{Key: "id", Value: id},
			{Key: "title", Value: text(article["title"])},
			{Key: "description", Value: text(article["description"])},
			{Key: "url", Value: text(article["url"])},
			{Key: "source", Value: text(integrations.Get(article, "source", "name"))},
			{Key: "publishedAt", Value: text(article["publishedAt"])},
		})
	}
	return out, nil
}

func (p *Provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	if name != "news_get_headlines" {
		return nil, errors.New("execution_failed")
	}
	apiKey := text(tc.Credentials["apiKey"])
	if apiKey == "" {
		return nil, errors.New("GNews API key is missing. Save it again in Official Integrations.")
	}
	articles, err := p.Headlines(ctx, apiKey, args)
	if err != nil {
		return nil, err
	}
	return dyn.Ordered{{Key: "count", Value: len(articles)}, {Key: "articles", Value: articles}}, nil
}

func (p *Provider) latestConnected(ctx context.Context, scope integrations.Scope) bool {
	var status string
	err := p.svc.DB.R.QueryRowContext(ctx, `SELECT status FROM integration_connections
		WHERE user_id = ? AND agent_id = ? AND provider_key = ?
		ORDER BY updated_at DESC, id DESC LIMIT 1`, scope.UserID, scope.AgentID, providerKey).Scan(&status)
	return err == nil && status == "connected"
}

func (p *Provider) clientConfig(ctx context.Context, scope integrations.Scope) dyn.Ordered {
	connected := p.latestConnected(ctx, scope)
	hasKey := p.storedKey(ctx, scope) != ""
	count := 0
	if connected {
		count = 1
	}
	return dyn.Ordered{{Key: "hasApiKey", Value: hasKey}, {Key: "configured", Value: hasKey},
		{Key: "accountCount", Value: count}, {Key: "hasConnectedAccount", Value: connected}}
}

// SetupConfig is what the setup dialog shows.
func (p *Provider) SetupConfig(ctx context.Context, scope integrations.Scope) (any, error) {
	return p.clientConfig(ctx, scope), nil
}

// SaveSetup checks the key against GNews, stores it and connects.
func (p *Provider) SaveSetup(ctx context.Context, scope integrations.Scope, config map[string]any) (any, error) {
	if scope.UserID <= 0 {
		return nil, errors.New("A valid user is required to save World News configuration.")
	}
	apiKey := text(config["apiKey"])
	if apiKey == "" {
		apiKey = p.storedKey(ctx, scope)
	}
	if apiKey == "" {
		return nil, errors.New("GNews API key is required.")
	}
	if _, err := p.Headlines(ctx, apiKey, map[string]any{"max": 1.0}); err != nil {
		message := strings.ToLower(err.Error())
		if strings.Contains(message, "401") || strings.Contains(message, "403") || strings.Contains(message, "api key") {
			return nil, errors.New("GNews rejected the API key. Check it and try again.")
		}
		return nil, err
	}
	if err := p.svc.SetProviderConfig(ctx, scope, providerKey, map[string]any{"apiKey": apiKey}); err != nil {
		return nil, err
	}
	sealed, err := p.svc.Seal(string(must(oauthclient.MarshalJS(map[string]any{"apiKey": apiKey}))))
	if err != nil {
		return nil, err
	}
	if err := p.svc.UpsertConnection(ctx, integrations.ConnectedAccount{
		UserID: scope.UserID, AgentID: scope.AgentID, ProviderKey: providerKey, AppKey: appID, AccountEmail: accountLabel,
		Scopes: []string{"gnews:read"}, CredentialsJSON: sealed, Metadata: map[string]any{"source": "gnews"},
	}); err != nil {
		return nil, err
	}
	return p.clientConfig(ctx, scope), nil
}

func must(b []byte, _ error) []byte { return b }

// ClearSetup removes the key and the connection.
func (p *Provider) ClearSetup(ctx context.Context, scope integrations.Scope) error {
	if err := p.svc.DeleteProviderConfig(ctx, scope, providerKey); err != nil {
		return err
	}
	return p.svc.DeleteProviderConnections(ctx, scope, providerKey)
}
