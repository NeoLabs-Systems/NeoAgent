const { BaseProvider } = require('./base');

class OllamaProvider extends BaseProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'ollama';
    this.baseUrl = config.baseUrl || process.env.OLLAMA_URL || 'http://localhost:11434';
    this.models = [];
  }

  async listModels() {
    try {
      const res = await fetch(`${this.baseUrl}/api/tags`);
      const data = await res.json();
      this.models = (data.models || []).map(m => m.name);
      return this.models;
    } catch {
      return [];
    }
  }

  getContextWindow(model) {
    return 128000;
  }

  formatToolsForOllama(tools) {
    return tools.map(tool => ({
      type: 'function',
      function: {
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters || { type: 'object', properties: {} }
      }
    }));
  }

  async chat(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || 'llama3.1';
    const body = {
      model,
      messages: messages.map(m => ({
        role: m.role,
        content: m.content || '',
        ...(m.tool_calls ? { tool_calls: m.tool_calls } : {}),
        ...(m.tool_call_id ? { tool_call_id: m.tool_call_id } : {})
      })),
      stream: false,
      options: {
        temperature: options.temperature ?? 0.7,
        num_predict: options.maxTokens || 16384
      }
    };

    if (tools.length > 0) {
      body.tools = this.formatToolsForOllama(tools);
    }

    const res = await fetch(`${this.baseUrl}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });

    const data = await res.json();
    const msg = data.message || {};

    return {
      content: msg.content || '',
      toolCalls: (msg.tool_calls || []).map((tc, i) => ({
        id: `call_ollama_${Date.now()}_${i}`,
        type: 'function',
        function: {
          name: tc.function.name,
          arguments: JSON.stringify(tc.function.arguments || {})
        }
      })),
      finishReason: msg.tool_calls?.length > 0 ? 'tool_calls' : 'stop',
      usage: data.prompt_eval_count ? {
        promptTokens: data.prompt_eval_count || 0,
        completionTokens: data.eval_count || 0,
        totalTokens: (data.prompt_eval_count || 0) + (data.eval_count || 0)
      } : null,
      model: data.model || model
    };
  }

  async *stream(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || 'llama3.1';
    const body = {
      model,
      messages: messages.map(m => ({
        role: m.role,
        content: m.content || '',
        ...(m.tool_calls ? { tool_calls: m.tool_calls } : {}),
        ...(m.tool_call_id ? { tool_call_id: m.tool_call_id } : {})
      })),
      stream: true,
      options: {
        temperature: options.temperature ?? 0.7,
        num_predict: options.maxTokens || 16384
      }
    };

    if (tools.length > 0) {
      body.tools = this.formatToolsForOllama(tools);
    }

    const res = await fetch(`${this.baseUrl}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let content = '';
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const data = JSON.parse(line);
          if (data.message?.content) {
            content += data.message.content;
            yield { type: 'content', content: data.message.content };
          }
          if (data.done) {
            const toolCalls = (data.message?.tool_calls || []).map((tc, i) => ({
              id: `call_ollama_${Date.now()}_${i}`,
              type: 'function',
              function: {
                name: tc.function.name,
                arguments: JSON.stringify(tc.function.arguments || {})
              }
            }));
            yield {
              type: 'done',
              content,
              toolCalls,
              finishReason: toolCalls.length > 0 ? 'tool_calls' : 'stop',
              usage: data.prompt_eval_count ? {
                promptTokens: data.prompt_eval_count || 0,
                completionTokens: data.eval_count || 0,
                totalTokens: (data.prompt_eval_count || 0) + (data.eval_count || 0)
              } : null
            };
          }
        } catch {}
      }
    }
  }
}

module.exports = { OllamaProvider };
