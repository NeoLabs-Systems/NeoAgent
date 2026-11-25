package sockets

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"image"
	"image/color"
	"image/png"
	"io"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

var testJPEG = append(append([]byte{0xff, 0xd8}, bytes.Repeat([]byte{7}, 30)...), 0xff, 0xd9)

func subscribe(t *testing.T, c *tclient, platform, device string) {
	t.Helper()
	c.emit("stream:subscribe", map[string]any{"platform": platform, "deviceId": device})
	c.expect("stream:subscribed")
}

func TestStreamSubscribeValidation(t *testing.T) {
	st := newStack(t)
	st.fake.admins[1] = true
	c := st.connect(1)
	for _, tc := range []struct {
		payload map[string]any
		want    string
	}{
		{map[string]any{"platform": "toaster", "deviceId": "x"}, "platform must be desktop, android, or browser."},
		{map[string]any{"platform": "desktop"}, "deviceId is required."},
		{map[string]any{}, "deviceId is required."},
		{map[string]any{"platform": "android", "deviceId": "   "}, "deviceId is required."},
	} {
		c.emit("stream:subscribe", tc.payload)
		if got := obj(c.expect("stream:error")[0])["error"]; got != tc.want {
			t.Errorf("%v: %q want %q", tc.payload, got, tc.want)
		}
		c.emit("stream:unsubscribe", tc.payload)
		if got := obj(c.expect("stream:error")[0])["error"]; got != tc.want {
			t.Errorf("unsubscribe %v: %q", tc.payload, got)
		}
	}
	// defaults: desktop platform, browser device, snake_case device id, trimming, case folding
	c.emit("stream:subscribe", map[string]any{"deviceId": " Mac "})
	if got := obj(c.expect("stream:subscribed")[0]); got["platform"] != "desktop" || got["deviceId"] != "Mac" || got["subscriberCount"] != float64(1) {
		t.Fatalf("%v", got)
	}
	c.emit("stream:subscribe", map[string]any{"platform": " BROWSER "})
	if got := obj(c.expect("stream:subscribed")[0]); got["platform"] != "browser" || got["deviceId"] != "browser" {
		t.Fatalf("%v", got)
	}
	c.emit("stream:subscribe", map[string]any{"platform": "android", "device_id": "emulator-5554"})
	if got := obj(c.expect("stream:subscribed")[0]); got["deviceId"] != "emulator-5554" {
		t.Fatalf("%v", got)
	}
}

func TestStreamFramesReachOnlySubscribers(t *testing.T) {
	st := newStack(t)
	a := st.connect(1)
	a2 := st.connect(1)
	other := st.connect(2)
	subscribe(t, a, "desktop", "dev")
	subscribe(t, a2, "android", "dev") // same device id, other platform
	subscribe(t, other, "desktop", "dev")

	st.srv.StreamHub().HandleFrame(1, "dev", Frame{Platform: "desktop", JPEG: testJPEG, Seq: 7, TS: 99, Flags: 1})
	ev := a.expectEvent("stream:frame")
	meta := obj(ev.args[0])
	if meta["deviceId"] != "dev" || meta["platform"] != "desktop" || meta["seq"] != float64(7) || meta["ts"] != float64(99) ||
		meta["flags"] != float64(1) || meta["capturedAt"].(float64) < 1e12 {
		t.Fatalf("meta %v", meta)
	}
	if len(ev.bins) != 1 || !bytes.Equal(ev.bins[0], testJPEG) {
		t.Fatalf("binary attachment: %v", ev.bins)
	}
	a2.expectSilence(100 * time.Millisecond)
	other.expectSilence(100 * time.Millisecond)

	// Empty and oversized frames are dropped.
	st.srv.StreamHub().HandleFrame(1, "dev", Frame{Platform: "desktop"})
	st.srv.StreamHub().HandleFrame(1, "dev", Frame{Platform: "desktop", JPEG: make([]byte, MaxStreamFrameBytes+1)})
	a.expectSilence(100 * time.Millisecond)

	status := st.srv.StreamHub().Status(1, "desktop", "dev")
	if status.FrameCount != 1 || status.BytesTotal != int64(len(testJPEG)) || status.SubscriberCount != 1 || status.Streaming {
		t.Fatalf("%+v", status)
	}
}

