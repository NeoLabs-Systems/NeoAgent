package wiring

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/llm"
	"github.com/NeoLabs-Systems/neolabs-go/llm/providers"
	"github.com/NeoLabs-Systems/neolabs-go/llm/transport"
	"net"
	"net/http"
	"net/netip"
	"os"
	"strconv"
	"strings"
	"sync"

	"github.com/NeoLabs-Systems/neoagent/internal/accounts"
	"github.com/NeoLabs-Systems/neoagent/internal/admin"
	"github.com/NeoLabs-Systems/neoagent/internal/agentscope"
	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
	"github.com/NeoLabs-Systems/neoagent/internal/mcpserver"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neoagent/internal/neorouterapi"
	"github.com/NeoLabs-Systems/neoagent/internal/security"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neoagent/internal/sockets"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks"
	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
	"github.com/NeoLabs-Systems/neoagent/internal/timeline"
	"github.com/NeoLabs-Systems/neoagent/internal/triggers"
	"github.com/NeoLabs-Systems/neolabs-go/apperr"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/publicerr"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

type agentScopeAdapter struct {
	r agentscope.Resolver
}

func (a agentScopeAdapter) Resolve(ctx context.Context, userID int64, candidate string) (string, error) {
	return a.r.Resolve(ctx, userID, candidate)
}

func (a agentScopeAdapter) IsMain(ctx context.Context, userID int64, agentID string) (bool, error) {
	return a.r.IsMain(ctx, userID, agentID)
}

type envAdapter struct {
	env    *admin.EnvStore
	getenv func(string) string
}

func (e envAdapter) Get(key string) string            { return e.getenv(key) }
func (e envAdapter) Lookup(key string) (string, bool) { return os.LookupEnv(key) }
func (e envAdapter) Set(key, val string) error {
	if e.env == nil {
		return nil
	}
	return e.env.Persist(key, val)
}

type nrAccountsAdapter struct {
	users  *accounts.Repo
	agents agentscope.Resolver
}

func (a nrAccountsAdapter) IsAdmin(ctx context.Context, userID int64) bool {
	return a.users != nil && a.users.IsAdmin(ctx, userID)
}

func (a nrAccountsAdapter) ResolveAgentID(ctx context.Context, userID int64, raw string) string {
	id, err := a.agents.Resolve(ctx, userID, raw)
	if err != nil || id == "" {
		return "main"
	}
	return id
}

type nrSettingsAdapter struct {
	store *settings.Store
}

func (s nrSettingsAdapter) NeoRouter(ctx context.Context, userID int64, agentID string) (string, string, any, error) {
	if s.store == nil {
		return "", "", nil, nil
	}
	apiKey, baseURL, _, _, err := s.store.ProviderCredential(ctx, userID, agentID, "neorouter")
	if err != nil {
		return "", "", nil, err
	}
	var roles any
	if raw, err := s.store.ReadValue(ctx, userID, agentID, "neorouter_roles"); err == nil && len(raw) > 0 {
		_ = json.Unmarshal(raw, &roles)
	}
	return apiKey, baseURL, roles, nil
}

func (s nrSettingsAdapter) SaveUserNeoRouter(ctx context.Context, userID int64, agentID, baseURL, apiKey string, roles []string, enableSystemOne bool) error {
	if s.store == nil {
		return nil
	}
	if err := s.store.SetProviderConfigByID(ctx, userID, agentID, "neorouter", &baseURL, nil); err != nil {
		return err
	}
	if err := s.store.SetProviderSecret(ctx, userID, agentID, "neorouter", apiKey); err != nil {
		return err
	}
	rawRoles, _ := json.Marshal(roles)
	patch := settings.Patch{"neorouter_roles": rawRoles}
	if enableSystemOne {
		patch["system_one_model"] = json.RawMessage(`"auto"`)
	}
	return s.store.Update(ctx, userID, agentID, patch, "neorouter")
}

func (s nrSettingsAdapter) ClearUserNeoRouter(ctx context.Context, userID int64, agentID string) error {
	if s.store == nil {
		return nil
	}
	return s.store.SetProviderSecret(ctx, userID, agentID, "neorouter", "")
}

