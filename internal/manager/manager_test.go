package manager

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"testing"

	"github.com/NeoLabs-Systems/neoagent/internal/release"
	"github.com/NeoLabs-Systems/neoagent/internal/setupcontract"
	"github.com/NeoLabs-Systems/neolabs-go/cli"
	nlrelease "github.com/NeoLabs-Systems/neolabs-go/cli/release"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

func TestParseSetupArguments(t *testing.T) {
	o, err := ParseSetupArguments([]string{"--full", "--json", "--channel=beta", "--runtime-package", "--defer-optional-sections", "--non-interactive"})
	if err != nil || o.Profile != "full" || !o.JSON || o.Channel != "beta" || !o.RuntimePackage || !o.DeferOptionalSections || !o.NonInteractive {
		t.Fatalf("%+v %v", o, err)
	}
	if _, err := ParseSetupArguments([]string{"--quick", "--full"}); cli.CodeOf(err, "") != "SETUP_PROFILE_CONFLICT" {
		t.Fatal(err)
	}
}

func TestResumeAndSections(t *testing.T) {
	start, done, values := prepareResume(&SetupState{Stage: "voice", ResumeValues: map[string]string{"PORT": "4000", "SECRET": "x"}})
	if start != "providers" || strings.Join(done, ",") != "core,network" || values["PORT"] != "4000" || values["SECRET"] != "" {
		t.Fatal(start, done, values)
	}
	if start, _, _ := prepareResume(&SetupState{Stage: "voice"}); start != "core" {
		t.Fatal(start)
	}
	if got := mappedCompleted([]string{"core", "review", "voice"}); strings.Join(got, ",") != "core,voice,network" {
		t.Fatal(got)
	}
	s := safeState(SetupState{ResumeValues: map[string]string{"PORT": "1", "OPENAI_API_KEY": "secret"}})
	if s.ResumeValues["OPENAI_API_KEY"] != "" || s.Stage != "choose-profile" || s.SchemaVersion != setupcontract.C.SchemaVersion {
		t.Fatalf("%+v", s)
	}
}

func TestEnvironmentUpdatesLeaveBlanksOut(t *testing.T) {
	keys, updates := environmentUpdates(map[string]string{"PORT": "3333", "SECURE_COOKIES": "false", "TRUST_PROXY": "false", "OPENAI_API_KEY": "k", "PUBLIC_URL": " "})
	if _, ok := updates["PUBLIC_URL"]; ok {
		t.Fatal("blank value written")
	}
	if updates["SESSION_SECRET"] == "" || updates["NEOAGENT_VM_GUEST_TOKEN"] == "" || updates["OPENAI_API_KEY"] != "k" {
		t.Fatal(updates)
	}
	if keys[0] != "NODE_ENV" || keys[1] != "PORT" {
		t.Fatal(keys)
	}
}

func TestServerProcessPatterns(t *testing.T) {
	for cmd, want := range map[string]bool{
		"/Users/x/.neoagent/app/versions/1/app/bin/neoagent serve": true,
		"neoagent serve":                       true,
		"/usr/local/bin/neoagent status":       false,
		"/opt/homebrew/bin/neoagent-release x": false,
	} {
		if got := goServerPattern.MatchString(cmd); got != want {
			t.Errorf("%q: %v", cmd, got)
		}
	}
	a := newTestApp(t)
	if !a.ownsExecutable(filepath.Join(a.Paths.Home, "app", "versions", "1", "app", "bin", "neoagent")) || a.ownsExecutable("/usr/local/bin/neoagent") {
		t.Fatal("ownership")
	}
	os.MkdirAll(filepath.Dir(a.Service.PlistPath), 0o700)
	os.WriteFile(a.Service.PlistPath, []byte("<string>/opt/node/bin/node</string>\n<string>/srv/NeoAgent/server/index.js</string>"), 0o644)
	if !slices.Contains(a.legacyNodeEntries(), "/srv/NeoAgent/server/index.js") {
		t.Fatal(a.legacyNodeEntries())
	}
	// Servers of other installations are never matched (this one has none).
	for _, p := range a.serverProcesses() {
		if !strings.Contains(p.Command, "/srv/NeoAgent/") {
			t.Fatalf("matched a foreign server: %+v", p)
		}
	}
}

func newTestApp(t *testing.T) *App {
	t.Helper()
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("NEOAGENT_HOME", filepath.Join(home, ".neoagent"))
	t.Setenv("TERMINAL_ENV", "host")
	for _, k := range []string{"PORT", "NEOAGENT_RELEASE_CHANNEL", "NEOAGENT_APP_DIR", "NEOAGENT_ENV_FILE", "NEOAGENT_DATA_DIR", "NEOAGENT_AGENT_DATA_DIR"} {
		t.Setenv(k, "")
		os.Unsetenv(k)
	}
	a, err := New(nil)
	if err != nil {
		t.Fatal(err)
	}
	a.UI = cli.NewUI(true)
	a.Events.JSON = false
	if err := a.Paths.Ensure(); err != nil {
		t.Fatal(err)
	}
	return a
}

