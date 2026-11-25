package desktop

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
)

func newDB(t *testing.T) *dbx.DB {
	ctx := context.Background()
	db, err := dbx.Open(ctx, filepath.Join(t.TempDir(), "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (1, 'u', 'x')`); err != nil {
		t.Fatal(err)
	}
	return db
}

// gatewayServer serves the companion WebSocket with a signed-in session.
func gatewayServer(t *testing.T, r *Registry) (*httptest.Server, *http.Client) {
	sdb, err := dbx.Open(context.Background(), filepath.Join(t.TempDir(), "s.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { sdb.Close() })
	store, _ := sessionx.NewStore(context.Background(), sdb.W)
	sessions, _ := sessionx.NewManager(store, sessionx.Options{Name: "neoagent.sid", Secrets: []string{"x"}})
	g := NewGateway(r, nil)
	t.Cleanup(g.Close)
	mux := http.NewServeMux()
	g.Routes(mux)
	mux.HandleFunc("/login", func(w http.ResponseWriter, req *http.Request) {
		sessionx.FromContext(req.Context()).Set("userId", int64(1))
	})
	srv := httptest.NewServer(sessions.Middleware(mux))
	t.Cleanup(srv.Close)
	jar, _ := cookiejar.New(nil)
	client := &http.Client{Jar: jar}
	resp, err := client.Get(srv.URL + "/login")
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	return srv, client
}

func dial(t *testing.T, srv *httptest.Server, client *http.Client) *websocket.Conn {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(srv.URL, "http")+WebSocketPath, &websocket.DialOptions{HTTPClient: client})
	if err != nil {
		t.Fatal(err)
	}
	return conn
}

func readJSON(t *testing.T, conn *websocket.Conn) map[string]any {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, data, err := conn.Read(ctx)
	if err != nil {
		t.Fatal(err)
	}
	out := map[string]any{}
	_ = json.Unmarshal(data, &out)
	return out
}

const helloMessage = `{"type":"hello","device":{"deviceId":"mac-1","activationId":"act-1","label":"Neo's Mac","hostname":"mac","platform":"darwin","companionEnabled":true,"displays":[{"id":"d1","name":"Built-in","width":1440,"height":900}],"permissions":{"appApprovals":{"Safari":true}}}}`

func TestCompanionRoundTripOverWebSocket(t *testing.T) {
	db := newDB(t)
	r := NewRegistry(Options{DB: db, Heartbeat: time.Hour})
	changes := make(chan int64, 8)
	r.OnConnectionChange = func(id int64) { changes <- id }
	srv, client := gatewayServer(t, r)
	conn := dial(t, srv, client)
	defer conn.CloseNow()
	ctx := context.Background()
	if err := conn.Write(ctx, websocket.MessageText, []byte(helloMessage)); err != nil {
		t.Fatal(err)
	}
	hello := readJSON(t, conn)
	device, _ := hello["device"].(map[string]any)
	if hello["ok"] != true || device["deviceId"] != "mac-1" || device["status"] != "online" || device["displays"].([]any)[0].(map[string]any)["label"] != "Built-in" {
		t.Fatalf("hello %v", hello)
	}
	<-changes
	if !r.IsConnected(1) {
		t.Fatal("not connected")
	}
	// The device answers a command the server dispatches.
	go func() {
		cmd := readJSON(t, conn)
		payload := cmd["payload"].(map[string]any)
		reply, _ := json.Marshal(map[string]any{"type": "result", "id": cmd["id"], "ok": true, "payload": map[string]any{"clicked": payload["x"], "paused": false}})
		_ = conn.Write(ctx, websocket.MessageText, reply)
	}()
	res, err := r.Dispatch(ctx, 1, "", CmdClick, map[string]any{"x": 10, "y": 20}, 0)
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := json.Marshal(res)
	if !strings.HasPrefix(string(raw), `{"clicked":10,"paused":false,"device":{"id":`) {
		t.Fatalf("dispatch %s", raw)
	}
	// A failure the device reports comes back as an error with its code.
	go func() {
		cmd := readJSON(t, conn)
		reply, _ := json.Marshal(map[string]any{"type": "result", "id": cmd["id"], "ok": false, "error": "Screen recording permission missing", "code": "PERMISSION"})
		_ = conn.Write(ctx, websocket.MessageText, reply)
	}()
	if _, err := r.Dispatch(ctx, 1, "", CmdCaptureFrame, nil, 0); err == nil || err.Error() != "Screen recording permission missing" {
		t.Fatalf("error %v", err)
	}
	// An unanswered command times out and is cancelled on the device.
	go func() {
		readJSON(t, conn) // the command
		cancel := readJSON(t, conn)
		if cancel["command"] != CmdCancel {
			t.Errorf("expected cancel, got %v", cancel)
		}
	}()
	if _, err := r.Dispatch(ctx, 1, "", CmdObserve, nil, 200*time.Millisecond); err == nil || !strings.Contains(err.Error(), "timed out") {
		t.Fatalf("timeout %v", err)
	}
	st := r.Status(ctx, 1)
	if !st.Connected || st.SelectedDeviceID != "mac-1" || st.OnlineCount != 1 {
		t.Fatalf("status %+v", st)
	}
	conn.Close(websocket.StatusNormalClosure, "bye")
	for deadline := time.Now().Add(5 * time.Second); (r.IsConnected(1) || r.Device(ctx, 1, "mac-1").Status != "offline") && time.Now().Before(deadline); {
		time.Sleep(20 * time.Millisecond)
	}
	if r.IsConnected(1) || r.Device(ctx, 1, "mac-1").Status != "offline" {
		t.Fatal("device still online after disconnect")
	}
}

func TestHelloIsChecked(t *testing.T) {
	db := newDB(t)
	r := NewRegistry(Options{DB: db, Heartbeat: time.Hour})
	srv, client := gatewayServer(t, r)
	conn := dial(t, srv, client)
	defer conn.CloseNow()
	_ = conn.Write(context.Background(), websocket.MessageText, []byte(`{"type":"hello","device":{"deviceId":"x","activationId":"a","companionEnabled":false}}`))
	if reply := readJSON(t, conn); reply["ok"] != false || reply["error"] != "Companion mode is not enabled on this desktop app." {
		t.Fatalf("%v", reply)
	}
	// A revoked device cannot reconnect with the same activation.
	ctx := context.Background()
	if _, _, err := r.Register(ctx, 1, "", &inProcess{open: true}, Hello{DeviceID: "dev", ActivationID: "a1", CompanionEnabled: true}); err != nil {
		t.Fatal(err)
	}
	if err := r.Revoke(ctx, 1, "dev"); err != nil {
		t.Fatal(err)
	}
	_, _, err := r.Register(ctx, 1, "", &inProcess{open: true}, Hello{DeviceID: "dev", ActivationID: "a1", CompanionEnabled: true})
	if e, ok := err.(*Error); !ok || e.Code != "DESKTOP_DEVICE_REVOKED" {
		t.Fatalf("%v", err)
	}
}

func TestHostCompanionRunsCommandsAndFiles(t *testing.T) {
	db := newDB(t)
	r := NewRegistry(Options{DB: db, Heartbeat: time.Hour})
	ws, err := workspace.New(t.TempDir(), false)
	if err != nil {
		t.Fatal(err)
	}
	h := &HostCompanion{Registry: r, Workspaces: ws}
	defer h.Shutdown()
	ctx := context.Background()
	if err := h.Ensure(ctx, 1); err != nil {
		t.Fatal(err)
	}
	res, err := r.Dispatch(ctx, 1, "", CmdExecute, map[string]any{"command": "pwd; echo hi", "cwd": "__neoagent_workspace__"}, 0)
	if err != nil {
		t.Fatal(err)
	}
	root, _ := ws.Root("1")
	resolved, _ := filepath.EvalSymlinks(root)
	if out := res.String("stdout"); !strings.Contains(out, "hi") || (!strings.Contains(out, root) && !strings.Contains(out, resolved)) {
		t.Fatalf("stdout %q (root %s)", out, root)
	}
	if _, err := r.Dispatch(ctx, 1, "", CmdWriteFile, map[string]any{"path": "notes.txt", "content": "tide"}, 0); err != nil {
		t.Fatal(err)
	}
	read, err := r.Dispatch(ctx, 1, "", CmdReadFile, map[string]any{"path": "notes.txt"}, 0)
	if err != nil || !strings.Contains(read.String("content"), "tide") {
		t.Fatalf("read %v %v", read, err)
	}
	if _, err := r.Dispatch(ctx, 1, "", CmdCaptureFrame, nil, 0); err == nil || !strings.Contains(err.Error(), "has no screen") {
		t.Fatalf("screen %v", err)
	}
	if got := r.SelectedDeviceID(ctx, 1); !strings.HasPrefix(got, "cli-") {
		t.Fatalf("selected %q", got)
	}
	h.Shutdown()
	if r.IsConnected(1) || r.SelectedDeviceID(ctx, 1) != "" {
		t.Fatal("host companion still registered")
	}
}
