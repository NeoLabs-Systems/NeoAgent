package mcpserver

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/mcp"
	"github.com/modelcontextprotocol/go-sdk/auth"
)

// Session is what the manager needs of a connection; mcp.Session satisfies it.
type Session interface {
	Tools(ctx context.Context) ([]map[string]any, error)
	Call(ctx context.Context, name string, args map[string]any) (map[string]any, error)
	Close() error
}

// StatusEvent is emitted whenever a server changes state (Node's
// "server_status" event). A stopped server carries only ServerID and Status.
type StatusEvent struct {
	ServerID         int64
	ServerName       string
	UserID           int64
	AgentID          string
	PreviousStatus   string
	ChangedAt        string
	Status           string
	Error            string
	ConsecutiveFails int
	NextRetryAt      string
}

// ManagerConfig wires the manager.
type ManagerConfig struct {
	Store *Store
	Log   *slog.Logger
	// HTTPClient carries every request to MCP servers and their OAuth
	// endpoints. Nil uses the ssrf client, which refuses private addresses.
	HTTPClient *http.Client
	// RedirectURL is the OAuth callback: PUBLIC_URL (or localhost:PORT) plus
	// /api/mcp/oauth/callback.
	RedirectURL string
	// OnStatus receives status events; nil ignores them.
	OnStatus func(StatusEvent)
	// Connect opens a session; nil uses mcp.Connect. Tests replace it.
	Connect func(ctx context.Context, c mcp.Config) (Session, error)

	ReconnectDelay    time.Duration // default 1 minute
	MaxReconnectDelay time.Duration // default 15 minutes
	OperationTimeout  time.Duration // default 30 seconds
	ToolFailureLimit  int           // consecutive failures before reconnecting, default 3
	OAuthTimeout      time.Duration // how long a browser sign-in may take, default 10 minutes
}

type server struct {
	id        int64
	userID    int64
	agentID   string
	url       string
	slug      string
	name      string
	sess      Session
	cancel    context.CancelFunc
	flow      *oauthFlow
	tools     []map[string]any
	status    string
	fails     int
	lastError string
	nextRetry string
}

// Manager keeps the live connections to MCP servers.
type Manager struct {
	store       *Store
	log         *slog.Logger
	httpClient  *http.Client
	redirectURL string
	onStatus    func(StatusEvent)
	connect     func(ctx context.Context, c mcp.Config) (Session, error)

	reconnectDelay, maxReconnectDelay, opTimeout, oauthTimeout time.Duration
	failureLimit                                               int

	base     context.Context
	stopBase context.CancelFunc

	mu       sync.Mutex
	servers  map[int64]*server
	timers   map[int64]*time.Timer
	attempts map[int64]int
	versions map[int64]int
	shutting bool
}

// NewManager builds a manager.
func NewManager(cfg ManagerConfig) *Manager {
	def := func(d *time.Duration, v time.Duration) {
		if *d == 0 {
			*d = v
		}
	}
	def(&cfg.ReconnectDelay, time.Minute)
	def(&cfg.MaxReconnectDelay, 15*time.Minute)
	def(&cfg.OperationTimeout, 30*time.Second)
	def(&cfg.OAuthTimeout, 10*time.Minute)
	if cfg.ToolFailureLimit == 0 {
		cfg.ToolFailureLimit = 3
	}
	if cfg.Log == nil {
		cfg.Log = slog.Default()
	}
	if cfg.HTTPClient == nil {
		cfg.HTTPClient = mcp.DefaultHTTPClient()
	}
	if cfg.Connect == nil {
		cfg.Connect = func(ctx context.Context, c mcp.Config) (Session, error) { return mcp.Connect(ctx, c) }
	}
	base, stop := context.WithCancel(context.Background())
	return &Manager{
		store: cfg.Store, log: cfg.Log, httpClient: cfg.HTTPClient, redirectURL: cfg.RedirectURL,
		onStatus: cfg.OnStatus, connect: cfg.Connect,
		reconnectDelay: cfg.ReconnectDelay, maxReconnectDelay: cfg.MaxReconnectDelay,
		opTimeout: cfg.OperationTimeout, oauthTimeout: cfg.OAuthTimeout, failureLimit: cfg.ToolFailureLimit,
		base: base, stopBase: stop,
		servers: map[int64]*server{}, timers: map[int64]*time.Timer{},
		attempts: map[int64]int{}, versions: map[int64]int{},
	}
}

