'use strict';

const { BaseProvider } = require('./base');
const { createJsonPrefixTracker, createStreamGuard, degenerateOutputError } = require('./stream_guard');

function visibleText(part) {
  return String(part?.content || part?.reasoning_content || '');
}

// Shared base for providers that speak the OpenAI Chat Completions wire format
// (OpenAI, Grok, NVIDIA NIM, GitHub Copilot, ...). It owns the response/usage
// normalization, the streaming consumer, and the vision request that were
// previously copy-pasted into each provider. Per-provider concerns — client
// construction, model lists, context windows, reasoning detection — stay in
// the subclasses, since those genuinely differ between vendors.
class OpenAICompatibleProvider extends BaseProvider {
  // Consumes a Chat Completions SSE stream. Keeps reading past finish_reason so
  // the trailing usage-only chunk (stream_options.include_usage) is captured,
  // and aborts as soon as any tool-call argument or the reply text turns into
  // runaway output instead of letting it run to max_tokens.
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
    let finishReason = null;
    let usage = null;

    const check = (verdict, toolName = '') => {
      if (verdict) throw degenerateOutputError(this.name, verdict, toolName);
    };

    for await (const chunk of stream) {
      if (chunk.usage) usage = this.normalizeUsage(chunk.usage);
      const choice = chunk.choices?.[0];
      const delta = choice?.delta;
      const text = visibleText(delta);
      if (text) {
        content += text;
        check(contentGuard.feed(text));
        yield { type: 'content', content: text };
      }
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
            check({ reason: argumentJson[index].reason, bytes: toolCalls[index].function.arguments.length }, name);
          }
          check(argumentGuards[index].feed(tc.function.arguments), name);
        }
      }
      if (choice?.finish_reason) finishReason = choice.finish_reason;
    }

    const calls = toolCalls.filter(Boolean);
    yield {
      type: calls.length > 0 ? 'tool_calls' : 'done',
      content,
      toolCalls: calls,
      finishReason,
      usage,
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
      cacheWriteTokens: usage.cacheWriteTokens ?? 0,
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
    return {
      content: visibleText(msg),
      toolCalls: (msg.tool_calls || [])
        .filter((tc) => tc?.function)
        .map((tc) => ({
          id: tc.id,
          type: 'function',
          function: { name: tc.function.name, arguments: tc.function.arguments },
        })),
      finishReason: choice.finish_reason,
      usage: this.normalizeUsage(response.usage),
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