func TestBackupSnapshotsLiveDatabaseAndRestore(t *testing.T) {
	a := newTestApp(t)
	ctx := context.Background()
	os.WriteFile(a.Paths.EnvFile, []byte("PORT=4111\n"), 0o600)
	db, err := dbx.Open(ctx, a.dbPath(), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	db.W.ExecContext(ctx, `CREATE TABLE notes (body TEXT)`)
	db.W.ExecContext(ctx, `INSERT INTO notes VALUES ('kept')`)
	os.MkdirAll(filepath.Join(a.Paths.DataDir, "computers", "instances", "u"), 0o700)
	os.WriteFile(filepath.Join(a.Paths.DataDir, "computers", "instances", "u", "disk.qcow2"), []byte("big"), 0o600)
	os.WriteFile(filepath.Join(a.Paths.AgentDataDir, "file.txt"), []byte("agent"), 0o600)

	target, err := a.backupRuntimeData(ctx, "manual")
	if err != nil {
		t.Fatal(err)
	}
	if exists(filepath.Join(target, "data", "computers")) {
		t.Fatal("computer disks copied into the data backup")
	}
	if exists(filepath.Join(target, "data", "neoagent.db-wal")) {
		t.Fatal("WAL copied next to a snapshot")
	}
	snap, _ := sql.Open("sqlite", filepath.Join(target, "data", "neoagent.db"))
	var body string
	if err := snap.QueryRow(`SELECT body FROM notes`).Scan(&body); err != nil || body != "kept" {
		t.Fatalf("snapshot lost the live row: %q %v", body, err)
	}
	snap.Close()

	db.W.ExecContext(ctx, `DELETE FROM notes`)
	db.Close()
	os.WriteFile(a.Paths.EnvFile, []byte("PORT=1\n"), 0o600)
	if err := a.restoreFrom(ctx, target); err != nil {
		t.Fatal(err)
	}
	restored, _ := sql.Open("sqlite", a.dbPath())
	defer restored.Close()
	if err := restored.QueryRow(`SELECT body FROM notes`).Scan(&body); err != nil || body != "kept" {
		t.Fatalf("restore: %q %v", body, err)
	}
	if raw, _ := os.ReadFile(a.Paths.EnvFile); string(raw) != "PORT=4111\n" {
		t.Fatalf("env %q", raw)
	}
}

func TestPruneKeepsNewestThree(t *testing.T) {
	dir := t.TempDir()
	for i := range 5 {
		os.MkdirAll(filepath.Join(dir, fmt.Sprintf("pre-update-%d", i)), 0o700)
	}
	os.MkdirAll(filepath.Join(dir, "manual-1"), 0o700)
	pruneBackups(dir, "pre-update-", 3)
	entries, _ := os.ReadDir(dir)
	if len(entries) != 4 {
		t.Fatal(len(entries))
	}
}

func TestAdminAccountAndPassword(t *testing.T) {
	a := newTestApp(t)
	ctx := context.Background()
	var out strings.Builder
	a.Out = &out
	a.JSON = true
	if err := a.cmdAccount(ctx, []string{"create", "--username", "owner", "--password", "short"}); err == nil {
		t.Fatal("weak password accepted")
	}
	if err := a.cmdAccount(ctx, []string{"create", "--username", "owner", "--password", "Correct-Horse-Battery-9!"}); err != nil {
		t.Fatal(err)
	}
	if err := a.cmdAccount(ctx, []string{"create", "--username", "second", "--password", "Correct-Horse-Battery-9!"}); err == nil {
		t.Fatal("second account created")
	}
	if err := a.cmdAdmin(ctx, []string{"grant", "owner"}); err != nil {
		t.Fatal(err)
	}
	if err := a.cmdAdmin(ctx, []string{"list"}); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out.String(), `{"admins":[{"id":1,"username":"owner"}]}`) {
		t.Fatal(out.String())
	}
	if err := a.cmdResetPassword(ctx, []string{"nobody", "--password-stdin"}); err == nil {
		t.Fatal("unknown account")
	}
}

