package guest

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

func TestAuthAndHealth(t *testing.T) {
	h := newHarness(t, nil)
	resp, err := http.Get(h.http.URL + "/health")
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	want := fmt.Sprintf(`{"status":"starting","runtime":"guest-agent","profile":"cli","platform":"%s","arch":"%s","cloudInitFinished":false}`, nodePlatform(), nodeArch())
	if resp.StatusCode != 200 || string(raw) != want {
		t.Fatalf("health %d %s", resp.StatusCode, raw)
	}
	os.WriteFile(h.srv.cfg.CloudInitFinishedPath, nil, 0o644)
	if got := h.json(h.do("GET", "/health", nil, map[string]string{"Authorization": ""})); got["status"] != "ok" || got["cloudInitFinished"] != true {
		t.Fatalf("%v", got)
	}
	for _, header := range []string{"", "Bearer", "Bearer wrong", "Basic " + testToken, "Bearer " + testToken + "x", "bearer " + testToken} {
		r := h.do("POST", "/exec", map[string]any{"command": "true"}, map[string]string{"Authorization": header})
		if r.status != 401 || r.body != `{"error":"Unauthorized."}` {
			t.Fatalf("header %q: %d %s", header, r.status, r.body)
		}
	}
	for _, url := range []string{"/proxy/9/x", "/workspace/files", "/unknown", "/desktop/status"} {
		if r := h.do("GET", url, nil, map[string]string{"Authorization": ""}); r.status != 401 {
			t.Fatalf("%s reachable without a token: %d", url, r.status)
		}
	}
	if r := h.do("GET", "/nope", nil, nil); r.status != 404 {
		t.Fatalf("unknown route: %d", r.status)
	}
	if !safeEqual("a", "a") || safeEqual("", "") || safeEqual("a", "ab") {
		t.Fatal("safeEqual")
	}
}

func TestExecRunsCommands(t *testing.T) {
	h := newHarness(t, nil)
	r := h.json(h.do("POST", "/exec", map[string]any{"command": "echo out; echo err >&2; exit 3", "cwd": h.workspace}, nil))
	if r["exitCode"] != float64(3) || r["stdout"] != "out" || r["stderr"] != "err" || r["cwd"] != h.workspace {
		t.Fatalf("%v", r)
	}
	r = h.json(h.do("POST", "/exec", map[string]any{"command": "cat", "stdin_input": "typed"}, nil))
	if r["stdout"] != "typed" {
		t.Fatalf("%v", r)
	}
	r = h.json(h.do("POST", "/exec", map[string]any{"command": `echo "$GOOD $bad"`, "env": map[string]any{"GOOD": "1", "bad": "2", "N": 5}}, nil))
	if r["stdout"] != "1" {
		t.Fatalf("env filter: %v", r)
	}
	r = h.json(h.do("POST", "/exec", map[string]any{"command": "sleep 30", "timeout": "300"}, nil))
	if r["timedOut"] != true || r["killed"] != true || r["signal"] != "SIGTERM" || r["exitCode"] != nil {
		t.Fatalf("timeout: %v", r)
	}
	if got := h.json(h.do("POST", "/exec", map[string]any{"command": "  "}, nil)); got["error"] != "command is required" {
		t.Fatalf("%v", got)
	}
}

func TestExecPtyAnswersPrompts(t *testing.T) {
	h := newHarness(t, nil)
	r := h.json(h.do("POST", "/exec", map[string]any{
		"command": `printf 'name? '; read n; printf 'ok? '; read c; echo "hi $n $c"`, "pty": true,
		"inputs": []any{map[string]any{"waitFor": "name?", "input": "neo"}, map[string]any{"waitFor": "ok?", "input": "yes"}},
	}, nil))
	if r["interactive"] != true || !strings.Contains(r["stdout"].(string), "hi neo yes") {
		t.Fatalf("%v", r)
	}
}

