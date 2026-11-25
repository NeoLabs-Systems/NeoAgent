package voice

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/livevoice"
)

//go:embed declarations.json
var declarationsJSON []byte

// Tool names of the live model, as the Gemini adapter declares them.
const (
	toolRunTask = "run_task"
	toolEndCall = "end_call"
)

// Texts the live model gets as tool answers; fixed wording the Node adapter had.
const (
	textNoAnswer              = "The task runtime could not answer this call."
	textEmptyRequest          = "Nothing was started: the request was empty. Ask the owner what they want done."
	textHandoffWithoutRequest = "The hand-off arrived without a request. Ask the owner what they want done."
)

// Errors a call's control messages can fail with.
var (
	ErrShuttingDown = errors.New("Voice runtime is shutting down.")
	ErrNotFound     = errors.New("Voice session was not found.")
	ErrDenied       = errors.New("Voice session access denied.")
)

const shutdownTimeout = 10 * time.Second

// ManagerConfig wires the voice runtime.
type ManagerConfig struct {
	DB       *dbx.DB
	Log      *slog.Logger
	Getenv   func(string) string
	Agents   Agents
	AI       AIDirectory
	Persona  Persona
	Engine   Engine
	Render   Renderer
	ErrorFor ErrorWriter
	// Sanitize words an error for logs and model-facing text (publicerr.Sanitize).
	Sanitize func(string) string
	// HTTPClient reaches providers; a base URL is user input, so it should
	// refuse internal addresses.
	HTTPClient *http.Client
	Clock      livevoice.Clock
}

// CallNotifier hears when an agent-initiated call ends.
type CallNotifier interface {
	NotifySessionClosed(call *Call, reason string)
}

// Call is one live voice call as the runtime tracks it.
type Call struct {
	*livevoice.Session
	UserID         int64
	AgentID        string
	Platform       string
	DevicePlatform string
	ConversationID string
	AgentInitiated bool
	Provider       LiveProvider
	tasks          *taskBridge
}

// HasRunningWork reports whether a hand-off of this call is still running.
func (c *Call) HasRunningWork() bool { return c.tasks.HasRunningWork() }

// Manager runs live voice calls: opening, reattaching and ending them, and
// routing a client's audio and controls to the right one.
type Manager struct {
	cfg          ManagerConfig
	catalog      LiveCatalog
	settings     SettingsReader
	transcriber  *Transcriber
	declarations []any

	mu           sync.Mutex
	sessions     map[string]*Call
	shuttingDown bool
	shutdown     chan struct{}
	notifier     CallNotifier
}

// NewManager builds the runtime.
func NewManager(cfg ManagerConfig) (*Manager, error) {
	var declarations []any
	if err := json.Unmarshal(declarationsJSON, &declarations); err != nil {
		return nil, fmt.Errorf("voice: declarations: %w", err)
	}
	if cfg.Log == nil {
		cfg.Log = slog.Default()
	}
	if cfg.Clock == nil {
		cfg.Clock = livevoice.RealClock{}
	}
	defaults := Defaults{Getenv: cfg.Getenv}
	settings := SettingsReader{DB: cfg.DB, Agents: cfg.Agents, Defaults: defaults}
	return &Manager{
		cfg:          cfg,
		catalog:      LiveCatalog{AI: cfg.AI, Defaults: defaults},
		settings:     settings,
		transcriber:  NewTranscriber(cfg.AI, settings, cfg.HTTPClient),
		declarations: declarations,
		sessions:     map[string]*Call{},
		shutdown:     make(chan struct{}),
	}, nil
}

// Transcriber is the speech-to-text side of the runtime.
func (m *Manager) Transcriber() *Transcriber { return m.transcriber }

// SetCallNotifier registers who hears about ended agent-initiated calls.
func (m *Manager) SetCallNotifier(n CallNotifier) {
	m.mu.Lock()
	m.notifier = n
	m.mu.Unlock()
}

// Capabilities is what the settings UI offers: the live voice models the
// account's keys can reach, plus the transcription providers used for voice
// notes and dictation.
type Capabilities struct {
	CatalogInfo
	Transcription STTCapabilities `json:"transcription"`
}

// GetCapabilities describes the voice options of an agent.
func (m *Manager) GetCapabilities(ctx context.Context, userID int64, agentID string) Capabilities {
	return Capabilities{
		CatalogInfo:   m.catalog.Describe(ctx, userID, agentID),
		Transcription: m.transcriber.Describe(ctx, userID, agentID),
	}
}

func (m *Manager) get(sessionID string) *Call {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.sessions[strings.TrimSpace(sessionID)]
}

// Session finds a call by id.
func (m *Manager) Session(sessionID string) *Call { return m.get(sessionID) }

