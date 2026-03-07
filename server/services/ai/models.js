const { GrokProvider } = require('./providers/grok');
const { OpenAIProvider } = require('./providers/openai');

const SUPPORTED_MODELS = [
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
    }
];

function createProviderInstance(providerStr) {
    if (providerStr === 'grok') {
        return new GrokProvider({ apiKey: process.env.XAI_API_KEY });
    } else if (providerStr === 'openai') {
        return new OpenAIProvider({ apiKey: process.env.OPENAI_API_KEY });
    }
    throw new Error(`Unknown provider: ${providerStr}`);
}

module.exports = {
    SUPPORTED_MODELS,
    createProviderInstance
};
