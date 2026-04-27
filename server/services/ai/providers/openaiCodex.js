const { OpenAIProvider } = require('./openai');

class OpenAICodexProvider extends OpenAIProvider {
  constructor(config = {}) {
    const officialBaseUrl = 'https://api.openai.com/v1';
    const baseUrl = config.baseUrl || process.env.OPENAI_CODEX_BASE_URL || 'https://chatgpt.com/backend-api/codex';
    
    if (!baseUrl.includes('api.openai.com') && !baseUrl.includes('chatgpt.com')) {
      console.warn(`[OpenAICodex] Using non-official base URL: ${baseUrl}`);
    } else if (baseUrl.includes('chatgpt.com')) {
      console.info(`[OpenAICodex] Using ChatGPT subscription endpoint: ${baseUrl}`);
    }

    super({
      ...config,
      apiKey: config.apiKey || process.env.OPENAI_CODEX_ACCESS_TOKEN,
      baseUrl
    });
    this.name = 'openai-codex';
  }

  // OpenAI Codex (subscription-based) uses the OAuth token directly as the API key.
  // The base URL routes it through the ChatGPT backend-api.
}

module.exports = { OpenAICodexProvider };
