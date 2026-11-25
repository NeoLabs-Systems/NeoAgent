package handlers

import (
	"context"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
)

// Deps are the domains the handlers reach. Any of them may be nil; the tools
// that need a missing one answer that it is unavailable.
type Deps struct {
	Engine Engine
	// DB is the main database: the chat history, MCP server and task tables
	// the Node handlers read directly.
	DB      *dbx.DB
	Tools   *tools.Registry
	Runtime Runtime

	Memory       Memory
	Messaging    Messaging
	Behavior     BehaviorPipeline
	Tasks        Tasks
	Skills       Skills
	MCP          MCP
	Integrations Integrations
	Credentials  Credentials
	Workspace    Workspace
	Artifacts    Artifacts
	Router       Router
	Media        Media
	Health       Health
	SocialVideo  SocialVideo
	SocialReach  SocialReach
	WebShares    WebShares
	Agents       Agents
	Calls        AgentCalls
	Settings     AppSettings
	SystemOne    SystemOne
	SynthID      SynthID
	Structured   StructuredData
	CodeNav      CodeNavigator
	// GitEnv is the git credential environment for a guest command.
	GitEnv func(ctx context.Context, run *Run, guestHost string, ttl time.Duration) (map[string]string, error)
	// StageFiles replaces each argument named in fileArgs with an owned
	// artifact holding that file from the agent's computer
	// (fetchWorkspaceFileArgs); the error names the file that failed.
	StageFiles func(ctx context.Context, run *Run, args dyn.Map, fileArgs []string) (dyn.Map, error)
	// URLCheck is validateCloudUrlWithDns.
	URLCheck func(ctx context.Context, url string) (allowed bool, reason string)
	HTTP     *HTTPRequester
	// BraveSearchKey is BRAVE_SEARCH_API_KEY, used when no NeoRouter does search.
	BraveSearchKey string
	// BraveSearchURL replaces the Brave endpoint in tests.
	BraveSearchURL string
	Now            func() time.Time
}

// CommandOptions are executeCliCommand's options.
type CommandOptions struct {
	Cwd          string
	Timeout      time.Duration
	Env          map[string]string
	StdinInput   any
	PTY          bool
	Inputs       []any
	RunID        string
	StepID       string
	DeviceTarget string
}

// Runtime is the user's computer: commands, browser, Android and desktop.
type Runtime interface {
	// ExecuteCommand runs a command and returns the executor's record (stdout,
	// stderr, exitCode, timedOut, killed, durationMs, backend, ...).
	ExecuteCommand(ctx context.Context, userID int64, command string, o CommandOptions) (dyn.Map, error)
	// GuestHostAddress is the address a guest reaches the host on, or "".
	GuestHostAddress(userID int64, deviceTarget string) string
	// Browser is the user's browser and which backend serves it ("vm",
	// "local-computer", ...).
	Browser(ctx context.Context, userID int64, deviceTarget string) (Browser, string, error)
	// Android is the user's Android controller.
	Android(ctx context.Context, userID int64) (Device, error)
	// Desktop is the desktop controller, or nil when there is none.
	Desktop(ctx context.Context, userID int64, deviceTarget string) (Device, error)
	// AcquireControl gives the computer to the agent; it fails when another
	// owner holds it.
	AcquireControl(userID int64, owner, id, deviceTarget string) error
}

// Browser is a browser provider. Every result is the provider's record.
type Browser interface {
	Navigate(ctx context.Context, url string, o dyn.Map) (dyn.Map, error)
	Click(ctx context.Context, selector, text any, screenshot bool) (dyn.Map, error)
	Type(ctx context.Context, selector, text any, o dyn.Map) (dyn.Map, error)
	Extract(ctx context.Context, selector, attribute, all any) (dyn.Map, error)
	Screenshot(ctx context.Context, o dyn.Map) (dyn.Map, error)
	Evaluate(ctx context.Context, script string) (dyn.Map, error)
	PressKey(ctx context.Context, key string, screenshot bool) (dyn.Map, error)
	Scroll(ctx context.Context, dx, dy int, screenshot bool) (dyn.Map, error)
}

// Device is an Android or desktop controller: method is the Node
// controller's method name (startEmulator, tap, clickPoint, typeText, ...)
// and args its options object.
type Device interface {
	Call(ctx context.Context, method string, args dyn.Map) (any, error)
}

// Memory is the memory manager.
type Memory interface {
	SaveMemory(ctx context.Context, userID int64, agentID, content, category string, importance float64, o MemorySave) (string, error)
	FindSimilar(ctx context.Context, userID int64, agentID, content, excludeID string) ([]any, error)
	OwnedMemoryIDs(ctx context.Context, userID int64, agentID string, ids []string) ([]string, error)
	Recall(ctx context.Context, userID int64, agentID, query string, limit int, validAt string, includeHistory bool) ([]any, error)
	// List returns memories as {id, content, category, importance, updated_at}.
	List(ctx context.Context, userID int64, agentID string, offset, limit int) ([]dyn.Map, error)
	Archive(ctx context.Context, userID int64, ids []string) (int64, error)
	SearchConversations(ctx context.Context, userID int64, agentID, query string, sessions int) ([]any, error)
	UpdateCore(ctx context.Context, userID int64, agentID, key, value string) error
	CoreKeys() []string
	MaxMemoryChars() int
	AppendDailyLog(userID int64, content string) (string, error)
	SetAPIKey(userID int64, service, key string) error
	ReadDailyLog(userID int64, date *time.Time) (string, error)
	ListDailyLogs(userID int64, limit int) (any, error)
	APIKeyNames(userID int64) ([]string, error)
}

