package manager

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/cli"
	"github.com/NeoLabs-Systems/neolabs-go/cli/envfile"
	"github.com/NeoLabs-Systems/neolabs-go/cli/oauthcli"
	"github.com/NeoLabs-Systems/neolabs-go/llm/anthropic"
	"github.com/NeoLabs-Systems/neolabs-go/llm/openaichat"
)

// loginEndpoints are the providers' OAuth endpoints; tests point them at a
// local server.
type loginEndpoints struct {
	ClaudeAuthorize, ClaudeToken    string
	GrokAuthorize, GrokToken        string
	GitHubDevice, GitHubToken       string
	OpenAIDevice, OpenAIDeviceToken string
	OpenAIToken, OpenAIVerification string
	OpenAIRedirect                  string
	ClaudeHost, GrokHost            string
	GrokPort                        int
	DeviceTimeout, BrowserTimeout   time.Duration
	OpenBrowser                     func(string)
}

var defaultLoginEndpoints = loginEndpoints{
	ClaudeAuthorize: "https://platform.claude.com/oauth/authorize", ClaudeToken: "https://platform.claude.com/v1/oauth/token",
	GrokAuthorize: "https://auth.x.ai/oauth2/authorize", GrokToken: "https://auth.x.ai/oauth2/token",
	GitHubDevice: "https://github.com/login/device/code", GitHubToken: "https://github.com/login/oauth/access_token",
	OpenAIDevice: "https://auth.openai.com/api/accounts/deviceauth/usercode", OpenAIDeviceToken: "https://auth.openai.com/api/accounts/deviceauth/token",
	OpenAIToken: "https://auth.openai.com/oauth/token", OpenAIVerification: "https://auth.openai.com/codex/device",
	OpenAIRedirect: "https://auth.openai.com/deviceauth/callback",
	ClaudeHost:     "localhost", GrokHost: "127.0.0.1", GrokPort: 56121,
	DeviceTimeout: 15 * time.Minute, BrowserTimeout: 5 * time.Minute,
	OpenBrowser: openInBrowser,
}

const (
	claudeClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
	githubClientID = "01ab8ac9400c4e429b23"
	openAIClientID = "app_EMoamEEZ73f0CkXaXp7hrann"
)

type loginProvider struct {
	ID, Label string
	flow      func(a *App, ctx context.Context) error
}

var loginProviders = []loginProvider{
	{"claude-code", "Claude", (*App).loginClaudeCode},
	{"openai-codex", "ChatGPT (OpenAI Codex)", (*App).loginOpenAICodex},
	{"github-copilot", "GitHub Copilot", (*App).loginGitHubCopilot},
	{"grok-oauth", "Grok (xAI)", (*App).loginGrokOAuth},
}

func (a *App) endpoints() loginEndpoints {
	if a.login != nil {
		return *a.login
	}
	return defaultLoginEndpoints
}

func authClient() *http.Client { return &http.Client{Timeout: 30 * time.Second} }

// cmdLogin connects an AI account; the tokens go to the env file, and a
// running server is restarted to read them.
func (a *App) cmdLogin(ctx context.Context, args []string) error {
	pos := cli.Positionals(args)
	var provider *loginProvider
	for i := range loginProviders {
		if len(pos) > 0 && loginProviders[i].ID == pos[0] {
			provider = &loginProviders[i]
		}
	}
	if provider == nil && len(pos) == 0 && a.UI.Interactive() {
		var choices []cli.Choice
		for _, p := range loginProviders {
			choices = append(choices, cli.Choice{Value: p.ID, Label: p.Label})
		}
		id, err := a.UI.Select("Which AI account would you like to connect?", choices)
		if err != nil {
			return err
		}
		return a.cmdLogin(ctx, []string{id})
	}
	if provider == nil {
		ids := make([]string, len(loginProviders))
		for i, p := range loginProviders {
			ids[i] = p.ID
		}
		name := "none"
		if len(pos) > 0 {
			name = pos[0]
		}
		return fmt.Errorf("Unsupported login provider: %s. Available: %s", name, strings.Join(ids, ", "))
	}
	if err := provider.flow(a, ctx); err != nil {
		return err
	}
	if a.Service.Managed() || cli.PortOpen(a.Port()) {
		return a.cmdRestart(ctx, nil)
	}
	return nil
}

