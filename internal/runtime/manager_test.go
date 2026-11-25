package runtime

import (
	"context"
	"errors"
	"net"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/proc"
	"github.com/NeoLabs-Systems/neolabs-go/vm"

	"github.com/NeoLabs-Systems/neoagent/internal/desktop"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guest"
	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
)

// fakeVM boots a real guest agent in-process for each user; a sleeping
// process stands in for the hypervisor so liveness is real.
type fakeVM struct {
	t       *testing.T
	mu      sync.Mutex
	inst    map[string]*Session
	starts  *startTracker
	display vm.Address
	ready   bool
	slept   []string
	stopped func(string)
}

func newFakeVM(t *testing.T) *fakeVM {
	return &fakeVM{t: t, inst: map[string]*Session{}, starts: newStartTracker(), ready: true}
}

func (f *fakeVM) Readiness() *omap {
	return obj("ready", f.ready, "missing", []string{})
}

func (f *fakeVM) Status(key string) *omap {
	f.mu.Lock()
	s := f.inst[key]
	f.mu.Unlock()
	return sessionStatus(s, f.starts.status(key), f.Capabilities(), f.Readiness(), nil, func(*Session) string { return "direct" })
}

func (f *fakeVM) Ensure(ctx context.Context, key string) (*Session, error) {
	f.mu.Lock()
	if s := f.inst[key]; s != nil && s.Alive() {
		f.mu.Unlock()
		return s, nil
	}
	f.mu.Unlock()
	return f.starts.begin(ctx, key, func() (*Session, error) {
		base := f.t.TempDir()
		srv, err := guest.New(guest.Config{
			Token: "tok", Port: 1, Profile: "cli",
			RuntimeHome: filepath.Join(base, "home"), DataDir: filepath.Join(base, "home", "data"),
			WorkspaceRoot: filepath.Join(base, "ws"), HomeDir: filepath.Join(base, "user"),
			MinFreeDiskBytes: 1, CloudInitFinishedPath: filepath.Join(base, "boot-finished"),
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
		s := NewSession()
		s.BaseURL, s.GuestToken, s.Process, s.DirectBoot = ts.URL, "tok", p, true
		s.StartedAt, s.InstanceDir, s.Display = time.Now(), base, f.display
		s.Resources = Allocation{MemoryMb: 1024, CPUs: 1}
		f.mu.Lock()
		f.inst[key] = s
		f.mu.Unlock()
		return s, nil
	})
}

func (f *fakeVM) Alive(key string) bool   { return f.Instance(key).Alive() }
func (f *fakeVM) Tracked(key string) bool { return f.Instance(key) != nil }
func (f *fakeVM) Instance(key string) *Session {
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
		s.SetState(StateStopping)
		s.Process.Kill()
		<-s.Process.Done()
		if f.stopped != nil {
			f.stopped(key)
		}
	}
}
func (f *fakeVM) Fail(key string, err error) { f.Kill(key); f.starts.fail(key, err) }
func (f *fakeVM) Sleep(key string) {
	f.mu.Lock()
	f.slept = append(f.slept, key)
	f.mu.Unlock()
	f.Kill(key)
	f.starts.sleep(key)
}
func (f *fakeVM) Shutdown()                  {}
func (f *fakeVM) BootTimeout() time.Duration { return 5 * time.Second }
func (f *fakeVM) GuestHostAddress() string   { return "10.0.2.2" }
func (f *fakeVM) OnStopped(fn func(string))  { f.stopped = fn }
func (f *fakeVM) RemoveUserData(string)      {}
func (f *fakeVM) Capabilities() []string     { return []string{"browser", "shell", "files"} }

type memArtifacts struct {
	mu    sync.Mutex
	saved []Artifact
}

func (m *memArtifacts) CreateBufferArtifact(_ context.Context, _ string, a Artifact) (StoredArtifact, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.saved = append(m.saved, a)
	return StoredArtifact{ID: "a1", URL: "/api/artifacts/a1/content", StoragePath: "/x/a1.log", ByteSize: int64(len(a.Content))}, nil
}

func newTestManager(t *testing.T, idle time.Duration) (*Manager, *fakeVM, *memArtifacts) {
	f := newFakeVM(t)
	art := &memArtifacts{}
	b := NewVMBackend(BackendOptions{Manager: f, Artifacts: art, IdleTimeout: idle})
	t.Cleanup(b.Shutdown)
	return NewManager(ManagerOptions{Backend: b, Artifacts: art}), f, art
}

func TestExecuteCommandRunsInTheGuest(t *testing.T) {
	m, _, art := newTestManager(t, -1)
	ctx := context.Background()
	res, err := m.ExecuteCommand(ctx, "1", "echo hello", "", ExecOptions{})
	if err != nil {
		t.Fatal(err)
	}
	if !res.Has("exitCode") || res.Float("exitCode") != 0 || res.String("stdout") != "hello" {
		t.Fatalf("result %v", res.Map())
	}
	// The guest's key order is forwarded as the guest wrote it.
	if keys := res.Keys(); keys[0] != "exitCode" || keys[1] != "stdout" {
		t.Fatalf("key order %v", keys)
	}
	big, err := m.ExecuteCLICommand(ctx, "1", "head -c 70000 /dev/zero | tr '\\0' a", "", ExecOptions{})
	if err != nil {
		t.Fatal(err)
	}
	if big.String("backend") != "cloud-computer" || big.Has("outputFilePath") || !big.Has("outputArtifact") {
		t.Fatalf("big %v", big.Keys())
	}
	if len(art.saved) != 1 || art.saved[0].Kind != "command-output" || len(art.saved[0].Content) < 70000 {
		t.Fatalf("artifact %+v", len(art.saved))
	}
	if _, err := m.ExecuteCommand(ctx, "1", "true", ProviderLocal, ExecOptions{}); err == nil {
		t.Fatal("local provider accepted")
	}
}

func TestStatusAndControlLeases(t *testing.T) {
	m, _, _ := newTestManager(t, -1)
	status, err := m.Status("1", "")
	if err != nil || status.String("state") != StateStopped || status.String("provider") != ProviderCloud {
		t.Fatalf("status %v %v", status, err)
	}
	if _, err := m.EnsureComputer(context.Background(), "1", ""); err != nil {
		t.Fatal(err)
	}
	if s, _ := m.Status("1", ""); s.String("state") != StateReady {
		t.Fatalf("state %s", s.String("state"))
	}
	if _, err := m.AcquireControl("1", "user", "session:a", ""); err != nil {
		t.Fatal(err)
	}
	if s, _ := m.Status("1", ""); s.String("state") != "user_control" {
		t.Fatalf("state %s", s.String("state"))
	}
	// Another browser session of the same user may not take over.
	_, err = m.AcquireControl("1", "user", "session:b", "")
	var coded *CodedError
	if !errors.As(err, &coded) || coded.Code != "COMPUTER_CONTROL_CONFLICT" || coded.Status != 409 {
		t.Fatalf("conflict %v", err)
	}
	// An agent run may take over from the user, teach may not take it from the agent.
	if _, err := m.AcquireControl("1", "agent", "run-1", ""); err != nil {
		t.Fatal(err)
	}
	if _, err := m.AcquireControl("1", "teach", "t1", ""); !errors.As(err, &coded) {
		t.Fatalf("teach over agent %v", err)
	}
	if _, err := m.AcquireControl("1", "agent", "run-2", ""); err != nil {
		t.Fatal(err)
	}
	lease := m.ControlLease("1", "")
	if lease == nil || strings.Join(lease.OwnerIDs, ",") != "run-1,run-2" {
		t.Fatalf("lease %+v", lease)
	}
	if !m.ReleaseControl("1", "run-1", "") || m.ControlLease("1", "").OwnerID != "run-2" {
		t.Fatal("partial release")
	}
	if !m.ReleaseControl("1", "", "") || m.ControlLease("1", "") != nil {
		t.Fatal("full release")
	}
	if _, err := m.SetComputerProvider(context.Background(), "1", "local"); !errors.As(err, &coded) || coded.Code != "LOCAL_COMPUTER_UNAVAILABLE" {
		t.Fatalf("local %v", err)
	}
	if _, err := m.Stop(context.Background(), "1", ""); err != nil {
		t.Fatal(err)
	}
	if s, _ := m.Status("1", ""); s.String("state") != StateStopped {
		t.Fatalf("after stop %s", s.String("state"))
	}
}

func TestDisplaySessions(t *testing.T) {
	m, f, _ := newTestManager(t, -1)
	if _, err := m.CreateDisplaySession("1", ""); err == nil {
		t.Fatal("display without a computer")
	}
	dir, err := os.MkdirTemp("", "dsp")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(dir)
	l, err := net.Listen("unix", filepath.Join(dir, "v.sock"))
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	f.display = vm.Address{Path: l.Addr().String()}
	if _, err := m.EnsureDisplay(context.Background(), "1", ""); err != nil {
		t.Fatal(err)
	}
	created, err := m.CreateDisplaySession("1", "")
	if err != nil {
		t.Fatal(err)
	}
	token := created.String("token")
	if !created.Bool("viewOnly") || !strings.HasPrefix(created.String("websocketPath"), "/api/computer/display-ws?token=") {
		t.Fatalf("session %v", created)
	}
	s := m.ResolveDisplaySession("1", token)
	if s == nil || m.ResolveDisplaySession("2", token) != nil {
		t.Fatal("resolve")
	}
	// Taking control replaces the viewers so they reconnect with input rights.
	if _, err := m.AcquireControl("1", "user", "session:a", ""); err != nil {
		t.Fatal(err)
	}
	if m.DisplaySessionActive("1", token, s) {
		t.Fatal("session survived a control change")
	}
	created, _ = m.CreateDisplaySession("1", "")
	if created.Bool("viewOnly") {
		t.Fatal("controlling user got a view-only session")
	}
	f.Kill("1")
	if m.ResolveDisplaySession("1", created.String("token")) != nil {
		t.Fatal("session survived the computer")
	}
}

func TestIdleComputerIsPutToSleep(t *testing.T) {
	m, f, _ := newTestManager(t, 50*time.Millisecond)
	if _, err := m.ExecuteCommand(context.Background(), "1", "true", "", ExecOptions{}); err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(5 * time.Second)
	state := ""
	for time.Now().Before(deadline) && state != StateSleeping {
		time.Sleep(20 * time.Millisecond)
		s, _ := m.Status("1", "")
		state = s.String("state")
	}
	if state != StateSleeping || f.Tracked("1") {
		t.Fatalf("idle computer not asleep: %s", state)
	}
}

func TestValidation(t *testing.T) {
	env := func(v map[string]string) func(string) string { return func(k string) string { return v[k] } }
	ready, issues := ValidationIssues(Validation(nil, env(nil)))
	if ready || strings.Join(issues, "") != "The computer runtime is not available." {
		t.Fatalf("%v %v", ready, issues)
	}
	m, f, _ := newTestManager(t, -1)
	if ready, issues := ValidationIssues(Validation(m, env(nil))); !ready || len(issues) != 0 {
		t.Fatalf("%v %v", ready, issues)
	}
	f.ready = false
	if _, issues := ValidationIssues(Validation(m, env(nil))); issues[0] != "The QEMU computer runtime is not installed. Run neoagent repair." {
		t.Fatal(issues)
	}
	if _, issues := ValidationIssues(Validation(m, env(map[string]string{"TERMINAL_ENV": "docker"}))); issues[0] != "The container computer runtime needs a reachable Docker daemon. Run neoagent repair." {
		t.Fatal(issues)
	}
}

func TestQemuReadinessNamesWhatIsMissing(t *testing.T) {
	dir := t.TempDir()
	m := NewQemuManager(QemuOptions{
		Dirs: Dirs{AppDir: dir, RuntimeHome: dir, DataDir: filepath.Join(dir, "data")},
		Env:  Env{Getenv: func(string) string { return "" }}, Architecture: "x64",
		QemuBinary: "-", QemuImgBinary: "-", Accelerators: []string{"tcg"},
		Profile: &ResourceProfile{},
	})
	r := m.Readiness()
	var missing []string
	r.Decode("missing", &missing)
	if r.Bool("ready") || len(missing) != 2 || missing[0] != "qemu-system-x86_64" || missing[1] != "qemu-img" {
		// the guest agent may be found next to the test binary only by accident
		if len(missing) != 3 {
			t.Fatalf("missing %v", missing)
		}
	}
	if _, err := m.Ensure(context.Background(), "1"); err == nil || !strings.Contains(err.Error(), "QEMU computer runtime is unavailable") {
		t.Fatalf("ensure %v", err)
	}
	for _, sub := range []string{"computers/images", "computers/instances"} {
		info, err := os.Stat(filepath.Join(dir, "data", sub))
		if err != nil || info.Mode().Perm() != 0o700 {
			t.Fatalf("%s %v", sub, err)
		}
	}
}

func TestGuestImageDockerfile(t *testing.T) {
	df := GuestImageDockerfile("debian:trixie-slim", "browser_cli")
	for _, want := range []string{"FROM debian:trixie-slim", "chromium", "COPY neoagent-guest /usr/local/bin/neoagent-guest", "touch /var/lib/neoagent/browser-runtime-ready", `CMD ["/usr/local/bin/neoagent-guest"]`} {
		if !strings.Contains(df, want) {
			t.Fatalf("missing %q in\n%s", want, df)
		}
	}
	if strings.Contains(GuestImageDockerfile("x", "cli"), "chromium") {
		t.Fatal("cli image installs a browser")
	}
}

func TestHostRuntimeRunsOnThisServer(t *testing.T) {
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'u', 'x')`); err != nil {
		t.Fatal(err)
	}
	devices := desktop.NewRegistry(desktop.Options{DB: db, Heartbeat: time.Hour})
	ws, _ := workspace.New(t.TempDir(), false)
	host := &LocalBackend{Registry: devices, Host: &desktop.HostCompanion{Registry: devices, Workspaces: ws}}
	m := NewManager(ManagerOptions{Host: host, Local: &LocalBackend{Registry: devices}, DB: db})
	defer m.Shutdown()
	res, err := m.ExecuteCLICommand(ctx, "1", "echo from-host", "", ExecOptions{Cwd: WorkspaceDir})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(res.String("stdout"), "from-host") || res.String("backend") != "cloud-computer" {
		t.Fatalf("%v", res.Map())
	}
	status, _ := m.Status("1", "")
	var caps []string
	status.Decode("capabilities", &caps)
	if status.String("state") != StateReady || strings.Join(caps, ",") != "shell,files" {
		t.Fatalf("status %v", status.Map())
	}
	env := func(k string) string {
		if k == "TERMINAL_ENV" {
			return "host"
		}
		return ""
	}
	v := Validation(m, env)
	var warnings []string
	v.Decode("warnings", &warnings)
	if ready, _ := ValidationIssues(v); !ready || len(warnings) != 1 || !strings.Contains(warnings[0], "TERMINAL_ENV=host") {
		t.Fatalf("validation %v", v.Map())
	}
	// The host companion shares the device registry, so the local provider
	// sees it as this user's connected device, as in Node.
	if _, err := m.SetComputerProvider(ctx, "1", "local"); err != nil {
		t.Fatal(err)
	}
	if d, err := m.CreateDisplaySession("1", ""); err != nil || !d.Bool("local") {
		t.Fatalf("display %v %v", d, err)
	}
	m.Shutdown()
	if _, err := m.CreateDisplaySession("1", ""); err == nil || !strings.Contains(err.Error(), "not connected") {
		t.Fatalf("display after shutdown %v", err)
	}
}
