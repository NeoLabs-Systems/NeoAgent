package wiring

import (
	"context"
	"errors"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/neorouterapi"
	"github.com/NeoLabs-Systems/neoagent/internal/skilllearning"
	"github.com/NeoLabs-Systems/neoagent/internal/teach"
	"github.com/NeoLabs-Systems/neoagent/internal/voice"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

// ── Structured inference, image analysis, transcription ─────────────────────

func (l *engineLink) inferStructured(ctx context.Context, userID int64, agentID, purpose, system, prompt string, maxTokens int) (map[string]any, error) {
	e := l.get()
	if e == nil {
		return nil, errEngineNotReady
	}
	answer, err := e.InferStructured(ctx, agent.StructuredRequest{UserID: userID, AgentID: agentID, Purpose: purpose, System: system, Prompt: prompt, MaxTokens: maxTokens})
	if err != nil {
		return nil, err
	}
	return answer.Parsed, nil
}

func (l *engineLink) analyzeImage(ctx context.Context, userID int64, agentID, path, question string) (any, error) {
	e := l.get()
	if e == nil {
		return nil, errEngineNotReady
	}
	return e.AnalyzeImage(ctx, userID, agentID, path, "", "", question)
}

// voiceDirectory is the AI domain as speech-to-text needs it.
type voiceDirectory struct {
	catalog settingsCatalogAdapter
	// dataDir and decrypt find keys in API_KEYS.json.
	dataDir string
	decrypt func(string) string
}

// ProviderCredentials is the key and address a provider is called with: the
// account's own key, else the server's, as for chat models.
func (v voiceDirectory) ProviderCredentials(userID int64, provider, agentID string) voice.Credentials {
	statuses, err := v.catalog.store.ProviderStatuses(context.Background(), userID, agentID)
	if err != nil {
		return voice.Credentials{}
	}
	for _, st := range statuses {
		if st.ID == provider {
			_, key, base, _ := resolveProvider(st)
			return voice.Credentials{APIKey: key, BaseURL: base}
		}
	}
	return voice.Credentials{}
}

func (v voiceDirectory) ProviderServesRole(provider string, userID int64, agentID, role string) bool {
	if provider != "neorouter" {
		return true
	}
	return v.catalog.routerForRole(context.Background(), userID, agentID, role) != nil
}

func (v voiceDirectory) ListVoiceModels(ctx context.Context, userID int64, provider string, creds voice.Credentials) ([]voice.LiveModel, error) {
	return liveModelLists.list(ctx, provider, creds, v.catalog.nr)
}

func (v voiceDirectory) NeoRouterFor(userID int64, agentID, role string) (voice.Router, bool) {
	conn := v.catalog.routerForRole(context.Background(), userID, agentID, role)
	if conn == nil {
		return voice.Router{}, false
	}
	return voice.Router{APIKey: conn.APIKey, APIBase: conn.APIBase}, true
}

func (v voiceDirectory) NeoRouterModels(ctx context.Context, router voice.Router, role string) ([]voice.RouterModel, error) {
	models, err := v.catalog.nr.ListModels(ctx, &neorouterapi.Connection{APIKey: router.APIKey, APIBase: router.APIBase}, role)
	if err != nil {
		return nil, err
	}
	out := make([]voice.RouterModel, len(models))
	for i, m := range models {
		out[i] = voice.RouterModel{ID: m.ID, Name: m.ID}
	}
	return out, nil
}

func (v voiceDirectory) ResolveAPIKey(names []string) string {
	return resolveAPIKey(names, v.dataDir, v.decrypt)
}

func newTranscribe(db *dbx.DB, agents agentscope.Resolver, directory voiceDirectory) func(ctx context.Context, userID int64, agentID, path string) (string, error) {
	transcriber := voice.NewTranscriber(directory, voice.SettingsReader{DB: db, Agents: agents, Defaults: voice.Defaults{Getenv: os.Getenv}},
		ssrf.NewClient(ssrf.Options{Timeout: 2 * time.Minute}))
	return func(ctx context.Context, userID int64, agentID, path string) (string, error) {
		return transcriber.TranscribeFile(ctx, userID, agentID, path, "", 0)
	}
}

// ── Skill learning ──────────────────────────────────────────────────────────

type skillLearner struct{ s *skilllearning.Service }

func (l skillLearner) EnqueueCompletedRun(userID int64, agentID, runID, triggerType, triggerSource, task string, taskID int64, finalContent string, iterations int, messages []llm.Message) {
	l.s.EnqueueCompletedRun(skilllearning.CompletedRun{UserID: userID, AgentID: agentID, RunID: runID, TriggerType: triggerType, TriggerSource: triggerSource,
		Task: task, FinalContent: finalContent, TaskID: taskID, Iterations: iterations, Messages: messages})
}

// teachLearner turns a Teach Mode demonstration into a skill.
type teachLearner struct{ s *skilllearning.Service }

func (l teachLearner) LearnFromComputerDemonstration(ctx context.Context, d teach.Demonstration) (teach.Learned, error) {
	userID, err := strconv.ParseInt(d.UserKey, 10, 64)
	if err != nil {
		return teach.Learned{}, errors.New("Computer learning requires a user and demonstrated goal.")
	}
	result, err := l.s.LearnFromComputerDemonstration(ctx, userID, d.AgentID, d.Goal, d.Evidence)
	if err != nil {
		return teach.Learned{}, err
	}
	return teach.Learned{Success: result.Success, Ignored: result.Ignored, Name: result.Name, Description: result.Description, Error: result.Error}, nil
}

// teachImages describes Teach Mode screenshots with a vision model.
type teachImages struct{ link *engineLink }

func (t teachImages) Describe(ctx context.Context, userKey, agentID, imageBase64, mimeType, question string) (string, error) {
	e := t.link.get()
	if e == nil {
		return "", errEngineNotReady
	}
	userID, err := strconv.ParseInt(userKey, 10, 64)
	if err != nil {
		return "", err
	}
	answer, err := e.AnalyzeImage(ctx, userID, agentID, "", imageBase64, mimeType, question)
	return answer.Description, err
}

// ── Late-bound computer collaborators ──────────────────────────────────────

// lateTeach is Teach Mode for the computer routes, set once it is built.
type lateTeach struct {
	mu sync.RWMutex
	s  *teach.Service
}

func (t *lateTeach) set(s *teach.Service) {
	t.mu.Lock()
	t.s = s
	t.mu.Unlock()
}

func (t *lateTeach) service() (*teach.Service, error) {
	t.mu.RLock()
	defer t.mu.RUnlock()
	if t.s == nil {
		return nil, errors.New("Teach Mode is unavailable.")
	}
	return t.s, nil
}

func (t *lateTeach) ActiveSummary(userKey string) (teach.Summary, bool) {
	s, err := t.service()
	if err != nil {
		return teach.Summary{}, false
	}
	return s.ActiveSummary(userKey)
}

func (t *lateTeach) StartSession(ctx context.Context, userKey string, in teach.StartInput) (teach.Summary, error) {
	s, err := t.service()
	if err != nil {
		return teach.Summary{}, err
	}
	return s.StartSession(ctx, userKey, in)
}

func (t *lateTeach) Record(ctx context.Context, userKey string, event map[string]any) (teach.RecordResult, error) {
	s, err := t.service()
	if err != nil {
		return teach.RecordResult{}, err
	}
	return s.Record(ctx, userKey, event)
}

func (t *lateTeach) StopSession(ctx context.Context, userKey, sessionID string) (teach.StopResult, error) {
	s, err := t.service()
	if err != nil {
		return teach.StopResult{}, err
	}
	return s.StopSession(ctx, userKey, sessionID)
}

func (t *lateTeach) Cancel(userKey, sessionID string) bool {
	s, err := t.service()
	return err == nil && s.Cancel(userKey, sessionID)
}

// runPauser pauses the agent run that controls the computer when the user
// takes over.
type runPauser struct{ link *engineLink }

func (p runPauser) RunRunning(runID string) bool {
	e := p.link.get()
	if e == nil {
		return false
	}
	r, ok := e.RunInfo(runID)
	return ok && r.Status() == "running"
}

func (p runPauser) PauseRun(runID string, userID int64, reason string) bool {
	e := p.link.get()
	return e != nil && e.PauseRun(runID, userID, reason)
}

var _ = dyn.Map{}
