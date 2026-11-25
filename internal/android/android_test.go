package android

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"mime/multipart"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

type artifacts struct{ count int }

func (a *artifacts) CreateBufferArtifact(_ context.Context, _ string, in BufferArtifact) (string, error) {
	a.count++
	return "/api/artifacts/" + strconv.Itoa(a.count) + "." + in.Extension, nil
}

// fakeSDK lays out an Android SDK whose adb is testdata/fake_adb.sh and whose
// emulator is a long-lived sleep, and points the adb stand-in at its logs.
type fakeSDK struct {
	home, sdk, log, pidFile string
	emulator                *exec.Cmd
}

func newFakeSDK(t *testing.T) *fakeSDK {
	t.Helper()
	home := t.TempDir()
	f := &fakeSDK{home: home, sdk: filepath.Join(home, "sdk"), log: filepath.Join(home, "adb.log"), pidFile: filepath.Join(home, "emulator.pid")}
	for _, dir := range []string{"emulator", "platform-tools"} {
		if err := os.MkdirAll(filepath.Join(f.sdk, dir), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	script, err := os.ReadFile("testdata/fake_adb.sh")
	if err != nil {
		t.Fatal(err)
	}
	must(t, os.WriteFile(filepath.Join(f.sdk, "platform-tools", "adb"), script, 0o755))
	must(t, os.WriteFile(filepath.Join(f.sdk, "emulator", "emulator"), nil, 0o755))
	must(t, os.WriteFile(f.log, nil, 0o600))
	fixtures, _ := filepath.Abs("testdata")
	t.Setenv("FAKE_ADB_LOG", f.log)
	t.Setenv("FAKE_ADB_PID_FILE", f.pidFile)
	t.Setenv("FAKE_ADB_FIXTURES", fixtures)
	t.Setenv("ANDROID_HOME", f.sdk)
	t.Setenv("ANDROID_SDK_ROOT", "")
	return f
}

func must(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}

func (f *fakeSDK) startEmulator(t *testing.T) int {
	t.Helper()
	f.emulator = exec.Command("sleep", "600")
	must(t, f.emulator.Start())
	go f.emulator.Wait()
	t.Cleanup(func() { _ = f.emulator.Process.Kill() })
	must(t, os.WriteFile(f.pidFile, []byte(strconv.Itoa(f.emulator.Process.Pid)), 0o600))
	return f.emulator.Process.Pid
}

func (f *fakeSDK) takeLog(t *testing.T) []string {
	t.Helper()
	raw, err := os.ReadFile(f.log)
	must(t, err)
	must(t, os.WriteFile(f.log, nil, 0o600))
	installPath := regexp.MustCompile(`install -r .*`)
	lines := []string{}
	for _, line := range strings.Split(string(raw), "\n") {
		if line != "" {
			lines = append(lines, installPath.ReplaceAllString(line, "install -r <apk>"))
		}
	}
	return lines
}

type step struct {
	Name   string `json:"name"`
	Method string `json:"method"`
	Path   string `json:"path"`
	User   *int   `json:"user"`
	Body   *string
	Upload *struct{ Field, Filename, Content string }
	Status int      `json:"status"`
	Resp   string   `json:"response"`
	ADB    []string `json:"adb"`
}

type scenario struct {
	Steps []step `json:"steps"`
	State State  `json:"state"`
}

func loadScenario(t *testing.T) scenario {
	t.Helper()
	raw, err := os.ReadFile("testdata/scenario.json")
	must(t, err)
	var s scenario
	must(t, json.Unmarshal(raw, &s))
	return s
}

type stack struct {
	host *Host
	srv  *httptest.Server
	http *http.Client
	fake *fakeSDK
}

func newStack(t *testing.T, running bool) *stack {
	t.Helper()
	ctx := context.Background()
	fake := newFakeSDK(t)
	host, err := NewHost(HostConfig{
		DataDir: filepath.Join(fake.home, "data"), RuntimeHome: fake.home, SDKDir: fake.sdk,
		Artifacts: &artifacts{}, Log: slog.New(slog.NewTextHandler(io.Discard, nil)),
		URLCheck: func(_ context.Context, raw string) (bool, string, error) {
			// The scenario only uses literal addresses, which need no DNS.
			if strings.Contains(raw, "192.168.") {
				return false, "192.168.1.1 is a local or private network address, which is not reachable from here.", nil
			}
			return true, "", nil
		},
	})
	must(t, err)
	if running {
		pid := fake.startEmulator(t)
		must(t, host.states.update("1", func(s *State) {
			s.Bootstrapped, s.PID, s.AdbSerial = true, ptr(pid), ptr("emulator-5554")
		}))
	}
	api, err := NewAPI(APIConfig{
		Provider: host, ValidateIntentURL: host.ValidateIntentURL,
		UploadDir: filepath.Join(fake.home, "data", "uploads", "android-apks"),
	})
	must(t, err)

	db, err := dbx.Open(ctx, filepath.Join(fake.home, "sessions.db"), dbx.Options{})
	must(t, err)
	t.Cleanup(func() { db.Close() })
	store, err := sessionx.NewStore(ctx, db.W)
	must(t, err)
	sessions, err := sessionx.NewManager(store, sessionx.Options{Name: "neoagent.sid", Secrets: []string{"s"}, MaxAge: time.Hour})
	must(t, err)
	mux := http.NewServeMux()
	api.Routes(mux)
	mux.HandleFunc("POST /test/login/{id}", func(w http.ResponseWriter, r *http.Request) {
		id, _ := strconv.ParseInt(r.PathValue("id"), 10, 64)
		sess := sessionx.FromContext(r.Context())
		sess.Set("userId", id)
		w.WriteHeader(http.StatusNoContent)
	})
	srv := httptest.NewServer(sessions.Middleware(mux))
	t.Cleanup(srv.Close)
	return &stack{host: host, srv: srv, fake: fake, http: nil}
}

func (s *stack) client(t *testing.T, signedIn bool) *http.Client {
	t.Helper()
	jar, _ := cookiejar.New(nil)
	c := &http.Client{Jar: jar}
	if signedIn {
		resp, err := c.Post(s.srv.URL+"/test/login/1", "text/plain", nil)
		must(t, err)
		resp.Body.Close()
	}
	return c
}

func (s *stack) do(t *testing.T, c *http.Client, st step) (int, string) {
	t.Helper()
	var body io.Reader
	contentType := ""
	switch {
	case st.Upload != nil:
		var buf bytes.Buffer
		mw := multipart.NewWriter(&buf)
		part, err := mw.CreateFormFile(st.Upload.Field, st.Upload.Filename)
		must(t, err)
		_, _ = part.Write([]byte(st.Upload.Content))
		must(t, mw.Close())
		body, contentType = &buf, mw.FormDataContentType()
	case st.Body != nil:
		body, contentType = strings.NewReader(*st.Body), "application/json"
	}
	req, err := http.NewRequest(st.Method, s.srv.URL+st.Path, body)
	must(t, err)
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	resp, err := c.Do(req)
	must(t, err)
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(raw)
}

// TestScenarioMatchesNode replays the recorded conversation with the Node
// /api/android router: same status, same body, same adb commands.
func TestScenarioMatchesNode(t *testing.T) {
	sc := loadScenario(t)
	s := newStack(t, true)
	signedIn, anonymous := s.client(t, true), s.client(t, false)
	for _, st := range sc.Steps {
		c := signedIn
		if st.User == nil {
			c = anonymous
		}
		status, body := s.do(t, c, st)
		if status != st.Status || body != st.Resp {
			t.Errorf("%s: got %d %s\n want %d %s", st.Name, status, body, st.Status, st.Resp)
		}
		if got := s.fake.takeLog(t); strings.Join(got, "\n") != strings.Join(st.ADB, "\n") {
			t.Errorf("%s: adb calls\n got %q\nwant %q", st.Name, got, st.ADB)
		}
	}
	// The stored state after stopping matches Node's file.
	got := s.host.states.read("1")
	if got.Bootstrapped != sc.State.Bootstrapped || got.PID != nil || got.AdbSerial != nil || got.UserID != "1" {
		t.Errorf("state = %+v", got)
	}
}

func TestStateFileFormat(t *testing.T) {
	s := newStack(t, false)
	must(t, s.host.states.update("7", func(st *State) { st.Starting, st.StartupPhase = true, ptr("Initializing") }))
	raw, err := os.ReadFile(filepath.Join(s.fake.home, "data", "android", "state", "7.json"))
	must(t, err)
	want := "{\n  \"userId\": \"7\",\n  \"bootstrapped\": false,\n  \"starting\": true,\n  \"startupPhase\": \"Initializing\",\n  \"lastStartError\": null,\n  \"pid\": null,\n  \"adbSerial\": null\n}"
	if string(raw) != want {
		t.Fatalf("state file:\n%s", raw)
	}
	info, _ := os.Stat(filepath.Join(s.fake.home, "data", "android", "state", "7.json"))
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("mode = %v", info.Mode())
	}
}

type vectors struct {
	Ports []struct {
		ID   string `json:"id"`
		Hash int32  `json:"hash"`
		Port int    `json:"port"`
	} `json:"ports"`
	ShellEscape []struct{ Input, Output string } `json:"shellEscape"`
	Bounds      []struct {
		Input  string `json:"input"`
		Bounds Bounds `json:"bounds"`
	} `json:"bounds"`
	Dumps []struct {
		XML   string        `json:"xml"`
		Nodes []NodeSummary `json:"nodes"`
		Picks []struct {
			Selector struct {
				Text        string `json:"text"`
				ResourceID  string `json:"resourceId"`
				Description string `json:"description"`
				ClassName   string `json:"className"`
				PackageName string `json:"packageName"`
				Clickable   bool   `json:"clickable"`
			} `json:"selector"`
			Node *NodeSummary `json:"node"`
		} `json:"picks"`
	} `json:"dumps"`
}

func TestHelpersMatchNode(t *testing.T) {
	var sc struct {
		Vectors vectors `json:"vectors"`
	}
	raw, err := os.ReadFile("testdata/scenario.json")
	must(t, err)
	must(t, json.Unmarshal(raw, &sc))
	v := sc.Vectors

	for _, c := range v.Ports {
		if got := hashCode(c.ID); got != c.Hash {
			t.Errorf("hashCode(%q) = %d, want %d", c.ID, got, c.Hash)
		}
		if got := adbPortBase + int(uint32(hashCode(c.ID))%adbPortSlots)*2; got != c.Port {
			t.Errorf("port(%q) = %d, want %d", c.ID, got, c.Port)
		}
	}
	for _, c := range v.ShellEscape {
		if got := shellEscape(c.Input); got != c.Output {
			t.Errorf("shellEscape(%q) = %q, want %q", c.Input, got, c.Output)
		}
	}
	for _, c := range v.Bounds {
		if got := parseBounds(c.Input); got != c.Bounds {
			t.Errorf("parseBounds(%q) = %+v, want %+v", c.Input, got, c.Bounds)
		}
	}
	for i, d := range v.Dumps {
		nodes := ParseUIDump(d.XML)
		if len(nodes) != len(d.Nodes) {
			t.Fatalf("dump %d: %d nodes, want %d", i, len(nodes), len(d.Nodes))
		}
		for j, n := range nodes {
			if n.Summarize() != d.Nodes[j] {
				t.Errorf("dump %d node %d = %+v, want %+v", i, j, n.Summarize(), d.Nodes[j])
			}
		}
		for _, p := range d.Picks {
			sel := Selector{
				Text: p.Selector.Text, ResourceID: p.Selector.ResourceID, Description: p.Selector.Description,
				ClassName: p.Selector.ClassName, PackageName: p.Selector.PackageName, Clickable: p.Selector.Clickable,
			}
			got := FindBestNode(nodes, sel)
			switch {
			case got == nil && p.Node != nil, got != nil && p.Node == nil, got != nil && got.Summarize() != *p.Node:
				t.Errorf("dump %d selector %+v picked %v, want %v", i, sel, got, p.Node)
			}
		}
	}
	if _, err := normalizeUserID("bad id!"); err == nil || err.Error() != "Android user ID contains unsupported characters." {
		t.Fatalf("err = %v", err)
	}
}
