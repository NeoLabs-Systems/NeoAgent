package httpserver

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neolabs-go/secheaders"
	"github.com/NeoLabs-Systems/neolabs-go/testkit"
)

func secheadersFor(c config.Config, analytics string) http.Header {
	return secheaders.Headers(SecurityHeaders(c, analytics))
}

func cfgFor(t *testing.T, env map[string]string) config.Config {
	t.Helper()
	env["SESSION_SECRET"] = "test-secret"
	c, err := config.Load(testkit.Env(env), t.TempDir(), t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func newServer(t *testing.T, c config.Config) http.Handler {
	t.Helper()
	return New(Deps{Config: c, Log: slog.New(slog.NewTextHandler(io.Discard, nil))})
}

func get(h http.Handler, method, target string, headers map[string]string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, target, nil)
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

// The CSP and baseline headers must equal what helmet 8.3 emitted for the same
// options in the Node server (captured in testdata/helmet.json).
func TestSecurityHeadersMatchHelmetCapture(t *testing.T) {
	raw, err := os.ReadFile("testdata/helmet.json")
	if err != nil {
		t.Fatal(err)
	}
	var captured map[string]map[string]string
	if err := json.Unmarshal(raw, &captured); err != nil {
		t.Fatal(err)
	}
	cases := map[string]struct {
		cfg       config.Config
		analytics string
	}{
		"secure":    {cfgFor(t, map[string]string{"PUBLIC_URL": "https://a.example"}), ""},
		"plain":     {cfgFor(t, map[string]string{}), ""},
		"analytics": {cfgFor(t, map[string]string{}), "https://analytics.example.com"},
	}
	for name, c := range cases {
		got := secheadersFor(c.cfg, c.analytics)
		for k, want := range captured[name] {
			if got.Get(k) != want {
				t.Errorf("%s: %s\n got: %q\nwant: %q", name, k, got.Get(k), want)
			}
		}
		for k := range got {
			if _, ok := captured[name][strings.ToLower(k)]; !ok && k != "Permissions-Policy" {
				t.Errorf("%s: unexpected extra header %s", name, k)
			}
		}
		if got.Get("Permissions-Policy") == "" {
			t.Errorf("%s: Permissions-Policy must be sent", name)
		}
	}
}

func TestHealthShape(t *testing.T) {
	rec := get(newServer(t, cfgFor(t, map[string]string{})), "GET", "/api/health", nil)
	if rec.Code != 200 || rec.Header().Get("Cache-Control") != "no-store, max-age=0" {
		t.Fatalf("%d %v", rec.Code, rec.Header())
	}
	var body struct {
		Status    string
		Timestamp string
		Runtime   struct {
			Ready      bool
			IssueCount int
			Summary    string
		}
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Status != "degraded" || body.Runtime.Ready || body.Runtime.IssueCount != 1 ||
		!strings.HasSuffix(body.Timestamp, "Z") || len(body.Timestamp) != len("2006-01-02T15:04:05.000Z") {
		t.Fatalf("%+v", body)
	}
}

func TestUnknownAPIPathsAnswerLikeExpress(t *testing.T) {
	h := newServer(t, cfgFor(t, map[string]string{}))
	rec := get(h, "GET", "/api/nope", nil)
	want := "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n<title>Error</title>\n</head>\n<body>\n<pre>Cannot GET /api/nope</pre>\n</body>\n</html>\n"
	if rec.Code != 404 || rec.Body.String() != want || rec.Header().Get("Content-Security-Policy") != "default-src 'none'" {
		t.Errorf("/api/nope: %d %q %v", rec.Code, rec.Body.String(), rec.Header())
	}
	// A signed-in area checks the session before it can say "not found".
	if rec := get(h, "GET", "/api/memory/nope", nil); rec.Code != 401 || rec.Body.String() != `{"error":"Unauthorized"}` {
		t.Errorf("/api/memory/nope: %d %s", rec.Code, rec.Body.String())
	}
	// The case guard answers mixed-case API paths before routing.
	if rec := get(h, "GET", "/API/health", nil); rec.Code != 404 || !strings.Contains(rec.Body.String(), `"error":"Not found"`) {
		t.Errorf("/API/health: %d %s", rec.Code, rec.Body.String())
	}
}

func TestCrossSiteWriteIsBlocked(t *testing.T) {
	h := newServer(t, cfgFor(t, map[string]string{}))
	rec := get(h, "POST", "/api/anything", map[string]string{"Origin": "https://evil.example"})
	if rec.Code != 403 {
		t.Fatalf("%d", rec.Code)
	}
}

func writeTree(t *testing.T, files map[string]string) string {
	t.Helper()
	dir := t.TempDir()
	for name, body := range files {
		p := filepath.Join(dir, name)
		os.MkdirAll(filepath.Dir(p), 0o755)
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

func TestFlutterAppServing(t *testing.T) {
	web := writeTree(t, map[string]string{
		"index.html":                `<html><head><base href="/"></head></html>`,
		"main.dart.js":              "console.log(1)",
		"flutter_bootstrap.js":      "boot",
		".last_build_id":            "build-42\n",
		"assets/AssetManifest.json": "{}",
	})
	secret := filepath.Join(t.TempDir(), "secret.txt")
	os.WriteFile(secret, []byte("TOP SECRET"), 0o600)

	c := cfgFor(t, map[string]string{})
	c.WebDir = web
	h := newServer(t, c)

	// SPA fallback rewrites base href and is never cached.
	rec := get(h, "GET", "/app/some/client/route", nil)
	if rec.Code != 200 || !strings.Contains(rec.Body.String(), `<base href="/app/">`) ||
		!strings.Contains(rec.Header().Get("Cache-Control"), "no-store") {
		t.Fatalf("%d %q %v", rec.Code, rec.Body.String(), rec.Header())
	}
	// Real files are served; the bootstrap script is no-store, others are revalidated.
	if rec := get(h, "GET", "/app/main.dart.js", nil); rec.Code != 200 || rec.Body.String() != "console.log(1)" ||
		rec.Header().Get("Cache-Control") != "public, max-age=0" || rec.Header().Get("ETag") == "" {
		t.Fatalf("%d %v", rec.Code, rec.Header())
	}
	if rec := get(h, "GET", "/app/flutter_bootstrap.js", nil); !strings.Contains(rec.Header().Get("Cache-Control"), "no-store") {
		t.Fatal("flutter_bootstrap.js must be no-store")
	}
	// Traversal and sibling-secret access are refused (served as the SPA shell, never the file).
	for _, p := range []string{"/app/../../" + secret, "/app/..%2f..%2fetc/passwd", "/app/%2e%2e/%2e%2e/etc/passwd"} {
		if rec := get(h, "GET", p, nil); strings.Contains(rec.Body.String(), "TOP SECRET") || strings.Contains(rec.Body.String(), "root:") {
			t.Fatalf("traversal leaked content via %s", p)
		}
	}
	// Non-GET is refused.
	if rec := get(h, "POST", "/app/x", nil); rec.Code != 405 {
		t.Fatalf("POST: %d", rec.Code)
	}
	// Build id.
	rec = get(h, "GET", "/app-build.json", nil)
	if strings.TrimSpace(rec.Body.String()) != `{"buildId":"build-42"}` {
		t.Fatalf("%s", rec.Body.String())
	}
}

func TestMissingFlutterBuildIs503(t *testing.T) {
	c := cfgFor(t, map[string]string{})
	c.WebDir = t.TempDir()
	rec := get(newServer(t, c), "GET", "/app/", nil)
	if rec.Code != 503 || !strings.Contains(rec.Body.String(), "Flutter web build not found") {
		t.Fatalf("%d %s", rec.Code, rec.Body.String())
	}
	rec = get(newServer(t, c), "GET", "/app-build.json", nil)
	if strings.TrimSpace(rec.Body.String()) != `{"buildId":null}` {
		t.Fatalf("%s", rec.Body.String())
	}
}

func TestLandingAndBrowser404(t *testing.T) {
	c := cfgFor(t, map[string]string{})
	c.Landing = writeTree(t, map[string]string{"index.html": "HOME", "status.html": "STATUS", "404.html": "LOST", "css/a.css": "x"})
	h := newServer(t, c)
	if rec := get(h, "GET", "/", nil); rec.Body.String() != "HOME" {
		t.Fatalf("%q", rec.Body.String())
	}
	if rec := get(h, "GET", "/status", nil); rec.Body.String() != "STATUS" {
		t.Fatalf("%q", rec.Body.String())
	}
	if rec := get(h, "GET", "/css/a.css", nil); rec.Body.String() != "x" {
		t.Fatal("static file")
	}
	rec := get(h, "GET", "/missing", map[string]string{"Accept": "text/html,application/xhtml+xml"})
	if rec.Code != 404 || rec.Body.String() != "LOST" {
		t.Fatalf("browser 404: %d %q", rec.Code, rec.Body.String())
	}
	rec = get(h, "GET", "/missing", map[string]string{"Accept": "application/json"})
	if rec.Code != 404 || !strings.Contains(rec.Body.String(), `"error"`) {
		t.Fatalf("api-style 404: %d %q", rec.Code, rec.Body.String())
	}
}
