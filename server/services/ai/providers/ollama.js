'use strict';

const { BaseProvider } = require('./base');
const { fetchResponseText, readResponseText } = require('../../network/http');
const { createAbortError, isAbortError, throwIfAborted } = require('../../../utils/abort');
const { readOllamaStream } = require('./ollama_stream');

const MAX_CHAT_RESPONSE_BYTES = 16 * 1024 * 1024;

function ollamaError(message, status = null) {
  const error = new Error(
    status == null
      ? `Ollama request failed: ${message}`
      : `Ollama request failed (HTTP ${status}): ${message}`,
  );
  if (status != null) error.status = status;
  if (/does not support tools|tools.*not supported/i.test(String(message || ''))) {
    error.code = 'OLLAMA_TOOLS_UNSUPPORTED';
  }
  return error;
}

class OllamaProvider extends BaseProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'ollama';
    this.baseUrl = config.baseUrl || process.env.OLLAMA_URL || 'http://localhost:11434';
    this.models = [];
  }

  async listModels(signal = null) {
    try {
      const { response, text } = await fetchResponseText(`${this.baseUrl}/api/tags`, {
        maxResponseBytes: 2 * 1024 * 1024,
        serviceName: 'Ollama model catalog',
        signal,
        timeoutMs: 5000,
      });
      if (!response.ok) throw new Error(`Ollama /api/tags returned HTTP ${response.status}`);
      const data = JSON.parse(text || '{}');
      this.models = (data.models || []).map(m => m.name);
      return this.models;
    } catch (err) {
      if (isAbortError(err, signal)) throw createAbortError(signal);
      return [];
    }
  }

  async ensureModel(model, signal = null) {
    const models = await this.listModels(signal);
    // Normalization: Ollama often adds :latest if no tag is specified
    const normalizedModel = model.includes(':') ? model : `${model}:latest`;
    const found = models.some(m => m === model || m === normalizedModel);
    
    if (found) return true;

    console.log(`[Ollama] Model '${model}' not found, pulling from registry...`);
    this.onStatus?.({
      kind: 'model_download',
      status: 'started',
      model,
      phase: 'Downloading model',
      message: `Downloading local Ollama model '${model}'. First-time pulls can take a while.`
    });
    try {
      const { response, text } = await fetchResponseText(`${this.baseUrl}/api/pull`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: model, stream: false }),
        maxResponseBytes: 2 * 1024 * 1024,
        serviceName: 'Ollama model pull',
        signal,
        timeoutMs: 5 * 60 * 1000,
      });
      if (!response.ok) {
        let detail = text;
        try { detail = JSON.parse(text || '{}').error || text; } catch {}
        throw new Error(
          `Pull failed with HTTP ${response.status}: ${String(detail || response.statusText).slice(0, 500)}`,
        );
      }
      console.log(`[Ollama] Model '${model}' pulled successfully.`);
      this.onStatus?.({
        kind: 'model_download',
        status: 'completed',
        model,
        phase: 'Thinking',
        message: `Local Ollama model '${model}' is ready.`
      });
      // Refresh local model list
      await this.listModels(signal);
      return true;
    } catch (e) {
      if (isAbortError(e, signal)) throw createAbortError(signal);
      this.onStatus?.({
        kind: 'model_download',
        status: 'failed',
        model,
        phase: 'Model download failed',
        message: `Failed to download local Ollama model '${model}': ${e.message}`
      });
      console.error(`[Ollama] Failed to pull model '${model}':`, e.message);
      throw e;
    }
  }

  getContextWindow(model) {
    return 128000;
  }

  formatToolsForOllama(tools) {
    return (Array.isArray(tools) ? tools : [])
      .filter((tool) => tool && typeof tool === 'object' && String(tool.name || '').trim())
      .map((tool) => ({
        type: 'function',
        function: {
          name: String(tool.name).trim(),
          description: tool.description,
          parameters: tool.parameters || { type: 'object', properties: {} },
        },
      }));
  }

  buildChatBody(messages, tools, options, stream) {
    const body = {
      model: this.requireModel(options),
      messages: messages.map(m => {
        const msg = {
          role: m.role,
          content: m.content || '',
          ...(m.tool_call_id ? { tool_call_id: m.tool_call_id } : {})
        };
        if (m.tool_calls) {
          msg.tool_calls = m.tool_calls.map((tc) => {
            const name = tc?.function?.name || tc?.name || '';
            const rawArgs = tc?.function?.arguments ?? tc?.arguments;
            let args = rawArgs;
            if (typeof args === 'string') {
              try { args = JSON.parse(args || '{}'); } catch { args = {}; }
            }
            if (args == null || typeof args !== 'object') args = {};
            return {
              ...tc,
              function: {
                name,
                arguments: args,
              },
            };
          }).filter((tc) => tc.function?.name);
        }
        return msg;
      }),
      stream,
      options: {
        temperature: options.temperature ?? 0.7,
        num_predict: options.maxTokens || 16384
      }
    };
    if (tools.length > 0) {
      body.tools = this.formatToolsForOllama(tools);
    }
    return body;
  }

  // Ollama returns HTTP 200 with an error body for some failures and a non-2xx
  // status for others; surface both as real errors instead of letting callers
  // see a silently empty response. Tags models that reject tools so the caller
  // can transparently retry without them.
  async postChat(body, signal = null) {
    const res = await fetch(`${this.baseUrl}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal,
    });
    if (!res.ok) {
      const detail = await readResponseText(res, {
        maxResponseBytes: 64 * 1024,
        serviceName: 'Ollama chat error',
      }).catch(() => '');
      let message = detail;
      try { message = JSON.parse(detail)?.error || detail; } catch {}
      throw ollamaError(message || res.statusText, res.status);
    }
    return res;
  }

  async readChatResponse(body, signal = null) {
    const res = await this.postChat(body, signal);
    const text = await readResponseText(res, {
      maxResponseBytes: MAX_CHAT_RESPONSE_BYTES,
      serviceName: 'Ollama chat',
    });
    throwIfAborted(signal, 'Ollama chat aborted.');
    let data;
    try {
      data = JSON.parse(text);
    } catch (cause) {
      throw new Error('Ollama /api/chat returned malformed JSON.', { cause });
    }
    if (data.error) throw ollamaError(data.error);
    return data;
  }

  async chat(messages, tools = [], options = {}) {
    const model = this.requireModel(options);
    await this.ensureModel(model, options.signal);

    let data;
    try {
      data = await this.readChatResponse(
        this.buildChatBody(messages, tools, { ...options, model }, false),
        options.signal,
      );
    } catch (err) {
      if (err.code === 'OLLAMA_TOOLS_UNSUPPORTED' && tools.length > 0) {
        console.warn(`[Ollama] Model '${model}' does not support tools; retrying without them.`);
        data = await this.readChatResponse(
          this.buildChatBody(messages, [], { ...options, model }, false),
          options.signal,
        );
      } else {
        throw err;
      }
    }
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
    const model = this.requireModel(options);
    await this.ensureModel(model, options.signal);

    let requestTools = tools;
    let retriedWithoutTools = false;
    while (true) {
      let emittedChunk = false;
      try {
        const res = await this.postChat(
          this.buildChatBody(messages, requestTools, { ...options, model }, true),
          options.signal,
        );
        for await (const chunk of readOllamaStream(res, {
          errorFactory: ollamaError,
          maxResponseBytes: MAX_CHAT_RESPONSE_BYTES,
          signal: options.signal,
        })) {
          emittedChunk = true;
          yield chunk;
        }
        return;
      } catch (err) {
        if (
          err.code === 'OLLAMA_TOOLS_UNSUPPORTED'
          && tools.length > 0
          && !retriedWithoutTools
          && !emittedChunk
        ) {
          console.warn(`[Ollama] Model '${model}' does not support tools; retrying stream without them.`);
          retriedWithoutTools = true;
          requestTools = [];
          continue;
        }
        throw err;
      }
    }
  }
}

module.exports = { OllamaProvider };
