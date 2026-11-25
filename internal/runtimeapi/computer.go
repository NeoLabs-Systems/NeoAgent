package runtimeapi

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/coder/websocket"

	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
	"github.com/NeoLabs-Systems/neolabs-go/wsgate"

	"github.com/NeoLabs-Systems/neoagent/internal/desktop"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
	"github.com/NeoLabs-Systems/neoagent/internal/teach"
)

const (
	maxEditBytes          = 1024 * 1024
	maxDisplayFrameBytes  = 32 * 1024 * 1024
	displayWebSocketPath  = "/api/computer/display-ws"
	computerJSONBodyLimit = 10 << 20
)

// Teach is Teach Mode as the routes use it.
type Teach interface {
	ActiveSummary(userKey string) (teach.Summary, bool)
	StartSession(ctx context.Context, userKey string, in teach.StartInput) (teach.Summary, error)
	Record(ctx context.Context, userKey string, event map[string]any) (teach.RecordResult, error)
	StopSession(ctx context.Context, userKey, sessionID string) (teach.StopResult, error)
	Cancel(userKey, sessionID string) bool
}

// RunPauser pauses an agent run that controls the computer when the user
// takes over.
type RunPauser interface {
	// RunRunning reports whether the run with this id is running.
	RunRunning(runID string) bool
	// PauseRun pauses it; false means it cannot be paused right now.
	PauseRun(runID string, userID int64, reason string) bool
}

// ComputerConfig configures the /api/computer routes.
type ComputerConfig struct {
	Manager *runtime.Manager
	Teach   Teach
	Runs    RunPauser
	// Home and AppDir are redacted from error messages.
	Home, AppDir string
	Gate         *wsgate.Gate
	// Devices and Artifacts receive command output uploaded by desktop companions.
	Devices   *desktop.Registry
	Artifacts runtime.ArtifactStore
}

// ComputerAPI serves /api/computer/*.
type ComputerAPI struct{ cfg ComputerConfig }

// NewComputer creates the routes.
func NewComputer(cfg ComputerConfig) *ComputerAPI {
	if cfg.Gate == nil {
		cfg.Gate = wsgate.New(wsgate.Options{MaxMessage: maxDisplayFrameBytes})
	}
	return &ComputerAPI{cfg: cfg}
}

// Close drops every display connection.
func (c *ComputerAPI) Close() { c.cfg.Gate.Close() }

type handler func(r *http.Request, user int64, sess *sessionx.Session) (any, error)

// Routes registers /api/computer endpoints on mux.
func (c *ComputerAPI) Routes(mux *http.ServeMux) {
	mux.Handle("/api/computer/novnc/", runtime.NoVNCHandler("/api/computer/novnc/"))
	mux.HandleFunc("GET "+displayWebSocketPath, c.displaySocket)
	route := func(pattern string, h handler) { mux.HandleFunc(pattern, c.wrap(h)) }
	route("GET /api/computer/status", c.status)
	route("GET /api/computer/provider", c.getProvider)
	route("PUT /api/computer/provider", c.putProvider)
	route("POST /api/computer/start", c.start)
	route("POST /api/computer/stop", c.stop)
	route("POST /api/computer/display-session", c.displaySession)
	mux.HandleFunc("GET /api/computer/display/{token}", c.displayPage)
	route("POST /api/computer/control/acquire", c.acquire)
	route("POST /api/computer/control/release", c.release)
	route("GET /api/computer/teach/status", c.teachStatus)
	route("POST /api/computer/teach/start", c.teachStart)
	route("POST /api/computer/teach/events", c.teachEvents)
	route("POST /api/computer/teach/{sessionId}/stop", c.teachStop)
	mux.HandleFunc("POST /api/computer/teach/{sessionId}/cancel", c.teachCancel)
	route("GET /api/computer/files", c.files)
	route("GET /api/computer/files/content", c.fileContent)
	route("PUT /api/computer/files/content", c.putFileContent)
	mux.HandleFunc("GET /api/computer/files/download", c.download)
	route("POST /api/computer/desktop/screenshot", c.desktopScreenshot)
	route("POST /api/computer/desktop/observe", c.desktopObserve)
	route("POST /api/computer/desktop/click", c.desktopClick)
	route("POST /api/computer/desktop/type", c.desktopType)
	route("POST /api/computer/desktop/key", c.desktopKey)
	route("POST /api/computer/desktop/launch", c.desktopLaunch)
	route("POST /api/computer/shell/execute", c.shell)
	route("POST /api/computer/local/command-output", c.localCommandOutput)
	route("GET /api/computer/browser/status", c.browserStatus)
	route("POST /api/computer/browser/navigate", c.browserNavigate)
	route("POST /api/computer/browser/click", c.browserClick)
	route("POST /api/computer/browser/type", c.browserType)
	route("POST /api/computer/browser/screenshot", c.browserScreenshot)
}

