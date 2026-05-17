const OpenAI = require('openai');
const { BaseProvider } = require('./base');

const DEFAULT_BASE_URL = 'https://chatgpt.com/backend-api/codex';

function normalizeContent(content) {
  if (content == null) return '';
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content.map((part) => {
      if (!part) return '';
      if (typeof part === 'string') return part;
      if (part.type === 'text' && typeof part.text === 'string') return part.text;
      if (part.type === 'input_text' && typeof part.text === 'string') return part.text;
      return '';
    }).join('');
  }
  return String(content);
}

function normalizeInputContent(content) {
  if (content == null) return [];

  if (typeof content === 'string') {
    return [{ type: 'input_text', text: content }];
  }

  if (!Array.isArray(content)) {
    const text = String(content);
    return text ? [{ type: 'input_text', text }] : [];
  }

  const parts = [];
  for (const part of content) {
    if (!part) continue;
    if (typeof part === 'string') {
      if (part.trim()) parts.push({ type: 'input_text', text: part });
      continue;
    }
    if (part.type === 'text' && typeof part.text === 'string') {
      parts.push({ type: 'input_text', text: part.text });
      continue;
    }
    if (part.type === 'input_text' && typeof part.text === 'string') {
      parts.push({ type: 'input_text', text: part.text });
      continue;
    }
    if (part.type === 'image_url') {
      const imageUrl = typeof part.image_url === 'string' ? part.image_url : part.image_url?.url;
      if (imageUrl) {
        parts.push({
          type: 'input_image',
          image_url: imageUrl,
          detail: part.detail || 'auto',
        });
      }
      continue;
    }
    if (part.type === 'input_image') {
      parts.push({
        type: 'input_image',
        image_url: part.image_url || null,
        file_id: part.file_id || null,
        detail: part.detail || 'auto',
      });
    }
  }

  return parts;
}

function toFunctionCallOutput(toolCallId, content) {
  return {
    type: 'function_call_output',
    call_id: toolCallId,
    output: normalizeContent(content),
  };
}

function extractResponseText(response) {
  if (typeof response?.output_text === 'string' && response.output_text.length > 0) {
    return response.output_text;
  }

  const parts = [];
  for (const item of response?.output || []) {
    if (item?.type !== 'message') continue;
    for (const content of item.content || []) {
      if (content?.type === 'output_text' && typeof content.text === 'string') {
        parts.push(content.text);
      }
    }
  }
  return parts.join('');
}

function extractToolCalls(response) {
  const toolCalls = [];
  for (const item of response?.output || []) {
    if (item?.type !== 'function_call') continue;
    toolCalls.push({
      id: item.call_id || item.id || '',
      type: 'function',
      function: {
        name: item.name || '',
        arguments: item.arguments || '',
      },
    });
  }
  return toolCalls.filter((toolCall) => toolCall.id && toolCall.function.name);
}

function formatOpenAIError(err) {
  if (!err || typeof err !== 'object') return 'Unknown OpenAI error';
  const parts = [];
  if (typeof err.status === 'number') parts.push(`HTTP ${err.status}`);
  if (err.type) parts.push(`type=${err.type}`);
  if (err.code) parts.push(`code=${err.code}`);
  if (err.param) parts.push(`param=${err.param}`);
  if (err.request_id) parts.push(`request_id=${err.request_id}`);
  const message = err.message || 'Unknown OpenAI error';
  return parts.length > 0 ? `${message} (${parts.join(', ')})` : message;
}

class OpenAICodexProvider extends BaseProvider {
  constructor(config = {}) {
    super(config);

    const baseURL = config.baseUrl || process.env.OPENAI_CODEX_BASE_URL || DEFAULT_BASE_URL;

    if (!baseURL.includes('chatgpt.com/backend-api/codex') && !baseURL.includes('api.openai.com')) {
      console.warn(`[OpenAICodex] Using non-official base URL: ${baseURL}`);
    } else if (baseURL.includes('chatgpt.com/backend-api/codex')) {
      console.info(`[OpenAICodex] Using ChatGPT Codex endpoint: ${baseURL}`);
    }

    this.name = 'openai-codex';
    this.models = [
      'gpt-5.5',
      'gpt-5.4',
      'gpt-5.4-mini',
    ];
    this.reasoningModels = new Set([
      'gpt-5.5',
      'gpt-5.4',
      'gpt-5.4-mini',
    ]);
    this.client = new OpenAI({
      apiKey: config.apiKey || process.env.OPENAI_CODEX_ACCESS_TOKEN,
      baseURL,
      defaultHeaders: {
        'Editor-Version': process.env.OPENAI_CODEX_EDITOR_VERSION || 'vscode/1.99.0',
        'Editor-Plugin-Version': process.env.OPENAI_CODEX_EDITOR_PLUGIN_VERSION || 'neoagent/1.0.0',
        'User-Agent': process.env.OPENAI_CODEX_USER_AGENT || 'NeoAgent/1.0.0',
      },
    });
  }

