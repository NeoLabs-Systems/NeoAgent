package mcpserver

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"
)

// authServer is an MCP server that wants a bearer token, with the discovery
// documents and token endpoint the OAuth flow needs.
func authServer(t *testing.T) *httptest.Server {
	mcpHandler := mcpBackend()
	var base string
	mux := http.NewServeMux()
	mux.HandleFunc("/mcp", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer good" {
			w.Header().Set("WWW-Authenticate", fmt.Sprintf(`Bearer resource_metadata="%s/.well-known/oauth-protected-resource"`, base))
			w.WriteHeader(401)
			return
		}
		mcpHandler.ServeHTTP(w, r)
	})
	write := func(w http.ResponseWriter, v any) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(v)
	}
	mux.HandleFunc("/.well-known/oauth-protected-resource", func(w http.ResponseWriter, r *http.Request) {
		write(w, map[string]any{"resource": base + "/mcp", "authorization_servers": []string{base}})
	})
	mux.HandleFunc("/.well-known/oauth-authorization-server", func(w http.ResponseWriter, r *http.Request) {
		write(w, map[string]any{
			"issuer": base, "authorization_endpoint": base + "/authorize", "token_endpoint": base + "/token",
			"response_types_supported": []string{"code"}, "code_challenge_methods_supported": []string{"S256"},
			"grant_types_supported": []string{"authorization_code", "refresh_token"},
		})
	})
	mux.HandleFunc("/token", func(w http.ResponseWriter, r *http.Request) {
		_ = r.ParseForm()
		if r.Form.Get("code") != "the-code" || r.Form.Get("code_verifier") == "" || r.Form.Get("client_id") != "client-1" {
			w.WriteHeader(400)
			write(w, map[string]any{"error": "invalid_grant"})
			return
		}
		write(w, map[string]any{"access_token": "good", "token_type": "Bearer", "refresh_token": "r1"})
	})
	srv := httptest.NewServer(mux)
	base = srv.URL
	t.Cleanup(srv.Close)
	return srv
}

func TestOAuthFlowThroughCallback(t *testing.T) {
	e := newEnv(t, nil)
	as := authServer(t)
	t.Cleanup(e.mgr.Shutdown) // connections must close before the server does
	ctx := context.Background()
	id, err := e.store.Insert(ctx, 1, "", "Authed", as.URL+"/mcp", map[string]any{
		"transport": "streamable-http", "auth": map[string]any{"type": "oauth", "clientId": "client-1"},
	}, true)
	if err != nil {
		t.Fatal(err)
	}

	code, out := e.do(t, "1", "POST", fmt.Sprintf("/api/mcp/%d/start", id), "")
	got := jsonOf(t, out)
	if code != 200 || got["status"] != "oauth_redirect" {
		t.Fatalf("start: %d %s", code, out)
	}
	authURL, err := url.Parse(got["url"].(string))
	if err != nil || !strings.HasSuffix(authURL.Path, "/authorize") {
		t.Fatalf("authorization url %v", got["url"])
	}
	state := authURL.Query().Get("state")
	if !oauthStateRE.MatchString(state) || authURL.Query().Get("client_id") != "client-1" || authURL.Query().Get("code_challenge") == "" {
		t.Fatalf("authorization url parameters: %s", authURL.RawQuery)
	}
	if st := e.mgr.Status(1, "")[id]; st.Status != "auth_required" {
		t.Fatalf("status %+v", st)
	}

	code, body := e.do(t, "1", "GET", "/api/mcp/oauth/callback?code=the-code&state="+url.QueryEscape(state), "")
	if code != 200 || !strings.Contains(body, "mcp_oauth_success") || !strings.Contains(body, `"https://agent.example.com"`) {
		t.Fatalf("callback: %d %s", code, body)
	}
	waitFor(t, "running", func() bool { return e.mgr.Status(1, "")[id].Status == "running" })
	if tools := e.mgr.AllTools(1, ""); len(tools) != 1 {
		t.Fatalf("tools %v", tools)
	}

	var raw string
	_ = e.db.W.QueryRow(`SELECT config FROM mcp_servers WHERE id = ?`, id).Scan(&raw)
	if strings.Contains(raw, `"good"`) || !strings.Contains(raw, "access_token") {
		t.Fatalf("tokens stored wrongly: %s", raw)
	}
	cfg, _ := e.store.ServerConfig(ctx, id)
	if cfg["auth"].(map[string]any)["tokens"].(map[string]any)["access_token"] != "good" {
		t.Fatalf("tokens not readable: %v", cfg)
	}

	// A restart reuses the stored tokens without asking again.
	e.mgr.Stop(id)
	done := make(chan error, 1)
	go func() {
		_, err := e.mgr.Start(ctx, id, as.URL+"/mcp", "Authed", 1, "")
		done <- err
	}()
	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("restart: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("restart hung")
	}
}
