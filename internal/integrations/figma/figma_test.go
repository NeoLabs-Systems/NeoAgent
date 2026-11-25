package figma

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

func TestOAuthAndFigmaTools(t *testing.T) {
	var mu sync.Mutex
	var requests []string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		mu.Lock()
		requests = append(requests, r.Method+" "+r.URL.RequestURI()+" "+r.Header.Get("Authorization")+" "+string(raw))
		mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/v1/oauth/token":
			_, _ = w.Write([]byte(`{"access_token":"fresh","refresh_token":"refresh","expires_in":3600}`))
		case "/v1/me":
			_, _ = w.Write([]byte(`{"id":"1","email":"user@example.com","handle":"user"}`))
		default:
			_, _ = w.Write([]byte(`{"ok":true}`))
		}
	}))
	defer server.Close()
	svc := &integrations.Services{HTTP: server.Client()}
	p := newProvider(svc, endpoints{server.URL + "/oauth", server.URL})
	cfg := integrations.OAuthConfig{ClientID: "id", ClientSecret: "secret", RedirectURI: "https://app.example/callback"}
	app := integrations.App{ID: "figma"}
	begin, err := p.begin(context.Background(), integrations.BeginInput{OAuth: cfg, App: app, State: "state"})
	if err != nil {
		t.Fatal(err)
	}
	u, _ := url.Parse(begin.URL)
	if u.Query().Get("scope") != strings.Join(scopes, " ") || u.Query().Get("state") != "state" {
		t.Fatal(begin.URL)
	}
	finish, err := p.finish(context.Background(), integrations.FinishInput{OAuth: cfg, App: app, Code: "code"})
	if err != nil {
		t.Fatal(err)
	}
	if finish.AccountEmail != "user@example.com" || finish.Credentials.String("access_token") != "fresh" {
		t.Fatal(finish)
	}
	tc := &integrations.ToolContext{OAuth: cfg, Credentials: oauthclient.Credentials{"access_token": "old", "refresh_token": "refresh", "expires_at": "2000-01-01T00:00:00.000Z"}}
	out, err := p.execute(context.Background(), "figma_get_file_nodes", map[string]any{"file_key": "file", "ids": "1:2,3:4"}, tc)
	if err != nil {
		t.Fatal(err)
	}
	if !json.Valid(out.(json.RawMessage)) || tc.Credentials.String("access_token") != "fresh" {
		t.Fatal(out, tc.Credentials)
	}
	if _, err := p.execute(context.Background(), "figma_api_request", map[string]any{"path": "https://evil.example/v1/me", "method": "GET"}, tc); err == nil {
		t.Fatal("accepted external host")
	}
	if _, err := p.execute(context.Background(), "figma_get_file", map[string]any{}, tc); err == nil {
		t.Fatal("accepted missing file key")
	}
	mu.Lock()
	defer mu.Unlock()
	if len(requests) != 4 || !strings.Contains(requests[3], "/v1/files/file/nodes?ids=1%3A2%2C3%3A4 Bearer fresh") {
		t.Fatal(requests)
	}
}
