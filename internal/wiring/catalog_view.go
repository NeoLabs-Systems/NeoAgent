package wiring

import (
	"context"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/llm"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"

	aimodels "github.com/NeoLabs-Systems/neoagent/internal/ai/models"
	"github.com/NeoLabs-Systems/neoagent/internal/jsonobj"
	"github.com/NeoLabs-Systems/neoagent/internal/neorouterapi"
	"github.com/NeoLabs-Systems/neoagent/internal/providersignin"
)

// modelReference holds the release dates, prices and tool support most
// provider catalogs leave out (OpenRouter's public catalog, no key sent).
var modelReference = llm.NewReference()

// The key order clients have always received for catalog entries.
var (
	chatModelKeys = []string{"id", "label", "provider", "purpose", "createdAt", "supportsTools", "modelId", "priceTier", "inputCostPerM",
		"available", "runtimeUnavailable", "providerStatus", "providerStatusLabel", "isByok", "byokLabel", "adminGranted"}
	decisionModelKeys = []string{"id", "label", "provider", "purpose", "createdAt", "supportsTools", "modelId", "priceTier", "inputCostPerM",
		"available", "runtimeUnavailable", "isByok", "byokLabel"}
	providerKeys = []string{"id", "label", "description", "authentication", "supportsApiKey", "supportsBaseUrl", "requiresBaseUrl", "defaultBaseUrl",
		"enabled", "available", "credentialConfigured", "baseUrlConfigured", "baseUrl", "customLabel", "isByok", "status", "statusLabel",
		"availabilityReason", "connected", "configured", "healthy", "degraded"}
)

func ordered(row map[string]any, keys []string) *jsonobj.Object {
	o := jsonobj.New()
	for _, k := range keys {
		o.Set(k, row[k])
	}
	return o
}

func orderedRows(rows []map[string]any, keys []string) []*jsonobj.Object {
	out := make([]*jsonobj.Object, 0, len(rows))
	for _, r := range rows {
		out = append(out, ordered(r, keys))
	}
	return out
}