func (s nrSettingsAdapter) UpdateUserRoles(ctx context.Context, userID int64, agentID string, roles []string) error {
	if s.store == nil {
		return nil
	}
	rawRoles, _ := json.Marshal(roles)
	return s.store.Update(ctx, userID, agentID, settings.Patch{"neorouter_roles": rawRoles}, "neorouter")
}

func (s nrSettingsAdapter) GetVoiceLiveProvider(ctx context.Context, userID int64, agentID string) (string, error) {
	if s.store == nil {
		return "", nil
	}
	raw, err := s.store.ReadValue(ctx, userID, agentID, "voice_live_provider")
	if err != nil {
		return "", err
	}
	var v string
	_ = json.Unmarshal(raw, &v)
	return v, nil
}

func (s nrSettingsAdapter) SetVoiceLiveProvider(ctx context.Context, userID int64, agentID, provider string) error {
	if s.store == nil {
		return nil
	}
	rawProv, _ := json.Marshal(provider)
	return s.store.Update(ctx, userID, agentID, settings.Patch{"voice_live_provider": rawProv, "voice_live_model": json.RawMessage(`""`)}, "neorouter")
}

func (s nrSettingsAdapter) IsLiveProviderUsable(context.Context, string, int64, string, string) (bool, error) {
	return false, nil
}

type settingsCatalogAdapter struct {
	store      *settings.Store
	nr         *neorouterapi.Service
	users      *accounts.Repo
	serverOnly bool
	cache      *catalogCache
	// failures is the model health memory; nil leaves every model unblocked.
	failures *aimodels.Failures
}

func (c settingsCatalogAdapter) BYOKTest(ctx context.Context, userID int64, agentID, providerID string, body map[string]any) (any, error) {
	def, ok := llm.ProviderDefinitionFor(providerID)
	if !ok || def.Authentication == "oauth" || providerID == "minimax" || (!def.SupportsAPIKey && !def.SupportsBaseURL) {
		return nil, fmt.Errorf("Unknown provider.")
	}
	apiKey, _ := body["apiKey"].(string)
	apiKey = strings.TrimSpace(apiKey)
	baseURL, _ := body["baseUrl"].(string)
	baseURL = strings.TrimSpace(baseURL)
	if baseURL != "" && apiKey == "" && def.SupportsAPIKey {
		return nil, fmt.Errorf("Testing a custom base URL requires the API key for that endpoint.")
	}
	if apiKey == "" && baseURL == "" {
		var err error
		apiKey, baseURL, _, _, err = c.store.ProviderCredential(ctx, userID, agentID, providerID)
		if err != nil {
			return nil, err
		}
		if apiKey == "" && def.EnvKey != "" {
			apiKey = os.Getenv(def.EnvKey)
		}
		if baseURL == "" && def.BaseURLEnvKey != "" {
			baseURL = os.Getenv(def.BaseURLEnvKey)
		}
	}
	if def.SupportsAPIKey && apiKey == "" {
		return nil, fmt.Errorf("No API key to test.")
	}
	if (def.RequiresBaseURL || !def.SupportsAPIKey) && baseURL == "" {
		return nil, fmt.Errorf("A base URL is required.")
	}
	if baseURL != "" {
		u, err := ssrf.CheckURL(baseURL)
		if err != nil {
			return nil, fmt.Errorf("Base URL must be a valid http(s) URL.")
		}
		var addresses []netip.Addr
		if ip, err := netip.ParseAddr(u.Hostname()); err == nil {
			addresses = []netip.Addr{ip}
		} else {
			addresses, err = net.DefaultResolver.LookupNetIP(ctx, "ip", u.Hostname())
			if err != nil || len(addresses) == 0 {
				return nil, fmt.Errorf("Unable to resolve base URL host.")
			}
		}
		for _, ip := range addresses {
			if err := ssrf.CheckAddr(ip); err != nil {
				return nil, fmt.Errorf("Base URL must point to a public address.")
			}
		}
	}
	provider, err := providers.New(providerID, providers.Config{Config: transport.Config{APIKey: apiKey, BaseURL: baseURL}})
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	// The Ollama catalog deliberately hides connection errors during discovery;
	// a connection test must distinguish those errors from an empty catalog.
	if providerID == "ollama" {
		res, err := transport.FetchText(ctx, transport.Config{}.Client(), transport.FetchOptions{URL: strings.TrimRight(baseURL, "/") + "/api/tags", MaxBytes: 2 << 20, Service: "Ollama model catalog", Provider: "ollama", Timeout: 5 * time.Second})
		if err != nil {
			return map[string]any{"success": true, "ok": false, "error": publicerr.Sanitize(err.Error(), "", "")}, nil
		}
		var payload struct {
			Models []json.RawMessage `json:"models"`
		}
		if !res.OK() || json.Unmarshal([]byte(res.Text), &payload) != nil {
			return map[string]any{"success": true, "ok": false, "error": "Ollama returned an invalid model catalog."}, nil
		}
		message := "Connected, but no models were returned."
		if len(payload.Models) > 0 {
			message = fmt.Sprintf("Connected — found %d model(s).", len(payload.Models))
		}
		return map[string]any{"success": true, "ok": true, "message": message}, nil
	}
	models, err := provider.Models(ctx)
	if err == nil && len(models) == 0 {
		if decider, ok := provider.(llm.Decider); ok {
			models, err = decider.DecisionModels(ctx)
		}
	}
	if err != nil {
		return map[string]any{"success": true, "ok": false, "error": publicerr.Sanitize(err.Error(), apiKey, "")}, nil
	}
	message := "Connected, but no models were returned."
	if len(models) > 0 {
		message = fmt.Sprintf("Connected — found %d model(s).", len(models))
	}
	return map[string]any{"success": true, "ok": true, "message": message}, nil
}

