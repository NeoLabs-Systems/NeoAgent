// Package figma implements the Figma OAuth integration and REST tools.
package figma

import (
	"context"
	_ "embed"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

//go:embed provider.json
var specJSON []byte
var scopes = []string{"current_user:read", "file_content:read", "file_metadata:read", "file_comments:read", "file_comments:write", "library_content:read", "library_assets:read", "file_dev_resources:read", "file_dev_resources:write"}

type endpoints struct{ auth, api string }
type provider struct {
	*integrations.OAuthProviderImpl
	svc *integrations.Services
	ep  endpoints
}

func New(svc *integrations.Services) integrations.Provider {
	return newProvider(svc, endpoints{"https://www.figma.com/oauth", "https://api.figma.com"})
}
func newProvider(svc *integrations.Services, ep endpoints) *provider {
	p := &provider{svc: svc, ep: ep}
	app := integrations.NewOAuthApp(svc, integrations.OAuthAppSpec{ProviderKey: "figma", Label: "Figma", EnvPrefix: "FIGMA", ConsoleURL: "https://www.figma.com/developers/apps", Notes: "Create an app, add the callback URL as a redirect URL, and enable these scopes.", Scopes: scopes})
	p.OAuthProviderImpl = integrations.NewOAuthProvider(svc, integrations.LoadSpec(specJSON), app, integrations.OAuthHooks{Begin: p.begin, Finish: p.finish, Execute: p.execute, Test: func(ctx context.Context, tc *integrations.ToolContext) error {
		_, err := p.request(ctx, tc, "GET", "/v1/me", nil, nil)
		return err
	}})
	return p
}
func (p *provider) begin(_ context.Context, in integrations.BeginInput) (integrations.BeginResult, error) {
	u, err := oauthclient.SetParams(p.ep.auth, oauthclient.Query{{"client_id", in.OAuth.ClientID}, {"redirect_uri", in.OAuth.RedirectURI}, {"response_type", "code"}, {"scope", strings.Join(scopes, " ")}, {"state", in.State}})
	return integrations.BeginResult{URL: u, AppID: in.App.ID}, err
}
func basic(config integrations.OAuthConfig) string {
	return "Basic " + base64.StdEncoding.EncodeToString([]byte(config.ClientID+":"+config.ClientSecret))
}
func (p *provider) token(ctx context.Context, config integrations.OAuthConfig, form [][2]string) (oauthclient.Credentials, error) {
	raw, err := p.svc.Client("Figma").JSON(ctx, oauthclient.Request{Method: "POST", URL: p.ep.api + "/v1/oauth/token", Header: map[string]string{"Authorization": basic(config)}, Form: form})
	if err != nil {
		return nil, err
	}
	obj := integrations.Object(raw)
	if strings.TrimSpace(integrations.Str(obj["access_token"])) == "" {
		return nil, errors.New("Figma token response did not return an access token.")
	}
	out := oauthclient.Credentials(obj)
	out["expires_at"] = oauthclient.ExpiresAt(out["expires_in"], false, time.Now())
	return out, nil
}
func (p *provider) finish(ctx context.Context, in integrations.FinishInput) (integrations.FinishResult, error) {
	creds, err := p.token(ctx, in.OAuth, [][2]string{{"redirect_uri", in.OAuth.RedirectURI}, {"code", in.Code}, {"grant_type", "authorization_code"}})
	if err != nil {
		return integrations.FinishResult{}, err
	}
	raw, err := p.svc.Client("Figma").JSON(ctx, oauthclient.Request{URL: p.ep.api + "/v1/me", Header: map[string]string{"Authorization": "Bearer " + creds.String("access_token")}})
	if err != nil {
		return integrations.FinishResult{}, err
	}
	user := integrations.Object(raw)
	if nested, ok := user["user"].(map[string]any); ok {
		user = nested
	}
	first := func(keys ...string) any {
		for _, key := range keys {
			if integrations.Truthy(user[key]) {
				return user[key]
			}
		}
		return nil
	}
	id, email, handle, name, avatar := first("id", "user_id", "handle"), first("email"), first("handle", "login"), first("name", "handle"), first("img_url", "avatar_url")
	account := strings.TrimSpace(integrations.Str(email))
	if account == "" {
		account = strings.TrimSpace(integrations.Str(handle))
	}
	if account == "" {
		account = strings.TrimSpace(integrations.Str(id))
	}
	if account == "" {
		return integrations.FinishResult{}, errors.New("Figma OAuth did not return a stable account identifier.")
	}
	return integrations.FinishResult{AppID: in.App.ID, AccountEmail: account, Credentials: creds, Scopes: scopes, Metadata: map[string]any{"id": id, "email": email, "handle": handle, "name": name, "avatarUrl": avatar}}, nil
}
func (p *provider) refresh(ctx context.Context, tc *integrations.ToolContext, creds oauthclient.Credentials) (oauthclient.Credentials, error) {
	token := strings.TrimSpace(creds.String("refresh_token"))
	if token == "" {
		return nil, errors.New("Figma refresh token is missing. Reconnect this integration account.")
	}
	next, err := p.token(ctx, tc.OAuth, [][2]string{{"grant_type", "refresh_token"}, {"refresh_token", token}})
	if err != nil {
		return nil, err
	}
	merged := oauthclient.Credentials{}
	for k, v := range creds {
		merged[k] = v
	}
	for k, v := range next {
		merged[k] = v
	}
	if strings.TrimSpace(merged.String("refresh_token")) == "" {
		merged["refresh_token"] = token
	}
	tc.UpdateCredentials(merged)
	return merged, nil
}
func (p *provider) request(ctx context.Context, tc *integrations.ToolContext, method, path string, query map[string]any, body any) (any, error) {
	values := url.Values{}
	for k, v := range query {
		if v != nil {
			values.Set(k, integrations.Str(v))
		}
	}
	target, err := oauthclient.PinnedURL(p.ep.api, path, values)
	if err != nil {
		return nil, fmt.Errorf("Figma API request URL is invalid or targets another host.")
	}
	raw, _, err := oauthclient.WithRefresh(ctx, tc.Credentials, func(ctx context.Context, c oauthclient.Credentials) (oauthclient.Credentials, error) {
		return p.refresh(ctx, tc, c)
	}, func(c oauthclient.Credentials) (json.RawMessage, error) {
		return p.svc.Client("Figma").JSON(ctx, oauthclient.Request{Method: method, URL: target, Header: map[string]string{"Authorization": "Bearer " + c.String("access_token")}, JSON: body})
	}, nil)
	return raw, err
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
	method, path := "GET", "/v1/me"
	var query map[string]any
	var body any
	switch name {
	case "figma_get_me":
	case "figma_get_file", "figma_get_file_nodes", "figma_get_file_images", "figma_get_comments", "figma_post_comment":
		key, err := require("file_key")
		if err != nil {
			return nil, err
		}
		path = "/v1/files/" + url.PathEscape(key)
		switch name {
		case "figma_get_file":
			query = map[string]any{"ids": args["ids"], "depth": args["depth"]}
		case "figma_get_file_nodes":
			ids, err := require("ids")
			if err != nil {
				return nil, err
			}
			path += "/nodes"
			query = map[string]any{"ids": ids}
		case "figma_get_file_images":
			ids, err := require("ids")
			if err != nil {
				return nil, err
			}
			path = "/v1/images/" + url.PathEscape(key)
			format, _ := args["format"].(string)
			if format == "" {
				format = "png"
			}
			query = map[string]any{"ids": ids, "format": format, "scale": args["scale"]}
		case "figma_get_comments":
			path += "/comments"
		case "figma_post_comment":
			msg, err := require("message")
			if err != nil {
				return nil, err
			}
			method = "POST"
			path += "/comments"
			m := map[string]any{"message": msg}
			if args["client_meta"] != nil {
				m["client_meta"] = args["client_meta"]
			}
			body = m
		}
	case "figma_api_request":
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
		return nil, fmt.Errorf("Unknown Figma tool: %s", name)
	}
	return p.request(ctx, tc, method, path, query, body)
}
