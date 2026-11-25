package wiring

import (
	"context"
	"encoding/json"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"

	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/artifacts"
	"github.com/NeoLabs-Systems/neoagent/internal/desktop"
	"github.com/NeoLabs-Systems/neoagent/internal/runtime"
	"github.com/NeoLabs-Systems/neoagent/internal/runtimeapi"
	"github.com/NeoLabs-Systems/neoagent/internal/sockets"
	"github.com/NeoLabs-Systems/neoagent/internal/streaming"
	"github.com/NeoLabs-Systems/neoagent/internal/teach"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
)

// computer is every user's computer and the routes that drive it.
type computer struct {
	Manager   *runtime.Manager
	Artifacts *artifacts.Store
	API       *runtimeapi.ComputerAPI
	System    *runtimeapi.SystemAPI
	// Devices are the desktop companions and Gateway their WebSocket.
	Devices *desktop.Registry
	Gateway *desktop.Gateway
	// Teach is Teach Mode, built once its learner exists (newTeach).
	Teach *lateTeach
	teach *teach.Service
}

// newComputer builds the runtime TERMINAL_ENV selects. Teach Mode and agent
// pausing are attached later by whoever owns them (SetTeach, SetRuns).
func newComputer(d Deps, emitter *deferredEmitter, store *artifacts.Store, workspaces *workspace.Manager, runs runtimeapi.RunPauser) *computer {
	env := runtime.Env{Getenv: os.Getenv, Log: d.Log}
	dirs := runtime.Dirs{AppDir: d.Cfg.AppDir, RuntimeHome: d.Cfg.Paths.Home, DataDir: d.Cfg.Paths.DataDir}
	var backend *runtime.VMBackend
	art := artifactAdapter{store: store}
	devices := desktop.NewRegistry(desktop.Options{DB: d.DB, Log: d.Log, Getenv: os.Getenv})
	var host *runtime.LocalBackend
	if vmm := runtime.NewComputerVMManager(dirs, env, d.Cfg.Port); vmm != nil {
		backend = runtime.NewVMBackend(runtime.BackendOptions{Manager: vmm, Artifacts: art, Env: env})
	} else {
		// TERMINAL_ENV=host: this server is every user's computer.
		host = &runtime.LocalBackend{Registry: devices, Artifacts: art, Host: &desktop.HostCompanion{Registry: devices, Workspaces: workspaces}}
	}
	mgr := runtime.NewManager(runtime.ManagerOptions{
		Backend:     backend,
		Host:        host,
		Local:       &runtime.LocalBackend{Registry: devices, Artifacts: art},
		TerminalEnv: runtime.ParseTerminalEnv(os.Getenv("TERMINAL_ENV")),
		Artifacts:   art,
		DB:          d.DB,
		WorkspaceRoot: func(_ context.Context, userKey string) (string, error) {
			return workspaces.Root(userKey)
		},
		EmitStatus: func(userKey string, status any) {
			if id, err := strconv.ParseInt(userKey, 10, 64); err == nil {
				emitter.EmitToUser(id, "computer:status", status)
			}
		},
		Env: env,
	})
	devices.OnConnectionChange = func(userID int64) { mgr.EmitStatus(strconv.FormatInt(userID, 10)) }
	home, _ := os.UserHomeDir()
	late := &lateTeach{}
	return &computer{
		Manager:   mgr,
		Artifacts: store,
		Teach:     late,
		API:       runtimeapi.NewComputer(runtimeapi.ComputerConfig{Manager: mgr, Home: home, AppDir: d.Cfg.AppDir, Teach: late, Runs: runs, Devices: devices, Artifacts: art}),
		System:    &runtimeapi.SystemAPI{Manager: mgr, Getenv: os.Getenv},
		Devices:   devices,
		Gateway:   desktop.NewGateway(devices, nil),
	}
}

// streamFrames relays desktop companion frames to the realtime stream hub.
type streamFrames struct{ hub *sockets.StreamHub }

func (s streamFrames) HandleFrame(userID, deviceID string, f streaming.Frame) {
	if id, err := strconv.ParseInt(userID, 10, 64); err == nil && s.hub != nil {
		s.hub.HandleFrame(id, deviceID, sockets.Frame{Platform: f.Platform, JPEG: f.JPEG, Seq: f.Seq, TS: f.TS, Flags: int(f.Flags)})
	}
}

// Validation reports whether the computer runtime is usable, for /api/health.
func (c *computer) Validation() (ready bool, issues []string) {
	return runtime.ValidationIssues(runtime.Validation(c.Manager, os.Getenv))
}

