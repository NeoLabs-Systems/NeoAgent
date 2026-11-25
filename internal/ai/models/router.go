package models

import (
	"slices"
	"sort"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/textx"
)

// Settings are the routing-relevant AI settings of an account and agent.
type Settings struct {
	EnabledModels        []string
	DefaultChatModel     string
	DefaultSubagentModel string
	CostMode             string
}

// Hint is what the caller knows about the request.
type Hint struct {
	Purpose            string
	AutonomyLevel      string
	Complexity         string
	CostMode           string
	RequiredConfidence string
}

// Unavailable is returned when routing has nothing to run on. Its Code is
// AI_MODELS_UNAVAILABLE, as in the Node server.
type Unavailable struct{ Message string }

func (e *Unavailable) Error() string { return e.Message }

// Code is the stable error code callers match on.
func (e *Unavailable) Code() string { return "AI_MODELS_UNAVAILABLE" }

var (
	purposes     = []string{"planning", "coding", "general", "fast"}
	economyModes = []string{"economy", "cost_saver", "lowest_cost"}
	qualityModes = []string{"quality", "highest_quality"}

	// The price class each kind of request reaches for first. Providers sell
	// their small and large models at very different rates, so price says which
	// class a model is in and its release date says whether it is current. A
	// model with no known price ranks with the mid-priced ones.
	tierPreferences = map[string][]string{
		"balanced": {"medium", "cheap", "expensive", "free"},
		"fast":     {"cheap", "medium", "free", "expensive"},
		"economy":  {"free", "cheap", "medium", "expensive"},
		"quality":  {"expensive", "medium", "cheap", "free"},
	}
)

// Pools are the model sets routing chooses from.
type Pools struct {
	Selectable, Ready []Model
	ConfiguredIDs     []string
	ConfiguredReady   []Model
}

// BuildRoutingPools sorts the catalog into what is selectable, what is also
// healthy, and what the account's enabled-models list allows.
func BuildRoutingPools(models []Model, enabled []string, health HealthSnapshot, excludedModelIDs, excludedProviderIDs []string) Pools {
	var selectable []Model
	for _, m := range models {
		if m.Available {
			selectable = append(selectable, m)
		}
	}
	var ready []Model
	for _, m := range selectable {
		if health.IsBlocked(m) || slices.Contains(excludedModelIDs, m.ID) || slices.Contains(lowerAll(excludedProviderIDs), m.Provider) {
			continue
		}
		ready = append(ready, m)
	}
	var configured []string
	for _, id := range enabled {
		if id = textx.Trim(id); id != "" {
			configured = append(configured, id)
		}
	}
	normalized := NormalizeSelections(selectable, configured)
	configuredReady := ready
	if len(configured) > 0 {
		configuredReady = nil
		for _, m := range ready {
			if slices.Contains(normalized, m.ID) {
				configuredReady = append(configuredReady, m)
			}
		}
	}
	return Pools{Selectable: selectable, Ready: ready, ConfiguredIDs: configured, ConfiguredReady: configuredReady}
}

func lowerAll(values []string) []string {
	out := make([]string, 0, len(values))
	for _, v := range values {
		if v = strings.ToLower(textx.Trim(v)); v != "" {
			out = append(out, v)
		}
	}
	return out
}

func requestedPurpose(isSubagent bool, hint Hint) string {
	explicit := strings.ToLower(textx.Trim(hint.Purpose))
	if slices.Contains(purposes, explicit) {
		return explicit
	}
	if hint.AutonomyLevel == "high" || hint.Complexity == "complex" {
		return "planning"
	}
	if isSubagent {
		return "fast"
	}
	return "general"
}

func routingProfile(isSubagent bool, hint Hint, s Settings) string {
	costMode := hint.CostMode
	if costMode == "" {
		costMode = s.CostMode
	}
	if costMode == "" {
		costMode = "balanced_auto"
	}
	costMode = strings.ToLower(textx.Trim(costMode))
	confidence := strings.ToLower(textx.Trim(hint.RequiredConfidence))
	switch {
	case slices.Contains(economyModes, costMode):
		return "economy"
	case slices.Contains(qualityModes, costMode) || confidence == "high":
		return "quality"
	case requestedPurpose(isSubagent, hint) == "fast":
		return "fast"
	}
	return "balanced"
}

