package spotify

import (
	"context"
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

func TestOAuthRefreshSearchAndPlayback(t *testing.T) {
	var mu sync.Mutex
	var calls []string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		mu.Lock()
		calls = append(calls, r.Method+" "+r.URL.RequestURI()+" "+r.Header.Get("Authorization")+" "+string(raw))
		mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case "/api/token":
			_, _ = w.Write([]byte(`{"access_token":"fresh","refresh_token":"refresh","expires_in":3600}`))
		case "/v1/me":
			_, _ = w.Write([]byte(`{"id":"1","email":"user@example.com"}`))
		case "/v1/me/player/pause":
			w.WriteHeader(204)
		default:
			_, _ = w.Write([]byte(`{"tracks":{}}`))
		}
	}))
	defer server.Close()
	p := newProvider(&integrations.Services{HTTP: server.Client()}, endpoints{server.URL, server.URL})
	cfg := integrations.OAuthConfig{ClientID: "id", ClientSecret: "secret", RedirectURI: "https://app.example/callback"}
	app := integrations.App{ID: "spotify"}
	begin, err := p.begin(context.Background(), integrations.BeginInput{OAuth: cfg, App: app, State: "state"})
	if err != nil {
		t.Fatal(err)
	}
	u, _ := url.Parse(begin.URL)
	if u.Query().Get("scope") != strings.Join(scopes, " ") || u.Query().Get("state") != "state" {
		t.Fatal(begin)
	}
	finish, err := p.finish(context.Background(), integrations.FinishInput{OAuth: cfg, App: app, Code: "code"})
	if err != nil || finish.AccountEmail != "user@example.com" {
		t.Fatal(finish, err)
	}
	tc := &integrations.ToolContext{OAuth: cfg, Credentials: oauthclient.Credentials{"access_token": "old", "refresh_token": "refresh", "expires_at": "2000-01-01T00:00:00.000Z"}}
	if _, err = p.execute(context.Background(), "spotify_search", map[string]any{"query": "song", "type": "artist,unknown", "limit": float64(100)}, tc); err != nil {
		t.Fatal(err)
	}
	out, err := p.execute(context.Background(), "spotify_control_playback", map[string]any{"action": "pause"}, tc)
	if err != nil || out.(map[string]any)["ok"] != true {
		t.Fatal(out, err)
	}
	if _, err = p.execute(context.Background(), "spotify_control_playback", map[string]any{"action": "seek"}, tc); err == nil {
		t.Fatal("accepted missing seek position")
	}
	if _, err = p.execute(context.Background(), "spotify_api_request", map[string]any{"path": "https://evil.example/v1/me"}, tc); err == nil {
		t.Fatal("accepted foreign host")
	}
	mu.Lock()
	defer mu.Unlock()
	if len(calls) != 5 || !strings.Contains(calls[3], "/v1/search?limit=50&q=song&type=artist Bearer fresh") || !strings.Contains(calls[4], "PUT /v1/me/player/pause Bearer fresh") {
		t.Fatal(calls)
	}
}
