package guest

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

const testToken = "test-token"

type harness struct {
	t         *testing.T
	srv       *Server
	http      *httptest.Server
	workspace string
	home      string
	runner    *fakeRunner
}

func newHarness(t *testing.T, mutate func(*Config)) *harness {
	t.Helper()
	base := t.TempDir()
	cfg := Config{
		Token: testToken, Port: 1, Profile: "cli",
		RuntimeHome: filepath.Join(base, "home"), DataDir: filepath.Join(base, "home", "data"),
		WorkspaceRoot: filepath.Join(base, "ws"), HomeDir: filepath.Join(base, "user"),
		MinFreeDiskBytes: 1, CloudInitFinishedPath: filepath.Join(base, "boot-finished"),
	}
	if mutate != nil {
		mutate(&cfg)
	}
	srv, err := New(cfg)
	if err != nil {
		t.Skip("cannot build a server here:", err)
	}
	runner := &fakeRunner{}
	srv.desktop = runner
	ts := httptest.NewServer(srv.Handler())
	t.Cleanup(func() { srv.Shutdown(); ts.Close() })
	return &harness{t: t, srv: srv, http: ts, workspace: cfg.WorkspaceRoot, home: cfg.HomeDir, runner: runner}
}

type reply struct {
	status int
	body   string
	header http.Header
}

func (h *harness) do(method, url string, body any, headers map[string]string) reply {
	h.t.Helper()
	var reader io.Reader
	if raw, ok := body.([]byte); ok {
		reader = bytes.NewReader(raw)
	} else if body != nil {
		raw, _ := json.Marshal(body)
		reader = bytes.NewReader(raw)
	}
	req, err := http.NewRequest(method, h.http.URL+url, reader)
	if err != nil {
		h.t.Fatal(err)
	}
	req.Header.Set("Authorization", "Bearer "+testToken)
	if _, raw := body.([]byte); !raw && body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	for k, v := range headers {
		if v == "" {
			req.Header.Del(k)
		} else {
			req.Header.Set(k, v)
		}
	}
	resp, err := (&http.Client{Timeout: 60 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}).Do(req)
	if err != nil {
		h.t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	return reply{resp.StatusCode, string(raw), resp.Header}
}

func (h *harness) json(r reply) map[string]any {
	h.t.Helper()
	var out map[string]any
	if err := json.Unmarshal([]byte(r.body), &out); err != nil {
		h.t.Fatalf("not JSON (%d): %s", r.status, r.body)
	}
	return out
}

func (h *harness) write(rel, content string) string {
	h.t.Helper()
	p := filepath.Join(h.workspace, rel)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		h.t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
		h.t.Fatal(err)
	}
	return p
}

// fakeRunner records the helper commands of the desktop and answers from a script.
type fakeRunner struct {
	calls   []string
	answers func(name string, args []string) cmdResult
	env     [][]string
}

func (f *fakeRunner) run(name string, args []string, _ time.Duration, extraEnv []string) cmdResult {
	f.calls = append(f.calls, strings.Join(append([]string{name}, args...), " "))
	f.env = append(f.env, extraEnv)
	if f.answers != nil {
		return f.answers(name, args)
	}
	return cmdResult{}
}