// TestUpdateSwitchesAndRollsBack serves two releases locally: a working one
// the update switches to, then a broken one it must roll back from.
func TestUpdateSwitchesAndRollsBack(t *testing.T) {
	if testing.Short() {
		t.Skip("builds and starts the server")
	}
	if !slices.Contains(setupcontract.C.RuntimeTargets[Platform()], Architecture()) {
		t.Skip("no runtime target for this computer")
	}
	pub, priv, _ := ed25519.GenerateKey(rand.Reader)
	der, _ := x509.MarshalPKCS8PrivateKey(priv)
	privateKey := base64.StdEncoding.EncodeToString(der)
	t.Setenv("NEOAGENT_RUNTIME_PUBLIC_KEY", base64.StdEncoding.EncodeToString(pub))

	work := t.TempDir()
	good := filepath.Join(work, "good", "neoagent")
	build := exec.Command("go", "build", "-ldflags", "-X github.com/NeoLabs-Systems/neoagent/internal/buildinfo.Version=2.0.0", "-o", good, "../../cmd/neoagent")
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatalf("build: %v\n%s", err, out)
	}
	broken := filepath.Join(work, "broken", "neoagent")
	os.MkdirAll(filepath.Dir(broken), 0o755)
	os.WriteFile(broken, []byte("#!/bin/sh\nexit 1\n"), 0o755)
	web := filepath.Join(work, "public")
	os.MkdirAll(web, 0o755)
	os.WriteFile(filepath.Join(web, "index.html"), []byte("<html>"), 0o644)

	dist := t.TempDir()
	var current string // the release the fake GitHub serves
	publish := func(version, binary string) {
		stage := filepath.Join(work, "stage-"+version)
		if err := release.StageRuntime(release.StageOptions{Output: stage, Binary: binary, WebDir: web, Platform: Platform(), Architecture: Architecture()}); err != nil {
			t.Fatal(err)
		}
		asset := filepath.Join(dist, release.RuntimeAssetName(Platform(), Architecture(), version))
		if err := nlrelease.CreateZip(stage, asset); err != nil {
			t.Fatal(err)
		}
		sum, size, _ := nlrelease.FileDigest(asset)
		m, err := nlrelease.NewRuntimeManifest(1, version, []nlrelease.Artifact{{Platform: Platform(), Architecture: Architecture(), AssetName: filepath.Base(asset), SHA256: sum, SizeBytes: size}}, setupcontract.C.RuntimeTargets)
		if err != nil {
			t.Fatal(err)
		}
		data, _ := nlrelease.Serialize(m)
		sig, _ := nlrelease.Sign(data, privateKey)
		name := release.RuntimeManifestPrefix + version + ".json"
		os.WriteFile(filepath.Join(dist, name), data, 0o644)
		os.WriteFile(filepath.Join(dist, name+".sig"), []byte(sig+"\n"), 0o644)
		current = version
	}
	var srv *httptest.Server
	srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/releases") {
			asset := release.RuntimeAssetName(Platform(), Architecture(), current)
			manifest := release.RuntimeManifestPrefix + current + ".json"
			list := []map[string]any{{"tag_name": "v" + current, "assets": []map[string]string{
				{"name": manifest, "browser_download_url": srv.URL + "/dl/" + manifest},
				{"name": manifest + ".sig", "browser_download_url": srv.URL + "/dl/" + manifest + ".sig"},
				{"name": asset, "browser_download_url": srv.URL + "/dl/" + asset},
			}}}
			json.NewEncoder(w).Encode(list)
			return
		}
		http.ServeFile(w, r, filepath.Join(dist, strings.TrimPrefix(r.URL.Path, "/dl/")))
	}))
	defer srv.Close()

	a := newTestApp(t)
	a.releaseAPI = srv.URL
	l, _ := net.Listen("tcp", "127.0.0.1:0")
	port := l.Addr().(*net.TCPAddr).Port
	l.Close()
	os.WriteFile(a.Paths.EnvFile, []byte("PORT="+strconv.Itoa(port)+"\n"), 0o600)
	t.Setenv("PORT", strconv.Itoa(port))
	// Only ps on PATH: no launchctl or systemctl, so the service runs as a
	// detached process and this machine's real service is never touched.
	bin := filepath.Join(work, "pathbin")
	os.MkdirAll(bin, 0o755)
	if ps, err := exec.LookPath("ps"); err == nil {
		os.Symlink(ps, filepath.Join(bin, "ps"))
	}
	t.Setenv("PATH", bin)
	a.Service.Runner = noServiceManager{a.Service.Runner}
	ctx := context.Background()
	t.Cleanup(func() { a.stopService(); a.waitForServerExit(ctx, 0) })

	publish("2.0.0", good)
	if err := a.cmdUpdate(ctx, nil); err != nil {
		logs, _ := os.ReadFile(filepath.Join(a.Paths.LogDir, "neoagent.error.log"))
		t.Fatalf("update: %v\n%s", err, tail(string(logs), 2000))
	}
	if h := fetchHandshake(ctx, port); h == nil || h.ServerVersion != "2.0.0" {
		t.Fatalf("after update: %+v", h)
	}
	if rt := a.currentRuntime(); rt == nil || rt.Version != "2.0.0" {
		t.Fatalf("current %+v", rt)
	}

	publish("3.0.0", broken)
	err := a.cmdUpdate(ctx, nil)
	if cli.CodeOf(err, "") != "UPDATE_ROLLED_BACK" {
		t.Fatalf("broken update: %v", err)
	}
	if h := fetchHandshake(ctx, port); h == nil || h.ServerVersion != "2.0.0" {
		t.Fatalf("after rollback: %+v", h)
	}
	if rt := a.currentRuntime(); rt == nil || rt.Version != "2.0.0" {
		t.Fatalf("marker after rollback %+v", rt)
	}
}