// StartResult is what starting a server reports.
type StartResult struct {
	Status string
	Tools  []map[string]any
}

// OAuthRedirect is returned by Start when the server needs the user to sign in.
type OAuthRedirect struct{ URL string }

func (e *OAuthRedirect) Error() string { return oauthRedirect + e.URL }

var errSuperseded = errors.New("start was superseded")

func (m *Manager) nextVersion(id int64) int {
	m.versions[id]++
	return m.versions[id]
}

func (m *Manager) cancelReconnectLocked(id int64) {
	if t := m.timers[id]; t != nil {
		t.Stop()
		delete(m.timers, id)
	}
}

func (m *Manager) emit(ev StatusEvent) {
	if m.onStatus != nil {
		m.onStatus(ev)
	}
}

// setStatus records and announces a state change.
func (m *Manager) setStatus(s *server, status string) {
	m.mu.Lock()
	prev := s.status
	s.status = status
	ev := StatusEvent{
		ServerID: s.id, ServerName: s.name, UserID: s.userID, AgentID: s.agentID, PreviousStatus: prev,
		ChangedAt: isoNow(), Status: status, Error: s.lastError, ConsecutiveFails: s.fails, NextRetryAt: s.nextRetry,
	}
	m.mu.Unlock()
	if err := m.store.setStatus(context.Background(), s.id, status); err != nil {
		m.log.Error("persisting MCP status failed", "server", s.id, "error", err)
	}
	m.emit(ev)
}

func (m *Manager) closeSession(s *server) {
	if s == nil {
		return
	}
	m.mu.Lock()
	sess, cancel := s.sess, s.cancel
	s.sess = nil
	m.mu.Unlock()
	if sess != nil {
		done := make(chan error, 1)
		go func() { done <- sess.Close() }()
		select {
		case err := <-done:
			if err != nil {
				m.log.Error("closing MCP client failed", "server", s.id, "error", errorMessage(err))
			}
		case <-time.After(m.opTimeout):
			m.log.Error("closing MCP client timed out", "server", s.id)
		}
	}
	if cancel != nil {
		cancel()
	}
}

func (m *Manager) recordFailure(s *server, err error, requiresAuth bool) string {
	msg := errorMessage(err)
	m.mu.Lock()
	m.attempts[s.id]++
	s.fails = m.attempts[s.id]
	s.lastError = msg
	s.nextRetry = ""
	m.mu.Unlock()
	if requiresAuth {
		m.setStatus(s, "auth_required")
	} else {
		m.setStatus(s, "error")
	}
	return msg
}

func (m *Manager) isCurrent(id int64, s *server, version int) bool {
	return !m.shutting && m.versions[id] == version && m.servers[id] == s
}

func (m *Manager) timeoutErr(label string) error {
	return fmt.Errorf("%s timed out after %d ms", label, m.opTimeout.Milliseconds())
}

// withTimeout runs fn with a context that ends after the operation timeout.
func (m *Manager) withTimeout(label string, fn func(ctx context.Context) error) error {
	ctx, cancel := context.WithTimeout(m.base, m.opTimeout)
	defer cancel()
	err := fn(ctx)
	if err != nil && errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return m.timeoutErr(label)
	}
	return err
}

type dialResult struct {
	sess Session
	err  error
}

