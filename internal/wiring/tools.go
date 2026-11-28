package wiring

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/handlers"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/systemone"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neoagent/internal/android"
	"github.com/NeoLabs-Systems/neoagent/internal/artifacts"
	"github.com/NeoLabs-Systems/neoagent/internal/cloudsec"
	"github.com/NeoLabs-Systems/neoagent/internal/credentials"
	"github.com/NeoLabs-Systems/neoagent/internal/gitproxy"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/mcpserver"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/mobilesync"
	"github.com/NeoLabs-Systems/neoagent/internal/neorouterapi"
	"github.com/NeoLabs-Systems/neoagent/internal/ocr"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neoagent/internal/skills"
	"github.com/NeoLabs-Systems/neoagent/internal/socialreach"
	"github.com/NeoLabs-Systems/neoagent/internal/socialvideo"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neoagent/internal/voice"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace/repotools"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/llm/openaiimages"
)

// toolSources are the domain services the agent's tools use. Any may be nil;
// the tools that need it then answer that it is unavailable.
type toolSources struct {
	DB           *dbx.DB
	Engine       handlers.Engine
	Tools        *tools.Registry
	Computer     *runtime.Manager
	Android      *android.Host
	Memory       *memory.Manager
	Messaging    *messaging.Manager
	Tasks        *tasks.Runtime
	Skills       *skills.Runner
	MCP          *mcpserver.Manager
	Integrations *integrations.Manager
	Credentials  *credentials.Broker
	Workspaces   *workspace.Manager
	Artifacts    *artifacts.Store
	Router       *neorouterapi.Service
	Health       *mobilesync.Health
	SocialVideo  *socialvideo.Service
	SocialReach  *socialreach.Service
	SystemOne    *systemone.Service
	GitProxy     *gitproxy.Proxy
	// InferStructured asks the fast model for a JSON object (browser_act's
	// field values); the engine provides it.
	InferStructured func(ctx context.Context, userID int64, agentID, system, prompt string, maxTokens int) (dyn.Map, error)
	// Transcribe is speech-to-text of an audio file.
	Transcribe func(ctx context.Context, userID int64, agentID, path string) (string, error)
	// AnalyzeImage asks a vision model about an image; the engine provides it.
	AnalyzeImage func(ctx context.Context, userID int64, agentID, path, question string) (any, error)
	// Behavior delivers replies through the messaging behavior pipeline.
	Behavior handlers.BehaviorPipeline
	// Settings and SettingsModels back settings_read/update/link.
	Settings       *settings.Store
	SettingsModels settings.AssistantModels
	// Emit sends a socket event to a user's clients.
	Emit func(userID int64, event string, payload any)
	// PublicBaseURL is how browsers reach this server.
	PublicBaseURL func() string
	// Calls rings the user's apps for call_user.
	Calls *voice.Coordinator
	// Embed is a text embedding for code_navigate's semantic mode, nil when
	// no embedding provider answers.
	Embed   func(ctx context.Context, text string) ([]float32, error)
	Getenv  func(string) string
	Version string
}