func TestStreamStopsWhenTheLastSubscriberLeaves(t *testing.T) {
	st := newStack(t)
	var reasons []string
	var mu sync.Mutex
	stop := func(reason string) error {
		mu.Lock()
		reasons = append(reasons, reason)
		mu.Unlock()
		return nil
	}
	got := func() []string { mu.Lock(); defer mu.Unlock(); return append([]string(nil), reasons...) }
	waitReasons := func(n int) []string {
		t.Helper()
		deadline := time.Now().Add(2 * time.Second)
		for len(got()) < n && time.Now().Before(deadline) {
			time.Sleep(10 * time.Millisecond)
		}
		return got()
	}

	hub := st.srv.StreamHub()
	a, b := st.connect(1), st.connect(1)
	subscribe(t, a, "browser", "browser")
	subscribe(t, b, "browser", "browser")
	hub.MarkStarted(1, "browser", "browser", 15, 80, stop)

	a.emit("stream:unsubscribe", map[string]any{"platform": "browser"})
	if got := obj(a.expect("stream:unsubscribed")[0]); got["subscriberCount"] != float64(1) {
		t.Fatalf("%v", got)
	}
	if len(got()) != 0 {
		t.Fatal("stream stopped with a subscriber left")
	}
	b.emit("stream:unsubscribe", map[string]any{"platform": "browser"})
	if got := obj(b.expect("stream:unsubscribed")[0]); got["subscriberCount"] != float64(0) {
		t.Fatalf("%v", got)
	}
	if r := waitReasons(1); len(r) != 1 || r[0] != "no_subscribers" {
		t.Fatalf("%v", r)
	}

	// A dropped connection counts as leaving.
	c := st.connect(1)
	subscribe(t, c, "desktop", "d")
	hub.MarkStarted(1, "d", "desktop", 10, 70, stop)
	c.ws.CloseNow()
	if r := waitReasons(2); len(r) != 2 || r[1] != "socket_disconnected" {
		t.Fatalf("%v", r)
	}
	if hub.Status(1, "desktop", "d").Streaming {
		t.Fatal("still streaming")
	}
}

