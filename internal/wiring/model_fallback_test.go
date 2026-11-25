package wiring

import (
	"context"
	"errors"
	"testing"

	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

// The live run Node completes (model_failure_cache.js, model_router.js): an
// OpenRouter paid model answers 402, so only OpenRouter's paid models cool down;
// OpenAI then answers 429, which cools down OpenAI; the run falls back to an
// OpenRouter :free model.
func TestBillingFailureLeavesAggregatorFreeModels(t *testing.T) {
	ctx := context.Background()
	f := &aimodels.Failures{Providers: providerTraits{}, Cooldowns: aimodels.DefaultCooldowns()}
	catalog := []aimodels.Model{
		{ID: "openrouter::paid/model", ModelID: "paid/model", Provider: "openrouter", Purpose: "general", Available: true, PriceTier: "medium"},
		{ID: "openai::gpt", ModelID: "gpt", Provider: "openai", Purpose: "general", Available: true, PriceTier: "medium"},
		{ID: "openrouter::ling-3.2-flash:free", ModelID: "ling-3.2-flash:free", Provider: "openrouter", Purpose: "general", Available: true, PriceTier: "free"},
		{ID: "openrouter::ernie-5.5-flash-preview:free", ModelID: "ernie-5.5-flash-preview:free", Provider: "openrouter", Purpose: "general", Available: true, PriceTier: "free"},
	}
	billing := &llm.Error{Status: 402, Message: "provider_billing"}
	if d := f.Disposition(billing, "openrouter"); d == nil || d.Scope != "paid" || d.FailureClass != "provider_billing" {
		t.Fatalf("402 on an aggregator: %+v", d)
	}
	if d := f.Disposition(billing, "openai"); d == nil || d.Scope != "provider" {
		t.Fatalf("402 on a direct provider: %+v", d)
	}
	if d := f.Disposition(&llm.Error{Status: 429}, "openrouter"); d == nil || d.Scope != "model" || d.FailureClass != "model_rate_limit" {
		t.Fatalf("429 on an aggregator: %+v", d)
	}
	f.RecordFailure(ctx, 1, "main", "openrouter::paid/model", billing)
	limited := &llm.Error{Status: 429, Message: "rate limited"}
	f.RecordFailure(ctx, 1, "main", "openai::gpt", limited)
	health := f.Snapshot(ctx, 1, "main")
	if health.ProviderIDs["openrouter"] || !health.PaidProviderIDs["openrouter"] || !health.ProviderIDs["openai"] {
		t.Fatalf("health %+v", health)
	}
	next := aimodels.SelectFallbackModel(aimodels.FallbackRequest{Models: catalog, Health: health, CurrentModelID: "openai::gpt",
		ExcludedModelIDs: []string{"openai::gpt", "openrouter::paid/model"}, ExcludedProviderIDs: []string{"openai"}})
	if next == nil || next.Provider != "openrouter" || next.PriceTier != "free" {
		t.Fatalf("fallback %+v", next)
	}
	if errors.Is(billing, context.Canceled) {
		t.Fatal("unreachable")
	}
}

func TestModelRowsKeepPriceTier(t *testing.T) {
	if m := modelFromRow(map[string]any{"id": "openrouter::x:free", "priceTier": "free"}); m.PriceTier != "free" {
		t.Fatalf("price tier dropped: %+v", m)
	}
}