// transportConfig reads the server's config into a connection config.
func (m *Manager) transportConfig(ctx context.Context, id int64, endpoint string) (mcp.Config, map[string]any, error) {
	cfg, err := m.store.ServerConfig(ctx, id)
	if err != nil {
		return mcp.Config{}, nil, err
	}
	c := mcp.Config{Endpoint: endpoint, Transport: mcp.SSE, HTTPClient: m.httpClient, Name: "NeoAgent", Version: "1.0.0", Headers: map[string]string{}}
	if cfg["transport"] == "streamable-http" {
		c.Transport = mcp.StreamableHTTP
	}
	if headers, _ := cfg["headers"].(map[string]any); headers != nil {
		for k, v := range headers {
			if s, _ := v.(string); s != "" {
				c.Headers[k] = s
			}
		}
	}
	if a, _ := cfg["auth"].(map[string]any); a != nil && a["type"] == "bearer" {
		if tok, _ := a["token"].(string); tok != "" {
			c.Headers["Authorization"] = "Bearer " + tok
		}
	}
	return c, cfg, nil
}

// Start connects a server and lists its tools. When the server needs OAuth it
// returns *OAuthRedirect and the connection waits for the callback.
func (m *Manager) Start(ctx context.Context, id int64, endpoint, name string, userID int64, agentID string) (StartResult, error) {
	return m.start(ctx, id, endpoint, name, userID, agentID, false)
}

func (m *Manager) start(ctx context.Context, id int64, endpoint, name string, userID int64, agentID string, reconnect bool) (StartResult, error) {
	m.mu.Lock()
	if m.shutting {
		m.mu.Unlock()
		return StartResult{}, errors.New("MCP client is shutting down")
	}
	if !reconnect {
		m.cancelReconnectLocked(id)
		delete(m.attempts, id)
	}
	previous := m.servers[id]
	version := m.nextVersion(id)
	m.mu.Unlock()
	m.closeSession(previous)

	fail := func(s *server, err error, requiresAuth bool) (StartResult, error) {
		m.mu.Lock()
		current := m.servers[id] == s
		m.mu.Unlock()
		if !current {
			return StartResult{}, err
		}
		msg := m.recordFailure(s, err, requiresAuth)
		if !requiresAuth {
			m.closeSession(s)
		}
		return StartResult{}, errors.New(msg)
	}

	endpoint, err := ValidateEndpoint(endpoint)
	if err != nil {
		return m.failPrevious(id, previous, err)
	}
	tcfg, rawCfg, err := m.transportConfig(ctx, id, endpoint)
	if err != nil {
		return m.failPrevious(id, previous, err)
	}
	var flow *oauthFlow
	var handler *auth.AuthorizationCodeHandler
	if a, _ := rawCfg["auth"].(map[string]any); a != nil && a["type"] == "oauth" {
		flow = newFlow()
		if handler, err = m.oauthHandler(id, rawCfg, flow); err != nil {
			return m.failPrevious(id, previous, err)
		}
		tcfg.OAuth = handler
	}

	display := name
	if display == "" {
		display = fmt.Sprint(id)
	}
	connCtx, cancel := context.WithCancel(m.base)
	m.mu.Lock()
	s := &server{
		id: id, userID: userID, agentID: agentID, url: endpoint, slug: slugFor(name, id), name: display,
		cancel: cancel, flow: flow, status: "starting", fails: m.attempts[id],
	}
	m.servers[id] = s
	m.mu.Unlock()
	m.setStatus(s, "starting")

	deadline := m.opTimeout
	if flow != nil {
		deadline = m.oauthTimeout
	}
	dialCtx, stopDial := context.WithTimeout(connCtx, deadline)
	results := make(chan dialResult, 1)
	go func() {
		sess, err := m.connect(dialCtx, tcfg)
		stopDial()
		results <- dialResult{sess, err}
	}()

	finishOAuth := func() {
		r := <-results
		var err error
		if r.err != nil {
			_, err = fail(s, r.err, false)
		} else {
			_, err = m.activate(s, r.sess, handler, version)
		}
		flow.finish(err)
	}

	var wait <-chan time.Time = time.After(m.opTimeout)
	var urls <-chan string
	if flow != nil {
		urls = flow.urlCh
	}
	select {
	case r := <-results:
		if r.err != nil {
			return fail(s, r.err, false)
		}
		return m.activate(s, r.sess, handler, version)
	case u := <-urls:
		go finishOAuth()
		_, err := fail(s, &OAuthRedirect{URL: u}, true)
		return StartResult{}, err
	case <-wait:
		cancel()
		return fail(s, m.timeoutErr(fmt.Sprintf("Connecting to MCP server %q", s.name)), false)
	}
}

