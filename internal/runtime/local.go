package runtime

import (
	"context"
	"errors"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/desktop"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guestproto"
)

// LocalBackend is a computer that is a user's own machine, reached through
// the desktop companion: the NeoAgent desktop app, or with TERMINAL_ENV=host
// this server itself (Host set).
type LocalBackend struct {
	Registry  *desktop.Registry
	Artifacts ArtifactStore
	// Host registers this server as the companion on first use.
	Host *desktop.HostCompanion
}

func userID(key string) int64 {
	id, _ := strconv.ParseInt(key, 10, 64)
	return id
}

// Readiness implements computer: nothing to install, but no isolation either.
func (l *LocalBackend) Readiness() *Object {
	host, _ := os.Hostname()
	return obj("ready", true, "isolated", false, "host", host, "managed", l.Host != nil, "missing", []string{})
}

func (l *LocalBackend) connected(key string) bool {
	return l.Registry != nil && l.Registry.IsConnected(userID(key))
}

// Status implements computer.
func (l *LocalBackend) Status(ctx context.Context, key string) *Object {
	st := desktop.Status{Devices: []desktop.Device{}}
	if l.Registry != nil {
		st = l.Registry.Status(ctx, userID(key))
	}
	selected := st.Selected()
	state := StateReady
	if !st.Connected || (selected != nil && selected.Paused) {
		state = StateStopped
	}
	var device, pending any
	permissions := map[string]any{}
	approvals := map[string]any{}
	if selected != nil {
		device = selected
		permissions = selected.PermissionsMap()
		if a, ok := permissions["appApprovals"].(map[string]any); ok {
			approvals = a
		}
		pending = selected.MetadataMap()["pendingPermission"]
	}
	capabilities := []string{"desktop", "browser", "shell", "files"}
	if l.Host != nil {
		// The host companion has no screen and no browser of its own.
		capabilities = []string{"shell", "files"}
	}
	return obj("state", state, "provider", ProviderLocal, "local", true, "connected", st.Connected,
		"selectedDeviceId", st.SelectedDeviceID, "device", device, "permissions", permissions, "appApprovals", approvals,
		"pendingPermission", pending, "isolated", false, "capabilities", capabilities)
}

// Alive implements computer.
func (l *LocalBackend) Alive(key string) bool { return l.connected(key) }

// Tracked implements computer.
func (l *LocalBackend) Tracked(key string) bool { return l.connected(key) }

func (l *LocalBackend) ensureCompanion(ctx context.Context, key string) error {
	if l.Host == nil {
		return nil
	}
	return l.Host.Ensure(ctx, userID(key))
}

func (l *LocalBackend) assertConnected(ctx context.Context, key string) error {
	if err := l.ensureCompanion(ctx, key); err != nil {
		return err
	}
	if !l.connected(key) {
		return &desktop.Error{Message: "The NeoAgent desktop app is reconnecting to this device.", Code: "DESKTOP_COMPANION_NOT_CONNECTED", Status: 409}
	}
	return nil
}

// pause pauses or resumes agent control of the selected device.
func (l *LocalBackend) pause(ctx context.Context, key string, paused bool) error {
	if !l.connected(key) {
		return nil
	}
	st := l.Registry.Status(ctx, userID(key))
	if id, _ := st.SelectedDeviceID.(string); id != "" {
		_, err := l.Registry.Pause(ctx, userID(key), id, paused)
		return err
	}
	return nil
}

// Wake implements computer: control of the device resumes.
func (l *LocalBackend) Wake(ctx context.Context, key string) error { return l.pause(ctx, key, false) }

// Prepare implements computer.
func (l *LocalBackend) Prepare(ctx context.Context, key string) error {
	if err := l.pause(ctx, key, false); err != nil {
		return err
	}
	return l.assertConnected(ctx, key)
}

// Stop implements computer: a person's machine is never shut down, only paused.
func (l *LocalBackend) Stop(ctx context.Context, key string) { _ = l.pause(ctx, key, true) }

