package wiring

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/neorouterapi"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/NeoLabs-Systems/neoagent/internal/sockets"
	"github.com/NeoLabs-Systems/neoagent/internal/voice"
	"github.com/NeoLabs-Systems/neolabs-go/livevoice"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
	"github.com/NeoLabs-Systems/neolabs-go/llm/providers"
	"github.com/NeoLabs-Systems/neolabs-go/llm/transport"
	"github.com/NeoLabs-Systems/neolabs-go/realtime"
)

// ── Live voice model lists ───────────────────────────────────────────────────

const (
	voiceModelRefresh        = 5 * time.Minute
	voiceModelPermanentRetry = 30 * time.Minute
	voiceModelTimeout        = 10 * time.Second
)

var permanentDiscoveryError = regexp.MustCompile(`(?i)401|403|unauthorized|forbidden|credits|spending`)

type voiceModelEntry struct {
	models  []voice.LiveModel
	expires time.Time
}

// voiceModels caches each provider's live model list like the chat models: the
// last list serves while the next one loads; only the first lookup waits.
type voiceModels struct {
	mu         sync.Mutex
	entries    map[[32]byte]voiceModelEntry
	refreshing map[[32]byte]chan struct{}
}

var liveModelLists = &voiceModels{entries: map[[32]byte]voiceModelEntry{}, refreshing: map[[32]byte]chan struct{}{}}

var neoRouterAuto = regexp.MustCompile(`^auto(-(free|plan|paid))?(:|$)`)

func (v *voiceModels) list(ctx context.Context, provider string, creds voice.Credentials, nr *neorouterapi.Service) ([]voice.LiveModel, error) {
	key := sha256.Sum256([]byte(provider + "\x00" + creds.APIKey + "\x00" + creds.BaseURL + "\x00voice"))
	v.mu.Lock()
	existing, have := v.entries[key]
	if have && time.Now().Before(existing.expires) {
		v.mu.Unlock()
		return existing.models, nil
	}
	done, running := v.refreshing[key]
	if !running {
		done = make(chan struct{})
		v.refreshing[key] = done
		go func() {
			models, err := loadLiveModels(context.WithoutCancel(ctx), provider, creds, nr)
			entry := voiceModelEntry{models: models, expires: time.Now().Add(voiceModelRefresh)}
			if err != nil {
				entry.models = existing.models
				if permanentDiscoveryError.MatchString(err.Error()) {
					entry.expires = time.Now().Add(voiceModelPermanentRetry)
				}
			}
			v.mu.Lock()
			v.entries[key] = entry
			delete(v.refreshing, key)
			v.mu.Unlock()
			close(done)
		}()
	}
	v.mu.Unlock()
	if have {
		return existing.models, nil
	}
	select {
	case <-done:
	case <-ctx.Done():
		return nil, ctx.Err()
	}
	v.mu.Lock()
	defer v.mu.Unlock()
	return v.entries[key].models, nil
}

func loadLiveModels(ctx context.Context, provider string, creds voice.Credentials, nr *neorouterapi.Service) ([]voice.LiveModel, error) {
	ctx, cancel := context.WithTimeout(ctx, voiceModelTimeout)
	defer cancel()
	if provider == "neorouter" {
		models, err := nr.ListModels(ctx, &neorouterapi.Connection{APIKey: creds.APIKey, APIBase: creds.BaseURL}, "live")
		if err != nil {
			return nil, err
		}
		out := make([]voice.LiveModel, 0, len(models))
		for _, m := range models {
			id := m.ID
			if neoRouterAuto.MatchString(id) && !strings.Contains(id, ":") {
				id += ":default"
			}
			lm := voice.LiveModel{ID: id, Protocols: []string{}}
			if m.NeoRouter != nil {
				lm.Protocols = m.NeoRouter.Protocols
			}
			out = append(out, lm)
		}
		return out, nil
	}
	p, err := providers.New(provider, providers.Config{Config: transport.Config{APIKey: creds.APIKey, BaseURL: creds.BaseURL, HTTPClient: modelHTTP(false)}})
	if err != nil {
		return nil, err
	}
	lister, ok := p.(llm.LiveVoiceLister)
	if !ok {
		return nil, nil
	}
	models, err := lister.LiveVoiceModels(ctx)
	if err != nil {
		return nil, err
	}
	seen := map[string]bool{}
	var out []voice.LiveModel
	for _, m := range models {
		id := strings.TrimSpace(m.ID)
		if id == "" || seen[id] {
			continue
		}
		seen[id] = true
		out = append(out, voice.LiveModel{ID: id, Thinking: m.Thinking, Protocols: m.Protocols})
	}
	return out, nil
}

