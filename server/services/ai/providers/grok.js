const OpenAI = require('openai');
const { OpenAICompatibleProvider } = require('./openaiCompatible');
const { wrapProviderError } = require('./provider_error');

// Grok models that rejected reasoning_effort; requests to them go without it.
const modelsWithoutReasoningEffort = new Set();

function rejectsReasoningEffort(error) {
  return Number(error?.status) === 400 && /reasoning/i.test(String(error?.message || ''));
}

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

    // Structured helper calls (triage, memory planning, verification) run at the
    // engine's reasoning effort, as on other providers. Agent turns keep Grok's
    // own reasoning depth.
    if (options.structured && options.reasoningEffort && !modelsWithoutReasoningEffort.has(model)) {
      params.reasoning_effort = options.reasoningEffort;
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

    try {
      const response = await this.client.chat.completions.create(params, { signal: options.signal });
      return this.normalizeResponse(response);
    } catch (error) {
      if (!params.reasoning_effort || !rejectsReasoningEffort(error)) throw error;
      modelsWithoutReasoningEffort.add(model);
      const retryParams = { ...params };
      delete retryParams.reasoning_effort;
      const response = await this.client.chat.completions.create(retryParams, { signal: options.signal });
      return this.normalizeResponse(response);
    }
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
