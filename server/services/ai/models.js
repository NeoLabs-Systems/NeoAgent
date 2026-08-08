'use strict';

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
const {
    createModelSelectionId,
    modelMatchesConfiguredId,
    toSelectableModel,
} = require('./model_identity');
const {
    classifyPriceTier,
    getInputCostPerM,
    refreshOllamaModels,
    refreshProviderModelList,
} = require('./model_discovery');
const { getDisabledModelIds } = require('./model_visibility');
const { fetchResponseText } = require('../network/http');
const { createAbortError, isAbortError, throwIfAborted } = require('../../utils/abort');

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

// Providers whose full model list is fetched from their API at runtime.
// grok-oauth inherits listModels() from GrokProvider and uses the same xAI endpoint.
const DYNAMIC_PROVIDERS = ['openai', 'anthropic', 'google', 'nvidia', 'grok', 'grok-oauth', 'openrouter'];

async function probeOllama(baseUrl, timeoutMs = 1500, signal = null) {
    try {
        const { response, text } = await fetchResponseText(`${baseUrl}/api/tags`, {
            method: 'GET',
            maxResponseBytes: 2 * 1024 * 1024,
            serviceName: 'Ollama health check',
            signal,
            timeoutMs,
        });
        if (!response.ok) {
            return {
                healthy: false,
                reason: `Ollama returned HTTP ${response.status}.`
            };
        }
        let data = {};
        try { data = JSON.parse(text || '{}'); } catch {}
        const modelCount = Array.isArray(data?.models) ? data.models.length : 0;
        return {
            healthy: true,
            reason: modelCount > 0
                ? `Connected to Ollama with ${modelCount} local model(s).`
                : 'Connected to Ollama, but no local models were reported.'
        };
    } catch (err) {
        if (isAbortError(err, signal)) throw createAbortError(signal);
        const reason = err?.code === 'HTTP_TIMEOUT'
            ? `Ollama did not respond within ${timeoutMs}ms.`
            : `Could not reach Ollama at ${baseUrl}.`;
        return { healthy: false, reason };
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
        // Availability is purely "can we call this provider" -- it has
        // credentials, or needs none (local Ollama). It intentionally ignores
        // `runtime.enabled`: that flag has no working UI to set on purpose,
        // it only ever comes from a hardcoded per-provider onboarding default
        // (see AI_PROVIDER_DEFINITIONS.defaultEnabled), and gating on it made
        // providers with valid, configured credentials silently unusable.
        const available = !definition.supportsApiKey || Boolean(runtime.apiKey);

        let status = 'ready';
        let statusLabel = 'Ready';
        let availabilityReason = 'Provider is available.';

        if (definition.supportsApiKey && !runtime.apiKey) {
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

async function getProviderHealthCatalog(userId, agentId = null, options = {}) {
    const providers = getProviderCatalog(userId, agentId);
    const enriched = [];

    for (const provider of providers) {
        throwIfAborted(options.signal);
        let connected = null;
        let healthy = provider.available;
        let degraded = false;
        let status = provider.status;
        let statusLabel = provider.statusLabel;
        let availabilityReason = provider.availabilityReason;

        if (provider.id === 'ollama' && provider.enabled && options.probeLocal !== false) {
            const probe = await probeOllama(
                provider.baseUrl || AI_PROVIDER_DEFINITIONS.ollama.defaultBaseUrl,
                1500,
                options.signal,
            );
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

async function getSupportedModels(userId, agentId = null, options = {}) {
    throwIfAborted(options.signal);
    const providerCatalog = options.providerCatalog
        || await getProviderHealthCatalog(userId, agentId, { signal: options.signal });
    const providerById = new Map(providerCatalog.map((provider) => [provider.id, provider]));

    const all = [...STATIC_MODELS];
    const seenModelIds = new Set(
        STATIC_MODELS.map((model) => createModelSelectionId(model.provider, model.id)),
    );

    // Ollama: dynamic list from local server
    const ollama = providerById.get('ollama');
    if (ollama?.available) {
        const dynamicModels = await refreshOllamaModels({
            baseUrl: ollama.baseUrl || AI_PROVIDER_DEFINITIONS.ollama.defaultBaseUrl,
            Provider: OllamaProvider,
            signal: options.signal,
        });
        for (const model of dynamicModels) {
            const selectionId = createModelSelectionId(model.provider, model.id);
            if (seenModelIds.has(selectionId)) continue;
            seenModelIds.add(selectionId);
            all.push(model);
        }
    }

    // API-backed providers: fetch model lists in parallel
    const dynamicFetches = DYNAMIC_PROVIDERS
        .filter((id) => providerById.get(id)?.available)
        .map(async (id) => {
            const runtime = getProviderRuntimeConfig(userId, id, agentId);
            return refreshProviderModelList({
                providerId: id,
                factory: PROVIDER_FACTORIES[id],
                apiKey: runtime.apiKey,
                baseUrl: runtime.baseUrl,
                signal: options.signal,
            });
        });

    const dynamicResults = await Promise.allSettled(dynamicFetches);
    throwIfAborted(options.signal);
    for (const result of dynamicResults) {
        if (result.status === 'fulfilled') {
            for (const model of result.value) {
                const selectionId = createModelSelectionId(model.provider, model.id);
                if (seenModelIds.has(selectionId)) continue;
                seenModelIds.add(selectionId);
                all.push(model);
            }
        }
    }

    const globalDisabledIds = getDisabledModelIds();
    const globalDisabledSet = globalDisabledIds.length ? new Set(globalDisabledIds) : null;

    // Plan-based model allowlist (billing optional feature).
    let planAllowedModels = null;
    try {
        const { isBillingEnabled } = require('../billing/config');
        if (isBillingEnabled()) {
            const { getActiveSubscription } = require('../billing/subscriptions');
            const sub = getActiveSubscription(userId);
            if (sub?.plan?.allowed_models?.length) {
                planAllowedModels = new Set(sub.plan.allowed_models);
            }
        }
    } catch {
        // Billing restrictions are non-critical.
    }

    return all.map((model) => {
        const selectableModel = toSelectableModel(model);
        const provider = providerById.get(model.provider);
        // Ollama models are always local/free; all others look up the OpenRouter
        // pricing cache (populated above by Promise.allSettled).
        const priceTier = model.provider === 'ollama'
            ? 'free'
            : (model.priceTier ?? classifyPriceTier(model.id));

        let available = provider?.available !== false;
        if (available && modelMatchesConfiguredId(selectableModel, globalDisabledSet)) {
            available = false;
        }
        if (available && planAllowedModels !== null && !modelMatchesConfiguredId(selectableModel, planAllowedModels)) {
            available = false;
        }

        const bareId = model.id.includes('/') ? model.id.slice(model.id.indexOf('/') + 1) : null;
        const inputCostPerM = model.provider === 'ollama'
            ? 0
            : (getInputCostPerM(model.id) ?? (bareId ? getInputCostPerM(bareId) : undefined) ?? null);

        return {
            ...selectableModel,
            priceTier,
            inputCostPerM,
            available,
            providerStatus: provider?.status || 'unknown',
            providerStatusLabel: provider?.statusLabel || 'Unknown'
        };
    });
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
    createProviderInstance,
    getProviderCatalog,
    getProviderHealthCatalog,
    getProviderRuntimeConfig,
    getSupportedModels
};