// MemorySave is how a memory_save call says where a fact came from.
type MemorySave struct {
	Replaces       []string
	Metadata       dyn.Map
	Confidence     float64
	StaleAfterDays *float64
}

// Messaging is the messaging manager.
type Messaging interface {
	// Send sends a message and returns {success, result:{messageId}, error, reason, suppressed}.
	Send(ctx context.Context, userID int64, agentID, platform, to, content, mediaPath, runID string, persistConversation bool) (dyn.Map, error)
	OwnerDestination(userID int64, agentID, platform string) string
	SupportsReactions(userID int64, agentID, platform string) bool
	SendReaction(ctx context.Context, userID int64, agentID, platform, chatID, messageID, emoji, runID string) error
	// PlatformStatus is the platform's status ("connected", ...), "" when unknown.
	PlatformStatus(ctx context.Context, userID int64, agentID, platform string) string
	// FormatOutgoing is normalizeOutgoingMessageForPlatform without stripping
	// the no-response marker.
	FormatOutgoing(platform, content string) string
}

// BehaviorPipeline delivers a reply through typing bubbles and turn epochs.
type BehaviorPipeline interface {
	DeliverReply(ctx context.Context, userID int64, agentID string, b *Behavior, content, mediaPath, runID string) (BehaviorResult, error)
}

// BehaviorResult is what the behavior pipeline did with a reply.
type BehaviorResult struct {
	Delivered        bool
	Suppressed       bool
	Reason           string
	Delivery         any
	DeliveredBubbles int
}

// Tasks is the task runtime.
type Tasks interface {
	Create(ctx context.Context, userID int64, agentID string, task dyn.Map) (any, error)
	List(ctx context.Context, userID int64, agentID string) ([]any, error)
	Delete(ctx context.Context, userID int64, taskID any) error
	Update(ctx context.Context, userID int64, taskID any, updates dyn.Map) (any, error)
	// ConfigHint is the expected config shape of a trigger type, "" when none.
	ConfigHint(triggerType string) string
}

// Skills is the skill runner.
type Skills interface {
	Create(ctx context.Context, userID int64, name, description, instructions string, metadata dyn.Map) (any, error)
	// Get returns a skill as {name, description, metadata, instructions}.
	Get(userID int64, name string) (dyn.Map, bool)
	// All lists the user's skills without their file paths.
	All(userID int64) []any
	Update(ctx context.Context, userID int64, name string, description, instructions *string, metadata dyn.Map, hasMetadata bool) (any, error)
	Delete(ctx context.Context, userID int64, name string) (any, error)
	// Execute runs a skill called as a tool; ok=false when no skill has that name.
	Execute(ctx context.Context, run *Run, name string, args dyn.Map) (any, bool, error)
}

// MCP is the MCP client manager.
type MCP interface {
	// CallByName runs a tool by its agent-facing name; found=false when no
	// server owns it.
	CallByName(ctx context.Context, userID int64, agentID, name string, args dyn.Map) (any, bool, error)
	// Start starts a registered server and lists its tools.
	Start(ctx context.Context, serverID int64, command, name string, userID int64, agentID string) ([]any, error)
	Stop(serverID int64)
	// Status is the live status per server id: {status, toolCount, error,
	// consecutiveFails, nextRetryAt}.
	Status(userID int64, agentID string) map[int64]dyn.Map
}

// Integrations is the official integrations manager.
type Integrations interface {
	// Execute runs a tool an integration owns; owned=false hands it on.
	Execute(ctx context.Context, run *Run, name string, args dyn.Map) (result any, owned bool, err error)
}

// Credentials is the credential broker.
type Credentials interface {
	FillBrowser(ctx context.Context, userID int64, agentID string, args dyn.Map, runID string) (any, error)
	SubmitProtected(ctx context.Context, userID int64, agentID string, fillID any, runID string) (any, error)
	CancelProtected(ctx context.Context, userID int64, agentID string, fillID any, runID string) (any, error)
	HTTPRequest(ctx context.Context, userID int64, agentID string, args dyn.Map, runID string) (any, error)
}

// FileRequest addresses a file in a computer's workspace.
type FileRequest struct {
	UserID        int64
	DeviceTarget  string
	WorkspaceRoot string
	Args          dyn.Map
}