// failPrevious reports a failure before a new connection object existed: the
// previous one, if still registered, takes the blame.
func (m *Manager) failPrevious(id int64, previous *server, err error) (StartResult, error) {
	m.mu.Lock()
	current := previous != nil && m.servers[id] == previous
	m.mu.Unlock()
	if current {
		return StartResult{}, errors.New(m.recordFailure(previous, err, false))
	}
	return StartResult{}, err
}

// activate lists the tools of a fresh connection and marks the server running.
func (m *Manager) activate(s *server, sess Session, handler *auth.AuthorizationCodeHandler, version int) (StartResult, error) {
	m.mu.Lock()
	s.sess = sess
	m.mu.Unlock()
	var tools []map[string]any
	err := m.withTimeout(fmt.Sprintf("Discovering tools from MCP server %q", s.name), func(ctx context.Context) (e error) {
		tools, e = sess.Tools(ctx)
		return e
	})
	m.mu.Lock()
	current := m.isCurrent(s.id, s, version)
	m.mu.Unlock()
	if !current {
		m.closeSession(s)
		return StartResult{}, errSuperseded
	}
	if err != nil {
		msg := m.recordFailure(s, err, false)
		m.closeSession(s)
		return StartResult{}, errors.New(msg)
	}
	if handler != nil {
		m.persistTokens(context.Background(), s.id, handler)
	}
	m.mu.Lock()
	s.tools = tools
	s.fails, s.lastError, s.nextRetry = 0, "", ""
	delete(m.attempts, s.id)
	m.mu.Unlock()
	m.setStatus(s, "running")
	return StartResult{Status: "running", Tools: tools}, nil
}

// Stop closes a server and forgets its connection.
func (m *Manager) Stop(id int64) {
	m.mu.Lock()
	m.cancelReconnectLocked(id)
	delete(m.attempts, id)
	m.nextVersion(id)
	s := m.servers[id]
	m.mu.Unlock()
	if s == nil {
		if err := m.store.setStatus(context.Background(), id, "stopped"); err != nil {
			m.log.Error("persisting MCP status failed", "server", id, "error", err)
		}
		return
	}
	m.closeSession(s)
	m.mu.Lock()
	delete(m.servers, id)
	m.mu.Unlock()
	if err := m.store.setStatus(context.Background(), id, "stopped"); err != nil {
		m.log.Error("persisting MCP status failed", "server", id, "error", err)
	}
	m.emit(StatusEvent{ServerID: id, Status: "stopped"})
}

// IsLive reports whether the manager holds a connection object for the server.
func (m *Manager) IsLive(id int64) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.servers[id] != nil
}

func (m *Manager) owned(id, userID int64) *server {
	s := m.servers[id]
	if s == nil || (userID != 0 && s.userID != userID) {
		return nil
	}
	return s
}

// ListTools asks a running server for its tools afresh.
func (m *Manager) ListTools(id, userID int64) ([]map[string]any, error) {
	m.mu.Lock()
	s := m.owned(id, userID)
	var sess Session
	if s != nil && s.status == "running" {
		sess = s.sess
	}
	m.mu.Unlock()
	if sess == nil {
		return nil, fmt.Errorf("Server %d not running", id)
	}
	var tools []map[string]any
	err := m.withTimeout(fmt.Sprintf("Discovering tools from MCP server %q", s.name), func(ctx context.Context) (e error) {
		tools, e = sess.Tools(ctx)
		return e
	})
	if err != nil {
		msg := m.recordFailure(s, err, false)
		m.scheduleReconnect(id, s.userID, s.agentID)
		return nil, fmt.Errorf("Failed to list tools for MCP server %q: %s", s.name, msg)
	}
	m.mu.Lock()
	s.tools = tools
	s.fails, s.lastError = 0, ""
	delete(m.attempts, id)
	m.mu.Unlock()
	return tools, nil
}