type taskIntegrationsAdapter struct {
	mgr *integrations.Manager
}

func (a taskIntegrationsAdapter) ExecuteTool(ctx context.Context, userID int64, agentID, name string, args *jsv.Object) (any, error) {
	if a.mgr == nil {
		return nil, nil
	}
	var m map[string]any
	if args != nil {
		raw, _ := json.Marshal(args)
		_ = json.Unmarshal(raw, &m)
	}
	return a.mgr.ExecuteTool(ctx, userID, name, m, agentID, integrations.ExecOptions{})
}

type taskMessagingAdapter struct {
	mgr *messaging.Manager
	db  *dbx.DB
}

func (a taskMessagingAdapter) IsRefusedSharedRecipient(int64, string, tasks.Target) bool {
	return false
}
func (a taskMessagingAdapter) ReachableSharedTarget(_ int64, _ string, t tasks.Target) tasks.Target {
	return t
}
func (a taskMessagingAdapter) IsPublicPlatform(p string) bool {
	return a.mgr != nil && a.mgr.IsPublicPlatform(p)
}
func (a taskMessagingAdapter) PlatformConnected(uid int64, aid, p string) bool {
	return a.mgr != nil && a.mgr.PlatformConnected(uid, aid, p)
}
func (a taskMessagingAdapter) ChatContext(context.Context, int64, string, tasks.Target) (tasks.ChatContext, error) {
	return tasks.ChatContext{}, nil
}
func (a taskMessagingAdapter) FormatOutgoing(platform, content string) string {
	return messaging.NormalizeOutgoingMessage(platform, content, false)
}
func (a taskMessagingAdapter) Send(ctx context.Context, req tasks.SendRequest) (any, error) {
	if a.mgr == nil {
		return nil, nil
	}
	return a.mgr.SendMessage(ctx, req.UserID, req.AgentID, req.Target.Platform, req.Target.To, req.Message, req.MediaPath)
}
func (a taskMessagingAdapter) AccessTargets(ctx context.Context, userID int64, agentID, platform string) ([]tasks.AccessTarget, error) {
	return []tasks.AccessTarget{}, nil
}

type mobileSyncEventsAdapter struct {
	rt *tasks.Runtime
}

func (a mobileSyncEventsAdapter) PublishEvent(name string, event map[string]any) {
	if a.rt != nil {
		a.rt.HandleEvent("mobilesync", name, event)
	}
}

type triggersTasksAdapter struct {
	rt *tasks.Runtime
}

