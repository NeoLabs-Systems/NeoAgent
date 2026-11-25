package guestproto

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

func TestChromiumCommand(t *testing.T) {
	want := "chromium --user-data-dir=/home/neo/.neoagent/data/browser-profiles/default --no-first-run --no-default-browser-check --restore-last-session --hide-crash-restore-bubble --disable-session-crashed-bubble --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 --remote-allow-origins=*"
	if got := ChromiumDesktopCommand(""); got != want {
		t.Fatalf("got %s", got)
	}
	if ChromiumCDPEndpoint() != "http://127.0.0.1:9222" {
		t.Fatal("endpoint")
	}
}

func TestMarkSessionClean(t *testing.T) {
	dir := t.TempDir()
	os.MkdirAll(filepath.Join(dir, "Default"), 0o700)
	prefs := filepath.Join(dir, "Default", "Preferences")
	os.WriteFile(prefs, []byte(`{"a":1,"profile":{"exit_type":"Crashed","x":2}}`), 0o600)
	if !MarkChromiumSessionClean(dir) {
		t.Fatal("not updated")
	}
	raw, _ := os.ReadFile(prefs)
	if !strings.Contains(string(raw), `"exit_type":"Normal"`) || !strings.Contains(string(raw), `"exited_cleanly":true`) || !strings.Contains(string(raw), `"x":2`) {
		t.Fatalf("%s", raw)
	}
	if MarkChromiumSessionClean(dir) {
		t.Fatal("second run should not change anything")
	}
	os.Symlink("host-"+strconv.Itoa(os.Getpid()), filepath.Join(dir, "SingletonLock"))
	if !IsChromiumProfileInUse(dir) {
		t.Fatal("live lock not detected")
	}
	os.WriteFile(prefs, []byte(`{"profile":{}}`), 0o600)
	if MarkChromiumSessionClean(dir) {
		t.Fatal("must not touch a profile in use")
	}
}
