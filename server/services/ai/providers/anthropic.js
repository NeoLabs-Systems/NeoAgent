const Anthropic = require('@anthropic-ai/sdk');
const { BaseProvider } = require('./base');

class AnthropicProvider extends BaseProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'anthropic';
    this.models = [
      'claude-sonnet-4-20250514',
      'claude-3-5-sonnet-20241022',
      'claude-3-5-haiku-20241022',
      'claude-3-opus-20240229',
      'MiniMax-M2.7'
    ];
    this.contextWindows = {
      'claude-sonnet-4-20250514': 200000,
      'claude-3-5-sonnet-20241022': 200000,
      'claude-3-5-haiku-20241022': 200000,
      'claude-3-opus-20240229': 200000,
      'MiniMax-M2.7': 204800
    };
    this.client = new Anthropic({
      apiKey: config.apiKey || process.env.ANTHROPIC_API_KEY,
      baseURL: config.baseUrl || process.env.ANTHROPIC_BASE_URL || undefined
    });
  }

  getContextWindow(model) {
    return this.contextWindows[model] || 200000;
  }

  formatTools(tools) {
    return tools.map(tool => ({
      name: tool.name,
      description: tool.description,
      input_schema: tool.parameters || { type: 'object', properties: {} }
    }));
  }

  normalizeContentBlocks(blocks = []) {
    const normalized = [];

    for (const block of blocks) {
      if (!block || !block.type) continue;

      if (block.type === 'thinking') {
        normalized.push({
          type: 'thinking',
          thinking: block.thinking || '',
          ...(block.signature ? { signature: block.signature } : {})
        });
        continue;
      }

      if (block.type === 'redacted_thinking') {
        normalized.push({
          type: 'redacted_thinking',
          data: block.data
        });
        continue;
      }

      if (block.type === 'text') {
        normalized.push({
          type: 'text',
          text: block.text || ''
        });
        continue;
      }

      if (block.type === 'tool_use') {
        normalized.push({
          type: 'tool_use',
          id: block.id,
          name: block.name,
          input: block.input || {}
        });
      }
    }

    return normalized;
  }

  convertMessages(messages) {
    let system = '';
    const converted = [];

    for (const msg of messages) {
      if (msg.role === 'system') {
        system += (system ? '\n\n' : '') + msg.content;
        continue;
      }

      if (msg.role === 'tool') {
        converted.push({
          role: 'user',
          content: [{
            type: 'tool_result',
            tool_use_id: msg.tool_call_id,
            content: typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content)
          }]
        });
        continue;
      }

      if (msg.role === 'assistant' && msg.tool_calls) {
        if (Array.isArray(msg.providerContentBlocks) && msg.providerContentBlocks.length > 0) {
          converted.push({
            role: 'assistant',
            content: this.normalizeContentBlocks(msg.providerContentBlocks)
          });
          continue;
        }

        const content = [];
        if (msg.content) content.push({ type: 'text', text: msg.content });
        for (const tc of msg.tool_calls) {
          content.push({
            type: 'tool_use',
            id: tc.id,
            name: tc.function.name,
            input: JSON.parse(tc.function.arguments || '{}')
          });
        }
        converted.push({ role: 'assistant', content });
        continue;
      }

      converted.push({
        role: msg.role === 'assistant' ? 'assistant' : 'user',
        content: msg.content
      });
    }

    return { system, messages: converted };
  }

  async chat(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || this.getDefaultModel();
    const { system, messages: converted } = this.convertMessages(messages);

    const params = {
      model,
      max_tokens: options.maxTokens || 16384,
      messages: converted
    };

    if (system) params.system = system;
    if (tools.length > 0) params.tools = this.formatTools(tools);

    const response = await this.client.messages.create(params);

    let content = '';
    const toolCalls = [];
    const providerContentBlocks = this.normalizeContentBlocks(response.content);

    for (const block of response.content) {
      if (block.type === 'text') {
        content += block.text;
      } else if (block.type === 'tool_use') {
        toolCalls.push({
          id: block.id,
          type: 'function',
          function: {
            name: block.name,
            arguments: JSON.stringify(block.input)
          }
        });
      }
    }

    return {
      content,
      toolCalls,
      providerContentBlocks,
      finishReason: response.stop_reason === 'tool_use' ? 'tool_calls' : 'stop',
      usage: {
        promptTokens: response.usage.input_tokens,
        completionTokens: response.usage.output_tokens,
        totalTokens: response.usage.input_tokens + response.usage.output_tokens
      },
      model: response.model
    };
  }

  async *stream(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || this.getDefaultModel();
    const { system, messages: converted } = this.convertMessages(messages);

    const params = {
      model,
      max_tokens: options.maxTokens || 16384,
      messages: converted,
      stream: true
    };

    if (system) params.system = system;
    if (tools.length > 0) params.tools = this.formatTools(tools);

    const stream = await this.client.messages.stream(params);

    let content = '';
    let currentToolCalls = [];
    let currentToolIndex = -1;
    const providerContentBlocks = [];

    for await (const event of stream) {
      if (event.type === 'content_block_start') {
        if (event.content_block.type === 'thinking') {
          providerContentBlocks[event.index] = {
            type: 'thinking',
            thinking: event.content_block.thinking || '',
            signature: event.content_block.signature || ''
          };
        } else if (event.content_block.type === 'redacted_thinking') {
          providerContentBlocks[event.index] = {
            type: 'redacted_thinking',
            data: event.content_block.data
          };
        } else if (event.content_block.type === 'text') {
          providerContentBlocks[event.index] = {
            type: 'text',
            text: event.content_block.text || ''
          };
        } else if (event.content_block.type === 'tool_use') {
          currentToolIndex++;
          currentToolCalls.push({
            id: event.content_block.id,
            type: 'function',
            function: { name: event.content_block.name, arguments: '' }
          });
          providerContentBlocks[event.index] = {
            type: 'tool_use',
            id: event.content_block.id,
            name: event.content_block.name,
            input: {}
          };
        }
      } else if (event.type === 'content_block_delta') {
        if (event.delta.type === 'text_delta') {
          content += event.delta.text;
          if (providerContentBlocks[event.index]?.type === 'text') {
            providerContentBlocks[event.index].text += event.delta.text;
          }
          yield { type: 'content', content: event.delta.text };
        } else if (event.delta.type === 'thinking_delta') {
          if (providerContentBlocks[event.index]?.type === 'thinking') {
            providerContentBlocks[event.index].thinking += event.delta.thinking || '';
          }
        } else if (event.delta.type === 'signature_delta') {
          if (providerContentBlocks[event.index]?.type === 'thinking') {
            providerContentBlocks[event.index].signature = event.delta.signature || '';
          }
        } else if (event.delta.type === 'input_json_delta') {
          if (currentToolCalls[currentToolIndex]) {
            currentToolCalls[currentToolIndex].function.arguments += event.delta.partial_json;
          }
          if (providerContentBlocks[event.index]?.type === 'tool_use') {
            const currentJson = providerContentBlocks[event.index]._inputJson || '';
            providerContentBlocks[event.index]._inputJson = currentJson + (event.delta.partial_json || '');
          }
        }
      } else if (event.type === 'message_stop') {
        const normalizedBlocks = providerContentBlocks
          .filter(Boolean)
          .map((block) => {
            if (block.type === 'tool_use') {
              let parsedInput = block.input || {};
              if (typeof block._inputJson === 'string' && block._inputJson.trim()) {
                try {
                  parsedInput = JSON.parse(block._inputJson);
                } catch { }
              }
              return {
                type: 'tool_use',
                id: block.id,
                name: block.name,
                input: parsedInput
              };
            }
            if (block.type === 'thinking') {
              return {
                type: 'thinking',
                thinking: block.thinking || '',
                ...(block.signature ? { signature: block.signature } : {})
              };
            }
            if (block.type === 'redacted_thinking') {
              return {
                type: 'redacted_thinking',
                data: block.data
              };
            }
            return {
              type: 'text',
              text: block.text || ''
            };
          });

        yield {
          type: 'done',
          content,
          toolCalls: currentToolCalls,
          providerContentBlocks: normalizedBlocks,
          finishReason: currentToolCalls.length > 0 ? 'tool_calls' : 'stop',
          usage: null
        };
      }
    }
  }
}

module.exports = { AnthropicProvider };
