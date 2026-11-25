package setupapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"testing"
)

func TestStatusAndMarkSectionFollowSetupContract(t *testing.T) {
	env := map[string]string{"NEOAGENT_SETUP_COMPLETED_SECTIONS": "core,network,voice"}
	get := func(k string) string { return env[k] }
	put := func(k, v string) error { env[k] = v; return nil }
	if err := MarkSectionComplete("providers", get, put); err != nil {
		t.Fatal(err)
	}
	if env["NEOAGENT_SETUP_COMPLETED_SECTIONS"] != "core,network,providers,voice" {
		t.Fatal(env)
	}
	a := New(Config{Getenv: get, UserID: func(*http.Request) (int64, bool) { return 1, true }})
	mux := http.NewServeMux()
	a.Routes(mux)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("GET", "/api/setup/status", nil))
	var out struct {
		Completed []string `json:"completedSections"`
		Open      []string `json:"openSections"`
		Complete  bool     `json:"complete"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(out.Completed, []string{"core", "network", "providers", "voice"}) || !reflect.DeepEqual(out.Open, []string{"integrations", "optional-capabilities"}) || out.Complete {
		t.Fatalf("%+v", out)
	}
}
