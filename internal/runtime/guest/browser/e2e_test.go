package browser

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/cloudsec"
)

const testPage = `<!doctype html><html><head><title>Tide Pools</title></head><body>
<main><h1>Tide pools</h1><p>A tide pool is a rocky pool on the seashore, left behind by the sea at low tide.</p>
<a id="next" href="/second">Read the second page</a>
<form action="/login" method="post"><input id="user" name="user"><input id="pass" name="pass" type="password"><button type="submit">Sign in</button></form>
<input id="q"><div id="out"></div>
<script>document.getElementById('q').addEventListener('keydown', (e) => { if (e.key === 'Enter') document.getElementById('out').textContent = 'entered:' + e.target.value; });</script>
</main></body></html>`

func freePort(t *testing.T) int {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}

// newBrowser starts a controller against a headless local Chrome, or skips.
func newBrowser(t *testing.T) (*Controller, *httptest.Server) {
	t.Helper()
	probe := &Controller{cfg: Config{Getenv: os.Getenv}}
	if probe.executable() == "" {
		t.Skip("no Chrome or Chromium installed")
	}
	site := http.NewServeMux()
	site.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		_, _ = io.WriteString(w, testPage)
	})
	site.HandleFunc("/second", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		_, _ = io.WriteString(w, `<html><head><title>Second</title></head><body><p>Just a moment...</p></body></html>`)
	})
	site.HandleFunc("/login", func(w http.ResponseWriter, r *http.Request) {
		_ = r.ParseForm()
		w.Header().Set("Content-Type", "text/html")
		_, _ = io.WriteString(w, `<html><head><title>Welcome `+r.FormValue("user")+`</title></head><body>ok</body></html>`)
	})
	srv := httptest.NewServer(site)
	t.Cleanup(srv.Close)

	dir, err := os.MkdirTemp("", "gbrowser")
	if err != nil {
		t.Fatal(err)
	}
	marker := filepath.Join(dir, "ready")
	_ = os.WriteFile(marker, nil, 0o600)
	c, err := New(Config{
		DataDir: filepath.Join(dir, "data"), ReadyMarker: marker, CDPPort: freePort(t),
		ExtraArgs: []string{"--headless=new", "--window-size=1280,900"},
		Validate: func(_ context.Context, raw string) (cloudsec.Result, error) {
			if strings.HasPrefix(raw, srv.URL) {
				return cloudsec.Result{Allowed: true}, nil
			}
			return cloudsec.Check(raw), nil
		},
		Sleep: func(ctx context.Context, d time.Duration) error { return ctx.Err() },
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		c.Shutdown()
		// Chromium was started detached, as on the desktop; stop it by profile.
		_ = exec.Command("pkill", "-f", "--", "--user-data-dir="+c.profileDir).Run()
		for i := 0; i < 50; i++ {
			if os.RemoveAll(dir) == nil {
				return
			}
			time.Sleep(100 * time.Millisecond)
		}
	})
	return c, srv
}

func asJSON(t *testing.T, v any) map[string]any {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	out := map[string]any{}
	_ = json.Unmarshal(raw, &out)
	return out
}

