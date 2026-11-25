package wiring

import (
	"context"
	"crypto/sha256"
	"fmt"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/admin"
	"github.com/NeoLabs-Systems/neoagent/internal/neorouterapi"
	"github.com/NeoLabs-Systems/neoagent/internal/settings"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
	"github.com/NeoLabs-Systems/neolabs-go/llm/providers"
	"github.com/NeoLabs-Systems/neolabs-go/llm/transport"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

var publicModelHTTP = ssrf.NewClient(ssrf.Options{Timeout: time.Hour})
var trustedModelHTTP = ssrf.NewClient(ssrf.Options{Timeout: time.Hour, AllowPrivate: true})

func modelHTTP(trusted bool) *http.Client {
	if trusted {
		return trustedModelHTTP
	}
	return publicModelHTTP
}

type providerRuntime struct {
	status   settings.ProviderStatus
	provider llm.Provider
	cacheKey [32]byte
}

func resolveProvider(st settings.ProviderStatus) (llm.ProviderDefinition, string, string, bool) {
	def, ok := llm.ProviderDefinitionFor(st.ID)
	if !ok {
		return def, "", "", false
	}
	key := strings.TrimSpace(st.APIKey)
	if key == "" && def.EnvKey != "" {
		key = strings.TrimSpace(os.Getenv(def.EnvKey))
	}
	baseURL := ""
	if def.SupportsBaseURL {
		if st.IsBYOK {
			baseURL = st.BaseURL
		}
		if baseURL == "" && def.BaseURLEnvKey != "" {
			baseURL = strings.TrimSpace(os.Getenv(def.BaseURLEnvKey))
		}
		if baseURL == "" {
			baseURL = def.DefaultBaseURL
		}
	}
	return def, key, baseURL, true
}
func runtimeProvider(st settings.ProviderStatus) (providerRuntime, bool) {
	def, key, baseURL, ok := resolveProvider(st)
	if !ok || st.ID == "neorouter" {
		return providerRuntime{}, false
	}
	if (def.SupportsAPIKey && key == "") || (def.RequiresBaseURL && baseURL == "") {
		return providerRuntime{}, false
	}
	p, err := providers.New(st.ID, providers.Config{Config: transport.Config{APIKey: key, BaseURL: baseURL, HTTPClient: modelHTTP(!st.IsBYOK)}})
	if err != nil {
		return providerRuntime{}, false
	}
	keyHash := sha256.Sum256([]byte(st.ID + "\x00" + key + "\x00" + baseURL))
	return providerRuntime{status: st, provider: p, cacheKey: keyHash}, true
}

type cachedCatalog struct {
	expires time.Time
	models  []llm.CatalogModel
}
type catalogCache struct {
	mu      sync.Mutex
	entries map[string]cachedCatalog
}

func (c *catalogCache) get(key string) ([]llm.CatalogModel, bool) {
	if c == nil {
		return nil, false
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	entry, ok := c.entries[key]
	if !ok || time.Now().After(entry.expires) {
		return nil, false
	}
	return append([]llm.CatalogModel(nil), entry.models...), true
}
func (c *catalogCache) put(key string, models []llm.CatalogModel, ttl time.Duration) {
	if c == nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.entries == nil {
		c.entries = map[string]cachedCatalog{}
	}
	now := time.Now()
	for k, entry := range c.entries {
		if !entry.expires.After(now) {
			delete(c.entries, k)
		}
	}
	c.entries[key] = cachedCatalog{expires: now.Add(ttl), models: append([]llm.CatalogModel(nil), models...)}
}

// discover runs the independent provider catalogs concurrently, preserving the
// provider order returned by the settings store.
func (c settingsCatalogAdapter) discover(ctx context.Context, userID int64, agentID string, decisions bool) []map[string]any {
	var statuses []settings.ProviderStatus
	if c.serverOnly {
		for _, d := range llm.ProviderDefinitions {
			statuses = append(statuses, settings.ProviderStatus{ID: d.ID, SupportsAPIKey: d.SupportsAPIKey, SupportsBaseURL: d.SupportsBaseURL, RequiresBaseURL: d.RequiresBaseURL, DefaultBaseURL: d.DefaultBaseURL})
		}
	} else {
		var err error
		statuses, err = c.store.ProviderStatuses(ctx, userID, agentID)
		if err != nil {
			return nil
		}
	}
	results := make([][]map[string]any, len(statuses))
	var wg sync.WaitGroup
	for i, st := range statuses {
		rt, ok := runtimeProvider(st)
		if !ok {
			continue
		}
		if decisions {
			if _, ok := rt.provider.(llm.Decider); !ok {
				continue
			}
		}
		wg.Add(1)
		go func(i int, rt providerRuntime) {
			defer wg.Done()
			callCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
			defer cancel()
			cacheKey := fmt.Sprintf("%x:%t", rt.cacheKey, decisions)
			found, cached := c.cache.get(cacheKey)
			if !cached {
				var err error
				found, err = listCatalog(callCtx, rt.provider, decisions)
				if err != nil || callCtx.Err() != nil {
					return
				}
				// OpenRouter's own listing is the reference catalog's source,
				// so what it states about its models is recorded there too.
				if rt.status.ID == "openrouter" {
					raw := make([]any, 0, len(found))
					for _, m := range found {
						if m.Raw != nil {
							raw = append(raw, m.Raw)
						}
					}
					modelReference.Record(raw)
				}
				ttl := 5 * time.Minute
				if rt.status.ID == "ollama" {
					ttl = 30 * time.Second
				}
				c.cache.put(cacheKey, found, ttl)
			}
			def, _ := llm.ProviderDefinitionFor(rt.status.ID)
			seen := map[string]bool{}
			for _, model := range found {
				id := strings.TrimSpace(model.ID)
				if id == "" || seen[id] {
					continue
				}
				seen[id] = true
				name := model.Name
				if name == "" {
					name = id
				}
				label := fmt.Sprintf("%s (%s)", name, def.Label)
				var createdAt, supportsTools any
				facts := llm.ReadCatalogFacts(model.Raw)
				if facts.CreatedAtMs != nil {
					createdAt = float64(*facts.CreatedAtMs)
				} else if model.Created > 0 {
					createdAt = float64(model.Created * 1000)
				}
				if model.SupportsTools != nil {
					supportsTools = *model.SupportsTools
				} else if facts.SupportsTools != nil {
					supportsTools = *facts.SupportsTools
				}
				results[i] = append(results[i], map[string]any{"id": def.ID + "::" + id, "modelId": id, "label": label, "provider": def.ID,
					"createdAt": createdAt, "supportsTools": supportsTools, "priceTier": model.PriceTier, "available": true,
					"isByok": rt.status.IsBYOK, "byokLabel": rt.status.Label, "adminGranted": false})
			}
		}(i, rt)
	}
	wg.Wait()
	var out []map[string]any
	for _, list := range results {
		out = append(out, list...)
	}
	return out
}

func (c settingsCatalogAdapter) applyVisibility(ctx context.Context, userID int64, models []map[string]any, decisions bool) {
	disabled := map[string]bool{}
	for _, id := range strings.Split(os.Getenv("NEOAGENT_DISABLED_MODELS"), ",") {
		if id = strings.TrimSpace(id); id != "" {
			disabled[id] = true
		}
	}
	granted := map[string]bool{}
	if !decisions && !c.serverOnly && len(disabled) > 0 {
		ids, err := (&admin.Store{DB: c.store.DB}).UserModelGrants(ctx, userID)
		if err == nil {
			for _, id := range ids {
				granted[id] = true
			}
		}
	}
	for _, model := range models {
		id, _ := model["id"].(string)
		raw, _ := model["modelId"].(string)
		blocked := disabled[id] || disabled[raw]
		grant := !decisions && blocked && (granted[id] || granted[raw])
		if blocked && !grant {
			model["available"] = false
		}
		if !decisions {
			model["adminGranted"] = grant
		}
	}
}

func (c settingsCatalogAdapter) routerForRole(ctx context.Context, userID int64, agentID, role string) *neorouterapi.Connection {
	if c.nr == nil {
		return nil
	}
	if c.serverOnly {
		conn := c.nr.ServerConnection()
		if conn.HasRole(role) {
			return conn
		}
		return nil
	}
	conn, err := c.nr.ForRole(ctx, userID, agentID, role)
	if err != nil {
		return nil
	}
	return conn
}

// listCatalog lists a provider's chat or decision models with what the vendor
// stated about them, where the provider exposes that.
func listCatalog(ctx context.Context, p llm.Provider, decisions bool) ([]llm.CatalogModel, error) {
	if decisions {
		if c, ok := p.(llm.DecisionCataloger); ok {
			return c.DecisionCatalog(ctx)
		}
		models, err := p.(llm.Decider).DecisionModels(ctx)
		return plainCatalog(models), err
	}
	if c, ok := p.(llm.Cataloger); ok {
		return c.Catalog(ctx)
	}
	models, err := p.Models(ctx)
	return plainCatalog(models), err
}

func plainCatalog(models []llm.Model) []llm.CatalogModel {
	out := make([]llm.CatalogModel, len(models))
	for i, m := range models {
		out[i] = llm.CatalogModel{Model: m}
	}
	return out
}

// providerTraits answers the model-failure rules from the provider definitions:
// an aggregator's billing failure stops only its paid models, and its rate
// limits stop only the model that hit them.
type providerTraits struct{}

func (providerTraits) IsAggregator(providerID string) bool {
	def, ok := llm.ProviderDefinitionFor(strings.ToLower(strings.TrimSpace(providerID)))
	return ok && def.Aggregator
}