func (a *App) printBrowserSignIn(service, link string) {
	a.UI.Title("Sign in to "+service, "Your browser opens to finish signing in.")
	a.UI.Note("If it doesn't open, visit this address:")
	a.UI.Print("  %s", link)
}

func (a *App) printDeviceCode(service, link, code string) {
	a.UI.Title("Sign in to "+service, "")
	a.UI.Print("  Go to %s", a.UI.Accent(link))
	a.UI.Print("  and enter %s", a.UI.Command(code))
	a.UI.Info("Waiting for you to finish signing in (up to 15 minutes)…")
}

// browserCode runs the PKCE browser flow and returns the code and the
// redirect URI it was issued for.
func (a *App) browserCode(ctx context.Context, service, authorize, host string, port int, scope, clientID string, pkce oauthcli.PKCE, state string) (code, redirect string, err error) {
	l, err := oauthcli.ListenLoopback(host, port, "/callback", state)
	if err != nil {
		return "", "", err
	}
	defer l.Close()
	q := url.Values{
		"response_type": {"code"}, "client_id": {clientID}, "redirect_uri": {l.RedirectURI}, "scope": {scope},
		"code_challenge": {pkce.Challenge}, "code_challenge_method": {"S256"}, "state": {state},
	}
	link := authorize + "?" + q.Encode()
	a.printBrowserSignIn(service, link)
	a.UI.Info("Waiting for you to finish signing in…")
	e := a.endpoints()
	e.OpenBrowser(link)
	code, err = l.Wait(ctx, e.BrowserTimeout)
	if err != nil {
		return "", "", fmt.Errorf("%s authorization: %w", service, err)
	}
	return code, l.RedirectURI, nil
}

func (a *App) saveTokens(values map[string]string) error {
	for _, k := range []string{"CLAUDE_CODE_OAUTH_TOKEN", "CLAUDE_CODE_REFRESH_TOKEN", "GROK_OAUTH_ACCESS_TOKEN", "GROK_OAUTH_REFRESH_TOKEN", "GROK_OAUTH_EXPIRES_AT", "GITHUB_COPILOT_ACCESS_TOKEN", "OPENAI_CODEX_ACCESS_TOKEN", "OPENAI_CODEX_REFRESH_TOKEN"} {
		if v, ok := values[k]; ok && v != "" {
			if err := a.setEnv(k, v); err != nil {
				return err
			}
		}
	}
	return nil
}

