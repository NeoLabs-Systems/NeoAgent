package sockets

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/schema"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/secheaders"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
	"github.com/coder/websocket"
)

// fakeBackend implements every domain interface of Services and records the
// calls, so the tests can see exactly what the handlers asked of the domains.
type fakeBackend struct {
	mu    sync.Mutex
	calls []string

	// behaviour switches
	runErr       error
	runResult    RunResult
	steerable    *SteerableRun
	steerQueued  bool
	command      *CommandResult
	chatWindow   int
	chatRecent   []map[string]any
	ownedConv    map[string]bool
	acceptResult AcceptResult
	voiceOpenErr error
	abortErr     error
	admins       map[int64]bool
	panicMemory  bool
}

func (f *fakeBackend) record(format string, args ...any) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, fmt.Sprintf(format, args...))
}

func (f *fakeBackend) seen() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]string(nil), f.calls...)
}

func (f *fakeBackend) has(prefix string) bool {
	for _, c := range f.seen() {
		if strings.HasPrefix(c, prefix) {
			return true
		}
	}
	return false
}

func (f *fakeBackend) waitFor(t *testing.T, prefix string) {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if f.has(prefix) {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("no call %q in %v", prefix, f.seen())
}

// Access
func (f *fakeBackend) ErrorMessageForUser(userID int64, err error) string {
	if f.admins[userID] {
		return err.Error()
	}
	return publicerr.Generic
}

func (f *fakeBackend) RunRecordsForUser(userID int64, r RunRecords) RunRecords {
	f.record("redact user=%d", userID)
	return r
}

// RunEvents
func (f *fakeBackend) List(_ context.Context, runID string) ([]any, error) {
	return []any{map[string]any{"run": runID, "type": "run:start"}}, nil
}

// Agents: slug "other" names a second agent, everything else the default.
func (f *fakeBackend) Resolve(_ context.Context, userID int64, candidate string) (string, error) {
	f.record("resolve user=%d candidate=%q", userID, candidate)
	if candidate == "other" {
		return "agent-other", nil
	}
	return "agent-main", nil
}

// Engine
func (f *fakeBackend) FindSteerableRun(userID int64, source string) (SteerableRun, bool) {
	if f.steerable != nil {
		return *f.steerable, true
	}
	return SteerableRun{}, false
}

func (f *fakeBackend) EnqueueSteering(runID, task string, o SteerOptions) bool {
	f.record("steer run=%s task=%s platform=%s conv=%s socket=%t", runID, task, o.Platform, o.ConversationID, o.SocketID != "")
	return f.steerQueued
}

func (f *fakeBackend) Run(_ context.Context, userID int64, task string, o RunOptions) (RunResult, error) {
	b, _ := json.Marshal(o)
	f.record("run user=%d task=%s opts=%s", userID, task, b)
	if f.runErr != nil {
		return RunResult{}, f.runErr
	}
	return f.runResult, nil
}

func (f *fakeBackend) Abort(runID string, userID int64) error {
	f.record("abort run=%q user=%d", runID, userID)
	return f.abortErr
}

// Commands
func (f *fakeBackend) Dispatch(_ context.Context, task string, userID int64, agentID, source, socketID string) (CommandResult, error) {
	f.record("command %s agent=%s source=%s", task, agentID, source)
	if f.command != nil {
		return *f.command, nil
	}
	return CommandResult{}, nil
}

// Conversations
func (f *fakeBackend) own(conversationID string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.ownedConv[conversationID] = true
}

func (f *fakeBackend) AssertOwned(userID int64, conversationID string) error {
	f.mu.Lock()
	owned := f.ownedConv[conversationID]
	f.mu.Unlock()
	if !owned {
		return errors.New("conversation not found")
	}
	return nil
}

func (f *fakeBackend) DefaultWebID(userID int64, agentID string) (string, error) {
	return "conv-default-" + agentID, nil
}

// Chat
func (f *fakeBackend) EnsureSettings(userID int64, agentID string) (int, error) {
	return f.chatWindow, nil
}

func (f *fakeBackend) WebContext(userID int64, window int, agentID string) (ChatContext, error) {
	return ChatContext{Recent: f.chatRecent, Summary: "summary"}, nil
}

func (f *fakeBackend) StoreWebReply(userID int64, agentID, conversationID string, r RunResult) error {
	f.record("store user=%d agent=%s conv=%s run=%s", userID, agentID, conversationID, r.RunID)
	return nil
}

// Messaging
func (f *fakeBackend) Connect(_ context.Context, userID int64, platform string, config map[string]any, agentID string) (any, error) {
	f.record("connect %s agent=%s config=%v", platform, agentID, config)
	return map[string]any{"platform": platform, "status": "connecting"}, nil
}

func (f *fakeBackend) Disconnect(_ context.Context, userID int64, platform, agentID string) (any, error) {
	f.record("disconnect %s agent=%s", platform, agentID)
	return map[string]any{"platform": platform, "ok": true}, nil
}

func (f *fakeBackend) Send(_ context.Context, userID int64, platform, to, content, agentID, media string) (any, error) {
	f.record("send %s to=%s content=%s agent=%s media=%s", platform, to, content, agentID, media)
	if platform == "broken" {
		return nil, errors.New("boom")
	}
	return map[string]any{"platform": platform, "to": to, "ok": true}, nil
}

func (f *fakeBackend) Statuses(userID int64, agentID string) (any, error) {
	return map[string]any{"agent": agentID, "whatsapp": "connected"}, nil
}

// Voice
func (f *fakeBackend) OpenFlutterSession(_ context.Context, o OpenVoiceSession) (string, error) {
	f.record("voice-open user=%d agent=%s session=%q peer=%t", o.UserID, o.AgentID, o.SessionID, o.Peer != nil)
	if f.voiceOpenErr != nil {
		return "", f.voiceOpenErr
	}
	if o.SessionID != "" {
		return o.SessionID, nil
	}
	return "sess-new", nil
}

func (f *fakeBackend) AppendAudio(id string, audio []byte, userID int64) error {
	f.record("audio %s %x", id, audio)
	return nil
}

func (f *fakeBackend) StartInput(id string, userID int64) error {
	f.record("input-start %s", id)
	return nil
}

func (f *fakeBackend) EndInput(id string, userID int64) error {
	f.record("input-end %s", id)
	return errors.New("no such session")
}

func (f *fakeBackend) InterruptOutput(id string, userID int64) error {
	f.record("interrupt %s", id)
	return nil
}

func (f *fakeBackend) CancelTask(id string, userID int64, runID string) error {
	f.record("cancel-task %s run=%s", id, runID)
	return nil
}

func (f *fakeBackend) CloseSession(_ context.Context, id, reason string, userID int64, cancel bool) error {
	f.record("close %s reason=%s cancel=%t", id, reason, cancel)
	return nil
}

func (f *fakeBackend) DetachSession(_ context.Context, id, reason string, userID int64) error {
	f.record("detach %s reason=%s", id, reason)
	return nil
}

// AgentCalls
func (f *fakeBackend) OfferPendingCall(p Peer, userID int64) {
	f.record("offer-call user=%d ua=%q", userID, p.Request().Header.Get("User-Agent"))
}

func (f *fakeBackend) Accept(_ context.Context, callID string, userID int64, p Peer) (AcceptResult, error) {
	f.record("accept %s", callID)
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.acceptResult, nil
}

func (f *fakeBackend) Decline(callID string, userID int64, p Peer, later bool) error {
	f.record("decline %s later=%t", callID, later)
	return nil
}

func (f *fakeBackend) HandleDisconnect(socketID string, userID int64) {
	f.record("call-disconnect user=%d", userID)
}

// Approvals
func (f *fakeBackend) OfferPendingApprovals(p Peer, userID int64) {
	f.record("offer-approvals user=%d", userID)
}

// MCP
func (f *fakeBackend) Status(_ context.Context, userID int64, agentID string) (any, error) {
	return map[string]any{"servers": []any{}, "agent": agentID}, nil
}

func (f *fakeBackend) ListTools(_ context.Context, serverID string, userID int64) (any, error) {
	return []any{map[string]any{"server": serverID}}, nil
}

func (f *fakeBackend) AllTools(userID int64, agentID string) (any, error) {
	return []any{map[string]any{"all": true, "agent": agentID}}, nil
}

// Integrations
func (f *fakeBackend) ListProviders(userID int64, agentID string) (any, error) {
	return []any{map[string]any{"id": "google", "agent": agentID}}, nil
}

// Memory
func (f *fakeBackend) Read(userID int64) (any, error) {
	f.record("memory-read")
	f.mu.Lock()
	boom := f.panicMemory
	f.mu.Unlock()
	if boom {
		panic("memory exploded")
	}
	return "memory text", nil
}
func (f *fakeBackend) AssistantBehaviorNotes(userID int64, agentID string) (any, error) {
	return []any{"note for " + agentID}, nil
}
func (f *fakeBackend) DailyLogs(count int, userID int64) (any, error) {
	return []any{map[string]any{"days": count}}, nil
}
func (f *fakeBackend) Search(_ context.Context, query string, userID int64, agentID string) (any, error) {
	return map[string]any{"query": query, "agent": agentID}, nil
}

func (f *fakeBackend) services() Services {
	return Services{
		Access: f, Agents: f, Engine: f, Commands: f, Conversations: f, Chat: f, RunEvents: f,
		Messaging: f, Voice: f, Calls: f, Approvals: f, MCP: f, Integrations: f, Memory: f,
	}
}

// stack is a Server behind the production-style middleware chain (sessions,
// error redaction, security headers, CORS) with a real SQLite database.
type stack struct {
	t       *testing.T
	srv     *Server
	http    *httptest.Server
	db      *dbx.DB
	fake    *fakeBackend
	cookies map[int64]string
}

type stackOpts struct {
	mod          func(*Config)
	fake         *fakeBackend
	strictLimits bool
}

func newStack(t *testing.T, opts ...func(*stackOpts)) *stack {
	t.Helper()
	o := &stackOpts{fake: &fakeBackend{chatWindow: 10, ownedConv: map[string]bool{}, admins: map[int64]bool{}}}
	for _, fn := range opts {
		fn(o)
	}
	ctx := context.Background()
	dir := t.TempDir()
	db, err := dbx.Open(ctx, filepath.Join(dir, "neoagent.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if err := schema.Ensure(ctx, db.W); err != nil {
		t.Fatal(err)
	}
	for id := 1; id <= 3; id++ {
		if _, err := db.W.Exec(`INSERT INTO users (id, username, password) VALUES (?, ?, 'x')`, id, "user"+strconv.Itoa(id)); err != nil {
			t.Fatal(err)
		}
	}
	for _, agent := range []string{"agent-main", "agent-other"} {
		if _, err := db.W.Exec(`INSERT INTO agents (id, user_id, slug, display_name) VALUES (?, 1, ?, ?)`, agent, agent, agent); err != nil {
			t.Fatal(err)
		}
	}
	sdb, err := dbx.Open(ctx, filepath.Join(dir, "sessions.db"), dbx.Options{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { sdb.Close() })
	store, err := sessionx.NewStore(ctx, sdb.W)
	if err != nil {
		t.Fatal(err)
	}
	mgr, err := sessionx.NewManager(store, sessionx.Options{Name: "neoagent.sid", Secrets: []string{"test-secret"}})
	if err != nil {
		t.Fatal(err)
	}

	origins := httpx.ParseOrigins("")
	cfg := Config{
		DB:       db,
		Services: o.fake.services(),
		Hub:      HubOptions(func(string) string { return "" }, origins, slog.New(slog.NewTextHandler(io.Discard, nil))),
		Log:      slog.New(slog.NewTextHandler(io.Discard, nil)),
	}
	if o.mod != nil {
		o.mod(&cfg)
	}
	srv, err := New(cfg)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(srv.Close)
	if !o.strictLimits { // the tests send far more events than a real client does
		relaxed := map[string]eventLimit{}
		for name, l := range eventLimits {
			relaxed[name] = eventLimit{l.window, 1000}
		}
		srv.limits.table = relaxed
	}

	mux := http.NewServeMux()
	srv.Routes(mux)
	mux.HandleFunc("/test-login", func(w http.ResponseWriter, r *http.Request) {
		id, _ := strconv.ParseInt(r.URL.Query().Get("user"), 10, 64)
		sessionx.FromContext(r.Context()).Set("userId", id)
	})
	var app http.Handler = mux
	app = publicerr.Middleware(func(*http.Request) bool { return true })(app)
	app = mgr.Middleware(app)
	app = httpx.Chain(app,
		httpx.Recover(slog.New(slog.NewTextHandler(io.Discard, nil))),
		secheaders.Middleware(secheaders.Config{}),
		httpx.CORS(origins),
		httpx.NoStoreAPI(),
		httpx.OriginGuard(origins),
		httpx.MaxBody(10<<20),
	)
	st := &stack{t: t, srv: srv, db: db, fake: o.fake, http: httptest.NewServer(app), cookies: map[int64]string{}}
	t.Cleanup(st.http.Close)
	return st
}

// login starts a session for the user and returns the Cookie header value.
func (s *stack) login(userID int64) string {
	s.t.Helper()
	if c, ok := s.cookies[userID]; ok {
		return c
	}
	res, err := http.Get(s.http.URL + "/test-login?user=" + strconv.FormatInt(userID, 10))
	if err != nil {
		s.t.Fatal(err)
	}
	res.Body.Close()
	for _, c := range res.Cookies() {
		s.cookies[userID] = c.Name + "=" + c.Value
	}
	if s.cookies[userID] == "" {
		s.t.Fatal("no session cookie")
	}
	return s.cookies[userID]
}

func (s *stack) wsURL() string {
	return "ws" + strings.TrimPrefix(s.http.URL, "http") + "/socket.io/?EIO=4&transport=websocket"
}

// sql helpers
func (s *stack) rows(query string, args ...any) []map[string]any {
	s.t.Helper()
	out, err := queryRows(context.Background(), s.db.R, query, args...)
	if err != nil {
		s.t.Fatal(err)
	}
	return out
}

func (s *stack) exec(query string, args ...any) sql.Result {
	s.t.Helper()
	res, err := s.db.W.Exec(query, args...)
	if err != nil {
		s.t.Fatal(err)
	}
	return res
}

// tclient is a Socket.IO client written against the wire protocol.
type tclient struct {
	t      *testing.T
	ws     *websocket.Conn
	mu     sync.Mutex
	acks   map[int]chan []any
	events chan received
	closed chan struct{}
	conn   chan struct{}
	gone   chan struct{} // server sent a DISCONNECT packet
}

type received struct {
	name string
	args []any
	bins [][]byte
}

func (s *stack) connect(userID int64) *tclient {
	s.t.Helper()
	return s.connectWith(http.Header{"Cookie": {s.login(userID)}})
}

func (s *stack) connectWith(h http.Header) *tclient {
	s.t.Helper()
	ws, _, err := websocket.Dial(context.Background(), s.wsURL(), &websocket.DialOptions{HTTPHeader: h})
	if err != nil {
		s.t.Fatal(err)
	}
	c := &tclient{t: s.t, ws: ws, acks: map[int]chan []any{}, events: make(chan received, 256),
		closed: make(chan struct{}), conn: make(chan struct{}), gone: make(chan struct{})}
	s.t.Cleanup(func() { ws.CloseNow() })
	go c.readLoop()
	c.sendRaw("40")
	select {
	case <-c.conn:
	case <-time.After(3 * time.Second):
		s.t.Fatal("socket.io connect timed out")
	}
	return c
}

func (c *tclient) sendRaw(s string) {
	if err := c.ws.Write(context.Background(), websocket.MessageText, []byte(s)); err != nil {
		c.t.Helper()
		c.t.Fatal(err)
	}
}

func (c *tclient) readLoop() {
	defer close(c.closed)
	var pending *received
	var want int
	var pendingAck int
	for {
		typ, data, err := c.ws.Read(context.Background())
		if err != nil {
			return
		}
		if typ == websocket.MessageBinary {
			if pending != nil {
				pending.bins = append(pending.bins, data)
				if len(pending.bins) == want {
					c.events <- *pending
					pending = nil
				}
			}
			continue
		}
		s := string(data)
		switch s[0] {
		case '2':
			c.sendRaw("3")
		case '4':
			c.onSIO(s[1:], &pending, &want, &pendingAck)
		}
	}
}

func (c *tclient) onSIO(s string, pending **received, want, pendingAck *int) {
	switch s[0] {
	case '0':
		select {
		case <-c.conn:
		default:
			close(c.conn)
		}
	case '1':
		select {
		case <-c.gone:
		default:
			close(c.gone)
		}
	case '2', '5':
		rest := s[1:]
		attachments := 0
		if s[0] == '5' {
			i := strings.IndexByte(rest, '-')
			attachments, _ = strconv.Atoi(rest[:i])
			rest = rest[i+1:]
		}
		var args []any
		if err := json.Unmarshal([]byte(rest), &args); err != nil {
			c.t.Errorf("bad event %q: %v", s, err)
			return
		}
		r := received{name: args[0].(string), args: args[1:]}
		if attachments > 0 {
			*pending, *want = &r, attachments
			return
		}
		c.events <- r
	case '3':
		i := 1
		for i < len(s) && s[i] >= '0' && s[i] <= '9' {
			i++
		}
		id, _ := strconv.Atoi(s[1:i])
		var args []any
		_ = json.Unmarshal([]byte(s[i:]), &args)
		c.mu.Lock()
		ch := c.acks[id]
		delete(c.acks, id)
		c.mu.Unlock()
		if ch != nil {
			ch <- args
		}
	}
}

// emit sends an event; with ack it waits for the acknowledgement.
func (c *tclient) emit(name string, args ...any) {
	c.t.Helper()
	payload, err := json.Marshal(append([]any{name}, args...))
	if err != nil {
		c.t.Fatal(err)
	}
	c.sendRaw("42" + string(payload))
}

// next returns the next event, whatever it is.
func (c *tclient) next(timeout time.Duration) (received, bool) {
	select {
	case r := <-c.events:
		return r, true
	case <-time.After(timeout):
		return received{}, false
	}
}

// expect returns the arguments of the next event, which must have this name.
func (c *tclient) expect(name string) []any {
	c.t.Helper()
	r, ok := c.next(3 * time.Second)
	if !ok {
		c.t.Fatalf("timed out waiting for %q", name)
	}
	if r.name != name {
		c.t.Fatalf("got event %q %v, want %q", r.name, r.args, name)
	}
	return r.args
}

func (c *tclient) expectEvent(name string) received {
	c.t.Helper()
	r, ok := c.next(3 * time.Second)
	if !ok || r.name != name {
		c.t.Fatalf("got %+v ok=%v, want %q", r, ok, name)
	}
	return r
}

func (c *tclient) expectSilence(d time.Duration) {
	c.t.Helper()
	if r, ok := c.next(d); ok {
		c.t.Fatalf("unexpected event %q %v", r.name, r.args)
	}
}

func obj(v any) map[string]any {
	m, ok := v.(map[string]any)
	if !ok {
		panic(fmt.Sprintf("not an object: %#v", v))
	}
	return m
}
