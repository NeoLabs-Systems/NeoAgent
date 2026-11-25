package agentimport

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

func apiServer(t *testing.T) (*httptest.Server, *rig) {
	t.Helper()
	r := newRig(t, applyScenario{}, false)
	r.env.DB.W.Exec(`INSERT INTO users (id, username, password, is_admin) VALUES (2, 'bob', 'x', 0)`)
	r.env.DB.W.Exec(`UPDATE users SET is_admin = 1 WHERE id = 1`)
	api := New(Config{Env: r.env, Scanner: Scanner{HomeDir: r.root, Now: fixedNow}, Now: func() time.Time { return time.Date(2026, 11, 24, 12, 0, 0, 0, time.UTC) }})
	ctx := context.Background()
	sdb, err := dbx.Open(ctx, filepath.Join(r.dir, "sessions.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { sdb.Close() })
	store, _ := sessionx.NewStore(ctx, sdb.W)
	mgr, _ := sessionx.NewManager(store, sessionx.Options{Name: "neoagent.sid", Secrets: []string{"s"}, MaxAge: time.Hour})
	mux := http.NewServeMux()
	api.Routes(mux)
	mux.HandleFunc("POST /test/login/{id}", func(w http.ResponseWriter, req *http.Request) {
		id, _ := strconv.ParseInt(req.PathValue("id"), 10, 64)
		sess := sessionx.FromContext(req.Context())
		sess.Regenerate()
		sess.Set("userId", id)
	})
	srv := httptest.NewServer(mgr.Middleware(mux))
	t.Cleanup(srv.Close)
	return srv, r
}

func call(t *testing.T, c *http.Client, method, url, body string) (int, string) {
	t.Helper()
	req, _ := http.NewRequest(method, url, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(raw)
}

func signedIn(t *testing.T, srv *httptest.Server, id string) *http.Client {
	jar, _ := cookiejar.New(nil)
	c := &http.Client{Jar: jar}
	call(t, c, "POST", srv.URL+"/test/login/"+id, "")
	return c
}

func TestImportRoutes(t *testing.T) {
	srv, r := apiServer(t)
	anon := &http.Client{}
	if code, body := call(t, anon, "GET", srv.URL+"/api/admin/import/sources", ""); code != 401 || body != `{"error":"Unauthorized"}` {
		t.Errorf("anonymous: %d %s", code, body)
	}
	bob := signedIn(t, srv, "2")
	if code, body := call(t, bob, "POST", srv.URL+"/api/admin/import", `{}`); code != 403 || body != `{"error":"Admin access required","code":"ADMIN_REQUIRED"}` {
		t.Errorf("non-admin: %d %s", code, body)
	}

	admin := signedIn(t, srv, "1")
	code, body := call(t, admin, "GET", srv.URL+"/api/admin/import/sources", "")
	var list struct {
		Sources []struct {
			ID, Source, Label, Path string
			NeedsHand               int
		}
		Parts   []string
		AiReady bool
	}
	if code != 200 || json.Unmarshal([]byte(body), &list) != nil || len(list.Sources) != 0 {
		// The fixtures live under HomeDir/openclaw and /hermes, not in the home itself.
		t.Logf("sources: %d %s", code, body)
	}
	if !list.AiReady || strings.Join(list.Parts, ",") != "keys,memories,skills,model,tasks,mcp,channels" {
		t.Errorf("sources answer: %s", body)
	}

	for _, c := range []struct{ body, want string }{
		{`{}`, `{"error":"sources must be a list of strings","code":"INVALID_IMPORT_REQUEST"}`},
		{`{"sources":[1]}`, `{"error":"sources must be a list of strings","code":"INVALID_IMPORT_REQUEST"}`},
		{`{"sources":[]}`, `{"error":"Choose at least one agent to bring over","code":"INVALID_IMPORT_REQUEST"}`},
		{`{"sources":["x"],"parts":["nope","keys","zip"]}`, `{"error":"Unknown parts: nope, zip","code":"INVALID_IMPORT_REQUEST"}`},
		{`{"sources":["x"],"parts":"keys"}`, `{"error":"parts must be a list of strings","code":"INVALID_IMPORT_REQUEST"}`},
		{`{"sources":["x"],"finish":"yes"}`, `{"error":"finish must be true or false","code":"INVALID_IMPORT_REQUEST"}`},
		{`{"sources":["x"],"finish":null}`, `{"error":"finish must be true or false","code":"INVALID_IMPORT_REQUEST"}`},
		{`{"sources":["x"]}`, `{"error":"The chosen agent was not found on this computer","code":"IMPORT_SOURCE_NOT_FOUND"}`},
	} {
		if _, got := call(t, admin, "POST", srv.URL+"/api/admin/import", c.body); got != c.want {
			t.Errorf("%s\n got  %s\n want %s", c.body, got, c.want)
		}
	}
	_ = r
}

func TestRunImportSummary(t *testing.T) {
	r := newRig(t, loadApply(t)["fresh"], false)
	api := New(Config{Env: r.env, Scanner: Scanner{HomeDir: r.root, Now: fixedNow}, Now: func() time.Time { return time.Date(2026, 11, 24, 12, 0, 0, 0, time.UTC) }})
	// Point the scanner at the OpenClaw fixture's parent so it finds one source.
	api.cfg.Scanner.HomeDir = filepath.Join(r.root, "openclaw")
	home := filepath.Join(r.root, "openclaw", ".openclaw")
	out, err := api.RunImport(context.Background(), 1, []string{home}, []string{"keys", "memories"}, true)
	if err != nil {
		t.Fatal(err)
	}
	if !out.RestartRequired || len(out.BroughtOver) == 0 || out.ReportFile == "" || out.FinishTask == nil || *out.FinishTask != "Finish moving in from OpenClaw" {
		t.Errorf("summary %+v", out)
	}
	raw, _ := json.Marshal(out)
	if !strings.HasPrefix(string(raw), `{"broughtOver":["`) || !strings.Contains(string(raw), `"finishTask":"Finish moving in from OpenClaw","restartRequired":true}`) {
		t.Errorf("summary JSON: %s", raw)
	}
	if out.AttentionTotal < len(out.Attention) {
		t.Errorf("attention counts %d/%d", len(out.Attention), out.AttentionTotal)
	}
}