func userFrom(r *http.Request) (int64, *sessionx.Session, bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, nil, false
	}
	id, ok := sess.Int64("userId")
	return id, sess, ok && id > 0
}

func key(id int64) string { return strconv.FormatInt(id, 10) }

type httpError struct {
	status int
	msg    string
	code   string
}

func (e *httpError) Error() string { return e.msg }

func (c *ComputerAPI) sendError(w http.ResponseWriter, err error) {
	status, code := http.StatusInternalServerError, ""
	var he *httpError
	var coded *runtime.CodedError
	var guest *runtime.GuestError
	switch {
	case errors.As(err, &he):
		status, code = he.status, he.code
	case errors.As(err, &coded):
		code = coded.Code
		if coded.Status > 0 {
			status = coded.Status
		}
	case errors.As(err, &guest):
		code = guest.Code
		if guest.Status > 0 {
			status = guest.Status
		}
	}
	var codeAny any
	if code != "" {
		codeAny = code
	}
	httpx.WriteJSON(w, status, jsonobj.New("error", publicerr.Sanitize(err.Error(), c.cfg.Home, c.cfg.AppDir), "code", codeAny))
}

func (c *ComputerAPI) wrap(h handler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		user, sess, ok := userFrom(r)
		if !ok {
			httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
			return
		}
		if c.cfg.Manager == nil {
			c.sendError(w, &httpError{503, "Computer runtime is unavailable.", ""})
			return
		}
		result, err := h(r, user, sess)
		if err != nil {
			c.sendError(w, err)
			return
		}
		if created, ok := result.(createdResult); ok {
			httpx.WriteJSON(w, http.StatusCreated, created.body)
			return
		}
		httpx.WriteJSON(w, http.StatusOK, result)
	}
}

// body reads the JSON body once per request (empty object when absent).
func body(r *http.Request) map[string]any {
	if cached, ok := r.Context().Value(bodyKey{}).(map[string]any); ok {
		return cached
	}
	out := map[string]any{}
	if r.Body != nil && strings.Contains(r.Header.Get("Content-Type"), "json") {
		_ = json.NewDecoder(io.LimitReader(r.Body, computerJSONBodyLimit)).Decode(&out)
	}
	if out == nil {
		out = map[string]any{}
	}
	*r = *r.WithContext(context.WithValue(r.Context(), bodyKey{}, out))
	return out
}

type bodyKey struct{}

// jsString is String(value || "") for the body fields the Node routes read.
func jsString(v any) string {
	switch t := v.(type) {
	case nil:
		return ""
	case string:
		return t
	case bool:
		if !t {
			return ""
		}
		return "true"
	case float64:
		if t == 0 {
			return ""
		}
		return strconv.FormatFloat(t, 'f', -1, 64)
	}
	raw, _ := json.Marshal(v)
	return string(raw)
}

func firstString(r *http.Request, names ...string) string {
	b := body(r)
	for _, n := range names {
		if s := jsString(b[n]); s != "" {
			return s
		}
	}
	q := r.URL.Query()
	for _, n := range names {
		if s := q.Get(n); s != "" {
			return s
		}
	}
	return ""
}

func deviceTarget(r *http.Request) string {
	v := strings.ToLower(strings.TrimSpace(firstString(r, "deviceTarget", "device_target")))
	if v == runtime.ProviderLocal || v == runtime.ProviderCloud {
		return v
	}
	return ""
}

func (c *ComputerAPI) requireUserControl(r *http.Request, user int64, sess *sessionx.Session) error {
	m := c.cfg.Manager
	owner := "session:" + sess.ID()
	target := deviceTarget(r)
	lease := m.ControlLease(key(user), target)
	if lease == nil || lease.OwnerType != "user" || lease.OwnerID != owner {
		return &httpError{409, "Take control of the computer before sending input.", "COMPUTER_USER_CONTROL_REQUIRED"}
	}
	_, err := m.AcquireControl(key(user), "user", owner, target)
	return err
}

