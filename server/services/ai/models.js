const { AnthropicProvider } = require('./providers/anthropic');
const { GoogleProvider } = require('./providers/google');
const { GrokProvider } = require('./providers/grok');
const { OllamaProvider } = require('./providers/ollama');
const { OpenAIProvider } = require('./providers/openai');
const { GithubCopilotProvider } = require('./providers/githubCopilot');
const { OpenAICodexProvider } = require('./providers/openaiCodex');
const { ClaudeCodeProvider } = require('./providers/claudeCode');
const { GrokOAuthProvider } = require('./providers/grokOauth');
const { NvidiaProvider } = require('./providers/nvidia');
const { OpenRouterProvider } = require('./providers/openrouter');
const {
    AI_PROVIDER_DEFINITIONS,
    getProviderConfigs,
    getProviderSecrets,
} = require('./settings');

const STATIC_MODELS = [
    // — xAI OAuth — fallback entries shown when grok-oauth token is invalid/exhausted.
    // When the token is valid, DYNAMIC_PROVIDERS will replace these with the live list.
    {
        id: 'grok-4',
        label: 'Grok 4 (xAI OAuth)',
        provider: 'grok-oauth',
        purpose: 'general',
    },
    {
        id: 'grok-4-mini',
        label: 'Grok 4 Mini (xAI OAuth)',
        provider: 'grok-oauth',
        purpose: 'fast',
    },
    // — GitHub Copilot (subscription; no public /models endpoint) ————————
    {
        id: 'gpt-5.3',
        label: 'GPT-5.3 (Copilot Default)',
        provider: 'github-copilot',
        purpose: 'general'
    },
    {
        id: 'gpt-4.1',
        label: 'GPT-4.1 (Copilot Fast)',
        provider: 'github-copilot',
        purpose: 'coding'
    },
    // — OpenAI Codex ——————————————————————————————————————————————————————
    {
        id: 'gpt-5.5',
        label: 'GPT-5.5 (Codex Default)',
        provider: 'openai-codex',
        purpose: 'general'
    },
    {
        id: 'gpt-5.4-mini',
        label: 'GPT-5.4 mini (Codex Fast)',
        provider: 'openai-codex',
        purpose: 'coding'
    },
    {
        id: 'gpt-5.4',
        label: 'GPT-5.4 (Codex Fallback)',
        provider: 'openai-codex',
        purpose: 'general'
    },
    // — Claude Code ————————————————————————————————————————————————————————
    {
        id: 'claude-opus-4-8',
        label: 'Claude Opus 4.8 (Claude Code / Flagship)',
        provider: 'claude-code',
        purpose: 'general'
    },
    {
        id: 'claude-opus-4-7',
        label: 'Claude Opus 4.7 (Claude Code / Default)',
        provider: 'claude-code',
        purpose: 'general'
    },
    {
        id: 'claude-sonnet-4-6',
        label: 'Claude Sonnet 4.6 (Claude Code / Fast)',
        provider: 'claude-code',
        purpose: 'coding'
    },
    {
        id: 'claude-haiku-4-5-20251001',
        label: 'Claude Haiku 4.5 (Claude Code / Subagents)',
        provider: 'claude-code',
        purpose: 'fast'
    },
    // — MiniMax ————————————————————————————————————————————————————————————
    {
        id: 'MiniMax-M2.7',
        label: 'MiniMax M2.7 (Coding Plan)',
        provider: 'minimax',
        purpose: 'coding'
    },
    // — Ollama — default suggestions (full list loaded dynamically) ————————
    {
        id: 'qwen3.5:4b',
        label: 'Qwen 3.5 4B (Local / Ollama)',
        provider: 'ollama',
        purpose: 'general',
    },
    {
        id: 'gemma4:12b',
        label: 'Gemma 4 12B (Local / Ollama)',
        provider: 'ollama',
        purpose: 'general',
    }
];