func TestStreamWithoutSubscribersStopsAfterTheGracePeriod(t *testing.T) {
	st := newStack(t, func(o *stackOpts) { o.mod = func(c *Config) { c.NoSubscriberGrace = 60 * time.Millisecond } })
	stopped := make(chan string, 2)
	hub := st.srv.StreamHub()
	hub.MarkStarted(1, "d", "desktop", 10, 70, func(r string) error { stopped <- r; return nil })
	select {
	case r := <-stopped:
		if r != "no_subscribers_initial" {
			t.Fatal(r)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("never stopped")
	}

	// A subscriber arriving in time cancels the countdown.
	hub.MarkStarted(1, "e", "desktop", 10, 70, func(r string) error { stopped <- r; return nil })
	c := st.connect(1)
	subscribe(t, c, "desktop", "e")
	select {
	case r := <-stopped:
		t.Fatalf("stopped despite a subscriber: %s", r)
	case <-time.After(250 * time.Millisecond):
	}
}

func TestStreamHubStatusAndShutdown(t *testing.T) {
	st := newStack(t)
	hub := st.srv.StreamHub()
	stopped := make(chan string, 4)
	stop := func(r string) error { stopped <- r; return nil }
	hub.MarkStarted(1, "one", "desktop", 12, 75, stop)
	hub.MarkStarted(1, "two", "android", 0, 0, stop)
	hub.MarkStarted(2, "three", "desktop", 5, 50, stop)

	list := hub.ListStatus(1)
	if len(list) != 2 || list[0].DeviceID != "one" || list[1].DeviceID != "two" {
		t.Fatalf("%+v", list)
	}
	raw, _ := json.Marshal(list[1])
	if string(raw) != `{"streaming":true,"platform":"android","deviceId":"two","fps":null,"quality":null,"subscriberCount":0,"frameCount":0,"bytesTotal":0,"lastFrameAt":null,"actualFps":0,"bytesPerSec":0}` {
		t.Fatalf("%s", raw)
	}
	// A stream that is not running still reports its subscribers.
	raw, _ = json.Marshal(hub.Status(9, " Android ", "x"))
	if !strings.Contains(string(raw), `"streaming":false,"platform":"android","deviceId":"x"`) {
		t.Fatalf("%s", raw)
	}
	hub.Shutdown()
	if len(stopped) != 3 || len(hub.ListStatus(1)) != 0 {
		t.Fatalf("shutdown stopped %d streams", len(stopped))
	}
	if hub.StopStream(1, "desktop", "one", "x") {
		t.Fatal("stream survived shutdown")
	}
}

func TestStreamFrameRateStatistics(t *testing.T) {
	st := newStack(t)
	hub := st.srv.StreamHub()
	clock := time.Unix(1_700_000_000, 0)
	hub.now = func() time.Time { return clock }
	c := st.connect(1)
	subscribe(t, c, "desktop", "d")
	for i := 0; i < 5; i++ {
		hub.HandleFrame(1, "d", Frame{JPEG: testJPEG})
	}
	clock = clock.Add(2 * time.Second)
	hub.HandleFrame(1, "d", Frame{JPEG: testJPEG})
	s := hub.Status(1, "desktop", "d")
	if s.FrameCount != 6 || s.ActualFPS != 3 || s.BytesPerSec != int64(len(testJPEG))*3 {
		t.Fatalf("%+v", s)
	}
}

// ---- /api/stream routes ----

type fakeDesktop struct {
	mu      sync.Mutex
	started []DesktopStart
	stopped []string
	err     error
	resolve string
}

func (f *fakeDesktop) ForUser(context.Context, int64) (DesktopProvider, error) { return f, nil }
func (f *fakeDesktop) StartStream(_ context.Context, o DesktopStart) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.started = append(f.started, o)
	return f.resolve, f.err
}

func (f *fakeDesktop) StopStream(_ context.Context, id string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.stopped = append(f.stopped, id)
	return nil
}

type fakeAndroid struct {
	serial   string
	captures atomic.Int32
}

func (f *fakeAndroid) ForUser(context.Context, int64) (AndroidController, error) { return f, nil }
func (f *fakeAndroid) LiveADBSerial() string                                     { return f.serial }
func (f *fakeAndroid) SDKDir() string                                            { return "/nonexistent-sdk" } // no adb: forces the screenshot fallback
func (f *fakeAndroid) CapturePNG(ctx context.Context, device string) ([]byte, error) {
	f.captures.Add(1)
	img := image.NewRGBA(image.Rect(0, 0, 8, 8))
	for i := 0; i < 8; i++ {
		img.Set(i, i, color.RGBA{255, 0, 0, 255})
	}
	var buf bytes.Buffer
	_ = png.Encode(&buf, img)
	time.Sleep(20 * time.Millisecond)
	return buf.Bytes(), nil
}

type fakeBrowser struct{ frames atomic.Int32 }

func (f *fakeBrowser) ForUser(context.Context, int64) (BrowserController, error) { return f, nil }
func (f *fakeBrowser) ScreenshotJPEG(_ context.Context, quality int) ([]byte, error) {
	f.frames.Add(1)
	return append(append([]byte(nil), testJPEG...), byte(quality)), nil
}

type routes struct {
	*stack
	desktop *fakeDesktop
	android *fakeAndroid
	browser *fakeBrowser
}

func newRoutes(t *testing.T) *routes {
	r := &routes{desktop: &fakeDesktop{}, android: &fakeAndroid{}, browser: &fakeBrowser{}}
	r.stack = newStack(t, func(o *stackOpts) {
		o.fake = &fakeBackend{chatWindow: 10, ownedConv: map[string]bool{}, admins: map[int64]bool{1: true}}
		o.mod = func(c *Config) {
			c.Controllers = Controllers{Desktop: r.desktop, Android: r.android, Browser: r.browser, AndroidFirstFrameTimeout: 100 * time.Millisecond}
			c.Home, c.Root = "/home/neo", "/srv/app"
		}
	})
	return r
}