// buildToolBackend turns the domain services into the tool backend.
func buildToolBackend(s toolSources) *handlers.Backend {
	getenv := s.Getenv
	if getenv == nil {
		getenv = os.Getenv
	}
	d := handlers.Deps{
		Engine:         s.Engine,
		DB:             s.DB,
		Tools:          s.Tools,
		BraveSearchKey: getenv("BRAVE_SEARCH_API_KEY"),
		HTTP:           &handlers.HTTPRequester{UserAgent: "NeoAgent/" + s.Version, AllowPrivate: getenv("NEOAGENT_HTTP_ALLOW_PRIVATE") == "true"},
		URLCheck: func(ctx context.Context, raw string) (bool, string) {
			r, err := cloudsec.Checker{}.Validate(ctx, raw)
			if err != nil {
				return false, err.Error()
			}
			return r.Allowed, r.Reason
		},
	}
	if s.Computer != nil {
		d.Runtime = toolRuntime{m: s.Computer, android: s.Android}
		d.Workspace = &handlers.ComputerWorkspace{
			Request: func(ctx context.Context, userID int64, method, path string, body any, deviceTarget string) (dyn.Map, error) {
				return guestMap(s.Computer.RequestComputer(ctx, userKey(userID), method, path, body, deviceTarget, runtime.RequestOptions{}))
			},
			Resolve: resolverOf(s.Workspaces),
		}
	}
	if s.Memory != nil {
		d.Memory = toolMemory{m: s.Memory}
	}
	if s.Messaging != nil {
		d.Messaging = toolMessaging{m: s.Messaging, mem: s.Memory, db: s.DB}
	}
	if s.Tasks != nil {
		d.Tasks = toolTasks{r: s.Tasks}
	}
	if s.Skills != nil {
		d.Skills = toolSkills{r: s.Skills}
	}
	if s.MCP != nil {
		d.MCP = toolMCP{m: s.MCP}
	}
	if s.Integrations != nil {
		d.Integrations = toolIntegrations{m: s.Integrations, artifacts: s.Artifacts, workspaces: s.Workspaces}
	}
	if s.Credentials != nil {
		d.Credentials = toolCredentials{b: s.Credentials}
	}
	if s.Artifacts != nil {
		d.Artifacts = toolArtifacts{s: s.Artifacts}
	}
	if s.Router != nil {
		d.Router = toolRouter{s: s.Router}
	}
	d.Media = toolMedia{transcribe: s.Transcribe, analyze: s.AnalyzeImage, xai: xaiImages(getenv)}
	if s.Behavior != nil {
		d.Behavior = s.Behavior
	}
	if s.Health != nil {
		d.Health = toolHealth{h: s.Health}
	}
	if s.SocialVideo != nil {
		d.SocialVideo = toolSocialVideo{s: s.SocialVideo}
	}
	if s.SocialReach != nil {
		d.SocialReach = s.SocialReach
	}
	if s.SystemOne != nil {
		d.SystemOne = toolSystemOne{s: s.SystemOne, infer: s.InferStructured}
	}
	if s.Workspaces != nil {
		d.Structured = toolStructured{w: s.Workspaces}
	}
	if s.GitProxy != nil {
		d.GitEnv = func(ctx context.Context, run *handlers.Run, guestHost string, ttl time.Duration) (map[string]string, error) {
			return s.GitProxy.GuestEnv(ctx, gitproxy.GuestEnvRequest{UserID: run.UserID, AgentID: run.AgentID, RunID: run.RunID, GuestHost: guestHost, TTL: ttl})
		}
	}
	addToolExtras(&d, s, getenv)
	return handlers.New(d)
}

func userKey(userID int64) string { return strconv.FormatInt(userID, 10) }

func resolverOf(w *workspace.Manager) func(int64, string, string) (string, error) {
	if w == nil {
		return nil
	}
	return func(userID int64, path, label string) (string, error) {
		return w.ResolvePath(userKey(userID), path, label)
	}
}

// toMap reads any JSON-shaped value as an object.
func toMap(v any) dyn.Map {
	raw, err := json.Marshal(v)
	if err != nil {
		return nil
	}
	var m dyn.Map
	_ = json.Unmarshal(raw, &m)
	return m
}

func toAny(v any) any {
	raw, err := json.Marshal(v)
	if err != nil {
		return nil
	}
	var out any
	_ = json.Unmarshal(raw, &out)
	return out
}

// toolRuntime is the user's computer and Android device.
type toolRuntime struct {
	m       *runtime.Manager
	android *android.Host
}

func (r toolRuntime) ExecuteCommand(ctx context.Context, userID int64, command string, o handlers.CommandOptions) (dyn.Map, error) {
	opts := runtime.ExecOptions{Cwd: o.Cwd, TimeoutMs: float64(o.Timeout.Milliseconds()), PTY: o.PTY, Inputs: o.Inputs, Env: o.Env, RunID: o.RunID, StepID: o.StepID}
	if o.StdinInput != nil {
		s := dyn.String(o.StdinInput)
		opts.StdinInput = &s
	}
	return guestMap(r.m.ExecuteCLICommand(ctx, userKey(userID), command, o.DeviceTarget, opts))
}

func (r toolRuntime) GuestHostAddress(int64, string) string { return r.m.GuestHostAddress() }

func (r toolRuntime) Browser(ctx context.Context, userID int64, deviceTarget string) (handlers.Browser, string, error) {
	p, err := r.m.Browser(ctx, userKey(userID), deviceTarget)
	if err != nil {
		return nil, "", err
	}
	if p == nil {
		return nil, "vm", nil
	}
	return toolBrowser{p: p}, "vm", nil
}

func (r toolRuntime) Android(ctx context.Context, userID int64) (handlers.Device, error) {
	if r.android == nil {
		return nil, errors.New("Android provider is unavailable. VM runtime is required.")
	}
	svc, err := r.android.AndroidFor(ctx, userID)
	if err != nil {
		return nil, err
	}
	return toolAndroid{s: svc}, nil
}

