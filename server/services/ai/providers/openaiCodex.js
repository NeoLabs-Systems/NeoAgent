const crypto = require('crypto');
const OpenAI = require('openai');
const { BaseProvider } = require('./base');

const DEFAULT_BASE_URL = 'https://chatgpt.com/backend-api/codex';
const OPENAI_CODEX_EMPTY_INPUT_TEXT = ' ';
const NEOAGENT_VERSION = (() => {
  try {
    return require('../../../../package.json').version || 'unknown';
  } catch {
    return 'unknown';
  }
})();

// Stable per-process installation ID — Codex backend uses it for request tracking.
const INSTALLATION_ID = crypto.randomUUID();

function decodeJwtPayload(token) {
  try {
    const parts = String(token || '').split('.');
    if (parts.length < 2) return null;
    const payload = Buffer.from(parts[1], 'base64url').toString('utf8');
    return JSON.parse(payload);
  } catch {
    return null;
  }
}

function isCodexBackendBaseUrl(baseURL) {
  const trimmed = String(baseURL || '').trim();
  if (!trimmed) return false;

  try {
    const url = new URL(trimmed);
    const path = url.pathname.replace(/\/+$/, '');
    return url.hostname === 'chatgpt.com'
      && (path === '/backend-api' || path === '/backend-api/v1' || path === '/backend-api/codex' || path === '/backend-api/codex/v1');
  } catch {
    return false;
  }
}

function isOpenAIApiBaseUrl(baseURL) {
  const trimmed = String(baseURL || '').trim();
  if (!trimmed) return false;

  try {
    const url = new URL(trimmed);
    const path = url.pathname.replace(/\/+$/, '');
    return url.hostname === 'api.openai.com' && (path === '' || path === '/v1');
  } catch {
    return false;
  }
}

function normalizeCodexBaseUrl(baseURL) {
  if (!baseURL || isOpenAIApiBaseUrl(baseURL) || isCodexBackendBaseUrl(baseURL)) {
    return DEFAULT_BASE_URL;
  }
  return baseURL;
}

function isNativeCodexResponsesBaseUrl(baseURL) {
  return isCodexBackendBaseUrl(baseURL);
}

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

