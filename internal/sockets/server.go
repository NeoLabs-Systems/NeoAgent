// Package sockets is NeoAgent's realtime surface: the Socket.IO server the
// Flutter app and the web client connect to (services/websocket.js,
// http/socket.js), the hub that relays remote-control stream frames
// (services/streaming/stream-hub.js) and the /api/stream routes.
//
// Other domains push events to clients through EmitToUser / EmitToRoom of the
// hub (Server.EmitToUser delegates to it); the handlers here own the events the
// clients send.
package sockets

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/realtime"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

// Config holds everything a Server needs.
type Config struct {
	DB       *dbx.DB
	Services Services
	// Hub are the Socket.IO options; HubOptions builds them from the environment.
	Hub realtime.Options
	// NoSubscriberGrace stops a stream nobody watches; HubOptions' sibling
	// StreamGrace reads it from the environment.
	NoSubscriberGrace time.Duration
	Controllers       Controllers
	// Home and Root are hidden from error text shown by the stream routes.
	Home, Root string
	Log        *slog.Logger
	Now        func() time.Time
}

// Server is the realtime layer of the app.
type Server struct {
	cfg     Config
	log     *slog.Logger
	hub     *realtime.Hub
	streams *StreamHub
	limits  *limiter
	watch   *observer
}

// New builds the server. It fails when a required collaborator is missing.
func New(cfg Config) (*Server, error) {
	s := cfg.Services
	switch {
	case cfg.DB == nil:
		return nil, errors.New("sockets: DB is required")
	case s.Access == nil, s.Agents == nil, s.Engine == nil, s.Conversations == nil, s.Chat == nil,
		s.RunEvents == nil, s.Messaging == nil, s.Voice == nil, s.MCP == nil, s.Memory == nil:
		return nil, errors.New("sockets: a required service is missing")
	}
	if cfg.Log == nil {
		cfg.Log = slog.Default()
	}
	if cfg.Now == nil {
		cfg.Now = time.Now
	}
	if cfg.Hub.Log == nil {
		cfg.Hub.Log = cfg.Log
	}
	hub := realtime.New(cfg.Hub)
	srv := &Server{
		cfg:     cfg,
		log:     cfg.Log,
		hub:     hub,
		streams: NewStreamHub(hub, cfg.NoSubscriberGrace, cfg.Log),
		limits:  newLimiter(cfg.Now),
		watch:   newObserver(cfg.Log, cfg.Now),
	}
	hub.OnConnection(srv.connection)
	return srv, nil
}

// Hub is the Socket.IO hub other domains emit through.
func (s *Server) Hub() *realtime.Hub { return s.hub }

// StreamHub is the hub the desktop gateway and the stream routes feed.
func (s *Server) StreamHub() *StreamHub { return s.streams }

// EmitToUser sends an event to all sockets of an account.
func (s *Server) EmitToUser(userID int64, event string, payload any) {
	s.hub.EmitToUser(userID, event, payload)
}

// EmitToRoom sends an event to all sockets in a room.
func (s *Server) EmitToRoom(room, event string, payload any) {
	s.hub.EmitToRoom(room, event, payload)
}

// RateLimitSnapshot is the websocket rate-limit diagnostics for the admin.
func (s *Server) RateLimitSnapshot() RateLimitSnapshot { return s.watch.snapshot() }

// Routes mounts the Socket.IO endpoint and the stream routes.
func (s *Server) Routes(mux *http.ServeMux) {
	mux.Handle("/socket.io/", s.hub)
	s.streamRoutes(mux)
}

// Close disconnects all clients and stops all streams.
func (s *Server) Close() {
	s.hub.Close()
	s.streams.Shutdown()
}

// client is one authenticated socket and the state its handlers share.
type client struct {
	srv    *Server
	sock   *realtime.Socket
	userID int64
	limits *userLimits

	mu            sync.Mutex
	voiceSessions map[string]struct{}
}

func sessionUserID(sock *realtime.Socket) (int64, bool) {
	sess := sessionx.FromContext(sock.Request().Context())
	if sess == nil {
		return 0, false
	}
	id, ok := sess.Int64("userId")
	return id, ok && id != 0
}

