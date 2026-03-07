const OpenAI = require('openai');
const { BaseProvider } = require('./base');

class OpenAIProvider extends BaseProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'openai';
    this.models = [
      'gpt-5',
      'gpt-5-mini',
      'gpt-5-nano',
      'gpt-5.2',
      'gpt-4.1',
      'o3',
      'o4-mini'
    ];
    // Reasoning models: no temperature, use max_completion_tokens, support reasoning_effort
    this.reasoningModels = new Set(['gpt-5', 'gpt-5-mini', 'gpt-5-nano', 'gpt-5.2', 'gpt-5.1', 'o1', 'o3', 'o4-mini', 'o3-mini']);
    this.contextWindows = {
      'gpt-5': 400000,
      'gpt-5-mini': 200000,
      'gpt-5-nano': 128000,
      'gpt-5.2': 400000,
      'gpt-5.1': 400000,
      'gpt-4.1': 1047576,
      'o3': 200000,
      'o4-mini': 200000,
      'o3-mini': 200000
    };
    this.client = new OpenAI({
      apiKey: config.apiKey || process.env.OPENAI_API_KEY
    });
  }

  isReasoningModel(model) {
    // Match exact IDs and prefix variants (gpt-5-2025-08-07 etc)
    for (const id of this.reasoningModels) {
      if (model === id || model.startsWith(id + '-')) return true;
    }
    return false;
  }

  getContextWindow(model) {
    for (const [id, size] of Object.entries(this.contextWindows)) {
      if (model === id || model.startsWith(id + '-')) return size;
    }
    return 128000;
  }

  _buildParams(model, messages, tools, options) {
    const isReasoning = this.isReasoningModel(model);
    // Reasoning models (GPT-5, o-series): use developer role for system messages
    const formattedMessages = isReasoning
      ? messages.map(m => m.role === 'system' ? { ...m, role: 'developer' } : m)
      : messages;

    const params = {
      model,
      messages: formattedMessages
    };

    if (isReasoning) {
      // max_completion_tokens (not max_tokens) for reasoning models
      params.max_completion_tokens = options.maxTokens || 16384;
      // reasoning_effort: low/medium/high (default medium for speed/quality balance)
      if (options.reasoningEffort || options.reasoning_effort) {
        params.reasoning_effort = options.reasoningEffort || options.reasoning_effort;
      }
      // No temperature for reasoning models
    } else {
      params.temperature = options.temperature ?? 0.7;
      params.max_tokens = options.maxTokens || 16384;
    }

    if (tools && tools.length > 0) {
      params.tools = this.formatTools(tools);
      params.tool_choice = options.toolChoice || 'auto';
    }

    return params;
  }

  async chat(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || this.getDefaultModel();
    const params = this._buildParams(model, messages, tools, options);

    const response = await this.client.chat.completions.create(params);
    const choice = response.choices[0];

    return {
      content: choice.message.content,
      toolCalls: choice.message.tool_calls || [],
      finishReason: choice.finish_reason,
      usage: response.usage ? {
        promptTokens: response.usage.prompt_tokens,
        completionTokens: response.usage.completion_tokens,
        totalTokens: response.usage.total_tokens
      } : null,
      model: response.model
    };
  }

  async *stream(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || this.getDefaultModel();
    const params = this._buildParams(model, messages, tools, options);
    params.stream = true;
    params.stream_options = { include_usage: true };
    const stream = await this.client.chat.completions.create(params);

    let currentToolCalls = [];
    let content = '';
    let finalUsage = null;

    for await (const chunk of stream) {
      // Final usage-only chunk (empty choices array)
      if (chunk.usage && (!chunk.choices || chunk.choices.length === 0)) {
        finalUsage = {
          promptTokens: chunk.usage.prompt_tokens,
          completionTokens: chunk.usage.completion_tokens,
          totalTokens: chunk.usage.total_tokens
        };
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
          if (tc.index !== undefined) {
            if (!currentToolCalls[tc.index]) {
              currentToolCalls[tc.index] = {
                id: tc.id || '',
                type: 'function',
                function: { name: '', arguments: '' }
              };
            }
            if (tc.id) currentToolCalls[tc.index].id = tc.id;
            if (tc.function?.name) currentToolCalls[tc.index].function.name += tc.function.name;
            if (tc.function?.arguments) currentToolCalls[tc.index].function.arguments += tc.function.arguments;
          }
        }
      }

      if (chunk.choices[0]?.finish_reason) {
        yield {
          type: 'done',
          content,
          toolCalls: currentToolCalls.filter(tc => tc.id),
          finishReason: chunk.choices[0].finish_reason,
          usage: chunk.usage ? {
            promptTokens: chunk.usage.prompt_tokens,
            completionTokens: chunk.usage.completion_tokens,
            totalTokens: chunk.usage.total_tokens
          } : finalUsage
        };
      }
    }
  }
}

module.exports = { OpenAIProvider };