// ── API_KEYS.json ────────────────────────────────────────────────────────────

// resolveAPIKey finds a key in the server environment, then in the agent data
// directory's API_KEYS.json (decrypted where the file holds sealed values).
func resolveAPIKey(names []string, dataDir string, decrypt func(string) string) string {
	for _, name := range names {
		if value := strings.TrimSpace(os.Getenv(name)); value != "" {
			return value
		}
	}
	if dataDir == "" {
		return ""
	}
	raw, err := os.ReadFile(filepath.Join(dataDir, "API_KEYS.json"))
	if err != nil {
		return ""
	}
	var parsed map[string]any
	if json.Unmarshal(raw, &parsed) != nil {
		return ""
	}
	for _, name := range names {
		for _, variant := range []string{name, strings.ToLower(name)} {
			s, _ := parsed[variant].(string)
			if decrypt != nil {
				s = decrypt(s)
			}
			if value := strings.TrimSpace(s); value != "" {
				return value
			}
		}
	}
	return ""
}

// ── The engine behind live voice ─────────────────────────────────────────────

// voiceEngine runs what the live model hands off as ordinary agent runs.
type voiceEngine struct{ link *engineLink }

func (v voiceEngine) Run(ctx context.Context, userID int64, request string, o voice.RunOptions) (voice.RunResult, error) {
	e := v.link.get()
	if e == nil {
		return voice.RunResult{}, errEngineNotReady
	}
	result, err := e.Run(ctx, userID, request, agent.Options{RunID: o.RunID, AgentID: o.AgentID, ConversationID: o.ConversationID, TriggerSource: o.TriggerSource,
		Source: o.Source, ChatID: o.ChatID, VoiceSessionID: o.VoiceSessionID, LatencyPriority: o.LatencyPriority,
		Context: agent.RunContext{RawUserMessage: o.RawUserMessage}})
	if err != nil {
		return voice.RunResult{}, err
	}
	return voice.RunResult{Status: result.Status, Content: result.Content}, nil
}

func (v voiceEngine) RunMeta(runID string) (voice.RunMeta, bool) {
	e := v.link.get()
	if e == nil {
		return voice.RunMeta{}, false
	}
	r, ok := e.RunInfo(runID)
	if !ok {
		return voice.RunMeta{}, false
	}
	return voice.RunMeta{Aborted: r.Aborted(), Status: r.Status(), Request: r.Request}, true
}

func (v voiceEngine) Abort(runID string, userID int64, reason string) bool {
	e := v.link.get()
	return e != nil && e.Abort(runID, userID, reason)
}

func toVoiceRuns(runs []agent.BackgroundRun) []voice.BackgroundRun {
	out := make([]voice.BackgroundRun, len(runs))
	for i, r := range runs {
		steps := make([]voice.RunStep, len(r.RecentSteps))
		for j, s := range r.RecentSteps {
			steps[j] = voice.RunStep{Step: dyn.Str(s["step"]), Status: dyn.Str(s["status"]), StartedAt: dyn.Str(s["started_at"]),
				CompletedAt: dyn.Str(s["completed_at"]), Error: dyn.Str(s["error"])}
		}
		out[i] = voice.BackgroundRun{RunID: r.RunID, Request: r.Request, Channel: r.Channel, StartedAt: dyn.Str(r.StartedAt), Status: r.Status, RecentSteps: steps}
	}
	return out
}