// Maps a provider id to its class and which runtime fields its constructor takes.
// Adding a provider is a one-line entry here instead of another dispatch branch.
// `apiKey`/`baseUrl` mirror exactly what each constructor was historically given;
// they intentionally do not derive from AI_PROVIDER_DEFINITIONS.supportsBaseUrl,
// which disagrees for github-copilot/openai-codex (those read their base URL from
// env, not from per-user config).
const PROVIDER_FACTORIES = Object.freeze({
    grok: { Provider: GrokProvider, apiKey: true, baseUrl: true },
    openai: { Provider: OpenAIProvider, apiKey: true, baseUrl: true },
    anthropic: { Provider: AnthropicProvider, apiKey: true, baseUrl: true },
    google: { Provider: GoogleProvider, apiKey: true, baseUrl: false },
    minimax: { Provider: AnthropicProvider, apiKey: true, baseUrl: true },
    ollama: { Provider: OllamaProvider, apiKey: false, baseUrl: true },
    'github-copilot': { Provider: GithubCopilotProvider, apiKey: true, baseUrl: false },
    'openai-codex': { Provider: OpenAICodexProvider, apiKey: true, baseUrl: false },
    'claude-code': { Provider: ClaudeCodeProvider, apiKey: true, baseUrl: false },
    'grok-oauth': { Provider: GrokOAuthProvider, apiKey: true, baseUrl: false },
    nvidia: { Provider: NvidiaProvider, apiKey: true, baseUrl: true },
    openrouter: { Provider: OpenRouterProvider, apiKey: true, baseUrl: true },
});

const dynamicModelsByBaseUrl = new Map();
const REFRESH_INTERVAL = 30000; // 30 seconds

// Unified dynamic model cache for all API-backed providers.
// Keyed by `${providerId}:${apiKey.slice(0,8)}` to handle per-user keys.
const providerModelCache = new Map();
const DYNAMIC_REFRESH_INTERVAL = 5 * 60 * 1000; // 5 minutes

// Populated from OpenRouter's /models response; used to price-classify models
// from all providers.  Keyed by both the full OpenRouter ID ("openai/gpt-5-mini")
// and the bare model ID ("gpt-5-mini") for cross-provider lookup.
const openrouterPricingCache = new Map();

// Providers whose full model list is fetched from their API at runtime.
// grok-oauth inherits listModels() from GrokProvider and uses the same xAI endpoint.
const DYNAMIC_PROVIDERS = ['openai', 'anthropic', 'google', 'nvidia', 'grok', 'grok-oauth', 'openrouter'];

function inferModelPurpose(id) {
    const s = id.toLowerCase();
    if (/flash|nano|lite|tiny|haiku|scout|mini(?!max)|small/.test(s)) return 'fast';
    if (/r1|qwq|o[0-9]|reasoning|thinking/.test(s)) return 'planning';
    if (/code|coder|starcoder|devstral|codex|codegemma/.test(s)) return 'coding';
    return 'general';
}

// Pricing tiers: free=$0  cheap<$0.50/1M  medium=$0.50–$5/1M  expensive>$5/1M
// Uses live prices from openrouterPricingCache; returns null when unknown.
function classifyPriceTier(modelId) {
    const costPerM = openrouterPricingCache.get(modelId);
    if (costPerM === undefined) return null;
    if (costPerM === 0) return 'free';
    if (costPerM < 0.5) return 'cheap';
    if (costPerM < 5) return 'medium';
    return 'expensive';
}

// Per-provider functions that turn a raw model object from listModels() into a display label.
const PROVIDER_LABEL_FN = {
    openai:    (m) => `${m.id} (OpenAI)`,
    anthropic: (m) => `${m.name || m.id} (Anthropic)`,
    google:    (m) => `${m.name || m.id} (Google)`,
    nvidia:    (m) => `${m.id} (NVIDIA NIM)`,
    grok:      (m) => `${m.id} (xAI)`,
    openrouter:(m) => `${m.name || m.id} (OpenRouter)`,
};

