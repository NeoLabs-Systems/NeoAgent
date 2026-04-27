const { BaseProvider } = require('./base');

const CODEX_BASE_URL = 'https://chatgpt.com/backend-api';

class CodexProvider extends BaseProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'codex';
    this.models = [
      'gpt-5.5',
      'gpt-5.4-mini',
      'gpt-5.2'
    ];
    this.reasoningModels = new Set(['gpt-5.5', 'gpt-5.4-mini', 'gpt-5.2', 'gpt-5.1']);
    this.contextWindows = {
      'gpt-5.5': 1000000,
      'gpt-5.4-mini': 200000,
      'gpt-5.2': 400000,
      'gpt-5.1': 400000
    };
    this.baseUrl = config.baseUrl || CODEX_BASE_URL;
    this.accessToken = config.accessToken || config.apiKey || '';
  }

  getDefaultModel() {
    return 'gpt-5.5';
  }

  getContextWindow(model) {
    for (const [id, size] of Object.entries(this.contextWindows)) {
      if (model === id || model.startsWith(id + '-')) return size;
    }
    return 272000;
  }

  supportsVision() {
    return true;
  }

  getDefaultVisionModel() {
    return 'gpt-4.1-mini';
  }

  isReasoningModel(model) {
    for (const id of this.reasoningModels) {
      if (model === id || model.startsWith(id + '-')) return true;
    }
    return false;
  }

  _getHeaders() {
    const headers = {
      'Content-Type': 'application/json',
    };
    if (this.accessToken) {
      headers['Authorization'] = `Bearer ${this.accessToken}`;
    }
    return headers;
  }

  formatTools(tools) {
    return tools.map(tool => ({
      type: 'function',
      function: {
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters || { type: 'object', properties: {} }
      }
    }));
  }

  async _request(endpoint, body, options = {}) {
    const url = `${this.baseUrl}${endpoint}`;
    const headers = this._getHeaders();

    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
      ...options
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Codex API error ${response.status}: ${errorText}`);
    }

    return response;
  }

  _buildParams(model, messages, tools, options) {
    const isReasoning = this.isReasoningModel(model);
    const formattedMessages = isReasoning
      ? messages.map(m => m.role === 'system' ? { ...m, role: 'developer' } : m)
      : messages;

    const params = {
      model,
      messages: formattedMessages
    };

    if (isReasoning) {
      params.max_completion_tokens = options.maxTokens || 16384;
      if (options.reasoningEffort || options.reasoning_effort) {
        params.reasoning_effort = options.reasoningEffort || options.reasoning_effort;
      }
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

    const response = await this._request('/v1/chat/completions', params);
    const data = await response.json();

    const choice = data.choices?.[0];
    if (!choice) {
      throw new Error('No response from Codex API');
    }

    return {
      content: choice.message?.content || '',
      toolCalls: choice.message?.tool_calls || [],
      finishReason: choice.finish_reason,
      usage: data.usage ? {
        promptTokens: data.usage.prompt_tokens,
        completionTokens: data.usage.completion_tokens,
        totalTokens: data.usage.total_tokens
      } : null,
      model: data.model
    };
  }

  async *stream(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || this.getDefaultModel();
    const params = this._buildParams(model, messages, tools, options);
    params.stream = true;
    params.stream_options = { include_usage: true };

    const url = `${this.baseUrl}/v1/chat/completions`;
    const headers = this._getHeaders();

    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(params)
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`Codex API error ${response.status}: ${errorText}`);
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    let currentToolCalls = [];
    let content = '';
    let finalUsage = null;

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (!line.startsWith('data: ')) continue;
          const dataStr = line.slice(6);
          if (dataStr === '[DONE]') continue;

          try {
            const data = JSON.parse(dataStr);

            if (data.usage && (!data.choices || data.choices.length === 0)) {
              finalUsage = {
                promptTokens: data.usage.prompt_tokens,
                completionTokens: data.usage.completion_tokens,
                totalTokens: data.usage.total_tokens
              };
              continue;
            }

            const delta = data.choices?.[0]?.delta;
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

            if (data.choices?.[0]?.finish_reason) {
              yield {
                type: 'done',
                content,
                toolCalls: currentToolCalls.filter(tc => tc.id),
                finishReason: data.choices[0].finish_reason,
                usage: data.usage || finalUsage
              };
            }
          } catch (parseErr) {
            // Skip malformed JSON
          }
        }
      }
    } finally {
      reader.releaseLock();
    }
  }
}

module.exports = { CodexProvider };