func (v voiceEngine) BackgroundRuns(userID int64, agentID string) []voice.BackgroundRun {
	e := v.link.get()
	if e == nil {
		return []voice.BackgroundRun{}
	}
	return toVoiceRuns(e.ListBackgroundRuns(userID, agentID, "", true))
}

func (v voiceEngine) ApplyBackgroundAction(userID int64, agentID string, runs []voice.BackgroundRun, voiceSessionID string, args map[string]any) map[string]any {
	e := v.link.get()
	if e == nil {
		return map[string]any{"error": errEngineNotReady.Error()}
	}
	// The engine re-reads its own records of the listed runs.
	listed := map[string]bool{}
	for _, r := range runs {
		listed[r.RunID] = true
	}
	var own []agent.BackgroundRun
	for _, r := range e.ListBackgroundRuns(userID, agentID, "", true) {
		if listed[r.RunID] {
			own = append(own, r)
		}
	}
	return e.ApplyBackgroundAction(userID, agentID, own, map[string]any{"fromVoiceSessionId": voiceSessionID}, args)
}

// voicePersona is what the live model is told about the owner and the
// conversation around a call.
type voicePersona struct {
	link    *engineLink
	sources *agent.PromptSources
	mem     *memory.Manager
}

func (p voicePersona) Sections(ctx context.Context, userID int64, agentID string) ([]string, error) {
	return p.sources.VoicePersonaSections(ctx, userID, agentID, "")
}

func (p voicePersona) LocalNow(userID int64) string {
	return p.sources.LocalNow(context.Background(), userID, time.Now())
}

func (p voicePersona) DefaultWebConversationID(userID int64, agentID string) (string, error) {
	return p.mem.DefaultWebConversationID(context.Background(), userID, agentID)
}

func (p voicePersona) RecentContext(conversationID string, limit int) (voice.Context, error) {
	e := p.link.get()
	if e == nil {
		return voice.Context{}, errEngineNotReady
	}
	summary, messages := e.ConversationContext(context.Background(), conversationID, limit)
	out := voice.Context{Summary: summary}
	for _, m := range messages {
		// Only plain text turns are spoken history.
		text, _ := m.Content.(string)
		out.Messages = append(out.Messages, voice.ContextMessage{Role: m.Role, Content: text, HasToolCalls: len(m.ToolCalls) > 0})
	}
	return out, nil
}

// voiceAgents names an agent for the call screen.
type voiceAgents struct{ r agentscope.Resolver }

func (a voiceAgents) Describe(ctx context.Context, userID int64, agentID string) (string, string) {
	id, err := a.r.Resolve(ctx, userID, agentID)
	if err != nil || id == "" {
		return "", ""
	}
	var name string
	_ = a.r.DB.R.QueryRowContext(ctx, `SELECT display_name FROM agents WHERE user_id = ? AND id = ?`, userID, id).Scan(&name)
	return id, name
}

// voiceRealtime is the socket hub as agent calls use it.
type voiceRealtime struct{ emitter *deferredEmitter }

func (v voiceRealtime) hub() *realtime.Hub {
	v.emitter.mu.RLock()
	defer v.emitter.mu.RUnlock()
	if v.emitter.srv == nil {
		return nil
	}
	return v.emitter.srv.Hub()
}

func (v voiceRealtime) UserSocketIDs(ctx context.Context, userID int64) []string {
	hub := v.hub()
	if hub == nil {
		return nil
	}
	var ids []string
	for _, s := range hub.Sockets(realtime.UserRoom(userID)) {
		ids = append(ids, s.ID())
	}
	return ids
}

func (v voiceRealtime) EmitToUser(userID int64, event string, payload any) {
	v.emitter.EmitToUser(userID, event, payload)
}

