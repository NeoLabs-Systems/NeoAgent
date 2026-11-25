package datasharing

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

func TestDataSharingRoutes(t *testing.T) {
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "test.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err = schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err = db.W.Exec(`INSERT INTO users (id,username,email,password) VALUES (1,'user','u@example.com','hash')`); err != nil {
		t.Fatal(err)
	}
	store, err := sessionx.NewStore(ctx, db.W)
	if err != nil {
		t.Fatal(err)
	}
	manager, err := sessionx.NewManager(store, sessionx.Options{Name: "test", Secrets: []string{"test-secret"}})
	if err != nil {
		t.Fatal(err)
	}
	mux := http.NewServeMux()
	(&API{Users: &accounts.Repo{DB: db}}).Routes(mux)
	mux.HandleFunc("POST /login", func(w http.ResponseWriter, r *http.Request) {
		sessionx.FromContext(r.Context()).Set("userId", int64(1))
	})
	handler := manager.Middleware(mux)
	login := httptest.NewRecorder()
	handler.ServeHTTP(login, httptest.NewRequest("POST", "/login", nil))
	cookie := login.Result().Cookies()[0]
	call := func(path, body string) map[string]any {
		t.Helper()
		req := httptest.NewRequest("PUT", path, strings.NewReader(body))
		req.AddCookie(cookie)
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		if rec.Code != 200 {
			t.Fatalf("%s: %d %s", path, rec.Code, rec.Body.String())
		}
		var out map[string]any
		if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
			t.Fatal(err)
		}
		return out["dataSharing"].(map[string]any)
	}
	initial := call("/api/account/data-sharing/client", `{"client":{"platform":"linux"}}`)
	if initial["enabled"] != false {
		t.Fatal(initial)
	}
	on := call("/api/account/data-sharing", `{"enabled":true,"client":{"platform":"LINUX","appVersion":"1.2.3","private":"discard"}}`)
	c := on["client"].(map[string]any)
	if on["enabled"] != true || c["platform"] != "linux" || c["appVersion"] != "1.2.3" || len(c) != 2 {
		t.Fatal(on)
	}
	updated := call("/api/account/data-sharing/client", `{"client":{"platform":"other","appVersion":"bad value"}}`)
	if updated["since"] != on["since"] || updated["client"].(map[string]any)["platform"] != nil {
		t.Fatal(updated)
	}
	off := call("/api/account/data-sharing", `{"enabled":false}`)
	if off["enabled"] != false || off["client"] != nil || off["since"] != nil {
		t.Fatal(off)
	}
}