func (l *LocalBackend) dispatch(ctx context.Context, key, command string, payload any, timeout time.Duration) (*Object, error) {
	if err := l.ensureCompanion(ctx, key); err != nil {
		return nil, err
	}
	if l.Registry == nil {
		return nil, desktop.Unavailable("")
	}
	return l.Registry.Dispatch(ctx, userID(key), "", command, payload, timeout)
}

// RequestGuest implements computer by mapping the guest's workspace endpoints
// onto companion commands.
func (l *LocalBackend) RequestGuest(ctx context.Context, key, method, path string, body any, o RequestOptions) (*Object, error) {
	if err := l.assertConnected(ctx, key); err != nil {
		return nil, err
	}
	u, err := url.Parse(path)
	if err != nil {
		u = &url.URL{Path: path}
	}
	method = strings.ToUpper(method)
	payload, _ := body.(map[string]any)
	if payload == nil {
		payload = map[string]any{}
	}
	var root any
	if r := strings.TrimSpace(o.WorkspaceRoot); r != "" {
		root = r
	}
	q := u.Query()
	switch {
	case u.Path == "/health":
		return obj("status", "ok", "provider", ProviderLocal), nil
	case u.Path == "/workspace/files" && method == http.MethodGet:
		return l.dispatch(ctx, key, desktop.CmdListFiles, map[string]any{"path": guestproto.FromWorkspacePath(q.Get("path"), "."), "workspaceRoot": root}, 0)
	case u.Path == "/workspace/files/content" && method == http.MethodGet:
		return l.dispatch(ctx, key, desktop.CmdReadFile, map[string]any{"path": guestproto.FromWorkspacePath(q.Get("path"), ""), "workspaceRoot": root}, 0)
	case u.Path == "/workspace/files/content" && method == http.MethodPut:
		p, _ := payload["path"].(string)
		return l.dispatch(ctx, key, desktop.CmdWriteFile, map[string]any{"path": guestproto.FromWorkspacePath(p, ""), "content": payload["content"], "workspaceRoot": root}, 0)
	case u.Path == "/workspace/files/download" && method == http.MethodGet:
		return l.dispatch(ctx, key, desktop.CmdReadFile, map[string]any{"path": guestproto.FromWorkspacePath(q.Get("path"), ""), "encoding": "base64", "workspaceRoot": root}, 0)
	case u.Path == "/workspace/search" && method == http.MethodPost:
		out := map[string]any{}
		for k, v := range payload {
			out[k] = v
		}
		p, _ := payload["path"].(string)
		out["path"] = guestproto.FromWorkspacePath(p, ".")
		out["workspaceRoot"] = root
		return l.dispatch(ctx, key, desktop.CmdSearchFiles, out, 0)
	}
	return nil, &CodedError{Message: "Unsupported local computer request: " + method + " " + u.Path, Code: "LOCAL_COMPUTER_REQUEST_UNSUPPORTED", Status: 400}
}

// ExecuteCommand implements computer.
func (l *LocalBackend) ExecuteCommand(ctx context.Context, key, command string, o ExecOptions) (*Object, error) {
	if err := l.ensureCompanion(ctx, key); err != nil {
		return nil, err
	}
	cwd := o.Cwd
	if cwd == guestproto.WorkspaceDir {
		cwd = "__neoagent_workspace__"
	}
	return l.localDesktop(key).executeCommand(ctx, command, cwd, o)
}

// KillCommand implements computer.
func (l *LocalBackend) KillCommand(ctx context.Context, key string, pid any, _ string) (*Object, error) {
	return l.dispatch(ctx, key, desktop.CmdCancel, map[string]any{"commandId": pid}, 0)
}

// OpenBrowser implements computer: the device's own browser, driven by screen.
func (l *LocalBackend) OpenBrowser(_ context.Context, key string) (Browser, error) {
	return &localBrowser{backend: l, key: key, desktop: l.localDesktop(key)}, nil
}