// OpenOptions describe a call to open.
type OpenOptions struct {
	UserID  int64
	AgentID string
	// SessionID names the call; a known id reattaches instead of starting over.
	SessionID          string
	Platform           string
	Sink               livevoice.Sink
	OriginConversation string
	AgentInitiated     bool
	// InputMode overrides the account's input mode (the wearable is push-to-talk).
	InputMode      string
	DevicePlatform string
}

// OpenSession starts a call. Reopening a known session id (a reconnecting
// client, or a client coming back while a hand-off is still running)
// reattaches instead of starting over.
func (m *Manager) OpenSession(ctx context.Context, o OpenOptions) (*Call, error) {
	m.mu.Lock()
	if m.shuttingDown {
		m.mu.Unlock()
		return nil, ErrShuttingDown
	}
	existing := m.sessions[strings.TrimSpace(o.SessionID)]
	m.mu.Unlock()
	if existing != nil {
		if err := assertOwner(existing, o.UserID); err != nil {
			return nil, err
		}
		if err := existing.Attach(ctx, o.Sink); err != nil {
			return nil, err
		}
		return existing, nil
	}

	agentID, err := m.cfg.Agents.Resolve(ctx, o.UserID, o.AgentID)
	if err != nil {
		return nil, err
	}
	configured, err := m.settings.Read(ctx, o.UserID, agentID)
	if err != nil {
		return nil, err
	}
	if o.InputMode != "" {
		configured.InputMode = o.InputMode
	}
	provider, _ := ProviderByID(configured.LiveProvider)
	model, found, err := m.catalog.Resolve(ctx, o.UserID, agentID, provider, configured.LiveModel)
	if err != nil {
		return nil, err
	}
	if !found {
		return nil, fmt.Errorf("%s lists no live voice model for this account. Check its API key.", provider.Label)
	}
	creds := m.cfg.AI.ProviderCredentials(o.UserID, provider.RuntimeProvider, agentID)
	creds.APIKey, creds.BaseURL = strings.TrimSpace(creds.APIKey), strings.TrimSpace(creds.BaseURL)

	id := strings.TrimSpace(o.SessionID)
	if id == "" {
		id = newRunID()
	}
	conversationID := o.OriginConversation
	if conversationID == "" {
		if conversationID, err = m.cfg.Persona.DefaultWebConversationID(o.UserID, agentID); err != nil {
			return nil, err
		}
	}
	call := m.newCall(id, o, agentID, conversationID, provider, model, configured, creds)

	m.mu.Lock()
	m.sessions[id] = call
	m.mu.Unlock()
	if err := call.Connect(ctx); err != nil {
		m.mu.Lock()
		delete(m.sessions, id)
		m.mu.Unlock()
		call.Close("connect_failed")
		return nil, err
	}
	return call, nil
}

func (m *Manager) newCall(id string, o OpenOptions, agentID, conversationID string, provider LiveProvider, model LiveModel, settings RuntimeSettings, creds Credentials) *Call {
	render := m.cfg.Render
	bridge := newTaskBridge(m.cfg.Engine, render, m.sanitizeError, m.cfg.Log)
	bridge.userID, bridge.agentID, bridge.sessionID, bridge.conversationID = o.UserID, agentID, id, conversationID
	call := &Call{
		UserID: o.UserID, AgentID: agentID, Platform: o.Platform, DevicePlatform: o.DevicePlatform,
		ConversationID: conversationID, AgentInitiated: o.AgentInitiated, Provider: provider, tasks: bridge,
	}
	call.Session = livevoice.NewSession(livevoice.Config{
		ID:       id,
		Provider: livevoice.Provider{ID: provider.ID, InputSampleRate: provider.InputSampleRate, OutputSampleRate: provider.OutputSampleRate},
		Settings: livevoice.Settings{Model: model.ID, Voice: settings.LiveVoice, InputMode: settings.InputMode},
		Sink:     o.Sink,
		NewAdapter: func(h livevoice.Handlers) livevoice.Adapter {
			return m.newAdapter(provider, model, settings, creds, h)
		},
		BuildPrompt: func(ctx context.Context) (livevoice.Prompt, error) {
			return buildLivePrompt(ctx, m.cfg.Persona, render, promptInputs{
				userID: o.UserID, agentID: agentID, conversationID: conversationID,
				runningTasks: bridge.runningTasksForPrompt(), taskTools: provider.TaskTools, devicePlatform: o.DevicePlatform,
			})
		},
		Tasks:        bridge,
		Store:        turnStore{db: m.cfg.DB, userID: o.UserID, agentID: agentID, conversationID: conversationID, sessionID: id},
		Texts:        m.texts(),
		DelegateTool: toolRunTask,
		ErrorFor:     func(err error) string { return m.cfg.ErrorFor(o.UserID, err) },
		OnIdle:       func(reason string) { m.forget(call, reason) },
		OnHangUp: func() {
			if err := m.CloseSession(id, "agent_hung_up", o.UserID, false); err != nil {
				m.cfg.Log.Warn("Failed to end hung-up voice call", "error", err.Error())
			}
		},
		Clock: m.cfg.Clock,
		Log:   m.cfg.Log,
	})
	bridge.session = call.Session
	return call
}

