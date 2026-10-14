const OpenAI = require('openai');
const { OpenAICompatibleProvider } = require('./openaiCompatible');
const { fetchResponseText } = require('../../network/http');
const { wrapProviderError } = require('./provider_error');
const { postSystemOneDecision } = require('./system_one_api');

const OPENROUTER_BASE_URL = 'https://openrouter.ai/api/v1';
const ATTRIBUTION_HEADERS = Object.freeze({
  'HTTP-Referer': 'https://github.com/NeoLabs-Systems/NeoAgent',
  'X-Title': 'NeoAgent',
});
// SystemOne models (Jev, Solar Decide, ...) answer typed questions instead of
// writing text. OpenRouter lists them under the `decisions` output modality
// and serves them through its System One API, never through chat completions.
const DECISION_MODALITY = 'decisions';

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
      defaultHeaders: ATTRIBUTION_HEADERS,
    });
  }

  async _fetchCatalog(query, signal) {
    const { response, text } = await fetchResponseText(`${this.baseURL}/models${query}`, {
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
    return payload.data || [];
  }

  // Chat models only: SystemOne models cannot hold a conversation.
  async listModels(signal = null) {
    const models = (await this._fetchCatalog('', signal))
      .filter((m) => !m.architecture?.output_modalities?.includes(DECISION_MODALITY));
    for (const m of models) {
      if (m.context_length) contextWindowCache.set(m.id, m.context_length);
      if (m.reasoning && typeof m.reasoning === 'object') reasoningCatalog.set(m.id, m.reasoning);
    }
    this.models = models.map((m) => m.id);
    return models;
  }

  async listDecisionModels(signal = null) {
    return this._fetchCatalog(`?output_modalities=${DECISION_MODALITY}`, signal);
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

    // Routers such as typesafe/jev-router keep a working model for a session
    // and only switch when the gain outweighs the lost prompt cache. Without a
    // session id every turn is routed from scratch and can change model mid-run.
    if (options.sessionId) params.session_id = String(options.sessionId);

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

  async decide({ model, state, questions, signal = null, timeoutMs } = {}) {
    return postSystemOneDecision(`${this.baseURL}/systemone`, {
      headers: { ...ATTRIBUTION_HEADERS, Authorization: `Bearer ${this.client.apiKey}` },
      model,
      state,
      questions,
      signal,
      timeoutMs,
    });
  }
}

module.exports = { OpenRouterProvider };