// Workspace is the computer workspace's file service.
type Workspace interface {
	ReadFile(ctx context.Context, r FileRequest) (dyn.Map, error)
	WriteFile(ctx context.Context, r FileRequest) (dyn.Map, error)
	EditFile(ctx context.Context, r FileRequest) (dyn.Map, error)
	ReplaceFileRange(ctx context.Context, r FileRequest) (dyn.Map, error)
	ListDirectory(ctx context.Context, r FileRequest) (dyn.Map, error)
	SearchFiles(ctx context.Context, r FileRequest) (dyn.Map, error)
	// ResolvePath maps a workspace path to a host path (resolvePath).
	ResolvePath(userID int64, path, label string) (string, error)
}

// Artifacts is the artifact store.
type Artifacts interface {
	CreateBuffer(ctx context.Context, userID int64, a NewArtifact) (StoredArtifact, error)
	ReadText(ctx context.Context, userID int64, artifactID any, startLine, endLine, query any) (any, error)
	// StoragePath is the stored file of an artifact the user owns.
	StoragePath(ctx context.Context, userID int64, artifactID string) (string, int64, bool, error)
	// ByStoragePath finds an owned artifact by its stored path.
	ByStoragePath(ctx context.Context, userID int64, path string) (string, bool, error)
}

// NewArtifact is a buffer to store.
type NewArtifact struct {
	Kind, Backend, FilenameBase, Extension, ContentType string
	Content                                             []byte
	Metadata                                            dyn.Map
}

// StoredArtifact is a stored artifact.
type StoredArtifact struct {
	ArtifactID string
	URL        string
}

// Router is a NeoRouter connection for a role ("search", "images").
type Router interface {
	// SearchWeb returns the results, or ok=false when no connection serves search.
	SearchWeb(ctx context.Context, userID int64, agentID, query string, count int, freshness any) ([]any, bool, error)
	// GenerateImages returns base64 PNGs, or ok=false when no connection serves images.
	GenerateImages(ctx context.Context, userID int64, agentID, prompt string, n int) ([]string, bool, error)
}

// Media covers what has no NeoRouter role: xAI images, vision, speech, OCR.
type Media interface {
	GenerateImagesXAI(ctx context.Context, prompt string, n int) ([]string, error)
	AnalyzeImage(ctx context.Context, userID int64, agentID, imagePath, question string) (any, error)
	Transcribe(ctx context.Context, userID int64, agentID, audioPath string) (string, error)
	OCR(ctx context.Context, imagePath string) (text string, confidence float64, err error)
}

// Health reads ingested health data.
type Health interface {
	Read(ctx context.Context, userID int64, metricType any, limit any) (any, error)
}

// SocialVideo extracts transcripts and frames from video links.
type SocialVideo interface {
	Extract(ctx context.Context, userID int64, agentID, url string, includeFrame, forceSTT bool) (any, error)
}

// SocialReach reads public social platforms.
type SocialReach interface {
	Status(ctx context.Context, userID int64) (any, error)
	Read(ctx context.Context, userID int64, args dyn.Map) (any, error)
	Search(ctx context.Context, userID int64, args dyn.Map) (any, error)
}

// WebShares shares a page served in the user's computer.
type WebShares interface {
	Share(ctx context.Context, userID int64, agentID string, name, port any) (any, error)
	Stop(ctx context.Context, userID int64, name any) (any, error)
	List(ctx context.Context, userID int64) (any, error)
}

// Agents creates persistent agents for a run.
type Agents interface {
	CreateForRun(ctx context.Context, run *Run, alreadyCreated bool, args dyn.Map) (dyn.Map, error)
}

// AgentCalls places an in-app call to the user.
type AgentCalls interface {
	CallUser(ctx context.Context, userID int64, agentID, runID, conversationID, openingMessage string) (any, error)
}

// AppSettings backs settings_read, settings_update and settings_link.
type AppSettings interface {
	Read(ctx context.Context, userID int64, agentID string, args dyn.Map) (any, error)
	Update(ctx context.Context, userID int64, agentID string, args dyn.Map) (any, error)
	Link(ctx context.Context, args dyn.Map) (any, error)
}

// SystemOne answers typed decisions for browser_act.
type SystemOne interface {
	Ready(ctx context.Context, userID int64, agentID string) (bool, error)
	Decide(ctx context.Context, userID int64, agentID, runID, stepID, phase string, state, questions dyn.Map) (dyn.Map, error)
	// InferStructured asks the fast model for a JSON object.
	InferStructured(ctx context.Context, userID int64, agentID, system, prompt string, maxTokens int) (dyn.Map, error)
}

// SynthID checks an image for Google's SynthID watermark.
type SynthID interface {
	Available() bool
	Detect(ctx context.Context, userID int64, imagePath string) (any, error)
}

// StructuredData queries CSV, TSV, JSON and SQLite files in the workspace.
type StructuredData interface {
	Query(ctx context.Context, userID int64, args dyn.Map) (any, error)
}

// CodeNavigator answers code_navigate (structure or semantic).
type CodeNavigator interface {
	Navigate(ctx context.Context, userID int64, args dyn.Map) (any, error)
}
