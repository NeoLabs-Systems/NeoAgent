const OpenAI = require('openai');
const { OpenAICompatibleProvider } = require('./openaiCompatible');
const { wrapProviderError } = require('./provider_error');

class GrokProvider extends OpenAICompatibleProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'grok';
    this.client = new OpenAI({
      apiKey: config.apiKey || process.env.XAI_API_KEY,
      baseURL: config.baseUrl || process.env.XAI_BASE_URL || 'https://api.x.ai/v1'
    });
  }

  async listModels(signal = null) {
    try {
      const res = await this.client.models.list({ signal });
      const DROP = /imagine|diffus|embed|-tts/i;
      return res.data
        .filter((m) => !DROP.test(m.id))
        .map((m) => ({ id: m.id, name: m.id }));
    } catch (err) {
      throw wrapProviderError(err, 'Failed to list Grok models', { signal });
    }
  }

  getContextWindow() {
    return 131072;
  }

  supportsVision() {
    return true;
  }

  _buildParams(model, messages, tools, options) {
    const params = {
      model,
      messages,
      max_tokens: options.maxTokens || 16384
    };

    const isReasoning = model.includes('reasoning');
    if (!isReasoning) {
      params.temperature = options.temperature ?? 0.9;
    }

    if (tools && tools.length > 0) {
      params.tools = this.formatTools(tools);
      params.tool_choice = 'auto';
    }

    return params;
  }

  async chat(messages, tools = [], options = {}) {
    const model = this.requireModel(options);
    const params = this._buildParams(model, messages, tools, options);

    const response = await this.client.chat.completions.create(params, { signal: options.signal });
    return this.normalizeResponse(response);
  }

  async *stream(messages, tools = [], options = {}) {
    const model = this.requireModel(options);
    const params = {
      ...this._buildParams(model, messages, tools, options),
      stream: true,
      stream_options: { include_usage: true }
    };

    const stream = await this.client.chat.completions.create(params, { signal: options.signal });
    yield* this.readStream(stream, tools);
  }

}

module.exports = { GrokProvider };
