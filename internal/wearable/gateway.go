package wearable

import (
	"context"
	"log/slog"
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/audiox"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/livevoice"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
	"github.com/NeoLabs-Systems/neolabs-go/wsclient"
)

const (
	helloTimeout      = 5 * time.Second
	heartbeatInterval = 30 * time.Second
	maxMessageBytes   = 1 << 20
	maxAudioChars     = 800000
	maxSessionIDChars = 128
	writeTimeout      = 10 * time.Second
	// outQueue bounds what is waiting to be written to one device; a device
	// that does not keep up is dropped rather than stalling its call.
	outQueue = 256
	// Upgrade attempts per address per window.
	upgradeWindow   = time.Minute
	upgradeAttempts = 30
)

// Voice is the live voice runtime as the gateway uses it. voice.Manager
// satisfies it.
type Voice interface {
	// OpenWearableCall starts the wearable's push-to-talk call, or reattaches to
	// a known session id, and returns the session's id.
	OpenWearableCall(ctx context.Context, userID int64, agentID, sessionID, devicePlatform string, sink livevoice.Sink) (string, error)
	AppendAudio(sessionID string, pcm []byte, userID int64) error
	StartInput(sessionID string, userID int64) error
	EndInput(sessionID string, userID int64) error
	InterruptOutput(sessionID string, userID int64) error
	CloseSession(sessionID, reason string, userID int64, cancelTask bool) error
}

// GatewayConfig wires the WebSocket gateway.
type GatewayConfig struct {
	Service *Service
	Voice   Voice
	Log     *slog.Logger
	// UserID returns the signed-in account of the upgrade request. Nil reads
	// "userId" from the session.
	UserID     func(*http.Request) (int64, bool)
	TrustProxy bool
	// Sanitize hides paths in errors sent to the device (publicerr.Sanitize).
	Sanitize func(string) string
	// Heartbeat and HelloTimeout default to the Node values; tests shorten them.
	Heartbeat    time.Duration
	HelloTimeout time.Duration
}

// Gateway carries wearables' live voice calls over a raw WebSocket with session
// auth. The wearable opens it with its paired session cookie, says hello, and
// then opens, feeds and closes calls with JSON messages.
type Gateway struct {
	cfg GatewayConfig

	mu       sync.Mutex
	attempts map[string]*attempt
	conns    map[*deviceConn]struct{}
	closing  bool
}

type attempt struct {
	windowStart time.Time
	count       int
}

// NewGateway builds the gateway.
func NewGateway(cfg GatewayConfig) *Gateway {
	if cfg.UserID == nil {
		cfg.UserID = sessionUserID
	}
	if cfg.Log == nil {
		cfg.Log = slog.Default()
	}
	if cfg.Heartbeat == 0 {
		cfg.Heartbeat = heartbeatInterval
	}
	if cfg.HelloTimeout == 0 {
		cfg.HelloTimeout = helloTimeout
	}
	return &Gateway{cfg: cfg, attempts: map[string]*attempt{}, conns: map[*deviceConn]struct{}{}}
}

func sessionUserID(r *http.Request) (int64, bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}

// Routes registers the socket on mux.
func (g *Gateway) Routes(mux *http.ServeMux) {
	mux.HandleFunc("GET "+WSPath, g.serve)
}

// allow counts one upgrade attempt of an address in a fixed window.
func (g *Gateway) allow(address string) bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	now := time.Now()
	for key, a := range g.attempts {
		if now.Sub(a.windowStart) >= upgradeWindow {
			delete(g.attempts, key)
		}
	}
	current := g.attempts[address]
	if current == nil {
		g.attempts[address] = &attempt{windowStart: now, count: 1}
		return true
	}
	if current.count >= upgradeAttempts {
		return false
	}
	current.count++
	return true
}

// Close ends every device connection.
func (g *Gateway) Close() {
	g.mu.Lock()
	g.closing = true
	conns := make([]*deviceConn, 0, len(g.conns))
	for c := range g.conns {
		conns = append(conns, c)
	}
	g.mu.Unlock()
	for _, c := range conns {
		_ = c.ws.Close(wsclient.CloseNormal, "server shutdown")
	}
}

