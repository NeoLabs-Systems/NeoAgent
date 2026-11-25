// Package notion implements the official Notion OAuth integration and tools.
package notion

import (
	"context"
	_ "embed"
	"encoding/base64"
	"errors"
	"fmt"
	"net/url"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

//go:embed provider.json
var specJSON []byte

const notionVersion = "2022-06-28"

type provider struct {
	*integrations.OAuthProviderImpl
	svc *integrations.Services
	api string
}

func New(svc *integrations.Services) integrations.Provider {
	return newProvider(svc, "https://api.notion.com")
}
func newProvider(svc *integrations.Services, api string) *provider {
	p := &provider{svc: svc, api: api}
	app := integrations.NewOAuthApp(svc, integrations.OAuthAppSpec{ProviderKey: "notion", Label: "Notion", EnvPrefix: "NOTION", ConsoleURL: "https://www.notion.so/profile/integrations", Notes: "Create a public integration, add the callback URL as its redirect URI, and copy the OAuth client ID and secret."})
	p.OAuthProviderImpl = integrations.NewOAuthProvider(svc, integrations.LoadSpec(specJSON), app, integrations.OAuthHooks{Begin: p.begin, Finish: p.finish, Execute: p.execute, Test: func(ctx context.Context, tc *integrations.ToolContext) error {
		_, err := p.request(ctx, tc, "GET", "/v1/users/me", nil, nil)
		return err
	}})
	return p
}
func (p *provider) begin(_ context.Context, in integrations.BeginInput) (integrations.BeginResult, error) {
	u, err := oauthclient.SetParams(p.api+"/v1/oauth/authorize", oauthclient.Query{{"owner", "user"}, {"client_id", in.OAuth.ClientID}, {"redirect_uri", in.OAuth.RedirectURI}, {"response_type", "code"}, {"state", in.State}})
	return integrations.BeginResult{URL: u, AppID: in.App.ID}, err
}
func (p *provider) finish(ctx context.Context, in integrations.FinishInput) (integrations.FinishResult, error) {
	basic := "Basic " + base64.StdEncoding.EncodeToString([]byte(in.OAuth.ClientID+":"+in.OAuth.ClientSecret))
	raw, err := p.svc.Client("Notion").JSON(ctx, oauthclient.Request{Method: "POST", URL: p.api + "/v1/oauth/token", Header: map[string]string{"Authorization": basic}, JSON: map[string]any{"grant_type": "authorization_code", "code": in.Code, "redirect_uri": in.OAuth.RedirectURI}})
	if err != nil {
		return integrations.FinishResult{}, err
	}
	token := integrations.Object(raw)
	owner, _ := token["owner"].(map[string]any)
	user := map[string]any{}
	if owner["type"] == "user" {
		user, _ = owner["user"].(map[string]any)
	}
	person, _ := user["person"].(map[string]any)
	email := strings.TrimSpace(integrations.Str(person["email"]))
	account := email
	if account == "" {
		account = strings.TrimSpace(integrations.Str(token["workspace_name"]))
	}
	if account == "" {
		account = strings.TrimSpace(integrations.Str(token["workspace_id"]))
	}
	if account == "" {
		return integrations.FinishResult{}, errors.New("Notion OAuth did not return a stable account identifier.")
	}
	creds := oauthclient.Credentials{}
	for _, k := range []string{"access_token", "token_type", "workspace_id", "workspace_name", "duplicated_template_id", "bot_id"} {
		if v, ok := token[k]; ok {
			creds[k] = v
		}
	}
	return integrations.FinishResult{AppID: in.App.ID, AccountEmail: account, Credentials: creds, Scopes: []string{}, Metadata: map[string]any{"workspaceId": token["workspace_id"], "workspaceName": token["workspace_name"], "ownerType": owner["type"], "userId": user["id"], "userName": user["name"], "avatarUrl": user["avatar_url"]}}, nil
}
func (p *provider) request(ctx context.Context, tc *integrations.ToolContext, method, path string, query map[string]any, body any) (any, error) {
	values := url.Values{}
	for k, v := range query {
		if v != nil {
			values.Set(k, integrations.Str(v))
		}
	}
	target, err := oauthclient.PinnedURL(p.api, path, values)
	if err != nil {
		return nil, fmt.Errorf("Notion API request URL is invalid or targets another host.")
	}
	return p.svc.Client("Notion").JSON(ctx, oauthclient.Request{Method: method, URL: target, Header: map[string]string{"Authorization": "Bearer " + tc.Credentials.String("access_token"), "Notion-Version": notionVersion}, JSON: body})
}
func (p *provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	require := func(key string) (string, error) {
		v, ok := args[key].(string)
		v = strings.TrimSpace(v)
		if !ok || v == "" {
			return "", fmt.Errorf("%s is required.", key)
		}
		return v, nil
	}
	pageSize := func(fallback float64) any {
		n, ok := integrations.JSNumber(args["page_size"])
		if !ok || n == 0 {
			n = fallback
		}
		return max(1, min(100, n))
	}
	method, path := "GET", ""
	var query map[string]any
	var body any
	switch name {
	case "notion_search":
		method = "POST"
		path = "/v1/search"
		m := map[string]any{"page_size": pageSize(10)}
		if v := strings.TrimSpace(integrations.Str(args["query"])); v != "" {
			m["query"] = v
		}
		if integrations.Truthy(args["filter"]) {
			m["filter"] = args["filter"]
		}
		body = m
	case "notion_create_page":
		method = "POST"
		path = "/v1/pages"
		m := map[string]any{}
		for _, key := range []string{"parent", "properties"} {
			if v, ok := args[key]; ok {
				m[key] = v
			}
		}
		if v, ok := args["children"].([]any); ok {
			m["children"] = v
		}
		body = m
	case "notion_get_page", "notion_update_page":
		id, err := require("page_id")
		if err != nil {
			return nil, err
		}
		path = "/v1/pages/" + url.PathEscape(id)
		if name == "notion_update_page" {
			method = "PATCH"
			m := map[string]any{}
			for _, k := range []string{"properties", "archived", "icon", "cover"} {
				if v, ok := args[k]; ok {
					m[k] = v
				}
			}
			body = m
		}
	case "notion_query_database":
		id, err := require("database_id")
		if err != nil {
			return nil, err
		}
		path = "/v1/databases/" + url.PathEscape(id) + "/query"
		method = "POST"
		m := map[string]any{"page_size": pageSize(10)}
		if integrations.Truthy(args["filter"]) {
			m["filter"] = args["filter"]
		}
		if v, ok := args["sorts"].([]any); ok {
			m["sorts"] = v
		}
		body = m
	case "notion_get_block_children", "notion_append_block_children", "notion_update_block", "notion_delete_block":
		id, err := require("block_id")
		if err != nil {
			return nil, err
		}
		path = "/v1/blocks/" + url.PathEscape(id)
		switch name {
		case "notion_get_block_children":
			path += "/children"
			query = map[string]any{"page_size": pageSize(25)}
		case "notion_append_block_children":
			path += "/children"
			method = "PATCH"
			children, ok := args["children"].([]any)
			if !ok {
				children = []any{}
			}
			body = map[string]any{"children": children}
		case "notion_update_block":
			method = "PATCH"
			body = args["body"]
			if !integrations.Truthy(body) {
				body = map[string]any{}
			}
		case "notion_delete_block":
			method = "DELETE"
		}
	case "notion_api_request":
		var err error
		path, err = require("path")
		if err != nil {
			return nil, err
		}
		method, _ = args["method"].(string)
		method = strings.ToUpper(strings.TrimSpace(method))
		if method == "" {
			method = "GET"
		}
		switch method {
		case "GET", "POST", "PUT", "PATCH", "DELETE":
		default:
			return nil, errors.New("Unsupported HTTP method.")
		}
		query, _ = args["query"].(map[string]any)
		body = args["body"]
	default:
		return nil, fmt.Errorf("Unknown Notion tool: %s", name)
	}
	return p.request(ctx, tc, method, path, query, body)
}