func (r *routes) call(method, path, body string, user int64) (int, string) {
	r.t.Helper()
	req, _ := http.NewRequest(method, r.http.URL+path, strings.NewReader(body))
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	if user != 0 {
		req.Header.Set("Cookie", r.login(user))
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		r.t.Fatal(err)
	}
	defer res.Body.Close()
	raw, _ := io.ReadAll(res.Body)
	return res.StatusCode, string(raw)
}

func TestStreamRoutesRequireASession(t *testing.T) {
	r := newRoutes(t)
	for _, c := range [][2]string{{"POST", "/api/stream/start"}, {"POST", "/api/stream/stop"}, {"GET", "/api/stream/status"}} {
		if code, body := r.call(c[0], c[1], "{}", 0); code != 401 || body != `{"error":"Unauthorized"}` {
			t.Errorf("%v: %d %s", c, code, body)
		}
	}
}

func TestStreamStartDesktop(t *testing.T) {
	r := newRoutes(t)
	r.desktop.resolve = "device-resolved"
	code, body := r.call("POST", "/api/stream/start", `{"platform":"Desktop","deviceId":" dev ","fps":99,"quality":"10","displayId":"2"}`, 1)
	if code != 200 || body != `{"ok":true,"platform":"desktop","deviceId":"device-resolved","fps":20,"quality":30}` {
		t.Fatalf("%d %s", code, body)
	}
	if got := r.desktop.started; len(got) != 1 || got[0].DeviceID != "dev" || got[0].FPS != 20 || got[0].Quality != 30 || got[0].DisplayID != "2" {
		t.Fatalf("%+v", got)
	}
	if s := r.srv.StreamHub().Status(1, "desktop", "device-resolved"); !s.Streaming || *s.FPS != 20 || *s.Quality != 30 {
		t.Fatalf("%+v", s)
	}

	// Restarting stops the previous stream first; stopping calls the provider.
	r.desktop.resolve = ""
	r.call("POST", "/api/stream/start", `{"platform":"desktop","deviceId":"device-resolved"}`, 1)
	if got := r.desktop.started[1]; got.FPS != 15 || got.Quality != 80 || got.DisplayID != nil {
		t.Fatalf("defaults %+v", got)
	}
	code, body = r.call("POST", "/api/stream/stop", `{"platform":"desktop","deviceId":"device-resolved"}`, 1)
	if code != 200 || body != `{"ok":true,"stopped":true,"platform":"desktop","deviceId":"device-resolved"}` {
		t.Fatalf("%d %s", code, body)
	}
	if len(r.desktop.stopped) != 2 { // once for the restart, once for the stop
		t.Fatalf("provider stops: %v", r.desktop.stopped)
	}
	code, body = r.call("POST", "/api/stream/stop", `{"platform":"desktop","deviceId":"device-resolved"}`, 1)
	if body != `{"ok":true,"stopped":false,"platform":"desktop","deviceId":"device-resolved"}` {
		t.Fatalf("%d %s", code, body)
	}
}