// CallTool runs a tool of a server. userID 0 skips the ownership check.
func (m *Manager) CallTool(id int64, tool string, args map[string]any, userID int64) (map[string]any, error) {
	m.mu.Lock()
	s := m.owned(id, userID)
	if s == nil {
		m.mu.Unlock()
		return nil, fmt.Errorf("Server %d not found", id)
	}
	if s.status != "running" {
		hint := ""
		if s.lastError != "" {
			hint = " (" + s.lastError + ")"
		}
		name := s.name
		m.mu.Unlock()
		return nil, fmt.Errorf("MCP server %q is not available%s", name, hint)
	}
	sess := s.sess
	m.mu.Unlock()
	if args == nil {
		args = map[string]any{}
	}
	var result map[string]any
	err := m.withTimeout(fmt.Sprintf("Calling MCP tool %q on %q", tool, s.name), func(ctx context.Context) (e error) {
		result, e = sess.Call(ctx, tool, args)
		return e
	})
	if err == nil {
		m.mu.Lock()
		s.fails, s.lastError = 0, ""
		delete(m.attempts, id)
		m.mu.Unlock()
		return result, nil
	}
	msg := errorMessage(err)
	m.mu.Lock()
	s.fails++
	s.lastError = msg
	tripped := s.fails >= m.failureLimit
	if tripped {
		m.attempts[id] = s.fails
		s.nextRetry = ""
	}
	m.mu.Unlock()
	if tripped {
		m.setStatus(s, "error")
		m.scheduleReconnect(id, s.userID, s.agentID)
	}
	return nil, fmt.Errorf("MCP tool %q failed: %s", tool, msg)
}

// CallToolByName runs a tool by its agent-facing name (mcp_<slug>_<tool>). It
// returns found=false when no running server of the account owns that name.
func (m *Manager) CallToolByName(fullName string, args map[string]any, userID int64, agentID string) (result map[string]any, found bool, err error) {
	m.mu.Lock()
	var id int64
	var tool string
	for sid, s := range m.servers {
		if userID != 0 && s.userID != userID {
			continue
		}
		if agentID != "" && s.agentID != "" && s.agentID != agentID {
			continue
		}
		if prefix := "mcp_" + s.slug + "_"; strings.HasPrefix(fullName, prefix) {
			id, tool, found = sid, strings.TrimPrefix(fullName, prefix), true
			break
		}
	}
	m.mu.Unlock()
	if !found {
		return nil, false, nil
	}
	result, err = m.CallTool(id, tool, args, userID)
	return result, true, err
}

// AllTools lists the tools of every running server of the account under the
// names agents use, each tool carrying originalName, parameters and serverId.
func (m *Manager) AllTools(userID int64, agentID string) []map[string]any {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := []map[string]any{}
	for id, s := range m.servers {
		if userID != 0 && s.userID != userID {
			continue
		}
		if agentID != "" && s.agentID != "" && s.agentID != agentID {
			continue
		}
		if s.status != "running" {
			continue
		}
		for _, tool := range s.tools {
			original, _ := tool["name"].(string)
			original = strings.TrimSpace(original)
			if original == "" {
				continue
			}
			t := make(map[string]any, len(tool)+3)
			for k, v := range tool {
				t[k] = v
			}
			t["name"] = "mcp_" + s.slug + "_" + original
			t["originalName"] = original
			if schema, ok := tool["inputSchema"]; ok && schema != nil {
				t["parameters"] = schema
			}
			t["serverId"] = id
			out = append(out, t)
		}
	}
	return out
}

// LiveStatus is the state of one connected server.
type LiveStatus struct {
	Status           string
	ToolCount        int
	Error            string
	ConsecutiveFails int
	NextRetryAt      string
}

// Status lists the connected servers of an account (all accounts when userID is
// 0), optionally only those of one agent.
func (m *Manager) Status(userID int64, agentID string) map[int64]LiveStatus {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := map[int64]LiveStatus{}
	for id, s := range m.servers {
		if userID != 0 && s.userID != userID {
			continue
		}
		if agentID != "" && s.agentID != "" && s.agentID != agentID {
			continue
		}
		out[id] = LiveStatus{Status: s.status, ToolCount: len(s.tools), Error: s.lastError, ConsecutiveFails: s.fails, NextRetryAt: s.nextRetry}
	}
	return out
}