// Shutdown stops every computer and display connection.
func (c *computer) Shutdown() {
	if c.teach != nil {
		c.teach.Stop()
	}
	c.API.Close()
	c.Gateway.Close()
	c.Manager.Shutdown()
	c.Devices.CloseAll()
}

// artifactAdapter stores computer artifacts in the artifact store.
type artifactAdapter struct{ store *artifacts.Store }

func (a artifactAdapter) CreateBufferArtifact(ctx context.Context, userKey string, in runtime.Artifact) (runtime.StoredArtifact, error) {
	stored, err := a.store.CreateBufferArtifact(ctx, userKey, artifacts.File{
		Kind: in.Kind, Backend: in.Backend, Extension: in.Extension, ContentType: in.ContentType,
		FilenameBase: in.FilenameBase, Content: in.Content, Metadata: in.Metadata,
	})
	if err != nil {
		return runtime.StoredArtifact{}, err
	}
	return runtime.StoredArtifact{ID: stored.ID, URL: stored.URL, StoragePath: stored.StoragePath, ByteSize: stored.ByteSize}, nil
}

// skillCommands runs skill command templates on the user's computer.
type skillCommands struct{ m *runtime.Manager }

func (s skillCommands) ExecuteCommand(ctx context.Context, userID int64, command string) (workspace.Obj, error) {
	result, err := s.m.ExecuteCommand(ctx, strconv.FormatInt(userID, 10), command, "", runtime.ExecOptions{})
	if err != nil {
		return nil, err
	}
	// The guest's key order is kept: the model reads the result as written.
	out := make(workspace.Obj, 0, len(result.Keys()))
	for _, k := range result.Keys() {
		v, _ := result.Get(k)
		out = append(out, workspace.Field{Key: k, Value: v})
	}
	return out, nil
}

// guestMap adapts an ordered guest answer to callers that read it as a map.
func guestMap(o *runtime.Object, err error) (map[string]any, error) {
	if err != nil {
		return nil, err
	}
	return o.Map(), nil
}

// teachRuntime is the user's computer as Teach Mode uses it.
type teachRuntime struct{ m *runtime.Manager }

func (t teachRuntime) AcquireControl(userKey, purpose, sessionID string) {
	_, _ = t.m.AcquireControl(userKey, purpose, sessionID, runtime.ProviderCloud)
}

func (t teachRuntime) ReleaseControl(userKey, sessionID string) {
	t.m.ReleaseControl(userKey, sessionID, runtime.ProviderCloud)
}

func (t teachRuntime) RequestComputer(ctx context.Context, userKey, method, path string, body any, o teach.RequestOptions) (map[string]any, error) {
	return guestMap(t.m.RequestComputer(ctx, userKey, method, path, body, "", runtime.RequestOptions{Timeout: o.Timeout, MaxResponseBytes: o.MaxResponseBytes}))
}

func (t teachRuntime) Browser(ctx context.Context, userKey string) (teach.Browser, error) {
	b, err := t.m.Browser(ctx, userKey, "")
	if err != nil {
		return nil, err
	}
	return teachBrowser{b}, nil
}

type teachBrowser struct{ b runtime.Browser }

func (t teachBrowser) PageInfo(ctx context.Context) (any, error) {
	status, err := t.b.Status(ctx)
	if err != nil {
		return nil, err
	}
	var info any
	status.Decode("pageInfo", &info)
	return info, nil
}

func (t teachBrowser) ExtractContent(ctx context.Context, maxChars int) (map[string]any, error) {
	return guestMap(t.b.ExtractContent(ctx, map[string]any{"maxChars": maxChars}))
}

func (t teachBrowser) Evaluate(ctx context.Context, script string) (any, error) {
	return t.b.Evaluate(ctx, script)
}

// newTeach builds Teach Mode on the computer; learner and images come from the
// agent engine.
func newTeach(c *computer, dataDir string, learner teach.Learner, images teach.ImageAnalyzer, emitter teach.Emitter, log *slog.Logger) *teach.Service {
	s := teach.New(teach.Config{
		Dir: filepath.Join(dataDir, "teach-sessions"), Runtime: teachRuntime{c.Manager},
		Learner: learner, Images: images, Emitter: emitter, Log: log,
	})
	c.teach = s
	c.Teach.set(s)
	return s
}

// adminHealth is the admin page's check list: server, version, database,
// update runner, computer runtime and the AI providers this account can use.
type adminHealth struct {
	db       *dbx.DB
	version  string
	dataDir  string
	computer *computer
	agents   agentscope.Resolver
	catalog  settingsCatalogAdapter
}

type healthRow struct {
	ID     string `json:"id"`
	Label  string `json:"label"`
	Passed bool   `json:"passed"`
	Detail string `json:"detail"`
}