// EmitToSocket reaches one socket through the room every socket joins under
// its own id.
func (v voiceRealtime) EmitToSocket(socketID, event string, payload any) {
	if hub := v.hub(); hub != nil {
		hub.EmitToRoom(socketID, event, payload)
	}
}

func (v voiceRealtime) EmitToUserExcept(userID int64, exceptSocketID, event string, payload any) {
	if hub := v.hub(); hub != nil {
		_ = hub.To(realtime.UserRoom(userID)).Except(exceptSocketID).Emit(event, payload)
	}
}

// voiceDelivery hands outbox deliveries of call-started runs to their call.
type voiceDelivery struct{ m *voice.Manager }

func (v voiceDelivery) PresentDelivery(entry *runledger.Entry) (bool, bool) {
	meta := entry.Metadata()
	liveness, _ := meta["liveness"].(map[string]any)
	detached := v.m.PresentDelivery(voice.Delivery{Recipient: entry.Recipient, RunID: entry.RunID, MessageKind: entry.MessageKind, Content: entry.Content(),
		Kind: dyn.Str(meta["kind"]), ExpectsReply: meta["expectsReply"] == true, LivenessStatus: dyn.Str(liveness["status"])})
	return !detached, detached
}

// ── Sockets ──────────────────────────────────────────────────────────────────

func peerSink(peer sockets.Peer) livevoice.Sink {
	return livevoice.SinkFunc(func(event string, payload map[string]any) { _ = peer.Emit(event, payload) })
}

// socketVoice is the voice runtime and the agent-call coordinator as the
// socket server uses them.
type socketVoice struct {
	m     *voice.Manager
	calls *voice.Coordinator
}

func (s socketVoice) OpenFlutterSession(ctx context.Context, o sockets.OpenVoiceSession) (string, error) {
	if o.Peer == nil {
		return "", errors.New("Socket is required to open a voice session.")
	}
	call, err := s.m.OpenFlutterSession(ctx, voice.OpenOptions{UserID: o.UserID, AgentID: o.AgentID, SessionID: o.SessionID, Sink: peerSink(o.Peer)})
	if err != nil {
		return "", err
	}
	return call.ID(), nil
}

func (s socketVoice) AppendAudio(id string, audio []byte, userID int64) error {
	return s.m.AppendAudio(id, audio, userID)
}
func (s socketVoice) StartInput(id string, userID int64) error { return s.m.StartInput(id, userID) }
func (s socketVoice) EndInput(id string, userID int64) error   { return s.m.EndInput(id, userID) }
func (s socketVoice) InterruptOutput(id string, userID int64) error {
	return s.m.InterruptOutput(id, userID)
}
func (s socketVoice) CancelTask(id string, userID int64, runID string) error {
	return s.m.CancelTask(id, userID, runID)
}
func (s socketVoice) CloseSession(_ context.Context, id, reason string, userID int64, cancelTask bool) error {
	return s.m.CloseSession(id, reason, userID, cancelTask)
}
func (s socketVoice) DetachSession(_ context.Context, id, reason string, userID int64) error {
	return s.m.DetachSession(id, reason, userID)
}

func (s socketVoice) OfferPendingCall(peer sockets.Peer, userID int64) {
	s.calls.OfferPendingCall(peer.ID(), userID)
}

func (s socketVoice) Accept(ctx context.Context, callID string, userID int64, peer sockets.Peer) (sockets.AcceptResult, error) {
	r := s.calls.Accept(ctx, callID, userID, peer.ID())
	return sockets.AcceptResult{Accepted: r.Accepted, Status: r.Status, SessionID: r.SessionID}, nil
}

func (s socketVoice) Decline(callID string, userID int64, peer sockets.Peer, later bool) error {
	s.calls.Decline(callID, userID, peer.ID(), later)
	return nil
}

func (s socketVoice) HandleDisconnect(socketID string, userID int64) {
	s.calls.HandleDisconnect(socketID, userID)
}
