// Package slack is the official Slack integration: OAuth with a user token,
// and the tools that read and post messages as the connected person.
package slack

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

//go:embed provider.json
var specJSON []byte

var userScopes = []string{
	"channels:read", "channels:history", "groups:read", "groups:history",
	"im:read", "im:history", "mpim:read", "mpim:history", "chat:write",
	"users:read", "users:read.email", "files:read", "files:write", "search:read",
	"reactions:read", "reactions:write", "pins:read", "pins:write",
}

var methodNamePattern = regexp.MustCompile(`^[a-zA-Z0-9_.]+$`)

type provider struct {
	svc  *integrations.Services
	base string // https://slack.com
}

// New is the Slack provider.
func New(svc *integrations.Services) *integrations.OAuthProviderImpl {
	return newProvider(svc, "https://slack.com")
}

func newProvider(svc *integrations.Services, base string) *integrations.OAuthProviderImpl {
	p := &provider{svc: svc, base: base}
	app := integrations.NewOAuthApp(svc, integrations.OAuthAppSpec{
		ProviderKey: "slack",
		Label:       "Slack",
		EnvPrefix:   "SLACK",
		ConsoleURL:  "https://api.slack.com/apps",
		Notes:       "Create an app, add the callback URL under OAuth & Permissions › Redirect URLs (Slack requires HTTPS), and add these user token scopes.",
		Scopes:      userScopes,
	})
	return integrations.NewOAuthProvider(svc, integrations.LoadSpec(specJSON), app, integrations.OAuthHooks{
		Begin:   p.begin,
		Finish:  p.finish,
		Execute: p.execute,
		Test: func(ctx context.Context, tc *integrations.ToolContext) error {
			_, err := p.request(ctx, tc, "auth.test", call{httpMethod: "GET"})
			return err
		},
	})
}

func (p *provider) begin(_ context.Context, in integrations.BeginInput) (integrations.BeginResult, error) {
	u, err := oauthclient.AppendQuery(p.base+"/oauth/v2/authorize",
		"client_id", in.OAuth.ClientID,
		"redirect_uri", in.OAuth.RedirectURI,
		"user_scope", oauthclient.JoinScopes(userScopes...),
		"state", in.State)
	return integrations.BeginResult{URL: u, AppID: in.App.ID}, err
}

// call is one Slack Web API request.
type call struct {
	httpMethod string
	query      oauthclient.Query
	body       any
}

func (p *provider) api(ctx context.Context, accessToken, methodName string, c call) (json.RawMessage, error) {
	name, err := integrations.RequireText(methodName, "method_name")
	if err != nil {
		return nil, err
	}
	if !methodNamePattern.MatchString(name) {
		return nil, errors.New("method_name must be a Slack Web API method name.")
	}
	method := strings.ToUpper(orDefault(c.httpMethod, "POST"))
	if method != "GET" && method != "POST" {
		return nil, errors.New("http_method must be GET or POST.")
	}
	u, err := oauthclient.SetParams(p.base+"/api/"+name, c.query)
	if err != nil {
		return nil, err
	}
	return p.svc.Client("Slack").JSON(ctx, oauthclient.Request{
		Method: method, URL: u, Header: map[string]string{"Authorization": "Bearer " + accessToken}, JSON: c.body,
	})
}