func (c *ComputerAPI) status(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	return c.cfg.Manager.Status(key(user), deviceTarget(r))
}

func (c *ComputerAPI) getProvider(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	status, err := c.cfg.Manager.Status(key(user), "")
	if err != nil {
		return nil, err
	}
	return map[string]any{"provider": c.cfg.Manager.ComputerProvider(key(user)), "status": status}, nil
}

func (c *ComputerAPI) putProvider(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	return c.cfg.Manager.SetComputerProvider(r.Context(), key(user), jsString(body(r)["provider"]))
}

func (c *ComputerAPI) start(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	return c.cfg.Manager.Start(r.Context(), key(user), deviceTarget(r))
}

func (c *ComputerAPI) stop(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	return c.cfg.Manager.Stop(r.Context(), key(user), deviceTarget(r))
}

func (c *ComputerAPI) displaySession(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	if _, err := c.cfg.Manager.EnsureDisplay(r.Context(), key(user), deviceTarget(r)); err != nil {
		return nil, err
	}
	return c.cfg.Manager.CreateDisplaySession(key(user), deviceTarget(r))
}

func (c *ComputerAPI) displayPage(w http.ResponseWriter, r *http.Request) {
	user, _, ok := userFrom(r)
	if !ok {
		httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
		return
	}
	if c.cfg.Manager == nil {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusServiceUnavailable)
		_, _ = io.WriteString(w, "Computer runtime is unavailable.")
		return
	}
	token := r.PathValue("token")
	session := c.cfg.Manager.ResolveDisplaySession(key(user), token)
	// Without a live session the page opens its own, so a link that outlived
	// its token reconnects instead of stranding the viewer.
	path, viewOnly := "", false
	if session != nil {
		path = displayWebSocketPath + "?token=" + url.QueryEscape(token)
		viewOnly = session.ViewOnly()
	}
	w.Header().Set("Cache-Control", "private, no-store")
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = io.WriteString(w, runtime.DisplayPage(path, viewOnly))
}

