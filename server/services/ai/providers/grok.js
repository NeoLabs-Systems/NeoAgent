const OpenAI = require('openai');
const { OpenAICompatibleProvider } = require('./openaiCompatible');

class GrokProvider extends OpenAICompatibleProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'grok';
    this.client = new OpenAI({
      apiKey: config.apiKey || process.env.XAI_API_KEY,
      baseURL: config.baseUrl || process.env.XAI_BASE_URL || 'https://api.x.ai/v1'
    });
  }

  getContextWindow(model) {
    return 131072; // grok-4 context window
  }

  supportsVision() {
    return true;
  }

  getDefaultVisionModel() {
    return 'grok-4.20-beta-latest-non-reasoning';
  }

  _buildParams(model, messages, tools, options) {
    const params = {
      model,
      messages,
      max_tokens: options.maxTokens || 16384
    };

    // grok-4-1-fast-reasoning is a reasoning model: no temperature
    const isReasoning = model.includes('reasoning') || model.startsWith('grok-4');
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
    const model = options.model || 'grok-4-1-fast-reasoning';
    const params = this._buildParams(model, messages, tools, options);

    const response = await this.client.chat.completions.create(params);
    return this.normalizeResponse(response);
  }

  async *stream(messages, tools = [], options = {}) {
    const model = options.model || 'grok-4-1-fast-reasoning';
    const params = {
      ...this._buildParams(model, messages, tools, options),
      stream: true,
      stream_options: { include_usage: true }
    };

    const stream = await this.client.chat.completions.create(params);

    let toolCalls = [];
    let content = '';
    let finalUsage = null;

    for await (const chunk of stream) {
      if (chunk.usage && (!chunk.choices || chunk.choices.length === 0)) {
        finalUsage = this.normalizeUsage(chunk.usage);
        continue;
      }

      const delta = chunk.choices[0]?.delta;
      if (!delta) continue;

      if (delta.content) {
        content += delta.content;
        yield { type: 'content', content: delta.content };
      }

      if (delta.tool_calls) {
        for (const tc of delta.tool_calls) {
          if (!toolCalls[tc.index]) {
            toolCalls[tc.index] = { id: tc.id || '', type: 'function', function: { name: tc.function?.name || '', arguments: '' } };
          }
          if (tc.id) toolCalls[tc.index].id = tc.id;
          if (tc.function?.name) toolCalls[tc.index].function.name = tc.function.name;
          if (tc.function?.arguments) toolCalls[tc.index].function.arguments += tc.function.arguments;
        }
      }

      const finishReason = chunk.choices[0]?.finish_reason;
      if (finishReason === 'tool_calls' || (finishReason === 'stop' && toolCalls.length > 0)) {
        yield {
          type: 'tool_calls',
          toolCalls,
          content,
          usage: this.normalizeUsage(chunk.usage) || finalUsage
        };
        return;
      }
      if (finishReason === 'stop') {
        yield {
          type: 'done',
          content,
          usage: this.normalizeUsage(chunk.usage) || finalUsage
        };
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

module.exports = { GrokProvider };
