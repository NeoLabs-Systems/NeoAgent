// Package models is the model catalog the harness routes over: selection ids,
// which models are visible to an account, the health memory that keeps failing
// models out of routing, automatic selection, and token-usage records.
package models

import (
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// SelectionSeparator joins a provider and a model id into a selection id.
const SelectionSeparator = "::"

// Model is one entry of the live catalog as routing and the settings screens
// see it. Available is false when the provider, an admin switch or the health
// memory keeps the model out of use.
type Model struct {
	// ID is the provider-scoped selection id ("openai::gpt-5.5"); ModelID is the
	// provider's own id.
	ID       string `json:"id"`
	ModelID  string `json:"modelId"`
	Name     string `json:"name,omitempty"`
	Provider string `json:"provider"`

	ContextWindow int  `json:"contextWindow,omitempty"`
	Vision        bool `json:"vision,omitempty"`

	// CreatedAt is the public release date in milliseconds, when known.
	CreatedAt     *float64 `json:"createdAt"`
	SupportsTools *bool    `json:"supportsTools"`
	Purpose       string   `json:"purpose"`
	PriceTier     string   `json:"priceTier,omitempty"`
	InputCostPerM *float64 `json:"inputCostPerM"`

	Available           bool   `json:"available"`
	RuntimeUnavailable  bool   `json:"runtimeUnavailable"`
	ProviderStatus      string `json:"providerStatus"`
	ProviderStatusLabel string `json:"providerStatusLabel"`
	IsByok              bool   `json:"isByok"`
	ByokLabel           string `json:"byokLabel"`
	AdminGranted        bool   `json:"adminGranted"`
}

// CreateSelectionID builds a provider-scoped model id.
func CreateSelectionID(provider, modelID string) string {
	return strings.ToLower(textx.Trim(provider)) + SelectionSeparator + textx.Trim(modelID)
}

// Selection is a parsed selection id.
type Selection struct{ Provider, ModelID string }

// ParseSelectionID splits a selection id; ok is false for anything that is not
// a provider-scoped model (including "auto").
func ParseSelectionID(value string) (Selection, bool) {
	raw := textx.Trim(value)
	separator := strings.Index(raw, SelectionSeparator)
	if separator <= 0 {
		return Selection{}, false
	}
	provider := strings.ToLower(textx.Trim(raw[:separator]))
	modelID := textx.Trim(raw[separator+len(SelectionSeparator):])
	if provider == "" || modelID == "" || modelID == "auto" {
		return Selection{}, false
	}
	return Selection{Provider: provider, ModelID: modelID}, true
}

// RawModelID is the provider's own id of a model.
func RawModelID(m Model) string {
	if m.ModelID != "" {
		return textx.Trim(m.ModelID)
	}
	return textx.Trim(m.ID)
}

// ToSelectable gives a catalog entry its provider-scoped id.
func ToSelectable(m Model) Model {
	provider := strings.ToLower(textx.Trim(m.Provider))
	modelID := RawModelID(m)
	m.ID = CreateSelectionID(provider, modelID)
	m.ModelID = modelID
	m.Provider = provider
	return m
}

// ResolveSelection finds the catalog model a stored or requested id means:
// the exact selection id, else a legacy bare model id (preferring the given
// provider when several providers offer it).
func ResolveSelection(models []Model, value, preferredProvider string) *Model {
	requested := textx.Trim(value)
	if requested == "" {
		return nil
	}
	for i := range models {
		if models[i].ID == requested {
			return &models[i]
		}
	}
	var legacy []*Model
	for i := range models {
		if RawModelID(models[i]) == requested {
			legacy = append(legacy, &models[i])
		}
	}
	if len(legacy) <= 1 {
		if len(legacy) == 1 {
			return legacy[0]
		}
		return nil
	}
	if preferred := strings.ToLower(textx.Trim(preferredProvider)); preferred != "" {
		for _, m := range legacy {
			if m.Provider == preferred {
				return m
			}
		}
	}
	// Preserve the catalog's stable ordering for legacy, unscoped settings. New
	// selections always use the provider-scoped id and are therefore unambiguous.
	return legacy[0]
}

// NormalizeSelections maps stored ids to unique selection ids, dropping what
// the catalog does not know.
func NormalizeSelections(models []Model, values []string) []string {
	var out []string
	seen := map[string]bool{}
	for _, value := range values {
		m := ResolveSelection(models, value, "")
		if m == nil || seen[m.ID] {
			continue
		}
		seen[m.ID] = true
		out = append(out, m.ID)
	}
	return out
}

// MatchesConfiguredID reports whether a model is named by a set of ids, by
// selection id or by bare model id.
func MatchesConfiguredID(m Model, configured map[string]bool) bool {
	if configured == nil {
		return false
	}
	return configured[m.ID] || configured[RawModelID(m)]
}
