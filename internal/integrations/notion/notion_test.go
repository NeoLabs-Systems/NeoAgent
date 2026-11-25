package notion

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neolabs-go/oauthclient"
)

func TestOAuthAndNotionTools(t *testing.T) {
	var mu sync.Mutex
	var requests []string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		mu.Lock()
		requests = append(requests, r.Method+" "+r.URL.RequestURI()+" "+r.Header.Get("Authorization")+" "+r.Header.Get("Notion-Version")+" "+string(raw))
		mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		if r.URL.Path == "/v1/oauth/token" {
			_, _ = w.Write([]byte(`{"access_token":"token","workspace_id":"workspace","workspace_name":"Team","owner":{"type":"user","user":{"id":"id","person":{"email":"user@example.com"}}}}`))
		} else {
			_, _ = w.Write([]byte(`{"object":"list"}`))
		}
	}))
	defer server.Close()
	p := newProvider(&integrations.Services{HTTP: server.Client()}, server.URL)
	cfg := integrations.OAuthConfig{ClientID: "id", ClientSecret: "secret", RedirectURI: "https://app.example/callback"}
	app := integrations.App{ID: "notion"}
	begin, err := p.begin(context.Background(), integrations.BeginInput{OAuth: cfg, App: app, State: "state"})
	if err != nil {
		t.Fatal(err)
	}
	u, _ := url.Parse(begin.URL)
	if u.Query().Get("owner") != "user" || u.Query().Get("state") != "state" {
		t.Fatal(begin)
	}
	result, err := p.finish(context.Background(), integrations.FinishInput{OAuth: cfg, App: app, Code: "code"})
	if err != nil || result.AccountEmail != "user@example.com" || result.Credentials.String("access_token") != "token" {
		t.Fatal(result, err)
	}
	tc := &integrations.ToolContext{Credentials: oauthclient.Credentials{"access_token": "token"}}
	out, err := p.execute(context.Background(), "notion_query_database", map[string]any{"database_id": "db", "page_size": float64(500)}, tc)
	if err != nil || !json.Valid(out.(json.RawMessage)) {
		t.Fatal(out, err)
	}
	if _, err := p.execute(context.Background(), "notion_api_request", map[string]any{"method": "GET", "path": "https://evil.example/v1/users"}, tc); err == nil {
		t.Fatal("accepted foreign host")
	}
	mu.Lock()
	defer mu.Unlock()
	if len(requests) != 2 || !strings.Contains(requests[1], "POST /v1/databases/db/query Bearer token 2022-06-28") || !strings.Contains(requests[1], `"page_size":100`) {
		t.Fatal(requests)
	}
}
