package tailscale

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
)

// ComputerRequest bounds one request to the user's cloud computer. Requests
// are never retried: a repeated login or HTTP call could act twice.
type ComputerRequest struct {
	Timeout          time.Duration
	MaxResponseBytes int64
}

// Computer reaches the guest agent of a user's isolated cloud computer, which
// runs the Tailscale node.
type Computer interface {
	// Isolated reports whether computers are per-user QEMU or Docker
	// machines; host and local computer modes cannot run a node.
	Isolated() bool
	Request(ctx context.Context, userID int64, method, path string, body any, o ComputerRequest) (map[string]any, error)
}

var errNoComputer = errors.New("Tailscale requires an isolated per-user QEMU or Docker computer runtime. Host and local computer modes are not supported.")

// nodeCredentials are a node's identity and its state blob.
type nodeCredentials struct {
	NodeID string `json:"nodeId"`
	State  string `json:"state"`
}

func assertNodeCredentials(v map[string]any) (nodeCredentials, error) {
	id, _ := v["nodeId"].(string)
	state, _ := v["state"].(string)
	if id == "" || state == "" || len(state) > 1500000 {
		return nodeCredentials{}, errors.New("Tailscale node credentials are missing. Reconnect this integration account.")
	}
	return nodeCredentials{NodeID: id, State: state}, nil
}

func connectionScope(conn integrations.Connection) string {
	return fmt.Sprintf("%d:%s:%d", conn.UserID, conn.AgentID, conn.ID)
}

