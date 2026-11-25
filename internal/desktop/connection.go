package desktop

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
)

// Transport carries companion messages: the WebSocket of a desktop app, or
// the in-process companion of TERMINAL_ENV=host.
type Transport interface {
	Send(data []byte) error
	Ping() error
	Close(reason string)
	Open() bool
}

type pending struct {
	command string
	payload map[string]any
	reply   chan reply
	upload  string // "", "uploading" or "completed"
}

type reply struct {
	result *jsonobj.Object
	err    error
}

// Connection is one live companion.
type Connection struct {
	r         *Registry
	t         Transport
	userID    int64
	sessionID string
	deviceID  string

	mu           sync.Mutex
	pending      map[string]*pending
	lastPong     time.Time
	lastPresence time.Time
	closed       bool
	stop         chan struct{}
}

func newConnection(r *Registry, t Transport, userID int64, sessionID, deviceID string) *Connection {
	return &Connection{r: r, t: t, userID: userID, sessionID: sessionID, deviceID: deviceID, pending: map[string]*pending{}, lastPong: time.Now(), stop: make(chan struct{})}
}

// DeviceID is the device behind the connection.
func (c *Connection) DeviceID() string { return c.deviceID }

func (c *Connection) start() {
	if c.r.heartbeat <= 0 {
		return
	}
	c.touchPresence(true)
	go func() {
		ticker := time.NewTicker(c.r.heartbeat)
		defer ticker.Stop()
		for {
			select {
			case <-c.stop:
				return
			case <-ticker.C:
			}
			if !c.Open() {
				c.fail(Unavailable("Desktop companion disconnected."))
				return
			}
			c.mu.Lock()
			late := c.r.heartbeatTimeout > 0 && time.Since(c.lastPong) > c.r.heartbeatTimeout
			c.mu.Unlock()
			if late {
				c.t.Close("heartbeat timed out")
				c.fail(Unavailable("Desktop companion heartbeat timed out."))
				return
			}
			c.touchPresence(false)
			if err := c.t.Ping(); err != nil {
				c.fail(err)
				return
			}
		}
	}()
}

// Open reports a usable connection.
func (c *Connection) Open() bool {
	c.mu.Lock()
	closed := c.closed
	c.mu.Unlock()
	return !closed && c.t.Open()
}

// Close ends the connection on purpose.
func (c *Connection) Close(reason string) {
	if c.Open() {
		if len(reason) > 120 {
			reason = reason[:120]
		}
		c.t.Close(reason)
	}
	c.fail(Unavailable("Desktop companion disconnected."))
}

// Closed is called when the transport went away.
func (c *Connection) Closed() { c.fail(Unavailable("Desktop companion disconnected.")) }

// fail rejects every pending command and gives the device up.
func (c *Connection) fail(err error) {
	c.mu.Lock()
	first := !c.closed
	c.closed = true
	waiting := c.pending
	c.pending = map[string]*pending{}
	c.mu.Unlock()
	if first {
		close(c.stop)
	}
	for _, p := range waiting {
		p.reply <- reply{err: err}
	}
	c.r.unregister(c)
}

// Pong records a heartbeat answer.
func (c *Connection) Pong() {
	c.mu.Lock()
	c.lastPong = time.Now()
	c.mu.Unlock()
	c.touchPresence(false)
}

func (c *Connection) touchPresence(force bool) {
	c.mu.Lock()
	if !force && c.r.presenceTouch > 0 && time.Since(c.lastPresence) < c.r.presenceTouch {
		c.mu.Unlock()
		return
	}
	c.lastPresence = time.Now()
	c.mu.Unlock()
	c.r.touchPresence(c.userID, c.deviceID)
}