func TestExecKill(t *testing.T) {
	h := newHarness(t, nil)
	done := make(chan map[string]any, 1)
	go func() { done <- h.json(h.do("POST", "/exec", map[string]any{"command": "sleep 30"}, nil)) }()
	var pid float64
	deadline := time.Now().Add(10 * time.Second)
	for pid == 0 && time.Now().Before(deadline) {
		time.Sleep(50 * time.Millisecond)
		for _, id := range candidatePIDs(h) {
			if h.srv.exec.IsManaged(id) {
				pid = float64(id)
			}
		}
	}
	if pid == 0 {
		t.Fatal("command never started")
	}
	k := h.json(h.do("POST", "/exec/kill", map[string]any{"pid": pid, "reason": "stop"}, nil))
	if k["success"] != true || k["pid"] != pid {
		t.Fatalf("%v", k)
	}
	r := <-done
	if r["killed"] != true {
		t.Fatalf("%v", r)
	}
	if got := h.json(h.do("POST", "/exec/kill", map[string]any{"pid": pid}, nil)); got["error"] != "pid not managed" {
		t.Fatalf("%v", got)
	}
	if got := h.json(h.do("POST", "/exec/kill", map[string]any{"pid": 1.5}, nil)); got["error"] != "pid is required" {
		t.Fatalf("%v", got)
	}
}

// candidatePIDs scans a plausible pid range for a managed command: the
// executor does not expose its list.
func candidatePIDs(h *harness) []int {
	var out []int
	for pid := 2; pid < 400000; pid++ {
		if h.srv.exec.IsManaged(pid) {
			out = append(out, pid)
			if len(out) > 3 {
				break
			}
		}
	}
	return out
}

func TestDiskSafetyBlocksWork(t *testing.T) {
	h := newHarness(t, func(c *Config) { c.MinFreeDiskBytes = 1 << 62 })
	r := h.do("POST", "/exec", map[string]any{"command": "true"}, nil)
	if r.status != 500 || h.json(r)["error"] != diskLimitMessage {
		t.Fatalf("%d %s", r.status, r.body)
	}
	imp := h.do("POST", "/workspace/import", []byte("x"), map[string]string{"x-neoagent-sha256": strings.Repeat("a", 64)})
	if imp.status != 507 || h.json(imp)["code"] != "COMPUTER_DISK_LIMIT" {
		t.Fatalf("%d %s", imp.status, imp.body)
	}
	if w := h.do("PUT", "/workspace/files/content", map[string]any{"path": "a.txt", "content": "x"}, nil); w.status != 500 {
		t.Fatalf("write: %d", w.status)
	}
}

func TestWorkspaceConfinement(t *testing.T) {
	h := newHarness(t, nil)
	outside := t.TempDir()
	os.WriteFile(filepath.Join(outside, "secret.txt"), []byte("secret"), 0o644)
	h.write("ok.txt", "fine")
	os.Symlink(outside, filepath.Join(h.workspace, "escape-dir"))
	os.Symlink(filepath.Join(outside, "secret.txt"), filepath.Join(h.workspace, "escape-file"))
	os.Symlink("ok.txt", filepath.Join(h.workspace, "inside-link"))
	for _, path := range []string{"../x", "..", "/etc/passwd", "escape-dir/secret.txt", "escape-file", "escape-dir", "a/../../x", "ok.txt/../../x"} {
		r := h.do("GET", "/workspace/files/content?path="+path, nil, nil)
		if r.status != 500 || strings.Contains(r.body, "secret") {
			t.Fatalf("read %q: %d %s", path, r.status, r.body)
		}
		w := h.do("PUT", "/workspace/files/content", map[string]any{"path": path, "content": "pwn"}, nil)
		if w.status == 200 {
			t.Fatalf("write %q accepted", path)
		}
	}
	if b, _ := os.ReadFile(filepath.Join(outside, "secret.txt")); string(b) != "secret" {
		t.Fatal("a write went through a link")
	}
	if _, err := os.Stat(filepath.Join(outside, "pwn")); err == nil {
		t.Fatal("wrote outside")
	}
	for _, url := range []string{"/workspace/files?path=escape-dir", "/workspace/files/download?path=escape-file"} {
		if r := h.do("GET", url, nil, nil); r.status != 500 {
			t.Fatalf("%s: %d", url, r.status)
		}
	}
	if r := h.do("POST", "/workspace/search", map[string]any{"path": "escape-dir", "query": "secret"}, nil); r.status != 500 {
		t.Fatalf("search through link: %d %s", r.status, r.body)
	}
	// Search never follows links inside the workspace either.
	if r := h.do("POST", "/workspace/search", map[string]any{"query": "secret"}, nil); strings.Contains(r.body, "secret.txt") {
		t.Fatalf("search followed a link: %s", r.body)
	}
	if got := h.json(h.do("GET", "/workspace/files/content?path=inside-link", nil, nil)); got["content"] != "fine" {
		t.Fatalf("%v", got)
	}
	if r := h.do("GET", "/workspace/files/content?path=a%00b", nil, nil); r.status != 500 || !strings.Contains(r.body, "invalid characters") {
		t.Fatalf("%d %s", r.status, r.body)
	}
}