async function refreshProviderModelList(providerId, apiKey, baseUrl) {
    const cacheKey = `${providerId}:${(apiKey || '').slice(0, 8)}`;
    const existing = providerModelCache.get(cacheKey);
    const now = Date.now();

    if (existing && now - existing.lastRefresh <= DYNAMIC_REFRESH_INTERVAL) {
        return existing.models;
    }

    try {
        const factory = PROVIDER_FACTORIES[providerId];
        const config = {};
        if (factory.apiKey) config.apiKey = apiKey;
        if (factory.baseUrl) config.baseUrl = baseUrl;
        const provider = new factory.Provider(config);

        const raw = await provider.listModels();

        // OpenRouter returns live pricing — populate the shared cache so all
        // other providers can resolve their price tier without a lookup table.
        if (providerId === 'openrouter') {
            for (const m of raw) {
                if (m.pricing?.prompt == null) continue;
                const inputPerM = parseFloat(m.pricing.prompt) * 1_000_000;
                openrouterPricingCache.set(m.id, inputPerM);
                // Also index by the bare model ID (everything after the first "/")
                // so that e.g. "gpt-5-mini" resolves from "openai/gpt-5-mini".
                if (m.id.includes('/')) {
                    const bareId = m.id.slice(m.id.indexOf('/') + 1);
                    if (!openrouterPricingCache.has(bareId)) {
                        openrouterPricingCache.set(bareId, inputPerM);
                    }
                }
            }
        }

        const labelFn = PROVIDER_LABEL_FN[providerId] || ((m) => m.id);
        const models = raw.map((m) => ({
            id: m.id,
            label: labelFn(m),
            provider: providerId,
            purpose: inferModelPurpose(m.id),
        }));

        providerModelCache.set(cacheKey, { models, lastRefresh: now });
        return models;
    } catch (err) {
        console.warn(`[Models] Failed to refresh ${providerId} models:`, err.message);
        // Always record a lastRefresh so we don't hammer the API on every request.
        // Permanent errors (auth/billing/credits) get a longer backoff.
        const isPermanent = /401|403|unauthorized|forbidden|credits|spending/i.test(err.message);
        const backoff = isPermanent ? 30 * 60 * 1000 : DYNAMIC_REFRESH_INTERVAL;
        providerModelCache.set(cacheKey, {
            models: existing?.models || [],
            lastRefresh: now - DYNAMIC_REFRESH_INTERVAL + backoff,
        });
        return existing?.models || [];
    }
}

async function probeOllama(baseUrl, timeoutMs = 1500) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
        const res = await fetch(`${baseUrl}/api/tags`, {
            method: 'GET',
            signal: controller.signal
        });
        if (!res.ok) {
            return {
                healthy: false,
                reason: `Ollama returned HTTP ${res.status}.`
            };
        }
        const data = await res.json().catch(() => ({}));
        const modelCount = Array.isArray(data?.models) ? data.models.length : 0;
        return {
            healthy: true,
            reason: modelCount > 0
                ? `Connected to Ollama with ${modelCount} local model(s).`
                : 'Connected to Ollama, but no local models were reported.'
        };
    } catch (err) {
        const reason = err?.name === 'AbortError'
            ? `Ollama did not respond within ${timeoutMs}ms.`
            : `Could not reach Ollama at ${baseUrl}.`;
        return { healthy: false, reason };
    } finally {
        clearTimeout(timer);
    }
}

