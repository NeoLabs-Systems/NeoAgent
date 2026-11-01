'use strict';

const { CustomOpenAIProvider } = require('./openai_compatible_custom');

const NOUS_BASE_URL = 'https://inference-api.nousresearch.com/v1';

// Nous Portal, the inference service behind Hermes Agent, speaks the OpenAI
// API. Its list also carries batch-only variants, which cannot chat.
class NousProvider extends CustomOpenAIProvider {
  constructor(config = {}) {
    super({
      ...config,
      apiKey: config.apiKey || process.env.NOUS_API_KEY,
      baseUrl: config.baseUrl || NOUS_BASE_URL,
    });
    this.name = 'nous';
  }

  async listModels(signal = null) {
    const models = (await super.listModels(signal)).filter((model) => !model.id.endsWith(':batch'));
    this.models = models.map((model) => model.id);
    return models;
  }
}

module.exports = { NOUS_BASE_URL, NousProvider };