func orDefault(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

func (p *provider) refresh(ctx context.Context, cfg integrations.OAuthConfig, creds oauthclient.Credentials) (oauthclient.Credentials, error) {
	refreshToken := strings.TrimSpace(creds.String("refresh_token"))
	if refreshToken == "" {
		return nil, errors.New("Slack refresh token is missing. Reconnect this integration account.")
	}
	basic := basicAuth(cfg.ClientID, cfg.ClientSecret)
	raw, err := p.svc.Client("Slack token refresh").JSON(ctx, oauthclient.Request{
		Method: "POST", URL: p.base + "/api/oauth.v2.access", Header: map[string]string{"Authorization": "Basic " + basic},
		Form: [][2]string{{"grant_type", "refresh_token"}, {"refresh_token", refreshToken}},
	})
	if err != nil {
		return nil, err
	}
	token := integrations.Object(raw)
	userToken := integrations.Or(integrations.Get(token, "authed_user", "access_token"), token["access_token"])
	if !integrations.Truthy(userToken) {
		return nil, errors.New("Slack token refresh did not return an access token.")
	}
	next := creds.Clone()
	next["access_token"] = userToken
	next["refresh_token"] = integrations.Or(integrations.Get(token, "authed_user", "refresh_token"), token["refresh_token"], refreshToken)
	expiresIn := integrations.Or(integrations.Get(token, "authed_user", "expires_in"), token["expires_in"])
	setOrDrop(next, "expires_in", expiresIn)
	next["expires_at"] = oauthclient.ExpiresAt(expiresIn, true, p.svc.Now())
	setOrDrop(next, "bot_access_token", integrations.Or(token["access_token"], creds["bot_access_token"]))
	setOrDrop(next, "token_type", integrations.Or(integrations.Get(token, "authed_user", "token_type"), token["token_type"], creds["token_type"]))
	next["team"] = integrations.Or(token["team"], creds["team"], nil)
	next["enterprise"] = integrations.Or(token["enterprise"], creds["enterprise"], nil)
	if authed, ok := token["authed_user"]; ok && integrations.Truthy(authed) {
		merged := map[string]any{}
		if old, ok := creds["authed_user"].(map[string]any); ok {
			for k, v := range old {
				merged[k] = v
			}
		}
		if fresh, ok := authed.(map[string]any); ok {
			for k, v := range fresh {
				merged[k] = v
			}
		}
		next["authed_user"] = merged
	} else {
		next["authed_user"] = integrations.Or(creds["authed_user"], nil)
	}
	return next, nil
}

// setOrDrop stores v, or removes the key when v is undefined (nil here), as
// JSON.stringify drops undefined members.
func setOrDrop(m oauthclient.Credentials, key string, v any) {
	if v == nil {
		delete(m, key)
		return
	}
	m[key] = v
}

func basicAuth(id, secret string) string {
	return base64Std(id + ":" + secret)
}

// request runs a Web API call with the stored credentials, refreshing them
// when they expired.
func (p *provider) request(ctx context.Context, tc *integrations.ToolContext, methodName string, c call) (json.RawMessage, error) {
	out, _, err := oauthclient.WithRefresh(ctx, tc.Credentials,
		func(ctx context.Context, creds oauthclient.Credentials) (oauthclient.Credentials, error) {
			next, err := p.refresh(ctx, tc.OAuth, creds)
			if err == nil {
				tc.UpdateCredentials(next)
			}
			return next, err
		},
		func(creds oauthclient.Credentials) (json.RawMessage, error) {
			return p.api(ctx, creds.String("access_token"), methodName, c)
		},
		func(err error, creds oauthclient.Credentials) bool {
			var pe *oauthclient.Error
			if !errors.As(err, &pe) || creds.String("refresh_token") == "" {
				return false
			}
			code := strings.ToLower(integrations.Str(pe.Data["error"]))
			return code == "invalid_auth" || code == "token_expired"
		})
	return out, err
}

func (p *provider) finish(ctx context.Context, in integrations.FinishInput) (integrations.FinishResult, error) {
	raw, err := p.svc.Client("Slack").JSON(ctx, oauthclient.Request{
		Method: "POST", URL: p.base + "/api/oauth.v2.access",
		Form: [][2]string{
			{"client_id", in.OAuth.ClientID}, {"client_secret", in.OAuth.ClientSecret}, {"code", in.Code},
			{"grant_type", "authorization_code"}, {"redirect_uri", in.OAuth.RedirectURI},
		},
	})
	if err != nil {
		return integrations.FinishResult{}, err
	}
	token := integrations.Object(raw)
	userToken := integrations.Str(integrations.Or(integrations.Get(token, "authed_user", "access_token"), token["access_token"]))
	refreshToken := integrations.Or(integrations.Get(token, "authed_user", "refresh_token"), token["refresh_token"], nil)
	expiresIn := integrations.Or(integrations.Get(token, "authed_user", "expires_in"), token["expires_in"], nil)

	authTestRaw, err := p.api(ctx, userToken, "auth.test", call{httpMethod: "GET"})
	if err != nil {
		return integrations.FinishResult{}, err
	}
	authTest := integrations.Object(authTestRaw)
	var user map[string]any
	if integrations.Truthy(authTest["user_id"]) {
		profileRaw, err := p.api(ctx, userToken, "users.info", call{
			httpMethod: "GET", query: oauthclient.Query{{"user", integrations.Str(authTest["user_id"])}},
		})
		if err == nil {
			user, _ = integrations.Get(integrations.Object(profileRaw), "user").(map[string]any)
		}
	}
	accountEmail := strings.TrimSpace(integrations.Str(integrations.Or(
		integrations.Get(user, "profile", "email"), authTest["user"], authTest["user_id"], "")))
	if accountEmail == "" {
		return integrations.FinishResult{}, errors.New("Slack OAuth did not return a stable account identifier.")
	}

	creds := oauthclient.Credentials{
		"access_token":  userToken,
		"refresh_token": refreshToken,
		"expires_in":    expiresIn,
		"expires_at":    oauthclient.ExpiresAt(expiresIn, true, p.svc.Now()),
		"team":          integrations.Or(token["team"], nil),
		"enterprise":    integrations.Or(token["enterprise"], nil),
		"authed_user":   integrations.Or(token["authed_user"], nil),
	}
	setOrDrop(creds, "bot_access_token", token["access_token"])
	setOrDrop(creds, "token_type", token["token_type"])
	return integrations.FinishResult{
		AppID:        in.App.ID,
		AccountEmail: accountEmail,
		Credentials:  creds,
		Scopes:       userScopes,
		Metadata: map[string]any{
			"name":     integrations.Or(integrations.Get(user, "real_name"), integrations.Get(user, "name"), authTest["user"], nil),
			"email":    integrations.Or(integrations.Get(user, "profile", "email"), nil),
			"image":    integrations.Or(integrations.Get(user, "profile", "image_192"), nil),
			"teamId":   integrations.Or(authTest["team_id"], integrations.Get(token, "team", "id"), nil),
			"teamName": integrations.Or(authTest["team"], integrations.Get(token, "team", "name"), nil),
			"userId":   integrations.Or(authTest["user_id"], nil),
		},
	}, nil
}

type postBody struct {
	Channel  string `json:"channel"`
	Text     string `json:"text"`
	ThreadTS any    `json:"thread_ts,omitempty"`
}

func (p *provider) execute(ctx context.Context, name string, args map[string]any, tc *integrations.ToolContext) (any, error) {
	switch name {
	case "slack_list_conversations":
		types := integrations.Or(args["types"], "public_channel,private_channel,im,mpim")
		return p.request(ctx, tc, "conversations.list", call{httpMethod: "GET", query: oauthclient.Query{
			{"types", integrations.Str(types)}, {"limit", integrations.Clamp(args["limit"], 50, 1, 200)},
		}})
	case "slack_get_conversation_history":
		channel, err := integrations.RequireText(args["channel"], "channel")
		if err != nil {
			return nil, err
		}
		return p.request(ctx, tc, "conversations.history", call{httpMethod: "GET", query: oauthclient.Query{
			{"channel", channel}, {"limit", integrations.Clamp(args["limit"], 20, 1, 200)},
		}})
	case "slack_post_message":
		channel, err := integrations.RequireText(args["channel"], "channel")
		if err != nil {
			return nil, err
		}
		text, err := integrations.RequireText(args["text"], "text")
		if err != nil {
			return nil, err
		}
		body := postBody{Channel: channel, Text: text}
		if ts := args["thread_ts"]; integrations.Truthy(ts) {
			body.ThreadTS = ts
		}
		return p.request(ctx, tc, "chat.postMessage", call{body: body})
	case "slack_search_messages":
		query, err := integrations.RequireText(args["query"], "query")
		if err != nil {
			return nil, err
		}
		return p.request(ctx, tc, "search.messages", call{httpMethod: "GET", query: oauthclient.Query{
			{"query", query}, {"count", integrations.Clamp(args["count"], 20, 1, 100)},
		}})
	case "slack_get_user_info":
		user, err := integrations.RequireText(args["user"], "user")
		if err != nil {
			return nil, err
		}
		return p.request(ctx, tc, "users.info", call{httpMethod: "GET", query: oauthclient.Query{{"user", user}}})
	case "slack_api_request":
		if p.svc.Env("NEOAGENT_ENABLE_SLACK_DYNAMIC_API_REQUEST") != "true" {
			return nil, errors.New("slack_api_request is disabled by default. Set NEOAGENT_ENABLE_SLACK_DYNAMIC_API_REQUEST=true to enable it.")
		}
		method, err := integrations.RequireText(args["method_name"], "method_name")
		if err != nil {
			return nil, err
		}
		c := call{httpMethod: integrations.Str(integrations.Or(args["http_method"], "POST"))}
		if q, ok := args["query"].(map[string]any); ok {
			for _, k := range integrations.SortedKeys(q) {
				if q[k] != nil {
					c.query = append(c.query, [2]string{k, integrations.Str(q[k])})
				}
			}
		}
		if integrations.Truthy(args["body"]) {
			c.body = args["body"]
		}
		return p.request(ctx, tc, method, c)
	}
	return nil, fmt.Errorf("Unknown tool: %s", name)
}
