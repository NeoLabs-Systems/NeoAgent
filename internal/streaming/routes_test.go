package streaming

import (
	"context"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

type started struct {
	user, device, platform string
	info                   StartInfo
	stop                   func(string)
}

type fakeHub struct {
	recorder
	mu      sync.Mutex
	starts  []started
	stopped []string
	active  map[string]bool
}

func (h *fakeHub) MarkStarted(user, device, platform string, info StartInfo, stop func(string)) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.starts = append(h.starts, started{user, device, platform, info, stop})
}

func (h *fakeHub) StopStream(_ context.Context, user, platform, device, reason string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	key := user + ":" + platform + ":" + device
	h.stopped = append(h.stopped, key+" "+reason)
	return h.active[key]
}

func (h *fakeHub) Status(user, platform, device string) any {
	return map[string]any{"streaming": false, "platform": platform, "deviceId": device, "user": user}
}

func (h *fakeHub) ListStatus(user string) any { return []any{map[string]any{"user": user}} }

type fakeDevices struct {
	serial    string
	desktop   *fakeDesktop
	png, jpeg []byte
}

type fakeDesktop struct {
	mu      sync.Mutex
	started []string
	stopped []string
}

func (d *fakeDesktop) StartStream(_ context.Context, device string, fps, quality int, display string) (string, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.started = append(d.started, strings.Join([]string{device, strconv.Itoa(fps), strconv.Itoa(quality), display}, "|"))
	return "resolved-" + device, nil
}

func (d *fakeDesktop) StopStream(_ context.Context, device string) error {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.stopped = append(d.stopped, device)
	return nil
}

type fakeAndroid struct {
	serial string
	png    []byte
}

func (a fakeAndroid) CapturePNG(context.Context) ([]byte, error) { return a.png, nil }
func (a fakeAndroid) LiveAdbSerial() string                      { return a.serial }
func (a fakeAndroid) ADBBin() string                             { return "/nonexistent/adb" }

func (f *fakeDevices) Desktop(context.Context, int64) (DesktopStreamer, error) { return f.desktop, nil }
func (f *fakeDevices) Android(context.Context, int64) (AndroidDevice, error) {
	return fakeAndroid{serial: f.serial, png: f.png}, nil
}
func (f *fakeDevices) Browser(context.Context, int64) (JPEGSource, error) {
	return &jpegSource{jpeg: f.jpeg}, nil
}

func routeStack(t *testing.T, serial string) (*httptest.Server, *fakeHub, *fakeDevices, *http.Client) {
	t.Helper()
	ctx := context.Background()
	hub := &fakeHub{active: map[string]bool{"1:browser:browser": true}}
	devices := &fakeDevices{serial: serial, desktop: &fakeDesktop{}, png: solidPNG(t, 8, 8), jpeg: solidJPEG(t, 8, 8)}
	api := NewAPI(APIConfig{Hub: hub, Devices: devices, FirstFrameTimeout: time.Second, Log: quiet})
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "s.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	store, err := sessionx.NewStore(ctx, db.W)
	if err != nil {
		t.Fatal(err)
	}
	sessions, err := sessionx.NewManager(store, sessionx.Options{Name: "neoagent.sid", Secrets: []string{"s"}, MaxAge: time.Hour})
	if err != nil {
		t.Fatal(err)
	}
	mux := http.NewServeMux()
	api.Routes(mux)
	mux.HandleFunc("POST /login", func(w http.ResponseWriter, r *http.Request) {
		sessionx.FromContext(r.Context()).Set("userId", int64(1))
		w.WriteHeader(http.StatusNoContent)
	})
	srv := httptest.NewServer(sessions.Middleware(mux))
	t.Cleanup(srv.Close)
	jar, _ := cookiejar.New(nil)
	c := &http.Client{Jar: jar}
	resp, err := c.Post(srv.URL+"/login", "text/plain", nil)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	return srv, hub, devices, c
}

func call(t *testing.T, c *http.Client, method, url, body string) (int, string) {
	t.Helper()
	req, _ := http.NewRequest(method, url, strings.NewReader(body))
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := c.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(raw)
}

