const { BaseProvider } = require('./base');
const { createStreamGuard, degenerateOutputError } = require('./stream_guard');

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
  async *readStream(stream) {
    const contentGuard = createStreamGuard();
    const argumentGuards = [];
    const toolCalls = [];
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
      if (delta?.content) {
        content += delta.content;
        check(contentGuard.feed(delta.content));
        yield { type: 'content', content: delta.content };
      }
      for (const tc of delta?.tool_calls || []) {
        const index = Number.isInteger(tc.index) ? tc.index : toolCalls.length;
        if (!toolCalls[index]) {
          toolCalls[index] = { id: tc.id || '', type: 'function', function: { name: '', arguments: '' } };
          argumentGuards[index] = createStreamGuard();
        }
        if (tc.id) toolCalls[index].id = tc.id;
        // Names arrive once, in pieces, or repeated on every delta depending
        // on the endpoint; append only what is not already there.
        if (tc.function?.name && !toolCalls[index].function.name.endsWith(tc.function.name)) {
          toolCalls[index].function.name += tc.function.name;
        }
        if (tc.function?.arguments) {
          toolCalls[index].function.arguments += tc.function.arguments;
          check(argumentGuards[index].feed(tc.function.arguments), toolCalls[index].function.name);
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
      content: msg.content || '',
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
