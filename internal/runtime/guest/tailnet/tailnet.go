// Package tailnet is the guest side of the Tailscale integration: for each
// operation it starts a short-lived, outbound-only userspace tailscaled from
// the node state the server sends, runs the operation, and returns the
// updated state. Nothing about the node stays in the VM.
package tailnet

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"

	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guestproto"
)

const maxStateBytes = 1 << 20

var operationIDPattern = regexp.MustCompile(`^[a-f0-9]{48}$`)

// outboundPrefs keep the node outbound-only: no SSH, no routes, no DNS
// takeover, no exit node, and shields up against inbound connections.
var outboundPrefs = map[string]any{
	"WantRunning": true, "ShieldsUp": true, "RouteAll": false, "CorpDNS": false,
	"RunSSH": false, "AdvertiseRoutes": []any{}, "AdvertiseTags": []any{}, "ExitNodeID": "", "ExitNodeIP": "",
}

// Process is a running tailscaled.
type Process interface {
	Done() <-chan struct{}
	// Signal signals the process group.
	Signal(sig syscall.Signal)
}

// Spawner starts tailscaled for one operation.
type Spawner func(dir, socketPath, statePath string, login bool) (Process, error)

// Config wires a Service; zero values use the real binaries and paths.
type Config struct {
	Spawn         Spawner
	TemporaryRoot string
	// CallPeer runs a ping or HTTP request against a peer.
	CallPeer func(ctx context.Context, socketPath string, status map[string]any, op operation) (any, error)
}

// Service runs Tailscale operations, one client at a time.
type Service struct {
	cfg    Config
	queue  sync.Mutex
	mu     sync.Mutex
	active map[string]*activeOp
	logins map[string]*loginEntry
}

type activeOp struct {
	cancel  context.CancelCauseFunc
	done    chan struct{}
	started bool
}

type loginEntry struct {
	value   any
	expires *time.Timer
}

// New creates the service.
func New(cfg Config) *Service {
	if cfg.Spawn == nil {
		cfg.Spawn = spawnTailscaled
	}
	if cfg.TemporaryRoot == "" {
		cfg.TemporaryRoot = guestproto.VolatileDir
	}
	if cfg.CallPeer == nil {
		cfg.CallPeer = requestPeer
	}
	return &Service{cfg: cfg, active: map[string]*activeOp{}, logins: map[string]*loginEntry{}}
}

type execProcess struct {
	cmd  *exec.Cmd
	done chan struct{}
}

func (p *execProcess) Done() <-chan struct{} { return p.done }
func (p *execProcess) Signal(sig syscall.Signal) {
	if p.cmd.Process != nil {
		_ = syscall.Kill(-p.cmd.Process.Pid, sig)
	}
}

// spawnTailscaled starts the client under timeout(1), so the guest OS ends it
// even if the agent itself crashes.
func spawnTailscaled(dir, socketPath, statePath string, login bool) (Process, error) {
	limit := "50s"
	if login {
		limit = "310s"
	}
	cmd := exec.Command(guestproto.Timeout, "--signal=TERM", "--kill-after=2s", limit, guestproto.Tailscaled,
		"--tun=userspace-networking", "--port=0", "--socket="+socketPath,
		"--state="+statePath, "--statedir="+dir, "--no-logs-no-support")
	cmd.Dir = dir
	cmd.Env = []string{"HOME=" + dir, "TS_NO_LOGS_NO_SUPPORT=true"}
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	p := &execProcess{cmd: cmd, done: make(chan struct{})}
	go func() { _ = cmd.Wait(); close(p.done) }()
	return p, nil
}

// operation is a validated request from the server.
type operation struct {
	action, operationID, nodeID, state string
	target                             target
}

func validate(input map[string]any) (operation, error) {
	action, _ := input["action"].(string)
	switch action {
	case "login", "list", "request", "ping", "logout":
	default:
		return operation{}, errors.New("Invalid Tailscale operation.")
	}
	id, _ := input["operationId"].(string)
	if !operationIDPattern.MatchString(id) {
		return operation{}, errors.New("Invalid operation ID.")
	}
	op := operation{action: action, operationID: id}
	if action == "login" {
		if truthy(input["authKey"]) || truthy(input["state"]) || truthy(input["nodeId"]) {
			return operation{}, errors.New("Interactive login must create a new node.")
		}
		return op, nil
	}
	node, nodeOK := input["nodeId"].(string)
	state, stateOK := input["state"].(string)
	if truthy(input["authKey"]) || !nodeOK || node == "" || !stateOK || state == "" || float64(len([]rune(state))) > maxStateBytes*1.4 {
		return operation{}, errors.New("Node credentials are missing.")
	}
	op.nodeID, op.state = node, state
	if action == "request" || action == "ping" {
		args, _ := input["args"].(map[string]any)
		if args == nil {
			args = map[string]any{}
		}
		t, err := authorize(action, args, input["grants"])
		if err != nil {
			return operation{}, err
		}
		op.target = t
	}
	return op, nil
}

