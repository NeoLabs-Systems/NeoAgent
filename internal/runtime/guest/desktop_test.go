package guest

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDesktopInputCommands(t *testing.T) {
	h := newHarness(t, nil)
	t.Setenv("DISPLAY", "")
	cases := []struct {
		url  string
		body map[string]any
		call string
		want string
	}{
		{"/desktop/click", map[string]any{"x": 10.5, "y": -0.5, "button": 3}, "xdotool mousemove --sync 11 0 click 3", `{"success":true,"x":11,"y":0}`},
		{"/desktop/click", map[string]any{"x": "7", "y": 8}, "xdotool mousemove --sync 7 8 click 1", `{"success":true,"x":7,"y":8}`},
		{"/desktop/mouse-move", map[string]any{"x": 1, "y": 2}, "xdotool mousemove --sync 1 2", `{"success":true,"x":1,"y":2}`},
		{"/desktop/drag", map[string]any{"startX": 1, "startY": 2, "endX": 3.4, "endY": 4}, "xdotool mousemove --sync 1 2 mousedown 1 mousemove --sync 3 4 mouseup 1", `{"success":true}`},
		{"/desktop/scroll", map[string]any{"deltaY": -250}, "xdotool click --repeat 3 4", `{"success":true,"deltaY":-250}`},
		{"/desktop/scroll", map[string]any{"deltaY": 99999}, "xdotool click --repeat 20 5", `{"success":true,"deltaY":99999}`},
		{"/desktop/scroll", map[string]any{}, "xdotool click --repeat 1 5", `{"success":true,"deltaY":0}`},
		{"/desktop/type-text", map[string]any{"text": "héllo 😀"}, "xdotool type --clearmodifiers --delay 1 -- héllo 😀", `{"success":true,"length":8}`},
		{"/desktop/press-key", map[string]any{"key": "ctrl+shift+T"}, "xdotool key --clearmodifiers ctrl+shift+T", `{"success":true,"key":"ctrl+shift+T"}`},
	}
	for _, c := range cases {
		h.runner.calls = nil
		r := h.do("POST", c.url, c.body, nil)
		if r.status != 200 || r.body != c.want || len(h.runner.calls) != 1 || h.runner.calls[0] != c.call {
			t.Fatalf("%s %v\n status %d body %s\n calls %v\n want %s / %s", c.url, c.body, r.status, r.body, h.runner.calls, c.call, c.want)
		}
		if env := h.runner.env[0]; len(env) != 1 || env[0] != "DISPLAY=:0" {
			t.Fatalf("display env %v", env)
		}
	}
	for url, body := range map[string]map[string]any{
		"/desktop/click":      {"x": 1},
		"/desktop/drag":       {"startX": 1, "startY": 1, "endX": 1},
		"/desktop/press-key":  {"key": "a;rm -rf /"},
		"/desktop/type-text":  {"text": strings.Repeat("a", 10001)},
		"/desktop/launch-app": {"app": "calculator"},
	} {
		h.runner.calls = nil
		if r := h.do("POST", url, body, nil); r.status != 500 || len(h.runner.calls) != 0 {
			t.Fatalf("%s accepted %v: %d %s %v", url, body, r.status, r.body, h.runner.calls)
		}
	}
}

func TestDesktopCommandFailureShowsTheTool(t *testing.T) {
	h := newHarness(t, nil)
	h.runner.answers = func(name string, args []string) cmdResult { return cmdResult{Status: 1, Stderr: "no display\n"} }
	r := h.do("POST", "/desktop/click", map[string]any{"x": 1, "y": 1}, nil)
	if r.status != 500 || r.body != `{"error":"no display"}` {
		t.Fatalf("%d %s", r.status, r.body)
	}
	h.runner.answers = func(name string, args []string) cmdResult { return cmdResult{Status: 2} }
	if r := h.do("POST", "/desktop/click", map[string]any{"x": 1, "y": 1}, nil); r.body != `{"error":"xdotool failed with exit code 2."}` {
		t.Fatalf("%s", r.body)
	}
}

