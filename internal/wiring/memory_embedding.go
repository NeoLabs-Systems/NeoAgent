package wiring

import (
	"context"
	"encoding/json"
	"os"
	"strings"

	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/memory"
	"github.com/NeoLabs-Systems/neoagent/internal/neorouterapi"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neolabs-go/embedding"
)

type memoryEmbeddingAdapter struct {
	router  *neorouterapi.Service
	store   *settings.Store
	catalog settingsCatalogAdapter
	client  *embedding.Client
}

func (a memoryEmbeddingAdapter) Embed(ctx context.Context, req memory.EmbedRequest) (*memory.Embedding, error) {
	if strings.TrimSpace(req.Text) == "" {
		return nil, nil
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	conn, err := a.router.ForRole(ctx, req.UserID, req.AgentID, "embeddings")
	if err == nil && conn != nil {
		result, callErr := a.router.Embed(ctx, conn, embedding.Truncate(req.Text), req.InputType)
		if callErr == nil && result != nil {
			vector := make([]float32, len(result.Vector))
			for i, v := range result.Vector {
				vector[i] = float32(v)
			}
			return &memory.Embedding{Vector: vector, Provider: "neorouter", Model: result.Model, Dimensions: len(vector)}, nil
		}
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	googleKey := strings.TrimSpace(os.Getenv("GOOGLE_AI_KEY"))
	if googleKey != "" && a.activeProvider(ctx, req.UserID, req.AgentID) == "google" {
		result, err := a.client.Google(ctx, googleKey, req.Text, req.InputType)
		if err != nil {
			return nil, err
		}
		if result != nil {
			return &memory.Embedding{Vector: result.Vector, Provider: result.Provider, Model: result.Model, Dimensions: result.Dimensions}, nil
		}
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	result, err := a.client.OpenAI(ctx, strings.TrimSpace(os.Getenv("OPENAI_API_KEY")), req.Text)
	if err != nil || result == nil {
		return nil, err
	}
	return &memory.Embedding{Vector: result.Vector, Provider: result.Provider, Model: result.Model, Dimensions: result.Dimensions}, nil
}

func (a memoryEmbeddingAdapter) activeProvider(ctx context.Context, userID int64, agentID string) string {
	values, err := a.store.All(ctx, userID, agentID)
	if err != nil {
		return ""
	}
	var selected string
	_ = json.Unmarshal(values["default_chat_model"], &selected)
	if selected == "" || selected == "auto" {
		var enabled []string
		_ = json.Unmarshal(values["enabled_models"], &enabled)
		if len(enabled) > 0 {
			selected = enabled[0]
		}
	}
	if selected == "" {
		return ""
	}
	entries, _, _ := a.catalog.listModels(ctx, userID, agentID)
	models := make([]aimodels.Model, 0, len(entries))
	for _, entry := range entries {
		data, err := json.Marshal(entry)
		if err != nil {
			continue
		}
		var model aimodels.Model
		if json.Unmarshal(data, &model) == nil && model.Available {
			models = append(models, model)
		}
	}
	if model := aimodels.ResolveSelection(models, selected, ""); model != nil {
		return model.Provider
	}
	return ""
}
