const { GrokProvider } = require('./providers/grok');
const { OpenAIProvider } = require('./providers/openai');
const { GoogleProvider } = require('./providers/google');
const { OllamaProvider } = require('./providers/ollama');

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

let dynamicModels = [];
let lastRefresh = 0;
const REFRESH_INTERVAL = 30000; // 30 seconds

async function getSupportedModels() {
    const now = Date.now();
    if (now - lastRefresh > REFRESH_INTERVAL) {
        await refreshDynamicModels();
    }

    const all = [...STATIC_MODELS];
    const staticIds = new Set(STATIC_MODELS.map(m => m.id));

    for (const dm of dynamicModels) {
        if (!staticIds.has(dm.id)) {
            all.push(dm);
        }
    }

    return all;
}

async function refreshDynamicModels() {
    try {
        const ollama = new OllamaProvider({ baseUrl: process.env.OLLAMA_URL });
        const models = await ollama.listModels();

        dynamicModels = models.map(name => ({
            id: name,
            label: `${name} (Ollama / Local)`,
            provider: 'ollama',
            purpose: 'general'
        }));

        lastRefresh = Date.now();
    } catch (err) {
        console.warn('[Models] Failed to refresh Ollama models:', err.message);
    }
}

function createProviderInstance(providerStr) {
    if (providerStr === 'grok') {
        return new GrokProvider({ apiKey: process.env.XAI_API_KEY });
    } else if (providerStr === 'openai') {
        return new OpenAIProvider({ apiKey: process.env.OPENAI_API_KEY });
    } else if (providerStr === 'google') {
        return new GoogleProvider({ apiKey: process.env.GOOGLE_AI_KEY });
    } else if (providerStr === 'ollama') {
        return new OllamaProvider({ baseUrl: process.env.OLLAMA_URL });
    }
    throw new Error(`Unknown provider: ${providerStr}`);
}

module.exports = {
    SUPPORTED_MODELS: STATIC_MODELS, // Backward compatibility
    getSupportedModels,
    createProviderInstance
};