func TestDesktopStatus(t *testing.T) {
	h := newHarness(t, nil)
	h.runner.answers = func(name string, args []string) cmdResult {
		switch name {
		case "xdotool":
			return cmdResult{Stdout: "Terminal\n"}
		case "xdpyinfo":
			return cmdResult{Stdout: "screen #0:\n  dimensions:    1280x720 pixels\n"}
		}
		return cmdResult{Status: 1}
	}
	if r := h.do("GET", "/desktop/status", nil, nil); r.body != `{"available":true,"display":":0","activeWindow":"Terminal","resolution":"1280x720"}` {
		t.Fatalf("%s", r.body)
	}
	h.runner.answers = func(string, []string) cmdResult { return cmdResult{Status: 1} }
	if r := h.do("GET", "/desktop/status", nil, nil); r.body != `{"available":false,"display":":0","activeWindow":null,"resolution":null}` {
		t.Fatalf("%s", r.body)
	}
}

func TestScreenshotWritesIntoTheFileRoot(t *testing.T) {
	h := newHarness(t, nil)
	r := h.json(h.do("POST", "/desktop/screenshot", nil, nil))
	path, _ := r["path"].(string)
	if r["success"] != true || filepath.Dir(path) != h.srv.fileRoot || !strings.HasPrefix(filepath.Base(path), "desktop-") || !strings.HasSuffix(path, ".png") {
		t.Fatalf("%v", r)
	}
	if h.runner.calls[0] != "scrot --silent "+path {
		t.Fatalf("%v", h.runner.calls)
	}
}

func TestLaunchApp(t *testing.T) {
	h := newHarness(t, nil)
	type launch struct {
		name string
		args []string
	}
	var got []launch
	h.srv.launch = func(name string, args []string, env []string) error {
		got = append(got, launch{name, args})
		return nil
	}
	for app, want := range map[string]string{"Terminal": "lxterminal --working-directory=" + h.workspace, "files": "pcmanfm " + h.workspace, "editor": "mousepad"} {
		got = nil
		r := h.do("POST", "/desktop/launch-app", map[string]any{"app": app}, nil)
		if r.status != 200 || len(got) != 1 || strings.TrimSpace(got[0].name+" "+strings.Join(got[0].args, " ")) != want {
			t.Fatalf("%s: %d %s %v", app, r.status, r.body, got)
		}
	}
	got = nil
	prefs := filepath.Join(h.srv.cfg.DataDir, "browser-profiles", "default", "Default", "Preferences")
	os.MkdirAll(filepath.Dir(prefs), 0o755)
	os.WriteFile(prefs, []byte(`{"profile":{"exit_type":"Crashed"}}`), 0o600)
	if r := h.do("POST", "/desktop/launch-app", map[string]any{"application": "browser"}, nil); r.status != 200 || got[0].name != "chromium" ||
		got[0].args[0] != "--user-data-dir="+filepath.Join(h.srv.cfg.DataDir, "browser-profiles", "default") {
		t.Fatalf("%d %v", r.status, got)
	}
	if b, _ := os.ReadFile(prefs); !strings.Contains(string(b), `"exited_cleanly":true`) {
		t.Fatalf("session not marked clean: %s", b)
	}
}

func TestEnsureDesktopCascade(t *testing.T) {
	h := newHarness(t, nil)
	alive := func(string, []string) cmdResult { return cmdResult{} }
	h.runner.answers = alive
	if r := h.do("POST", "/desktop/ensure", nil, nil); r.body != `{"available":true,"display":":0"}` || len(h.runner.calls) != 1 || !strings.HasPrefix(h.runner.calls[0], "xdpyinfo") {
		t.Fatalf("%s %v", r.body, h.runner.calls)
	}

	// Nothing starts: the agent rewrites the session's files, tries each way of
	// starting it, and reports what the logs say.
	if exists(ensureDesktopScript) || exists("/tmp/.X11-unix/X0") {
		t.Skip("this host has a desktop of its own")
	}
	h.srv.waitScale = 0.001
	h.runner = &fakeRunner{answers: func(name string, args []string) cmdResult {
		switch {
		case name == "xdpyinfo":
			return cmdResult{Status: 1}
		case name == "sudo" && len(args) > 3 && strings.Contains(args[3], "journalctl"):
			return cmdResult{Stdout: "line one\nsystemd-sysv-install noise\n\n(EE) no screens found\n"}
		}
		return cmdResult{}
	}}
	h.srv.desktop = h.runner
	r := h.do("POST", "/desktop/ensure", nil, nil)
	if r.body != `{"available":false,"display":":0","error":"line one (EE) no screens found"}` {
		t.Fatalf("%s", r.body)
	}
	all := strings.Join(h.runner.calls, "\n")
	for _, step := range []string{
		"sudo -n rm -f /etc/X11/xorg.conf.d/10-neoagent-display.conf",
		"sudo -n chmod 0755 /usr/local/bin/neoagent-display-setup",
		"sudo -n systemctl mask getty@tty1.service",
		"sudo -n systemctl stop lightdm.service",
		"sudo -n systemctl daemon-reload",
		"sudo -n systemctl enable lightdm.service neoagent-desktop-seat.service",
		"sudo -n systemctl restart lightdm.service",
		"sudo -n systemctl start neoagent-desktop-seat.service",
	} {
		if !strings.Contains(all, step) {
			t.Errorf("missing step %q in\n%s", step, all)
		}
	}
}