// providerCatalog is every provider with whether it can be called and its
// health status, as the settings screens and the model catalog see it. The
// base URL is unfiltered; callers decide who may see it.
func (c settingsCatalogAdapter) providerCatalog(ctx context.Context, userID int64, agentID string) ([]map[string]any, error) {
	statuses, err := c.store.ProviderStatuses(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	compatKey, compatibleReady := "", false
	for _, st := range statuses {
		if st.ID == "openai-compatible" {
			_, key, baseURL, _ := resolveProvider(st)
			compatKey = key
			compatibleReady = key != "" && baseURL != "" && validBaseURL(baseURL)
		}
	}

	out := make([]map[string]any, 0, len(statuses))
	for _, st := range statuses {
		def, key, baseURL, _ := resolveProvider(st)
		baseURLValid := validBaseURL(baseURL)
		credConfigured := key != ""
		available := (!st.SupportsAPIKey || credConfigured) && (!st.RequiresBaseURL || (baseURL != "" && baseURLValid))
		if st.ID == "neorouter" {
			conn := c.routerForRole(ctx, userID, agentID, "chat")
			available, credConfigured = conn != nil, conn != nil
			if conn != nil {
				baseURL = conn.APIBase
			}
		}
		// Official OpenAI stays off when its key is the one a custom
		// OpenAI-compatible endpoint uses: that key belongs to the endpoint.
		sharesCompatibleKey := st.ID == "openai" && officialOpenAIHost(baseURL) && key != "" && key == compatKey && !st.IsBYOK
		if available && compatibleReady && sharesCompatibleKey {
			available = false
		}

		status, statusLabel, reason := "ready", "Ready", "Provider is available."
		switch {
		case st.SupportsAPIKey && !credConfigured:
			status, statusLabel, reason = "needs_setup", "Setup Needed", "Credentials for this provider are not available on this deployment yet."
		case st.RequiresBaseURL && baseURL == "":
			status, statusLabel, reason = "needs_setup", "Setup Needed", "A base URL is required for this provider."
		case st.RequiresBaseURL && !baseURLValid:
			status, statusLabel, reason = "needs_setup", "Setup Needed", "The configured base URL must be an HTTP or HTTPS URL without embedded credentials."
		case st.ID == "openai" && !available && compatibleReady:
			status, statusLabel, reason = "needs_setup", "Setup Needed", "Official OpenAI is not enabled when OPENAI_API_KEY is the same key used for a custom OpenAI-compatible endpoint."
		case st.ID == "ollama":
			status, statusLabel, reason = "local", "Local", "This provider connects to your local Ollama server."
		case credConfigured:
			status, statusLabel, reason = "configured", "Configured", "Credentials for this provider are available to the runtime."
		}
		// Health: a callable provider is connected; a configured one is healthy.
		var connected any
		healthy, degraded := available, false
		switch {
		case st.ID == "ollama":
			addr := baseURL
			if addr == "" {
				addr = def.DefaultBaseURL
			}
			probe := probeOllama(ctx, addr)
			connected, healthy, degraded = probe.healthy, probe.healthy, !probe.healthy
			if !probe.healthy {
				status, statusLabel, reason = "offline", "Offline", probe.reason
			} else if available {
				status, statusLabel, reason = "healthy", "Healthy", probe.reason
			}
		case available:
			connected = true
			if status == "configured" {
				status, statusLabel = "healthy", "Healthy"
			}
		default:
			connected = false
		}
		out = append(out, map[string]any{
			"id": st.ID, "label": def.Label, "description": def.Description, "authentication": st.Authentication,
			"supportsApiKey": st.SupportsAPIKey, "supportsBaseUrl": st.SupportsBaseURL, "requiresBaseUrl": st.RequiresBaseURL,
			"defaultBaseUrl": st.DefaultBaseURL, "enabled": st.Enabled, "available": healthy,
			"credentialConfigured": credConfigured, "baseUrlConfigured": baseURL != "", "baseUrl": baseURL,
			"customLabel": st.Label, "isByok": st.IsBYOK, "status": status, "statusLabel": statusLabel,
			"availabilityReason": reason, "connected": connected, "configured": st.ID == "ollama" || available,
			"healthy": healthy, "degraded": degraded,
		})
	}
	return out, nil
}

// validBaseURL accepts an empty base URL or an HTTP(S) URL without credentials.
func validBaseURL(baseURL string) bool {
	if baseURL == "" {
		return true
	}
	_, err := ssrf.CheckURL(baseURL)
	return err == nil
}

func officialOpenAIHost(baseURL string) bool {
	if baseURL == "" {
		return true
	}
	u, err := ssrf.CheckURL(baseURL)
	return err == nil && strings.EqualFold(u.Hostname(), "api.openai.com")
}

// enrich fills in what the reference catalog and the health memory know about
// each model, the way the Node catalog did.
func (c settingsCatalogAdapter) enrich(ctx context.Context, userID int64, agentID string, rows []map[string]any, decisions bool, providers []map[string]any) {
	status := map[string]map[string]any{}
	for _, p := range providers {
		id, _ := p["id"].(string)
		status[id] = p
	}
	var health aimodels.HealthSnapshot
	if c.failures != nil {
		health = c.failures.Snapshot(ctx, userID, agentID)
	}
	for _, r := range rows {
		provider, _ := r["provider"].(string)
		modelID, _ := r["modelId"].(string)
		id, _ := r["id"].(string)
		var cost *float64
		var facts llm.ModelFacts
		if provider == "ollama" {
			zero := 0.0
			cost = &zero
		} else if f, ok := modelReference.Lookup(modelID); ok {
			facts, cost = f, f.InputCostPerM
		}
		tier, _ := r["priceTier"].(string)
		if tier == "" {
			tier = llm.PriceTierForCost(cost)
		}
		r["priceTier"] = nilIfEmpty(tier)
		r["inputCostPerM"] = floatOrNil(cost)
		if facts.CreatedAtMs != nil {
			r["createdAt"] = float64(*facts.CreatedAtMs)
		} else if r["createdAt"] == nil {
			r["createdAt"] = nil
		}
		if r["supportsTools"] == nil && facts.SupportsTools != nil {
			r["supportsTools"] = *facts.SupportsTools
		}
		if decisions {
			r["purpose"] = ""
		} else if tier == "cheap" {
			r["purpose"] = "fast"
		} else {
			r["purpose"] = "general"
		}
		blocked := health.IsBlocked(aimodels.Model{ID: id, ModelID: modelID, Provider: provider, PriceTier: tier})
		r["runtimeUnavailable"] = blocked
		if blocked {
			r["available"] = false
		}
		if !decisions {
			p := status[provider]
			r["providerStatus"], r["providerStatusLabel"] = "unknown", "Unknown"
			if p != nil {
				r["providerStatus"], r["providerStatusLabel"] = p["status"], p["statusLabel"]
				if p["available"] == false {
					r["available"] = false
				}
			}
		}
	}
}

func nilIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func floatOrNil(f *float64) any {
	if f == nil {
		return nil
	}
	return *f
}

// listModels is the chat model catalog with per-provider counts.
func (c settingsCatalogAdapter) listModels(ctx context.Context, userID int64, agentID string) ([]map[string]any, map[string]int, map[string]int) {
	var providers []map[string]any
	if !c.serverOnly {
		providers, _ = c.providerCatalog(ctx, userID, agentID)
	}
	// The reference loads first: a provider's own listing, recorded during
	// discovery, is more specific than the public catalog and must win.
	_ = modelReference.EnsureFresh(ctx, publicModelHTTP)
	rows := c.discover(ctx, userID, agentID, false)
	if rows == nil {
		rows = []map[string]any{}
	}
	if c.nr != nil {
		if conn := c.routerForRole(ctx, userID, agentID, "chat"); conn != nil {
			if ms, err := c.nr.ListModels(ctx, conn, "chat"); err == nil {
				for _, m := range ms {
					if m.ID == "" {
						continue
					}
					tier, _ := m.Raw["priceTier"].(string)
					rows = append(rows, map[string]any{
						"id": "neorouter::" + m.ID, "modelId": m.ID, "label": m.ID + " (NeoRouter)", "provider": "neorouter",
						"available": true, "priceTier": tier, "createdAt": nil, "supportsTools": nil, "isByok": false, "byokLabel": "", "adminGranted": false,
					})
				}
			}
		}
	}
	c.enrich(ctx, userID, agentID, rows, false, providers)
	c.applyVisibility(ctx, userID, rows, false)
	counts, avail := map[string]int{}, map[string]int{}
	for _, r := range rows {
		id, _ := r["provider"].(string)
		counts[id]++
		if r["available"] != false {
			avail[id]++
		}
	}
	return rows, counts, avail
}

// decisionModels is the SystemOne model catalog.
func (c settingsCatalogAdapter) decisionModels(ctx context.Context, userID int64, agentID string) []map[string]any {
	_ = modelReference.EnsureFresh(ctx, publicModelHTTP)
	rows := c.discover(ctx, userID, agentID, true)
	if rows == nil {
		rows = []map[string]any{}
	}
	if c.nr != nil {
		if conn := c.routerForRole(ctx, userID, agentID, "system_one"); conn != nil {
			if list, err := c.nr.ListModels(ctx, conn, "moderation"); err == nil {
				for _, m := range list {
					if neorouterapi.IsDecisionModel(m) {
						rows = append(rows, map[string]any{
							"id": "neorouter::" + m.ID, "modelId": m.ID, "label": m.ID + " (NeoRouter)", "provider": "neorouter",
							"available": true, "createdAt": nil, "supportsTools": nil, "isByok": false, "byokLabel": "",
						})
					}
				}
			}
		}
	}
	c.enrich(ctx, userID, agentID, rows, true, nil)
	c.applyVisibility(ctx, userID, rows, true)
	return rows
}

// Models serves /api/settings/meta/models.
func (c settingsCatalogAdapter) Models(ctx context.Context, userID int64, agentID string) (any, error) {
	rows, _, _ := c.listModels(ctx, userID, agentID)
	return jsonobj.New("models", orderedRows(rows, chatModelKeys)), nil
}

// SystemOneModels serves /api/settings/meta/system-one-models.
func (c settingsCatalogAdapter) SystemOneModels(ctx context.Context, userID int64, agentID string) (any, error) {
	return jsonobj.New("models", orderedRows(c.decisionModels(ctx, userID, agentID), decisionModelKeys)), nil
}

// AIProviders serves /api/settings/meta/ai-providers. A base URL from the
// server's environment (a NeoRouter, a LAN Ollama, ...) is the operator's
// business: people see only addresses they set up.
func (c settingsCatalogAdapter) AIProviders(ctx context.Context, userID int64, agentID string) (any, error) {
	providers, err := c.providerCatalog(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	_, counts, avail := c.listModels(ctx, userID, agentID)
	admin := c.users != nil && c.users.IsAdmin(ctx, userID)
	out := make([]*jsonobj.Object, 0, len(providers))
	for _, p := range providers {
		id, _ := p["id"].(string)
		baseURL, _ := p["baseUrl"].(string)
		if !admin && p["isByok"] != true && baseURL != "" {
			p["baseUrl"] = ""
			reason, _ := p["availabilityReason"].(string)
			p["availabilityReason"] = strings.ReplaceAll(reason, baseURL, "the configured address")
		}
		o := ordered(p, providerKeys)
		o.Set("modelCount", counts[id])
		o.Set("availableModelCount", avail[id])
		out = append(out, o)
	}
	return jsonobj.New("providers", out), nil
}

// BYOKList serves /api/settings/byok.
func (c settingsCatalogAdapter) BYOKList(ctx context.Context, userID int64, agentID string) (any, error) {
	providers, err := c.providerCatalog(ctx, userID, agentID)
	if err != nil {
		return nil, err
	}
	out := []*jsonobj.Object{}
	for _, p := range providers {
		id, _ := p["id"].(string)
		apiKey, _ := p["supportsApiKey"].(bool)
		base, _ := p["supportsBaseUrl"].(bool)
		if (!apiKey && !base) || p["authentication"] == "oauth" || id == "minimax" {
			continue
		}
		byok := p["isByok"] == true
		baseURL, customLabel := "", ""
		if byok {
			baseURL, _ = p["baseUrl"].(string)
			customLabel, _ = p["customLabel"].(string)
		}
		out = append(out, jsonobj.New(
			"id", id, "label", p["label"], "description", p["description"],
			"supportsApiKey", apiKey, "supportsBaseUrl", base, "requiresBaseUrl", p["requiresBaseUrl"],
			"defaultBaseUrl", p["defaultBaseUrl"], "isCustomEndpoint", id == "openai-compatible",
			"configured", byok, "signInAvailable", providersignin.HasSignInMethod(id),
			"baseUrl", baseURL, "customLabel", customLabel,
		))
	}
	return jsonobj.New("providers", out), nil
}
