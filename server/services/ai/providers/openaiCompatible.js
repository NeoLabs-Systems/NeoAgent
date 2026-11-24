'use strict';

const { BaseProvider } = require('./base');
const { createJsonPrefixTracker, createStreamGuard, degenerateOutputError } = require('./stream_guard');

function textField(value) {
  return typeof value === 'string' ? value : '';
}

// reasoning_content / reasoning is the model's private thought, never the reply:
// not even when a turn has no reply text, since that is how a model says it has
// nothing to add. An endpoint that puts its whole answer there looks like an
// empty turn, which the loop recovers from by asking again or switching models;
// passing the thought off as the answer showed it to the user.
function replyText(part) {
  return textField(part?.content);
}

// OpenRouter streams reasoning_details in pieces keyed by index. The sequence has
// to go back exactly as it came, so pieces of one block are joined in place.
function mergeReasoningDetails(details, incoming) {
  for (const piece of Array.isArray(incoming) ? incoming : []) {
    const index = Number.isInteger(piece?.index) ? piece.index : details.length;
    const current = details[index];
    if (!current) {
      details[index] = { ...piece };
      continue;
    }
    for (const field of ['text', 'summary', 'data']) {
      if (typeof piece[field] === 'string') current[field] = `${current[field] || ''}${piece[field]}`;
    }
    if (piece.signature) current.signature = piece.signature;
    if (piece.format) current.format = piece.format;
  }
  return details;
}

// A provider's reasoning, in the field it used, so it can go back the same way.
// DeepSeek rejects a tool-call turn that comes back without it.
function reasoningStateFrom({ reasoningContent = '', reasoning = '', reasoningDetails = [] }) {
  const details = reasoningDetails.filter(Boolean);
  if (details.length) return { reasoning_details: details };
  if (reasoningContent) return { reasoning_content: reasoningContent };
  if (reasoning) return { reasoning };
  return null;
}

class OpenAICompatibleProvider extends BaseProvider {
  prepareMessages(messages) {
    return super.prepareMessages(messages.map((message) => (
      message?.reasoningState ? { ...message, ...message.reasoningState } : message
    )));
  }

  async *readStream(stream, tools = []) {
    const contentGuard = createStreamGuard();
    const argumentGuards = [];
    const argumentJson = [];
    const toolCalls = [];
    const declaredKeys = new Map(tools.map((tool) => [
      tool.name,
      tool.parameters?.properties && tool.parameters.additionalProperties !== true
        ? new Set(Object.keys(tool.parameters.properties))
        : null,
    ]));
    let content = '';
    let reasoningContent = '';
    let reasoningPlain = '';
    const reasoningDetails = [];
    let finishReason = null;
    let usage = null;
    let servedModel = null;

    const check = (verdict, toolName = '') => {
      if (verdict) throw degenerateOutputError(this.name, verdict, toolName);
    };

    for await (const chunk of stream) {
      if (chunk.usage) usage = this.normalizeUsage(chunk.usage);
      if (chunk.model) servedModel = chunk.model;
      const choice = chunk.choices?.[0];
      const delta = choice?.delta;
      const text = replyText(delta);
      if (text) {
        content += text;
        check(contentGuard.feed(text));
        yield { type: 'content', content: text };
      }
      reasoningContent += textField(delta?.reasoning_content);
      reasoningPlain += textField(delta?.reasoning);
      if (delta?.reasoning_details) mergeReasoningDetails(reasoningDetails, delta.reasoning_details);
      for (const tc of delta?.tool_calls || []) {
        const index = Number.isInteger(tc.index) ? tc.index : toolCalls.length;
        if (!toolCalls[index]) {
          toolCalls[index] = { id: tc.id || '', type: 'function', function: { name: '', arguments: '' } };
          argumentGuards[index] = createStreamGuard();
          argumentJson[index] = createJsonPrefixTracker({
            isKnownKey: (key) => {
              const known = declaredKeys.get(toolCalls[index].function.name);
              return !known || known.has(key);
            },
          });
        }
        if (tc.id) toolCalls[index].id = tc.id;
        // Names arrive once, in pieces, or repeated on every delta depending
        // on the endpoint; append only what is not already there.
        if (tc.function?.name && !toolCalls[index].function.name.endsWith(tc.function.name)) {
          toolCalls[index].function.name += tc.function.name;
        }
        if (tc.function?.arguments) {
          toolCalls[index].function.arguments += tc.function.arguments;
          const name = toolCalls[index].function.name;
          if (!argumentJson[index].feed(tc.function.arguments)) {
            check({
              reason: argumentJson[index].reason,
              key: argumentJson[index].key,
              bytes: toolCalls[index].function.arguments.length,
            }, name);
          }
          check(argumentGuards[index].feed(tc.function.arguments), name);
        }
      }
      if (choice?.finish_reason) finishReason = choice.finish_reason;
    }

    const calls = toolCalls.filter(Boolean);
    const reasoningState = calls.length > 0
      ? reasoningStateFrom({ reasoningContent, reasoning: reasoningPlain, reasoningDetails })
      : null;
    yield {
      type: calls.length > 0 ? 'tool_calls' : 'done',
      content,
      toolCalls: calls,
      finishReason,
      // Output stopped at the token limit rather than because the model was
      // done. Callers must not treat that as a finished answer.
      truncated: finishReason === 'length',
      usage,
      ...(servedModel ? { model: servedModel } : {}),
      ...(reasoningState ? { reasoningState } : {}),
    };
  }