// noServiceManager hides launchctl and systemctl from the service manager.
type noServiceManager struct {
	inner interface {
		Run(string, ...string) (string, error)
		Exists(string) bool
	}
}

func (n noServiceManager) Run(name string, args ...string) (string, error) {
	return n.inner.Run(name, args...)
}
func (n noServiceManager) Exists(name string) bool {
	return name != "launchctl" && name != "systemctl" && name != "schtasks" && n.inner.Exists(name)
}

func tail(s string, n int) string {
	if len(s) > n {
		return s[len(s)-n:]
	}
	return s
}

func TestRefreshLauncher(t *testing.T) {
	bin := t.TempDir()
	t.Setenv("NEOAGENT_BIN_DIR", bin)
	launcher := filepath.Join(bin, "neoagent")
	if err := os.WriteFile(launcher, []byte("old"), 0o755); err != nil {
		t.Fatal(err)
	}
	rt := installedRuntime{Version: "2.0.0", Dir: t.TempDir()}
	if err := os.MkdirAll(filepath.Dir(rt.binary()), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(rt.binary(), []byte("new"), 0o755); err != nil {
		t.Fatal(err)
	}
	a := &App{}
	if err := a.refreshLauncher(filepath.Join(bin, "other"), rt); err != nil {
		t.Fatal(err)
	}
	if data, _ := os.ReadFile(launcher); string(data) != "old" {
		t.Fatal("replaced an unrelated launcher")
	}
	if err := a.refreshLauncher(launcher, rt); err != nil {
		t.Fatal(err)
	}
	if data, err := os.ReadFile(launcher); err != nil || string(data) != "new" {
		t.Fatalf("launcher = %q, %v", data, err)
	}
}

func TestPruneRuntimesKeepsActiveAndPrevious(t *testing.T) {
	a := newTestApp(t)
	for _, name := range []string{"1.0.0", "2.0.0", "3.0.0", ".staging-work", "unrelated"} {
		if err := os.MkdirAll(filepath.Join(a.versionsDir(), name), 0o700); err != nil {
			t.Fatal(err)
		}
	}
	active := installedRuntime{Version: "3.0.0", Dir: filepath.Join(a.versionsDir(), "3.0.0")}
	for _, name := range []string{active.binary(), filepath.Join(active.appDir(), "public", "index.html")} {
		if err := os.MkdirAll(filepath.Dir(name), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(name, []byte("active"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := a.writeCurrent(active.Version); err != nil {
		t.Fatal(err)
	}
	if err := a.pruneRuntimes(installedRuntime{Version: "3.0.0"}, &installedRuntime{Version: "2.0.0"}); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"2.0.0", "3.0.0", ".staging-work", "unrelated"} {
		if !exists(filepath.Join(a.versionsDir(), name)) {
			t.Fatalf("removed %s", name)
		}
	}
	if exists(filepath.Join(a.versionsDir(), "1.0.0")) {
		t.Fatal("obsolete runtime was not removed")
	}
}

func TestInstallRuntimeDoesNotReplaceActive(t *testing.T) {
	a := newTestApp(t)
	version := "2.0.0"
	rt := installedRuntime{Version: version, Dir: filepath.Join(a.versionsDir(), version)}
	if err := os.MkdirAll(filepath.Dir(rt.binary()), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(rt.binary(), []byte("active"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(rt.appDir(), "public"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(rt.appDir(), "public", "index.html"), []byte("web"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := a.writeCurrent(version); err != nil {
		t.Fatal(err)
	}
	stage := t.TempDir()
	if err := os.MkdirAll(filepath.Join(stage, "app", "bin"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stage, "app", "bin", release.BinaryName(Platform())), []byte("replacement"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(stage, "app", "public"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stage, "app", "public", "index.html"), []byte("web"), 0o644); err != nil {
		t.Fatal(err)
	}
	archive := filepath.Join(t.TempDir(), "runtime.zip")
	if err := nlrelease.CreateZip(stage, archive); err != nil {
		t.Fatal(err)
	}
	if _, err := a.installRuntime(context.Background(), availableRuntime{Version: version}, archive, true); err == nil {
		t.Fatal("replaced active runtime")
	}
	if data, err := os.ReadFile(rt.binary()); err != nil || string(data) != "active" {
		t.Fatalf("active binary = %q, %v", data, err)
	}
}
