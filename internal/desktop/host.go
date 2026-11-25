package desktop

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	goruntime "runtime"
	"strconv"
	"sync"

	"github.com/NeoLabs-Systems/neoagent/internal/runtime/cli"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
)

// inProcess is a companion transport without a socket: commands sent to it
// run in this process and the reply comes back as if from a device.
type inProcess struct {
	mu      sync.Mutex
	open    bool
	conn    *Connection
	handle  func(ctx context.Context, command string, payload map[string]any) (any, error)
	pending sync.WaitGroup
}

func (t *inProcess) Open() bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.open
}

func (t *inProcess) Close(string) {
	t.mu.Lock()
	t.open = false
	t.mu.Unlock()
}

func (t *inProcess) Ping() error {
	t.mu.Lock()
	conn := t.conn
	open := t.open
	t.mu.Unlock()
	if open && conn != nil {
		conn.Pong()
	}
	return nil
}

func (t *inProcess) Send(data []byte) error {
	var m struct {
		Type    string         `json:"type"`
		ID      string         `json:"id"`
		Command string         `json:"command"`
		Payload map[string]any `json:"payload"`
	}
	if json.Unmarshal(data, &m) != nil || m.Type != "command" {
		return nil
	}
	if m.Payload == nil {
		m.Payload = map[string]any{}
	}
	t.pending.Add(1)
	go func() {
		defer t.pending.Done()
		payload, err := t.handle(context.Background(), m.Command, m.Payload)
		var out any
		if err != nil {
			code := any(nil)
			var de *Error
			if errors.As(err, &de) && de.Code != "" {
				code = de.Code
			}
			out = map[string]any{"type": "result", "id": m.ID, "ok": false, "error": err.Error(), "code": code}
		} else {
			if payload == nil {
				payload = map[string]any{}
			}
			out = map[string]any{"type": "result", "id": m.ID, "ok": true, "payload": payload}
		}
		t.mu.Lock()
		conn, open := t.conn, t.open
		t.mu.Unlock()
		if open && conn != nil {
			raw, _ := json.Marshal(out)
			conn.HandleMessage(raw)
		}
	}()
	return nil
}

// HostCompanion makes this server every user's companion device for
// TERMINAL_ENV=host: shell work goes to a CLI executor and file work to the
// user's workspace, through the same command path a desktop app uses.
type HostCompanion struct {
	Registry *Registry
	// Workspaces gives each user's workspace root.
	Workspaces *workspace.Manager

	mu      sync.Mutex
	running map[int64]*hostRun
	starts  map[int64]chan struct{}
}

type hostRun struct {
	t        *inProcess
	conn     *Connection
	previous string
}

func unsupported(command string) error {
	return &Error{
		Message: `The command-line companion cannot run "` + command + `" because it has no screen. Use the desktop app for screen control.`,
		Code:    "LOCAL_COMPANION_UNSUPPORTED",
	}
}

// Ensure registers the companion for the user unless it is connected.
func (h *HostCompanion) Ensure(ctx context.Context, userID int64) error {
	if userID <= 0 {
		return errors.New("The host computer requires a user ID.")
	}
	for {
		if h.Registry.IsConnected(userID) {
			return nil
		}
		h.mu.Lock()
		if h.running == nil {
			h.running, h.starts = map[int64]*hostRun{}, map[int64]chan struct{}{}
		}
		if wait, busy := h.starts[userID]; busy {
			h.mu.Unlock()
			select {
			case <-wait:
				continue
			case <-ctx.Done():
				return ctx.Err()
			}
		}
		done := make(chan struct{})
		h.starts[userID] = done
		old := h.running[userID]
		delete(h.running, userID)
		h.mu.Unlock()
		if old != nil {
			old.stop(h.Registry)
		}
		run, err := h.start(ctx, userID)
		h.mu.Lock()
		if err == nil {
			h.running[userID] = run
		}
		delete(h.starts, userID)
		close(done)
		h.mu.Unlock()
		return err
	}
}

func (h *HostCompanion) start(ctx context.Context, userID int64) (*hostRun, error) {
	key := strconv.FormatInt(userID, 10)
	root := ""
	if h.Workspaces != nil {
		var err error
		if root, err = h.Workspaces.Root(key); err != nil {
			return nil, err
		}
	}
	pinned, err := workspace.New(root, true)
	if err != nil {
		return nil, err
	}
	executor, err := cli.NewExecutor()
	if err != nil {
		return nil, err
	}
	// A model can read anything a command can: commands get a fixed environment.
	executor.BaseEnvironment = func() []string { return cli.WorkerEnv(os.Environ(), "") }
	t := &inProcess{open: true}
	t.handle = func(ctx context.Context, command string, p map[string]any) (any, error) {
		switch command {
		case CmdGetStatus:
			return map[string]any{"paused": false, "capabilities": map[string]any{"files": true, "shell": true}}, nil
		case CmdPing:
			return map[string]any{}, nil
		case CmdExecute:
			cwd := jsTextOr(p["cwd"])
			if cwd == "" || cwd == "__neoagent_workspace__" {
				cwd = root
			}
			o := cli.Options{Cwd: cwd, TimeoutMs: number(p["timeout"])}
			if s, ok := p["stdin_input"].(string); ok {
				o.StdinInput = s
			} else if s, ok := p["stdinInput"].(string); ok {
				o.StdinInput = s
			}
			return executor.Execute(ctx, jsTextOr(p["command"]), o), nil
		case CmdCancel:
			pid, _ := strconv.Atoi(jsTextOr(p["commandId"]))
			return executor.Kill(pid, "aborted"), nil
		case CmdListFiles:
			return pinned.ListDirectory(key, workspace.Options(p))
		case CmdReadFile:
			return pinned.ReadFile(key, workspace.Options(p))
		case CmdWriteFile:
			return pinned.WriteFile(key, workspace.Options(p))
		case CmdSearchFiles:
			return pinned.SearchFiles(key, workspace.Options(p))
		}
		return nil, unsupported(command)
	}
	hostname, _ := os.Hostname()
	deviceID := "cli-" + hostname
	// Remember the selection: the desktop app may be online on this machine too.
	previous := h.Registry.SelectedDeviceID(ctx, userID)
	conn, _, err := h.Registry.Register(ctx, userID, "", t, Hello{
		DeviceID: deviceID, Label: "NeoAgent CLI", Hostname: hostname, Platform: goruntime.GOOS,
		Capabilities: map[string]any{"files": true, "shell": true, "screen": false},
	})
	if err != nil {
		return nil, err
	}
	t.mu.Lock()
	t.conn = conn
	t.mu.Unlock()
	if err := h.Registry.SetSelectedDeviceID(ctx, userID, deviceID); err != nil {
		return nil, err
	}
	return &hostRun{t: t, conn: conn, previous: previous}, nil
}

func (r *hostRun) stop(reg *Registry) {
	_ = reg.SetSelectedDeviceID(context.Background(), r.conn.userID, r.previous)
	r.conn.Close("command-line run finished")
	r.t.Close("")
	r.t.pending.Wait()
}

// Shutdown unregisters every host companion.
func (h *HostCompanion) Shutdown() {
	h.mu.Lock()
	runs := h.running
	h.running = map[int64]*hostRun{}
	h.mu.Unlock()
	for _, r := range runs {
		r.stop(h.Registry)
	}
}

func jsTextOr(v any) string {
	if !truthy(v) {
		return ""
	}
	return jsText(v)
}