  normalizeUsage(usage) {
    if (!usage) return null;
    return {
      inputTokens: usage.prompt_tokens ?? usage.promptTokens ?? 0,
      outputTokens: usage.completion_tokens ?? usage.completionTokens ?? 0,
      reasoningTokens: usage.completion_tokens_details?.reasoning_tokens
        ?? usage.output_tokens_details?.reasoning_tokens
        ?? usage.reasoningTokens
        ?? 0,
      cachedReadTokens: usage.prompt_tokens_details?.cached_tokens
        ?? usage.input_tokens_details?.cached_tokens
        ?? usage.cachedReadTokens
        ?? 0,
      cacheWriteTokens: usage.prompt_tokens_details?.cache_write_tokens
        ?? usage.input_tokens_details?.cache_write_tokens
        ?? usage.cacheWriteTokens
        ?? 0,
      promptTokens: usage.prompt_tokens ?? usage.promptTokens ?? 0,
      completionTokens: usage.completion_tokens ?? usage.completionTokens ?? 0,
      totalTokens: usage.total_tokens ?? usage.totalTokens ?? 0,
    };
  }

  normalizeResponse(response) {
    const choice = response?.choices?.[0];
    if (!choice) {
      throw new Error(`Provider '${this.name}' returned no choices in the response`);
    }
    const msg = choice.message || {};
    const reasoningState = msg.tool_calls?.length
      ? reasoningStateFrom({
        reasoningContent: textField(msg.reasoning_content),
        reasoning: textField(msg.reasoning),
        reasoningDetails: Array.isArray(msg.reasoning_details) ? msg.reasoning_details : [],
      })
      : null;
    return {
      content: replyText(msg),
      // A router may answer with another model than the one asked for.
      ...(response.model ? { model: response.model } : {}),
      toolCalls: (msg.tool_calls || [])
        .filter((tc) => tc?.function)
        .map((tc) => ({
          id: tc.id,
          type: 'function',
          function: { name: tc.function.name, arguments: tc.function.arguments },
        })),
      finishReason: choice.finish_reason,
      truncated: choice.finish_reason === 'length',
      usage: this.normalizeUsage(response.usage),
      ...(reasoningState ? { reasoningState } : {}),
    };
  }

  async analyzeImage(options = {}) {
    if (!this.supportsVision()) {
      throw new Error(`Provider '${this.name}' does not support image analysis`);
    }

    const model = this.requireModel(options);
    const b64 = options.imageBase64 || BaseProvider.readImageAsBase64(options.imagePath);
    const response = await this.client.chat.completions.create({
      model,
      max_tokens: options.maxTokens || 4096,
      messages: [{
        role: 'user',
        content: [
          { type: 'text', text: options.question || 'Describe this image in detail.' },
          {
            type: 'image_url',
            image_url: {
              url: `data:${options.mimeType || 'image/jpeg'};base64,${b64}`,
            },
          },
        ],
      }],
    }, options.signal ? { signal: options.signal } : undefined);

    return {
      content: response.choices[0]?.message?.content || '',
      model: response.model || model,
    };
  }
}

module.exports = { OpenAICompatibleProvider };
