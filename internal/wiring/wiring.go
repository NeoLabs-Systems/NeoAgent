package wiring

import (
	"context"
	"encoding/json"
	"github.com/NeoLabs-Systems/neoagent/internal/commands"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/accounterase"
	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neoagent/internal/admin"
	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/agentimport"
	"github.com/NeoLabs-Systems/neoagent/internal/agentsapi"
	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/prompts"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/systemone"
	"github.com/NeoLabs-Systems/neoagent/internal/android"
	"github.com/NeoLabs-Systems/neoagent/internal/artifacts"
	"github.com/NeoLabs-Systems/neoagent/internal/authapi"
	"github.com/NeoLabs-Systems/neoagent/internal/behavior"
	"github.com/NeoLabs-Systems/neoagent/internal/config"
	"github.com/NeoLabs-Systems/neoagent/internal/datasharing"
	"github.com/NeoLabs-Systems/neoagent/internal/delegation"
	"github.com/NeoLabs-Systems/neoagent/internal/gitproxy"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/figma"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/github"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/google"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/microsoft"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/notion"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/slack"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations/spotify"
	"github.com/NeoLabs-Systems/neoagent/internal/mcpserver"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/mobilesync"
	"github.com/NeoLabs-Systems/neoagent/internal/neorouterapi"
	"github.com/NeoLabs-Systems/neoagent/internal/providersignin"
	"github.com/NeoLabs-Systems/neoagent/internal/publicstatus"
	"github.com/NeoLabs-Systems/neoagent/internal/runtimeapi"
	"github.com/NeoLabs-Systems/neoagent/internal/security"
	"github.com/NeoLabs-Systems/neoagent/internal/securityapi"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neoagent/internal/setupapi"
	"github.com/NeoLabs-Systems/neoagent/internal/sharedmessaging"
	"github.com/NeoLabs-Systems/neoagent/internal/skilllearning"
	"github.com/NeoLabs-Systems/neoagent/internal/skills"
	"github.com/NeoLabs-Systems/neoagent/internal/socialreach"
	"github.com/NeoLabs-Systems/neoagent/internal/socialvideo"
	"github.com/NeoLabs-Systems/neoagent/internal/sockets"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks"
	"github.com/NeoLabs-Systems/neoagent/internal/taskwebhooks"
	"github.com/NeoLabs-Systems/neoagent/internal/timeline"
	"github.com/NeoLabs-Systems/neoagent/internal/triggers"
	"github.com/NeoLabs-Systems/neoagent/internal/voice"
	"github.com/NeoLabs-Systems/neoagent/internal/wearable"
	"github.com/NeoLabs-Systems/neoagent/internal/webshares"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/embedding"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/secretbox"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

// Deps are the core server dependencies constructed in main.go.
type Deps struct {
	Cfg            config.Config
	DB             *dbx.DB
	Sessions       *sessionx.Manager
	Store          *sessionx.Store
	Box            *secretbox.Box
	Users          *accounts.Repo
	Records        *accounts.SessionRecords
	Version        string
	Log            *slog.Logger
	BindOAuthState func(*sessionx.Session, string)
}

// App holds the wired domain services, route mounts, and lifecycle hooks.
type App struct {
	SystemOne        *systemone.Service
	IntegrationOAuth *authapi.IntegrationCallbacks
	ModelOAuth       *authapi.ModelCallbacks
	Admin            *admin.API
	Routes           []interface{ Routes(*http.ServeMux) }

	db        *dbx.DB
	log       *slog.Logger
	mcp       *mcpserver.Manager
	mcpCancel context.CancelFunc
	mcpWG     sync.WaitGroup
	router    *neorouterapi.Service
	memory    *memory.Manager
	messaging *messaging.Manager
	shared    *messaging.SharedConnections
	tasks     *tasks.Runtime
	sockets   *sockets.Server
	computer  *computer
	wearables *wearable.Gateway
	// Front serves shared web pages ahead of the app.
	Front func(http.Handler) http.Handler
	// engine runs the agent; learning learns skills from its runs.
	engine    *agent.Engine
	learning  *skilllearning.Service
	policies  *security.Policies
	approvals *security.Gate
	behavior  *behavior.Pipeline
	voice     *voice.Manager
	ingestion *memory.IngestionService
	calls     *voice.Coordinator
	commands  *commands.Router
	// integrations keep sockets and sign-in sessions open (WhatsApp, Tailscale).
	integrations *integrations.Manager
	// importer brings OpenClaw and Hermes Agent installations over.
	importer *agentimport.API
	// models is the model catalog the engine selects from (headless runs check
	// an explicit model against it).
	models agentModels
}

// RuntimeValidation reports whether the computer runtime is usable.
func (a *App) RuntimeValidation() (ready bool, issues []string) { return a.computer.Validation() }

// Build constructs and wires all domain packages.
func Build(ctx context.Context, d Deps) (*App, error) {
	app := &App{db: d.DB, log: d.Log}
	if app.log == nil {
		app.log = slog.Default()
	}
	agents := agentscope.Resolver{DB: d.DB}
	emitter := &deferredEmitter{}
	link := &engineLink{}
	envStore := &admin.EnvStore{File: d.Cfg.Paths.EnvFile}

	localBox := d.Box
	if localBox == nil {
		var err error
		localBox, err = secretbox.New(config.SecretPrefix, d.Cfg.SessionSecret)
		if err != nil {
			return nil, err
		}
	}

	agentDataDir := d.Cfg.Paths.AgentDataDir
	localSecret := strings.TrimSpace(os.Getenv("NEOAGENT_DATA_ENCRYPTION_KEY"))
	if localSecret == "" {
		localSecret = d.Cfg.SessionSecret
	}
	memoryBox, err := secretbox.New("enc:local:v1:", localSecret)
	if err != nil {
		return nil, err
	}
	artifactsDir := filepath.Join(d.Cfg.Paths.DataDir, "artifacts")
	_ = os.MkdirAll(agentDataDir, 0o700)
	_ = os.MkdirAll(artifactsDir, 0o700)

	baseSettings := settings.New(settings.Config{
		DB: d.DB, Box: localBox, Log: d.Log, TrustProxy: d.Cfg.TrustProxy,
		RuntimeBackend: settings.RuntimeBackendFor(os.Getenv("TERMINAL_ENV")),
	})
	nrSvc := neorouterapi.New(neorouterapi.Config{
		Env:      envAdapter{env: envStore, getenv: os.Getenv},
		Settings: nrSettingsAdapter{store: baseSettings.Store},
		Accounts: nrAccountsAdapter{users: d.Users, agents: agents}, Log: d.Log,
	})
	app.router = nrSvc
	modelCache := &catalogCache{}
	failures := &aimodels.Failures{Store: &aimodels.HealthStore{DB: d.DB, Log: d.Log}, Providers: providerTraits{}, Cooldowns: aimodels.CooldownsFromEnv(os.Getenv), Log: d.Log}
	catalog := settingsCatalogAdapter{store: baseSettings.Store, nr: nrSvc, users: d.Users, cache: modelCache, failures: failures}
	app.models = agentModels{catalog}

	embedder := memoryEmbeddingAdapter{router: nrSvc, store: baseSettings.Store, catalog: catalog, client: embedding.New()}
	memMgr, err := memory.New(ctx, memory.Config{
		DB:           d.DB,
		AgentDataDir: agentDataDir,
		LocalBox:     memoryBox,
		Embedder:     embedder,
		Log:          d.Log,
	})
	if err != nil {
		return nil, err
	}
	app.memory = memMgr

	intSvc := integrations.NewServices(d.DB, localBox)
	providers := []integrations.Provider{
		figma.New(intSvc),
		notion.New(intSvc),
		spotify.New(intSvc),
		google.New(intSvc),
		microsoft.New(intSvc),
		github.New(intSvc),
		slack.New(intSvc),
	}
	batch1 := addIntegrationsBatch1(&providers, intSvc, d.DB, localBox, d.Cfg.Paths.DataDir)
	batch2 := addIntegrationsBatch2(&providers, intSvc, d.DB, localBox, emitter, agentDataDir)
	sortProvidersLikeNode(providers)
	var ingestion *memory.IngestionService
	intMgr, err := integrations.NewManager(intSvc, providers, integrations.Hooks{
		OnConnected: func(conn integrations.Connection, memorySweep bool) {
			ingestion.HandleConnected(memory.Connection{ID: conn.ID, UserID: conn.UserID, AgentID: conn.AgentID, ProviderKey: conn.ProviderKey,
				AppKey: conn.AppKey, Status: conn.Status, AccountEmail: conn.AccountEmail, MetadataJSON: conn.MetadataJSON}, memorySweep)
		},
		DecorateSnapshot: func(ctx context.Context, snap *integrations.Snapshot, userID int64, agentID string) {
			decorateWithCoverage(ingestion)(ctx, snap, userID, agentID)
		},
	}, d.Log)
	if err != nil {
		return nil, err
	}
	ingestion = memory.NewIngestionService(memory.IngestionConfig{
		Memory: memMgr, Integrations: ingestionIntegrations{mgr: intMgr, svc: intSvc}, Emitter: emitter, Log: d.Log,
	})
	app.ingestion = ingestion
	app.IntegrationOAuth = &authapi.IntegrationCallbacks{
		Describe: func(ctx context.Context, state string) (*authapi.IntegrationPending, error) {
			p, err := intMgr.DescribePendingOAuth(ctx, state)
			if err != nil || p == nil {
				return nil, err
			}
			return &authapi.IntegrationPending{ProviderLabel: p.ProviderLabel, AppLabel: p.AppLabel, Username: p.Username, StartedAt: p.StartedAt}, nil
		},
		Finish: func(ctx context.Context, state, code string) (*authapi.IntegrationResult, error) {
			result, err := intMgr.FinishOAuth(ctx, state, code)
			if err != nil {
				return nil, err
			}
			return &authapi.IntegrationResult{Provider: result.Provider, AppID: result.AppID, ConnectionID: result.ConnectionID, AccountEmail: result.AccountEmail}, nil
		},
	}

	var taskRt *tasks.Runtime
	mcpStore := &mcpserver.Store{DB: d.DB, Box: localBox}
	mcpMgr := mcpserver.NewManager(mcpserver.ManagerConfig{
		Store:       mcpStore,
		Log:         d.Log,
		RedirectURL: mcpRedirectURL(d.Cfg),
		OnStatus:    func(e mcpserver.StatusEvent) { publishMCPStatus(taskRt, e) },
	})

	app.mcp = mcpMgr

	var msgMgr *messaging.Manager
	media := inboundMedia{&artifacts.Store{DB: d.DB, Root: artifactsDir}}
	inbound := &inboundHandler{link: link, db: d.DB, store: &messaging.Store{DB: d.DB, Agents: agentScopeAdapter{r: agents}},
		manager: func() *messaging.Manager { return msgMgr }, memory: memMgr, emitter: emitter}
	msgMgr = messaging.NewManager(messaging.ManagerConfig{
		Engine:            inbound,
		DB:                d.DB,
		Box:               localBox,
		Agents:            agentScopeAdapter{r: agents},
		Emitter:           emitter,
		Factories:         messagingFactories(d.DB, intSvc, media),
		DataDir:           d.Cfg.Paths.AgentDataDir,
		OnEvent:           func(name string, event map[string]any) { taskRt.HandleEvent("messaging", name, event) },
		LegacyWhatsAppDir: filepath.Join(d.Cfg.Paths.DataDir, "whatsapp-auth"),
		Log:               d.Log,
	})
	app.messaging = msgMgr
	sharedStore := &sharedmessaging.Store{DB: d.DB, Box: localBox}
	app.shared = messaging.NewSharedConnections(msgMgr, sharedStore)
	app.shared.IsAdmin = func(ctx context.Context, uid int64) bool { return d.Users.IsAdmin(ctx, uid) }
	sharedAdm := sharedAdmin{store: sharedStore, shared: app.shared}

	tlSvc := &timeline.Service{DB: d.DB}
	taskMessaging := &taskMessagingAdapter{mgr: msgMgr, db: d.DB, shared: sharedStore, integrations: intMgr}
	taskRt = tasks.New(tasks.Config{
		DB:           d.DB,
		Box:          localBox,
		Log:          d.Log,
		Agents:       agentScopeAdapter{r: agents},
		Emitter:      emitter,
		Engine:       link,
		Timeline:     tlSvc,
		Messaging:    taskMessaging,
		Integrations: taskIntegrationsAdapter{mgr: intMgr},
	})
	app.tasks = taskRt
	batch2.bind(intMgr, taskRt)
	app.integrations = intMgr

	modelFlows := providersignin.NewFlows(baseSettings.Store)
	app.ModelOAuth = &authapi.ModelCallbacks{
		Describe: func(ctx context.Context, state string) (*authapi.ModelPending, error) {
			label, userID, started, ok := modelFlows.Describe(state)
			if !ok {
				return nil, nil
			}
			u, err := d.Users.ByID(ctx, userID)
			if err != nil {
				return nil, err
			}
			name := ""
			if u != nil {
				name = u.Username
			}
			return &authapi.ModelPending{ProviderLabel: label, Username: name, StartedAt: started.UTC().Format("2006-01-02 15:04:05")}, nil
		},
		Finish: func(ctx context.Context, state, code string) (string, error) {
			result, err := modelFlows.Complete(ctx, state, code, 0)
			if err != nil {
				return "", err
			}
			provider, _ := result["providerId"].(string)
			return provider, nil
		},
		Fail: modelFlows.Fail,
	}
	app.SystemOne = &systemone.Service{Source: systemOneSource{store: baseSettings.Store, catalog: catalog, router: nrSvc, failures: failures}, Observer: systemOneObserver{db: d.DB, failures: failures, log: d.Log}}
	sanitize := func(message string) string { return publicerr.Sanitize(message, d.Cfg.Paths.Home, "") }
	voiceDir := voiceDirectory{catalog: catalog, dataDir: agentDataDir, decrypt: memMgr.DecryptLocal}
	voiceMgr, err := voice.NewManager(voice.ManagerConfig{DB: d.DB, Log: d.Log, Getenv: os.Getenv, Agents: agents, AI: voiceDir,
		Persona: voicePersona{link: link, sources: &agent.PromptSources{DB: d.DB, Memory: memMgr}, mem: memMgr}, Engine: voiceEngine{link: link},
		Render: prompts.Render, Sanitize: sanitize, HTTPClient: ssrf.NewClient(ssrf.Options{Timeout: 2 * time.Minute}),
		ErrorFor: (&socketServices{users: d.Users}).ErrorMessageForUser})
	if err != nil {
		return nil, err
	}
	agentCalls := voice.NewCoordinator(voiceRealtime{emitter: emitter}, voiceMgr, voiceAgents{r: agents}, d.Log)
	voiceMgr.SetCallNotifier(agentCalls)
	app.voice, app.calls = voiceMgr, agentCalls
	voiceCapabilities := func(ctx context.Context, userID int64, agentID string) (any, error) {
		return voiceMgr.GetCapabilities(ctx, userID, agentID), nil
	}
	baseSettings.Store.Hooks.VoiceCapabilities = voiceCapabilities
	inbound.commands = func() *commands.Router { return app.commands }
	inbound.messages = fixedMessages{baseSettings.Store}
	inbound.voiceNotes = &voice.NoteProcessor{Transcriber: voiceMgr.Transcriber(), Log: d.Log, FFmpeg: os.Getenv("FFMPEG_BIN")}
	inbound.speechModel = func(ctx context.Context, userID int64, agentID string) string {
		all, err := (agentSettings{baseSettings.Store}).AISettings(ctx, userID, agentID)
		if err != nil {
			return ""
		}
		return dyn.Str(all["default_speech_model"])
	}
	settingsAPI := settings.New(settings.Config{
		DB: d.DB, Box: localBox, Log: d.Log, TrustProxy: d.Cfg.TrustProxy,
		RuntimeBackend: settings.RuntimeBackendFor(os.Getenv("TERMINAL_ENV")),
		Catalog:        settingsCatalogAdapter{store: baseSettings.Store, nr: nrSvc, users: d.Users, cache: modelCache, failures: failures},
	})
	settingsAPI.Store.Hooks.VoiceCapabilities = voiceCapabilities

	eraser := &accounterase.Eraser{
		DB:           d.DB,
		DataDir:      d.Cfg.Paths.DataDir,
		AgentDataDir: agentDataDir,
		Sessions:     d.Store,
		Log:          d.Log,
	}

	adminAPI := admin.New(admin.Deps{
		DB:         d.DB,
		Records:    d.Records,
		EnvFile:    d.Cfg.Paths.EnvFile,
		TrustProxy: d.Cfg.TrustProxy,
		Log:        d.Log,
		ModelCatalog: func(ctx context.Context) ([]string, error) {
			catalog := settingsCatalogAdapter{store: baseSettings.Store, nr: nrSvc, users: d.Users, serverOnly: true, cache: modelCache, failures: failures}
			models, _, _ := catalog.listModels(ctx, 0, "")
			ids := make([]string, 0, len(models))
			for _, m := range models {
				if id, ok := m["id"].(string); ok {
					ids = append(ids, id)
				}
			}
			return ids, nil
		},
		Extra: admin.ExtraDeps{
			MessagingList:    sharedAdm.list,
			MessagingUpdate:  sharedAdm.update,
			MessagingDelete:  sharedAdm.remove,
			Updates:          adminUpdates(d.Cfg),
			MarkSetupSection: func(section string) error { return setupapi.MarkSectionComplete(section, os.Getenv, envStore.Persist) },
			DeleteUser: func(ctx context.Context, targetID, _ int64) error {
				_, err := eraser.Erase(ctx, targetID)
				return err
			},
			HealthCheck: func(ctx context.Context, uid int64) (any, error) {
				return adminHealth{
					db: d.DB, version: d.Version, dataDir: d.Cfg.Paths.DataDir, computer: app.computer, agents: agents,
					catalog: settingsCatalogAdapter{store: baseSettings.Store, nr: nrSvc, users: d.Users, cache: modelCache, failures: failures},
				}.check(ctx, uid)
			},
			ListModels: func(ctx context.Context, uid int64) (any, error) {
				return (settingsCatalogAdapter{store: baseSettings.Store, nr: nrSvc, users: d.Users, cache: modelCache, failures: failures}).adminModels(ctx, envAdapter{env: envStore, getenv: os.Getenv})
			},
		},
	})

	socketBackend := &socketServices{link: link, db: d.DB, users: d.Users, agents: agents, mem: memMgr, msg: msgMgr, mcp: mcpMgr, integrations: intMgr, settings: baseSettings.Store}

	svSvc := socialvideo.New(socialvideo.Config{Transcriber: videoTranscriber{voiceMgr}})
	srSvc := socialreach.New(socialreach.Config{DB: d.DB, Box: localBox, Video: svSvc})

	skillsDir := filepath.Join(agentDataDir, "skills")
	_ = os.MkdirAll(skillsDir, 0o700)
	workspaces, err := workspace.New(filepath.Join(agentDataDir, "workspaces"), false)
	if err != nil {
		return nil, err
	}
	inbound.workspaces = workspaces
	app.computer = newComputer(d, emitter, &artifacts.Store{DB: d.DB, Root: artifactsDir}, workspaces, runPauser{link})
	batch2.bindComputer(app.computer.Manager)
	batch1.broker.SetBrowsers(credentialBrowsers{app.computer.Manager})
	eraser.Runtime = app.computer.Manager
	reschedule := func(userID int64) error { return taskRt.RescheduleUserTasks(context.Background(), userID) }
	baseSettings.Store.Hooks.RescheduleTasks, settingsAPI.Store.Hooks.RescheduleTasks = reschedule, reschedule
	skillRunner := skills.NewRunner(skills.RunnerConfig{DB: d.DB, Dir: skillsDir, Log: d.Log, Commands: skillCommands{app.computer.Manager}})
	_ = skillRunner.Load(ctx)
	app.importer = agentimport.New(agentimport.Config{Env: agentimport.Env{
		DB: d.DB, Box: localBox, EnvFile: d.Cfg.Paths.EnvFile, RuntimeHome: d.Cfg.Paths.Home, AgentDataDir: d.Cfg.Paths.AgentDataDir, AIProviders: importAIProviders,
		Host: importHost{db: d.DB, memory: memMgr, skills: skillRunner, settings: baseSettings.Store, tasks: taskRt},
	}, Scanner: agentimport.Scanner{Getenv: os.Getenv}, Log: d.Log})

	androidHost, err := android.NewHost(android.HostConfig{
		DataDir:     d.Cfg.Paths.DataDir,
		RuntimeHome: d.Cfg.Paths.Home,
		LogoPath:    filepath.Join(d.Cfg.AppDir, "flutter_app", "assets", "branding", "app_icon_512.png"),
		Artifacts:   androidArtifacts{app.computer.Artifacts},
		URLCheck:    checkIntentURL,
		Log:         d.Log,
	})
	if err != nil {
		return nil, err
	}
	androidAPI, err := android.NewAPI(android.APIConfig{
		Provider:          androidHost,
		ValidateIntentURL: androidHost.ValidateIntentURL,
		UploadDir:         filepath.Join(d.Cfg.Paths.DataDir, "uploads", "android-apks"),
		Log:               d.Log,
	})
	if err != nil {
		return nil, err
	}

	sockSrv, err := sockets.New(sockets.Config{
		DB:  d.DB,
		Log: d.Log,
		Hub: sockets.HubOptions(os.Getenv, d.Cfg.Origins, d.Log),

		NoSubscriberGrace: sockets.StreamGrace(os.Getenv),
		Controllers:       streamControllers(app.computer, androidHost),
		Home:              d.Cfg.Paths.Home,
		Root:              d.Cfg.AppDir,
		Services: sockets.Services{
			Access:        socketBackend,
			Agents:        socketBackend,
			Engine:        socketBackend,
			Conversations: socketBackend,
			Chat:          socketBackend,
			RunEvents:     socketBackend,
			Messaging:     socketBackend,
			Voice:         socketVoice{m: voiceMgr, calls: agentCalls},
			Calls:         socketVoice{m: voiceMgr, calls: agentCalls},
			Commands:      socketCommands{app: app},
			MCP:           socketBackend,
			Memory:        socketBackend,
			Integrations:  socketBackend,
			Approvals:     socketBackend,
		},
	})
	if err != nil {
		return nil, err
	}
	app.sockets = sockSrv
	app.computer.Gateway.Frames = streamFrames{hub: sockSrv.StreamHub()}
	emitter.Set(sockSrv)
	app.Admin = adminAPI

	app.behavior = &behavior.Pipeline{DB: d.DB, Emitter: emitter, Log: d.Log, Memory: behaviorMemory{memMgr},
		Inference: behaviorInference{link: link, systemOne: func() *systemone.Service { return app.SystemOne }},
		Sender:    behaviorSender{mgr: func() *messaging.Manager { return msgMgr }}}
	inbound.behavior = app.behavior
	gitProxy := gitproxy.New(gitproxy.Config{Connections: gitproxy.DBConnections{DB: d.DB, Box: localBox}, Port: d.Cfg.Port, Log: d.Log})
	engineAPI := app.wireEngine(ctx, engineWiring{
		d: d, link: link, emitter: emitter, agents: agents, settings: baseSettings.Store, catalog: catalog, memory: memMgr, failures: failures,
		messaging: msgMgr, integrations: intMgr, mcp: mcpMgr, skills: skillRunner, timeline: tlSvc, artifacts: &artifacts.Store{DB: d.DB, Root: artifactsDir},
		tasks: taskRt, systemOne: app.SystemOne, socket: socketBackend, android: androidHost, workspaces: workspaces, router: nrSvc,
		socialVideo: svSvc, socialReach: srSvc, inbound: inbound, behavior: app.behavior, gitProxy: gitProxy, voice: voiceMgr, calls: agentCalls, voiceDir: voiceDir, credentials: batch1.broker, embedder: embedder,
	})
	intAPI := integrations.New(integrations.Config{Manager: intMgr, Log: d.Log, BindState: d.BindOAuthState, Home: d.Cfg.Paths.Home, Root: d.Cfg.AppDir})
	wearableAPI, wearableGateway := newWearable(d, voiceMgr, taskRt, sanitize)
	app.wearables = wearableGateway
	app.Routes = []interface{ Routes(*http.ServeMux) }{
		miscRoutes{rateLimits: &aimodels.RateLimiter{DB: d.DB, Config: aimodels.RateLimitConfigFromEnv(os.Getenv)}},
		adminAPI,
		settingsAPI,
		sockSrv,
		memory.NewAPI(memory.APIConfig{Memory: memMgr, Ingestion: ingestion, Log: d.Log, TrustProxy: d.Cfg.TrustProxy}),
		intAPI,
		batch1Routes{api: intAPI, b: batch1},
		mcpserver.New(mcpserver.Config{Manager: mcpMgr, Agents: agents, Log: d.Log, PublicBaseURL: d.Cfg.PublicURL}),
		msgMgr,
		taskRt,
		taskwebhooks.New(taskwebhooks.Config{DB: d.DB, Box: localBox, Dispatcher: taskRt}),
		triggers.New(triggers.Config{DB: d.DB, Tasks: triggersTasksAdapter{rt: taskRt}, Log: d.Log}),
		nrSvc,
		skills.New(skills.Config{DB: d.DB, Runner: skillRunner, Log: d.Log, Audit: skillRunner, SkillsSh: newSkillsSh()}),
		androidAPI,
		mobilesync.New(mobilesync.Config{DB: d.DB, Box: localBox, Agents: agentScopeAdapter{r: agents}, Events: mobileSyncEventsAdapter{rt: taskRt}, Log: d.Log}),
		accounterase.New(accounterase.Config{Eraser: eraser, SecureCookie: d.Cfg.SecureCookie, TrustProxy: d.Cfg.TrustProxy}),
		gitProxy,
		app.importer,
		socialvideo.NewAPI(socialvideo.APIConfig{Extractor: svSvc, Log: d.Log, AgentID: func(r *http.Request, userID int64, body map[string]json.RawMessage) (string, error) {
			return agents.Resolve(r.Context(), userID, agentscope.Candidate(r, body))
		}}),
		socialreach.NewAPI(socialreach.APIConfig{Backend: srSvc, Log: d.Log}),
		publicstatus.New(publicstatus.Config{
			DB: d.DB, RuntimeReady: func() bool { ready, _ := app.computer.Validation(); return ready },
			HasComputer: func() bool { return true }, HasVoice: func() bool { return true },
			HasAI: func() bool { return true }, HasMessaging: func() bool { return true },
			HasIntegration: func() bool { return true }, HasMCP: func() bool { return true },
			HasTasks: func() bool { return true }, HasMemory: func() bool { return true },
		}),
		setupapi.New(setupapi.Config{DB: d.DB, Version: d.Version}),
		webshares.New(webshares.Config{DB: d.DB, ComputerRunning: func(userID int64) bool {
			return app.computer.Manager.HasVM(strconv.FormatInt(userID, 10))
		}}),
		&datasharing.API{Users: d.Users, TrustProxy: d.Cfg.TrustProxy},
		artifacts.New(artifacts.Config{DB: d.DB, Root: artifactsDir}),
		runtimeapi.New(),
		app.computer.API,
		app.computer.System,
		app.computer.Gateway,
		securityapi.New(securityapi.Config{DB: d.DB, Policies: app.policies, Gate: app.approvals}),
		behavior.New(behavior.Config{DB: d.DB, Pipeline: app.behavior}),
		providersignin.New(providersignin.Config{DB: d.DB, PublicURL: d.Cfg.PublicURL, Flows: modelFlows, BindState: d.BindOAuthState}),
		delegation.New(delegation.Config{DB: d.DB, IsAdmin: func(ctx context.Context, uid int64) bool { return d.Users.IsAdmin(ctx, uid) }, PublicURL: d.Cfg.PublicURL, Log: d.Log}),
		agentsapi.New(agentsapi.Config{DB: d.DB, IsAdmin: func(ctx context.Context, uid int64) bool { return d.Users.IsAdmin(ctx, uid) }}),
		engineAPI,
		wearableAPI,
		wearableGateway,
		voice.NewAPI(voice.RoutesConfig{Manager: voiceMgr, Log: d.Log, Sanitize: sanitize,
			AgentCandidate: func(r *http.Request) string { return agentscope.Candidate(r, nil) }}),
	}
	return app, nil
}

// Start starts background domain services.
func (a *App) Start(ctx context.Context) error {
	if a.Admin != nil {
		a.Admin.StartUpdateChecks(ctx)
	}
	if a.router != nil {
		if err := a.router.Start(ctx); err != nil {
			return err
		}
	}
	if a.memory != nil {
		a.memory.Start(ctx)
	}
	if a.mcp != nil {
		rows, err := a.db.R.QueryContext(ctx, `SELECT id FROM users`)
		if err != nil {
			a.Stop()
			return err
		}
		var users []int64
		for rows.Next() {
			var id int64
			if err = rows.Scan(&id); err != nil {
				break
			}
			users = append(users, id)
		}
		if err == nil {
			err = rows.Err()
		}
		rows.Close()
		if err != nil {
			a.Stop()
			return err
		}
		var restoreCtx context.Context
		restoreCtx, a.mcpCancel = context.WithCancel(ctx)
		for _, id := range users {
			a.mcpWG.Add(1)
			go func(userID int64) {
				defer a.mcpWG.Done()
				if _, err := a.mcp.LoadFromDB(restoreCtx, userID); err != nil && restoreCtx.Err() == nil {
					a.log.Warn("MCP restore failed", "user", userID, "error", err)
				}
			}(id)
		}
	}
	if a.messaging != nil {
		if err := a.messaging.Start(ctx); err != nil {
			a.Stop()
			return err
		}
		if a.shared != nil {
			if err := a.shared.Start(ctx); err != nil {
				a.Stop()
				return err
			}
		}
	}
	if a.tasks != nil {
		if err := a.tasks.Start(ctx); err != nil {
			a.Stop()
			return err
		}
	}
	if err := a.startEngine(ctx); err != nil {
		a.Stop()
		return err
	}
	return nil
}

// Stop shuts down background domain services cleanly.
func (a *App) Stop() {
	if a.wearables != nil {
		a.wearables.Close()
	}
	a.stopEngine()
	if a.ingestion != nil {
		a.ingestion.Stop()
	}
	if a.mcpCancel != nil {
		a.mcpCancel()
	}
	a.mcpWG.Wait()
	if a.mcp != nil {
		a.mcp.Shutdown()
	}
	if a.router != nil {
		defer a.router.Stop()
	}
	if a.tasks != nil {
		a.tasks.Stop()
	}
	if a.integrations != nil {
		a.integrations.Shutdown(context.Background())
	}
	if a.messaging != nil {
		if a.shared != nil {
			a.shared.Stop()
		}
		a.messaging.Stop()
	}
	if a.memory != nil {
		a.memory.Stop()
	}
	if a.computer != nil {
		a.computer.Shutdown()
	}
	if a.sockets != nil {
		a.sockets.Close()
	}
}