// decodeBase64 decodes like Node's Buffer.from(s, 'base64'): characters
// outside the alphabet and padding are skipped, a dangling character dropped.
func decodeBase64(s string) []byte {
	var b strings.Builder
	for _, r := range s {
		switch {
		case r >= 'A' && r <= 'Z', r >= 'a' && r <= 'z', r >= '0' && r <= '9', r == '+', r == '/':
			b.WriteRune(r)
		case r == '-':
			b.WriteByte('+')
		case r == '_':
			b.WriteByte('/')
		case r == '=':
			goto done
		}
	}
done:
	clean := b.String()
	if len(clean)%4 == 1 {
		clean = clean[:len(clean)-1]
	}
	out, _ := base64.RawStdEncoding.DecodeString(clean)
	return out
}

// Result is what an operation returns to the server.
type Result struct {
	Result  any     `json:"result,omitempty"`
	Error   string  `json:"error,omitempty"`
	NodeID  string  `json:"nodeId"`
	Tailnet string  `json:"tailnet"`
	State   *string `json:"state"`
}

// Run executes one operation.
func (s *Service) Run(ctx context.Context, input map[string]any, onLoginURL func(string)) (*Result, error) {
	op, err := validate(input)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	if _, busy := s.active[op.operationID]; busy {
		s.mu.Unlock()
		return nil, errors.New("Tailscale operation already running.")
	}
	limit := 45 * time.Second
	if op.action == "login" {
		limit = 300 * time.Second
	}
	opCtx, cancel := context.WithCancelCause(ctx)
	timed, stopTimer := context.WithTimeoutCause(opCtx, limit, errors.New("The operation was aborted due to timeout"))
	rec := &activeOp{cancel: cancel, done: make(chan struct{})}
	s.active[op.operationID] = rec
	s.mu.Unlock()
	defer func() {
		stopTimer()
		cancel(nil)
		close(rec.done)
		s.mu.Lock()
		delete(s.active, op.operationID)
		s.mu.Unlock()
	}()
	// One short-lived client per VM, even for concurrent agent connections.
	s.queue.Lock()
	defer s.queue.Unlock()
	if timed.Err() != nil {
		return nil, context.Cause(timed)
	}
	s.mu.Lock()
	rec.started = true
	s.mu.Unlock()
	result, err := s.runClient(timed, op, onLoginURL)
	if err != nil && timed.Err() != nil {
		return nil, context.Cause(timed)
	}
	return result, err
}

