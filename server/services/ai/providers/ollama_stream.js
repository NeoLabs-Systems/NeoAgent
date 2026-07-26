'use strict';

const { waitForAbortableResult } = require('../../network/http');
const { throwIfAborted } = require('../../../utils/abort');

function malformedStreamError(cause = null) {
  const error = new Error('Ollama /api/chat returned malformed streaming JSON.', cause ? { cause } : undefined);
  error.code = 'OLLAMA_STREAM_MALFORMED';
  return error;
}

function streamEndedEarlyError() {
  const error = new Error('Ollama stream ended before sending a completion marker.');
  error.code = 'OLLAMA_STREAM_INCOMPLETE';
  return error;
}

function parseLine(line) {
  if (!line.trim()) return null;
  try {
    const value = JSON.parse(line);
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      throw malformedStreamError();
    }
    return value;
  } catch (error) {
    if (error?.code === 'OLLAMA_STREAM_MALFORMED') throw error;
    throw malformedStreamError(error);
  }
}

function usageFrom(data) {
  if (data.prompt_eval_count == null && data.eval_count == null) return null;
  const promptTokens = Number(data.prompt_eval_count) || 0;
  const completionTokens = Number(data.eval_count) || 0;
  return {
    promptTokens,
    completionTokens,
    totalTokens: promptTokens + completionTokens,
  };
}

function consumeData(data, state, errorFactory) {
  if (data.error) throw errorFactory(data.error);
  const chunks = [];
  if (data.message?.content) {
    const content = String(data.message.content);
    state.content += content;
    chunks.push({ type: 'content', content });
  }
  if (Array.isArray(data.message?.tool_calls)) {
    for (const toolCall of data.message.tool_calls) {
      const name = String(toolCall?.function?.name || '').trim();
      if (!name) throw malformedStreamError();
      state.toolCalls.push({
        id: `call_ollama_${state.callSeed}_${state.nextCallIndex}`,
        type: 'function',
        function: {
          name,
          arguments: typeof toolCall.function.arguments === 'string'
            ? toolCall.function.arguments
            : JSON.stringify(toolCall.function.arguments || {}),
        },
      });
      state.nextCallIndex += 1;
    }
  }
  if (data.done === true) {
    state.done = true;
    chunks.push({
      type: 'done',
      content: state.content,
      toolCalls: state.toolCalls,
      finishReason: state.toolCalls.length > 0 ? 'tool_calls' : 'stop',
      usage: usageFrom(data),
    });
  }
  return chunks;
}

async function* readOllamaStream(response, options = {}) {
  const reader = response?.body?.getReader?.();
  if (!reader) throw new Error('Ollama /api/chat returned no streaming response body.');
  const decoder = new TextDecoder();
  const maxResponseBytes = Number(options.maxResponseBytes) > 0
    ? Number(options.maxResponseBytes)
    : 16 * 1024 * 1024;
  const errorFactory = options.errorFactory || ((message) => new Error(String(message || 'Ollama error')));
  const state = {
    callSeed: Date.now(),
    content: '',
    done: false,
    nextCallIndex: 0,
    toolCalls: [],
  };
  let buffer = '';
  let responseBytes = 0;

  const emitLine = (line) => {
    const data = parseLine(line);
    return data ? consumeData(data, state, errorFactory) : [];
  };

  try {
    while (!state.done) {
      throwIfAborted(options.signal, 'Ollama stream aborted.');
      const { done, value } = await waitForAbortableResult(
        reader.read(),
        options.signal,
        'Ollama stream aborted.',
      );
      if (done) break;
      responseBytes += value?.byteLength || 0;
      if (responseBytes > maxResponseBytes) {
        const error = new Error('Ollama stream exceeded its response safety limit.');
        error.code = 'HTTP_RESPONSE_TOO_LARGE';
        throw error;
      }

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';
      for (const line of lines) {
        for (const chunk of emitLine(line)) yield chunk;
        if (state.done) return;
      }
    }

    buffer += decoder.decode();
    if (buffer.trim()) {
      for (const chunk of emitLine(buffer)) yield chunk;
    }
    if (!state.done) throw streamEndedEarlyError();
  } finally {
    await reader.cancel().catch(() => {});
    reader.releaseLock?.();
  }
}

module.exports = {
  readOllamaStream,
};