func (r toolRuntime) Desktop(_ context.Context, userID int64, deviceTarget string) (handlers.Device, error) {
	p, err := r.m.Desktop(userKey(userID), deviceTarget)
	if err != nil || p == nil {
		return nil, err
	}
	return toolDesktop{p: p}, nil
}

func (r toolRuntime) AcquireControl(userID int64, owner, id, deviceTarget string) error {
	_, err := r.m.AcquireControl(userKey(userID), owner, id, deviceTarget)
	return err
}

// toolBrowser is the computer's browser.
type toolBrowser struct{ p runtime.Browser }

func (b toolBrowser) Navigate(ctx context.Context, url string, o dyn.Map) (dyn.Map, error) {
	return guestMap(b.p.Navigate(ctx, url, o))
}
func (b toolBrowser) Click(ctx context.Context, selector, text any, screenshot bool) (dyn.Map, error) {
	return guestMap(b.p.Click(ctx, selector, text, screenshot))
}

// Type fills a field (the Node VM provider's type posts /browser/fill).
func (b toolBrowser) Type(ctx context.Context, selector, text any, o dyn.Map) (dyn.Map, error) {
	value := ""
	if text != nil {
		value = dyn.String(text)
	}
	return guestMap(b.p.Fill(ctx, selector, value, o))
}
func (b toolBrowser) Extract(ctx context.Context, selector, attribute, all any) (dyn.Map, error) {
	return guestMap(b.p.Extract(ctx, selector, attribute, dyn.Truthy(all)))
}
func (b toolBrowser) Screenshot(ctx context.Context, o dyn.Map) (dyn.Map, error) {
	return guestMap(b.p.Screenshot(ctx, o))
}
func (b toolBrowser) Evaluate(ctx context.Context, script string) (dyn.Map, error) {
	return guestMap(b.p.Evaluate(ctx, script))
}
func (b toolBrowser) PressKey(ctx context.Context, key string, screenshot bool) (dyn.Map, error) {
	return guestMap(b.p.PressKey(ctx, key, screenshot))
}
func (b toolBrowser) Scroll(ctx context.Context, dx, dy int, screenshot bool) (dyn.Map, error) {
	return guestMap(b.p.Scroll(ctx, dx, dy, screenshot))
}

// toolDesktop maps the desktop tools' controller calls.
type toolDesktop struct{ p runtime.Desktop }

func (d toolDesktop) Call(ctx context.Context, method string, a dyn.Map) (any, error) {
	switch method {
	case "observe":
		return d.p.Observe(ctx)
	case "clickPoint":
		return d.p.ClickPoint(ctx, a["x"], a["y"], a["button"])
	case "drag":
		return d.p.Drag(ctx, a["x1"], a["y1"], a["x2"], a["y2"], a["durationMs"])
	case "scroll":
		return d.p.Scroll(ctx, a["deltaX"], a["deltaY"])
	case "typeText":
		return d.p.TypeText(ctx, dyn.Str(a["text"]), a["pressEnter"] == true)
	case "pressKey":
		return d.p.PressKey(ctx, dyn.Str(a["key"]))
	case "launchApp":
		return d.p.LaunchApp(ctx, dyn.Str(a["app"]))
	case "getAccessibilityTree":
		return d.p.AccessibilityTree(ctx)
	}
	return nil, fmt.Errorf("unknown desktop method %s", method)
}

// toolAndroid maps the Android tools' controller calls.
type toolAndroid struct{ s android.Service }

func (a toolAndroid) Call(ctx context.Context, method string, args dyn.Map) (any, error) {
	p := android.Params(args)
	includeNodes := args["includeNodes"] != false
	switch method {
	case "startEmulator":
		var opts android.StartOptions
		if h, ok := args["headless"].(bool); ok {
			opts.Headless = &h
		}
		if c, ok := a.s.(interface {
			StartEmulator(context.Context, android.StartOptions, time.Duration) (any, error)
		}); ok {
			timeout := 240 * time.Second
			if ms, ok := dyn.Float(args["timeoutMs"]); ok && ms > 0 {
				timeout = time.Duration(min(max(ms, 1000), 600000)) * time.Millisecond
			}
			return c.StartEmulator(ctx, opts, timeout)
		}
		return a.s.RequestStartEmulator(ctx, opts)
	case "stopEmulator":
		return a.s.StopEmulator(ctx)
	case "listDevices":
		return a.s.ListDevices(ctx)
	case "openApp":
		return a.s.OpenApp(ctx, p)
	case "openIntent":
		return a.s.OpenIntent(ctx, p)
	case "tap":
		return a.s.Tap(ctx, p)
	case "longPress":
		return a.s.LongPress(ctx, p)
	case "type":
		return a.s.Type(ctx, p)
	case "swipe":
		return a.s.Swipe(ctx, p)
	case "pressKey":
		return a.s.PressKey(ctx, dyn.Str(args["key"]))
	case "waitFor":
		return a.s.WaitFor(ctx, p)
	case "observe":
		return a.s.Observe(ctx, includeNodes)
	case "dumpUi":
		return a.s.DumpUI(ctx, includeNodes)
	case "screenshot":
		return a.s.Screenshot(ctx)
	case "listApps":
		return a.s.ListApps(ctx, args["includeSystem"] == true)
	case "installApk":
		return a.s.InstallAPK(ctx, dyn.Str(args["apkPath"]))
	case "shell":
		req := android.ShellRequest{Command: dyn.Str(args["command"]), Screenshot: args["screenshot"] == true}
		if ms, ok := dyn.Float(args["timeoutMs"]); ok && ms > 0 {
			req.Timeout = time.Duration(ms) * time.Millisecond
		}
		return a.s.Shell(ctx, req)
	}
	return nil, fmt.Errorf("unknown Android method %s", method)
}