// displaySocket bridges the noVNC websocket to QEMU's raw RFB socket, which
// the guest cannot reach; every frame passes the display-session checks.
func (c *ComputerAPI) displaySocket(w http.ResponseWriter, r *http.Request) {
	user, ok := c.cfg.Gate.Admit(w, r)
	if !ok {
		return
	}
	reject := func(status int) {
		w.Header().Set("Connection", "close")
		w.WriteHeader(status)
	}
	m := c.cfg.Manager
	if m == nil {
		reject(http.StatusServiceUnavailable)
		return
	}
	userKey := key(user)
	token := r.URL.Query().Get("token")
	session := m.ResolveDisplaySession(userKey, token)
	if session == nil {
		reject(http.StatusForbidden)
		return
	}
	target, ok := m.DisplayTarget(userKey)
	if !ok {
		reject(http.StatusConflict)
		return
	}
	conn, err := c.cfg.Gate.Accept(w, r)
	if err != nil {
		return
	}
	upstream, err := target.Dial(5 * time.Second)
	if err != nil {
		conn.Close(websocket.StatusInternalError, "Computer display unavailable")
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() {
		defer cancel()
		buf := make([]byte, 64*1024)
		for {
			n, err := upstream.Read(buf)
			if n > 0 {
				m.TouchDisplaySession(session)
				if conn.SendBinary(append([]byte(nil), buf[:n]...)) != nil {
					return
				}
			}
			if err != nil {
				if ctx.Err() == nil {
					conn.Close(websocket.StatusGoingAway, "Computer display closed")
				}
				return
			}
		}
	}()
	for {
		_, data, err := conn.Read(ctx)
		if err != nil {
			break
		}
		if !m.DisplaySessionActive(userKey, token, session) {
			conn.Close(websocket.StatusPolicyViolation, "Computer control changed")
			break
		}
		m.TouchComputerActivity(userKey)
		m.TouchDisplaySession(session)
		if _, err := upstream.Write(data); err != nil {
			conn.Close(websocket.StatusInternalError, "Computer display unavailable")
			break
		}
	}
	cancel()
	_ = upstream.Close()
	conn.Terminate()
}

func (c *ComputerAPI) acquire(r *http.Request, user int64, sess *sessionx.Session) (any, error) {
	m := c.cfg.Manager
	target := deviceTarget(r)
	if existing := m.ControlLease(key(user), target); existing != nil && existing.OwnerType == "agent" {
		for _, owner := range existing.OwnerIDs {
			if c.cfg.Runs != nil && c.cfg.Runs.RunRunning(owner) {
				place := "cloud"
				if existing.Provider == runtime.ProviderLocal {
					place = "local"
				}
				if !c.cfg.Runs.PauseRun(owner, user, fmt.Sprintf("User took control of the %s computer.", place)) {
					return nil, &httpError{409, "The active agent cannot be paused at this moment.", "COMPUTER_AGENT_NOT_PAUSABLE"}
				}
			} else {
				m.ReleaseControl(key(user), owner, target)
			}
		}
		m.ReleaseControl(key(user), "", target)
	}
	return m.AcquireControl(key(user), "user", "session:"+sess.ID(), target)
}

func (c *ComputerAPI) release(r *http.Request, user int64, sess *sessionx.Session) (any, error) {
	return map[string]any{"released": c.cfg.Manager.ReleaseControl(key(user), "session:"+sess.ID(), deviceTarget(r))}, nil
}

func (c *ComputerAPI) teach() (Teach, error) {
	if c.cfg.Teach == nil {
		return nil, &httpError{503, "Teach Mode is unavailable.", ""}
	}
	return c.cfg.Teach, nil
}

func (c *ComputerAPI) teachStatus(_ *http.Request, user int64, _ *sessionx.Session) (any, error) {
	t, err := c.teach()
	if err != nil {
		return nil, err
	}
	if summary, ok := t.ActiveSummary(key(user)); ok {
		return summary, nil
	}
	return map[string]any{"status": "idle"}, nil
}

func (c *ComputerAPI) teachStart(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	t, err := c.teach()
	if err != nil {
		return nil, err
	}
	m := c.cfg.Manager
	if m.ComputerProvider(key(user)) != runtime.ProviderCloud {
		return nil, &httpError{409, "Teach Mode currently requires the cloud computer.", "TEACH_MODE_CLOUD_REQUIRED"}
	}
	if _, err := m.Start(r.Context(), key(user), ""); err != nil {
		return nil, err
	}
	if lease := m.ControlLease(key(user), runtime.ProviderCloud); lease != nil && lease.OwnerType == "user" {
		m.ReleaseControl(key(user), lease.OwnerID, runtime.ProviderCloud)
	}
	b := body(r)
	agent := jsString(b["agentId"])
	if agent == "" {
		agent = jsString(b["agent_id"])
	}
	return t.StartSession(r.Context(), key(user), teach.StartInput{Goal: jsString(b["goal"]), AgentID: agent})
}

func (c *ComputerAPI) teachEvents(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	t, err := c.teach()
	if err != nil {
		return nil, err
	}
	return t.Record(r.Context(), key(user), body(r))
}

func (c *ComputerAPI) teachStop(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	t, err := c.teach()
	if err != nil {
		return nil, err
	}
	return t.StopSession(r.Context(), key(user), r.PathValue("sessionId"))
}

func (c *ComputerAPI) teachCancel(w http.ResponseWriter, r *http.Request) {
	user, _, ok := userFrom(r)
	if !ok {
		httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
		return
	}
	if c.cfg.Manager == nil {
		c.sendError(w, &httpError{503, "Computer runtime is unavailable.", ""})
		return
	}
	t, err := c.teach()
	if err != nil {
		c.sendError(w, err)
		return
	}
	cancelled := t.Cancel(key(user), r.PathValue("sessionId"))
	status := http.StatusOK
	if !cancelled {
		status = http.StatusNotFound
	}
	httpx.WriteJSON(w, status, map[string]any{"cancelled": cancelled})
}

func (c *ComputerAPI) guest(r *http.Request, user int64, method, path string, payload any, o runtime.RequestOptions) (*runtime.Object, error) {
	return c.cfg.Manager.RequestComputer(r.Context(), key(user), method, path, payload, deviceTarget(r), o)
}

func (c *ComputerAPI) files(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	p := r.URL.Query().Get("path")
	if p == "" {
		p = "."
	}
	return c.guest(r, user, http.MethodGet, "/workspace/files?path="+url.QueryEscape(p), nil, runtime.RequestOptions{})
}

func (c *ComputerAPI) fileContent(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	return c.guest(r, user, http.MethodGet, "/workspace/files/content?path="+url.QueryEscape(r.URL.Query().Get("path")), nil, runtime.RequestOptions{})
}

func (c *ComputerAPI) putFileContent(r *http.Request, user int64, sess *sessionx.Session) (any, error) {
	if err := c.requireUserControl(r, user, sess); err != nil {
		return nil, err
	}
	b := body(r)
	content := ""
	if v, ok := b["content"]; ok && v != nil {
		if s, isString := v.(string); isString {
			content = s
		} else {
			raw, _ := json.Marshal(v)
			content = string(raw)
		}
	}
	if len(content) > maxEditBytes {
		return nil, &httpError{400, "File is too large to edit.", ""}
	}
	return c.guest(r, user, http.MethodPut, "/workspace/files/content", map[string]any{"path": jsString(b["path"]), "content": content}, runtime.RequestOptions{})
}

func (c *ComputerAPI) download(w http.ResponseWriter, r *http.Request) {
	user, _, ok := userFrom(r)
	if !ok {
		httpx.WriteJSON(w, http.StatusUnauthorized, map[string]any{"error": "Unauthorized"})
		return
	}
	if c.cfg.Manager == nil {
		c.sendError(w, &httpError{503, "Computer runtime is unavailable.", ""})
		return
	}
	result, err := c.guest(r, user, http.MethodGet, "/workspace/files/download?path="+url.QueryEscape(r.URL.Query().Get("path")), nil, runtime.RequestOptions{MaxResponseBytes: 24 << 20})
	if err != nil {
		c.sendError(w, err)
		return
	}
	encoded := result.String("content")
	content, _ := base64.StdEncoding.DecodeString(encoded)
	contentType := result.String("contentType")
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	filename := result.String("filename")
	if filename == "" {
		filename = "download"
	}
	w.Header().Set("Cache-Control", "private, no-store")
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Content-Disposition", "attachment; filename*=UTF-8''"+encodeURIComponent(filename))
	w.Header().Set("Content-Length", strconv.Itoa(len(content)))
	_, _ = w.Write(content)
}

// encodeURIComponent escapes like JavaScript's encodeURIComponent.
func encodeURIComponent(s string) string {
	const keep = "-_.!~*'()"
	var b strings.Builder
	for _, c := range []byte(s) {
		if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || strings.IndexByte(keep, c) >= 0 {
			b.WriteByte(c)
		} else {
			fmt.Fprintf(&b, "%%%02X", c)
		}
	}
	return b.String()
}

func (c *ComputerAPI) desktop(r *http.Request, user int64) (runtime.Desktop, error) {
	return c.cfg.Manager.Desktop(key(user), deviceTarget(r))
}

func (c *ComputerAPI) desktopScreenshot(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	d, err := c.desktop(r, user)
	if err != nil {
		return nil, err
	}
	return d.Screenshot(r.Context())
}

func (c *ComputerAPI) desktopObserve(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	d, err := c.desktop(r, user)
	if err != nil {
		return nil, err
	}
	return d.Observe(r.Context())
}

func (c *ComputerAPI) controlledDesktop(r *http.Request, user int64, sess *sessionx.Session) (runtime.Desktop, error) {
	if err := c.requireUserControl(r, user, sess); err != nil {
		return nil, err
	}
	return c.desktop(r, user)
}

func (c *ComputerAPI) desktopClick(r *http.Request, user int64, sess *sessionx.Session) (any, error) {
	d, err := c.controlledDesktop(r, user, sess)
	if err != nil {
		return nil, err
	}
	b := body(r)
	return d.ClickPoint(r.Context(), b["x"], b["y"], b["button"])
}

func (c *ComputerAPI) desktopType(r *http.Request, user int64, sess *sessionx.Session) (any, error) {
	d, err := c.controlledDesktop(r, user, sess)
	if err != nil {
		return nil, err
	}
	b := body(r)
	return d.TypeText(r.Context(), jsString(b["text"]), b["pressEnter"] == true)
}

func (c *ComputerAPI) desktopKey(r *http.Request, user int64, sess *sessionx.Session) (any, error) {
	d, err := c.controlledDesktop(r, user, sess)
	if err != nil {
		return nil, err
	}
	return d.PressKey(r.Context(), jsString(body(r)["key"]))
}

func (c *ComputerAPI) desktopLaunch(r *http.Request, user int64, sess *sessionx.Session) (any, error) {
	d, err := c.controlledDesktop(r, user, sess)
	if err != nil {
		return nil, err
	}
	return d.LaunchApp(r.Context(), jsString(body(r)["app"]))
}

func (c *ComputerAPI) shell(r *http.Request, user int64, sess *sessionx.Session) (any, error) {
	if err := c.requireUserControl(r, user, sess); err != nil {
		return nil, err
	}
	b := body(r)
	o := runtime.ExecOptions{Cwd: jsString(b["cwd"]), PTY: b["pty"] == true}
	if o.Cwd == "" {
		// The interactive terminal runs in the agent workspace unless pinned.
		o.Cwd = runtime.WorkspaceDir
	}
	if t, ok := b["timeout"].(float64); ok {
		o.TimeoutMs = t
	}
	if s, ok := b["stdinInput"].(string); ok {
		o.StdinInput = &s
	}
	return c.cfg.Manager.ExecuteCommand(r.Context(), key(user), jsString(b["command"]), deviceTarget(r), o)
}

const maxCommandOutputBytes = 16 * 1024 * 1024

var sha256Hex = regexp.MustCompile(`^[a-f0-9]{64}$`)

// localCommandOutput receives the full output of a command a desktop
// companion is running, checked against its length and SHA-256.
func (c *ComputerAPI) localCommandOutput(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	if !strings.HasPrefix(strings.ToLower(r.Header.Get("Content-Type")), "application/octet-stream") {
		return nil, &httpError{400, "Content-Type must be application/octet-stream.", ""}
	}
	header := func(name string) (string, error) {
		v := strings.TrimSpace(r.Header.Get(name))
		if v == "" || len(v) > 256 {
			return "", &httpError{400, name + " is required.", ""}
		}
		return v, nil
	}
	deviceID, err := header("x-neoagent-device-id")
	if err != nil {
		return nil, err
	}
	commandID, err := header("x-neoagent-command-id")
	if err != nil {
		return nil, err
	}
	if c.cfg.Devices == nil || c.cfg.Artifacts == nil {
		return nil, &httpError{503, "Desktop command output storage is unavailable.", "COMMAND_OUTPUT_UPLOAD_INVALID"}
	}
	claim, ok := c.cfg.Devices.ClaimCommandOutput(user, deviceID, commandID)
	if !ok {
		return nil, &httpError{409, "Command output is not tied to an active desktop command.", "COMMAND_OUTPUT_NOT_PENDING"}
	}
	stored, err := func() (runtime.StoredArtifact, error) {
		expected, perr := strconv.ParseInt(strings.TrimSpace(r.Header.Get("Content-Length")), 10, 64)
		if perr != nil || expected <= 0 {
			return runtime.StoredArtifact{}, &httpError{400, "A positive Content-Length is required.", "COMMAND_OUTPUT_UPLOAD_INVALID"}
		}
		if expected > maxCommandOutputBytes {
			return runtime.StoredArtifact{}, &httpError{413, "Command output exceeds the 16 MiB artifact limit.", "COMMAND_OUTPUT_UPLOAD_INVALID"}
		}
		checksum := strings.ToLower(strings.TrimSpace(r.Header.Get("x-neoagent-output-sha256")))
		if !sha256Hex.MatchString(checksum) {
			return runtime.StoredArtifact{}, &httpError{400, "A SHA-256 command output checksum is required.", "COMMAND_OUTPUT_UPLOAD_INVALID"}
		}
		data, rerr := io.ReadAll(io.LimitReader(r.Body, expected+1))
		if rerr != nil {
			return runtime.StoredArtifact{}, rerr
		}
		if int64(len(data)) > expected {
			return runtime.StoredArtifact{}, &httpError{413, "Command output byte count exceeded Content-Length.", "COMMAND_OUTPUT_UPLOAD_INVALID"}
		}
		if int64(len(data)) != expected {
			return runtime.StoredArtifact{}, &httpError{400, "Command output byte count did not match Content-Length.", "COMMAND_OUTPUT_UPLOAD_INVALID"}
		}
		sum := sha256.Sum256(data)
		if hex.EncodeToString(sum[:]) != checksum {
			return runtime.StoredArtifact{}, &httpError{400, "Command output checksum mismatch.", "COMMAND_OUTPUT_CHECKSUM_MISMATCH"}
		}
		complete := r.Header.Get("x-neoagent-output-complete") != "false"
		stdout, _ := strconv.ParseFloat(r.Header.Get("x-neoagent-stdout-bytes"), 64)
		stderr, _ := strconv.ParseFloat(r.Header.Get("x-neoagent-stderr-bytes"), 64)
		return c.cfg.Artifacts.CreateBufferArtifact(r.Context(), key(user), runtime.Artifact{
			Kind: "command-output", Backend: "desktop-companion", Extension: "log", ContentType: "text/plain; charset=utf-8",
			FilenameBase: "command-output", Content: data,
			Metadata: map[string]any{"deviceId": claim.DeviceID, "sessionId": claim.SessionID, "commandId": claim.CommandID,
				"runId": claim.RunID, "stepId": claim.StepID, "stdoutBytes": stdout, "stderrBytes": stderr, "complete": complete},
		})
	}()
	if err != nil {
		c.cfg.Devices.FinishCommandOutput(user, deviceID, commandID, false)
		return nil, err
	}
	if !c.cfg.Devices.FinishCommandOutput(user, deviceID, commandID, true) {
		return nil, &httpError{409, "Desktop command disconnected before output transfer completed.", "COMMAND_OUTPUT_DISCONNECTED"}
	}
	complete := r.Header.Get("x-neoagent-output-complete") != "false"
	return createdResult{runtime.NewObject("outputArtifact", runtime.NewObject("artifactId", stored.ID, "url", stored.URL, "byteSize", stored.ByteSize, "complete", complete))}, nil
}

// createdResult answers 201 Created.
type createdResult struct{ body any }

func (c *ComputerAPI) browser(r *http.Request, user int64) (runtime.Browser, error) {
	return c.cfg.Manager.Browser(r.Context(), key(user), deviceTarget(r))
}

func (c *ComputerAPI) browserStatus(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	b, err := c.browser(r, user)
	if err != nil {
		return nil, err
	}
	status, err := b.Status(r.Context())
	if err != nil {
		return nil, err
	}
	var pageInfo any
	if v, ok := status.Get("pageInfo"); ok {
		pageInfo = v
	}
	var headless bool
	headless = !(status.Decode("headless", &headless) && !headless)
	return runtime.NewObject("launched", status.Bool("launched"), "pages", status.Float("pages"), "headless", headless, "pageInfo", pageInfo), nil
}

func (c *ComputerAPI) controlledBrowser(r *http.Request, user int64, sess *sessionx.Session) (runtime.Browser, error) {
	if err := c.requireUserControl(r, user, sess); err != nil {
		return nil, err
	}
	return c.browser(r, user)
}

func (c *ComputerAPI) browserNavigate(r *http.Request, user int64, sess *sessionx.Session) (any, error) {
	b, err := c.controlledBrowser(r, user, sess)
	if err != nil {
		return nil, err
	}
	in := body(r)
	return b.Navigate(r.Context(), jsString(in["url"]), map[string]any{"waitFor": in["waitFor"]})
}

func (c *ComputerAPI) browserClick(r *http.Request, user int64, sess *sessionx.Session) (any, error) {
	b, err := c.controlledBrowser(r, user, sess)
	if err != nil {
		return nil, err
	}
	in := body(r)
	return b.Click(r.Context(), in["selector"], in["text"], in["screenshot"] != false)
}

func (c *ComputerAPI) browserType(r *http.Request, user int64, sess *sessionx.Session) (any, error) {
	b, err := c.controlledBrowser(r, user, sess)
	if err != nil {
		return nil, err
	}
	in := body(r)
	return b.TypeText(r.Context(), jsString(in["text"]), map[string]any{"pressEnter": in["pressEnter"] == true, "screenshot": in["screenshot"] != false})
}

func (c *ComputerAPI) browserScreenshot(r *http.Request, user int64, _ *sessionx.Session) (any, error) {
	b, err := c.browser(r, user)
	if err != nil {
		return nil, err
	}
	in := body(r)
	return b.Screenshot(r.Context(), map[string]any{"fullPage": in["fullPage"] == true, "selector": in["selector"]})
}
