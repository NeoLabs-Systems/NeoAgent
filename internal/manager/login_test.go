package manager

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/cli/envfile"
)

// fakeAuth is every provider's OAuth server in one: device codes that are
// pending once, and token endpoints that check the PKCE verifier.
func fakeAuth(t *testing.T) (*httptest.Server, *loginEndpoints) {
	var polls atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body := map[string]any{}
		if strings.HasPrefix(r.Header.Get("Content-Type"), "application/json") {
			json.NewDecoder(r.Body).Decode(&body)
		} else {
			r.ParseForm()
			for k := range r.PostForm {
				body[k] = r.PostForm.Get(k)
			}
		}
		reply := func(v any) { json.NewEncoder(w).Encode(v) }
		switch r.URL.Path {
		case "/github/device":
			reply(map[string]any{"device_code": "dc", "user_code": "ABCD-1234", "verification_uri": "https://github.com/login/device", "interval": 1})
		case "/github/token":
			if polls.Add(1) == 1 {
				reply(map[string]any{"error": "authorization_pending"})
				return
			}
			reply(map[string]any{"access_token": "gh-token"})
		case "/openai/device":
			reply(map[string]any{"device_auth_id": "auth", "usercode": "WXYZ", "interval": 1})
		case "/openai/device-token":
			if polls.Add(1) == 1 {
				w.WriteHeader(http.StatusForbidden)
				return
			}
			reply(map[string]any{"authorization_code": "ac", "code_verifier": "cv"})
		case "/openai/token":
			if body["code"] != "ac" || body["code_verifier"] != "cv" {
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			reply(map[string]any{"access_token": "codex-token", "refresh_token": "codex-refresh"})
		case "/claude/token", "/grok/token":
			if body["code"] != "the-code" || body["code_verifier"] == "" {
				w.WriteHeader(http.StatusBadRequest)
				reply(map[string]any{"error": "bad request"})
				return
			}
			reply(map[string]any{"access_token": strings.Trim(r.URL.Path, "/") + "-access", "refresh_token": "refresh", "expires_in": 3600})
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(srv.Close)
	e := defaultLoginEndpoints
	e.ClaudeAuthorize, e.ClaudeToken = srv.URL+"/claude/authorize", srv.URL+"/claude/token"
	e.GrokAuthorize, e.GrokToken = srv.URL+"/grok/authorize", srv.URL+"/grok/token"
	e.GitHubDevice, e.GitHubToken = srv.URL+"/github/device", srv.URL+"/github/token"
	e.OpenAIDevice, e.OpenAIDeviceToken, e.OpenAIToken = srv.URL+"/openai/device", srv.URL+"/openai/device-token", srv.URL+"/openai/token"
	e.ClaudeHost, e.GrokHost, e.GrokPort = "127.0.0.1", "127.0.0.1", 0
	e.DeviceTimeout, e.BrowserTimeout = 20*time.Second, 10*time.Second
	// The "browser": approves at once by following the redirect with a code.
	e.OpenBrowser = func(link string) {
		u, _ := url.Parse(link)
		q := u.Query()
		go http.Get(q.Get("redirect_uri") + "?code=the-code&state=" + url.QueryEscape(q.Get("state")))
	}
	return srv, &e
}

func TestLoginFlowsSaveTokens(t *testing.T) {
	a := newTestApp(t)
	_, endpoints := fakeAuth(t)
	a.login = endpoints
	t.Setenv("PORT", "1") // nothing listens: no restart afterwards
	ctx := context.Background()
	for _, id := range []string{"github-copilot", "openai-codex", "claude-code", "grok-oauth"} {
		if err := a.cmdLogin(ctx, []string{id}); err != nil {
			t.Fatalf("%s: %v", id, err)
		}
	}
	env, _ := envfile.Load(a.Paths.EnvFile)
	for key, want := range map[string]string{
		"GITHUB_COPILOT_ACCESS_TOKEN": "gh-token", "OPENAI_CODEX_ACCESS_TOKEN": "codex-token", "OPENAI_CODEX_REFRESH_TOKEN": "codex-refresh",
		"CLAUDE_CODE_OAUTH_TOKEN": "claude/token-access", "CLAUDE_CODE_REFRESH_TOKEN": "refresh",
		"GROK_OAUTH_ACCESS_TOKEN": "grok/token-access", "GROK_OAUTH_REFRESH_TOKEN": "refresh",
	} {
		if env[key] != want {
			t.Errorf("%s = %q, want %q", key, env[key], want)
		}
	}
	if env["GROK_OAUTH_EXPIRES_AT"] == "" {
		t.Error("no Grok expiry saved")
	}
	if err := a.cmdLogin(ctx, []string{"bogus"}); err == nil || !strings.Contains(err.Error(), "Available: claude-code") {
		t.Fatal(err)
	}
}

func TestLoginRejectsForgedState(t *testing.T) {
	a := newTestApp(t)
	_, endpoints := fakeAuth(t)
	endpoints.OpenBrowser = func(link string) {
		u, _ := url.Parse(link)
		go http.Get(u.Query().Get("redirect_uri") + "?code=the-code&state=forged")
	}
	a.login = endpoints
	if err := a.loginClaudeCode(context.Background()); err == nil || !strings.Contains(err.Error(), "state mismatch") {
		t.Fatal(err)
	}
}

func TestGrokExpiry(t *testing.T) {
	now := time.UnixMilli(1_000_000)
	// header.{"exp":2000}.sig
	jwt := "e30.eyJleHAiOjIwMDB9.x"
	if got := grokExpiresAt(jwt, nil, now); got != 2_000_000 {
		t.Fatal(got)
	}
	if got := grokExpiresAt("opaque", map[string]any{"expires_at": 1_700_000_000.0}, now); got != 1_700_000_000_000 {
		t.Fatal(got)
	}
	if got := grokExpiresAt("opaque", map[string]any{"expires_in": 60.0}, now); got != 1_060_000 {
		t.Fatal(got)
	}
}

func TestExecArguments(t *testing.T) {
	o, err := parseExecArguments([]string{"--model", "openrouter/a/b", "--json", "--allow-all-tools", "-y", "do it"})
	if err != nil || o.Model != "openrouter/a/b" || !o.AllowAllTools || !o.Yes || o.Instruction != "do it" {
		t.Fatalf("%+v %v", o, err)
	}
	for _, bad := range [][]string{{}, {"a", "b"}, {"--model"}, {"--what", "x"}} {
		if _, err := parseExecArguments(bad); err == nil {
			t.Errorf("accepted %v", bad)
		}
	}
	a := newTestApp(t)
	if err := a.confirmLocalExecution(false); err == nil || !strings.Contains(err.Error(), "--yes") {
		t.Fatal(err)
	}
}
