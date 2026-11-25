package tailnet

import (
	"bufio"
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"
)

// fakeDaemon stands in for tailscaled: it serves the LocalAPI on the socket,
// rewrites the node state file, and answers peer dials with a tiny HTTP
// service.
type fakeDaemon struct {
	mu        sync.Mutex
	selfID    string
	authURL   string
	loginWait int // status polls before Running during a login
	prefs     map[string]any
	calls     []string
	stateSeen []byte
	dials     []string
}

type fakeProcess struct {
	ln   net.Listener
	once sync.Once
	done chan struct{}
}

func (p *fakeProcess) Done() <-chan struct{} { return p.done }
func (p *fakeProcess) Signal(syscall.Signal) {
	p.once.Do(func() { p.ln.Close(); close(p.done) })
}

const statusJSON = `{"BackendState":%q,"AuthURL":%q,"Self":{"ID":%q},"CurrentTailnet":{"Name":"example.com"},
"Peer":{"zz":{"ID":"p2","HostName":"beta","DNSName":"beta.example.com.","Online":false,"TailscaleIPs":["100.70.0.2"]},
"aa":{"ID":"p1","HostName":"alpha","DNSName":"alpha.example.com.","Online":true,"TailscaleIPs":["10.0.0.1","100.64.0.1"]}}}`

func (d *fakeDaemon) spawn(dir, socketPath, statePath string, login bool) (Process, error) {
	state, _ := os.ReadFile(statePath)
	d.mu.Lock()
	d.stateSeen = state
	d.mu.Unlock()
	ln, err := net.Listen("unix", socketPath)
	if err != nil {
		return nil, err
	}
	p := &fakeProcess{ln: ln, done: make(chan struct{})}
	polls := 0
	mux := http.NewServeMux()
	mux.HandleFunc("/localapi/v0/", func(w http.ResponseWriter, r *http.Request) {
		endpoint := strings.TrimPrefix(r.URL.Path, "/localapi/v0/")
		d.mu.Lock()
		d.calls = append(d.calls, r.Method+" "+endpoint)
		d.mu.Unlock()
		switch endpoint {
		case "status":
			backend, auth := "Running", ""
			if login && polls < d.loginWait {
				backend, auth = "NeedsLogin", d.authURL
			}
			polls++
			w.Write([]byte(strings.ReplaceAll(jsonf(statusJSON, backend, auth, d.selfID), "\n", "")))
		case "start":
			var body map[string]any
			_ = json.NewDecoder(r.Body).Decode(&body)
			d.mu.Lock()
			d.prefs = body["UpdatePrefs"].(map[string]any)
			d.mu.Unlock()
			_ = os.WriteFile(statePath, []byte("state-after-"+d.selfID), 0o600)
		case "prefs":
			d.mu.Lock()
			raw, _ := json.Marshal(d.prefs)
			d.mu.Unlock()
			w.Write(raw)
		case "dial":
			d.mu.Lock()
			d.dials = append(d.dials, r.Header.Get("Dial-Host")+":"+r.Header.Get("Dial-Port"))
			d.mu.Unlock()
			conn, rw, _ := w.(http.Hijacker).Hijack()
			rw.WriteString("HTTP/1.1 101 Switching Protocols\r\nUpgrade: ts-dial\r\nConnection: upgrade\r\n\r\n")
			rw.Flush()
			go servePeer(conn, rw.Reader)
		}
	})
	go http.Serve(ln, mux)
	return p, nil
}

func jsonf(format string, args ...any) string {
	out := format
	for _, a := range args {
		raw, _ := json.Marshal(a)
		out = strings.Replace(out, "%q", string(raw), 1)
	}
	return out
}

// servePeer answers one HTTP request on a dialed peer stream.
func servePeer(conn net.Conn, r *bufio.Reader) {
	defer conn.Close()
	req, err := http.ReadRequest(r)
	if err != nil {
		return
	}
	body, _ := io.ReadAll(req.Body)
	payload := req.Method + " " + req.URL.RequestURI() + " host=" + req.Host + " x-a=" + req.Header.Get("X-A") + " body=" + string(body)
	resp := "HTTP/1.1 201 Created\r\nContent-Type: text/plain\r\nSet-Cookie: s=1\r\nX-Multi: a\r\nX-Multi: b\r\nContent-Length: " +
		strconv.Itoa(len(payload)) + "\r\n\r\n" + payload
	conn.Write([]byte(resp))
}

