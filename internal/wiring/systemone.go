package wiring

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"time"

	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/systemone"
	"github.com/NeoLabs-Systems/neoagent/internal/neorouterapi"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
	"github.com/NeoLabs-Systems/neolabs-go/llm/providers"
	"github.com/NeoLabs-Systems/neolabs-go/llm/transport"
)

type systemOneSource struct {
	store    *settings.Store
	catalog  settingsCatalogAdapter
	router   *neorouterapi.Service
	failures *aimodels.Failures
}

func (s systemOneSource) Selection(ctx context.Context, user int64, agent string) (string, error) {
	values, err := s.store.All(ctx, user, agent)
	if err != nil {
		return "", err
	}
	var value string
	if err = json.Unmarshal(values["system_one_model"], &value); err != nil {
		return "", err
	}
	return value, nil
}
func (s systemOneSource) Models(ctx context.Context, user int64, agent string) ([]systemone.Model, error) {
	rows := s.catalog.decisionModels(ctx, user, agent)
	health := s.failures.Snapshot(ctx, user, agent)
	out := make([]systemone.Model, 0, len(rows))
	for _, row := range rows {
		id, _ := row["id"].(string)
		modelID, _ := row["modelId"].(string)
		provider, _ := row["provider"].(string)
		available, _ := row["available"].(bool)
		if health.IsBlocked(aimodels.Model{ID: id, ModelID: modelID, Provider: provider}) {
			available = false
		}
		out = append(out, systemone.Model{ID: id, ModelID: modelID, Provider: provider, Available: available})
	}
	return out, nil
}
func (s systemOneSource) Provider(ctx context.Context, user int64, agent string, model systemone.Model) (llm.Decider, error) {
	if model.Provider == "neorouter" {
		conn, err := s.router.ForRole(ctx, user, agent, "system_one")
		if err != nil {
			return nil, err
		}
		if conn == nil {
			return nil, errors.New("NeoRouter does not serve SystemOne for this agent.")
		}
		server := s.router.ServerConnection()
		trusted := conn.Scope == "server" || (server != nil && server.APIBase == conn.APIBase)
		p, err := providers.New("neorouter", providers.Config{Config: transport.Config{APIKey: conn.APIKey, BaseURL: conn.APIBase, HTTPClient: modelHTTP(trusted)}})
		if err != nil {
			return nil, err
		}
		return p.(llm.Decider), nil
	}
	statuses, err := s.store.ProviderStatuses(ctx, user, agent)
	if err != nil {
		return nil, err
	}
	for _, status := range statuses {
		if status.ID == model.Provider {
			p, ok := runtimeProvider(status)
			if !ok {
				return nil, errors.New("SystemOne provider is not configured.")
			}
			decider, ok := p.provider.(llm.Decider)
			if !ok {
				return nil, errors.New("Provider does not serve SystemOne models.")
			}
			return decider, nil
		}
	}
	return nil, errors.New("Unknown SystemOne provider.")
}

type systemOneObserver struct {
	db       *dbx.DB
	failures *aimodels.Failures
	log      *slog.Logger
}

func (o systemOneObserver) Used(ctx context.Context, req systemone.Request, model systemone.Model, response map[string]any, elapsed time.Duration) {
	summary := map[string]any{}
	if answers, ok := response["answers"].(map[string]any); ok {
		for key, value := range answers {
			a, ok := value.(map[string]any)
			if !ok {
				continue
			}
			switch a["type"] {
			case "noul":
				summary[key] = a["noul"]
			case "choice":
				summary[key] = map[string]any{"choice": a["choice"], "confidence": a["confidence"]}
			case "score":
				summary[key] = map[string]any{"score": a["score"], "confidence": a["confidence"]}
			}
		}
	}
	usage, _ := response["usage"].(map[string]any)
	if usage == nil {
		usage = map[string]any{}
	}
	modelName, _ := response["model"].(string)
	if modelName == "" {
		modelName = model.ModelID
	}
	var cost *float64
	if n, ok := usage["cost"].(float64); ok {
		cost = &n
	}
	_, err := aimodels.RecordUsage(ctx, o.db, aimodels.UsageRecord{RunID: req.RunID, StepID: req.StepID, UserID: req.UserID, AgentID: req.AgentID, Provider: model.Provider, Model: modelName, Phase: req.Phase, Usage: aimodels.NormalizeUsage(usage), LatencyMs: elapsed.Milliseconds(), EstimatedCostUSD: cost, Metadata: map[string]any{"answers": summary}})
	if err != nil && o.log != nil {
		o.log.Warn("SystemOne usage recording failed", "error", err)
	}
}
func (o systemOneObserver) Failed(ctx context.Context, req systemone.Request, model systemone.Model, err error) {
	if disposition := o.failures.Disposition(err, model.Provider); disposition != nil && disposition.Scope == "model" {
		o.failures.RecordFailure(ctx, req.UserID, req.AgentID, model.ID, err)
	}
}
