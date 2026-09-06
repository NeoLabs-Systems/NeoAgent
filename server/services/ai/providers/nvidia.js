const OpenAI = require('openai');
const { OpenAICompatibleProvider } = require('./openaiCompatible');
const { wrapProviderError } = require('./provider_error');

const NVIDIA_BASE_URL = 'https://integrate.api.nvidia.com/v1';

class NvidiaProvider extends OpenAICompatibleProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'nvidia';
    this.client = new OpenAI({
      apiKey: config.apiKey || process.env.NVIDIA_API_KEY,
      baseURL: config.baseUrl || NVIDIA_BASE_URL,
    });
  }

  async listModels(signal = null) {
    try {
      const res = await this.client.models.list({ signal });
      const DROP = /embed|bge|e5-|rerank|guard|safety|moderat|diffus|flux|stable|imagen|vision-enc|whisper|tts|speech|paraphrase|classif/i;
      return res.data
        .filter((m) => !DROP.test(m.id))
        .map((m) => ({ id: m.id, name: m.id }));
    } catch (err) {
      throw wrapProviderError(err, 'NVIDIA NIM request failed', { signal });
    }
  }

  getContextWindow() {
    return 131072;
  }

  _isReasoningModel(model) {
    return /(?:^|[/_-])(?:r\d+|qwq|reasoning)(?:$|[/_.-])/i.test(String(model || ''));
  }

  _buildParams(model, messages, tools, options) {
    const params = {
      model,
      messages,
      max_tokens: options.maxTokens || 8192,
    };

    if (!this._isReasoningModel(model)) {
      params.temperature = options.temperature ?? 0.6;
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
    let response;
    try {
      response = await this.client.chat.completions.create(params, { signal: options.signal });
    } catch (err) {
      throw wrapProviderError(err, 'NVIDIA NIM request failed', {
        signal: options.signal,
      });
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
      throw wrapProviderError(err, 'NVIDIA NIM request failed', {
        signal: options.signal,
      });
    }

    let toolCalls = [];
    let content = '';
    let finalUsage = null;

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

    if (toolCalls.length > 0) {
      yield { type: 'tool_calls', toolCalls, content, usage: finalUsage };
    } else {
      yield { type: 'done', content, usage: finalUsage };
    }
  }

}

module.exports = { NvidiaProvider };
