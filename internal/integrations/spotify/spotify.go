// Package spotify implements Spotify OAuth, search and playback controls.
package spotify

import (
	"context"
	_ "embed"
	"encoding/base64"
	"errors"
	"fmt"
	"math"
	"net/url"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

//go:embed provider.json
var specJSON []byte
var scopes = []string{"user-read-email", "user-read-private", "user-read-playback-state", "user-modify-playback-state", "user-read-currently-playing", "user-read-recently-played"}

type endpoints struct{ accounts, api string }
type provider struct {
	*integrations.OAuthProviderImpl
	svc *integrations.Services
	ep  endpoints
}

func New(svc *integrations.Services) integrations.Provider {
	return newProvider(svc, endpoints{"https://accounts.spotify.com", "https://api.spotify.com"})
}
func newProvider(svc *integrations.Services, ep endpoints) *provider {
	p := &provider{svc: svc, ep: ep}
	app := integrations.NewOAuthApp(svc, integrations.OAuthAppSpec{ProviderKey: "spotify", Label: "Spotify", EnvPrefix: "SPOTIFY", ConsoleURL: "https://developer.spotify.com/dashboard", Notes: "Create an app that uses the Web API and add the callback URL as a redirect URI. While the app is in development mode, add your Spotify account under User Management.", Scopes: scopes})
	p.OAuthProviderImpl = integrations.NewOAuthProvider(svc, integrations.LoadSpec(specJSON), app, integrations.OAuthHooks{Begin: p.begin, Finish: p.finish, Execute: p.execute, Test: func(ctx context.Context, tc *integrations.ToolContext) error {
		_, err := p.request(ctx, tc, "GET", "/v1/me", nil, nil)
		return err
	}})
	return p
}
func (p *provider) begin(_ context.Context, in integrations.BeginInput) (integrations.BeginResult, error) {
	u, err := oauthclient.SetParams(p.ep.accounts+"/authorize", oauthclient.Query{{"response_type", "code"}, {"client_id", in.OAuth.ClientID}, {"redirect_uri", in.OAuth.RedirectURI}, {"scope", strings.Join(scopes, " ")}, {"state", in.State}, {"show_dialog", "true"}})
	return integrations.BeginResult{URL: u, AppID: in.App.ID}, err
}
func (p *provider) token(ctx context.Context, cfg integrations.OAuthConfig, form [][2]string) (oauthclient.Credentials, error) {
	basic := "Basic " + base64.StdEncoding.EncodeToString([]byte(cfg.ClientID+":"+cfg.ClientSecret))
	raw, err := p.svc.Client("Spotify OAuth token exchange").JSON(ctx, oauthclient.Request{Method: "POST", URL: p.ep.accounts + "/api/token", Header: map[string]string{"Authorization": basic}, Form: form})
	if err != nil {
		return nil, err
	}
	return oauthclient.Credentials(integrations.Object(raw)), nil
}
func (p *provider) finish(ctx context.Context, in integrations.FinishInput) (integrations.FinishResult, error) {
	token, err := p.token(ctx, in.OAuth, [][2]string{{"grant_type", "authorization_code"}, {"code", in.Code}, {"redirect_uri", in.OAuth.RedirectURI}})
	if err != nil {
		return integrations.FinishResult{}, err
	}
	access := strings.TrimSpace(token.String("access_token"))
	refresh := strings.TrimSpace(token.String("refresh_token"))
	if access == "" {
		return integrations.FinishResult{}, errors.New("Spotify OAuth did not return an access token.")
	}
	if refresh == "" {
		return integrations.FinishResult{}, errors.New("Spotify OAuth did not return a refresh token.")
	}
	raw, err := p.svc.Client("Spotify profile").JSON(ctx, oauthclient.Request{URL: p.ep.api + "/v1/me", Header: map[string]string{"Authorization": "Bearer " + access}})
	if err != nil {
		return integrations.FinishResult{}, err
	}
	profile := integrations.Object(raw)
	email := strings.TrimSpace(integrations.Str(profile["email"]))
	account := email
	if account == "" {
		if id := strings.TrimSpace(integrations.Str(profile["id"])); id != "" {
			account = "spotify:" + id
		} else {
			account = "spotify_user"
		}
	}
	tokenType := token.String("token_type")
	if tokenType == "" {
		tokenType = "Bearer"
	}
	scope := token.String("scope")
	if scope == "" {
		scope = strings.Join(scopes, " ")
	}
	expires := token["expires_in"]
	n, ok := integrations.JSNumber(expires)
	if !ok || n == 0 {
		expires = 3600
	}
	creds := oauthclient.Credentials{"access_token": access, "refresh_token": refresh, "token_type": tokenType, "scope": scope, "expires_in": expires, "expires_at": oauthclient.ExpiresAt(expires, false, time.Now())}
	return integrations.FinishResult{AppID: in.App.ID, AccountEmail: account, Credentials: creds, Scopes: strings.Fields(scope), Metadata: map[string]any{"spotifyUserId": profile["id"], "displayName": profile["display_name"], "email": profile["email"], "country": profile["country"], "product": profile["product"]}}, nil
}
func (p *provider) refresh(ctx context.Context, tc *integrations.ToolContext, old oauthclient.Credentials) (oauthclient.Credentials, error) {
	refresh := strings.TrimSpace(old.String("refresh_token"))
	if refresh == "" {
		return old, nil
	}
	next, err := p.token(ctx, tc.OAuth, [][2]string{{"grant_type", "refresh_token"}, {"refresh_token", refresh}})
	if err != nil {
		return nil, err
	}
	if strings.TrimSpace(next.String("access_token")) == "" {
		return nil, errors.New("Spotify token refresh did not return an access token.")
	}
	merged := oauthclient.Credentials{}
	for k, v := range old {
		merged[k] = v
	}
	for k, v := range next {
		merged[k] = v
	}
	if merged.String("refresh_token") == "" {
		merged["refresh_token"] = refresh
	}
	if merged.String("token_type") == "" {
		merged["token_type"] = "Bearer"
	}
	expires := next["expires_in"]
	n, ok := integrations.JSNumber(expires)
	if !ok || n == 0 {
		expires = 3600
	}
	merged["expires_in"], merged["expires_at"] = expires, oauthclient.ExpiresAt(expires, false, time.Now())
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
		return nil, fmt.Errorf("Spotify API request URL is invalid or targets another host.")
	}
	out, _, err := oauthclient.WithRefresh(ctx, tc.Credentials, func(ctx context.Context, c oauthclient.Credentials) (oauthclient.Credentials, error) {
		return p.refresh(ctx, tc, c)
	}, func(c oauthclient.Credentials) (any, error) {
		token := strings.TrimSpace(c.String("access_token"))
		if token == "" {
			return nil, errors.New("Spotify access token is missing. Reconnect this integration account.")
		}
		kind := strings.TrimSpace(c.String("token_type"))
		if kind == "" {
			kind = "Bearer"
		}
		raw, err := p.svc.Client("Spotify").JSON(ctx, oauthclient.Request{Method: method, URL: target, Header: map[string]string{"Authorization": kind + " " + token, "Accept": "application/json"}, JSON: body})
		if err != nil {
			return nil, err
		}
		if string(raw) == "null" {
			return nil, nil
		}
		return raw, nil
	}, nil)
	return out, err
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
	limit := func(fallback float64) any {
		n, ok := integrations.JSNumber(args["limit"])
		if !ok || n == 0 {
			n = fallback
		}
		return max(1, min(50, n))
	}
	method, path := "GET", ""
	var query map[string]any
	var body any
	action := ""
	switch name {
	case "spotify_get_current_playback":
		path = "/v1/me/player"
	case "spotify_get_recently_played":
		path = "/v1/me/player/recently-played"
		query = map[string]any{"limit": limit(20)}
	case "spotify_search":
		text, err := require("query")
		if err != nil {
			return nil, err
		}
		path = "/v1/search"
		rawType := strings.ToLower(integrations.Str(args["type"]))
		var types []string
		for _, v := range strings.Split(rawType, ",") {
			v = strings.TrimSpace(v)
			switch v {
			case "track", "artist", "album", "playlist":
				types = append(types, v)
			}
		}
		if len(types) == 0 {
			types = []string{"track"}
		}
		query = map[string]any{"q": text, "type": strings.Join(types, ","), "limit": limit(10)}
		if market := strings.ToUpper(strings.TrimSpace(integrations.Str(args["market"]))); market != "" {
			query["market"] = market
		}
	case "spotify_control_playback":
		action = strings.ToLower(strings.TrimSpace(integrations.Str(args["action"])))
		query = map[string]any{}
		if id := strings.TrimSpace(integrations.Str(args["device_id"])); id != "" {
			query["device_id"] = id
		}
		method = "PUT"
		switch action {
		case "play":
			path = "/v1/me/player/play"
			m := map[string]any{}
			if v := strings.TrimSpace(integrations.Str(args["context_uri"])); v != "" {
				m["context_uri"] = v
			}
			if v, ok := args["uris"].([]any); ok {
				m["uris"] = v
			}
			if value, present := args["position_ms"]; present {
				if n, ok := integrations.JSNumber(value); ok && !math.IsNaN(n) && !math.IsInf(n, 0) {
					m["position_ms"] = n
				}
			}
			body = m
		case "pause":
			path = "/v1/me/player/pause"
		case "next", "previous":
			method = "POST"
			path = "/v1/me/player/" + action
		case "seek":
			value, present := args["position_ms"]
			n, ok := integrations.JSNumber(value)
			if !present || !ok || math.IsNaN(n) || math.IsInf(n, 0) || n < 0 {
				return nil, errors.New("position_ms must be a non-negative number for seek action.")
			}
			path = "/v1/me/player/seek"
			query["position_ms"] = math.Floor(n)
		case "set_volume":
			value, present := args["volume_percent"]
			n, ok := integrations.JSNumber(value)
			if !present || !ok || math.IsNaN(n) || math.IsInf(n, 0) || n < 0 || n > 100 {
				return nil, errors.New("volume_percent must be between 0 and 100 for set_volume action.")
			}
			path = "/v1/me/player/volume"
			query["volume_percent"] = math.Round(n)
		case "shuffle":
			v, ok := args["state"].(bool)
			if !ok {
				return nil, errors.New("state must be true or false for shuffle action.")
			}
			path = "/v1/me/player/shuffle"
			query["state"] = v
		case "repeat":
			v := strings.ToLower(strings.TrimSpace(integrations.Str(args["mode"])))
			if v != "track" && v != "context" && v != "off" {
				return nil, errors.New("mode must be one of track, context, or off for repeat action.")
			}
			path = "/v1/me/player/repeat"
			query["state"] = v
		default:
			return nil, errors.New("Unsupported action. Use play, pause, next, previous, seek, set_volume, shuffle, or repeat.")
		}
	case "spotify_api_request":
		var err error
		path, err = require("path")
		if err != nil {
			return nil, err
		}
		method = strings.ToUpper(strings.TrimSpace(integrations.Str(args["method"])))
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
		return nil, fmt.Errorf("Unknown Spotify tool: %s", name)
	}
	result, err := p.request(ctx, tc, method, path, query, body)
	if err != nil {
		return nil, err
	}
	if name == "spotify_get_current_playback" && result == nil {
		return map[string]any{"is_playing": false}, nil
	}
	if action != "" {
		return map[string]any{"action": action, "ok": true, "response": result}, nil
	}
	return result, nil
}
