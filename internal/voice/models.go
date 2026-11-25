package voice

import (
	"context"
	"regexp"
	"sort"
	"strconv"
)

var (
	autoModel    = regexp.MustCompile(`^auto(-(free|plan|paid))?:default$`)
	previewModel = regexp.MustCompile(`(?i)preview`)
	versionInID  = regexp.MustCompile(`\d+(?:\.\d+)?`)
)

func versionOf(modelID string) float64 {
	match := versionInID.FindString(modelID)
	if match == "" {
		return 0
	}
	v, _ := strconv.ParseFloat(match, 64)
	return v
}

func flag(b bool) int {
	if b {
		return 1
	}
	return 0
}

// RankLiveModels orders a provider's live models: a router's auto model first
// (it picks the best live model per call), then released models before
// previews, the newest version first, and the plain model before its variants.
// The first one is what a call uses when nobody picked a model.
func RankLiveModels(models []LiveModel) []LiveModel {
	ranked := append([]LiveModel(nil), models...)
	sort.SliceStable(ranked, func(i, j int) bool {
		a, b := ranked[i], ranked[j]
		if x, y := flag(autoModel.MatchString(a.ID)), flag(autoModel.MatchString(b.ID)); x != y {
			return x > y
		}
		if x, y := flag(previewModel.MatchString(a.ID)), flag(previewModel.MatchString(b.ID)); x != y {
			return x < y
		}
		if va, vb := versionOf(a.ID), versionOf(b.ID); va != vb {
			return va > vb
		}
		return len(utf16Units(a.ID)) < len(utf16Units(b.ID))
	})
	return ranked
}

// LiveCatalog resolves live providers and their models for an account.
type LiveCatalog struct {
	AI       AIDirectory
	Defaults Defaults
}

// providerReady: whether this person can call through the provider at all. It
// needs a key, and a NeoRouter also needs live voice switched on for it.
func (c LiveCatalog) providerReady(userID int64, agentID string, p LiveProvider) bool {
	creds := c.AI.ProviderCredentials(userID, p.RuntimeProvider, agentID)
	return creds.APIKey != "" && c.AI.ProviderServesRole(p.RuntimeProvider, userID, agentID, "live")
}

// ListModels lists a provider's live models. They come from the provider's own
// model list, refreshed and cached like the chat models; without a key there is
// nothing to list.
func (c LiveCatalog) ListModels(ctx context.Context, userID int64, agentID string, p LiveProvider) ([]LiveModel, error) {
	if !c.providerReady(userID, agentID, p) {
		return nil, nil
	}
	creds := c.AI.ProviderCredentials(userID, p.RuntimeProvider, agentID)
	models, err := c.AI.ListVoiceModels(ctx, userID, p.RuntimeProvider, creds)
	if err != nil {
		return nil, err
	}
	if p.Protocol == "" {
		return models, nil
	}
	// A NeoRouter lists its live models once, with the protocols that reach each.
	var served []LiveModel
	for _, m := range models {
		for _, protocol := range m.Protocols {
			if protocol == p.Protocol {
				served = append(served, m)
				break
			}
		}
	}
	return served, nil
}

// Resolve picks the configured model, or the provider's default. What the model
// list says about it (whether it thinks) comes along; a configured model the
// list does not show is used as given. It reports false when there is none.
func (c LiveCatalog) Resolve(ctx context.Context, userID int64, agentID string, p LiveProvider, configured string) (LiveModel, bool, error) {
	models, err := c.ListModels(ctx, userID, agentID, p)
	if err != nil {
		return LiveModel{}, false, err
	}
	if configured == "" {
		ranked := RankLiveModels(models)
		if len(ranked) == 0 {
			return LiveModel{}, false, nil
		}
		return ranked[0], true, nil
	}
	for _, m := range models {
		if m.ID == configured {
			return m, true, nil
		}
	}
	return LiveModel{ID: configured}, true, nil
}

// ProviderInfo is one live provider as the settings and the admin console list
// it.
type ProviderInfo struct {
	ID           string   `json:"id"`
	Label        string   `json:"label"`
	Available    bool     `json:"available"`
	DefaultModel *string  `json:"defaultModel"`
	Models       []string `json:"models"`
	DefaultVoice string   `json:"defaultVoice"`
	Voices       []string `json:"voices"`
}

// CatalogInfo is the live voice part of the capabilities.
type CatalogInfo struct {
	DefaultProvider string         `json:"defaultProvider"`
	InputModes      []string       `json:"inputModes"`
	Providers       []ProviderInfo `json:"providers"`
}

// Describe is what the settings and the admin console offer.
func (c LiveCatalog) Describe(ctx context.Context, userID int64, agentID string) CatalogInfo {
	info := CatalogInfo{
		DefaultProvider: c.Defaults.ServerDefaultProvider(),
		InputModes:      append([]string{}, inputModes...),
		Providers:       []ProviderInfo{},
	}
	for _, p := range liveProviders {
		listed, err := c.ListModels(ctx, userID, agentID, p)
		if err != nil {
			listed = nil
		}
		ranked := RankLiveModels(listed)
		ids := make([]string, len(ranked))
		for i, m := range ranked {
			ids[i] = m.ID
		}
		var defaultModel *string
		if configured := c.Defaults.ConfiguredModel(p.ID, ""); configured != "" {
			defaultModel = &configured
		} else if len(ids) > 0 {
			defaultModel = &ids[0]
		}
		info.Providers = append(info.Providers, ProviderInfo{
			ID: p.ID, Label: p.Label,
			// A key alone is not enough: one that does not work, or a router
			// without live models for this protocol, lists nothing to call with.
			Available:    len(ids) > 0,
			DefaultModel: defaultModel,
			Models:       ids,
			DefaultVoice: c.Defaults.ResolveVoice(p.ID, ""),
			Voices:       append([]string{}, p.Voices...),
		})
	}
	return info
}