func TestWriteKeepsModeAndLinkTarget(t *testing.T) {
	h := newHarness(t, nil)
	script := h.write("run.sh", "#!/bin/sh\n")
	os.Chmod(script, 0o755)
	os.Symlink("run.sh", filepath.Join(h.workspace, "alias"))
	if r := h.do("PUT", "/workspace/files/content", map[string]any{"path": "alias", "content": "#!/bin/sh\necho new\n"}, nil); r.status != 200 {
		t.Fatal(r.body)
	}
	info, _ := os.Lstat(filepath.Join(h.workspace, "alias"))
	if info.Mode()&os.ModeSymlink == 0 {
		t.Fatal("the link was replaced by a file")
	}
	st, _ := os.Stat(script)
	body, _ := os.ReadFile(script)
	if st.Mode().Perm() != 0o755 || string(body) != "#!/bin/sh\necho new\n" {
		t.Fatalf("mode %v body %q", st.Mode().Perm(), body)
	}
	entries, _ := os.ReadDir(h.workspace)
	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".tmp") {
			t.Fatalf("temp file left behind: %s", e.Name())
		}
	}
	data := base64.StdEncoding.EncodeToString([]byte{0, 1, 2, 255})
	if r := h.do("PUT", "/workspace/files/content", map[string]any{"path": "deep/er/bin.dat", "content": data, "encoding": "base64"}, nil); r.status != 200 {
		t.Fatal(r.body)
	}
	if b, _ := os.ReadFile(filepath.Join(h.workspace, "deep/er/bin.dat")); !bytes.Equal(b, []byte{0, 1, 2, 255}) {
		t.Fatalf("%v", b)
	}
	big := strings.Repeat("x", maxWorkspaceFileBytes+1)
	if r := h.do("PUT", "/workspace/files/content", map[string]any{"path": "big", "content": big}, nil); r.status != 500 || !strings.Contains(r.body, "too large to edit") {
		t.Fatalf("%d %.80s", r.status, r.body)
	}
	dl := h.json(h.do("GET", "/workspace/files/download?path=deep/er/bin.dat", nil, nil))
	if dl["content"] != data || dl["filename"] != "bin.dat" {
		t.Fatalf("%v", dl)
	}
	h.write("huge", strings.Repeat("y", maxWorkspaceFileBytes+1))
	if r := h.do("GET", "/workspace/files/content?path=huge", nil, nil); r.status != 500 || !strings.Contains(r.body, "too large") {
		t.Fatalf("%d %.80s", r.status, r.body)
	}
}

func TestFilesReadRoots(t *testing.T) {
	h := newHarness(t, nil)
	file := h.write("note.txt", "hello")
	r := h.json(h.do("POST", "/files/read", map[string]any{"path": file, "encoding": "utf8"}, nil))
	real, _ := filepath.EvalSymlinks(file)
	if r["content"] != "hello" || r["byteSize"] != float64(5) || r["path"] != real || r["encoding"] != "utf8" {
		t.Fatalf("%v", r)
	}
	r = h.json(h.do("POST", "/files/read", map[string]any{"path": file}, nil))
	if r["content"] != base64.StdEncoding.EncodeToString([]byte("hello")) {
		t.Fatalf("%v", r)
	}
	outside := filepath.Join(t.TempDir(), "x")
	os.WriteFile(outside, []byte("x"), 0o600)
	os.Symlink("/etc/hosts", filepath.Join(h.workspace, "hosts"))
	for _, p := range []string{"/etc/hosts", "/etc/../etc/hosts", filepath.Join(h.workspace, "hosts"), "/nonexistent"} {
		if got := h.json(h.do("POST", "/files/read", map[string]any{"path": p}, nil)); got["error"] != "path is outside guest-agent readable roots" {
			t.Fatalf("%s: %v", p, got)
		}
	}
	// A screenshot name only ever refers to the screenshots directory.
	shots := filepath.Join(h.srv.cfg.DataDir, "screenshots")
	os.MkdirAll(shots, 0o755)
	os.WriteFile(filepath.Join(shots, "s.png"), []byte("png"), 0o644)
	os.MkdirAll(filepath.Join(h.srv.cfg.RuntimeHome, "data"), 0o755)
	h.srv.readables = h.srv.readableRoots()
	if got := h.json(h.do("POST", "/files/read", map[string]any{"path": "/screenshots/../../etc/s.png"}, nil)); got["byteSize"] != float64(3) {
		t.Fatalf("%v", got)
	}
	// delete_after_read removes files under the agent's own directory only.
	mine := filepath.Join(h.srv.fileRoot, "job1", "out.bin")
	os.MkdirAll(filepath.Dir(mine), 0o755)
	os.WriteFile(mine, []byte("bye"), 0o644)
	h.do("POST", "/files/read", map[string]any{"path": mine, "delete_after_read": true}, nil)
	if _, err := os.Stat(mine); err == nil {
		t.Fatal("file survived delete_after_read")
	}
	if _, err := os.Stat(filepath.Dir(mine)); err == nil {
		t.Fatal("empty directory survived")
	}
	if h.srv.deletable("/home/neo/workspace/x") || h.srv.deletable("/etc/hosts") {
		t.Fatal("delete_after_read reaches outside scratch space")
	}
}