func (m *Manager) texts() livevoice.Texts {
	render := m.cfg.Render
	return livevoice.Texts{
		TaskStarted:           render("voice/task_started.md", nil),
		NoAnswer:              textNoAnswer,
		EmptyRequest:          textEmptyRequest,
		HandoffWithoutRequest: textHandoffWithoutRequest,
		Unanswered:            render("voice/unanswered.md", nil),
		StatusUpdate: func(seconds int, facts string) string {
			return render("voice/status_update.md", map[string]string{"seconds": strconv.Itoa(seconds), "facts": facts})
		},
		LineDropped: func(last string) string {
			return render("voice/line_dropped.md", map[string]string{"last": last})
		},
	}
}

func (m *Manager) newAdapter(provider LiveProvider, model LiveModel, settings RuntimeSettings, creds Credentials, h livevoice.Handlers) livevoice.Adapter {
	if provider.Adapter == "openai" {
		return livevoice.NewOpenAI(livevoice.OpenAIConfig{
			APIKey: creds.APIKey, BaseURL: creds.BaseURL, Model: model.ID, Voice: settings.LiveVoice,
			HTTPClient: m.cfg.HTTPClient, Handlers: h,
		})
	}
	return livevoice.NewGemini(livevoice.GeminiConfig{
		APIKey: creds.APIKey, BaseURL: creds.BaseURL, Model: model.ID, Thinking: model.Thinking,
		Voice: settings.LiveVoice, InputMode: settings.InputMode, FunctionDeclarations: m.declarations,
		HangUpTool: toolEndCall, HTTPClient: m.cfg.HTTPClient, Handlers: h,
	})
}

func (m *Manager) sanitizeError(err error) string {
	if m.cfg.Sanitize != nil {
		return m.cfg.Sanitize(err.Error())
	}
	return err.Error()
}

// OpenFlutterSession opens a call for the app; sink delivers its events over
// the client's socket.
func (m *Manager) OpenFlutterSession(ctx context.Context, o OpenOptions) (*Call, error) {
	if o.Sink == nil {
		return nil, errors.New("Socket is required to open a voice session.")
	}
	o.Platform = "voice_live"
	return m.OpenSession(ctx, o)
}

// OpenWearableSession opens a call for the wearable. It talks while its avatar
// is held, whatever the account's input mode: its calls are always push-to-talk.
func (m *Manager) OpenWearableSession(ctx context.Context, o OpenOptions) (*Call, error) {
	o.Platform = "wearable_live"
	o.InputMode = InputPTT
	return m.OpenSession(ctx, o)
}

// OpenWearableCall is OpenWearableSession as the wearable gateway uses it: the
// call's id comes back, and its events go to sink.
func (m *Manager) OpenWearableCall(ctx context.Context, userID int64, agentID, sessionID, devicePlatform string, sink livevoice.Sink) (string, error) {
	call, err := m.OpenWearableSession(ctx, OpenOptions{
		UserID: userID, AgentID: agentID, SessionID: sessionID, DevicePlatform: devicePlatform, Sink: sink,
	})
	if err != nil {
		return "", err
	}
	return call.ID(), nil
}

// HasActiveSessionForUser reports whether the account is on a call.
func (m *Manager) HasActiveSessionForUser(userID int64) bool {
	m.mu.Lock()
	calls := make([]*Call, 0, len(m.sessions))
	for _, c := range m.sessions {
		calls = append(calls, c)
	}
	m.mu.Unlock()
	for _, c := range calls {
		if c.UserID == userID && c.Attached() {
			return true
		}
	}
	return false
}

// AppendAudio passes microphone audio of a call to the model.
func (m *Manager) AppendAudio(sessionID string, pcm []byte, userID int64) error {
	call, err := m.require(sessionID, userID)
	if err != nil {
		return err
	}
	call.AppendAudio(pcm)
	return nil
}

// StartInput marks the start of a push-to-talk turn.
func (m *Manager) StartInput(sessionID string, userID int64) error {
	call, err := m.require(sessionID, userID)
	if err != nil {
		return err
	}
	call.StartInput()
	return nil
}

// EndInput marks the end of a turn.
func (m *Manager) EndInput(sessionID string, userID int64) error {
	call, err := m.require(sessionID, userID)
	if err != nil {
		return err
	}
	call.EndInput()
	return nil
}