func TestBrowserAgainstChrome(t *testing.T) {
	c, site := newBrowser(t)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	res, err := c.Navigate(ctx, site.URL+"/", NavigateOptions{ChallengeRetry: true, Screenshot: true})
	if err != nil {
		t.Fatal(err)
	}
	nav := asJSON(t, res)
	if nav["title"] != "Tide Pools" || nav["status"] != float64(200) || !strings.Contains(nav["pageContent"].(string), "A tide pool is a rocky pool") || nav["referrerMode"] != "direct" {
		t.Fatalf("navigate %v", nav)
	}
	if shot, _ := nav["fullPath"].(string); shot == "" {
		t.Fatal("no screenshot")
	} else if raw, err := os.ReadFile(shot); err != nil || !bytes.HasPrefix(raw, []byte("\x89PNG")) {
		t.Fatalf("screenshot %v", err)
	}
	raw, _ := json.Marshal(res)
	if !strings.HasPrefix(string(raw), `{"title":"Tide Pools","url":`) || !strings.Contains(string(raw), `"challengeRetried":false,"screenshotPath":"/screenshots/`) {
		t.Fatalf("key order %s", raw)
	}

	blocked, _ := c.Navigate(ctx, "http://169.254.169.254/latest", NavigateOptions{Screenshot: true})
	if b := asJSON(t, blocked); b["error"] == nil || b["url"] != "http://169.254.169.254/latest" {
		t.Fatalf("blocked %v", b)
	}

	ev, _ := c.Evaluate(ctx, "const a = {x: 1, y: [2]}; a")
	if e := asJSON(t, ev); e["result"] != `{"x":1,"y":[2]}` {
		t.Fatalf("evaluate %v", e)
	}
	ev, _ = c.Evaluate(ctx, "const a = 1; undefined")
	if e := asJSON(t, ev); e["result"] != "undefined" {
		t.Fatalf("evaluate undefined %v", e)
	}
	ev, _ = c.Evaluate(ctx, "throw new Error('boom')")
	if e := asJSON(t, ev); !strings.Contains(e["error"].(string), "boom") {
		t.Fatalf("evaluate throw %v", e)
	}

	ex, _ := c.Extract(ctx, "h1", "", false)
	if e := asJSON(t, ex); e["result"] != "Tide pools" {
		t.Fatalf("extract %v", e)
	}
	ex, _ = c.Extract(ctx, "input", "id", true)
	if e := asJSON(t, ex); len(e["results"].([]any)) != 3 {
		t.Fatalf("extract all %v", e)
	}
	ex, _ = c.Extract(ctx, "#missing", "", false)
	if e := asJSON(t, ex); e["error"] == nil {
		t.Fatalf("extract missing %v", e)
	}

	filled, _ := c.Fill(ctx, "#q", "hello", FillOptions{Clear: true, PressEnter: true})
	if f := asJSON(t, filled); f["success"] != true || f["typed"] != "hello" {
		t.Fatalf("fill %v", f)
	}
	ex, _ = c.Extract(ctx, "#out", "", false)
	if e := asJSON(t, ex); e["result"] != "entered:hello" {
		t.Fatalf("after enter %v", e)
	}
	if k, _ := c.PressKey(ctx, "", false); asJSON(t, k)["error"] != "key required" {
		t.Fatal("empty key accepted")
	}
	if k, _ := c.PressKey(ctx, "Control+A", false); asJSON(t, k)["key"] != "Control+A" {
		t.Fatal("press key")
	}
	if s, _ := c.Scroll(ctx, 0, 300, false); asJSON(t, s)["success"] != true {
		t.Fatal("scroll")
	}
	if p, _ := c.ClickPoint(ctx, "x", 10, false); asJSON(t, p)["error"] != "x coordinate must be a finite number." {
		t.Fatal("bad coordinate accepted")
	}
	jpeg, err := c.ScreenshotJPEG(ctx, float64(10), false, "")
	if err != nil || !bytes.HasPrefix(jpeg, []byte{0xff, 0xd8}) {
		t.Fatalf("jpeg %v", err)
	}

	clicked, _ := c.Click(ctx, "", "second page", false)
	if cl := asJSON(t, clicked); cl["success"] != true {
		t.Fatalf("click %v", cl)
	}
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		st, _ := c.Status(ctx)
		if st.PageInfo.Title != nil && *st.PageInfo.Title == "Second" {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	st, err := c.Status(ctx)
	if err != nil || !st.Launched || st.Pages < 1 || st.PageInfo.Title == nil || *st.PageInfo.Title != "Second" {
		t.Fatalf("status %+v %v", st, err)
	}
	if nf, _ := c.Click(ctx, "", "no such text", false); asJSON(t, nf)["error"] != "No clickable element found with text: no such text" {
		t.Fatal("click without match")
	}
}

func TestProtectedCredentialFillThroughRoutes(t *testing.T) {
	c, site := newBrowser(t)
	mux := http.NewServeMux()
	Mount(mux.Handle, c)
	api := httptest.NewServer(mux)
	defer api.Close()
	post := func(path string, body any) (int, map[string]any) {
		raw, _ := json.Marshal(body)
		resp, err := http.Post(api.URL+path, "application/json", bytes.NewReader(raw))
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		out := map[string]any{}
		_ = json.NewDecoder(resp.Body).Decode(&out)
		return resp.StatusCode, out
	}
	if code, nav := post("/browser/navigate", map[string]any{"url": site.URL + "/", "screenshot": false}); code != 200 || nav["title"] != "Tide Pools" {
		t.Fatalf("%d %v", code, nav)
	}
	code, fill := post("/browser/credential-fill", map[string]any{"allowedOrigin": site.URL, "usernameSelector": "#user", "passwordSelector": "#pass", "username": "ada", "password": "s3cret"})
	if code != 200 || fill["success"] != true {
		t.Fatalf("%d %v", code, fill)
	}
	if code, body := post("/browser/click", map[string]any{"selector": "#next"}); code != 423 || body["code"] != "PROTECTED_CREDENTIAL_FILL_ACTIVE" {
		t.Fatalf("gate %d %v", code, body)
	}
	code, done := post("/browser/credential-submit", map[string]any{"protectedFillId": fill["protectedFillId"]})
	if code != 200 || done["title"] != "Welcome ada" || done["protected"] != false {
		t.Fatalf("%d %v", code, done)
	}
	if code, body := post("/browser/credential-cancel", map[string]any{"protectedFillId": "x"}); code != 500 || body["error"] != "Protected credential fill is missing or expired." {
		t.Fatalf("%d %v", code, body)
	}
}

func TestRoutesWithoutBrowserProfile(t *testing.T) {
	mux := http.NewServeMux()
	Mount(mux.Handle, nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("GET", "/browser/status", nil))
	if rec.Code != 500 || !strings.Contains(rec.Body.String(), "browser runtime is unavailable in this guest profile.") {
		t.Fatalf("%d %s", rec.Code, rec.Body.String())
	}
}
