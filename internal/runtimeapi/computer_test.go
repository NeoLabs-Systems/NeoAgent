package runtimeapi

import (
	"context"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/coder/websocket"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/proc"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
	"github.com/NeoLabs-Systems/neolabs-go/vm"

	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guest"
)

// fakeVM runs a real guest agent in-process; a sleeping process stands in
// for the hypervisor and a UNIX socket echoes like a VNC server.
type fakeVM struct {
	t       *testing.T
	mu      sync.Mutex
	inst    map[string]*runtime.Session
	display vm.Address
	stopped func(string)
}

func (f *fakeVM) Readiness() *runtime.Object { return runtime.NewObject("ready", true) }
func (f *fakeVM) Status(key string) *runtime.Object {
	state := runtime.StateStopped
	if s := f.Instance(key); s != nil {
		state = s.State()
	}
	return runtime.NewObject("state", state, "capabilities", f.Capabilities())
}
func (f *fakeVM) Ensure(_ context.Context, key string) (*runtime.Session, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if s := f.inst[key]; s != nil {
		return s, nil
	}
	base := f.t.TempDir()
	srv, err := guest.New(guest.Config{
		Token: "tok", Port: 1, Profile: "cli",
		RuntimeHome: filepath.Join(base, "h"), DataDir: filepath.Join(base, "h", "d"),
		WorkspaceRoot: filepath.Join(base, "ws"), HomeDir: filepath.Join(base, "u"),
		MinFreeDiskBytes: 1, CloudInitFinishedPath: filepath.Join(base, "done"),
	})
	if err != nil {
		return nil, err
	}
	ts := httptest.NewServer(srv.Handler())
	p, err := proc.Start(proc.Spec{Path: "sleep", Args: []string{"600"}})
	if err != nil {
		return nil, err
	}
	f.t.Cleanup(func() { p.Kill(); srv.Shutdown(); ts.Close() })
	s := runtime.NewSession()
	s.BaseURL, s.GuestToken, s.Process, s.DirectBoot, s.StartedAt, s.Display = ts.URL, "tok", p, true, time.Now(), f.display
	f.inst[key] = s
	return s, nil
}
func (f *fakeVM) Alive(key string) bool   { return f.Instance(key).Alive() }
func (f *fakeVM) Tracked(key string) bool { return f.Instance(key) != nil }
func (f *fakeVM) Instance(key string) *runtime.Session {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.inst[key]
}
func (f *fakeVM) Kill(key string) {
	f.mu.Lock()
	s := f.inst[key]
	delete(f.inst, key)
	f.mu.Unlock()
	if s != nil {
		s.Process.Kill()
		<-s.Process.Done()
	}
}
func (f *fakeVM) Fail(key string, _ error)   { f.Kill(key) }
func (f *fakeVM) Sleep(key string)           { f.Kill(key) }
func (f *fakeVM) Shutdown()                  {}
func (f *fakeVM) BootTimeout() time.Duration { return 5 * time.Second }
func (f *fakeVM) GuestHostAddress() string   { return "10.0.2.2" }
func (f *fakeVM) OnStopped(fn func(string))  { f.stopped = fn }
func (f *fakeVM) RemoveUserData(string)      {}
func (f *fakeVM) Capabilities() []string     { return []string{"shell", "files"} }

type stack struct {
	t      *testing.T
	srv    *httptest.Server
	client *http.Client
}

func newStack(t *testing.T, withRuntime bool) (*stack, *fakeVM) {
	t.Helper()
	ctx := context.Background()
	sdb, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "s.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { sdb.Close() })
	store, err := sessionx.NewStore(ctx, sdb.W)
	if err != nil {
		t.Fatal(err)
	}
	sessions, err := sessionx.NewManager(store, sessionx.Options{Name: "neoagent.sid", Secrets: []string{"x"}})
	if err != nil {
		t.Fatal(err)
	}
	f := &fakeVM{t: t, inst: map[string]*runtime.Session{}}
	cfg := ComputerConfig{}
	if withRuntime {
		backend := runtime.NewVMBackend(runtime.BackendOptions{Manager: f, IdleTimeout: -1})
		t.Cleanup(backend.Shutdown)
		cfg.Manager = runtime.NewManager(runtime.ManagerOptions{Backend: backend})
	}
	api := NewComputer(cfg)
	t.Cleanup(api.Close)
	mux := http.NewServeMux()
	api.Routes(mux)
	(&SystemAPI{Manager: cfg.Manager, Getenv: func(string) string { return "" }}).Routes(mux)
	mux.HandleFunc("/test-login", func(w http.ResponseWriter, r *http.Request) {
		id, _ := strconv.ParseInt(r.URL.Query().Get("user"), 10, 64)
		sessionx.FromContext(r.Context()).Set("userId", id)
	})
	srv := httptest.NewServer(sessions.Middleware(mux))
	t.Cleanup(srv.Close)
	jar, _ := cookiejar.New(nil)
	return &stack{t: t, srv: srv, client: &http.Client{Jar: jar}}, f
}

func (s *stack) login(user int) {
	s.t.Helper()
	resp, err := s.client.Get(s.srv.URL + "/test-login?user=" + strconv.Itoa(user))
	if err != nil {
		s.t.Fatal(err)
	}
	resp.Body.Close()
}