func (a triggersTasksAdapter) GeofenceTasks(ctx context.Context, userID int64) ([]triggers.GeofenceTask, error) {
	rows, err := a.rt.GeofenceTasks(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]triggers.GeofenceTask, 0, len(rows))
	for _, r := range rows {
		out = append(out, triggers.GeofenceTask{
			ID:            r.ID,
			TriggerConfig: r.TriggerConfig,
		})
	}
	return out, nil
}

func (a triggersTasksAdapter) PublishEvent(name string, event map[string]any) {
	if a.rt != nil {
		a.rt.HandleEvent("mobile", name, event)
	}
}

// socketHubEmitter adapts *sockets.Server (or a deferred pointer) as an Emitter.
type deferredEmitter struct {
	mu  sync.RWMutex
	srv *sockets.Server
}

func (d *deferredEmitter) Set(s *sockets.Server) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.srv = s
}

func (d *deferredEmitter) EmitToUser(userID int64, event string, payload any) {
	d.mu.RLock()
	s := d.srv
	d.mu.RUnlock()
	if s != nil {
		s.EmitToUser(userID, event, payload)
	}
}

// socketServices implements sockets.Services over the domain packages.
type socketServices struct {
	link         *engineLink
	approvals    *security.Gate
	db           *dbx.DB
	users        *accounts.Repo
	agents       agentscope.Resolver
	mem          *memory.Manager
	msg          *messaging.Manager
	mcp          *mcpserver.Manager
	integrations *integrations.Manager
	settings     *settings.Store
}

func (s *socketServices) ErrorMessageForUser(userID int64, err error) string {
	if err == nil {
		return ""
	}
	if s.users != nil && s.users.IsAdmin(context.Background(), userID) {
		return err.Error()
	}
	failure := publicerr.Failure{Message: err.Error()}
	if e, ok := apperr.As(err); ok {
		failure.Status = e.Status
		failure.Code = e.Code
	}
	return publicerr.NonAdminMessage(failure, "", "")
}

func (s *socketServices) RunRecordsForUser(userID int64, records sockets.RunRecords) sockets.RunRecords {
	if s.users != nil && s.users.IsAdmin(context.Background(), userID) {
		return records
	}
	redact := func(row map[string]any) map[string]any {
		if row == nil || row["error"] == nil || row["error"] == "" {
			return row
		}
		copy := make(map[string]any, len(row))
		for k, v := range row {
			copy[k] = v
		}
		copy["error"] = publicerr.Generic
		if _, ok := copy["result"]; ok {
			copy["result"] = nil
		}
		return copy
	}
	records.Run = redact(records.Run)
	if records.Runs != nil {
		out := make([]map[string]any, len(records.Runs))
		for i, row := range records.Runs {
			out[i] = redact(row)
		}
		records.Runs = out
	}
	if records.Steps != nil {
		out := make([]map[string]any, len(records.Steps))
		for i, row := range records.Steps {
			out[i] = redact(row)
		}
		records.Steps = out
	}
	if records.Events != nil {
		out := make([]any, len(records.Events))
		for i, event := range records.Events {
			out[i] = event
			if m, ok := event.(map[string]any); ok {
				if payload, ok := m["payload"].(map[string]any); ok && payload["error"] != nil && payload["error"] != "" {
					copy := make(map[string]any, len(m))
					for k, v := range m {
						copy[k] = v
					}
					copy["payload"] = redact(payload)
					out[i] = copy
				}
			}
		}
		records.Events = out
	}
	return records
}

func (s *socketServices) Resolve(ctx context.Context, userID int64, candidate string) (string, error) {
	return s.agents.Resolve(ctx, userID, candidate)
}

func (s *socketServices) FindSteerableRun(userID int64, triggerSource string) (sockets.SteerableRun, bool) {
	return s.link.findSteerable(userID, triggerSource)
}
func (s *socketServices) EnqueueSteering(runID, task string, o sockets.SteerOptions) bool {
	return s.link.enqueueSteering(runID, task, o)
}
func (s *socketServices) Run(ctx context.Context, userID int64, task string, opts sockets.RunOptions) (sockets.RunResult, error) {
	return s.link.run(ctx, userID, task, opts)
}
func (s *socketServices) Abort(runID string, userID int64) error { return s.link.abort(runID, userID) }