// toolMemory is the memory manager.
type toolMemory struct{ m *memory.Manager }

func (t toolMemory) SaveMemory(ctx context.Context, userID int64, agentID, content, category string, importance float64, o handlers.MemorySave) (string, error) {
	opts := memory.SaveOptions{AgentID: agentID, Replaces: o.Replaces, Confidence: o.Confidence, StaleAfterDays: o.StaleAfterDays}
	if o.Metadata != nil {
		opts.Metadata = jsx.ParseObject(dyn.Stringify(o.Metadata))
	}
	return t.m.SaveMemory(ctx, userID, content, category, importance, opts)
}

func (t toolMemory) FindSimilar(ctx context.Context, userID int64, agentID, content, excludeID string) ([]any, error) {
	list, err := t.m.FindSimilarMemories(ctx, userID, content, agentID, nil, excludeID, 0)
	if err != nil {
		return nil, err
	}
	out, _ := toAny(list).([]any)
	return out, nil
}

func (t toolMemory) OwnedMemoryIDs(ctx context.Context, userID int64, agentID string, ids []string) ([]string, error) {
	return t.m.OwnedMemoryIDs(ctx, userID, agentID, ids)
}

func (t toolMemory) Recall(ctx context.Context, userID int64, agentID, query string, limit int, validAt string, includeHistory bool) ([]any, error) {
	list, err := t.m.RecallMemory(ctx, userID, query, limit, memory.RecallOptions{AgentID: agentID, ValidAt: validAt, IncludeHistory: includeHistory})
	if err != nil {
		return nil, err
	}
	out, _ := toAny(list).([]any)
	return out, nil
}

func (t toolMemory) List(ctx context.Context, userID int64, agentID string, offset, limit int) ([]dyn.Map, error) {
	list, err := t.m.ListMemories(ctx, userID, memory.ListOptions{AgentID: agentID, Offset: offset, Limit: limit})
	if err != nil {
		return nil, err
	}
	out := make([]dyn.Map, len(list))
	for i, m := range list {
		out[i] = toMap(m)
	}
	return out, nil
}

func (t toolMemory) Archive(ctx context.Context, userID int64, ids []string) (int64, error) {
	return t.m.ArchiveMemories(ctx, ids, true, userID)
}

func (t toolMemory) SearchConversations(ctx context.Context, userID int64, agentID, query string, sessions int) ([]any, error) {
	list, err := t.m.SearchConversations(ctx, userID, query, memory.SearchConversationsOptions{AgentID: agentID, Sessions: sessions})
	if err != nil {
		return nil, err
	}
	out, _ := toAny(list).([]any)
	return out, nil
}

func (t toolMemory) UpdateCore(ctx context.Context, userID int64, agentID, key, value string) error {
	return t.m.UpdateCore(ctx, userID, agentID, key, value)
}

func (toolMemory) CoreKeys() []string  { return memory.CoreKeys }
func (toolMemory) MaxMemoryChars() int { return memory.MaxMemoryChars }

func (t toolMemory) AppendDailyLog(userID int64, content string) (string, error) {
	return t.m.AppendDailyLog(content, userID)
}

func (t toolMemory) SetAPIKey(userID int64, service, key string) error {
	return t.m.SetAPIKey(userID, service, key)
}

func (t toolMemory) ReadDailyLog(userID int64, date *time.Time) (string, error) {
	day := time.Now()
	if date != nil {
		day = *date
	}
	return t.m.ReadDailyLog(day, userID)
}

