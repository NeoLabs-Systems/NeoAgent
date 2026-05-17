const { AnthropicProvider } = require('./providers/anthropic');
const { GoogleProvider } = require('./providers/google');
const { GrokProvider } = require('./providers/grok');
const { OllamaProvider } = require('./providers/ollama');
const { OpenAIProvider } = require('./providers/openai');
const { GithubCopilotProvider } = require('./providers/githubCopilot');
const { OpenAICodexProvider } = require('./providers/openaiCodex');
const { ClaudeCodeProvider } = require('./providers/claudeCode');
const {
    AI_PROVIDER_DEFINITIONS,
    getProviderConfigs,
    getProviderSecrets,
} = require('./settings');

const STATIC_MODELS = [
    {
        id: 'grok-4-1-fast-reasoning',
        label: 'Grok 4.1 (Personality / Default)',
        provider: 'grok',
        purpose: 'general'
    },
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
    {
        id: 'gemini-3.1-flash-lite-preview',
        label: 'Gemini 3.1 Flash Lite (Preview)',
        provider: 'google',
        purpose: 'general'
    },
    {
        id: 'MiniMax-M2.7',
        label: 'MiniMax M2.7 (Coding Plan)',
        provider: 'minimax',
        purpose: 'coding'
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
    const { agentId = null, ...providerOverrides } = configOverrides || {};
    const runtime = getProviderRuntimeConfig(userId, providerStr, agentId);

    if (!runtime.enabled) {
        throw new Error(`Provider '${providerStr}' is disabled in settings.`);
    }
    if (runtime.supportsApiKey && !runtime.apiKey) {
        throw new Error(`Provider '${providerStr}' is not configured on this deployment.`);
    }

    if (providerStr === 'grok') {
        return new GrokProvider({ apiKey: runtime.apiKey, baseUrl: runtime.baseUrl, ...providerOverrides });
    } else if (providerStr === 'openai') {
        return new OpenAIProvider({ apiKey: runtime.apiKey, baseUrl: runtime.baseUrl, ...providerOverrides });
    } else if (providerStr === 'anthropic') {
        return new AnthropicProvider({ apiKey: runtime.apiKey, baseUrl: runtime.baseUrl, ...providerOverrides });
    } else if (providerStr === 'google') {
        return new GoogleProvider({ apiKey: runtime.apiKey, ...providerOverrides });
    } else if (providerStr === 'minimax') {
        return new AnthropicProvider({ apiKey: runtime.apiKey, baseUrl: runtime.baseUrl, ...providerOverrides });
    } else if (providerStr === 'ollama') {
        return new OllamaProvider({ baseUrl: runtime.baseUrl, ...providerOverrides });
    } else if (providerStr === 'github-copilot') {
        return new GithubCopilotProvider({ apiKey: runtime.apiKey, ...providerOverrides });
    } else if (providerStr === 'openai-codex') {
        return new OpenAICodexProvider({ apiKey: runtime.apiKey, ...providerOverrides });
    } else if (providerStr === 'claude-code') {
        return new ClaudeCodeProvider({ apiKey: runtime.apiKey, ...providerOverrides });
    }
    throw new Error(`Unknown provider: ${providerStr}`);
}

module.exports = {
    AI_PROVIDER_DEFINITIONS,
    SUPPORTED_MODELS: STATIC_MODELS, // Backward compatibility
    createProviderInstance,
    getProviderCatalog,
    getProviderHealthCatalog,
    getProviderRuntimeConfig,
    getSupportedModels
};