// InterruptOutput stops the assistant talking.
func (m *Manager) InterruptOutput(sessionID string, userID int64) error {
	call, err := m.require(sessionID, userID)
	if err != nil {
		return err
	}
	call.InterruptOutput()
	return nil
}

// CancelTask is the call screen's stop button: it stops the run, or the newest
// task of the call without a run id.
func (m *Manager) CancelTask(sessionID string, userID int64, runID string) error {
	call, err := m.require(sessionID, userID)
	if err != nil {
		return err
	}
	call.tasks.CancelFromScreen(runID)
	return nil
}

// DetachSession: the client went away. Running hand-offs keep going and the
// session stays reattachable until they finish.
func (m *Manager) DetachSession(sessionID, reason string, userID int64) error {
	call := m.get(sessionID)
	if call == nil {
		return nil
	}
	if err := assertOwner(call, userID); err != nil {
		return err
	}
	m.cfg.Log.Info("Voice client detached", "sessionId", sessionID, "reason", reason, "runActive", call.HasRunningWork())
	call.Detach()
	return nil
}

// CloseSession ends a call. With work still running the client only detaches,
// unless cancelTask asks for the work to stop too.
func (m *Manager) CloseSession(sessionID, reason string, userID int64, cancelTask bool) error {
	call := m.get(sessionID)
	if call == nil {
		return nil
	}
	if err := assertOwner(call, userID); err != nil {
		return err
	}
	m.cfg.Log.Info("Live voice call ending", "sessionId", sessionID, "reason", reason, "provider", call.Provider.ID)
	if call.HasRunningWork() && !cancelTask {
		call.Detach()
	} else {
		m.mu.Lock()
		delete(m.sessions, call.ID())
		m.mu.Unlock()
		m.closeCall(call, reason, cancelTask)
	}
	m.notifyClosed(call, reason)
	return nil
}

func (m *Manager) closeCall(call *Call, reason string, cancelTasks bool) {
	if cancelTasks {
		call.tasks.AbortAll("voice_session_closed")
	}
	call.Close(reason)
}

// forget releases a call nobody listens to and no task keeps alive.
func (m *Manager) forget(call *Call, reason string) {
	m.mu.Lock()
	if m.sessions[call.ID()] != call {
		m.mu.Unlock()
		return
	}
	delete(m.sessions, call.ID())
	m.mu.Unlock()
	m.cfg.Log.Info("Live voice call ending", "sessionId", call.ID(), "reason", reason, "provider", call.Provider.ID)
	call.Close(reason)
	m.notifyClosed(call, reason)
}

func (m *Manager) notifyClosed(call *Call, reason string) {
	m.mu.Lock()
	n := m.notifier
	m.mu.Unlock()
	if n != nil {
		n.NotifySessionClosed(call, reason)
	}
}

// PresentDelivery handles outbox deliveries for voice-originated runs. A
// session whose client is gone reports detached, and the delivery worker shows
// the result in chat instead.
func (m *Manager) PresentDelivery(entry Delivery) (detached bool) {
	call := m.get(entry.Recipient)
	if call == nil || !call.Attached() {
		return true
	}
	call.tasks.Present(entry)
	return false
}

// Say has the model tell the owner something once the line is free.
func (m *Manager) Say(sessionID, text string) {
	if call := m.get(sessionID); call != nil {
		call.Say(text)
	}
}

// Shutdown ends every call and waits a bounded time for the providers.
func (m *Manager) Shutdown(ctx context.Context) {
	m.mu.Lock()
	if m.shuttingDown {
		m.mu.Unlock()
		<-m.shutdown
		return
	}
	m.shuttingDown = true
	calls := make([]*Call, 0, len(m.sessions))
	for _, c := range m.sessions {
		calls = append(calls, c)
	}
	m.sessions = map[string]*Call{}
	m.mu.Unlock()

	var wg sync.WaitGroup
	for _, c := range calls {
		wg.Add(1)
		go func() {
			defer wg.Done()
			m.closeCall(c, "server_shutdown", true)
		}()
	}
	done := make(chan struct{})
	go func() { wg.Wait(); close(done) }()
	select {
	case <-done:
	case <-time.After(shutdownTimeout):
	case <-ctx.Done():
	}
	close(m.shutdown)
}

func (m *Manager) require(sessionID string, userID int64) (*Call, error) {
	m.mu.Lock()
	shutting := m.shuttingDown
	m.mu.Unlock()
	if shutting {
		return nil, ErrShuttingDown
	}
	call := m.get(sessionID)
	if call == nil {
		return nil, ErrNotFound
	}
	return call, assertOwner(call, userID)
}

func assertOwner(call *Call, userID int64) error {
	if userID == 0 || call.UserID != userID {
		return ErrDenied
	}
	return nil
}