func (t toolMemory) ListDailyLogs(userID int64, limit int) (any, error) {
	logs, err := t.m.ListDailyLogs(limit, userID)
	if err != nil {
		return nil, err
	}
	return toAny(logs), nil
}

func (t toolMemory) APIKeyNames(userID int64) ([]string, error) {
	keys, err := t.m.ReadAPIKeys(userID)
	if err != nil || keys == nil {
		return nil, err
	}
	return keys.Keys(), nil
}

// toolMessaging is the messaging manager.
type toolMessaging struct {
	m   *messaging.Manager
	mem *memory.Manager
	db  *dbx.DB
}

// messageMedia resolves message attachments to the user's own artifacts and
// workspace files (resolveUserFileReference of the Node manager).
type messageMedia struct {
	artifacts  *artifacts.Store
	workspaces *workspace.Manager
}

func (f messageMedia) Resolve(ctx context.Context, userID int64, reference string) (string, error) {
	var store handlers.Artifacts
	if f.artifacts != nil {
		store = toolArtifacts{s: f.artifacts}
	}
	var ws handlers.Workspace
	if f.workspaces != nil {
		ws = &handlers.ComputerWorkspace{Resolve: resolverOf(f.workspaces)}
	}
	return handlers.ResolveUserFile(ctx, store, ws, userID, reference, "Message attachment")
}

func (t toolMessaging) Send(ctx context.Context, userID int64, agentID, platform, to, content, mediaRef, runID string, persist bool) (dyn.Map, error) {
	result, err := t.m.SendAgentMessage(ctx, messaging.AgentSend{
		UserID: userID, AgentID: agentID, Platform: platform, To: to, Content: content,
		MediaReference: mediaRef, RunID: runID,
	})
	if err != nil {
		var se *messaging.SendError
		if errors.As(err, &se) && se.Ambiguous {
			return dyn.Map{"success": false, "error": se.Msg, "deliveryAmbiguous": true}, nil
		}
		return nil, err
	}
	if persist && result["suppressed"] != true && t.db != nil {
		if err := t.persistConversation(ctx, userID, agentID, platform, to, messaging.NormalizeOutgoingMessage(platform, content, false)); err != nil {
			return nil, err
		}
	}
	return result, nil
}

// persistConversation records a task's message in the chat's conversation,
// found under any address of the chat (WhatsApp LID or number).
func (t toolMessaging) persistConversation(ctx context.Context, userID int64, agentID, platform, to, content string) error {
	id, err := t.m.ConversationFor(ctx, userID, agentID, platform, to, "")
	if err != nil {
		return err
	}
	if _, err := t.db.W.ExecContext(ctx, `INSERT INTO conversation_messages (conversation_id, role, content) VALUES (?, ?, ?)`, id, "assistant", content); err != nil {
		return err
	}
	_, err = t.db.W.ExecContext(ctx, `UPDATE conversations SET updated_at = datetime('now') WHERE id = ?`, id)
	return err
}

func (t toolMessaging) OwnerDestination(userID int64, agentID, platform string) string {
	return t.m.OwnerDestination(context.Background(), userID, agentID, platform)
}

func (t toolMessaging) SupportsReactions(userID int64, agentID, platform string) bool {
	return t.m.SupportsReactions(context.Background(), userID, agentID, platform)
}

func (t toolMessaging) SendReaction(ctx context.Context, userID int64, agentID, platform, chatID, messageID, emoji, runID string) error {
	return t.m.SendReaction(ctx, userID, agentID, platform, chatID, messageID, emoji, runID)
}

func (t toolMessaging) PlatformStatus(ctx context.Context, userID int64, agentID, platform string) string {
	status, _ := t.m.GetPlatformStatus(ctx, userID, agentID, platform)["status"].(string)
	return status
}

func (t toolMessaging) FormatOutgoing(platform, content string) string {
	return messaging.NormalizeOutgoingMessage(platform, content, false)
}

// toolTasks is the task runtime.
type toolTasks struct{ r *tasks.Runtime }

func jsvObject(m dyn.Map) *jsv.Object {
	v, err := jsv.Decode([]byte(dyn.Stringify(m)))
	if err != nil {
		return jsv.NewObject()
	}
	o, _ := v.(*jsv.Object)
	if o == nil {
		return jsv.NewObject()
	}
	return o
}

// taskID reads a task id argument; a non-numeric id matches no task.
func taskID(v any) int64 {
	n := jsv.Number(v)
	if n != n || n != float64(int64(n)) {
		return -1
	}
	return int64(n)
}

