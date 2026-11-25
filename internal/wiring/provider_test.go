package wiring

import (
	"context"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestBYOKTestRejectsMissingCredentialsAndPrivateEndpoints(t *testing.T) {
	a := settingsCatalogAdapter{}
	for _, tc := range []struct {
		id   string
		body map[string]any
		want string
	}{
		{"invalid", nil, "Unknown provider"},
		{"openai", map[string]any{"baseUrl": "https://example.com"}, "requires the API key"},
		{"ollama", map[string]any{"baseUrl": "http://127.0.0.1:1"}, "public address"},
	} {
		result, err := a.BYOKTest(context.Background(), 1, "main", tc.id, tc.body)
		if tc.want != "" {
			if err == nil || !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("%s: %v", tc.id, err)
			}
			continue
		}
		if err != nil {
			t.Fatal(err)
		}
		if result.(map[string]any)["ok"] != false {
			t.Fatalf("private endpoint accepted: %v", result)
		}
	}
}

func TestRuntimeProviderUsesConfiguredEnvironment(t *testing.T) {
	var authorization string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authorization = r.Header.Get("Authorization")
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"data":[{"id":"model-a"}]}`))
	}))
	defer srv.Close()
	t.Setenv("OPENAI_API_KEY", "server-key")
	t.Setenv("OPENAI_BASE_URL", srv.URL)
	rt, ok := runtimeProvider(settings.ProviderStatus{ID: "openai", SupportsAPIKey: true, SupportsBaseURL: true})
	if !ok {
		t.Fatal("configured provider unavailable")
	}
	list, err := rt.provider.Models(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(list) != 1 || list[0].ID != "model-a" || authorization != "Bearer server-key" {
		t.Fatalf("models %v authorization %q", list, authorization)
	}
}