func (g *Gateway) serve(w http.ResponseWriter, r *http.Request) {
	address := httpx.ClientIP(r, g.cfg.TrustProxy)
	if !g.allow(address) {
		w.WriteHeader(http.StatusTooManyRequests)
		return
	}
	userID, ok := g.cfg.UserID(r)
	if !ok {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}
	g.mu.Lock()
	closing := g.closing
	g.mu.Unlock()
	if closing {
		w.WriteHeader(http.StatusServiceUnavailable)
		return
	}
	ws, err := wsclient.Accept(w, r, wsclient.AcceptOptions{ReadLimit: maxMessageBytes})
	if err != nil {
		return
	}
	conn := &deviceConn{
		g: g, ws: ws, userID: userID, address: address, userAgent: r.Header.Get("User-Agent"),
		socketAddress: remoteAddress(r, false), out: make(chan []byte, outQueue), active: map[string]struct{}{},
	}
	g.mu.Lock()
	g.conns[conn] = struct{}{}
	g.mu.Unlock()
	conn.run(r.Context())
	g.mu.Lock()
	delete(g.conns, conn)
	g.mu.Unlock()
}

// deviceConn is one wearable's socket.
type deviceConn struct {
	g             *Gateway
	ws            *wsclient.Conn
	userID        int64
	address       string
	userAgent     string
	socketAddress string
	out           chan []byte

	initialized atomic.Bool
	deviceID    string
	platform    string
	active      map[string]struct{}
	mu          sync.Mutex
}

func (c *deviceConn) run(parent context.Context) {
	ctx, cancel := context.WithCancel(parent)
	defer cancel()

	hello := time.AfterFunc(c.g.cfg.HelloTimeout, func() {
		if !c.initialized.Load() {
			_ = c.ws.Close(wsclient.ClosePolicyViolation, "Wearable hello timed out")
		}
	})
	defer hello.Stop()
	go c.writeLoop(ctx)
	go c.heartbeat(ctx)

	for {
		_, data, err := c.ws.Read(ctx)
		if err != nil {
			break
		}
		c.handle(ctx, data)
	}
	cancel()
	c.teardown()
}

func (c *deviceConn) writeLoop(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case data := <-c.out:
			wctx, cancel := context.WithTimeout(ctx, writeTimeout)
			err := c.ws.WriteText(wctx, data)
			cancel()
			if err != nil {
				_ = c.ws.CloseNow()
				return
			}
		}
	}
}

// heartbeat pings the device; one that does not answer in time is dropped.
func (c *deviceConn) heartbeat(ctx context.Context) {
	ticker := time.NewTicker(c.g.cfg.Heartbeat)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
		pctx, cancel := context.WithTimeout(ctx, c.g.cfg.Heartbeat)
		err := c.ws.Ping(pctx)
		cancel()
		if err != nil && ctx.Err() == nil {
			_ = c.ws.CloseNow()
			return
		}
	}
}

// send queues a message for the device; a device that cannot keep up is dropped.
func (c *deviceConn) send(payload fields) {
	data, err := payload.MarshalJSON()
	if err != nil {
		return
	}
	select {
	case c.out <- data:
	default:
		c.g.cfg.Log.Warn("Wearable too slow; dropping its connection", "deviceId", c.deviceID)
		_ = c.ws.CloseNow()
	}
}

func (c *deviceConn) sendError(err error) {
	message := err.Error()
	if c.g.cfg.Sanitize != nil {
		message = c.g.cfg.Sanitize(message)
	}
	c.send(fields{{"type", "voice:error"}, {"error", message}})
}

// sink carries a call's events to the device as {type: event, ...payload}.
func (c *deviceConn) sink() livevoice.Sink {
	return livevoice.SinkFunc(func(event string, payload map[string]any) {
		if !ShouldSendEvent(c.platform, event) {
			return
		}
		out := fields{{"type", event}}
		for k, v := range payload {
			out = append(out, field{k, v})
		}
		c.send(out)
	})
}