func (s *Service) runClient(ctx context.Context, op operation, onLoginURL func(string)) (*Result, error) {
	dir, err := os.MkdirTemp(s.cfg.TemporaryRoot, "neo-ts-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(dir)
	if err := os.Chmod(dir, 0o700); err != nil {
		return nil, err
	}
	socketPath, statePath := filepath.Join(dir, "api.sock"), filepath.Join(dir, "state")
	if op.state != "" {
		state := decodeBase64(op.state)
		if len(state) > maxStateBytes {
			return nil, errors.New("Tailscale node state exceeds limit.")
		}
		if err := os.WriteFile(statePath, state, 0o600); err != nil {
			return nil, err
		}
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	proc, err := s.cfg.Spawn(dir, socketPath, statePath, op.action == "login")
	if err != nil {
		return nil, errors.New("Tailscale client is unavailable in this VM. Update its guest runtime.")
	}
	killed := false
	kill := func() {
		if !killed {
			proc.Signal(syscall.SIGKILL)
			killed = true
		}
		<-proc.Done()
	}
	defer kill()
	stop := context.AfterFunc(ctx, func() { proc.Signal(syscall.SIGKILL) })
	defer stop()
	exited := func() bool {
		select {
		case <-proc.Done():
			return true
		default:
			return false
		}
	}
	pause := func(d time.Duration) error {
		select {
		case <-ctx.Done():
			return context.Cause(ctx)
		case <-time.After(d):
			return nil
		}
	}
	for {
		if err := ctx.Err(); err != nil {
			return nil, context.Cause(ctx)
		}
		if exited() {
			return nil, errors.New("Tailscale client stopped.")
		}
		if _, err := localRequest(ctx, socketPath, "GET", "status", nil); err == nil {
			break
		}
		if err := pause(50 * time.Millisecond); err != nil {
			return nil, err
		}
	}
	prefs := map[string]any{"Hostname": "neoagent"}
	for k, v := range outboundPrefs {
		prefs[k] = v
	}
	if _, err := localRequest(ctx, socketPath, "POST", "start", map[string]any{"UpdatePrefs": prefs}); err != nil {
		return nil, err
	}
	if op.action == "login" {
		if _, err := localRequest(ctx, socketPath, "POST", "login-interactive", nil); err != nil {
			return nil, err
		}
	}
	var status map[string]any
	var statusRaw []byte
	for {
		if err := ctx.Err(); err != nil {
			return nil, context.Cause(ctx)
		}
		if exited() {
			return nil, errors.New("Tailscale client stopped.")
		}
		if status, statusRaw, err = localRequestRaw(ctx, socketPath, "GET", "status", nil); err != nil {
			return nil, err
		}
		if status["BackendState"] == "Running" {
			break
		}
		if authURL, _ := status["AuthURL"].(string); op.action == "login" && authURL != "" {
			u, err := url.Parse(authURL)
			if err != nil || u.Scheme != "https" || u.Host != "login.tailscale.com" || u.User != nil {
				return nil, errors.New("Tailscale returned an invalid login URL.")
			}
			if onLoginURL != nil {
				onLoginURL(u.String())
			}
		}
		if err := pause(100 * time.Millisecond); err != nil {
			return nil, err
		}
	}
	self, _ := status["Self"].(map[string]any)
	tailnet, _ := status["CurrentTailnet"].(map[string]any)
	selfID, _ := self["ID"].(string)
	tailnetName, _ := tailnet["Name"].(string)
	if selfID == "" || tailnetName == "" {
		return nil, errors.New("Tailscale node identity is unavailable.")
	}
	if op.action != "login" && selfID != op.nodeID {
		return nil, errors.New("Node identity changed. Reconnect this integration account.")
	}
	current, err := localRequest(ctx, socketPath, "GET", "prefs", nil)
	if err != nil {
		return nil, err
	}
	if !truthy(current["ShieldsUp"]) || truthy(current["RunSSH"]) || truthy(current["RouteAll"]) || truthy(current["CorpDNS"]) || truthy(current["ExitNodeID"]) || truthy(current["ExitNodeIP"]) {
		return nil, errors.New("Tailscale outbound-only policy could not be enforced.")
	}
	out := &Result{NodeID: selfID, Tailnet: tailnetName}
	switch op.action {
	case "logout":
		if _, err := localRequest(ctx, socketPath, "POST", "logout", nil); err != nil {
			return nil, err
		}
		out.Result = map[string]bool{"disconnected": true}
	case "login":
		out.Result = map[string]bool{"connected": true}
	case "list":
		out.Result = map[string]any{"peers": peerList(statusRaw)}
	default:
		result, err := s.cfg.CallPeer(ctx, socketPath, status, op)
		if err != nil {
			if ctx.Err() != nil {
				return nil, context.Cause(ctx)
			}
			out.Error = err.Error()
		} else {
			out.Result = result
		}
	}
	proc.Signal(syscall.SIGTERM)
	select {
	case <-proc.Done():
	case <-time.After(2 * time.Second):
		kill()
	}
	if op.action == "logout" {
		return out, nil
	}
	state, err := os.ReadFile(statePath)
	if err != nil {
		return nil, err
	}
	if len(state) > maxStateBytes {
		return nil, errors.New("Tailscale node state exceeds limit.")
	}
	if len(state) > 0 {
		encoded := base64.StdEncoding.EncodeToString(state)
		out.State = &encoded
	}
	return out, nil
}

type peer struct {
	ID      any  `json:"id"`
	Name    any  `json:"name"`
	DNSName any  `json:"dnsName"`
	Online  bool `json:"online"`
}

// peerList lists the peers in the order of the status JSON's Peer object.
func peerList(statusRaw []byte) []peer {
	var top struct {
		Peer json.RawMessage `json:"Peer"`
	}
	out := []peer{}
	if json.Unmarshal(statusRaw, &top) != nil || len(top.Peer) == 0 {
		return out
	}
	dec := json.NewDecoder(bytes.NewReader(top.Peer))
	if tok, err := dec.Token(); err != nil || tok != json.Delim('{') {
		return out
	}
	for dec.More() {
		if _, err := dec.Token(); err != nil {
			return out
		}
		var p map[string]any
		if err := dec.Decode(&p); err != nil {
			return out
		}
		out = append(out, peer{ID: p["ID"], Name: p["HostName"], DNSName: p["DNSName"], Online: p["Online"] == true})
	}
	return out
}

// BeginLogin starts an interactive login and answers with the sign-in URL as
// soon as tailscaled offers one (or with the connected node).
func (s *Service) BeginLogin(ctx context.Context, input map[string]any) (any, error) {
	if _, err := validate(input); err != nil {
		return nil, err
	}
	id, _ := input["operationId"].(string)
	s.setLogin(id, map[string]any{"status": "connecting"}, false)
	first := make(chan any, 1)
	failed := make(chan struct{})
	var once sync.Once
	go func() {
		// The login outlives the request that started it.
		result, err := s.Run(context.WithoutCancel(ctx), input, func(loginURL string) {
			once.Do(func() { first <- map[string]any{"status": "connecting", "loginUrl": loginURL} })
		})
		if err != nil {
			s.setLogin(id, map[string]any{"status": "failed", "error": "Tailscale sign-in ended. Please connect again."}, true)
			once.Do(func() { close(failed) })
			return
		}
		value := struct {
			Status  string  `json:"status"`
			Result  any     `json:"result,omitempty"`
			NodeID  string  `json:"nodeId"`
			Tailnet string  `json:"tailnet"`
			State   *string `json:"state"`
		}{"connected", result.Result, result.NodeID, result.Tailnet, result.State}
		s.setLogin(id, value, true)
		once.Do(func() { first <- map[string]any{"status": "connected"} })
	}()
	select {
	case v := <-first:
		return v, nil
	case <-failed:
		return nil, errors.New("Tailscale sign-in could not start. Please connect again.")
	}
}

func (s *Service) setLogin(id string, value any, expire bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	entry := s.logins[id]
	if entry == nil {
		entry = &loginEntry{}
		s.logins[id] = entry
	}
	entry.value = value
	if expire && entry.expires == nil {
		entry.expires = time.AfterFunc(5*time.Minute, func() {
			s.mu.Lock()
			if s.logins[id] == entry {
				delete(s.logins, id)
			}
			s.mu.Unlock()
		})
	}
}

// LoginStatus reports an interactive login.
func (s *Service) LoginStatus(id string) any {
	s.mu.Lock()
	defer s.mu.Unlock()
	if entry := s.logins[id]; entry != nil {
		return entry.value
	}
	return map[string]any{"status": "failed", "error": "Tailscale sign-in expired. Please connect again."}
}

// Cancel stops an operation and forgets its login.
func (s *Service) Cancel(id string) {
	s.mu.Lock()
	rec := s.active[id]
	started := rec != nil && rec.started
	if entry := s.logins[id]; entry != nil {
		if entry.expires != nil {
			entry.expires.Stop()
		}
		delete(s.logins, id)
	}
	s.mu.Unlock()
	if rec != nil {
		rec.cancel(errors.New("Tailscale operation canceled."))
		if started {
			<-rec.done
		}
	}
}

// Shutdown cancels every operation.
func (s *Service) Shutdown() {
	s.mu.Lock()
	ids := make([]string, 0, len(s.active))
	for id := range s.active {
		ids = append(ids, id)
	}
	s.mu.Unlock()
	for _, id := range ids {
		s.Cancel(id)
	}
	s.mu.Lock()
	s.logins = map[string]*loginEntry{}
	s.mu.Unlock()
}

// Mount registers the /integrations/tailscale endpoints; handle adds the
// guest's bearer token check.
func Mount(handle func(pattern string, h http.Handler), s *Service) {
	reply := func(w http.ResponseWriter, r *http.Request, v any, err error) {
		if err != nil {
			status := http.StatusInternalServerError
			if r.Context().Err() != nil {
				status = 499
			}
			httpx.WriteJSON(w, status, map[string]any{"error": err.Error()})
			return
		}
		httpx.WriteJSON(w, http.StatusOK, v)
	}
	handle("POST /integrations/tailscale", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body := map[string]any{}
		if strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
			raw, _ := io.ReadAll(io.LimitReader(r.Body, 10<<20))
			_ = json.Unmarshal(raw, &body)
			if body == nil {
				body = map[string]any{}
			}
		}
		if body["action"] == "login" {
			v, err := s.BeginLogin(r.Context(), body)
			reply(w, r, v, err)
			return
		}
		v, err := s.Run(r.Context(), body, nil)
		reply(w, r, v, err)
	}))
	handle("GET /integrations/tailscale/{operationId}/login-status", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		httpx.WriteJSON(w, http.StatusOK, s.LoginStatus(r.PathValue("operationId")))
	}))
	handle("POST /integrations/tailscale/{operationId}/cancel", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		s.Cancel(r.PathValue("operationId"))
		httpx.WriteJSON(w, http.StatusOK, map[string]bool{"canceled": true})
	}))
}