func TestStreamStartErrors(t *testing.T) {
	r := newRoutes(t)
	for _, tc := range []struct {
		path, body string
		code       int
		msg        string
	}{
		{"/api/stream/start", `{}`, 400, "platform must be desktop, android, or browser."},
		{"/api/stream/start", `{"platform":"tv"}`, 400, "platform must be desktop, android, or browser."},
		{"/api/stream/start", `{"platform":"desktop"}`, 400, "deviceId is required."},
		{"/api/stream/start", `{"platform":"android"}`, 409, "No emulator is running for this account."},
		{"/api/stream/start", `{`, 400, "Invalid JSON body"},
		{"/api/stream/stop", `{"platform":"desktop"}`, 400, "deviceId is required."},
		{"/api/stream/stop", `{"platform":"android"}`, 400, "deviceId is required."},
		{"/api/stream/stop", `{}`, 400, "platform must be desktop, android, or browser."},
	} {
		code, body := r.call("POST", tc.path, tc.body, 1)
		want, _ := json.Marshal(map[string]string{"error": tc.msg})
		if code != tc.code || body != string(want) {
			t.Errorf("%s %s: %d %s", tc.path, tc.body, code, body)
		}
	}
	r.android.serial = "emulator-5554"
	if code, body := r.call("POST", "/api/stream/start", `{"platform":"android","deviceId":"emulator-9999"}`, 1); code != 400 ||
		!strings.Contains(body, "does not match the active emulator serial") {
		t.Fatalf("%d %s", code, body)
	}
	r.desktop.err = errors.New("companion offline at /home/neo/x")
	if code, body := r.call("POST", "/api/stream/start", `{"platform":"desktop","deviceId":"d"}`, 1); code != 500 || body != `{"error":"companion offline at ~/x"}` {
		t.Fatalf("paths are hidden from error text: %d %s", code, body)
	}
}

func TestStreamStartBrowserDeliversFrames(t *testing.T) {
	r := newRoutes(t)
	c := r.connect(1)
	subscribe(t, c, "browser", "browser")
	code, body := r.call("POST", "/api/stream/start", `{"platform":"browser","fps":50,"quality":90}`, 1)
	if code != 200 || body != `{"ok":true,"platform":"browser","deviceId":"browser","fps":20,"quality":90}` {
		t.Fatalf("%d %s", code, body)
	}
	ev := c.expectEvent("stream:frame")
	if obj(ev.args[0])["platform"] != "browser" || len(ev.bins) != 1 || ev.bins[0][len(ev.bins[0])-1] != 90 {
		t.Fatalf("%v", ev)
	}
	code, body = r.call("POST", "/api/stream/stop", `{"platform":"browser"}`, 1)
	if code != 200 || !strings.Contains(body, `"stopped":true`) {
		t.Fatalf("%d %s", code, body)
	}
	time.Sleep(150 * time.Millisecond)
	settled := r.browser.frames.Load()
	time.Sleep(200 * time.Millisecond)
	if r.browser.frames.Load() != settled {
		t.Fatal("browser capture kept running after stop")
	}
}

func TestStreamStartAndroidFallsBackToScreenshots(t *testing.T) {
	r := newRoutes(t)
	r.android.serial = "emulator-5554"
	c := r.connect(1)
	subscribe(t, c, "android", "emulator-5554")
	code, body := r.call("POST", "/api/stream/start", `{"platform":"android"}`, 1)
	if code != 200 || body != `{"ok":true,"platform":"android","deviceId":"emulator-5554","fps":12,"quality":75}` {
		t.Fatalf("%d %s", code, body)
	}
	ev := c.expectEvent("stream:frame")
	if obj(ev.args[0])["platform"] != "android" || len(ev.bins) != 1 || len(ev.bins[0]) < 4 || ev.bins[0][0] != 0xff || ev.bins[0][1] != 0xd8 {
		t.Fatalf("not a JPEG: %v", ev)
	}
	// stop without a deviceId resolves the emulator's serial
	code, body = r.call("POST", "/api/stream/stop", `{"platform":"android"}`, 1)
	if code != 200 || body != `{"ok":true,"stopped":true,"platform":"android","deviceId":"emulator-5554"}` {
		t.Fatalf("%d %s", code, body)
	}
	time.Sleep(100 * time.Millisecond)
	settled := r.android.captures.Load()
	time.Sleep(200 * time.Millisecond)
	if r.android.captures.Load() > settled+1 {
		t.Fatal("screenshot polling kept running after stop")
	}
}

