const OpenAI = require('openai');
const { OpenAICompatibleProvider } = require('./openaiCompatible');

const OPENROUTER_BASE_URL = 'https://openrouter.ai/api/v1';

// Context windows fetched from the API are cached here so getContextWindow
// can serve them without a network call at inference time.
const contextWindowCache = new Map();

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

  async listModels() {
    const res = await fetch(`${this.baseURL}/models`, {
      headers: { 'Authorization': `Bearer ${this.client.apiKey}` },
    });
    if (!res.ok) throw new Error(`OpenRouter /models returned HTTP ${res.status}`);
    const { data } = await res.json();
    const models = data || [];
    for (const m of models) {
      if (m.context_length) contextWindowCache.set(m.id, m.context_length);
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
    const model = options.model || this.getDefaultModel();
    const params = this._buildParams(model, messages, tools, options);
    let response;
    try {
      response = await this.client.chat.completions.create(params);
    } catch (err) {
      throw new Error(`OpenRouter request failed: ${err?.message || String(err)}`);
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
    const model = options.model || this.getDefaultModel();
    const params = {
      ...this._buildParams(model, messages, tools, options),
      stream: true,
      stream_options: { include_usage: true },
    };

    let stream;
    try {
      stream = await this.client.chat.completions.create(params);
    } catch (err) {
      throw new Error(`OpenRouter request failed: ${err?.message || String(err)}`);
    }

    let toolCalls = [];
    let content = '';
    let finalUsage = null;

    // The OpenAI SDK converts OpenRouter's SSE error events (data.error) into
    // APIErrors before yielding — so we wrap the loop to add context.
    try {
    for await (const chunk of stream) {
      if (chunk.usage && (!chunk.choices || chunk.choices.length === 0)) {
        finalUsage = this.normalizeUsage(chunk.usage);
        continue;
      }

      const delta = chunk.choices?.[0]?.delta;
      if (!delta) continue;

      if (delta.content) {
        content += delta.content;
        yield { type: 'content', content: delta.content };
      }

      if (delta.tool_calls) {
        for (const tc of delta.tool_calls) {
          if (!toolCalls[tc.index]) {
            toolCalls[tc.index] = {
              id: tc.id || '',
              type: 'function',
              function: { name: tc.function?.name || '', arguments: '' },
            };
          }
          if (tc.id) toolCalls[tc.index].id = tc.id;
          if (tc.function?.name) toolCalls[tc.index].function.name = tc.function.name;
          if (tc.function?.arguments) toolCalls[tc.index].function.arguments += tc.function.arguments;
        }
      }

      const finishReason = chunk.choices[0]?.finish_reason;
      if (finishReason === 'tool_calls' || (finishReason === 'stop' && toolCalls.length > 0)) {
        yield { type: 'tool_calls', toolCalls, content, usage: this.normalizeUsage(chunk.usage) || finalUsage };
        return;
      }
      if (finishReason === 'stop') {
        yield { type: 'done', content, usage: this.normalizeUsage(chunk.usage) || finalUsage };
        return;
      }
    }
    } catch (err) {
      // Re-throw SDK APIErrors (from OpenRouter SSE error events) with OpenRouter context.
      throw new Error(`OpenRouter: ${err?.message || String(err)}`);
    }

    if (toolCalls.length > 0) {
      yield { type: 'tool_calls', toolCalls, content, usage: finalUsage };
    } else {
      yield { type: 'done', content, usage: finalUsage };
    }
  }
}

module.exports = { OpenRouterProvider };