func TestPrivilegedFileWriteCommand(t *testing.T) {
	h := newHarness(t, nil)
	if err := h.srv.writePrivilegedFile("/etc/lightdm/lightdm.conf.d/50-neoagent.conf", "[LightDM]\n"); err != nil {
		t.Fatal(err)
	}
	want := `sudo -n /bin/sh -c install -d -m 0755 "/etc/lightdm/lightdm.conf.d" && echo ` + "W0xpZ2h0RE1dCg==" + ` | base64 -d > "/etc/lightdm/lightdm.conf.d/50-neoagent.conf"`
	if h.runner.calls[0] != want {
		t.Fatalf("%s", h.runner.calls[0])
	}
	h.runner.answers = func(string, []string) cmdResult { return cmdResult{Status: 1, Stderr: "sudo: a password is required"} }
	if err := h.srv.writePrivilegedFile("/x", "y"); err == nil || err.Error() != "sudo: a password is required" {
		t.Fatalf("%v", err)
	}
}

func TestTeachContext(t *testing.T) {
	h := newHarness(t, nil)
	h.write("a/b.txt", "12345")
	events := filepath.Join(h.home, ".neoagent")
	os.MkdirAll(events, 0o755)
	var lines []string
	for i := 0; i < 60; i++ {
		lines = append(lines, `{"n":`+itoa(i)+`}`)
	}
	os.WriteFile(filepath.Join(events, "teach-shell-events.jsonl"), []byte(strings.Join(lines, "\n")+"\n"), 0o644)
	h.runner.answers = func(name string, args []string) cmdResult {
		switch name {
		case "sh":
			return cmdResult{Stdout: "Editor\n"}
		case "python3":
			return cmdResult{Stdout: `{"nodes":[{"role":"frame","name":"x"}],"sensitiveInputActive":false}`}
		}
		return cmdResult{}
	}
	got := h.json(h.do("GET", "/teach/context", nil, nil))
	if got["activeWindow"] != "Editor" || got["sensitiveInputActive"] != false {
		t.Fatalf("%v", got)
	}
	evs := got["shellEvents"].([]any)
	if len(evs) != 50 || evs[0].(map[string]any)["n"] != float64(10) {
		t.Fatalf("events %d", len(evs))
	}
	files := got["files"].([]any)
	if len(files) != 1 || files[0].(map[string]any)["path"] != "a/b.txt" {
		t.Fatalf("%v", files)
	}
	// While a password field has focus nothing else is revealed.
	h.runner.answers = func(name string, args []string) cmdResult {
		if name == "python3" {
			return cmdResult{Stdout: `{"nodes":[],"sensitiveInputActive":true}`}
		}
		return cmdResult{Stdout: "Login"}
	}
	r := h.do("GET", "/teach/context", nil, nil)
	if !strings.Contains(r.body, `"shellEvents":[],"files":[]`) || !strings.Contains(r.body, `"sensitiveInputActive":true`) {
		t.Fatalf("%s", r.body)
	}
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	s := ""
	for ; n > 0; n /= 10 {
		s = string(rune('0'+n%10)) + s
	}
	return s
}
