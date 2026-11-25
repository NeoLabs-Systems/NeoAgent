package main

import (
	"bufio"
	"encoding/json"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

type cliEnv struct {
	root, home, bin string
	port            int
	env             []string
}

func (c *cliEnv) run(args ...string) (string, error) {
	cmd := exec.Command(c.bin, args...)
	cmd.Env, cmd.Dir = c.env, c.root
	out, err := cmd.CombinedOutput()
	return string(out), err
}

// newCLIEnv builds the binary into a runtime-package layout and prepares a
// throwaway HOME. PATH hides launchctl and systemctl, so the service runs as
// a detached process and the real per-user service of this machine is never
// touched.
func newCLIEnv(t *testing.T) *cliEnv {
	t.Helper()
	if testing.Short() {
		t.Skip("builds and starts the server")
	}
	root := t.TempDir()
	app := filepath.Join(root, "runtime", "app")
	bin := filepath.Join(app, "bin", "neoagent")
	build := exec.Command("go", "build", "-o", bin, ".")
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatalf("build: %v\n%s", err, out)
	}
	for rel, body := range map[string]string{"public/index.html": "<!doctype html><title>NeoAgent</title>", "landing/index.html": "landing"} {
		os.MkdirAll(filepath.Dir(filepath.Join(app, rel)), 0o755)
		os.WriteFile(filepath.Join(app, rel), []byte(body), 0o644)
	}
	home := filepath.Join(root, "home")
	os.MkdirAll(home, 0o700)
	l, _ := net.Listen("tcp", "127.0.0.1:0")
	port := l.Addr().(*net.TCPAddr).Port
	l.Close()
	c := &cliEnv{root: root, home: home, bin: bin, port: port, env: []string{"HOME=" + home, "NEOAGENT_HOME=" + filepath.Join(home, ".neoagent"), "PATH=" + filepath.Join(root, "nobin"),
		"TERMINAL_ENV=host", "PORT=" + strconv.Itoa(port), "TMPDIR=" + os.TempDir()}}
	t.Cleanup(func() { c.run("uninstall") })
	return c
}

func jsonEvents(out string) []map[string]any {
	var list []map[string]any
	sc := bufio.NewScanner(strings.NewReader(out))
	for sc.Scan() {
		var ev map[string]any
		if json.Unmarshal(sc.Bytes(), &ev) == nil {
			list = append(list, ev)
		}
	}
	return list
}

// TestInstallLifecycle drives install, status, backup, restore, stop and
// uninstall.
func TestInstallLifecycle(t *testing.T) {
	c := newCLIEnv(t)
	port, run, events := c.port, c.run, jsonEvents

	out, err := run("install", "--quick", "--non-interactive", "--json", "--runtime-package")
	if err != nil {
		t.Fatalf("install: %v\n%s", err, out)
	}
	evs := events(out)
	last := evs[len(evs)-1]
	if last["state"] != "ready" || last["stage"] != "complete" {
		t.Fatalf("install did not finish: %s", out)
	}
	result := last["result"].(map[string]any)
	if result["backendUrl"] != "http://localhost:"+strconv.Itoa(port) || result["instanceId"] == "" {
		t.Fatalf("result %v", result)
	}

	out, _ = run("status", "--json")
	if ev := events(out); len(ev) != 1 || ev[0]["result"].(map[string]any)["running"] != true {
		t.Fatalf("status: %s", out)
	}
	if _, err := run("healthcheck"); err != nil {
		t.Fatalf("healthcheck failed while running")
	}
	if out, err := run("account", "create", "--username", "owner", "--password", "Correct-Horse-Battery-9!"); err != nil {
		t.Fatalf("account: %v %s", err, out)
	}

	out, err = run("backup", "--json")
	if err != nil {
		t.Fatalf("backup: %v\n%s", err, out)
	}
	var backup struct{ Backup string }
	for _, line := range strings.Split(out, "\n") {
		if strings.HasPrefix(line, `{"backup"`) {
			json.Unmarshal([]byte(line), &backup)
		}
	}
	if _, err := os.Stat(filepath.Join(backup.Backup, "data", "neoagent.db")); err != nil {
		t.Fatalf("backup lacks the database: %s", out)
	}
	if _, err := run("healthcheck"); err != nil {
		t.Fatal("backup left NeoAgent stopped")
	}

	// A second account after the backup disappears again with the restore.
	if out, err := run("reset-password", "owner", "--password-stdin"); err == nil {
		t.Fatalf("reset-password without input succeeded: %s", out)
	}
	out, err = run("restore", backup.Backup)
	if err != nil {
		t.Fatalf("restore: %v\n%s", err, out)
	}
	if _, err := run("healthcheck"); err != nil {
		t.Fatal("restore left NeoAgent stopped")
	}

	if out, err := run("stop"); err != nil {
		t.Fatalf("stop: %v %s", err, out)
	}
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := run("healthcheck"); err != nil {
			return
		}
		time.Sleep(200 * time.Millisecond)
	}
	t.Fatal("server still answers after stop")
}

// TestMigrateAndExec imports the OpenClaw fixture twice (the second run must
// find everything already there) and runs exec, which boots the app without
// its HTTP listener. No AI is connected, so the run itself fails cleanly.
func TestMigrateAndExec(t *testing.T) {
	c := newCLIEnv(t)
	if err := os.CopyFS(c.home, os.DirFS("../../internal/agentimport/testdata/fixtures")); err != nil {
		t.Fatal(err)
	}
	if out, err := c.run("setup", "--quick", "--non-interactive", "--json"); err != nil {
		t.Fatalf("setup: %v\n%s", err, out)
	}
	if out, err := c.run("account", "create", "--username", "owner", "--password", "Correct-Horse-Battery-9!"); err != nil {
		t.Fatalf("account: %v\n%s", err, out)
	}
	from := filepath.Join(c.home, "openclaw", ".openclaw")
	if out, err := c.run("migrate", "--from", from, "--dry-run"); err != nil || !strings.Contains(out, "OpenClaw") {
		t.Fatalf("dry run: %v\n%s", err, out)
	}
	summary := func(out string) map[string]any {
		for _, ev := range jsonEvents(out) {
			if _, ok := ev["broughtOver"]; ok {
				return ev
			}
		}
		t.Fatalf("no summary in:\n%s", out)
		return nil
	}
	out, err := c.run("migrate", "--from", from, "--yes", "--json")
	if err != nil {
		t.Fatalf("migrate: %v\n%s", err, out)
	}
	first := summary(out)
	if brought, _ := first["broughtOver"].([]any); len(brought) == 0 {
		t.Fatalf("nothing brought over: %v", first)
	}
	out, err = c.run("migrate", "--from", from, "--yes", "--json")
	if err != nil {
		t.Fatalf("second migrate: %v\n%s", err, out)
	}
	if again := summary(out); again["alreadyThere"].(float64) == 0 {
		t.Fatalf("second run found nothing already there: %v", again)
	}
	if _, err := os.Stat(filepath.Join(c.home, ".neoagent", "backups")); err != nil {
		t.Fatal("no pre-import backup")
	}

	out, err = c.run("exec", "--yes", "Say hello")
	if err == nil || !strings.Contains(out, "No AI model is available") {
		t.Fatalf("exec without an AI: %v\n%s", err, out)
	}
	if out, err := c.run("exec", "--yes", "--model", "nope/none", "x"); err == nil || !strings.Contains(out, "is not available to this account") {
		t.Fatalf("exec with unknown model: %v\n%s", err, out)
	}
}