func (a *App) loginClaudeCode(ctx context.Context) error {
	// A Claude Code login on this computer (`claude login`) is reused.
	home, _ := os.UserHomeDir()
	if raw, err := os.ReadFile(filepath.Join(home, ".claude", ".credentials.json")); err == nil {
		var creds struct {
			Tokens struct {
				AccessToken string `json:"accessToken"`
			} `json:"claudeAiOauthTokens"`
		}
		if json.Unmarshal(raw, &creds) == nil && creds.Tokens.AccessToken != "" {
			if err := a.saveTokens(map[string]string{"CLAUDE_CODE_OAUTH_TOKEN": creds.Tokens.AccessToken}); err != nil {
				return err
			}
			a.UI.OK("Signed in to Claude with your Claude Code login")
			return nil
		}
	}
	e := a.endpoints()
	pkce, state := oauthcli.NewPKCE(), oauthcli.NewState()
	code, redirect, err := a.browserCode(ctx, "Claude", e.ClaudeAuthorize, e.ClaudeHost, 0, anthropic.ClaudeCodeScopes, claudeClientID, pkce, state)
	if err != nil {
		return err
	}
	data, _, err := oauthcli.PostJSON(ctx, authClient(), e.ClaudeToken, map[string]string{"anthropic-version": "2023-06-01"}, map[string]string{
		"grant_type": "authorization_code", "code": code, "redirect_uri": redirect, "client_id": claudeClientID,
		"code_verifier": pkce.Verifier, "scope": anthropic.ClaudeCodeScopes, "state": state,
	})
	if err != nil {
		return fmt.Errorf("Claude Code token exchange failed: %w", err)
	}
	if oauthcli.Str(data, "access_token") == "" {
		return fmt.Errorf("Token exchange succeeded but no access_token was returned.")
	}
	if err := a.saveTokens(map[string]string{"CLAUDE_CODE_OAUTH_TOKEN": oauthcli.Str(data, "access_token"), "CLAUDE_CODE_REFRESH_TOKEN": oauthcli.Str(data, "refresh_token")}); err != nil {
		return err
	}
	a.UI.OK("Signed in to Claude")
	return nil
}

func (a *App) loginGrokOAuth(ctx context.Context) error {
	e := a.endpoints()
	pkce, state := oauthcli.NewPKCE(), oauthcli.NewState()
	code, redirect, err := a.browserCode(ctx, "Grok", e.GrokAuthorize, e.GrokHost, e.GrokPort, openaichat.GrokOAuthScopes, openaichat.GrokOAuthClientID, pkce, state)
	if err != nil {
		return err
	}
	data, _, err := oauthcli.PostJSON(ctx, authClient(), e.GrokToken, nil, url.Values{
		"grant_type": {"authorization_code"}, "code": {code}, "redirect_uri": {redirect},
		"client_id": {openaichat.GrokOAuthClientID}, "code_verifier": {pkce.Verifier},
	})
	if err != nil {
		return fmt.Errorf("Grok OAuth token exchange failed: %w", err)
	}
	access := oauthcli.Str(data, "access_token")
	if access == "" {
		return fmt.Errorf("Token exchange succeeded but no access_token was returned.")
	}
	if err := a.saveTokens(map[string]string{"GROK_OAUTH_ACCESS_TOKEN": access, "GROK_OAUTH_REFRESH_TOKEN": oauthcli.Str(data, "refresh_token")}); err != nil {
		return err
	}
	if at := grokExpiresAt(access, data, time.Now()); at > 0 {
		if err := a.setEnv("GROK_OAUTH_EXPIRES_AT", strconv.FormatInt(at, 10)); err != nil {
			return err
		}
	} else if _, err := envfile.Remove(a.Paths.EnvFile, "GROK_OAUTH_EXPIRES_AT"); err != nil {
		return err
	}
	a.UI.OK("Signed in to Grok")
	return nil
}

// grokExpiresAt is the token's expiry in Unix milliseconds: the JWT exp,
// else expires_at (seconds or milliseconds), else now + expires_in.
func grokExpiresAt(token string, data map[string]any, now time.Time) int64 {
	if parts := strings.Split(token, "."); len(parts) >= 2 {
		if raw, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(parts[1], "=")); err == nil {
			var claims struct {
				Exp float64 `json:"exp"`
			}
			if json.Unmarshal(raw, &claims) == nil && claims.Exp > 0 {
				return int64(claims.Exp * 1000)
			}
		}
	}
	num := func(keys ...string) float64 {
		for _, k := range keys {
			switch v := data[k].(type) {
			case float64:
				return v
			case string:
				if f, err := strconv.ParseFloat(v, 64); err == nil {
					return f
				}
			}
		}
		return 0
	}
	if at := num("expires_at", "expiresAt"); at > 0 {
		if at > 10_000_000_000 {
			return int64(at)
		}
		return int64(at * 1000)
	}
	if in := num("expires_in", "expiresIn"); in > 0 {
		return now.UnixMilli() + int64(in*1000)
	}
	return 0
}

