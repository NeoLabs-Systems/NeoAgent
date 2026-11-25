package desktop

import (
	"context"
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"github.com/coder/websocket"

	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
	"github.com/NeoLabs-Systems/neolabs-go/wsgate"

	"github.com/NeoLabs-Systems/neoagent/internal/streaming"
)

const (
	helloTimeout  = 5 * time.Second
	maxHelloBytes = 64 * 1024
)

// Gateway serves the desktop companion WebSocket.
type Gateway struct {
	Registry *Registry
	// Frames receives desktop stream frames; nil drops them.
	Frames streaming.FrameSink
	Gate   *wsgate.Gate
}

// NewGateway creates the gateway.
func NewGateway(r *Registry, frames streaming.FrameSink) *Gateway {
	return &Gateway{Registry: r, Frames: frames, Gate: wsgate.New(wsgate.Options{MaxMessage: MaxFrameBytes})}
}

// Routes registers the WebSocket endpoint.
func (g *Gateway) Routes(mux *http.ServeMux) { mux.HandleFunc("GET "+WebSocketPath, g.serve) }

// Close drops every companion socket.
func (g *Gateway) Close() { g.Gate.Close() }

// wsTransport is a companion WebSocket. The gate's keepalive pings it and
// terminates it when a ping goes unanswered, so while it is open it is alive.
type wsTransport struct {
	conn  *wsgate.Conn
	mu    sync.Mutex
	open  bool
	alive func()
}

func (t *wsTransport) Send(data []byte) error { return t.conn.SendText(data) }
func (t *wsTransport) Ping() error {
	t.mu.Lock()
	alive := t.open && t.alive != nil
	t.mu.Unlock()
	if alive {
		t.alive()
	}
	return nil
}
func (t *wsTransport) Open() bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.open
}
func (t *wsTransport) Close(reason string) {
	t.mu.Lock()
	t.open = false
	t.mu.Unlock()
	t.conn.Close(websocket.StatusNormalClosure, reason)
}

func (g *Gateway) serve(w http.ResponseWriter, r *http.Request) {
	userID, ok := g.Gate.Admit(w, r)
	if !ok {
		return
	}
	if g.Registry == nil {
		w.Header().Set("Connection", "close")
		w.WriteHeader(http.StatusServiceUnavailable)
		return
	}
	sessionID := ""
	if sess := sessionx.FromContext(r.Context()); sess != nil {
		sessionID = sess.ID()
	}
	conn, err := g.Gate.Accept(w, r)
	if err != nil {
		return
	}
	defer conn.Terminate()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	helloCtx, helloCancel := context.WithTimeout(ctx, helloTimeout)
	_, data, err := conn.Read(helloCtx)
	helloCancel()
	if err != nil {
		conn.Close(websocket.StatusPolicyViolation, "Desktop companion hello timed out")
		return
	}
	reject := func(message string) {
		_ = conn.SendJSON(map[string]any{"type": "hello", "ok": false, "error": message})
		if len(message) > 120 {
			message = message[:120]
		}
		conn.Close(websocket.StatusPolicyViolation, message)
	}
	if len(data) > maxHelloBytes {
		reject("Desktop companion hello is too large.")
		return
	}
	hello, isHello := ParseHello(data)
	if !isHello {
		reject("Desktop companion hello is required.")
		return
	}
	if err := CheckHello(hello); err != nil {
		reject(err.Error())
		return
	}
	transport := &wsTransport{conn: conn, open: true}
	connection, device, err := g.Registry.Register(r.Context(), userID, sessionID, transport, hello)
	if err != nil {
		reject(err.Error())
		return
	}
	transport.mu.Lock()
	transport.alive = connection.Pong
	transport.mu.Unlock()
	_ = conn.SendJSON(struct {
		Type   string  `json:"type"`
		OK     bool    `json:"ok"`
		UserID int64   `json:"userId"`
		Device *Device `json:"device"`
	}{"hello", true, userID, device})
	go conn.KeepAlive(ctx, g.Registry.heartbeat)
	for {
		binary, msg, err := conn.Read(ctx)
		if err != nil {
			break
		}
		if binary && len(msg) > 10 && msg[0] == frameTypeVideo {
			if f := ParseFrame(msg); f != nil && g.Frames != nil {
				g.Frames.HandleFrame(jsonID(userID), device.DeviceID, streaming.Frame{JPEG: f.JPEG, Platform: "desktop", Seq: f.Seq, TS: f.TS, Flags: f.Flags})
			}
			connection.HandleMessage(msg[:1])
			continue
		}
		connection.HandleMessage(msg)
	}
	transport.mu.Lock()
	transport.open = false
	transport.mu.Unlock()
	connection.Closed()
}

func jsonID(id int64) string {
	raw, _ := json.Marshal(id)
	return string(raw)
}