func makeTar(t *testing.T, entries func(tw *tar.Writer)) ([]byte, string) {
	t.Helper()
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	entries(tw)
	tw.Close()
	gz.Close()
	sum := sha256.Sum256(buf.Bytes())
	return buf.Bytes(), hex.EncodeToString(sum[:])
}

func addFile(tw *tar.Writer, name, body string, mode int64) {
	tw.WriteHeader(&tar.Header{Name: name, Typeflag: tar.TypeReg, Mode: mode, Size: int64(len(body))})
	tw.Write([]byte(body))
}

func TestImportExtractsSafely(t *testing.T) {
	h := newHarness(t, nil)
	archive, sum := makeTar(t, func(tw *tar.Writer) {
		tw.WriteHeader(&tar.Header{Name: "./", Typeflag: tar.TypeDir, Mode: 0o755})
		tw.WriteHeader(&tar.Header{Name: "./sub/", Typeflag: tar.TypeDir, Mode: 0o755})
		addFile(tw, "./sub/a.txt", "alpha", 0o644)
		addFile(tw, "./run.sh", "#!/bin/sh", 0o4755)
		tw.WriteHeader(&tar.Header{Name: "./sub/rel", Typeflag: tar.TypeSymlink, Linkname: "a.txt"})
		tw.WriteHeader(&tar.Header{Name: "./dev", Typeflag: tar.TypeChar, Mode: 0o666})
	})
	r := h.do("POST", "/workspace/import", archive, map[string]string{"x-neoagent-sha256": sum, "Content-Type": "application/gzip"})
	got := h.json(r)
	if r.status != 200 || got["success"] != true || got["sha256"] != sum || got["entries"] != float64(6) {
		t.Fatalf("%d %s", r.status, r.body)
	}
	if b, _ := os.ReadFile(filepath.Join(h.workspace, "sub/a.txt")); string(b) != "alpha" {
		t.Fatalf("%q", b)
	}
	if b, _ := os.ReadFile(filepath.Join(h.workspace, "sub/rel")); string(b) != "alpha" {
		t.Fatalf("link: %q", b)
	}
	st, _ := os.Stat(filepath.Join(h.workspace, "run.sh"))
	if st.Mode()&(os.ModeSetuid|os.ModeSetgid) != 0 || st.Mode().Perm()&0o022 != 0 {
		t.Fatalf("mode %v", st.Mode())
	}
	if _, err := os.Stat(filepath.Join(h.workspace, "dev")); err == nil {
		t.Fatal("a device node was created")
	}
	staged, _ := os.ReadDir(filepath.Join(h.home, ".neoagent", "imports"))
	if len(staged) != 0 {
		t.Fatalf("staged archive left behind: %v", staged)
	}
}

