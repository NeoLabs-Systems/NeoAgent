const OpenAI = require('openai');
const { OpenAICompatibleProvider } = require('./openaiCompatible');
const { wrapProviderError } = require('./provider_error');

class OpenAIProvider extends OpenAICompatibleProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'openai';
    this.client = new OpenAI({
      apiKey: config.apiKey || process.env.OPENAI_API_KEY,
      baseURL: config.baseUrl || process.env.OPENAI_BASE_URL || undefined,
      defaultHeaders: config.defaultHeaders || undefined
    });
  }

  async listModels(signal = null) {
    try {
      const res = await this.client.models.list({ signal });
      const DROP = /dall-e|whisper|tts|embed|moderat|realtime|audio|transcribe|search-api|-image-|babbage|davinci-002|^sora|-instruct/i;
      return res.data
        .filter((m) => !DROP.test(m.id))
        .map((m) => ({ id: m.id, name: m.id }));
    } catch (err) {
      throw wrapProviderError(err, 'Failed to list OpenAI models', { signal });
    }
  }

  isReasoningModel(model) {
    const id = String(model || '').trim().toLowerCase();
    return /^o\d/.test(id)
      || /^gpt-(?:[5-9]|\d{2,})(?:[.\-]|$)/.test(id)
      || id.includes('reasoning');
  }

  getContextWindow() {
    return 128000;
  }

  supportsVision() {
    return true;
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
    const model = this.requireModel(options);
    const params = this._buildParams(model, messages, tools, options);

    const response = await this.client.chat.completions.create(params, { signal: options.signal });
    const choice = response.choices[0];

    return {
      content: choice.message.content,
      toolCalls: choice.message.tool_calls || [],
      finishReason: choice.finish_reason,
      usage: this.normalizeUsage(response.usage),
      model: response.model
    };
  }

  async *stream(messages, tools = [], options = {}) {
    const model = this.requireModel(options);
    const params = this._buildParams(model, messages, tools, options);
    params.stream = true;
    params.stream_options = { include_usage: true };
    const stream = await this.client.chat.completions.create(params, { signal: options.signal });

    let currentToolCalls = [];
    let content = '';
    let finalUsage = null;

    for await (const chunk of stream) {
      // Final usage-only chunk (empty choices array)
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
          usage: this.normalizeUsage(chunk.usage) || finalUsage
        };
      }
    }
  }

}

module.exports = { OpenAIProvider };