// connection runs for every socket that joins the default namespace.
func (s *Server) connection(sock *realtime.Socket) {
	userID, ok := sessionUserID(sock)
	if !ok {
		s.log.Warn("[WS] Rejecting unauthenticated socket", "socketId", sock.ID())
		sock.Disconnect(true)
		return
	}
	sock.Join(realtime.UserRoom(userID))
	c := &client{srv: s, sock: sock, userID: userID, limits: s.limits.acquire(userID), voiceSessions: map[string]struct{}{}}
	s.log.Info("[WS] User connected", "userId", userID, "socketId", sock.ID())

	if calls := s.cfg.Services.Calls; calls != nil {
		calls.OfferPendingCall(sock, userID)
	}
	if approvals := s.cfg.Services.Approvals; approvals != nil {
		approvals.OfferPendingApprovals(sock, userID)
	}
	for name, h := range c.handlers() {
		sock.On(name, c.wrap(name, h))
	}
	sock.OnDisconnect(c.disconnected)
}

// handler is the body of one client event. Async handlers do slow work (they
// call into other domains and wait); they run on their own goroutine so the
// socket keeps serving its other events, as the Node handlers do when they
// await. The others are quick and run in order of arrival.
type handler struct {
	run   func(ev *realtime.Event)
	async bool
}

// refusal says how a rate-limited event is answered.
type refusal struct {
	event, field string
	record       bool
	extra        map[string]any
}

func (c *client) wrap(name string, h handler) realtime.Handler {
	return func(ev *realtime.Event) {
		if c.refused(name) {
			return
		}
		run := func() {
			defer func() {
				if r := recover(); r != nil {
					c.srv.log.Error("[WS] handler panicked", "event", name, "userId", c.userID, "panic", r)
				}
			}()
			h.run(ev)
		}
		if h.async {
			go run()
			return
		}
		run()
	}
}

// refused counts the event against the account's budget and, when it is over,
// tells the client the way Node does for that event.
func (c *client) refused(name string) bool {
	ok, retry := c.srv.limits.allow(c.limits, name)
	if ok {
		return false
	}
	r := refusals[name]
	if r.record {
		c.srv.watch.record(c.userID, c.sock.ID(), name, retry)
	}
	payload := map[string]any{r.field: rateLimitMessage(name, retry)}
	for k, v := range r.extra {
		payload[k] = v
	}
	_ = c.sock.Emit(r.event, payload)
	return true
}

// refusals is the answer to each rate-limited event.
var refusals = map[string]refusal{
	"agent:run":            {event: "run:error", field: "error", record: true},
	"agent:abort":          {event: "error", field: "message", record: true},
	"agent:history":        {event: "error", field: "message", record: true},
	"agent:run_detail":     {event: "error", field: "message", record: true},
	"messaging:connect":    {event: "messaging:error", field: "error", record: true},
	"messaging:disconnect": {event: "messaging:error", field: "error", record: true},
	"messaging:send":       {event: "messaging:error", field: "error", record: true},
	"messaging:status":     {event: "messaging:error", field: "error", record: true},
	"voice:call_accept":    {event: "voice:error", field: "error"},
	"voice:call_decline":   {event: "voice:error", field: "error"},
	"voice:session_open":   {event: "voice:error", field: "error", record: true},
	"voice:audio":          voiceSessionRefusal,
	"voice:input_start":    voiceSessionRefusal,
	"voice:input_end":      voiceSessionRefusal,
	"voice:interrupt":      voiceSessionRefusal,
	"voice:cancel_task":    voiceSessionRefusal,
	"voice:session_close":  voiceSessionRefusal,
	"mcp:status":           {event: "mcp:error", field: "error", record: true},
	"mcp:tools":            {event: "mcp:error", field: "error", record: true},
	"integrations:status":  {event: "error", field: "message", record: true},
	"memory:read":          {event: "error", field: "message", record: true},
	"memory:search":        {event: "error", field: "message", record: true},
	"stream:subscribe":     {event: "stream:error", field: "error", record: true},
	"stream:unsubscribe":   {event: "stream:error", field: "error", record: true},
}

var voiceSessionRefusal = refusal{event: "voice:error", field: "error", record: true, extra: map[string]any{"recoverable": true}}

// errorText is errorMessageForUser.
func (c *client) errorText(err error) string {
	return c.srv.cfg.Services.Access.ErrorMessageForUser(c.userID, err)
}

// failWith tells the client an event failed, as `socket.emit(event, {field: errorMessageForUser})`.
func (c *client) failWith(event, field string, err error, extra ...any) {
	payload := map[string]any{field: c.errorText(err)}
	for i := 0; i+1 < len(extra); i += 2 {
		payload[extra[i].(string)] = extra[i+1]
	}
	_ = c.sock.Emit(event, payload)
}