func TestImportRejectsHostileArchives(t *testing.T) {
	outside := t.TempDir()
	cases := map[string]func(tw *tar.Writer){
		"parent":    func(tw *tar.Writer) { addFile(tw, "../evil.txt", "x", 0o644) },
		"nested":    func(tw *tar.Writer) { addFile(tw, "a/../../evil.txt", "x", 0o644) },
		"absolute":  func(tw *tar.Writer) { addFile(tw, "/tmp/evil-abs.txt", "x", 0o644) },
		"backslash": func(tw *tar.Writer) { addFile(tw, `..\evil.txt`, "x", 0o644) },
		"abs link": func(tw *tar.Writer) {
			tw.WriteHeader(&tar.Header{Name: "l", Typeflag: tar.TypeSymlink, Linkname: outside})
		},
		"parent link": func(tw *tar.Writer) {
			tw.WriteHeader(&tar.Header{Name: "d/l", Typeflag: tar.TypeSymlink, Linkname: "../../x"})
		},
		"hardlink out": func(tw *tar.Writer) { tw.WriteHeader(&tar.Header{Name: "l", Typeflag: tar.TypeLink, Linkname: "../x"}) },
		"link then write": func(tw *tar.Writer) {
			tw.WriteHeader(&tar.Header{Name: "l", Typeflag: tar.TypeSymlink, Linkname: outside})
			addFile(tw, "l/pwned.txt", "x", 0o644)
		},
	}
	for name, build := range cases {
		t.Run(name, func(t *testing.T) {
			h := newHarness(t, nil)
			archive, sum := makeTar(t, build)
			r := h.do("POST", "/workspace/import", archive, map[string]string{"x-neoagent-sha256": sum})
			if r.status != 400 || h.json(r)["error"] != "Workspace archive contains an unsafe path." {
				t.Fatalf("%d %s", r.status, r.body)
			}
			if entries, _ := os.ReadDir(outside); len(entries) != 0 {
				t.Fatalf("escaped into %v", entries)
			}
			if _, err := os.Stat(filepath.Join(filepath.Dir(h.workspace), "evil.txt")); err == nil {
				t.Fatal("escaped the workspace")
			}
			if entries, _ := os.ReadDir(h.workspace); len(entries) != 0 {
				t.Fatalf("partial extraction: %v", entries)
			}
		})
	}
}

func TestImportChecksAndLimits(t *testing.T) {
	h := newHarness(t, func(c *Config) { c.MaxImportBytes = 1000 })
	archive, sum := makeTar(t, func(tw *tar.Writer) { addFile(tw, "a", "a", 0o644) })
	for header, want := range map[string]string{"": "A valid workspace archive checksum is required.", "xyz": "A valid workspace archive checksum is required.", strings.Repeat("0", 64): "Workspace import checksum verification failed."} {
		r := h.do("POST", "/workspace/import", archive, map[string]string{"x-neoagent-sha256": header})
		if r.status != 400 || h.json(r)["error"] != want {
			t.Fatalf("%q: %d %s", header, r.status, r.body)
		}
	}
	if r := h.do("POST", "/workspace/import", archive, map[string]string{"x-neoagent-sha256": strings.ToUpper(sum)}); r.status != 200 {
		t.Fatalf("uppercase digest: %d %s", r.status, r.body)
	}
	big := bytes.Repeat([]byte("z"), 1500)
	r := h.do("POST", "/workspace/import", big, map[string]string{"x-neoagent-sha256": strings.Repeat("1", 64)})
	if r.status != 413 || h.json(r)["error"] != "Workspace import exceeds the guest disk safety limit." {
		t.Fatalf("%d %s", r.status, r.body)
	}
	notTar := []byte("not an archive")
	s := sha256.Sum256(notTar)
	if r := h.do("POST", "/workspace/import", notTar, map[string]string{"x-neoagent-sha256": hex.EncodeToString(s[:])}); r.status != 400 {
		t.Fatalf("%d %s", r.status, r.body)
	}
}

func TestSearchAndListBounds(t *testing.T) {
	h := newHarness(t, nil)
	for i := 0; i < 5; i++ {
		h.write(fmt.Sprintf("f%d.txt", i), "needle\n")
	}
	got := h.json(h.do("POST", "/workspace/search", map[string]any{"query": "needle", "maxResults": 3}, nil))
	if len(got["results"].([]any)) != 3 || got["truncated"] != true {
		t.Fatalf("%v", got)
	}
	long := strings.Repeat("é", 600) + "needle"
	h.write("long.txt", long+"\n")
	got = h.json(h.do("POST", "/workspace/search", map[string]any{"query": "needle", "glob": "long"}, nil))
	text := got["results"].([]any)[0].(map[string]any)["text"].(string)
	if utf16Len(text) != 500 {
		t.Fatalf("text length %d", utf16Len(text))
	}
}

