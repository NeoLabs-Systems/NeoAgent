package wiring

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/NeoLabs-Systems/neoagent/internal/gitproxy"
	"github.com/NeoLabs-Systems/neoagent/internal/mobilesync"
	"github.com/NeoLabs-Systems/neoagent/internal/voice"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neoagent/internal/agent"
	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/handlers"
	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/systemone"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/tools"
	"github.com/NeoLabs-Systems/neoagent/internal/android"
	"github.com/NeoLabs-Systems/neoagent/internal/artifacts"
	"github.com/NeoLabs-Systems/neoagent/internal/behavior"
	"github.com/NeoLabs-Systems/neoagent/internal/commands"
	"github.com/NeoLabs-Systems/neoagent/internal/credentials"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/mcpserver"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/neorouterapi"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/NeoLabs-Systems/neoagent/internal/security"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neoagent/internal/skilllearning"
	"github.com/NeoLabs-Systems/neoagent/internal/skills"
	"github.com/NeoLabs-Systems/neoagent/internal/socialreach"
	"github.com/NeoLabs-Systems/neoagent/internal/socialvideo"
	"github.com/NeoLabs-Systems/neoagent/internal/sockets"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neoagent/internal/timeline"
	"github.com/NeoLabs-Systems/neoagent/internal/webshares"
	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
	"github.com/NeoLabs-Systems/neolabs-go/llm/providers"
	"github.com/NeoLabs-Systems/neolabs-go/llm/transport"
)

// engineLink lets services built before the engine (tasks, sockets,
// messaging) reach it once it exists.
type engineLink struct {
	mu sync.RWMutex
	e  *agent.Engine
}

func (l *engineLink) set(e *agent.Engine) {
	l.mu.Lock()
	l.e = e
	l.mu.Unlock()
}

func (l *engineLink) get() *agent.Engine {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return l.e
}

var errEngineNotReady = errors.New("The agent engine is starting.")

// ── Settings and models ─────────────────────────────────────────────────────

type agentSettings struct{ store *settings.Store }

