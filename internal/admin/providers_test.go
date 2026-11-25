package admin

import (
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
)

func TestProviderSettings(t *testing.T) {
	t.Setenv("TYPESAFE_API_KEY", "abcdefghijklm")
	a := New(Deps{EnvFile: filepath.Join(t.TempDir(), ".env")})
	result, err := a.getProviders(nil)
	if err != nil {
		t.Fatal(err)
	}
	providers := result.(map[string]any)["providers"].([]map[string]any)
	found := false
	for _, p := range providers {
		if p["key"] == "TYPESAFE_API_KEY" {
			found = true
			if p["hint"] != "abcd••••jklm" || p["configured"] != true {
				t.Fatalf("unexpected provider: %#v", p)
			}
		}
	}
	if !found {
		t.Fatal("missing TypeSafe provider")
	}
	for _, body := range []string{`{"key":"SESSION_SECRET","value":"bad"}`, `{"key":"OLLAMA_URL","value":"http://user:pass@example.com"}`} {
		req := httptest.NewRequest(http.MethodPut, "/api/admin/providers", strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		if _, err := a.putProviders(req); err == nil {
			t.Fatalf("accepted %s", body)
		}
	}
	req := httptest.NewRequest(http.MethodPut, "/api/admin/providers", strings.NewReader(`{"key":"OLLAMA_URL","value":"http://localhost:11434"}`))
	req.Header.Set("Content-Type", "application/json")
	t.Setenv("OLLAMA_URL", "")
	if _, err := a.putProviders(req); err != nil {
		t.Fatal(err)
	}
}