func newTestService(t *testing.T, d *fakeDaemon) *Service {
	dir, err := os.MkdirTemp("", "ts")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(dir) })
	return New(Config{Spawn: d.spawn, TemporaryRoot: dir})
}

const opID = "0123456789abcdef0123456789abcdef0123456789abcdef"

// recorded is a request body exactly as the server sends it
// (internal/integrations/tailscale/testdata/node.json).
func recorded(t *testing.T, raw string) map[string]any {
	var body map[string]any
	if err := json.Unmarshal([]byte(strings.ReplaceAll(raw, "<op>", opID)), &body); err != nil {
		t.Fatal(err)
	}
	return body
}

func TestListPeersFromRecordedRequest(t *testing.T) {
	d := &fakeDaemon{selfID: "n1"}
	s := newTestService(t, d)
	res, err := s.Run(context.Background(), recorded(t, `{"action": "list", "state": "s1", "nodeId": "n1", "args": {}, "grants": [], "operationId": "<op>"}`), nil)
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := json.Marshal(res)
	want := `{"result":{"peers":[{"id":"p2","name":"beta","dnsName":"beta.example.com.","online":false},{"id":"p1","name":"alpha","dnsName":"alpha.example.com.","online":true}]},"nodeId":"n1","tailnet":"example.com","state":"` +
		base64.StdEncoding.EncodeToString([]byte("state-after-n1")) + `"}`
	if string(raw) != want {
		t.Fatalf("got  %s\nwant %s", raw, want)
	}
	// "s1" is not padded base64; Node's decoder still reads its one byte.
	if !bytes.Equal(d.stateSeen, []byte{0xb3}) {
		t.Fatalf("state written %x", d.stateSeen)
	}
	if d.prefs["ShieldsUp"] != true || d.prefs["RunSSH"] != false || d.prefs["Hostname"] != "neoagent" {
		t.Fatalf("prefs %v", d.prefs)
	}
}

func TestPingAndRequestThroughPeerStream(t *testing.T) {
	d := &fakeDaemon{selfID: "n1"}
	s := newTestService(t, d)
	res, err := s.Run(context.Background(), recorded(t, `{"action": "ping", "state": "s3", "nodeId": "n1", "args": {"peer_id": "p1", "port": 8443}, "grants": [{"peerId": "p1", "port": 8443, "scheme": "https", "path": "/api?x=1", "methods": ["GET", "POST"]}], "operationId": "<op>"}`), nil)
	if err != nil || res.Error != "" {
		t.Fatal(err, res.Error)
	}
	if ping, _ := res.Result.(pingResult); !ping.Reachable || d.dials[0] != "100.64.0.1:8443" {
		t.Fatalf("ping %+v dials %v", res.Result, d.dials)
	}
	res, err = s.Run(context.Background(), recorded(t, `{"action": "request", "state": "s3", "nodeId": "n1", "args": {"peer_id": "p1", "port": 8080, "scheme": "http", "path": "/api?x=1", "method": "post", "body": "x", "headers": {"x-a": "b"}}, "grants": [{"peerId": "p1", "port": 8080, "scheme": "http", "path": "/api?x=1", "methods": ["POST"]}], "operationId": "<op>"}`), nil)
	if err != nil || res.Error != "" {
		t.Fatal(err, res.Error)
	}
	got := res.Result.(httpResult)
	if got.Status != 201 || got.Body != "POST /api?x=1 host=alpha.example.com:8080 x-a=b body=x" || got.Headers["set-cookie"] != nil || got.Headers["x-multi"] != "a, b" {
		t.Fatalf("%+v", got)
	}
}