// agentFor is resolveAgentFromPayload: the agent a payload names, else the default.
func (c *client) agentFor(candidate string) (string, error) {
	return c.srv.cfg.Services.Agents.Resolve(context.Background(), c.userID, candidate)
}

func agentCandidate(data map[string]any) string {
	return firstTruthy(data["agentId"], data["agent_id"])
}

// disconnected cleans up after a socket: its call, its stream subscriptions
// and its voice sessions.
func (c *client) disconnected(reason string) {
	s := c.srv
	if calls := s.cfg.Services.Calls; calls != nil {
		calls.HandleDisconnect(c.sock.ID(), c.userID)
	}
	s.limits.release(c.userID)
	go s.streams.UnsubscribeAll(c.sock.ID())

	c.mu.Lock()
	ids := make([]string, 0, len(c.voiceSessions))
	for id := range c.voiceSessions {
		ids = append(ids, id)
	}
	c.voiceSessions = map[string]struct{}{}
	c.mu.Unlock()
	for _, id := range ids {
		go func() {
			if err := s.cfg.Services.Voice.DetachSession(context.Background(), id, "socket_disconnected", c.userID); err != nil {
				s.log.Error("[WS] Failed to detach voice session after socket disconnect", "sessionId", id, "error", err)
			}
		}()
	}
	s.log.Info("[WS] User disconnected", "userId", c.userID, "socketId", c.sock.ID(), "reason", reason)
}

func (c *client) trackVoiceSession(id string, open bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if open {
		c.voiceSessions[id] = struct{}{}
	} else {
		delete(c.voiceSessions, id)
	}
}

// HubOptions reads the socket settings of the Node server from the
// environment (NEOAGENT_SOCKET_*) and applies the origin rule: configured
// origins, else loopback only, and clients without an Origin header.
func HubOptions(getenv func(string) string, origins httpx.Origins, log *slog.Logger) realtime.Options {
	ms := func(name string, def time.Duration) time.Duration {
		if n, err := strconv.ParseFloat(strings.TrimSpace(getenv(name)), 64); err == nil && n > 0 {
			return time.Duration(n * float64(time.Millisecond))
		}
		return def
	}
	payload := int64(8 * 1024 * 1024)
	if n, err := strconv.ParseFloat(strings.TrimSpace(getenv("NEOAGENT_SOCKET_MAX_HTTP_BUFFER_BYTES")), 64); err == nil && n > 0 {
		payload = int64(n)
	}
	return realtime.Options{
		PingInterval:   ms("NEOAGENT_SOCKET_PING_INTERVAL_MS", 25*time.Second),
		PingTimeout:    ms("NEOAGENT_SOCKET_PING_TIMEOUT_MS", 20*time.Second),
		ConnectTimeout: ms("NEOAGENT_SOCKET_CONNECT_TIMEOUT_MS", 10*time.Second),
		MaxPayload:     payload,
		AllowOrigin:    func(origin string) bool { return origins.Allowed(origin, true) },
		Log:            log,
	}
}

// StreamGrace is NEOAGENT_STREAM_NO_SUBSCRIBER_GRACE_MS (default 15 s, 0 disables).
func StreamGrace(getenv func(string) string) time.Duration {
	raw := strings.TrimSpace(getenv("NEOAGENT_STREAM_NO_SUBSCRIBER_GRACE_MS"))
	if n, err := strconv.ParseFloat(raw, 64); err == nil && raw != "" && n >= 0 {
		return time.Duration(n * float64(time.Millisecond))
	}
	return 15 * time.Second
}

// FirstFrameTimeout is NEOAGENT_ANDROID_STREAM_FIRST_FRAME_TIMEOUT_MS: how long
// the Android H.264 pipeline may take to produce a frame (default 6 s).
func FirstFrameTimeout(getenv func(string) string) time.Duration {
	if n, err := strconv.Atoi(strings.TrimSpace(getenv("NEOAGENT_ANDROID_STREAM_FIRST_FRAME_TIMEOUT_MS"))); err == nil && n > 0 {
		return time.Duration(n) * time.Millisecond
	}
	return defaultFirstFrameTimeout
}

func (s *Server) firstFrameTimeout() time.Duration {
	if d := s.cfg.Controllers.AndroidFirstFrameTimeout; d > 0 {
		return d
	}
	return defaultFirstFrameTimeout
}
