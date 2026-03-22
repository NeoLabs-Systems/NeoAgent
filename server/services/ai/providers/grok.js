const OpenAI = require('openai');
const { BaseProvider } = require('./base');

class GrokProvider extends BaseProvider {
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
    const params = { ...this._buildParams(model, messages, tools, options), stream: true };

    const stream = await this.client.chat.completions.create(params);

    let toolCalls = [];
    let content = '';

    for await (const chunk of stream) {
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
        yield { type: 'tool_calls', toolCalls, content };
        return;
      }
      if (finishReason === 'stop') {
        yield { type: 'done', content };
        return;
      }
    }

    if (toolCalls.length > 0) {
      yield { type: 'tool_calls', toolCalls, content };
    } else {
      yield { type: 'done', content };
    }
  }

  normalizeResponse(response) {
    const choice = response.choices[0];
    const msg = choice.message;
    return {
      content: msg.content || '',
      toolCalls: msg.tool_calls?.map(tc => ({
        id: tc.id,
        type: 'function',
        function: { name: tc.function.name, arguments: tc.function.arguments }
      })) || [],
      finishReason: choice.finish_reason,
      usage: response.usage
    };
  }

  formatTools(tools) {
    return tools.map(tool => ({
      type: 'function',
      function: {
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters
      }
    }));
  }
}

module.exports = { GrokProvider };