func tierRank(m Model, preference []string) int {
	if rank := slices.Index(preference, m.PriceTier); rank != -1 {
		return rank
	}
	return slices.Index(preference, "medium")
}

// RankModels orders candidates for automatic selection: models whose catalog
// says they cannot call tools last, then the price class the request wants, then
// the most recent release. Nothing here reads model names.
func RankModels(models []Model, isSubagent bool, hint Hint, s Settings) []Model {
	preference := tierPreferences[routingProfile(isSubagent, hint, s)]
	type ranked struct {
		model             Model
		index, tool, tier int
		createdAt         float64
	}
	entries := make([]ranked, len(models))
	for i, m := range models {
		entry := ranked{model: m, index: i, tier: tierRank(m, preference)}
		if m.SupportsTools != nil && !*m.SupportsTools {
			entry.tool = 1
		}
		if m.CreatedAt != nil {
			entry.createdAt = *m.CreatedAt
		}
		entries[i] = entry
	}
	sort.SliceStable(entries, func(a, b int) bool {
		l, r := entries[a], entries[b]
		if l.tool != r.tool {
			return l.tool < r.tool
		}
		if l.tier != r.tier {
			return l.tier < r.tier
		}
		if l.createdAt != r.createdAt {
			return l.createdAt > r.createdAt
		}
		return l.index < r.index
	})
	out := make([]Model, len(entries))
	for i, e := range entries {
		out[i] = e.model
	}
	return out
}

// With NeoRouter connected for chat, its routing replaces the Smart Selector: an
// automatic choice goes to the NeoRouter profile that fits the request, whatever
// the Smart Selector pool holds, and NeoRouter itself picks the model and falls
// back across its providers for every request. "auto:default" follows the
// profile set on NeoAgent's key in NeoRouter; NeoRouter already takes the
// cheaper of similar models, so economy needs no profile of its own.
var neoRouterProfiles = map[string]string{
	"economy": "auto:default", "quality": "auto:smart", "fast": "auto:fast",
	"planning": "auto:smart", "coding": "auto:smart", "general": "auto:default",
}

// Work a tool turn shows (see TaskKinds) and the profile it gets when the user
// pinned no model for it.
var neoRouterTaskProfiles = map[string]string{
	"coding": "auto:smart", "computer_use": "auto:smart", "android_use": "auto:smart", "research": "auto:smart",
}

func neoRouterProfile(isSubagent bool, hint Hint, s Settings) string {
	profile := routingProfile(isSubagent, hint, s)
	if profile != "balanced" {
		return neoRouterProfiles[profile]
	}
	return neoRouterProfiles[requestedPurpose(isSubagent, hint)]
}

func neoRouterModel(models []Model, profile string) *Model {
	for i := range models {
		if models[i].Provider == "neorouter" && models[i].ModelID == profile {
			return &models[i]
		}
	}
	return nil
}

// NeoRouterTaskSelection is the NeoRouter profile a tool turn of this kind moves
// to, or "".
func NeoRouterTaskSelection(kind string) string {
	if profile, ok := neoRouterTaskProfiles[kind]; ok {
		return "neorouter::" + profile
	}
	return ""
}

// Sub-agents run on the chat model unless an older config pinned one for them.
func subagentOrChatModel(s Settings, isSubagent bool) string {
	chat := s.DefaultChatModel
	if chat == "" {
		chat = "auto"
	}
	if !isSubagent {
		return chat
	}
	sub := s.DefaultSubagentModel
	if sub == "" {
		sub = "auto"
	}
	if sub == "auto" {
		return chat
	}
	return sub
}

// Route is the outcome of initial selection. Reason is "requested_model_unavailable"
// when an explicitly requested model could not be used.
type Route struct {
	Model  Model
	Reason string
}