function getProviderRuntimeConfig(userId, providerId, agentId = null) {
    const definition = AI_PROVIDER_DEFINITIONS[providerId];
    if (!definition) {
        throw new Error(`Unknown provider: ${providerId}`);
    }

    const configs = getProviderConfigs(userId, agentId);
    const secrets = getProviderSecrets(userId, agentId);
    const config = configs[providerId] || {};
    const envApiKey = definition.envKey ? (process.env[definition.envKey] || '').trim() : '';
    const scopedApiKey = typeof secrets[providerId] === 'string' ? secrets[providerId].trim() : '';
    const baseUrl = definition.supportsBaseUrl
        ? ((typeof config.baseUrl === 'string' ? config.baseUrl.trim() : '') || definition.defaultBaseUrl || '')
        : '';

    return {
        ...definition,
        enabled: config.enabled !== false,
        apiKey: scopedApiKey || envApiKey,
        credentialConfigured: Boolean(scopedApiKey || envApiKey),
        baseUrl
    };
}

function getProviderCatalog(userId, agentId = null) {
    return Object.values(AI_PROVIDER_DEFINITIONS).map((definition) => {
        const runtime = getProviderRuntimeConfig(userId, definition.id, agentId);
        const available = runtime.enabled && (!definition.supportsApiKey || Boolean(runtime.apiKey));

        let status = 'ready';
        let statusLabel = 'Ready';
        let availabilityReason = 'Provider is available.';

        if (!runtime.enabled) {
            status = 'disabled';
            statusLabel = 'Disabled';
            availabilityReason = 'Enable this provider to make its models selectable.';
        } else if (definition.supportsApiKey && !runtime.apiKey) {
            status = 'needs_setup';
            statusLabel = 'Setup Needed';
            availabilityReason = 'Credentials for this provider are not available on this deployment yet.';
        } else if (definition.id === 'ollama') {
            status = 'local';
            statusLabel = 'Local';
            availabilityReason = 'This provider connects to your local Ollama server.';
        } else if (runtime.credentialConfigured) {
            status = 'configured';
            statusLabel = 'Configured';
            availabilityReason = 'Credentials for this provider are available to the runtime.';
        }

        return {
            id: definition.id,
            label: definition.label,
            description: definition.description,
            supportsApiKey: definition.supportsApiKey,
            supportsBaseUrl: definition.supportsBaseUrl,
            defaultBaseUrl: definition.defaultBaseUrl,
            enabled: runtime.enabled,
            available,
            credentialConfigured: runtime.credentialConfigured,
            baseUrl: runtime.baseUrl,
            status,
            statusLabel,
            availabilityReason
        };
    });
}

async function getProviderHealthCatalog(userId, agentId = null) {
    const providers = getProviderCatalog(userId, agentId);
    const enriched = [];

    for (const provider of providers) {
        let connected = null;
        let healthy = provider.available;
        let degraded = false;
        let status = provider.status;
        let statusLabel = provider.statusLabel;
        let availabilityReason = provider.availabilityReason;

        if (provider.id === 'ollama' && provider.enabled) {
            const probe = await probeOllama(provider.baseUrl || AI_PROVIDER_DEFINITIONS.ollama.defaultBaseUrl);
            connected = probe.healthy;
            healthy = provider.enabled && probe.healthy;
            degraded = provider.enabled && !probe.healthy;
            if (!probe.healthy) {
                status = 'offline';
                statusLabel = 'Offline';
                availabilityReason = probe.reason;
            } else if (provider.available) {
                status = 'healthy';
                statusLabel = 'Healthy';
                availabilityReason = probe.reason;
            }
        } else if (provider.available) {
            connected = true;
            healthy = true;
            status = provider.status === 'configured'
                ? 'healthy'
                : provider.status;
            statusLabel = provider.status === 'configured'
                ? 'Healthy'
                : provider.statusLabel;
        } else {
            connected = false;
            healthy = false;
        }

        enriched.push({
            ...provider,
            available: healthy,
            connected,
            configured: provider.enabled && (!provider.supportsApiKey || provider.credentialConfigured || provider.id === 'ollama'),
            healthy,
            degraded,
            status,
            statusLabel,
            availabilityReason,
        });
    }

    return enriched;
}

