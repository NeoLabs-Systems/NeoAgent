const { BaseProvider } = require('./base');

// Shared base for providers that speak the OpenAI Chat Completions wire format
// (OpenAI, Grok, NVIDIA NIM, GitHub Copilot, ...). It owns the response/usage
// normalization and vision request that were previously copy-pasted into each
// provider. Per-provider concerns — client construction, model lists, context
// windows, reasoning detection, and the streaming loop — stay in the subclasses,
// since those genuinely differ between vendors.
class OpenAICompatibleProvider extends BaseProvider {
  normalizeUsage(usage) {
    if (!usage) return null;
    return {
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

    const model = options.model || this.getDefaultVisionModel();
    const b64 = BaseProvider.readImageAsBase64(options.imagePath);
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
    });

    return {
      content: response.choices[0]?.message?.content || '',
      model: response.model || model,
    };
  }
}

module.exports = { OpenAICompatibleProvider };