func (m *Manager) scheduleReconnect(id, userID int64, agentID string) {
	m.mu.Lock()
	if m.shutting || m.timers[id] != nil {
		m.mu.Unlock()
		return
	}
	s := m.servers[id]
	if s == nil || s.status == "auth_required" {
		m.mu.Unlock()
		return
	}
	attempts := max(1, m.attempts[id])
	delay := min(m.reconnectDelay<<min(attempts-1, 20), m.maxReconnectDelay)
	if delay <= 0 {
		delay = m.maxReconnectDelay
	}
	s.nextRetry = time.Now().Add(delay).UTC().Format("2006-01-02T15:04:05.000Z")
	m.mu.Unlock()
	m.setStatus(s, "reconnecting")

	timer := time.AfterFunc(delay, func() { m.reconnect(id, userID, agentID) })
	m.mu.Lock()
	if m.shutting {
		timer.Stop()
	} else {
		m.timers[id] = timer
	}
	m.mu.Unlock()
}

func (m *Manager) reconnect(id, userID int64, agentID string) {
	m.mu.Lock()
	delete(m.timers, id)
	cur := m.servers[id]
	running := cur != nil && cur.status == "running"
	m.mu.Unlock()
	if m.base.Err() != nil || cur == nil || running {
		return
	}
	row, ok, err := m.store.enabledRow(context.Background(), id)
	if err != nil {
		m.log.Error("MCP reconnect lookup failed", "server", id, "error", err)
		return
	}
	if !ok {
		m.Stop(id)
		return
	}
	if _, err := m.start(context.Background(), id, row.Command, row.Name, userID, agentID, true); err != nil {
		m.mu.Lock()
		failed := m.servers[id]
		retry := failed != nil && failed.status != "auth_required" && !m.shutting
		m.mu.Unlock()
		if retry {
			m.scheduleReconnect(id, userID, agentID)
		}
		return
	}
	m.log.Info("MCP reconnected", "server", row.Name)
}

// LoadResult is the outcome of starting one stored server.
type LoadResult struct {
	ID     int64
	Name   string
	Status string
	Error  string
}

// LoadFromDB starts every enabled server of an account, scheduling a retry for
// those that fail.
func (m *Manager) LoadFromDB(ctx context.Context, userID int64) ([]LoadResult, error) {
	rows, err := m.store.Enabled(ctx, userID)
	if err != nil {
		return nil, err
	}
	var results []LoadResult
	for _, row := range rows {
		if _, err := m.Start(ctx, row.ID, row.Command, row.Name, userID, row.AgentID); err != nil {
			m.log.Error("MCP server failed to start", "name", row.Name, "error", err)
			m.mu.Lock()
			s := m.servers[row.ID]
			status := "error"
			retry := false
			if s != nil {
				status = s.status
				retry = s.status != "auth_required"
			}
			m.mu.Unlock()
			if retry {
				m.scheduleReconnect(row.ID, userID, row.AgentID)
			}
			results = append(results, LoadResult{ID: row.ID, Name: row.Name, Status: status, Error: err.Error()})
			continue
		}
		results = append(results, LoadResult{ID: row.ID, Name: row.Name, Status: "running"})
	}
	return results, nil
}

// Shutdown stops every connection and any pending reconnect.
func (m *Manager) Shutdown() {
	m.mu.Lock()
	m.shutting = true
	for id := range m.timers {
		m.cancelReconnectLocked(id)
	}
	ids := make([]int64, 0, len(m.servers))
	for id := range m.servers {
		ids = append(ids, id)
	}
	m.mu.Unlock()
	var wg sync.WaitGroup
	for _, id := range ids {
		wg.Add(1)
		go func() { defer wg.Done(); m.Stop(id) }()
	}
	wg.Wait()
	m.stopBase()
}
