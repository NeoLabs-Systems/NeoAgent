'use strict';

const OpenAI = require('openai');
const { OpenAICompatibleProvider } = require('./openaiCompatible');
const { wrapProviderError } = require('./provider_error');

class CustomOpenAIProvider extends OpenAICompatibleProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'openai-compatible';
    this.baseURL = config.baseUrl || process.env.OPENAI_COMPATIBLE_BASE_URL || '';
    this.client = new OpenAI({
      apiKey: config.apiKey || process.env.OPENAI_COMPATIBLE_API_KEY,
      baseURL: this.baseURL,
    });
  }

  async listModels(signal = null) {
    try {
      const response = await this.client.models.list({ signal });
      const models = Array.isArray(response?.data) ? response.data : [];
      this.models = models
        .map((model) => String(model?.id || '').trim())
        .filter(Boolean);
      return this.models.map((id) => ({ id, name: id }));
    } catch (error) {
      throw wrapProviderError(error, 'Failed to list custom OpenAI-compatible models', {
        signal,
      });
    }
  }

  _buildParams(model, messages, tools, options) {
    const params = {
      model,
      messages,
      max_tokens: options.maxTokens || 16384,
    };

    if (options.temperature != null) {
      params.temperature = options.temperature;
    }

    if (tools && tools.length > 0) {
      params.tools = this.formatTools(tools);
      params.tool_choice = options.toolChoice || 'auto';
    }

    return params;
  }

  async chat(messages, tools = [], options = {}) {
    const model = options.model || this.getDefaultModel();
    try {
      const response = await this.client.chat.completions.create(
        this._buildParams(model, messages, tools, options),
        { signal: options.signal },
      );
      return this.normalizeResponse(response);
    } catch (error) {
      throw wrapProviderError(error, 'Custom OpenAI-compatible request failed', {
        signal: options.signal,
      });
    }
  }

  async *stream(messages, tools = [], options = {}) {
    const model = options.model || this.getDefaultModel();
    let stream;
    try {
      stream = await this.client.chat.completions.create({
        ...this._buildParams(model, messages, tools, options),
        stream: true,
      }, { signal: options.signal });
    } catch (error) {
      throw wrapProviderError(error, 'Custom OpenAI-compatible request failed', {
        signal: options.signal,
      });
    }

    const toolCalls = [];
    let content = '';

    try {
      for await (const chunk of stream) {
        const choice = chunk?.choices?.[0];
        const delta = choice?.delta;
        if (delta?.content) {
          content += delta.content;
          yield { type: 'content', content: delta.content };
        }

        for (const toolCall of delta?.tool_calls || []) {
          const index = Number.isInteger(toolCall.index) ? toolCall.index : toolCalls.length;
          if (!toolCalls[index]) {
            toolCalls[index] = {
              id: toolCall.id || '',
              type: 'function',
              function: { name: '', arguments: '' },
            };
          }
          if (toolCall.id) toolCalls[index].id = toolCall.id;
          if (toolCall.function?.name) toolCalls[index].function.name += toolCall.function.name;
          if (toolCall.function?.arguments) {
            toolCalls[index].function.arguments += toolCall.function.arguments;
          }
        }

        if (!choice?.finish_reason) continue;
        const usage = this.normalizeUsage(chunk.usage);
        if (toolCalls.length > 0) {
          yield {
            type: 'tool_calls',
            toolCalls: toolCalls.filter(Boolean),
            content,
            usage,
          };
        } else {
          yield { type: 'done', content, usage };
        }
        return;
      }
    } catch (error) {
      throw wrapProviderError(error, 'Custom OpenAI-compatible stream failed', {
        signal: options.signal,
      });
    }

    if (toolCalls.length > 0) {
      yield {
        type: 'tool_calls',
        toolCalls: toolCalls.filter(Boolean),
        content,
        usage: null,
      };
    } else {
      yield { type: 'done', content, usage: null };
    }
  }
}

module.exports = { CustomOpenAIProvider };
