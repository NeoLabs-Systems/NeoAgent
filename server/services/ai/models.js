const { AnthropicProvider } = require('./providers/anthropic');
const { GoogleProvider } = require('./providers/google');
const { GrokProvider } = require('./providers/grok');
const { OllamaProvider } = require('./providers/ollama');
const { OpenAIProvider } = require('./providers/openai');
const {
    AI_PROVIDER_DEFINITIONS,
    getProviderConfigs,
} = require('./settings');

const STATIC_MODELS = [
    {
        id: 'grok-4-1-fast-reasoning',
        label: 'Grok 4.1 (Personality / Default)',
        provider: 'grok',
        purpose: 'general'
    },
    {
        id: 'gpt-5-nano',
        label: 'GPT-5 Nano (Fast / Subagents)',
        provider: 'openai',
        purpose: 'fast'
    },
    {
        id: 'gpt-5-mini',
        label: 'GPT-5 Mini (Planning / Complex)',
        provider: 'openai',
        purpose: 'planning'
    },
    {
        id: 'claude-sonnet-4-20250514',
        label: 'Claude Sonnet 4 (Analysis / Writing)',
        provider: 'anthropic',
        purpose: 'planning'
    },
    {
        id: 'claude-3-5-haiku-20241022',
        label: 'Claude 3.5 Haiku (Fast)',
        provider: 'anthropic',
        purpose: 'fast'
    },
    {
        id: 'gemini-3.1-flash-lite-preview',
        label: 'Gemini 3.1 Flash Lite (Preview)',
        provider: 'google',
        purpose: 'general'
    },
    {
        id: 'qwen3.5:4b',
        label: 'Qwen 3.5 4B (Local / Ollama)',
        provider: 'ollama',
        purpose: 'general'
    }
];

const dynamicModelsByBaseUrl = new Map();
const REFRESH_INTERVAL = 30000; // 30 seconds

function getProviderRuntimeConfig(userId, providerId) {
    const definition = AI_PROVIDER_DEFINITIONS[providerId];
    if (!definition) {
        throw new Error(`Unknown provider: ${providerId}`);
    }

    const configs = getProviderConfigs(userId);
    const config = configs[providerId] || {};
    const envApiKey = definition.envKey ? (process.env[definition.envKey] || '').trim() : '';
    const storedApiKey = typeof config.apiKey === 'string' ? config.apiKey.trim() : '';
    const resolvedApiKey = storedApiKey || envApiKey;
    const baseUrl = definition.supportsBaseUrl
        ? ((typeof config.baseUrl === 'string' ? config.baseUrl.trim() : '') || definition.defaultBaseUrl || '')
        : '';

    return {
        ...definition,
        enabled: config.enabled !== false,
        apiKey: resolvedApiKey,
        storedApiKey,
        hasStoredApiKey: Boolean(storedApiKey),
        hasEnvironmentApiKey: Boolean(envApiKey),
        baseUrl
    };
}

function getProviderCatalog(userId) {
    return Object.values(AI_PROVIDER_DEFINITIONS).map((definition) => {
        const runtime = getProviderRuntimeConfig(userId, definition.id);
        const available = runtime.enabled && (!definition.supportsApiKey || Boolean(runtime.apiKey));

        let status = 'ready';
        let statusLabel = 'Ready';
        let availabilityReason = 'Provider is available.';

        if (!runtime.enabled) {
            status = 'disabled';
            statusLabel = 'Disabled';
            availabilityReason = 'Enable this provider to make its models selectable.';
        } else if (definition.supportsApiKey && !runtime.apiKey) {
            status = 'needs_key';
            statusLabel = 'Needs API key';
            availabilityReason = `Add an API key here or expose ${definition.envKey} on the server.`;
        } else if (definition.id === 'ollama') {
            status = 'local';
            statusLabel = 'Local';
            availabilityReason = 'This provider connects to your local Ollama server.';
        } else if (runtime.hasStoredApiKey) {
            status = 'stored_key';
            statusLabel = 'Saved here';
            availabilityReason = 'This provider uses credentials stored in your profile settings.';
        } else if (runtime.hasEnvironmentApiKey) {
            status = 'env_key';
            statusLabel = 'Using env';
            availabilityReason = `This provider is currently using ${definition.envKey} from the server environment.`;
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
            hasStoredApiKey: runtime.hasStoredApiKey,
            hasEnvironmentApiKey: runtime.hasEnvironmentApiKey,
            usesEnvironmentApiKey: !runtime.hasStoredApiKey && runtime.hasEnvironmentApiKey,
            baseUrl: runtime.baseUrl,
            status,
            statusLabel,
            availabilityReason
        };
    });
}

async function getSupportedModels(userId) {
    const providerCatalog = getProviderCatalog(userId);
    const providerById = new Map(providerCatalog.map((provider) => [provider.id, provider]));

    const all = [...STATIC_MODELS];
    const staticIds = new Set(STATIC_MODELS.map((model) => model.id));
    const ollama = providerById.get('ollama');

    if (ollama?.enabled) {
        const dynamicModels = await refreshDynamicModels(ollama.baseUrl);
        for (const model of dynamicModels) {
            if (!staticIds.has(model.id)) {
                all.push(model);
            }
        }
    }

    return all.map((model) => {
        const provider = providerById.get(model.provider);
        return {
            ...model,
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
            purpose: 'general'
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
    const runtime = getProviderRuntimeConfig(userId, providerStr);

    if (!runtime.enabled) {
        throw new Error(`Provider '${providerStr}' is disabled in settings.`);
    }
    if (runtime.supportsApiKey && !runtime.apiKey) {
        throw new Error(`Provider '${providerStr}' is missing an API key.`);
    }

    if (providerStr === 'grok') {
        return new GrokProvider({ apiKey: runtime.apiKey, baseUrl: runtime.baseUrl, ...configOverrides });
    } else if (providerStr === 'openai') {
        return new OpenAIProvider({ apiKey: runtime.apiKey, baseUrl: runtime.baseUrl, ...configOverrides });
    } else if (providerStr === 'anthropic') {
        return new AnthropicProvider({ apiKey: runtime.apiKey, baseUrl: runtime.baseUrl, ...configOverrides });
    } else if (providerStr === 'google') {
        return new GoogleProvider({ apiKey: runtime.apiKey, ...configOverrides });
    } else if (providerStr === 'ollama') {
        return new OllamaProvider({ baseUrl: runtime.baseUrl, ...configOverrides });
    }
    throw new Error(`Unknown provider: ${providerStr}`);
}

module.exports = {
    AI_PROVIDER_DEFINITIONS,
    SUPPORTED_MODELS: STATIC_MODELS, // Backward compatibility
    createProviderInstance,
    getProviderCatalog,
    getProviderRuntimeConfig,
    getSupportedModels
};