func (s agentSettings) AISettings(ctx context.Context, userID int64, agentID string) (dyn.Map, error) {
	all, err := s.store.All(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	out := make(dyn.Map, len(all))
	for k, raw := range all {
		var v any
		if json.Unmarshal(raw, &v) == nil {
			out[k] = v
		}
	}
	return out, nil
}

type agentModels struct {
	catalog settingsCatalogAdapter
}

func modelFromRow(row map[string]any) aimodels.Model {
	m := aimodels.Model{}
	m.ID, _ = row["id"].(string)
	m.ModelID, _ = row["modelId"].(string)
	m.Provider, _ = row["provider"].(string)
	m.Name, _ = row["label"].(string)
	m.Purpose, _ = row["purpose"].(string)
	if m.Purpose == "" {
		m.Purpose = "general"
	}
	m.Available, _ = row["available"].(bool)
	m.RuntimeUnavailable, _ = row["runtimeUnavailable"].(bool)
	m.ProviderStatus, _ = row["providerStatus"].(string)
	m.ProviderStatusLabel, _ = row["providerStatusLabel"].(string)
	m.IsByok, _ = row["isByok"].(bool)
	m.ByokLabel, _ = row["byokLabel"].(string)
	m.AdminGranted, _ = row["adminGranted"].(bool)
	// A free model stays routable while its aggregator's paid models cool down.
	m.PriceTier, _ = row["priceTier"].(string)
	if b, ok := row["supportsTools"].(bool); ok {
		m.SupportsTools = &b
	}
	if f, ok := row["createdAt"].(float64); ok {
		m.CreatedAt = &f
	}
	if f, ok := row["inputCostPerM"].(float64); ok {
		m.InputCostPerM = &f
	}
	return m
}

func (m agentModels) Catalog(ctx context.Context, userID int64, agentID string) ([]aimodels.Model, error) {
	rows, _, _ := m.catalog.listModels(ctx, userID, agentID)
	out := make([]aimodels.Model, 0, len(rows))
	for _, row := range rows {
		out = append(out, modelFromRow(row))
	}
	return out, nil
}

func (m agentModels) Provider(ctx context.Context, userID int64, agentID string, model aimodels.Model) (llm.Provider, error) {
	if model.Provider == "neorouter" {
		conn := m.catalog.routerForRole(ctx, userID, agentID, "chat")
		if conn == nil {
			return nil, errors.New("NeoRouter is not connected for this agent.")
		}
		server := m.catalog.nr.ServerConnection()
		trusted := conn.Scope == "server" || (server != nil && server.APIBase == conn.APIBase)
		return providers.New("neorouter", providers.Config{Config: transport.Config{APIKey: conn.APIKey, BaseURL: conn.APIBase, HTTPClient: modelHTTP(trusted)}})
	}
	statuses, err := m.catalog.store.ProviderStatuses(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	for _, st := range statuses {
		if st.ID == model.Provider {
			rt, ok := runtimeProvider(st)
			if !ok {
				return nil, fmt.Errorf("%s is not configured.", model.Provider)
			}
			return rt.provider, nil
		}
	}
	return nil, fmt.Errorf("Unknown model provider %s.", model.Provider)
}

func (m agentModels) IsBYOK(ctx context.Context, userID int64, agentID, provider string) bool {
	statuses, err := m.catalog.store.ProviderStatuses(ctx, userID, agentID)
	if err != nil {
		return false
	}
	for _, st := range statuses {
		if st.ID == provider {
			return st.IsBYOK
		}
	}
	return false
}

// ── Tool catalog ────────────────────────────────────────────────────────────

type agentCatalog struct {
	db           *dbx.DB
	registry     *tools.Registry
	skills       *skills.Runner
	integrations *integrations.Manager
	mcp          *mcpserver.Manager
	systemOne    systemOneEnabled
	policies     *security.Policies
	getenv       func(string) string
}

type systemOneEnabled func(ctx context.Context, userID int64, agentID string) bool

func (c agentCatalog) Registry() *tools.Registry { return c.registry }

func definitionFrom(raw any) (tools.Definition, bool) {
	encoded, err := json.Marshal(raw)
	if err != nil {
		return tools.Definition{}, false
	}
	var d tools.Definition
	if json.Unmarshal(encoded, &d) != nil || strings.TrimSpace(d.Name) == "" {
		return tools.Definition{}, false
	}
	return d, true
}

var agentTools = map[string]bool{"delegate_to_agent": true, "agent_task": true, "create_agent": true}

func (c agentCatalog) Available(ctx context.Context, req agent.CatalogRequest) []tools.Definition {
	uid := req.UserID
	list := c.registry.Available(tools.Options{UserID: &uid, AgentID: req.AgentID, TriggerType: req.TriggerType, TriggerSource: req.TriggerSource})
	list = append(list, integratedDefinitions(c.getenv)...)
	if c.skills != nil && req.Public == nil {
		for _, raw := range c.skills.ToolDefinitions(req.UserID) {
			if d, ok := definitionFrom(raw); ok {
				list = append(list, d)
			}
		}
	}
	if c.integrations != nil {
		var defs []json.RawMessage
		if req.Public != nil {
			defs = c.integrations.ProviderToolDefinitions(req.Public.IntegrationProvider)
		} else {
			defs, _ = c.integrations.ToolDefinitions(ctx, req.UserID, req.AgentID)
		}
		for _, raw := range defs {
			if d, ok := definitionFrom(raw); ok {
				list = append(list, d)
			}
		}
	}
	// browser_act runs on a SystemOne model, so it is offered only while SystemOne is on.
	systemOneOn := c.systemOne != nil && c.systemOne(ctx, req.UserID, req.AgentID)
	visibleAgent := c.visibleAgentTools(ctx, req)
	var out []tools.Definition
	for _, d := range list {
		if d.Name == "browser_act" && !systemOneOn {
			continue
		}
		if agentTools[d.Name] && !visibleAgent[d.Name] {
			continue
		}
		if req.Public != nil && !req.Public.ToolNames[d.Name] {
			continue
		}
		if _, ok := tools.Compact(d, true); !ok {
			continue
		}
		out = append(out, d)
	}
	return out
}

// visibleAgentTools: handing work on needs an agent to hand it to, and
// creating agents is off in task runs and where the policy says never.
func (c agentCatalog) visibleAgentTools(ctx context.Context, req agent.CatalogRequest) map[string]bool {
	visible := map[string]bool{}
	agentID, err := agentscope.Resolver{DB: c.db}.Resolve(ctx, req.UserID, req.AgentID)
	if err != nil {
		return visible
	}
	inTask := req.TriggerSource == "agent_delegation"
	canDelegate := len(agent.DelegationTargets(ctx, c.db, req.UserID, agentID)) > 0
	if canDelegate {
		visible["delegate_to_agent"] = true
	}
	var open int
	_ = c.db.R.QueryRowContext(ctx, `SELECT COUNT(*) FROM agent_delegations WHERE user_id = ? AND status IN ('pending', 'working', 'waiting') AND (parent_agent_id = ? OR target_agent_id = ?)`,
		req.UserID, agentID, agentID).Scan(&open)
	if canDelegate || inTask || open > 0 {
		visible["agent_task"] = true
	}
	if !inTask && c.policies != nil && c.policies.Policy(ctx, req.UserID, "create_agent", nil) != "deny" && security.Permitted(ctx, c.db, req.UserID, "agent_creation") {
		visible["create_agent"] = true
	}
	return visible
}

func (c agentCatalog) External(ctx context.Context, userID int64, agentID string) []tools.Definition {
	if c.mcp == nil {
		return nil
	}
	var out []tools.Definition
	for _, raw := range c.mcp.AllTools(userID, agentID) {
		if d, ok := definitionFrom(raw); ok {
			out = append(out, d)
		}
	}
	return out
}

// ── Messaging ───────────────────────────────────────────────────────────────

type agentMessaging struct {
	mgr *messaging.Manager
	mem *memory.Manager
	db  *dbx.DB
}

func toObject(v any) map[string]any {
	if v == nil {
		return nil
	}
	encoded, err := json.Marshal(v)
	if err != nil {
		return nil
	}
	var m map[string]any
	_ = json.Unmarshal(encoded, &m)
	return m
}

func (m agentMessaging) Send(ctx context.Context, req agent.SendRequest) (agent.SendResult, error) {
	result, err := m.mgr.SendAgentMessage(ctx, messaging.AgentSend{UserID: req.UserID, AgentID: req.AgentID, Platform: req.Platform, To: req.ChatID,
		Content: req.Content, MediaPath: req.MediaPath, RunID: req.RunID, DeliveryKind: req.Kind, Metadata: toObject(req.Metadata)})
	if err != nil {
		var se *messaging.SendError
		if errors.As(err, &se) {
			if se.Ambiguous {
				return agent.SendResult{Ambiguous: true, Error: se.Msg}, nil
			}
			return agent.SendResult{}, &runledger.DeliveryError{Message: se.Msg, Safe: true}
		}
		return agent.SendResult{}, err
	}
	suppressed := result["suppressed"] == true
	if req.PersistConversation && !suppressed && m.mem != nil {
		(toolMessaging{m: m.mgr, mem: m.mem, db: m.db}).persistConversation(ctx, req.UserID, req.AgentID, req.Platform, req.ChatID,
			messaging.NormalizeOutgoingMessage(req.Platform, req.Content, false))
	}
	id := fmt.Sprint(dyn.Get(result, "result", "messageId"))
	if id == "<nil>" {
		id = ""
	}
	return agent.SendResult{Success: result["success"] == true, Suppressed: suppressed, PlatformMessageID: id}, nil
}

func (m agentMessaging) SendTyping(ctx context.Context, userID int64, agentID, platform, chatID string) {
	m.mgr.SendTyping(ctx, userID, agentID, platform, chatID, true)
}

func (m agentMessaging) Normalize(platform, content string) string {
	return messaging.NormalizeOutgoingMessage(platform, content, true)
}

func (m agentMessaging) NormalizeInterim(platform, content string) string {
	return strings.TrimSpace(messaging.NormalizeOutgoingMessage(platform, content, false))
}

func (m agentMessaging) Split(platform, content string) []string {
	return messaging.SplitOutgoingMessage(platform, content)
}

func (m agentMessaging) Guide(platform string) string {
	return messaging.BuildPlatformFormattingGuide(platform, true)
}

// ── Prompt extras, integrations, artifacts ──────────────────────────────────

type agentExtras struct {
	timeline *timeline.Service
	skills   *skills.Runner
}

func (x agentExtras) Timeline(ctx context.Context, userID int64, agentID, query string) string {
	if x.timeline == nil {
		return ""
	}
	text, _ := x.timeline.BuildPromptContext(ctx, userID, timeline.PromptOptions{AgentID: agentID, Query: query, Limit: 6, Sources: []string{"screen", "tasks", "runs"}})
	return text
}

func (x agentExtras) Skills(ctx context.Context, userID int64) string {
	if x.skills == nil {
		return ""
	}
	return x.skills.SkillsForPrompt(skills.PromptOptions{UserID: userID, MaxTotalChars: 9000, MaxDescriptionChars: 180, MaxTriggerChars: 100})
}

type agentIntegrations struct{ mgr *integrations.Manager }

func (i agentIntegrations) ConnectedProviderLabels(ctx context.Context, userID int64, agentID string) string {
	labels, _ := i.mgr.ConnectedProviderLabels(ctx, userID, agentID)
	return labels
}

func (i agentIntegrations) SummarizeConnectedProviders(ctx context.Context, userID int64, agentID string, keys []string) string {
	text, _ := i.mgr.SummarizeConnected(ctx, userID, agentID, keys)
	return text
}

type agentArtifacts struct{ store *artifacts.Store }

func (a agentArtifacts) CreateTextArtifact(ctx context.Context, userID int64, kind, filenameBase, contentType, content string, metadata map[string]any) (string, error) {
	stored, err := a.store.CreateBufferArtifact(ctx, userKey(userID), artifacts.File{Kind: kind, Backend: "local", Extension: "txt", ContentType: contentType,
		FilenameBase: filenameBase, Content: []byte(content), Metadata: metadata})
	return stored.ID, err
}

// ── The engine ──────────────────────────────────────────────────────────────

type engineSources struct {
	db           *dbx.DB
	users        *accounts.Repo
	agents       agentscope.Resolver
	settings     *settings.Store
	catalog      settingsCatalogAdapter
	memory       *memory.Manager
	failures     *aimodels.Failures
	messaging    *messaging.Manager
	integrations *integrations.Manager
	mcp          *mcpserver.Manager
	skills       *skills.Runner
	timeline     *timeline.Service
	artifacts    *artifacts.Store
	tasks        *tasks.Runtime
	systemOne    *systemone.Service
	emitter      agent.Emitter
	registry     *tools.Registry
	commands     *commands.Router
	policies     *security.Policies
	guard        *security.Guard
	behavior     *behavior.Pipeline
	workspace    agent.CommandRunner
	voice        *voice.Manager
	health       agent.CapabilityHealth
	embedder     memory.Embedder
	dataDir      string
}

// tools is the agent's tool catalog.
func (s engineSources) tools() agentCatalog {
	systemOneOn := func(ctx context.Context, userID int64, agentID string) bool {
		var value string
		if raw, err := s.settings.ReadValue(ctx, userID, agentID, "system_one_model"); err == nil {
			_ = json.Unmarshal(raw, &value)
		}
		return value != "" && value != "off"
	}
	return agentCatalog{db: s.db, registry: s.registry, skills: s.skills, integrations: s.integrations, mcp: s.mcp, systemOne: systemOneOn, policies: s.policies, getenv: os.Getenv}
}

func buildEngine(s engineSources, backend *handlers.Backend, learning *skilllearning.Service) *agent.Engine {
	deps := agent.Deps{
		DB: s.db, Emitter: s.emitter, Settings: agentSettings{s.settings}, Models: agentModels{s.catalog},
		Tools:  s.tools(),
		Agents: s.agents, Memory: s.memory, Prompts: &ai.SystemPrompts{Sources: &agent.PromptSources{DB: s.db, Memory: s.memory}}, Failures: s.failures,
		RateLimits: &aimodels.RateLimiter{DB: s.db, Config: aimodels.RateLimitConfigFromEnv(os.Getenv)},
		Extras:     agentExtras{timeline: s.timeline, skills: s.skills},
		SystemOne:  s.systemOne,
		Backend:    backend,
		RunEnded:   backend.ForgetRun,
	}
	if s.guard != nil {
		deps.Gates = s.guard
	}
	if s.behavior != nil {
		deps.Behavior = behaviorDelivery{s.behavior}
	}
	if s.workspace != nil {
		deps.Commands = s.workspace
	}
	if s.voice != nil {
		deps.Voice = voiceDelivery{s.voice}
	}
	if s.health != nil {
		deps.Health = s.health
	}
	deps.Embedder, deps.DataDir = s.embedder, s.dataDir
	if learning != nil {
		deps.SkillLearning = skillLearner{learning}
	}
	if s.messaging != nil {
		deps.Messaging = agentMessaging{mgr: s.messaging, mem: s.memory, db: s.db}
	}
	if s.integrations != nil {
		deps.Integrations = agentIntegrations{s.integrations}
	}
	if s.artifacts != nil {
		deps.Artifacts = agentArtifacts{s.artifacts}
	}
	if s.tasks != nil {
		deps.Tasks = taskResumer{s.tasks}
	}
	e := agent.New(deps)
	e.IsAdmin = func(ctx context.Context, userID int64) bool { return s.users != nil && s.users.IsAdmin(ctx, userID) }
	e.StoreWebReply = func(userID int64, agentID, conversationID string, result agent.Result) {
		storeWebReply(s.db, userID, agentID, conversationID, result, "web")
	}
	return e
}

func storeWebReply(db *dbx.DB, userID int64, agentID, conversationID string, result agent.Result, platform string) {
	if result.Status != "completed" || result.Content == "" {
		return
	}
	metadata, _ := json.Marshal(map[string]any{"tokens": result.TotalTokens, "platform": platform})
	var conversation any
	if conversationID != "" {
		conversation = conversationID
	}
	_, _ = db.W.Exec(`INSERT INTO conversation_history (user_id, agent_id, agent_run_id, conversation_id, role, content, metadata) VALUES (?, ?, ?, ?, 'assistant', ?, ?)`,
		userID, agentID, result.RunID, conversation, result.Content, string(metadata))
}

func (s engineSources) api(e *agent.Engine, socket *socketServices) *agent.API {
	return agent.NewAPI(e, agent.APIDeps{
		Commands: func(ctx context.Context, task string, userID int64, agentID string) (bool, string, any, error) {
			if s.commands == nil {
				return false, "", nil, nil
			}
			result, err := s.commands.Dispatch(ctx, task, commands.Context{UserID: userID, AgentID: agentID, Source: "http"})
			if err != nil {
				return false, "", nil, err
			}
			return result.Handled, result.Content, result.Events, nil
		},
		OwnedConversation: func(ctx context.Context, userID int64, id string) (string, error) {
			return s.memory.AssertOwnedConversation(ctx, userID, id)
		},
		DefaultConversation: func(ctx context.Context, userID int64, agentID string) (string, error) {
			return s.memory.DefaultWebConversationID(ctx, userID, agentID)
		},
		WebContext: func(ctx context.Context, userID int64, agentID string) (agent.ChatContext, int, error) {
			window, err := socket.EnsureSettings(userID, agentID)
			if err != nil {
				return agent.ChatContext{}, 0, err
			}
			chat, err := socket.WebContext(userID, window, agentID)
			summary, _ := chat.Summary.(string)
			return agent.ChatContext{Recent: chat.Recent, Summary: summary}, window, err
		},
	})
}

// taskResult is a run's answer in the form the task runtime reads.
func taskResult(result agent.Result) *jsv.Object {
	return jsv.NewObject().Set("content", result.Content).Set("status", result.Status).Set("runId", result.RunID).
		Set("totalTokens", result.TotalTokens).Set("iterations", result.Iterations)
}

// ── Scheduled tasks ─────────────────────────────────────────────────────────

func (l *engineLink) RunTask(ctx context.Context, req tasks.RunRequest) (tasks.RunResult, error) {
	e := l.get()
	if e == nil {
		return tasks.RunResult{}, errEngineNotReady
	}
	delivery := &agent.Delivery{}
	if req.Delivery != nil && req.Delivery.NotifyTarget != nil {
		delivery.NotifyTarget = &agent.NotifyTarget{Platform: req.Delivery.NotifyTarget.Platform, To: req.Delivery.NotifyTarget.To}
	}
	o := agent.Options{RunID: req.RunID, AgentID: req.AgentID, Title: req.Title, TriggerType: req.TriggerType, TriggerSource: req.TriggerSource,
		ConversationID: req.ConversationID, TaskID: req.TaskID, ScheduledAt: req.ScheduledAt, Model: req.Model, BypassUserRateLimits: true,
		Delivery: delivery, AllowMultipleProactiveMessages: req.AllowMultipleProactiveMessages, StageProactiveMessages: true, SkipGlobalRecall: true,
		SkipConversationHistory: true, PriorMessages: priorMessages(req.PriorMessages), PriorSummary: req.PriorSummary, ResumedFromRunID: req.ResumedFromRunID}
	if req.Resumable != nil {
		o.ResumableTask = &agent.ResumableTask{TaskID: req.Resumable.TaskID, ScheduledAt: req.Resumable.ScheduledAt, TriggerSource: req.Resumable.TriggerSource}
	}
	result, err := e.Run(ctx, req.UserID, req.Prompt, o)
	if req.Delivery != nil {
		delivery.Lock()
		req.Delivery.FinalDelivered, req.Delivery.FinalContent = delivery.FinalDelivered, delivery.FinalContent
		req.Delivery.NoResponse, req.Delivery.LastWordSent, req.Delivery.WrappedUp = delivery.NoResponse, delivery.LastWordSent, delivery.WrappedUp
		req.Delivery.Sent = append([]string(nil), delivery.Sent...)
		if delivery.AwaitingReply != nil {
			req.Delivery.AwaitingReply = map[string]any{"kind": delivery.AwaitingReply.Kind, "content": delivery.AwaitingReply.Content, "createdAt": delivery.AwaitingReply.CreatedAt}
		}
		if delivery.Staged != nil {
			req.Delivery.Staged = &tasks.StagedMessage{Platform: delivery.Staged.Platform, Content: delivery.Staged.Content, MediaPath: delivery.Staged.MediaPath}
		}
		delivery.Unlock()
	}
	if err != nil {
		return tasks.RunResult{RunID: result.RunID}, err
	}
	if result.Status == "failed" {
		return tasks.RunResult{RunID: result.RunID}, errors.New(orDefault(result.Error, "The task run failed."))
	}
	return tasks.RunResult{RunID: result.RunID, Result: taskResult(result)}, nil
}

func orDefault(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

func priorMessages(v any) []llm.Message {
	var out []llm.Message
	for _, item := range dyn.List(toAny(v)) {
		m := dyn.Obj(item)
		if role, _ := m["role"].(string); role != "" && dyn.Truthy(m["content"]) {
			out = append(out, llm.Message{Role: role, Content: m["content"]})
		}
	}
	return out
}

// ── Chat over sockets ───────────────────────────────────────────────────────

func (l *engineLink) findSteerable(userID int64, triggerSource string) (sockets.SteerableRun, bool) {
	e := l.get()
	if e == nil {
		return sockets.SteerableRun{}, false
	}
	r := e.FindSteerableRun(userID, triggerSource, "")
	if r == nil {
		return sockets.SteerableRun{}, false
	}
	return sockets.SteerableRun{RunID: r.ID, AgentID: r.AgentID, ConversationID: r.ConversationID}, true
}

func (l *engineLink) enqueueSteering(runID, task string, o sockets.SteerOptions) bool {
	e := l.get()
	if e == nil {
		return false
	}
	return e.EnqueueSteering(runID, task, map[string]any{"platform": o.Platform, "conversationId": o.ConversationID, "socketId": o.SocketID}) > 0
}

func (l *engineLink) run(ctx context.Context, userID int64, task string, o sockets.RunOptions) (sockets.RunResult, error) {
	e := l.get()
	if e == nil {
		return sockets.RunResult{}, errEngineNotReady
	}
	var prior []llm.Message
	for _, m := range o.PriorMessages {
		if role, _ := m["role"].(string); role != "" && dyn.Truthy(m["content"]) {
			prior = append(prior, llm.Message{Role: role, Content: m["content"]})
		}
	}
	summary, _ := o.PriorSummary.(string)
	result, err := e.Run(ctx, userID, task, agent.Options{RunID: o.RunID, AgentID: o.AgentID, ConversationID: o.ConversationID, TriggerSource: o.TriggerSource,
		PriorMessages: prior, PriorSummary: summary})
	if err != nil {
		return sockets.RunResult{}, err
	}
	raw := map[string]any{"runId": result.RunID, "content": result.Content, "totalTokens": result.TotalTokens, "iterations": result.Iterations, "status": result.Status}
	if result.Error != "" {
		raw["error"] = result.Error
	}
	return sockets.RunResult{RunID: result.RunID, Content: result.Content, TotalTokens: result.TotalTokens, Raw: raw}, nil
}

func (l *engineLink) abort(runID string, userID int64) error {
	e := l.get()
	if e == nil {
		return nil
	}
	if runID == "" {
		e.AbortAll(userID)
		return nil
	}
	e.Abort(runID, userID, "")
	return nil
}

// ── The tool handlers' view of the engine ───────────────────────────────────

type handlerEngine struct {
	link *engineLink
	db   *dbx.DB
}

var _ handlers.Engine = handlerEngine{}

type handlerDelivery struct{ d *agent.Delivery }

func (h handlerDelivery) NotifyTarget() (string, string, bool) {
	h.d.Lock()
	defer h.d.Unlock()
	if h.d.NotifyTarget == nil {
		return "", "", false
	}
	return h.d.NotifyTarget.Platform, h.d.NotifyTarget.To, true
}
func (h handlerDelivery) SentCount() int {
	h.d.Lock()
	defer h.d.Unlock()
	return len(h.d.Sent)
}
func (h handlerDelivery) Staged() bool {
	h.d.Lock()
	defer h.d.Unlock()
	return h.d.Staged != nil
}
func (h handlerDelivery) Stage(m handlers.StagedMessage) {
	h.d.Lock()
	h.d.Staged = &agent.Staged{Platform: m.Platform, To: m.To, Content: m.Content, Purpose: m.Purpose, MediaPath: m.MediaPath, StagedAt: m.StagedAt}
	h.d.Unlock()
}
func (h handlerDelivery) ChooseSilence() {
	h.d.Lock()
	h.d.NoResponse = true
	h.d.Unlock()
}
func (h handlerDelivery) MarkLastWordSent() {
	h.d.Lock()
	h.d.LastWordSent = true
	h.d.Unlock()
}
func (h handlerDelivery) MarkFinalDelivered() {
	h.d.Lock()
	h.d.FinalDelivered = true
	h.d.Unlock()
}
func (h handlerDelivery) MarkSent(content string) { h.d.MarkSent(content) }

func (h handlerEngine) Run(runID string) *handlers.Run {
	e := h.link.get()
	if e == nil {
		return nil
	}
	r, ok := e.RunInfo(runID)
	if !ok {
		return nil
	}
	o := r.Options
	run := &handlers.Run{UserID: r.UserID, AgentID: r.AgentID, RunID: r.ID, TriggerType: r.TriggerType, TriggerSource: r.TriggerSource,
		ConversationID: r.ConversationID, Source: o.Source, ChatID: o.ChatID, DeviceTarget: r.DeviceTarget, WorkspaceRoot: r.WorkspaceRoot,
		AllowMultipleProactiveMessages: o.AllowMultipleProactiveMessages, AllowExternalSideEffects: o.AllowExternalSideEffects,
		StageProactiveMessages: o.StageProactiveMessages, Delivery: handlerDelivery{r.Delivery}, DeliveryScopeID: r.DeliveryScopeID, Persisted: true}
	if o.TaskID != 0 {
		run.TaskID = fmt.Sprint(o.TaskID)
	}
	run.ScheduledAt = o.ScheduledAt
	if trust := r.Trust(); trust != nil {
		run.Tainted = trust.Tainted()
		run.OwnerStatements = trust.OwnerStatements()
	}
	if social := o.Context.Social; social != nil && r.TriggerSource == "messaging" {
		if b, ok := social.Behavior.(*handlers.Behavior); ok {
			run.Behavior = b
		}
		in := &handlers.Inbound{Platform: o.Source, ChatID: o.ChatID, IsGroup: social.IsGroup}
		if social.Message != nil {
			in.Sender = social.Message.Sender
		}
		run.Inbound = in
	}
	if r.Public != nil {
		run.Public = &handlers.PublicScope{Platform: r.Public.Platform, ChatID: r.Public.ChatID, ToolNames: r.Public.ToolNames, ProviderKey: r.Public.IntegrationProvider, AppKey: r.Public.IntegrationApp}
	}
	return run
}

func (h handlerEngine) engine() (*agent.Engine, error) {
	e := h.link.get()
	if e == nil {
		return nil, errEngineNotReady
	}
	return e, nil
}

func (h handlerEngine) SearchTools(ctx context.Context, runID, query string, limit any) (any, error) {
	e, err := h.engine()
	if err != nil {
		return nil, err
	}
	n, _ := dyn.Int(limit)
	return e.SearchTools(runID, query, n, nil)
}

func (h handlerEngine) ActivateTools(ctx context.Context, runID string, names []string) (any, error) {
	e, err := h.engine()
	if err != nil {
		return nil, err
	}
	return e.ActivateTools(runID, names)
}

func (h handlerEngine) ManageBackgroundRun(ctx context.Context, runID string, args dyn.Map) (any, error) {
	e, err := h.engine()
	if err != nil {
		return nil, err
	}
	return e.ManageBackgroundRun(runID, args), nil
}

func (h handlerEngine) UpdateTaskLedger(ctx context.Context, runID string, args dyn.Map) (any, error) {
	e, err := h.engine()
	if err != nil {
		return nil, err
	}
	return e.UpdateTaskLedger(runID, args), nil
}

func number(v any) float64 {
	f, _ := dyn.Float(v)
	return f
}

func (h handlerEngine) SpawnSubagent(ctx context.Context, run *handlers.Run, req handlers.SubagentRequest) (any, error) {
	e, err := h.engine()
	if err != nil {
		return nil, err
	}
	contextText := ""
	if req.Context != nil {
		if s, ok := req.Context.(string); ok {
			contextText = s
		} else {
			contextText = dyn.Stringify(req.Context)
		}
	}
	return e.SpawnSubagent(ctx, run.UserID, run.RunID, req.Task, agent.SubagentOptions{AgentID: run.AgentID, Context: contextText, Model: req.Model, Write: req.Write,
		AllowedTools: req.AllowedTools, SelectedTools: req.SelectedTools, RequiredArtifacts: req.RequiredArtifacts,
		MaxTurns: number(req.MaxTurns), MaxTokens: number(req.MaxTokens), MaxSeconds: number(req.MaxSeconds)})
}

func (h handlerEngine) ActiveToolNames(runID string) []string {
	e := h.link.get()
	if e == nil {
		return nil
	}
	r, ok := e.RunInfo(runID)
	if !ok {
		return nil
	}
	var out []string
	for _, t := range r.ActiveTools() {
		out = append(out, t.Name)
	}
	return out
}

func (h handlerEngine) DelegateTask(ctx context.Context, run *handlers.Run, args dyn.Map) (any, error) {
	e, err := h.engine()
	if err != nil {
		return nil, err
	}
	return e.DelegateTask(ctx, run.UserID, run.AgentID, run.RunID, args), nil
}

func (h handlerEngine) AgentTaskAction(ctx context.Context, run *handlers.Run, args dyn.Map) (any, error) {
	e, err := h.engine()
	if err != nil {
		return nil, err
	}
	return e.AgentTaskAction(ctx, run.UserID, run.AgentID, run.RunID, args), nil
}

func (h handlerEngine) ListSubagents(runID string) (any, error) {
	e, err := h.engine()
	if err != nil {
		return nil, err
	}
	return e.ListSubagents(runID), nil
}

func (h handlerEngine) WaitSubagent(ctx context.Context, runID, handle string, timeoutMS any) (any, error) {
	e, err := h.engine()
	if err != nil {
		return nil, err
	}
	return e.WaitForSubagent(ctx, handle, runID, time.Duration(number(timeoutMS))*time.Millisecond), nil
}

func (h handlerEngine) CancelSubagent(ctx context.Context, runID, handle string) (any, error) {
	e, err := h.engine()
	if err != nil {
		return nil, err
	}
	return e.CancelSubagent(handle, runID), nil
}

func (h handlerEngine) CreatedAgentInRun(runID string) bool {
	e := h.link.get()
	return e != nil && e.CreatedAgentInRun(runID)
}

func (h handlerEngine) AgentCreated(ctx context.Context, run *handlers.Run, agentID string) {
	if e := h.link.get(); e != nil {
		e.AgentCreated(run.RunID, run.UserID, run.AgentID, agentID)
	}
}

func (h handlerEngine) PublishInterimUpdate(ctx context.Context, u handlers.InterimUpdate) (any, error) {
	e, err := h.engine()
	if err != nil {
		return nil, err
	}
	return e.PublishInterim(ctx, agent.InterimRequest{RunID: u.RunID, UserID: u.UserID, AgentID: u.AgentID, TriggerSource: u.TriggerSource,
		ConversationID: u.ConversationID, Platform: u.Platform, ChatID: u.ChatID, Content: u.Content, Kind: u.Kind, ExpectsReply: u.ExpectsReply, DeferFollowUp: u.DeferFollowUp})
}

func (h handlerEngine) MarkRunVisibleReply(runID string) {
	if e := h.link.get(); e != nil {
		e.MarkVisibleReply(runID)
	}
}

func (h handlerEngine) Emit(userID int64, event string, payload any) {
	if e := h.link.get(); e != nil {
		e.Emit(userID, event, toObject(payload))
	}
}

// RollbackWorkspace, RunRepositories and FileDiagnosticsHistory are the run's
// workspace checkpoints.
func (h handlerEngine) RollbackWorkspace(ctx context.Context, runID string) (any, error) {
	e, err := h.engine()
	if err != nil {
		return nil, err
	}
	return e.RollbackWorkspace(ctx, runID), nil
}

func (h handlerEngine) RunRepositories(runID string) []dyn.Map {
	if e := h.link.get(); e != nil {
		return e.RunRepositories(runID)
	}
	return nil
}

func (h handlerEngine) FileDiagnosticsHistory(runID string) map[string]string {
	if e := h.link.get(); e != nil {
		return e.FileDiagnosticsHistory(runID)
	}
	return nil
}

func (h handlerEngine) CommitDelivery(ctx context.Context, runID string, c handlers.DeliveryCommit) (handlers.DeliveryOutcome, error) {
	e, err := h.engine()
	if err != nil {
		return handlers.DeliveryOutcome{}, err
	}
	run, err := e.Ledger().LoadRun(ctx, runID)
	if err != nil || run == nil {
		return handlers.DeliveryOutcome{Reason: "not_found"}, err
	}
	result, err := e.Ledger().CommitDelivery(ctx, runledger.Commit{
		Run: runledger.CommitRun{ID: run.ID, UserID: run.UserID, AgentID: run.AgentID}, ScopeID: c.ScopeID, Channel: c.Channel, Recipient: c.Recipient,
		Purpose: c.Purpose, Slot: runledger.SlotForContent(c.SlotContent), Content: c.Content, Metadata: c.Metadata, DedupeContent: c.DedupeContent,
		AllowEmptyContent: c.AllowEmptyContent,
		Transmit: func(ctx context.Context, _ *runledger.Entry) (runledger.Transmission, error) {
			t := c.Transmit(ctx)
			return runledger.Transmission{OK: t.OK, Skipped: t.SkippedTransmission, Ambiguous: t.Ambiguous, PlatformMessageID: t.PlatformMessageID, Reason: t.Reason, Error: t.Error}, nil
		},
	})
	if err != nil {
		return handlers.DeliveryOutcome{}, err
	}
	return handlers.DeliveryOutcome{OK: result.OK, Duplicate: result.Duplicate, Reason: result.Reason, Error: result.Error}, nil
}

type taskResumer struct{ rt *tasks.Runtime }

func (t taskResumer) ResumeInterruptedTask(ctx context.Context, taskID, userID int64, scheduledAt, triggerSource, runID, resumedFromRunID, note string) error {
	result := t.rt.ResumeInterruptedTask(ctx, taskID, userID, scheduledAt, triggerSource, runID, resumedFromRunID, note)
	if errText := fmt.Sprint(dyn.Get(toAny(result), "error")); errText != "<nil>" && errText != "" {
		return errors.New(errText)
	}
	return nil
}

// ── Building and running the engine ─────────────────────────────────────────

type engineWiring struct {
	d            Deps
	link         *engineLink
	emitter      *deferredEmitter
	agents       agentscope.Resolver
	settings     *settings.Store
	catalog      settingsCatalogAdapter
	memory       *memory.Manager
	failures     *aimodels.Failures
	messaging    *messaging.Manager
	integrations *integrations.Manager
	mcp          *mcpserver.Manager
	skills       *skills.Runner
	timeline     *timeline.Service
	artifacts    *artifacts.Store
	tasks        *tasks.Runtime
	systemOne    *systemone.Service
	socket       *socketServices
	android      *android.Host
	workspaces   *workspace.Manager
	router       *neorouterapi.Service
	socialVideo  *socialvideo.Service
	socialReach  *socialreach.Service
	inbound      *inboundHandler
	behavior     *behavior.Pipeline
	voice        *voice.Manager
	calls        *voice.Coordinator
	voiceDir     voiceDirectory
	gitProxy     *gitproxy.Proxy
	credentials  *credentials.Broker
	embedder     memoryEmbeddingAdapter
}

// roomEmitter adds room events to the deferred socket emitter.
type roomEmitter struct{ d *deferredEmitter }

func (r roomEmitter) EmitToRoom(room, event string, payload any) {
	r.d.mu.RLock()
	s := r.d.srv
	r.d.mu.RUnlock()
	if s != nil {
		s.EmitToRoom(room, event, payload)
	}
}

// wireEngine builds the agent engine, its tool backend, skill learning and
// Teach Mode, and returns the run routes.
func (a *App) wireEngine(ctx context.Context, w engineWiring) *agent.API {
	registry, err := tools.NewRegistry(registryEnvironment{db: w.d.DB})
	if err != nil {
		panic(fmt.Sprintf("tool registry: %v", err))
	}
	policies := &security.Policies{DB: w.d.DB, Catalog: security.NewCatalog(registry)}
	approvals := security.NewGate(w.d.DB, w.emitter, policies, w.d.Log)
	guard := &security.Guard{DB: w.d.DB, Policies: policies, Approvals: approvals, Registry: registry, Log: w.d.Log,
		HostTerminal: registryEnvironment{db: w.d.DB}.HostTerminal,
		WorkspaceBusy: func(runID string) bool {
			e := w.link.get()
			return e != nil && e.HasWritingSubagent(runID)
		}}
	a.policies, a.approvals = policies, approvals
	if w.messaging != nil && w.inbound != nil {
		chat := newChatApprovals(w.messaging, approvals, w.inbound, w.d.Log)
		approvals.SetChatDelivery(chat)
		w.messaging.SetApprovals(chat)
	}
	w.socket.approvals = approvals
	learning := &skilllearning.Service{DB: w.d.DB, Skills: w.skills, Infer: w.link.inferStructured, Emitter: w.emitter, Log: w.d.Log,
		AutoLearning: func(ctx context.Context, userID int64, agentID string) bool {
			raw, err := w.settings.ReadValue(ctx, userID, agentID, "auto_skill_learning")
			if err != nil || len(raw) == 0 || string(raw) == "null" {
				return true
			}
			var on any
			_ = json.Unmarshal(raw, &on)
			return dyn.Truthy(on)
		}}
	a.learning = learning
	transcribe := newTranscribe(w.d.DB, w.agents, w.voiceDir)
	backend := buildToolBackend(toolSources{
		DB: w.d.DB, Engine: handlerEngine{link: w.link, db: w.d.DB}, Tools: registry, Computer: a.computer.Manager, Android: w.android,
		Memory: w.memory, Messaging: w.messaging, Tasks: w.tasks, Skills: w.skills, MCP: w.mcp, Integrations: w.integrations,
		Workspaces: w.workspaces, Artifacts: w.artifacts, Router: w.router, SocialVideo: w.socialVideo, SocialReach: w.socialReach,
		SystemOne: w.systemOne, Version: w.d.Version, Getenv: os.Getenv, Transcribe: transcribe, AnalyzeImage: w.link.analyzeImage,
		Credentials: w.credentials, Settings: w.settings, SettingsModels: assistantModels{w.catalog}, Behavior: behaviorDelivery{w.behavior}, Calls: w.calls,
		GitProxy: w.gitProxy, Health: &mobilesync.Health{DB: w.d.DB},
		Emit:          func(userID int64, event string, payload any) { w.emitter.EmitToUser(userID, event, payload) },
		PublicBaseURL: func() string { return publicBaseURL(w.d) },
		Embed: func(ctx context.Context, text string) ([]float32, error) {
			e, err := w.embedder.Embed(ctx, memory.EmbedRequest{Text: text, InputType: "query"})
			if err != nil || e == nil {
				return nil, err
			}
			return e.Vector, nil
		},
		InferStructured: func(ctx context.Context, userID int64, agentID, system, prompt string, maxTokens int) (dyn.Map, error) {
			return w.link.inferStructured(ctx, userID, agentID, "fast", system, prompt, maxTokens)
		},
	})
	sources := engineSources{db: w.d.DB, users: w.d.Users, agents: w.agents, settings: w.settings, catalog: w.catalog, memory: w.memory,
		failures: w.failures, messaging: w.messaging, integrations: w.integrations, mcp: w.mcp, skills: w.skills, timeline: w.timeline,
		artifacts: w.artifacts, tasks: w.tasks, systemOne: w.systemOne, emitter: w.emitter, registry: registry, policies: policies, guard: guard, behavior: w.behavior, voice: w.voice}
	if a.computer != nil && a.computer.Manager != nil {
		sources.workspace = toolRuntime{m: a.computer.Manager, android: w.android}
	}
	health := capabilityHealth{messaging: w.messaging, mcp: w.mcp}
	if a.computer != nil {
		health.computer = a.computer.Manager
	}
	sources.health = health
	sources.embedder, sources.dataDir = w.embedder, w.d.Cfg.Paths.DataDir
	sources.commands = commands.New(commands.Config{DB: w.d.DB, Agents: w.agents, Messages: fixedMessages{w.settings}, Engine: commandEngine{w.link},
		Queues: commandQueues{w.messaging}, Messaging: commandMessaging{mgr: w.messaging, db: w.d.DB},
		Catalog: commandCatalog{tools: sources.tools(), models: w.catalog, skills: w.skills}, Summaries: webSummaries{db: w.d.DB}})
	a.commands = sources.commands
	e := buildEngine(sources, backend, learning)
	w.link.set(e)
	if a.ingestion != nil {
		a.ingestion.SetExtractor(e.ExtractDocumentFacts)
	}
	a.engine = e
	a.Front = (&webshares.Proxy{Store: &webshares.Store{DB: w.d.DB, Getenv: os.Getenv}, Guests: a.computer.Manager, PublicURL: w.d.Cfg.PublicURL,
		TrustProxy: w.d.Cfg.TrustProxy}).Wrap
	newTeach(a.computer, w.d.Cfg.Paths.DataDir, teachLearner{learning}, teachImages{w.link}, roomEmitter{w.emitter}, w.d.Log)
	return sources.api(e, w.socket)
}

// registryEnvironment answers the questions some built-ins' availability
// depends on.
type registryEnvironment struct{ db *dbx.DB }

func (registryEnvironment) HostTerminal() bool {
	return strings.ToLower(strings.TrimSpace(os.Getenv("TERMINAL_ENV"))) == "host"
}

func (r registryEnvironment) WebSharingEnabled(userID int64) bool {
	var value string
	if r.db.R.QueryRow(`SELECT value FROM user_settings WHERE user_id = ? AND key = 'web_sharing_enabled'`, userID).Scan(&value) != nil {
		return false
	}
	return value == "true" || value == "1"
}

// startEngine closes the runs a previous process left behind, starts Teach
// Mode, and picks interrupted work back up.
func (a *App) startEngine(ctx context.Context) error {
	if a.engine == nil {
		return nil
	}
	if a.computer != nil && a.computer.teach != nil {
		if err := a.computer.teach.Start(ctx); err != nil {
			return err
		}
	}
	a.engine.RecoverOrphanedRuns(ctx)
	a.engine.ResumeInterruptedRuns(ctx)
	a.engine.ResumeAgentTasks(ctx)
	return nil
}

// stopEngine interrupts the active runs so a restart can resume them.
func (a *App) stopEngine() {
	if a.engine != nil {
		if a.engine.Shutdown("Server shutting down while run was in progress.", 10*time.Second) {
			a.log.Warn("Agent runs did not stop in time")
		}
	}
	if a.learning != nil {
		a.learning.Shutdown()
	}
	if a.calls != nil {
		a.calls.Shutdown()
	}
	if a.voice != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		a.voice.Shutdown(ctx)
		cancel()
	}
	if a.behavior != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		a.behavior.Shutdown(ctx)
		cancel()
	}
	if a.approvals != nil {
		a.approvals.Shutdown()
	}
}

// assistantModels are the model lists settings_read offers.
type assistantModels struct{ catalog settingsCatalogAdapter }

func (m assistantModels) ChatModels(ctx context.Context, userID int64, agentID string) ([]map[string]any, error) {
	rows, _, _ := m.catalog.listModels(ctx, userID, agentID)
	return rows, nil
}

func (m assistantModels) SystemOneModels(ctx context.Context, userID int64, agentID string) ([]map[string]any, error) {
	return m.catalog.decisionModels(ctx, userID, agentID), nil
}

// publicBaseURL is how browsers reach this server.
func publicBaseURL(d Deps) string {
	if d.Cfg.PublicURL != "" {
		return strings.TrimRight(d.Cfg.PublicURL, "/")
	}
	return "http://localhost:" + strconv.Itoa(d.Cfg.Port)
}