  _isReasoningModel(model) {
    if (!model) return false;
    for (const id of this.reasoningModels) {
      if (model === id || model.startsWith(`${id}-`)) return true;
    }
    return false;
  }

  _buildRequest(messages = [], tools = [], options = {}, model = '') {
    const instructions = [];
    const input = [];

    for (const msg of messages || []) {
      if (!msg || !msg.role) continue;

      if ((msg.role === 'system' || msg.role === 'developer') && msg.content != null) {
        const text = normalizeContent(msg.content).trim();
        if (text) instructions.push(text);
        continue;
      }

      if (msg.role === 'tool') {
        const toolCallId = String(msg.tool_call_id || '').trim();
        if (!toolCallId) continue;
        input.push(toFunctionCallOutput(toolCallId, msg.content));
        continue;
      }

      const content = normalizeInputContent(msg.content);
      if (content.length > 0) {
        input.push({
          type: 'message',
          role: msg.role === 'assistant' ? 'assistant' : 'user',
          content,
        });
      }

      if (msg.role === 'assistant' && Array.isArray(msg.tool_calls) && msg.tool_calls.length > 0) {
        for (const toolCall of msg.tool_calls) {
          const name = String(toolCall?.function?.name || '').trim();
          const argumentsText = String(toolCall?.function?.arguments || '');
          const callId = String(toolCall?.id || toolCall?.call_id || '').trim();
          if (!name || !callId) continue;
          input.push({
            type: 'function_call',
            id: callId,
            call_id: callId,
            name,
            arguments: argumentsText,
          });
        }
      }
    }

    const request = {
      input,
    };

    if (instructions.length > 0) {
      request.instructions = instructions.join('\n\n');
    }

    if (tools && tools.length > 0) {
      request.tools = this.formatTools(tools);
      request.tool_choice = options.toolChoice || 'auto';
    }

    request.max_output_tokens = options.maxTokens || 16384;

    if (options.temperature !== undefined && options.temperature !== null) {
      request.temperature = options.temperature;
    }

    const reasoningEffort = options.reasoningEffort || options.reasoning_effort;
    if (reasoningEffort || this._isReasoningModel(model)) {
      request.reasoning = {
        effort: reasoningEffort || 'medium',
      };
    }

    return request;
  }

  async chat(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || this.getDefaultModel();
    const request = this._buildRequest(messages, tools, options, model);
    let response;
    try {
      response = await this.client.responses.create({
        model,
        ...request,
      });
    } catch (err) {
      throw new Error(`OpenAI Codex request failed: ${formatOpenAIError(err)}`);
    }

    const toolCalls = extractToolCalls(response);

    return {
      content: extractResponseText(response),
      toolCalls,
      finishReason: toolCalls.length > 0 ? 'tool_calls' : 'stop',
      usage: response.usage ? {
        promptTokens: response.usage.input_tokens,
        completionTokens: response.usage.output_tokens,
        totalTokens: response.usage.total_tokens,
      } : null,
      model: response.model,
    };
  }

  async *stream(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || this.getDefaultModel();
    const request = this._buildRequest(messages, tools, options, model);
    let stream;
    try {
      stream = await this.client.responses.create({
        model,
        ...request,
        stream: true,
      });
    } catch (err) {
      throw new Error(`OpenAI Codex request failed: ${formatOpenAIError(err)}`);
    }

    let content = '';
    let finalResponse = null;

    for await (const event of stream) {
      if (event.type === 'response.output_text.delta' && typeof event.delta === 'string') {
        content += event.delta;
        yield { type: 'content', content: event.delta };
        continue;
      }

      if (event.type === 'response.completed') {
        finalResponse = event.response;
      }
    }

    const response = finalResponse || {};
    const toolCalls = extractToolCalls(response);
    const finalContent = extractResponseText(response) || content;

    if (toolCalls.length > 0) {
      yield {
        type: 'tool_calls',
        content: finalContent,
        toolCalls,
        usage: response.usage ? {
          promptTokens: response.usage.input_tokens,
          completionTokens: response.usage.output_tokens,
          totalTokens: response.usage.total_tokens,
        } : null,
      };
      return;
    }

    yield {
      type: 'done',
      content: finalContent,
      toolCalls: [],
      finishReason: 'stop',
      usage: response.usage ? {
        promptTokens: response.usage.input_tokens,
        completionTokens: response.usage.output_tokens,
        totalTokens: response.usage.total_tokens,
      } : null,
    };
  }
}

module.exports = { OpenAICodexProvider };