func intervalOf(data map[string]any) time.Duration {
	if v, ok := data["interval"].(float64); ok && v > 0 {
		return time.Duration(v) * time.Second
	}
	return 5 * time.Second
}

func (a *App) loginGitHubCopilot(ctx context.Context) error {
	e := a.endpoints()
	data, _, err := oauthcli.PostJSON(ctx, authClient(), e.GitHubDevice, nil, map[string]string{"client_id": githubClientID, "scope": "user:email"})
	if err != nil {
		return fmt.Errorf("GitHub device-code request failed: %w", err)
	}
	device, user, link := oauthcli.Str(data, "device_code"), oauthcli.Str(data, "user_code"), oauthcli.Str(data, "verification_uri")
	if device == "" || user == "" || link == "" {
		return fmt.Errorf("GitHub device-code response was missing required fields.")
	}
	a.printDeviceCode("GitHub Copilot", link, user)
	var token string
	err = oauthcli.PollDevice(ctx, authClient(), e.GitHubToken, func() any {
		return map[string]string{"client_id": githubClientID, "device_code": device, "grant_type": "urn:ietf:params:oauth:grant-type:device_code"}
	}, intervalOf(data), e.DeviceTimeout, func(d map[string]any) bool {
		token = oauthcli.Str(d, "access_token")
		return token != ""
	})
	if err != nil {
		return err
	}
	if err := a.saveTokens(map[string]string{"GITHUB_COPILOT_ACCESS_TOKEN": token}); err != nil {
		return err
	}
	a.UI.OK("Signed in to GitHub Copilot")
	return nil
}

func (a *App) loginOpenAICodex(ctx context.Context) error {
	e := a.endpoints()
	data, _, err := oauthcli.PostJSON(ctx, authClient(), e.OpenAIDevice, nil, map[string]string{
		"client_id": openAIClientID, "scope": "openid profile email offline_access model.request model.read model.create",
	})
	if err != nil {
		return fmt.Errorf("OpenAI device-code request failed: %w", err)
	}
	authID := oauthcli.Str(data, "device_auth_id")
	user := oauthcli.Str(data, "user_code")
	if user == "" {
		user = oauthcli.Str(data, "usercode")
	}
	if authID == "" || user == "" {
		return fmt.Errorf("OpenAI device-code response was missing required fields.")
	}
	a.printDeviceCode("ChatGPT", e.OpenAIVerification, user)
	var code, verifier string
	err = oauthcli.PollDevice(ctx, authClient(), e.OpenAIDeviceToken, func() any {
		return map[string]string{"device_auth_id": authID, "user_code": user}
	}, intervalOf(data), e.DeviceTimeout, func(d map[string]any) bool {
		code, verifier = oauthcli.Str(d, "authorization_code"), oauthcli.Str(d, "code_verifier")
		return code != "" && verifier != ""
	})
	if err != nil {
		return err
	}
	tokens, _, err := oauthcli.PostJSON(ctx, authClient(), e.OpenAIToken, nil, url.Values{
		"grant_type": {"authorization_code"}, "code": {code}, "redirect_uri": {e.OpenAIRedirect},
		"client_id": {openAIClientID}, "code_verifier": {verifier},
	})
	if err != nil {
		return fmt.Errorf("OpenAI token exchange failed: %w", err)
	}
	if oauthcli.Str(tokens, "access_token") == "" {
		return fmt.Errorf("OpenAI token exchange succeeded but did not return an access token.")
	}
	if err := a.saveTokens(map[string]string{"OPENAI_CODEX_ACCESS_TOKEN": oauthcli.Str(tokens, "access_token"), "OPENAI_CODEX_REFRESH_TOKEN": oauthcli.Str(tokens, "refresh_token")}); err != nil {
		return err
	}
	a.UI.OK("Signed in to ChatGPT")
	return nil
}