func (c *deviceConn) handle(ctx context.Context, data []byte) {
	msg, err := ParseMessage(data)
	if err != nil {
		c.sendError(err)
		return
	}
	svc := c.g.cfg.Service
	if !c.initialized.Load() {
		if !msg.IsHello() {
			c.sendError(errString("wearable:hello is required before other messages."))
			return
		}
		conn := svc.Register(RegisterParams{
			UserID: c.userID, Owner: c, RemoteAddress: c.address, SocketAddress: c.socketAddress,
			UserAgent: c.userAgent, Hello: msg.Fields,
		})
		c.mu.Lock()
		c.deviceID, c.platform = conn.DeviceID, conn.Hello.Platform
		c.mu.Unlock()
		c.initialized.Store(true)
		c.send(fields{
			{"type", "wearable:hello"}, {"ok", true}, {"deviceId", conn.DeviceID}, {"userId", c.userID},
			{"serverTime", isoTime(svc.cfg.Now())},
		})
		return
	}
	if !msg.Supported() {
		c.sendError(errString(`Unsupported wearable message type "` + msg.Type + `".`))
		return
	}
	svc.Touch(c.userID, c.deviceID)
	if err := c.dispatch(ctx, msg); err != nil {
		c.sendError(err)
	}
}

type errString string

func (e errString) Error() string { return string(e) }

func (c *deviceConn) dispatch(ctx context.Context, msg Message) error {
	voice := c.g.cfg.Voice
	sessionID := optionalString(msg.Fields["sessionId"], maxSessionIDChars)
	requireSession := func() error {
		if sessionID == "" {
			return errString("sessionId is required")
		}
		return nil
	}
	switch msg.Type {
	case "voice:session_open":
		agent := optionalString(msg.Fields["agentId"], 1<<20)
		if agent == "" {
			agent = optionalString(msg.Fields["agent_id"], 1<<20)
		}
		id, err := voice.OpenWearableCall(ctx, c.userID, agent, sessionID, c.platform, c.sink())
		if err != nil {
			return err
		}
		c.mu.Lock()
		c.active[id] = struct{}{}
		c.mu.Unlock()
	case "voice:audio":
		if err := requireSession(); err != nil {
			return err
		}
		audio := optionalString(msg.Fields["audioBase64"], maxAudioChars)
		if audio == "" {
			return errString("audioBase64 is required")
		}
		return voice.AppendAudio(sessionID, audiox.DecodeBase64(audio), c.userID)
	case "voice:input_start":
		if err := requireSession(); err != nil {
			return err
		}
		return voice.StartInput(sessionID, c.userID)
	case "voice:input_end":
		if err := requireSession(); err != nil {
			return err
		}
		return voice.EndInput(sessionID, c.userID)
	case "voice:interrupt":
		if err := requireSession(); err != nil {
			return err
		}
		return voice.InterruptOutput(sessionID, c.userID)
	case "voice:session_close":
		if err := requireSession(); err != nil {
			return err
		}
		c.mu.Lock()
		delete(c.active, sessionID)
		c.mu.Unlock()
		return voice.CloseSession(sessionID, "wearable_client_closed", c.userID, false)
	}
	return nil
}

// teardown forgets the device and releases its calls: one with work still
// running detaches and stays reattachable, the rest end.
func (c *deviceConn) teardown() {
	c.mu.Lock()
	deviceID := c.deviceID
	sessions := make([]string, 0, len(c.active))
	for id := range c.active {
		sessions = append(sessions, id)
	}
	c.mu.Unlock()
	if deviceID != "" {
		c.g.cfg.Service.Unregister(c.userID, deviceID, c)
	}
	for _, id := range sessions {
		// A call that is already gone needs no release; the rest were asked.
		if err := c.g.cfg.Voice.CloseSession(id, "wearable_socket_closed", c.userID, false); err != nil {
			c.g.cfg.Log.Debug("Wearable call not released", "sessionId", id, "error", err.Error())
		}
	}
}
