package agent

import (
	"context"
	"fmt"
	"slices"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// selectedModel is the model a call goes to.
type selectedModel struct {
	Provider     llm.Provider
	ProviderName string
	Model        string
	SelectionID  string
}

func (s selectedModel) handle() ai.ModelHandle {
	return ai.ModelHandle{Provider: s.Provider, ProviderName: s.ProviderName, Model: s.Model, SelectionID: s.SelectionID}
}

func routingSettings(settings dyn.Map) aimodels.Settings {
	var enabled []string
	for _, v := range dyn.List(settings["enabled_models"]) {
		if s := strings.TrimSpace(dyn.Str(v)); s != "" {
			enabled = append(enabled, s)
		}
	}
	return aimodels.Settings{
		EnabledModels:        enabled,
		DefaultChatModel:     dyn.Str(settings["default_chat_model"]),
		DefaultSubagentModel: dyn.Str(settings["default_subagent_model"]),
		CostMode:             dyn.Str(settings["cost_mode"]),
	}
}

func (e *Engine) aiSettings(ctx context.Context, userID int64, agentID string) dyn.Map {
	settings, err := e.deps.Settings.AISettings(ctx, userID, agentID)
	if err != nil || settings == nil {
		if err != nil {
			e.log.Warn("AI settings unavailable", "user", userID, "error", err)
		}
		return dyn.Map{"chat_history_window": float64(20), "default_chat_model": "auto", "default_subagent_model": "auto", "cost_mode": "balanced_auto"}
	}
	return settings
}

// selectModel picks the model a call starts on: the requested one when it is
// usable, else NeoRouter's profile, else the best of the automatic pool.
func (e *Engine) selectModel(ctx context.Context, userID int64, agentID string, isSubagent bool, override string, hint aimodels.Hint, onFallback func(string)) (selectedModel, error) {
	settings := e.aiSettings(ctx, userID, agentID)
	catalog, err := e.deps.Models.Catalog(ctx, userID, agentID)
	if err != nil {
		return selectedModel{}, err
	}
	route, err := aimodels.SelectInitialModel(aimodels.InitialRequest{
		Models: catalog, Settings: routingSettings(settings), Health: e.deps.Failures.Snapshot(ctx, userID, agentID),
		IsSubagent: isSubagent, ModelOverride: override, Hint: hint,
	})
	if err != nil {
		return selectedModel{}, err
	}
	requested := override
	if requested == "" {
		requested = dyn.Str(settings["default_chat_model"])
		if isSubagent && dyn.Str(settings["default_subagent_model"]) != "auto" {
			requested = dyn.Str(settings["default_subagent_model"])
		}
	}
	if requested == "" {
		requested = "auto"
	}
	if route.Reason != "" {
		e.log.Warn("Requested model is not routable; falling back", "user", userID, "agent", agentID, "requested", requested, "selected", route.Model.ID, "reason", route.Reason)
		if onFallback != nil {
			onFallback(fmt.Sprintf("Requested model is unavailable; using %s.", route.Model.ID))
		}
	} else {
		e.log.Info("Model selected", "user", userID, "agent", agentID, "requested", requested, "selected", route.Model.ID)
	}
	provider, err := e.deps.Models.Provider(ctx, userID, agentID, route.Model)
	if err != nil {
		return selectedModel{}, err
	}
	return selectedModel{Provider: provider, ProviderName: route.Model.Provider, Model: aimodels.RawModelID(route.Model), SelectionID: route.Model.ID}, nil
}

// fallbackModelID is the model to move to after a failure, or "".
func (e *Engine) fallbackModelID(ctx context.Context, userID int64, agentID, currentID string, failure error, failed map[string]bool) (string, error) {
	settings := e.aiSettings(ctx, userID, agentID)
	catalog, err := e.deps.Models.Catalog(ctx, userID, agentID)
	if err != nil {
		return "", err
	}
	current := aimodels.ResolveSelection(catalog, currentID, "")
	provider := ""
	if current != nil {
		provider = current.Provider
	}
	var excludedProviders []string
	if d := e.deps.Failures.Disposition(failure, provider); d != nil && d.Scope == "provider" && provider != "" {
		excludedProviders = []string{provider}
	}
	excluded := []string{}
	for id := range failed {
		if id = strings.TrimSpace(id); id != "" {
			excluded = append(excluded, id)
		}
	}
	if currentID != "" && !slices.Contains(excluded, currentID) {
		excluded = append(excluded, currentID)
	}
	slices.Sort(excluded)
	next := aimodels.SelectFallbackModel(aimodels.FallbackRequest{
		Models: catalog, Settings: routingSettings(settings), Health: e.deps.Failures.Snapshot(ctx, userID, agentID),
		CurrentModelID: currentID, ExcludedModelIDs: excluded, ExcludedProviderIDs: excludedProviders,
	})
	if next == nil {
		e.log.Warn("Model failed; no fallback model left", "user", userID, "model", currentID, "error", failure)
		return "", nil
	}
	e.log.Warn("Model failed; switching", "user", userID, "model", currentID, "to", next.ID, "error", failure)
	return next.ID, nil
}

func (e *Engine) reasoningEffort(o Options) string {
	if o.LatencyProfile == "voice" {
		return "low"
	}
	if o.ReasoningEffort != "" {
		return o.ReasoningEffort
	}
	if v := e.deps.Getenv("REASONING_EFFORT"); v != "" {
		return v
	}
	return "low"
}

// runModels decides what a provider failure means for a run's model.
type runModels struct {
	e *Engine
	r *Run
}

func (m *runModels) Failed(ctx context.Context, selectionID string, err error) {
	m.e.deps.Failures.RecordFailure(context.Background(), m.r.UserID, m.r.AgentID, selectionID, err)
}

func (m *runModels) Succeeded(ctx context.Context, selectionID string) {
	m.e.deps.Failures.RecordSuccess(context.Background(), m.r.UserID, m.r.AgentID, selectionID)
}

func (m *runModels) ShouldSwitch(err error) bool { return m.e.deps.Failures.ShouldSwitchModel(err) }

func (m *runModels) Switch(ctx context.Context, s *ai.Session, cause error) (bool, error) {
	next, err := m.e.fallbackModelID(ctx, m.r.UserID, m.r.AgentID, s.Model.SelectionID, cause, s.FailedModelIDs)
	if err != nil || next == "" {
		return false, nil
	}
	selected, err := m.e.selectModel(ctx, m.r.UserID, m.r.AgentID, m.r.TriggerType == "subagent", next, aimodels.Hint{}, m.e.statusNotifier(m.r))
	if err != nil {
		return false, nil
	}
	m.e.adoptModel(m.r, s, selected)
	return true, nil
}

func (e *Engine) adoptModel(r *Run, s *ai.Session, selected selectedModel) {
	handle := selected.handle()
	handle.Provider = e.meter(r, selected.Provider, selected.ProviderName)
	s.Model = handle
	s.Env.Sanitize.Model = selected.Model
	r.setModel(handle)
	e.execDB(context.Background(), `UPDATE agent_runs SET model = ?, updated_at = datetime('now') WHERE id = ?`, selected.SelectionID, r.ID)
}

func (e *Engine) statusNotifier(r *Run) func(string) {
	return func(message string) {
		e.Emit(r.UserID, "run:interim", map[string]any{"runId": r.ID, "message": message, "phase": "model_fallback"})
	}
}

// applyTaskModel moves the run onto the model the user pinned for the kind of
// work a tool turn shows, and back to the run's own model when that work has no
// pin. Runs NeoRouter routes move between its profiles instead.
func (e *Engine) applyTaskModel(ctx context.Context, r *Run, s *ai.Session, calls []ai.Call, base string, explicit bool, unroutable map[string]bool) {
	if explicit {
		return
	}
	toolNames := make([]string, len(calls))
	for i, c := range calls {
		toolNames[i] = c.Name
	}
	kind := aimodels.InferTaskKind(toolNames)
	if kind == "" {
		return
	}
	raw := dyn.Obj(e.aiSettings(ctx, r.UserID, r.AgentID)["task_models"])
	wanted := aimodels.NormalizeTaskModels(raw)[kind]
	if wanted == "" && strings.HasPrefix(base, "neorouter::auto:") {
		wanted = aimodels.NeoRouterTaskSelection(kind)
	}
	if wanted == "" {
		wanted = base
	}
	if wanted == "" || wanted == s.Model.SelectionID || s.FailedModelIDs[wanted] || unroutable[wanted] {
		return
	}
	selected, err := e.selectModel(ctx, r.UserID, r.AgentID, r.TriggerType == "subagent", wanted, aimodels.Hint{}, nil)
	if err != nil {
		e.log.Warn("Task model switch failed", "to", wanted, "error", err)
		return
	}
	// The router falls back when the pin is not routable; stay rather than adopt that.
	if selected.SelectionID != wanted {
		unroutable[wanted] = true
		return
	}
	dropReasoning(s.Messages)
	e.adoptModel(r, s, selected)
}

func dropReasoning(messages []llm.Message) {
	for i := range messages {
		messages[i].ReasoningState = nil
		messages[i].ProviderContentBlocks = nil
	}
}