func TestRejectedOperations(t *testing.T) {
	d := &fakeDaemon{selfID: "n1"}
	s := newTestService(t, d)
	cases := map[string]string{
		`{"action": "ping", "state": "s3", "nodeId": "n1", "args": {"peer_id": "p2", "port": 443}, "grants": [], "operationId": "<op>"}`:                                                                                               "This service operation has not been granted. Configure service access in the Tailscale integration.",
		`{"action": "request", "state": "s", "nodeId": "n1", "args": {"peer_id": "p1", "port": 1, "path": "/", "headers": {"a": 1}}, "grants": [{"peerId": "p1", "port": 1, "path": "/", "methods": ["GET"]}], "operationId": "<op>"}`: "Invalid request headers.",
		`{"action": "login", "state": "s", "operationId": "<op>"}`:                                           "Interactive login must create a new node.",
		`{"action": "list", "operationId": "<op>"}`:                                                          "Node credentials are missing.",
		`{"action": "list", "state": "s", "nodeId": "n1", "operationId": "short"}`:                           "Invalid operation ID.",
		`{"action": "shell", "operationId": "<op>"}`:                                                         "Invalid Tailscale operation.",
		`{"action": "list", "state": "s4", "nodeId": "n9", "args": {}, "grants": [], "operationId": "<op>"}`: "Node identity changed. Reconnect this integration account.",
	}
	for body, want := range cases {
		if _, err := s.Run(context.Background(), recorded(t, body), nil); err == nil || err.Error() != want {
			t.Errorf("%s: %v want %s", body, err, want)
		}
	}
}

func TestInteractiveLoginThroughRoutes(t *testing.T) {
	d := &fakeDaemon{selfID: "n7", authURL: "https://login.tailscale.com/a/abc", loginWait: 5}
	s := newTestService(t, d)
	mux := http.NewServeMux()
	Mount(mux.Handle, s)
	srv := httptest.NewServer(mux)
	defer srv.Close()
	post := func(path, body string) (int, map[string]any) {
		resp, err := http.Post(srv.URL+path, "application/json", strings.NewReader(body))
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		out := map[string]any{}
		_ = json.NewDecoder(resp.Body).Decode(&out)
		return resp.StatusCode, out
	}
	code, begun := post("/integrations/tailscale", strings.ReplaceAll(`{"action": "login", "operationId": "<op>"}`, "<op>", opID))
	if code != 200 || begun["status"] != "connecting" || begun["loginUrl"] != "https://login.tailscale.com/a/abc" {
		t.Fatalf("%d %v", code, begun)
	}
	var status map[string]any
	for deadline := time.Now().Add(5 * time.Second); time.Now().Before(deadline); time.Sleep(50 * time.Millisecond) {
		resp, err := http.Get(srv.URL + "/integrations/tailscale/" + opID + "/login-status")
		if err != nil {
			t.Fatal(err)
		}
		status = map[string]any{}
		_ = json.NewDecoder(resp.Body).Decode(&status)
		resp.Body.Close()
		if status["status"] != "connecting" {
			break
		}
	}
	if status["status"] != "connected" || status["nodeId"] != "n7" || status["tailnet"] != "example.com" || status["state"] == nil {
		t.Fatalf("status %v", status)
	}
	if code, body := post("/integrations/tailscale/"+opID+"/cancel", "{}"); code != 200 || body["canceled"] != true {
		t.Fatalf("%d %v", code, body)
	}
	resp, err := http.Get(srv.URL + "/integrations/tailscale/" + opID + "/login-status")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var gone map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&gone)
	if gone["status"] != "failed" || gone["error"] != "Tailscale sign-in expired. Please connect again." {
		t.Fatalf("after cancel %v", gone)
	}
}

func TestInvalidLoginURLIsRefused(t *testing.T) {
	d := &fakeDaemon{selfID: "n7", authURL: "https://evil.example/a", loginWait: 5}
	s := newTestService(t, d)
	_, err := s.BeginLogin(context.Background(), recorded(t, `{"action": "login", "operationId": "<op>"}`))
	if err == nil || err.Error() != "Tailscale sign-in could not start. Please connect again." {
		t.Fatalf("%v", err)
	}
	if st := s.LoginStatus(opID).(map[string]any); st["error"] != "Tailscale sign-in ended. Please connect again." {
		t.Fatalf("%v", st)
	}
}