// InitialRequest describes a selection.
type InitialRequest struct {
	Models        []Model
	Settings      Settings
	Health        HealthSnapshot
	IsSubagent    bool
	ModelOverride string
	Hint          Hint
}

// SelectInitialModel picks the model a run starts on: the requested one when it
// is usable, else NeoRouter's profile when connected, else the best of the
// automatic pool. With enabled_models configured, automatic routing only ever
// picks from that pool; falling back to the full discovered catalog would
// silently run models the user never enabled.
func SelectInitialModel(req InitialRequest) (Route, error) {
	pools := BuildRoutingPools(req.Models, req.Settings.EnabledModels, req.Health, nil, nil)
	if len(pools.Selectable) == 0 {
		cooling := false
		for _, m := range req.Models {
			cooling = cooling || m.RuntimeUnavailable
		}
		if cooling {
			return Route{}, &Unavailable{"All AI models are temporarily unavailable after provider errors. The next run will retry after their recovery window."}
		}
		return Route{}, &Unavailable{"No AI model is available. Add a provider API key in Settings → API keys (or ask your server admin), then try again."}
	}
	if len(pools.Ready) == 0 {
		return Route{}, &Unavailable{"All discovered AI models are temporarily unavailable. The next run will retry after their recovery window."}
	}
	requestedID := textx.Trim(req.ModelOverride)
	if requestedID == "" {
		requestedID = subagentOrChatModel(req.Settings, req.IsSubagent)
	}
	if requestedID != "auto" {
		if requested := ResolveSelection(pools.Ready, requestedID, ""); requested != nil {
			return Route{Model: *requested}, nil
		}
	}
	reason := ""
	if requestedID != "auto" {
		reason = "requested_model_unavailable"
	}
	if routed := neoRouterModel(pools.Ready, neoRouterProfile(req.IsSubagent, req.Hint, req.Settings)); routed != nil {
		return Route{Model: *routed, Reason: reason}, nil
	}
	if len(pools.ConfiguredIDs) > 0 && len(pools.ConfiguredReady) == 0 {
		return Route{}, &Unavailable{"None of the enabled AI models are currently usable. Enable another model in Settings or wait for their recovery window."}
	}
	pool := pools.Ready
	if len(pools.ConfiguredIDs) > 0 {
		pool = pools.ConfiguredReady
	}
	ranked := RankModels(pool, req.IsSubagent, req.Hint, req.Settings)
	return Route{Model: ranked[0], Reason: reason}, nil
}

// FallbackRequest describes a failure fallback.
type FallbackRequest struct {
	Models              []Model
	Settings            Settings
	Health              HealthSnapshot
	CurrentModelID      string
	ExcludedModelIDs    []string
	ExcludedProviderIDs []string
}

// SelectFallbackModel picks the model to move to after a failure: from the same
// pool as automatic routing, preferring another provider than the failed one. It
// returns nil when nothing is left.
func SelectFallbackModel(req FallbackRequest) *Model {
	pools := BuildRoutingPools(req.Models, req.Settings.EnabledModels, req.Health, req.ExcludedModelIDs, req.ExcludedProviderIDs)
	base := pools.Ready
	if len(pools.ConfiguredIDs) > 0 {
		base = pools.ConfiguredReady
	}
	if len(base) == 0 {
		return nil
	}
	current := ResolveSelection(pools.Selectable, req.CurrentModelID, "")
	if current == nil {
		current = ResolveSelection(req.Models, req.CurrentModelID, "")
	}
	candidates := base
	if current != nil && current.Provider != "" {
		var diverse []Model
		for _, m := range base {
			if m.Provider != current.Provider {
				diverse = append(diverse, m)
			}
		}
		if len(diverse) > 0 {
			candidates = diverse
		}
	}
	purpose := "general"
	if current != nil && current.Purpose != "" {
		purpose = current.Purpose
	}
	ranked := RankModels(candidates, false, Hint{Purpose: purpose}, req.Settings)
	if len(ranked) == 0 {
		return nil
	}
	return &ranked[0]
}
