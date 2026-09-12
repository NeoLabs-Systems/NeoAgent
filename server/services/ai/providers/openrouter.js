const OpenAI = require('openai');
const { OpenAICompatibleProvider } = require('./openaiCompatible');
const { fetchResponseText } = require('../../network/http');
const { wrapProviderError } = require('./provider_error');

const OPENROUTER_BASE_URL = 'https://openrouter.ai/api/v1';

// Context windows fetched from the API are cached here so getContextWindow
// can serve them without a network call at inference time.
const contextWindowCache = new Map();
// Per-model reasoning metadata from the same catalog response.
const reasoningCatalog = new Map();

// Effort is only sent to models that already reason by default, and only at a
// level the catalog lists. On models where reasoning is optional (Claude via
// OpenRouter, for example) the parameter would switch thinking on, changing
// latency, cost, and sampling constraints instead of merely lowering effort.
function catalogReasoningEffort(model, requested) {
  const effort = String(requested || '').trim().toLowerCase();
  const entry = reasoningCatalog.get(model);
  if (!effort || !entry || !(entry.mandatory || entry.default_enabled)) return null;
  const supported = Array.isArray(entry.supported_efforts) ? entry.supported_efforts : null;
  return !supported || supported.includes(effort) ? effort : null;
}

class OpenRouterProvider extends OpenAICompatibleProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'openrouter';
    this.models = [];
    this.baseURL = config.baseUrl || OPENROUTER_BASE_URL;
    this.client = new OpenAI({
      apiKey: config.apiKey || process.env.OPENROUTER_API_KEY,
      baseURL: this.baseURL,
      timeout: 90_000,  // 90 s — free models can queue; avoids hanging forever
      maxRetries: 0,    // engine handles retries; avoid SDK silently re-queuing slow models
      defaultHeaders: {
        'HTTP-Referer': 'https://github.com/NeoLabs-Systems/NeoAgent',
        'X-Title': 'NeoAgent',
      },
    });
  }

  async listModels(signal = null) {
    const { response, text } = await fetchResponseText(`${this.baseURL}/models`, {
      headers: { 'Authorization': `Bearer ${this.client.apiKey}` },
      maxResponseBytes: 5 * 1024 * 1024,
      serviceName: 'OpenRouter model catalog',
      signal,
    });
    if (!response.ok) {
      const error = new Error(`OpenRouter /models returned HTTP ${response.status}`);
      error.status = response.status;
      error.headers = response.headers;
      throw error;
    }
    let payload;
    try {
      payload = JSON.parse(text || '{}');
    } catch {
      throw new Error('OpenRouter /models returned invalid JSON.');
    }
    const { data } = payload;
    const models = data || [];
    for (const m of models) {
      if (m.context_length) contextWindowCache.set(m.id, m.context_length);
      if (m.reasoning && typeof m.reasoning === 'object') reasoningCatalog.set(m.id, m.reasoning);
    }
    this.models = models.map((m) => m.id);
    return models;
  }

  getContextWindow(model) {
    return contextWindowCache.get(model) ?? 128000;
  }

  _buildParams(model, messages, tools, options) {
    const params = {
      model,
      messages,
      temperature: options.temperature ?? 0.7,
      max_tokens: options.maxTokens || 16384,
    };

    const effort = catalogReasoningEffort(model, options.reasoningEffort);
    if (effort) params.reasoning = { effort };

    if (tools && tools.length > 0) {
      params.tools = this.formatTools(tools);
      params.tool_choice = 'auto';
    }

    return params;
  }

  _extractOpenRouterError(obj) {
    if (!obj) return null;
    const e = obj.error;
    if (!e) return null;
    const msg = e.message || (typeof e === 'string' ? e : JSON.stringify(e));
    return `OpenRouter: ${msg}${e.code ? ` (code ${e.code})` : ''}`;
  }

  async chat(messages, tools = [], options = {}) {
    const model = this.requireModel(options);
    const params = this._buildParams(model, messages, tools, options);
    let response;
    try {
      response = await this.client.chat.completions.create(params, { signal: options.signal });
    } catch (err) {
      throw wrapProviderError(err, 'OpenRouter request failed', {
        signal: options.signal,
      });
    }
    // OpenRouter returns HTTP 200 even for errors (rate limits, model unavailable, etc.)
    const orErr = this._extractOpenRouterError(response);
    if (orErr) throw new Error(orErr);
    if (!response?.choices?.length) {
      throw new Error(`OpenRouter: model returned no choices (may be rate-limited or unavailable)`);
    }
    return this.normalizeResponse(response);
  }

  async *stream(messages, tools = [], options = {}) {
    const model = this.requireModel(options);
    const params = {
      ...this._buildParams(model, messages, tools, options),
      stream: true,
      stream_options: { include_usage: true },
    };

    let stream;
    try {
      stream = await this.client.chat.completions.create(params, { signal: options.signal });
    } catch (err) {
      throw wrapProviderError(err, 'OpenRouter request failed', {
        signal: options.signal,
      });
    }

    // The OpenAI SDK converts OpenRouter's SSE error events (data.error) into
    // APIErrors before yielding — so we wrap the loop to add context.
    try {
      yield* this.readStream(stream, tools);
    } catch (err) {
      throw wrapProviderError(err, 'OpenRouter stream failed', {
        signal: options.signal,
      });
    }
  }
}

module.exports = { OpenRouterProvider };