// OfferPendingApprovals re-sends waiting approvals to a client that connected.
func (s *socketServices) OfferPendingApprovals(peer sockets.Peer, userID int64) {
	if s.approvals != nil {
		s.approvals.OfferPending(peer, userID)
	}
}

func (s *socketServices) List(ctx context.Context, runID string) ([]any, error) {
	events := []any{}
	if runID == "" {
		return events, nil
	}
	rows, err := s.db.R.QueryContext(ctx, `SELECT id,run_id,user_id,agent_id,event_type,request_id,step_id,sequence_index,payload_json,created_at FROM agent_run_events WHERE run_id=? AND sequence_index>0 ORDER BY sequence_index ASC,id ASC LIMIT 5000`, runID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id, userID int64
		var run, event string
		var agent, request, step, payload, created sql.NullString
		var sequence sql.NullInt64
		if err := rows.Scan(&id, &run, &userID, &agent, &event, &request, &step, &sequence, &payload, &created); err != nil {
			return nil, err
		}
		var data map[string]any
		if json.Unmarshal([]byte(payload.String), &data) != nil || data == nil {
			data = map[string]any{}
		}
		nullable := func(v sql.NullString) any {
			if !v.Valid || v.String == "" {
				return nil
			}
			return v.String
		}
		events = append(events, map[string]any{"id": id, "runId": run, "userId": userID, "agentId": nullable(agent), "eventType": event, "requestId": nullable(request), "stepId": nullable(step), "sequenceIndex": sequence.Int64, "payload": data, "createdAt": nullable(created)})
	}
	return events, rows.Err()
}

func (s *socketServices) AssertOwned(userID int64, conversationID string) error {
	_, err := s.mem.AssertOwnedConversation(context.Background(), userID, conversationID)
	return err
}

func (s *socketServices) DefaultWebID(userID int64, agentID string) (string, error) {
	return s.mem.DefaultWebConversationID(context.Background(), userID, agentID)
}

func (s *socketServices) EnsureSettings(userID int64, agentID string) (int, error) {
	values, err := s.settings.All(context.Background(), userID, agentID)
	if err != nil {
		return 0, err
	}
	window := 20
	if raw := values["chat_history_window"]; len(raw) > 0 {
		_ = json.Unmarshal(raw, &window)
	}
	return window, nil
}
func (s *socketServices) WebContext(userID int64, window int, agentID string) (sockets.ChatContext, error) {
	ctx := context.Background()
	rows, err := s.db.R.QueryContext(ctx, `SELECT role, content FROM conversation_history WHERE user_id = ? AND agent_id = ? ORDER BY created_at DESC LIMIT ?`, userID, agentID, window)
	if err != nil {
		return sockets.ChatContext{}, err
	}
	defer rows.Close()
	recent := []map[string]any{}
	for rows.Next() {
		var role string
		var content *string
		if err := rows.Scan(&role, &content); err != nil {
			return sockets.ChatContext{}, err
		}
		text := ""
		if content != nil {
			text = *content
		}
		recent = append(recent, map[string]any{"role": role, "content": text})
	}
	if err := rows.Err(); err != nil {
		return sockets.ChatContext{}, err
	}
	for i, j := 0, len(recent)-1; i < j; i, j = i+1, j-1 {
		recent[i], recent[j] = recent[j], recent[i]
	}
	var summary string
	var raw string
	err = s.db.R.QueryRowContext(ctx, `SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = 'web_chat_summary'`, userID, agentID).Scan(&raw)
	if err == nil {
		if json.Unmarshal([]byte(raw), &summary) != nil {
			summary = raw
		}
		summary = strings.TrimSpace(summary)
		if len([]rune(summary)) > 6000 {
			summary = string([]rune(summary)[:6000]) + "\n...[summary trimmed]"
		}
	} else if err != sql.ErrNoRows {
		return sockets.ChatContext{}, err
	}
	return sockets.ChatContext{Recent: recent, Summary: summary}, nil
}
func (s *socketServices) StoreWebReply(userID int64, agentID, conversationID string, result sockets.RunResult) error {
	raw, ok := result.Raw.(map[string]any)
	if !ok || raw["status"] != "completed" || result.Content == "" {
		return nil
	}
	metadata, err := json.Marshal(map[string]any{"tokens": result.TotalTokens, "platform": "web"})
	if err != nil {
		return err
	}
	_, err = s.db.W.ExecContext(context.Background(), `INSERT INTO conversation_history (user_id, agent_id, agent_run_id, conversation_id, role, content, metadata) VALUES (?, ?, ?, ?, 'assistant', ?, ?)`, userID, agentID, result.RunID, conversationID, result.Content, string(metadata))
	return err
}