func cut120(s string) string {
	if r := []rune(s); len(r) > 120 {
		return string(r[:120])
	}
	return s
}

// updateStatus reads the update runner's status file; a runner that died
// while "running" reads as failed, as the Node reader reports it.
func (h adminHealth) updateStatus() (state, message string, failedRecently bool) {
	var st struct {
		State       string `json:"state"`
		Message     string `json:"message"`
		RunnerPID   any    `json:"runnerPid"`
		CompletedAt string `json:"completedAt"`
		UpdatedAt   string `json:"updatedAt"`
	}
	st.State = "idle"
	if raw, err := os.ReadFile(filepath.Join(h.dataDir, "update-status.json")); err == nil {
		_ = json.Unmarshal(raw, &st)
	}
	if st.State == "running" {
		pid, _ := st.RunnerPID.(float64)
		if pid <= 0 || pid != float64(int(pid)) || processGone(int(pid)) {
			st.State, st.Message = "failed", "The update stopped unexpectedly. Nothing was lost; you can try again."
			if st.CompletedAt == "" {
				st.CompletedAt = time.Now().UTC().Format(time.RFC3339Nano)
			}
		}
	}
	if st.State == "failed" {
		finished := st.CompletedAt
		if finished == "" {
			finished = st.UpdatedAt
		}
		if t, err := time.Parse(time.RFC3339Nano, finished); err == nil && time.Since(t) < 24*time.Hour {
			failedRecently = true
		}
	}
	return st.State, st.Message, failedRecently
}

// providerNames lists the providers available to the account across its
// active agents (server keys and the account's own both count).
func (h adminHealth) providerNames(ctx context.Context, userID int64) []string {
	if _, err := h.agents.Resolve(ctx, userID, ""); err != nil {
		return nil
	}
	rows, err := h.db.R.QueryContext(ctx, `SELECT id FROM agents WHERE user_id = ? AND status != 'archived' ORDER BY is_default DESC, updated_at DESC, display_name ASC`, userID)
	if err != nil {
		return nil
	}
	var agentIDs []string
	for rows.Next() {
		var id string
		if rows.Scan(&id) == nil {
			agentIDs = append(agentIDs, id)
		}
	}
	rows.Close()
	seen := map[string]bool{}
	var names []string
	for _, agentID := range agentIDs {
		providers, err := h.catalog.providerCatalog(ctx, userID, agentID)
		if err != nil {
			continue
		}
		for _, p := range providers {
			if p["available"] != true {
				continue
			}
			name, _ := p["customLabel"].(string)
			if name == "" {
				name, _ = p["label"].(string)
			}
			if !seen[name] {
				seen[name] = true
				names = append(names, name)
			}
		}
	}
	return names
}

func (h adminHealth) check(ctx context.Context, userID int64) (any, error) {
	version := h.version
	if version == "" {
		version = "Unknown"
	}
	db := healthRow{ID: "database", Label: "Database", Passed: true, Detail: "SQLite connected"}
	var one int
	if err := h.db.R.QueryRowContext(ctx, `SELECT 1`).Scan(&one); err != nil {
		db.Passed, db.Detail = false, cut120(err.Error())
	}
	state, message, failedRecently := h.updateStatus()
	update := healthRow{ID: "update", Label: "Update status", Passed: !failedRecently, Detail: "No update running"}
	if state != "idle" {
		update.Detail = strings.TrimSpace(state + " — " + message)
	}
	ready, issues := h.computer.Validation()
	vm := healthRow{ID: "vm_runtime", Label: "Cloud VM runtime", Passed: ready, Detail: "Available"}
	if !ready {
		vm.Detail = "Not configured"
		if len(issues) > 0 {
			vm.Detail = issues[0]
		}
	}
	providers := h.providerNames(ctx, userID)
	ai := healthRow{ID: "ai_providers", Label: "AI providers", Passed: len(providers) > 0, Detail: "No providers available to this account"}
	if len(providers) > 0 {
		ai.Detail = strings.Join(providers, ", ")
	}
	results := []healthRow{
		{ID: "backend", Label: "Backend server", Passed: true, Detail: "Running"},
		{ID: "version", Label: "Server version", Passed: true, Detail: version},
		db, update, vm, ai,
	}
	if os.Getenv("DEEPGRAM_API_KEY") != "" {
		results = append(results, healthRow{ID: "deepgram", Label: "Deepgram (transcription)", Passed: true, Detail: "API key configured"})
	}
	passed := true
	for _, r := range results {
		passed = passed && r.Passed
	}
	return struct {
		Passed  bool        `json:"passed"`
		Results []healthRow `json:"results"`
	}{passed, results}, nil
}