func TestStreamStatusRoute(t *testing.T) {
	r := newRoutes(t)
	r.srv.StreamHub().MarkStarted(1, "d1", "desktop", 10, 70, func(string) error { return nil })
	r.srv.StreamHub().MarkStarted(2, "d2", "desktop", 10, 70, func(string) error { return nil })

	code, body := r.call("GET", "/api/stream/status", "", 1)
	if code != 200 || !strings.HasPrefix(body, `{"streams":[{"streaming":true,"platform":"desktop","deviceId":"d1","fps":10,"quality":70,`) ||
		!strings.HasSuffix(body, `"platform":null}`) {
		t.Fatalf("%d %s", code, body)
	}
	code, body = r.call("GET", "/api/stream/status?platform=Android", "", 1)
	// the platform is only echoed: the list is every stream of the account
	if !strings.HasSuffix(body, `"platform":"android"}`) || !strings.Contains(body, "d1") {
		t.Fatalf("%d %s", code, body)
	}
	code, body = r.call("GET", "/api/stream/status?deviceId=d1", "", 1)
	if !strings.HasPrefix(body, `{"streaming":true,"platform":"desktop","deviceId":"d1"`) {
		t.Fatalf("%d %s", code, body)
	}
	code, body = r.call("GET", "/api/stream/status?platform=browser&deviceId=%20", "", 1)
	if code != 200 || !strings.Contains(body, `"deviceId":"browser"`) {
		t.Fatalf("%d %s", code, body)
	}
	code, body = r.call("GET", "/api/stream/status?platform=nope", "", 1)
	if code != 400 {
		t.Fatalf("%d %s", code, body)
	}
	code, body = r.call("GET", "/api/stream/status?deviceId=%20%20", "", 1)
	if code != 400 || body != `{"error":"deviceId is required."}` {
		t.Fatalf("%d %s", code, body)
	}
}

func TestStreamRoutesWithoutControllers(t *testing.T) {
	st := newStack(t)
	for _, platform := range []string{"desktop", "android", "browser"} {
		req, _ := http.NewRequest("POST", st.http.URL+"/api/stream/start", strings.NewReader(`{"platform":"`+platform+`","deviceId":"d"}`))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Cookie", st.login(1))
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		body, _ := io.ReadAll(res.Body)
		res.Body.Close()
		want := map[string]string{"desktop": "Desktop provider", "android": "Android controller", "browser": "Browser controller"}[platform]
		if res.StatusCode != 500 || !strings.Contains(string(body), want+" is unavailable.") {
			t.Errorf("%s: %d %s", platform, res.StatusCode, body)
		}
	}
}

func TestJPEGSplitterFindsFramesAcrossChunks(t *testing.T) {
	a := append(append([]byte{0xff, 0xd8, 1, 2}, 3), 0xff, 0xd9)
	b := []byte{0xff, 0xd8, 9, 0xff, 0xd9}
	stream := append(append([]byte{0, 0, 5}, a...), append([]byte{4}, b...)...)
	var p jpegSplitter
	var got [][]byte
	for i := 0; i < len(stream); i += 3 { // arrive in tiny chunks
		got = append(got, p.push(stream[i:min(i+3, len(stream))])...)
	}
	if len(got) != 2 || !bytes.Equal(got[0], a) || !bytes.Equal(got[1], b) {
		t.Fatalf("%x", got)
	}
	if frames := p.push([]byte{1, 2, 3}); len(frames) != 0 || len(p.buf) != 0 {
		t.Fatal("garbage must be discarded")
	}
	if frames := p.push([]byte{1, 0xff}); len(frames) != 0 || len(p.buf) != 1 {
		t.Fatal("a trailing FF may start a marker")
	}
}

func TestPNGToJPEG(t *testing.T) {
	var buf bytes.Buffer
	_ = png.Encode(&buf, image.NewRGBA(image.Rect(0, 0, 4, 4)))
	out, err := PNGToJPEG(buf.Bytes(), 80)
	if err != nil || len(out) < 4 || out[0] != 0xff || out[1] != 0xd8 || out[len(out)-2] != 0xff || out[len(out)-1] != 0xd9 {
		t.Fatalf("%x %v", out, err)
	}
	if _, err := PNGToJPEG([]byte("not a png"), 80); err == nil {
		t.Fatal("garbage accepted")
	}
}