func (s *socketServices) Connect(ctx context.Context, userID int64, platform string, cfg map[string]any, agentID string) (any, error) {
	return s.msg.ConnectPlatform(ctx, userID, agentID, platform, cfg, true)
}
func (s *socketServices) Disconnect(ctx context.Context, userID int64, platform, agentID string) (any, error) {
	return s.msg.DisconnectPlatform(ctx, userID, agentID, platform)
}
func (s *socketServices) Send(ctx context.Context, userID int64, platform, to, content, agentID, mediaPath string) (any, error) {
	return s.msg.SendMessage(ctx, userID, agentID, platform, to, content, mediaPath)
}
func (s *socketServices) Statuses(userID int64, agentID string) (any, error) {
	return s.msg.AllStatuses(context.Background(), userID, agentID), nil
}

func (s *socketServices) Status(_ context.Context, userID int64, agentID string) (any, error) {
	return s.mcp.Status(userID, agentID), nil
}
func (s *socketServices) ListTools(_ context.Context, serverID string, userID int64) (any, error) {
	id, err := strconv.ParseInt(serverID, 10, 64)
	if err != nil {
		return []map[string]any{}, nil
	}
	return s.mcp.ListTools(id, userID)
}
func (s *socketServices) AllTools(userID int64, agentID string) (any, error) {
	return s.mcp.AllTools(userID, agentID), nil
}

func (s *socketServices) ListProviders(userID int64, agentID string) (any, error) {
	return s.integrations.ListProviders(context.Background(), userID, agentID)
}

func (s *socketServices) Read(userID int64) (any, error) { return s.mem.ReadMemory(userID) }
func (s *socketServices) AssistantBehaviorNotes(userID int64, agentID string) (any, error) {
	return s.mem.AssistantBehaviorNotes(context.Background(), userID, agentID)
}
func (s *socketServices) DailyLogs(count int, userID int64) (any, error) {
	return s.mem.ListDailyLogs(count, userID)
}
func (s *socketServices) Search(ctx context.Context, query string, userID int64, agentID string) (any, error) {
	return s.mem.SearchConversations(ctx, userID, query, memory.SearchConversationsOptions{AgentID: agentID})
}

var _ http.Handler = nil
var _ = strings.TrimSpace
var _ = timeline.TaskLifecycle{}

func (c settingsCatalogAdapter) adminModels(ctx context.Context, env envAdapter) (any, error) {
	c.serverOnly = true
	chat, _, _ := c.listModels(ctx, 0, "")
	decisions := c.decisionModels(ctx, 0, "")
	visibility := aimodels.Visibility{Env: env}
	ids := func(ms []map[string]any) []string {
		out := make([]string, 0, len(ms))
		for _, m := range ms {
			if id, ok := m["id"].(string); ok {
				out = append(out, id)
			}
		}
		return out
	}
	if _, err := visibility.Reconcile(ids(chat), aimodels.CatalogLLM); err != nil {
		return nil, err
	}
	disabled, err := visibility.Reconcile(ids(decisions), aimodels.CatalogDecisions)
	if err != nil {
		return nil, err
	}
	if disabled == nil {
		disabled = []string{}
	}
	return jsonobj.New("models", orderedRows(chat, chatModelKeys), "systemOneModels", orderedRows(decisions, decisionModelKeys),
		"disabledModels", disabled, "autoEnableNewModels", visibility.AutoEnableNew()), nil
}