func TestProxyRelaysAndStreams(t *testing.T) {
	h := newHarness(t, nil)
	release := make(chan struct{})
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/echo":
			body, _ := io.ReadAll(r.Body)
			w.Header().Set("X-Seen-Host", r.Host)
			w.Header().Set("X-Seen-Auth", r.Header.Get("Authorization"))
			w.Header().Set("X-Seen-Custom", r.Header.Get("X-Custom"))
			w.Header().Set("Upgrade", "h2c")
			w.WriteHeader(201)
			fmt.Fprintf(w, "%s %s %s", r.Method, r.URL.RawQuery, body)
		case "/stream":
			w.WriteHeader(200)
			w.Write([]byte("first;"))
			w.(http.Flusher).Flush()
			<-release
			w.Write([]byte("second"))
		default:
			w.Write([]byte("root"))
		}
	}))
	defer upstream.Close()
	port := upstream.Listener.Addr().(*net.TCPAddr).Port
	r := h.do("POST", fmt.Sprintf("/proxy/%d/echo?a=1&b=2", port), []byte("payload"), map[string]string{"X-Custom": "yes"})
	if r.status != 201 || r.body != "POST a=1&b=2 payload" {
		t.Fatalf("%d %s", r.status, r.body)
	}
	if r.header.Get("X-Seen-Host") != fmt.Sprintf("localhost:%d", port) || r.header.Get("X-Seen-Auth") != "" || r.header.Get("X-Seen-Custom") != "yes" || r.header.Get("Upgrade") != "" {
		t.Fatalf("headers %v", r.header)
	}
	if r := h.do("GET", fmt.Sprintf("/proxy/%d", port), nil, nil); r.body != "root" {
		t.Fatalf("no trailing slash: %d %s", r.status, r.body)
	}
	if r := h.do("GET", fmt.Sprintf("/proxy/%d/", port), nil, nil); r.body != "root" {
		t.Fatalf("root: %s", r.body)
	}
	// The first chunk arrives while the upstream is still writing.
	req, _ := http.NewRequest("GET", fmt.Sprintf("%s/proxy/%d/stream", h.http.URL, port), nil)
	req.Header.Set("Authorization", "Bearer "+testToken)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	buf := make([]byte, 6)
	if _, err := io.ReadFull(resp.Body, buf); err != nil || string(buf) != "first;" {
		t.Fatalf("first chunk %q %v", buf, err)
	}
	close(release)
	rest, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if string(rest) != "second" {
		t.Fatalf("rest %q", rest)
	}

	for _, bad := range []string{"/proxy/0/x", "/proxy/65536/x", "/proxy/abc/x", "/proxy/123456/x", fmt.Sprintf("/proxy/%d/x", h.srv.Port()), "/proxy", "/proxy/"} {
		if r := h.do("GET", bad, nil, nil); r.status != 400 || h.json(r)["error"] != "Invalid port." {
			t.Fatalf("%s: %d %s", bad, r.status, r.body)
		}
	}
	l, _ := net.Listen("tcp", "127.0.0.1:0")
	closed := l.Addr().(*net.TCPAddr).Port
	l.Close()
	r = h.do("GET", fmt.Sprintf("/proxy/%d/x", closed), nil, nil)
	if r.status != 502 || r.header.Get("x-neoagent-proxy") != "unreachable" || h.json(r)["error"] == nil {
		t.Fatalf("%d %v %s", r.status, r.header, r.body)
	}
}

func TestExtensionPointIsBehindTheToken(t *testing.T) {
	h := newHarness(t, nil)
	h.srv.Handle("GET /browser/status", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write([]byte(`{"mounted":true}`)) }))
	if r := h.do("GET", "/browser/status", nil, map[string]string{"Authorization": ""}); r.status != 401 {
		t.Fatalf("%d", r.status)
	}
	if r := h.do("GET", "/browser/status", nil, nil); r.body != `{"mounted":true}` || h.srv.Profile() != "cli" {
		t.Fatalf("%s", r.body)
	}
}

func TestInvalidJSONAndMissingShell(t *testing.T) {
	h := newHarness(t, nil)
	r := h.do("POST", "/exec", []byte("{nope"), map[string]string{"Content-Type": "application/json"})
	if r.status != 400 {
		t.Fatalf("%d %s", r.status, r.body)
	}
	if _, err := New(Config{}); err == nil {
		t.Fatal("a server without a token was created")
	}
}

func TestBootAssetsReportMissingFiles(t *testing.T) {
	if runtime.GOOS == "linux" {
		t.Skip("a Linux test host may really have a kernel in /boot")
	}
	h := newHarness(t, nil)
	if r := h.do("GET", "/system/boot-assets", nil, nil); r.status != 500 {
		t.Fatalf("%d %s", r.status, r.body)
	}
}