func (t toolTasks) Create(ctx context.Context, userID int64, agentID string, task dyn.Map) (any, error) {
	return t.r.CreateTask(ctx, userID, agentID, jsvObject(task))
}

func (t toolTasks) List(ctx context.Context, userID int64, agentID string) ([]any, error) {
	list, err := t.r.ListTasks(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	out := make([]any, len(list))
	for i, o := range list {
		out[i] = o
	}
	return out, nil
}

func (t toolTasks) Delete(ctx context.Context, userID int64, id any) error {
	return t.r.DeleteTask(ctx, taskID(id), userID)
}

func (t toolTasks) Update(ctx context.Context, userID int64, id any, updates dyn.Map) (any, error) {
	return t.r.UpdateTask(ctx, taskID(id), userID, jsvObject(updates))
}

func (t toolTasks) ConfigHint(triggerType string) string {
	for _, a := range t.r.Adapters() {
		if a.Type == triggerType {
			return a.ConfigHint
		}
	}
	return ""
}

// toolSkills is the skill runner.
type toolSkills struct{ r *skills.Runner }

func skillMeta(m dyn.Map) skills.Meta {
	if m == nil {
		return skills.Meta{}
	}
	v, err := workspace.DecodeJSON([]byte(dyn.Stringify(m)))
	if err != nil {
		return skills.Meta{}
	}
	meta, _ := v.(workspace.Obj)
	return meta
}

func (t toolSkills) Create(ctx context.Context, userID int64, name, description, instructions string, metadata dyn.Map) (any, error) {
	return t.r.Create(ctx, userID, name, description, instructions, skillMeta(metadata))
}

func (t toolSkills) Get(userID int64, name string) (dyn.Map, bool) {
	s, ok := t.r.GetSkill(name, userID)
	if !ok {
		return nil, false
	}
	return dyn.Map{"name": s.Name, "description": s.Description, "metadata": toAny(s.Metadata), "instructions": s.Instructions}, true
}

func (t toolSkills) All(userID int64) []any {
	out := []any{}
	for _, s := range t.r.GetAll(userID) {
		var owner any
		if s.OwnerType == "user" || s.OwnerType == "legacy" {
			owner = s.UserID
		}
		out = append(out, dyn.Ordered{
			{Key: "name", Value: s.Name}, {Key: "description", Value: s.Description}, {Key: "metadata", Value: toAny(s.Metadata)},
			{Key: "enabled", Value: s.Enabled()}, {Key: "userId", Value: owner}, {Key: "ownerType", Value: s.OwnerType}, {Key: "readOnly", Value: s.ReadOnly},
		})
	}
	return out
}

func (t toolSkills) Update(ctx context.Context, userID int64, name string, description, instructions *string, metadata dyn.Map, hasMetadata bool) (any, error) {
	edit := skills.Edit{Description: description, Instructions: instructions}
	if hasMetadata {
		meta := skillMeta(metadata)
		edit.Metadata = &meta
	}
	return t.r.Update(ctx, userID, name, edit)
}

func (t toolSkills) Delete(ctx context.Context, userID int64, name string) (any, error) {
	return t.r.Delete(ctx, userID, name)
}

func (t toolSkills) Execute(ctx context.Context, run *handlers.Run, name string, args dyn.Map) (any, bool, error) {
	var agent *string
	if run.AgentID != "" {
		a := run.AgentID
		agent = &a
	}
	result, ok := t.r.Execute(ctx, name, skills.ToolCall{UserID: run.UserID, AgentID: agent, Args: skillMeta(args)})
	if !ok {
		return nil, false, nil
	}
	return result, true, nil
}

// toolMCP is the MCP client manager.
type toolMCP struct{ m *mcpserver.Manager }

func (t toolMCP) CallByName(_ context.Context, userID int64, agentID, name string, args dyn.Map) (any, bool, error) {
	result, found, err := t.m.CallToolByName(name, args, userID, agentID)
	return result, found, err
}

func (t toolMCP) Start(ctx context.Context, serverID int64, command, name string, userID int64, agentID string) ([]any, error) {
	r, err := t.m.Start(ctx, serverID, command, name, userID, agentID)
	if err != nil {
		return nil, err
	}
	out := make([]any, len(r.Tools))
	for i, tool := range r.Tools {
		out[i] = tool
	}
	return out, nil
}

func (t toolMCP) Stop(serverID int64) { t.m.Stop(serverID) }

func (t toolMCP) Status(userID int64, agentID string) map[int64]dyn.Map {
	out := map[int64]dyn.Map{}
	for id, s := range t.m.Status(userID, agentID) {
		m := dyn.Map{"status": s.Status, "toolCount": s.ToolCount, "consecutiveFails": s.ConsecutiveFails}
		if s.Error != "" {
			m["error"] = s.Error
		}
		if s.NextRetryAt != "" {
			m["nextRetryAt"] = s.NextRetryAt
		}
		out[id] = m
	}
	return out
}

// toolIntegrations is the official integrations manager.
type toolIntegrations struct {
	m          *integrations.Manager
	artifacts  *artifacts.Store
	workspaces *workspace.Manager
}

func (t toolIntegrations) Execute(ctx context.Context, run *handlers.Run, name string, args dyn.Map) (any, bool, error) {
	opts := integrations.ExecOptions{Run: integrations.Run{TriggerSource: run.TriggerSource, TaskID: run.TaskID, ScheduledAt: run.ScheduledAt}}
	if run.Public != nil {
		opts.Public = &integrations.PublicScope{ProviderKey: run.Public.ProviderKey, AppKey: run.Public.AppKey}
	}
	args, refusal := t.confineLocalPaths(ctx, run, name, args)
	if refusal != "" {
		return dyn.Map{"error": refusal}, true, nil
	}
	result, err := t.m.ExecuteTool(ctx, run.UserID, name, args, run.AgentID, opts)
	if err != nil {
		return nil, false, err
	}
	if f, ok := result.(*integrations.ToolFailure); ok && f.Error == "no_provider_support" {
		return nil, false, nil
	}
	return result, true, nil
}

// toolCredentials is the credential broker.
type toolCredentials struct{ b *credentials.Broker }

func (t toolCredentials) FillBrowser(ctx context.Context, userID int64, agentID string, args dyn.Map, runID string) (any, error) {
	return t.b.FillBrowser(ctx, userID, agentID, args, credentials.RunContext{RunID: runID})
}

func (t toolCredentials) SubmitProtected(ctx context.Context, userID int64, agentID string, fillID any, runID string) (any, error) {
	return t.b.SubmitProtected(ctx, userID, agentID, dyn.Str(fillID), credentials.RunContext{RunID: runID})
}

func (t toolCredentials) CancelProtected(ctx context.Context, userID int64, agentID string, fillID any, runID string) (any, error) {
	return t.b.CancelProtected(ctx, userID, agentID, dyn.Str(fillID), credentials.RunContext{RunID: runID})
}

func (t toolCredentials) HTTPRequest(ctx context.Context, userID int64, agentID string, args dyn.Map, runID string) (any, error) {
	return t.b.HTTPRequest(ctx, userID, agentID, args, credentials.RunContext{RunID: runID})
}

// toolArtifacts is the artifact store.
type toolArtifacts struct{ s *artifacts.Store }

func (t toolArtifacts) CreateBuffer(ctx context.Context, userID int64, a handlers.NewArtifact) (handlers.StoredArtifact, error) {
	stored, err := t.s.CreateBufferArtifact(ctx, userKey(userID), artifacts.File{
		Kind: a.Kind, Backend: a.Backend, Extension: a.Extension, ContentType: a.ContentType,
		FilenameBase: a.FilenameBase, Content: a.Content, Metadata: a.Metadata,
	})
	if err != nil {
		return handlers.StoredArtifact{}, err
	}
	return handlers.StoredArtifact{ArtifactID: stored.ID, URL: stored.URL}, nil
}

func (t toolArtifacts) ReadText(ctx context.Context, userID int64, id, startLine, endLine, query any) (any, error) {
	return t.s.ReadText(ctx, userID, id, startLine, endLine, query)
}

func (t toolArtifacts) StoragePath(ctx context.Context, userID int64, id string) (string, int64, bool, error) {
	r, err := t.s.Get(ctx, userID, id)
	if err != nil || r == nil {
		return "", 0, false, err
	}
	return r.StoragePath, r.ByteSize, true, nil
}

func (t toolArtifacts) ByStoragePath(ctx context.Context, userID int64, path string) (string, bool, error) {
	r, err := t.s.GetByStoragePath(ctx, userID, path)
	if err != nil || r == nil {
		return "", false, err
	}
	return r.StoragePath, true, nil
}

// toolRouter is NeoRouter for the search and images roles.
type toolRouter struct{ s *neorouterapi.Service }

func (t toolRouter) SearchWeb(ctx context.Context, userID int64, agentID, query string, count int, freshness any) ([]any, bool, error) {
	conn, err := t.s.ForRole(ctx, userID, agentID, "search")
	if err != nil || conn == nil {
		return nil, false, nil
	}
	results, err := t.s.SearchWeb(ctx, conn, query, count, dyn.Str(freshness))
	if err != nil {
		return nil, true, err
	}
	out, _ := toAny(results).([]any)
	return out, true, nil
}

func (t toolRouter) GenerateImages(ctx context.Context, userID int64, agentID, prompt string, n int) ([]string, bool, error) {
	conn, err := t.s.ForRole(ctx, userID, agentID, "images")
	if err != nil || conn == nil {
		return nil, false, nil
	}
	images, err := t.s.GenerateImages(ctx, conn, prompt, n)
	return images, true, err
}

// toolMedia covers xAI images, vision, speech-to-text and OCR; vision and
// speech-to-text come from the engine.
type toolMedia struct {
	transcribe func(ctx context.Context, userID int64, agentID, path string) (string, error)
	analyze    func(ctx context.Context, userID int64, agentID, path, question string) (any, error)
	xai        openaiimages.Client
}

// GenerateImagesXAI is generate_image without NeoRouter: grok-imagine-image
// on XAI_BASE_URL (https://api.x.ai/v1 by default) with XAI_API_KEY.
func (t toolMedia) GenerateImagesXAI(ctx context.Context, prompt string, n int) ([]string, error) {
	return t.xai.Generate(ctx, "grok-imagine-image", prompt, n)
}

func (t toolMedia) AnalyzeImage(ctx context.Context, userID int64, agentID, path, question string) (any, error) {
	if t.analyze == nil {
		return nil, errors.New("No vision-capable model is currently available in the live provider catalogs.")
	}
	return t.analyze(ctx, userID, agentID, path, question)
}

func (t toolMedia) Transcribe(ctx context.Context, userID int64, agentID, path string) (string, error) {
	if t.transcribe == nil {
		return "", errors.New("Speech-to-text is unavailable.")
	}
	return t.transcribe(ctx, userID, agentID, path)
}

func (toolMedia) OCR(ctx context.Context, path string) (string, float64, error) {
	return ocr.Recognize(ctx, "", path)
}

// toolHealth reads ingested health data.
type toolHealth struct{ h *mobilesync.Health }

func (t toolHealth) Read(ctx context.Context, userID int64, metricType, limit any) (any, error) {
	n := 0
	if f, ok := dyn.Float(limit); ok {
		n = int(f)
	}
	return t.h.ReadData(ctx, userID, dyn.Str(metricType), n)
}

// toolSocialVideo extracts transcripts from video links.
type toolSocialVideo struct{ s *socialvideo.Service }

func (t toolSocialVideo) Extract(ctx context.Context, userID int64, agentID, url string, includeFrame, forceSTT bool) (any, error) {
	return t.s.Extract(ctx, userID, url, socialvideo.Options{IncludeFrame: includeFrame, ForceSTT: forceSTT, AgentID: agentID})
}

// toolSystemOne answers browser_act's decisions.
type toolSystemOne struct {
	s     *systemone.Service
	infer func(ctx context.Context, userID int64, agentID, system, prompt string, maxTokens int) (dyn.Map, error)
}

func (t toolSystemOne) Ready(ctx context.Context, userID int64, agentID string) (bool, error) {
	return t.s.Ready(ctx, userID, agentID)
}

func (t toolSystemOne) Decide(ctx context.Context, userID int64, agentID, runID, stepID, phase string, state, questions dyn.Map) (dyn.Map, error) {
	return t.s.Decide(ctx, systemone.Request{UserID: userID, AgentID: agentID, RunID: runID, StepID: stepID, Phase: phase, State: state, Questions: questions})
}

func (t toolSystemOne) InferStructured(ctx context.Context, userID int64, agentID, system, prompt string, maxTokens int) (dyn.Map, error) {
	if t.infer == nil {
		return nil, errors.New("The fast model is unavailable.")
	}
	return t.infer(ctx, userID, agentID, system, prompt, maxTokens)
}

// toolStructured queries data files in the server workspace.
type toolStructured struct{ w *workspace.Manager }

func (t toolStructured) Query(ctx context.Context, userID int64, args dyn.Map) (any, error) {
	return t.w.Query(ctx, userKey(userID), workspace.Options(args))
}

// RunInWorkspace is agent.CommandRunner: the checkpoints' git reads, from the
// workspace directory every computer maps to its own.
func (r toolRuntime) RunInWorkspace(ctx context.Context, userID int64, runID, deviceTarget, script string, timeout time.Duration) (dyn.Map, error) {
	return r.ExecuteCommand(ctx, userID, script, handlers.CommandOptions{Cwd: repotools.GuestWorkspaceDir, Timeout: timeout, RunID: runID, DeviceTarget: deviceTarget})
}
