package sockets

import (
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/realtime"
	"github.com/coder/websocket"
)

func TestUnauthenticatedSocketIsConnectedThenDisconnected(t *testing.T) {
	st := newStack(t)
	c := st.connectWith(http.Header{}) // no session cookie
	select {
	case <-c.gone:
	case <-time.After(3 * time.Second):
		t.Fatal("anonymous socket was not disconnected")
	}
	if st.fake.has("offer-call") {
		t.Fatal("anonymous socket reached the domains")
	}
}

func TestForgedSessionCookieIsAnonymous(t *testing.T) {
	st := newStack(t)
	c := st.connectWith(http.Header{"Cookie": {"neoagent.sid=s%3Aforged.AAAA"}})
	select {
	case <-c.gone:
	case <-time.After(3 * time.Second):
		t.Fatal("forged cookie was accepted")
	}
}

func TestConnectedSocketJoinsUserRoomAndDomainsAreOffered(t *testing.T) {
	st := newStack(t)
	a1 := st.connect(1)
	a2 := st.connect(1)
	b := st.connect(2)

	st.fake.waitFor(t, "offer-approvals user=2")
	if !st.fake.has(`offer-call user=1 ua="Go-http-client`) && !st.fake.has("offer-call user=1") {
		t.Fatalf("calls: %v", st.fake.seen())
	}

	st.srv.EmitToUser(1, "tasks:task_running", map[string]any{"taskId": 5})
	for _, c := range []*tclient{a1, a2} {
		if got := obj(c.expect("tasks:task_running")[0]); got["taskId"] != float64(5) {
			t.Fatalf("payload %v", got)
		}
	}
	b.expectSilence(150 * time.Millisecond)

	st.srv.EmitToRoom(realtime.UserRoom(2), "settings:changed", map[string]any{"keys": []any{"theme"}})
	b.expect("settings:changed")
	a1.expectSilence(100 * time.Millisecond)

	// A nil payload sends the event with no arguments.
	st.srv.EmitToUser(2, "teach:status", nil)
	if args := b.expect("teach:status"); len(args) != 0 {
		t.Fatalf("args %v", args)
	}
}

func TestDisconnectNotifiesDomainsOnce(t *testing.T) {
	st := newStack(t)
	c := st.connect(1)
	c.emit("voice:session_open", map[string]any{"sessionId": "s1"})
	st.fake.waitFor(t, "voice-open")
	c.ws.Close(websocket.StatusNormalClosure, "")
	st.fake.waitFor(t, "call-disconnect user=1")
	st.fake.waitFor(t, "detach s1 reason=socket_disconnected")
}

func TestOriginRulesOfTheHub(t *testing.T) {
	st := newStack(t)
	try := func(origin string) int {
		req, _ := http.NewRequest(http.MethodGet, st.http.URL+"/socket.io/?EIO=4&transport=polling", nil)
		if origin != "" {
			req.Header.Set("Origin", origin)
		}
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		res.Body.Close()
		return res.StatusCode
	}
	for origin, want := range map[string]int{
		"":                       200, // native clients send none
		"http://localhost:3000":  200, // no configured origins: loopback is fine
		"http://127.0.0.1:8080":  200,
		"http://evil.example":    403,
		"null":                   403,
		"https://localhost.evil": 403,
	} {
		if got := try(origin); got != want {
			t.Errorf("origin %q: %d want %d", origin, got, want)
		}
	}
}

func TestConfiguredOriginsReplaceTheLoopbackDefault(t *testing.T) {
	origins := httpx.ParseOrigins("https://app.example")
	opts := HubOptions(func(string) string { return "" }, origins, nil)
	if !opts.AllowOrigin("https://app.example") || opts.AllowOrigin("http://localhost:3000") || !opts.AllowOrigin("") {
		t.Fatal("origin rule differs from validateOrigin")
	}
}

func TestHubOptionsReadTheNodeEnvironment(t *testing.T) {
	env := map[string]string{
		"NEOAGENT_SOCKET_PING_INTERVAL_MS":               "1500",
		"NEOAGENT_SOCKET_PING_TIMEOUT_MS":                "junk",
		"NEOAGENT_SOCKET_MAX_HTTP_BUFFER_BYTES":          "1000",
		"NEOAGENT_STREAM_NO_SUBSCRIBER_GRACE_MS":         "0",
		"NEOAGENT_ANDROID_STREAM_FIRST_FRAME_TIMEOUT_MS": "250",
	}
	get := func(k string) string { return env[k] }
	o := HubOptions(get, httpx.ParseOrigins(""), nil)
	if o.PingInterval != 1500*time.Millisecond || o.PingTimeout != 20*time.Second ||
		o.ConnectTimeout != 10*time.Second || o.MaxPayload != 1000 {
		t.Fatalf("%+v", o)
	}
	if StreamGrace(get) != 0 || StreamGrace(func(string) string { return "" }) != 15*time.Second {
		t.Fatal("stream grace")
	}
	if FirstFrameTimeout(get) != 250*time.Millisecond || FirstFrameTimeout(func(string) string { return "" }) != 6*time.Second {
		t.Fatal("first frame timeout")
	}
	d := HubOptions(func(string) string { return "" }, httpx.ParseOrigins(""), nil)
	if d.PingInterval != 25*time.Second || d.MaxPayload != 8*1024*1024 {
		t.Fatalf("defaults %+v", d)
	}
}

func TestNewRequiresItsCollaborators(t *testing.T) {
	if _, err := New(Config{}); err == nil {
		t.Fatal("empty config accepted")
	}
	st := newStack(t)
	cfg := st.srv.cfg
	cfg.Services.Engine = nil
	if _, err := New(cfg); err == nil || !strings.Contains(err.Error(), "required") {
		t.Fatalf("missing engine accepted: %v", err)
	}
}

func TestPanickingHandlerDoesNotKillTheServer(t *testing.T) {
	st := newStack(t)
	st.fake.panicMemory = true
	c := st.connect(1)
	c.emit("memory:read", map[string]any{})
	st.fake.waitFor(t, "memory-read")
	st.fake.mu.Lock()
	st.fake.panicMemory = false
	st.fake.mu.Unlock()
	c.emit("memory:read", map[string]any{})
	c.expect("memory:data") // the socket and the server are still alive
}