// OpenDesktop implements computer.
func (l *LocalBackend) OpenDesktop(key string) Desktop { return l.localDesktop(key) }

func (l *LocalBackend) localDesktop(key string) *localDesktop {
	return &localDesktop{backend: l, key: key}
}

// TouchActivity implements computer.
func (l *LocalBackend) TouchActivity(string) {}

// Shutdown implements computer.
func (l *LocalBackend) Shutdown() {
	if l.Host != nil {
		l.Host.Shutdown()
	}
}

var _ computer = (*LocalBackend)(nil)

// localDesktop drives a companion device's screen.
type localDesktop struct {
	backend *LocalBackend
	key     string
}

func (d *localDesktop) call(ctx context.Context, command string, payload map[string]any, timeout time.Duration) (*Object, error) {
	if d.backend.Registry == nil {
		return nil, desktop.Unavailable("")
	}
	result, err := d.backend.dispatch(ctx, d.key, command, payload, timeout)
	if err != nil {
		return nil, err
	}
	return d.materialize(ctx, result)
}

// materialize stores a screenshot the device sent inline as an artifact.
func (d *localDesktop) materialize(ctx context.Context, result *Object) (*Object, error) {
	raw := firstNonEmpty(result.String("screenshotDataUrl"), result.String("screenshotData"), result.String("screenshotBase64"))
	if raw == "" {
		return result, nil
	}
	image, err := decodeImage(raw)
	if err != nil {
		return nil, err
	}
	if d.backend.Artifacts == nil {
		return nil, errors.New("Screenshot storage is unavailable.")
	}
	var device struct {
		DeviceID        any `json:"deviceId"`
		ActiveDisplayID any `json:"activeDisplayId"`
	}
	result.Decode("device", &device)
	display := any(result.String("displayId"))
	if display == "" {
		display = device.ActiveDisplayID
	}
	stored, err := d.backend.Artifacts.CreateBufferArtifact(ctx, d.key, Artifact{
		Kind: "desktop-screenshot", Backend: "desktop-companion", Extension: image.extension, ContentType: image.contentType,
		FilenameBase: "desktop-companion-screenshot", Content: image.data,
		Metadata: map[string]any{"deviceId": device.DeviceID, "displayId": display},
	})
	if err != nil {
		return nil, err
	}
	out := result.Clone().Set("screenshotPath", stored.URL).Set("artifactId", stored.ID).
		Set("filename", baseName(stored.StoragePath)).Set("fullPath", stored.StoragePath)
	for _, k := range []string{"screenshotDataUrl", "screenshotData", "screenshotBase64"} {
		out.Delete(k)
	}
	return out, nil
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

func baseName(p string) string {
	if i := strings.LastIndexAny(p, `/\`); i >= 0 {
		return p[i+1:]
	}
	return p
}

// Status implements Desktop: the user's companion devices.
func (d *localDesktop) Status(ctx context.Context) *Object {
	if d.backend.Registry == nil {
		return obj("connected", false, "selectedDeviceId", nil, "onlineCount", 0, "devices", []any{})
	}
	st := d.backend.Registry.Status(ctx, userID(d.key))
	return obj("connected", st.Connected, "selectedDeviceId", st.SelectedDeviceID, "onlineCount", st.OnlineCount, "devices", st.Devices)
}

// Screenshot implements Desktop.
func (d *localDesktop) Screenshot(ctx context.Context) (*Object, error) {
	return d.call(ctx, desktop.CmdCaptureFrame, map[string]any{}, 0)
}

// Observe implements Desktop.
func (d *localDesktop) Observe(ctx context.Context) (*Object, error) {
	return d.call(ctx, desktop.CmdObserve, map[string]any{}, 0)
}

// ClickPoint implements Desktop.
func (d *localDesktop) ClickPoint(ctx context.Context, x, y, button any) (*Object, error) {
	p := map[string]any{"x": x, "y": y}
	if button != nil {
		p["button"] = button
	}
	return d.call(ctx, desktop.CmdClick, p, 0)
}

// MouseMove implements Desktop.
func (d *localDesktop) MouseMove(ctx context.Context, x, y any) (*Object, error) {
	return d.call(ctx, desktop.CmdMouseMove, map[string]any{"x": x, "y": y}, 0)
}

// Drag implements Desktop.
func (d *localDesktop) Drag(ctx context.Context, x1, y1, x2, y2, durationMs any) (*Object, error) {
	return d.call(ctx, desktop.CmdDrag, map[string]any{"x1": x1, "y1": y1, "x2": x2, "y2": y2, "durationMs": durationMs}, 0)
}

// Scroll implements Desktop.
func (d *localDesktop) Scroll(ctx context.Context, deltaX, deltaY any) (*Object, error) {
	return d.call(ctx, desktop.CmdScroll, map[string]any{"deltaX": deltaX, "deltaY": deltaY}, 0)
}

// TypeText implements Desktop.
func (d *localDesktop) TypeText(ctx context.Context, text string, pressEnter bool) (*Object, error) {
	p := map[string]any{"text": text}
	if pressEnter {
		p["pressEnter"] = true
	}
	return d.call(ctx, desktop.CmdTypeText, p, 0)
}

// PressKey implements Desktop.
func (d *localDesktop) PressKey(ctx context.Context, key string) (*Object, error) {
	return d.call(ctx, desktop.CmdPressKey, map[string]any{"key": key}, 0)
}

// LaunchApp implements Desktop.
func (d *localDesktop) LaunchApp(ctx context.Context, app string) (*Object, error) {
	return d.call(ctx, desktop.CmdLaunchApp, map[string]any{"app": app}, 0)
}

// AccessibilityTree implements Desktop.
func (d *localDesktop) AccessibilityTree(ctx context.Context) (*Object, error) {
	return d.call(ctx, desktop.CmdGetTree, map[string]any{}, 0)
}

func (d *localDesktop) executeCommand(ctx context.Context, command, cwd string, o ExecOptions) (*Object, error) {
	timeout := time.Duration(0)
	if o.TimeoutMs > 0 {
		timeout = time.Duration(o.TimeoutMs)*time.Millisecond + 10*time.Second
	}
	var stdin any
	if o.StdinInput != nil && *o.StdinInput != "" {
		stdin = *o.StdinInput
	}
	var timeoutValue any
	if o.TimeoutMs > 0 {
		timeoutValue = o.TimeoutMs
	}
	inputs := o.Inputs
	if inputs == nil {
		inputs = []any{}
	}
	return d.call(ctx, desktop.CmdExecute, map[string]any{
		"command": command, "deviceId": nil, "cwd": nullable(cwd), "timeout": timeoutValue, "stdin_input": stdin,
		"pty": o.PTY, "inputs": inputs, "runId": nullable(o.RunID), "stepId": nullable(o.StepID),
	}, timeout)
}

// localBrowser is the user's own browser, driven through the screen: DOM
// access does not exist there.
type localBrowser struct {
	backend *LocalBackend
	key     string
	desktop *localDesktop
	lastURL string
}

func recoverable(message, code string) error {
	return &CodedError{Message: message, Code: code}
}

func (b *localBrowser) Navigate(ctx context.Context, target string, _ map[string]any) (*Object, error) {
	result, err := b.backend.dispatch(ctx, b.key, desktop.CmdOpenURI, map[string]any{"uri": target}, 0)
	if err != nil {
		return nil, err
	}
	b.lastURL = target
	return result.Clone().Set("url", target).Set("local", true), nil
}

func (b *localBrowser) Click(context.Context, any, any, bool) (*Object, error) {
	return nil, recoverable("Semantic selectors are unavailable on the local desktop. Observe the screen and use coordinate control.", "LOCAL_BROWSER_SEMANTIC_CONTROL_UNAVAILABLE")
}

func (b *localBrowser) Extract(context.Context, any, any, bool) (*Object, error) {
	return nil, recoverable("DOM extraction is unavailable on the local desktop. Use screen observation or the shell.", "LOCAL_BROWSER_DOM_UNAVAILABLE")
}

func (b *localBrowser) ExtractContent(ctx context.Context, _ map[string]any) (*Object, error) {
	return b.Extract(ctx, nil, nil, false)
}

func (b *localBrowser) Evaluate(context.Context, string) (*Object, error) {
	return nil, recoverable("Browser JavaScript execution is unavailable on the local desktop. Use visible desktop control.", "LOCAL_BROWSER_DOM_UNAVAILABLE")
}

func (b *localBrowser) ClickPoint(ctx context.Context, x, y any, _ bool) (*Object, error) {
	return b.desktop.ClickPoint(ctx, x, y, nil)
}

func (b *localBrowser) Fill(ctx context.Context, _ any, value string, options map[string]any) (*Object, error) {
	return b.desktop.TypeText(ctx, value, options["pressEnter"] == true)
}

func (b *localBrowser) TypeText(ctx context.Context, text string, options map[string]any) (*Object, error) {
	return b.desktop.TypeText(ctx, text, options["pressEnter"] == true)
}

func (b *localBrowser) PressKey(ctx context.Context, key string, _ bool) (*Object, error) {
	return b.desktop.PressKey(ctx, key)
}

func (b *localBrowser) Scroll(ctx context.Context, deltaX, deltaY any, _ bool) (*Object, error) {
	return b.desktop.Scroll(ctx, deltaX, deltaY)
}

func (b *localBrowser) Screenshot(ctx context.Context, _ map[string]any) (*Object, error) {
	return b.desktop.Screenshot(ctx)
}

func (b *localBrowser) ScreenshotJPEG(ctx context.Context, _ int, _ map[string]any) ([]byte, error) {
	result, err := b.desktop.Screenshot(ctx)
	if err != nil {
		return nil, err
	}
	path := result.String("fullPath")
	if path == "" {
		return nil, errors.New("Local computer screenshot is unavailable.")
	}
	return os.ReadFile(path)
}

func (b *localBrowser) Launch(ctx context.Context, _ map[string]any) (*Object, error) {
	if err := b.backend.assertConnected(ctx, b.key); err != nil {
		return nil, err
	}
	return obj("success", true, "launched", true, "local", true), nil
}

func (b *localBrowser) Close(context.Context) (*Object, error) {
	return obj("success", true, "launched", true, "local", true), nil
}

func (b *localBrowser) FillCredential(context.Context, map[string]any) (*Object, error) {
	return nil, recoverable("Protected credential fill is unavailable on the local desktop.", "LOCAL_BROWSER_DOM_UNAVAILABLE")
}

func (b *localBrowser) SubmitProtectedCredential(context.Context, string) (*Object, error) {
	return nil, errors.New("Protected credential fill is missing or expired.")
}

func (b *localBrowser) CancelProtectedCredential(context.Context, string) (*Object, error) {
	return nil, errors.New("Protected credential fill is missing or expired.")
}

func (b *localBrowser) Status(ctx context.Context) (*Object, error) {
	connected := b.backend.connected(b.key)
	pages := 0
	if connected {
		pages = 1
	}
	title := "Local computer"
	if b.backend.Registry != nil {
		st := b.backend.Registry.Status(ctx, userID(b.key))
		for _, d := range st.Devices {
			if st.SelectedDeviceID != nil && d.DeviceID == st.SelectedDeviceID {
				title = d.Label
				if t, _ := d.MetadataMap()["frontmostWindowTitle"].(string); t != "" {
					title = t
				}
			}
		}
	}
	return obj("launched", connected, "pages", pages, "headless", false,
		"pageInfo", obj("url", nullable(b.lastURL), "title", title, "local", true)), nil
}

var _ Browser = (*localBrowser)(nil)
var _ Browser = (*BrowserProvider)(nil)
var _ Desktop = (*localDesktop)(nil)
var _ Desktop = (*DesktopProvider)(nil)