async function getSupportedModels(userId, agentId = null) {
    const providerCatalog = await getProviderHealthCatalog(userId, agentId);
    const providerById = new Map(providerCatalog.map((provider) => [provider.id, provider]));

    const all = [...STATIC_MODELS];
    const staticIds = new Set(STATIC_MODELS.map((model) => model.id));

    // Ollama: dynamic list from local server
    const ollama = providerById.get('ollama');
    if (ollama?.enabled) {
        const dynamicModels = await refreshDynamicModels(ollama.baseUrl);
        for (const model of dynamicModels) {
            if (!staticIds.has(model.id)) {
                all.push(model);
            }
        }
    }

    // API-backed providers: fetch model lists in parallel
    const dynamicFetches = DYNAMIC_PROVIDERS
        .filter((id) => providerById.get(id)?.available)
        .map(async (id) => {
            const runtime = getProviderRuntimeConfig(userId, id, agentId);
            return refreshProviderModelList(id, runtime.apiKey, runtime.baseUrl);
        });

    const dynamicResults = await Promise.allSettled(dynamicFetches);
    for (const result of dynamicResults) {
        if (result.status === 'fulfilled') {
            for (const model of result.value) {
                if (!staticIds.has(model.id)) {
                    all.push(model);
                }
            }
        }
    }

    return all.map((model) => {
        const provider = providerById.get(model.provider);
        // Ollama models are always local/free; all others look up the OpenRouter
        // pricing cache (populated above by Promise.allSettled).
        const priceTier = model.provider === 'ollama'
            ? 'free'
            : (model.priceTier ?? classifyPriceTier(model.id));
        return {
            ...model,
            priceTier,
            available: provider?.available !== false,
            providerStatus: provider?.status || 'unknown',
            providerStatusLabel: provider?.statusLabel || 'Unknown'
        };
    });
}

async function refreshDynamicModels(baseUrl) {
    const cacheKey = baseUrl || AI_PROVIDER_DEFINITIONS.ollama.defaultBaseUrl;
    const existing = dynamicModelsByBaseUrl.get(cacheKey);
    const now = Date.now();

    if (existing && now - existing.lastRefresh <= REFRESH_INTERVAL) {
        return existing.models;
    }

    try {
        const ollama = new OllamaProvider({ baseUrl: cacheKey });
        const models = await ollama.listModels();
        const normalized = models.map((name) => ({
            id: name,
            label: `${name} (Ollama / Local)`,
            provider: 'ollama',
            purpose: 'general',
        }));

        dynamicModelsByBaseUrl.set(cacheKey, {
            models: normalized,
            lastRefresh: now
        });
        return normalized;
    } catch (err) {
        console.warn('[Models] Failed to refresh Ollama models:', err.message);
        const cached = dynamicModelsByBaseUrl.get(cacheKey);
        return cached?.models || [];
    }
}

function createProviderInstance(providerStr, userId = null, configOverrides = {}) {
    const factory = PROVIDER_FACTORIES[providerStr];
    if (!factory) {
        throw new Error(`Unknown provider: ${providerStr}`);
    }

    const { agentId = null, ...providerOverrides } = configOverrides || {};
    const runtime = getProviderRuntimeConfig(userId, providerStr, agentId);

    if (!runtime.enabled) {
        throw new Error(`Provider '${providerStr}' is disabled in settings.`);
    }
    if (runtime.supportsApiKey && !runtime.apiKey) {
        throw new Error(`Provider '${providerStr}' is not configured on this deployment.`);
    }

    const config = {};
    if (factory.apiKey) config.apiKey = runtime.apiKey;
    if (factory.baseUrl) config.baseUrl = runtime.baseUrl;

    return new factory.Provider({ ...config, ...providerOverrides });
}

module.exports = {
    AI_PROVIDER_DEFINITIONS,
    PROVIDER_FACTORIES,
    SUPPORTED_MODELS: STATIC_MODELS, // Backward compatibility
    createProviderInstance,
    getProviderCatalog,
    getProviderHealthCatalog,
    getProviderRuntimeConfig,
    getSupportedModels
};