func TestStreamRoutes(t *testing.T) {
	srv, hub, devices, c := routeStack(t, "emulator-5554")

	cases := []struct {
		name, method, path, body string
		status                   int
		resp                     string
	}{
		{"bad platform", "POST", "/api/stream/start", `{"platform":"tv"}`, 400, `{"error":"platform must be desktop, android, or browser."}`},
		{"desktop needs a device", "POST", "/api/stream/start", `{"platform":"desktop"}`, 400, `{"error":"deviceId is required."}`},
		{"android device mismatch", "POST", "/api/stream/start", `{"platform":"android","deviceId":"emulator-1"}`, 400, `{"error":"Android deviceId does not match the active emulator serial."}`},
		{"browser start with bounds", "POST", "/api/stream/start", `{"platform":"Browser","fps":99,"quality":"5"}`, 200, `{"ok":true,"platform":"browser","deviceId":"browser","fps":20,"quality":30}`},
		{"android start defaults", "POST", "/api/stream/start", `{"platform":"android"}`, 200, `{"ok":true,"platform":"android","deviceId":"emulator-5554","fps":12,"quality":75}`},
		{"android fps fallback", "POST", "/api/stream/start", `{"platform":"android","fps":"fast","quality":200}`, 200, `{"ok":true,"platform":"android","deviceId":"emulator-5554","fps":12,"quality":95}`},
		{"desktop start", "POST", "/api/stream/start", `{"platform":"desktop","deviceId":"d1","displayId":"2","fps":7.9}`, 200, `{"ok":true,"platform":"desktop","deviceId":"resolved-d1","fps":7,"quality":80}`},
		{"stop browser default", "POST", "/api/stream/stop", `{"platform":"browser"}`, 200, `{"ok":true,"stopped":true,"platform":"browser","deviceId":"browser"}`},
		{"stop android default", "POST", "/api/stream/stop", `{"platform":"android"}`, 200, `{"ok":true,"stopped":false,"platform":"android","deviceId":"emulator-5554"}`},
		{"stop desktop needs id", "POST", "/api/stream/stop", `{"platform":"desktop"}`, 400, `{"error":"deviceId is required."}`},
		{"status of one", "GET", "/api/stream/status?platform=android&deviceId=emulator-5554", "", 200, `{"deviceId":"emulator-5554","platform":"android","streaming":false,"user":"1"}`},
		{"status browser needs no id", "GET", "/api/stream/status?platform=browser&deviceId=%20", "", 200, `{"deviceId":"browser","platform":"browser","streaming":false,"user":"1"}`},
		{"status list", "GET", "/api/stream/status", "", 200, `{"streams":[{"user":"1"}],"platform":null}`},
		{"status list for platform", "GET", "/api/stream/status?platform=desktop", "", 200, `{"streams":[{"user":"1"}],"platform":"desktop"}`},
		{"status bad platform", "GET", "/api/stream/status?platform=x", "", 400, `{"error":"platform must be desktop, android, or browser."}`},
	}
	for _, tc := range cases {
		status, body := call(t, c, tc.method, srv.URL+tc.path, tc.body)
		if status != tc.status || body != tc.resp {
			t.Errorf("%s: got %d %s, want %d %s", tc.name, status, body, tc.status, tc.resp)
		}
	}

	hub.mu.Lock()
	if len(hub.starts) != 4 || hub.starts[0].platform != "browser" || hub.starts[0].info != (StartInfo{FPS: 20, Quality: 30}) ||
		hub.starts[3].device != "resolved-d1" {
		t.Errorf("marked streams = %+v", hub.starts)
	}
	starts := append([]started(nil), hub.starts...)
	hub.mu.Unlock()
	if got := devices.desktop.started; len(got) != 1 || got[0] != "d1|7|80|2" {
		t.Errorf("desktop start = %v", got)
	}
	// The registered stop callbacks end the producers they started.
	starts[3].stop("no_subscribers")
	if got := devices.desktop.stopped; len(got) != 1 || got[0] != "resolved-d1" {
		t.Errorf("desktop stop = %v", got)
	}
	for _, s := range starts[:3] {
		s.stop("shutdown")
	}
	// Each start stopped a previous stream of the same device first.
	if len(hub.stopped) < 4 || hub.stopped[0] != "1:browser:browser restart" {
		t.Errorf("stops = %v", hub.stopped)
	}
}

func TestStreamRoutesNeedSignIn(t *testing.T) {
	srv, _, _, _ := routeStack(t, "")
	plain := &http.Client{}
	for _, path := range []string{"/api/stream/status"} {
		if status, body := call(t, plain, "GET", srv.URL+path, ""); status != 401 || body != `{"error":"Unauthorized"}` {
			t.Errorf("%s: %d %s", path, status, body)
		}
	}
	srv2, _, _, c2 := routeStack(t, "")
	if status, body := call(t, c2, "POST", srv2.URL+"/api/stream/start", `{"platform":"android"}`); status != 409 || body != `{"error":"No emulator is running for this account."}` {
		t.Errorf("no emulator: %d %s", status, body)
	}
	if status, body := call(t, c2, "POST", srv2.URL+"/api/stream/stop", `{"platform":"android"}`); status != 400 || body != `{"error":"deviceId is required."}` {
		t.Errorf("stop without emulator: %d %s", status, body)
	}
}