// Send runs a command on the companion and waits for its result. A command
// that times out or is cancelled is cancelled on the device too.
func (c *Connection) Send(ctx context.Context, command string, payload any, timeout time.Duration) (*jsonobj.Object, error) {
	if !c.Open() {
		return nil, Unavailable("")
	}
	if timeout <= 0 {
		timeout = c.r.commandTimeout
	}
	timeout = min(maxCommandTimeout, max(100*time.Millisecond, timeout))
	id := uuid.NewString()
	if payload == nil {
		payload = map[string]any{}
	}
	p := &pending{command: command, reply: make(chan reply, 1)}
	if m, ok := payload.(map[string]any); ok {
		p.payload = m
	}
	c.mu.Lock()
	c.pending[id] = p
	c.mu.Unlock()
	cancelRemote := func() {
		c.mu.Lock()
		delete(c.pending, id)
		c.mu.Unlock()
		if command != CmdCancel && c.Open() {
			_ = c.t.Send(commandMessage(uuid.NewString(), CmdCancel, map[string]any{"commandId": id}))
		}
	}
	if err := c.t.Send(commandMessage(id, command, payload)); err != nil {
		c.mu.Lock()
		delete(c.pending, id)
		c.mu.Unlock()
		return nil, err
	}
	timer := time.NewTimer(timeout)
	defer timer.Stop()
	select {
	case r := <-p.reply:
		return r.result, r.err
	case <-timer.C:
		cancelRemote()
		return nil, &Error{Message: "Desktop companion command timed out: " + command, Code: "DESKTOP_COMPANION_COMMAND_TIMEOUT"}
	case <-ctx.Done():
		cancelRemote()
		return nil, fmt.Errorf("Desktop companion command aborted: %s", command)
	}
}

// HandleMessage processes a message from the companion.
func (c *Connection) HandleMessage(data []byte) {
	c.mu.Lock()
	c.lastPong = time.Now()
	c.mu.Unlock()
	c.touchPresence(false)
	if len(data) > 0 && data[0] == frameTypeVideo {
		return
	}
	m := parseMessage(data)
	if m == nil {
		return
	}
	if m.Type == "event" {
		if m.Event == "statusChanged" || m.Event == "permissionsChanged" {
			var payload map[string]any
			_ = json.Unmarshal(m.Payload, &payload)
			c.r.TouchConnection(context.Background(), c.userID, c.deviceID, objectOr(payload))
		}
		return
	}
	if m.Type != "result" || m.ID == "" {
		return
	}
	c.mu.Lock()
	p := c.pending[m.ID]
	delete(c.pending, m.ID)
	c.mu.Unlock()
	if p == nil {
		return
	}
	if m.OK != nil && !*m.OK {
		message := "Desktop companion command failed: " + p.command
		if truthy(m.Error) {
			message = jsText(m.Error)
		}
		code := ""
		if truthy(m.Code) {
			code = jsText(m.Code)
		}
		p.reply <- reply{err: &Error{Message: message, Code: code}}
		return
	}
	result := jsonobj.New()
	if len(m.Payload) > 0 && string(m.Payload) != "null" {
		if err := json.Unmarshal(m.Payload, result); err != nil {
			result = jsonobj.New()
		}
	}
	p.reply <- reply{result: result}
}

func (c *Connection) claimOutput(commandID string) (runID, stepID any, ok bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	p := c.pending[commandID]
	if p == nil || p.command != CmdExecute || p.upload != "" {
		return nil, nil, false
	}
	p.upload = "uploading"
	return p.payload["runId"], p.payload["stepId"], true
}

func (c *Connection) finishOutput(commandID string, success bool) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	p := c.pending[commandID]
	if p == nil || p.upload != "uploading" {
		return false
	}
	p.upload = ""
	if success {
		p.upload = "completed"
	}
	return true
}

func truthy(v any) bool {
	switch t := v.(type) {
	case nil:
		return false
	case bool:
		return t
	case float64:
		return t != 0 && !math.IsNaN(t)
	case string:
		return t != ""
	}
	return true
}

// jsText is String(value) for a JSON value.
func jsText(v any) string {
	switch t := v.(type) {
	case nil:
		return "null"
	case string:
		return t
	case bool:
		return strconv.FormatBool(t)
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64)
	case []any:
		parts := make([]string, len(t))
		for i, e := range t {
			if e != nil {
				parts[i] = jsText(e)
			}
		}
		return strings.Join(parts, ",")
	}
	return "[object Object]"
}

// number is Number(value) || 0.
func number(v any) float64 {
	switch t := v.(type) {
	case float64:
		if math.IsNaN(t) {
			return 0
		}
		return t
	case string:
		if f, err := strconv.ParseFloat(strings.TrimSpace(t), 64); err == nil {
			return f
		}
	case bool:
		if t {
			return 1
		}
	}
	return 0
}