func operationID() string {
	b := make([]byte, 24)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// runtime runs node operations in the user's computer and tracks them, so a
// disconnect can stop every operation of a connection.
type runtime struct {
	computer func() Computer
	svc      *integrations.Services

	mu       sync.Mutex
	active   map[string]*activeCall
	stopping bool
}

type activeCall struct {
	userID int64
	scope  string
	cancel context.CancelCauseFunc
	done   chan struct{}
}

func (r *runtime) require() (Computer, error) {
	c := r.computer()
	if c == nil || !c.Isolated() {
		return nil, errNoComputer
	}
	return c, nil
}

func (r *runtime) cancelRemote(c Computer, userID int64, opID string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_, err := c.Request(ctx, userID, "POST", "/integrations/tailscale/"+opID+"/cancel", map[string]any{}, ComputerRequest{Timeout: 10 * time.Second})
	return err
}

// call runs one operation; an aborted call terminates the client inside the
// guest with a fresh context, so the abort cannot skip that.
func (r *runtime) call(ctx context.Context, userID int64, scope string, payload map[string]any, opID string) (map[string]any, error) {
	r.mu.Lock()
	if r.stopping {
		r.mu.Unlock()
		return nil, errors.New("Tailscale integration is stopping.")
	}
	r.mu.Unlock()
	c, err := r.require()
	if err != nil {
		return nil, err
	}
	if err := ctx.Err(); err != nil {
		return nil, context.Cause(ctx)
	}
	if opID == "" {
		opID = operationID()
	}
	callCtx, cancel := context.WithCancelCause(ctx)
	rec := &activeCall{userID: userID, scope: scope, cancel: cancel, done: make(chan struct{})}
	r.mu.Lock()
	if r.active == nil {
		r.active = map[string]*activeCall{}
	}
	r.active[opID] = rec
	r.mu.Unlock()
	body := map[string]any{}
	for k, v := range payload {
		body[k] = v
	}
	body["operationId"] = opID
	response, err := c.Request(callCtx, userID, "POST", "/integrations/tailscale", body, ComputerRequest{Timeout: 60 * time.Second, MaxResponseBytes: 3 << 20})
	aborted := callCtx.Err() != nil
	close(rec.done)
	defer func() {
		r.mu.Lock()
		delete(r.active, opID)
		r.mu.Unlock()
		cancel(nil)
	}()
	if aborted {
		if cerr := r.cancelRemote(c, userID, opID); cerr != nil && err == nil {
			err = cerr
		}
	}
	if err != nil {
		if aborted {
			return nil, context.Cause(callCtx)
		}
		return nil, err
	}
	if response == nil {
		return nil, errors.New("Invalid Tailscale runtime response.")
	}
	return response, nil
}

func (r *runtime) loginStatus(ctx context.Context, userID int64, opID string) (map[string]any, error) {
	c, err := r.require()
	if err != nil {
		return nil, err
	}
	return c.Request(ctx, userID, "GET", "/integrations/tailscale/"+opID+"/login-status", nil, ComputerRequest{Timeout: 10 * time.Second, MaxResponseBytes: 2 << 20})
}

func (r *runtime) cancelLogin(userID int64, opID string) error {
	c, err := r.require()
	if err != nil {
		return err
	}
	return r.cancelRemote(c, userID, opID)
}

// execute runs a tool on a connection, re-reading it first so disconnects
// and policy changes also apply to queued calls.
func (r *runtime) execute(ctx context.Context, conn integrations.Connection, action string, args map[string]any) (any, error) {
	current, err := r.svc.ConnectionByID(ctx, conn.UserID, conn.ID, conn.AgentID)
	if err != nil {
		return nil, err
	}
	if current == nil || current.ProviderKey != providerKey || current.Status != "connected" {
		return nil, errors.New("Tailscale connection is no longer available.")
	}
	if action == "request" && integrations.AccessMode(current) == integrations.AccessReadOnly {
		return nil, errors.New("Tailscale HTTP operations require read/write access.")
	}
	creds, err := assertNodeCredentials(r.svc.Credentials(*current))
	if err != nil {
		return nil, err
	}
	var grants []Service
	if action != "list" {
		op, err := authorizeRequest(*current, action, args)
		if err != nil {
			return nil, err
		}
		grants = op.grants
	}
	if grants == nil {
		grants = []Service{}
	}
	if args == nil {
		args = map[string]any{}
	}
	response, err := r.call(ctx, current.UserID, connectionScope(*current), map[string]any{
		"action": action, "state": creds.State, "nodeId": creds.NodeID, "args": args, "grants": grants,
	}, "")
	if err != nil {
		return nil, err
	}
	next, err := assertNodeCredentials(response)
	if err != nil {
		return nil, err
	}
	if next.NodeID != creds.NodeID {
		return nil, errors.New("Tailscale node identity changed.")
	}
	if err := r.storeCredentials(ctx, *current, next); err != nil {
		return nil, err
	}
	if msg, ok := response["error"]; ok && integrations.Truthy(msg) {
		return nil, errors.New(integrations.Str(msg))
	}
	if action == "list" {
		services, err := servicesFor(*current)
		if err != nil {
			return nil, err
		}
		out := map[string]any{}
		if result, ok := response["result"].(map[string]any); ok {
			for k, v := range result {
				out[k] = v
			}
		}
		out["services"] = services
		return out, nil
	}
	return response["result"], nil
}

func (r *runtime) storeCredentials(ctx context.Context, conn integrations.Connection, creds nodeCredentials) error {
	raw, _ := json.Marshal(creds)
	sealed, err := r.svc.Seal(string(raw))
	if err != nil {
		return err
	}
	_, err = r.svc.DB.W.ExecContext(ctx, `UPDATE integration_connections SET credentials_json = ?, updated_at = datetime('now')
		WHERE id = ? AND user_id = ? AND agent_id = ? AND status = 'connected'`, sealed, conn.ID, conn.UserID, conn.AgentID)
	return err
}

// stop aborts every operation of a connection and terminates their clients.
func (r *runtime) stop(scope string) {
	r.mu.Lock()
	var matching []*activeCall
	for _, rec := range r.active {
		if rec.scope == scope {
			matching = append(matching, rec)
		}
	}
	r.mu.Unlock()
	for _, rec := range matching {
		rec.cancel(errors.New("Tailscale connection was disconnected."))
	}
	for _, rec := range matching {
		<-rec.done
	}
}

func (r *runtime) shutdown() {
	r.mu.Lock()
	r.stopping = true
	scopes := map[string]bool{}
	for _, rec := range r.active {
		scopes[rec.scope] = true
	}
	r.mu.Unlock()
	for scope := range scopes {
		r.stop(scope)
	}
}