function normalizeMessageContent(content, role = 'user') {
  if (content == null) return [];
  const isAssistant = role === 'assistant';
  const textType = isAssistant ? 'output_text' : 'input_text';

  if (typeof content === 'string') {
    return [{ type: textType, text: content, ...(isAssistant ? { annotations: [] } : {}) }];
  }

  if (!Array.isArray(content)) {
    const text = String(content);
    return text ? [{ type: textType, text, ...(isAssistant ? { annotations: [] } : {}) }] : [];
  }

  const parts = [];
  for (const part of content) {
    if (!part) continue;
    if (typeof part === 'string') {
      if (part.trim()) parts.push({ type: textType, text: part, ...(isAssistant ? { annotations: [] } : {}) });
      continue;
    }
    if (part.type === 'text' && typeof part.text === 'string') {
      parts.push({ type: textType, text: part.text, ...(isAssistant ? { annotations: [] } : {}) });
      continue;
    }
    if (part.type === 'input_text' && typeof part.text === 'string') {
      parts.push({ type: textType, text: part.text, ...(isAssistant ? { annotations: [] } : {}) });
      continue;
    }
    if (part.type === 'output_text' && typeof part.text === 'string') {
      parts.push({ type: textType, text: part.text, ...(isAssistant ? { annotations: part.annotations || [] } : {}) });
      continue;
    }
    if (isAssistant && part.type === 'refusal') {
      const refusal = typeof part.refusal === 'string' ? part.refusal : part.text;
      if (typeof refusal === 'string') parts.push({ type: 'refusal', refusal });
      continue;
    }
    if (isAssistant) continue;
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

    const configuredBaseURL = config.baseUrl || process.env.OPENAI_CODEX_BASE_URL || DEFAULT_BASE_URL;
    const baseURL = normalizeCodexBaseUrl(configuredBaseURL);

    this.baseURL = baseURL;
    this.usesCodexBackend = isCodexBackendBaseUrl(baseURL);

    if (!this.usesCodexBackend && !baseURL.includes('api.openai.com')) {
      console.warn(`[OpenAICodex] Using non-official base URL: ${baseURL}`);
    } else if (this.usesCodexBackend) {
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

    let accountId = process.env.OPENAI_CODEX_ACCOUNT_ID || '';
    if (!accountId && this.usesCodexBackend) {
      const accessToken = config.apiKey || process.env.OPENAI_CODEX_ACCESS_TOKEN || '';
      const payload = decodeJwtPayload(accessToken);
      // account_id lives in access_token directly, or nested under the OIDC namespace in id_token
      accountId = payload?.chatgpt_account_id
        || payload?.['https://api.openai.com/auth']?.chatgpt_account_id
        || '';
    }

    const defaultHeaders = this.usesCodexBackend
      ? {
          'originator': 'openclaw',
          'version': NEOAGENT_VERSION,
          'User-Agent': `openclaw/${NEOAGENT_VERSION}`,
          'x-codex-installation-id': INSTALLATION_ID,
          'x-openai-internal-codex-residency': process.env.OPENAI_CODEX_RESIDENCY || 'us',
          ...(accountId ? { 'ChatGPT-Account-Id': accountId } : {}),
        }
      : undefined;

    this.client = new OpenAI({
      apiKey: config.apiKey || process.env.OPENAI_CODEX_ACCESS_TOKEN,
      baseURL,
      defaultHeaders,
      ...(config.fetch ? { fetch: config.fetch } : {}),
    });
  }

  formatTools(tools) {
    return tools.map((tool) => ({
      type: 'function',
      name: tool.name,
      description: tool.description || '',
      parameters: tool.parameters || { type: 'object', properties: {} },
      strict: false,
    }));
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

      const role = msg.role === 'assistant' ? 'assistant' : 'user';
      const content = normalizeMessageContent(msg.content, role);
      if (content.length > 0) {
        input.push({
          type: 'message',
          role,
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

    if (this.usesCodexBackend) {
      if (input.length === 0 && instructions.length > 0) {
        input.push({
          type: 'message',
          role: 'user',
          content: [{ type: 'input_text', text: OPENAI_CODEX_EMPTY_INPUT_TEXT }],
        });
      }
      // instructions must always be present (even empty) — backend returns 400 if omitted
      request.instructions = instructions.join('\n\n');
      request.store = false;
      // tools fields must always be explicit
      if (tools && tools.length > 0) {
        request.tools = this.formatTools(tools);
        request.tool_choice = options.toolChoice || 'auto';
      } else {
        request.tools = [];
        request.tool_choice = 'auto';
      }
      request.parallel_tool_calls = false;
      // Reasoning parameters are only sent when there are no tools: on the Codex
      // backend, combining reasoning mode with function-calling causes the model to
      // produce only internal reasoning output (no function_calls, no text), which
      // makes the engine see steps=0 and finalResponse=no on every run.
      const hasTools = tools && tools.length > 0;
      if (this._isReasoningModel(model) && !hasTools) {
        const effort = options.reasoningEffort || options.reasoning_effort || 'medium';
        request.reasoning = { effort, summary: 'auto' };
        request.include = ['reasoning.encrypted_content'];
      }
      this._sanitizeNativeCodexRequest(request);
    } else {
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
        request.reasoning = { effort: reasoningEffort || 'medium' };
      }
    }

    return request;
  }

  _requestHeaders() {
    const requestId = crypto.randomUUID();
    return this.usesCodexBackend
      ? {
          'x-client-request-id': requestId,
          'x-openclaw-session-id': requestId,
          'x-openclaw-turn-id': requestId,
          'x-openclaw-turn-attempt': '1',
        }
      : undefined;
  }

  _sanitizeNativeCodexRequest(request) {
    if (!isNativeCodexResponsesBaseUrl(this.baseURL)) return request;
    for (const key of [
      'max_output_tokens',
      'metadata',
      'prompt_cache_retention',
      'service_tier',
      'temperature',
      'top_p',
    ]) {
      delete request[key];
    }
    if (request.text && typeof request.text === 'object' && !Array.isArray(request.text)) {
      const text = { ...request.text };
      delete text.format;
      if (Object.keys(text).length > 0) {
        request.text = text;
      } else {
        delete request.text;
      }
    }
    return request;
  }

  async chat(messages, tools = [], options = {}) {
    if (this.usesCodexBackend) {
      let final = null;
      let content = '';
      for await (const event of this.stream(messages, tools, options)) {
        if (event.type === 'content') {
          content += event.content || '';
          continue;
        }
        if (event.type === 'tool_calls' || event.type === 'done') {
          final = event;
        }
      }
      return {
        content: final?.content || content,
        toolCalls: final?.toolCalls || [],
        finishReason: final?.finishReason || (final?.toolCalls?.length > 0 ? 'tool_calls' : 'stop'),
        usage: final?.usage || null,
        model: final?.model || options.model || this.config.model || this.getDefaultModel(),
      };
    }

    const model = options.model || this.config.model || this.getDefaultModel();
    const request = this._buildRequest(messages, tools, options, model);
    let response;
    try {
      response = await this.client.responses.create(
        { model, ...request },
        { headers: this._requestHeaders() },
      );
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
      stream = await this.client.responses.create(
        { model, ...request, stream: true },
        { headers: this._requestHeaders() },
      );
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