func (s *stack) call(method, path string, body any) (int, map[string]any, string) {
	s.t.Helper()
	var reader io.Reader
	if body != nil {
		raw, _ := json.Marshal(body)
		reader = strings.NewReader(string(raw))
	}
	req, _ := http.NewRequest(method, s.srv.URL+path, reader)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := s.client.Do(req)
	if err != nil {
		s.t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	out := map[string]any{}
	_ = json.Unmarshal(raw, &out)
	return resp.StatusCode, out, string(raw)
}

func TestComputerRoutesNeedASession(t *testing.T) {
	s, _ := newStack(t, true)
	if code, _, _ := s.call("GET", "/api/computer/status", nil); code != 401 {
		t.Fatalf("status %d", code)
	}
}

func TestComputerRoutesWithoutRuntime(t *testing.T) {
	s, _ := newStack(t, false)
	s.login(1)
	code, body, _ := s.call("GET", "/api/computer/status", nil)
	if code != 503 || body["error"] != "Computer runtime is unavailable." {
		t.Fatalf("%d %v", code, body)
	}
	code, body, _ = s.call("GET", "/api/system/test/computer", nil)
	if code != 200 || body["passed"] != false || body["detail"] != "Cloud computer runtime is unavailable." {
		t.Fatalf("%d %v", code, body)
	}
}

func TestShellNeedsUserControl(t *testing.T) {
	s, _ := newStack(t, true)
	s.login(1)
	code, body, _ := s.call("POST", "/api/computer/shell/execute", map[string]any{"command": "echo hi"})
	if code != 409 || body["code"] != "COMPUTER_USER_CONTROL_REQUIRED" {
		t.Fatalf("%d %v", code, body)
	}
	code, body, _ = s.call("POST", "/api/computer/control/acquire", map[string]any{})
	if code != 200 || body["ownerType"] != "user" || !strings.HasPrefix(body["ownerId"].(string), "session:") {
		t.Fatalf("%d %v", code, body)
	}
	code, body, _ = s.call("POST", "/api/computer/shell/execute", map[string]any{"command": "echo hi", "cwd": "/tmp"})
	if code != 200 || body["stdout"] != "hi" || body["exitCode"] != float64(0) {
		t.Fatalf("%d %v", code, body)
	}
	code, body, _ = s.call("GET", "/api/computer/status", nil)
	if code != 200 || body["state"] != "user_control" || body["provider"] != "cloud" {
		t.Fatalf("%d %v", code, body)
	}
	code, body, _ = s.call("POST", "/api/computer/control/release", map[string]any{})
	if code != 200 || body["released"] != true {
		t.Fatalf("%d %v", code, body)
	}
	code, body, _ = s.call("PUT", "/api/computer/provider", map[string]any{"provider": "local"})
	if code != 503 || body["code"] != "LOCAL_COMPUTER_UNAVAILABLE" {
		t.Fatalf("%d %v", code, body)
	}
	code, body, _ = s.call("GET", "/api/computer/teach/status", nil)
	if code != 503 || body["error"] != "Teach Mode is unavailable." {
		t.Fatalf("%d %v", code, body)
	}
	code, body, _ = s.call("GET", "/api/system/test/cli", nil)
	if code != 200 || body["passed"] != true || body["backendUsed"] != "cloud-computer" {
		t.Fatalf("%d %v", code, body)
	}
}

func TestNoVNCAssets(t *testing.T) {
	s, _ := newStack(t, true)
	resp, err := http.Get(s.srv.URL + "/api/computer/novnc/core/rfb.js")
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != 200 || !strings.Contains(string(raw), "RFB") || resp.Header.Get("Cache-Control") != "public, max-age=86400, immutable" || !strings.Contains(resp.Header.Get("Content-Type"), "javascript") {
		t.Fatalf("%d %v", resp.StatusCode, resp.Header)
	}
	for _, path := range []string{"/api/computer/novnc/core/", "/api/computer/novnc/missing.js", "/api/computer/novnc/../../etc/passwd"} {
		resp, err := http.Get(s.srv.URL + path)
		if err != nil {
			t.Fatal(err)
		}
		resp.Body.Close()
		if resp.StatusCode != 404 {
			t.Fatalf("%s %d", path, resp.StatusCode)
		}
	}
}

func TestDisplayWebSocketBridgesTheScreen(t *testing.T) {
	s, f := newStack(t, true)
	dir, err := os.MkdirTemp("", "vnc")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)
	l, err := net.Listen("unix", filepath.Join(dir, "v.sock"))
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	go func() {
		for {
			c, err := l.Accept()
			if err != nil {
				return
			}
			go func() { defer c.Close(); _, _ = io.Copy(c, c) }()
		}
	}()
	f.display = vm.Address{Path: l.Addr().String()}
	s.login(1)
	code, body, _ := s.call("POST", "/api/computer/display-session", map[string]any{})
	if code != 200 {
		t.Fatalf("%d %v", code, body)
	}
	wsPath := body["websocketPath"].(string)
	code, _, page := s.call("GET", body["viewUrl"].(string), nil)
	if code != 200 || !strings.Contains(page, wsPath) {
		t.Fatalf("page %d", code)
	}
	u := "ws" + strings.TrimPrefix(s.srv.URL, "http") + wsPath
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	conn, _, err := websocket.Dial(ctx, u, &websocket.DialOptions{HTTPClient: s.client})
	if err != nil {
		t.Fatal(err)
	}
	defer conn.CloseNow()
	if err := conn.Write(ctx, websocket.MessageBinary, []byte("RFB 003.008\n")); err != nil {
		t.Fatal(err)
	}
	typ, data, err := conn.Read(ctx)
	if err != nil || typ != websocket.MessageBinary || string(data) != "RFB 003.008\n" {
		t.Fatalf("%v %q %v", typ, data, err)
	}
	// A token from another session, or none, is refused before the upgrade.
	_, resp, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(s.srv.URL, "http")+"/api/computer/display-ws?token=nope", &websocket.DialOptions{HTTPClient: s.client})
	if err == nil || resp == nil || resp.StatusCode != 403 {
		t.Fatalf("forged token: %v", err)
	}
}
