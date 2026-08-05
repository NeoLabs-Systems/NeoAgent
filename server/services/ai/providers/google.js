'use strict';

const { GoogleGenAI } = require('@google/genai');
const { BaseProvider } = require('./base');
const { fetchResponseText } = require('../../network/http');

function parseToolArguments(value) {
  try {
    const parsed = JSON.parse(value || '{}');
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? parsed
      : {};
  } catch {
    return {};
  }
}

function normalizeUsage(usage) {
  if (!usage) return null;
  return {
    inputTokens: usage.promptTokenCount || 0,
    outputTokens: usage.candidatesTokenCount || 0,
    reasoningTokens: usage.thoughtsTokenCount || 0,
    cachedReadTokens: usage.cachedContentTokenCount || 0,
    cacheWriteTokens: 0,
    promptTokens: usage.promptTokenCount || 0,
    completionTokens: usage.candidatesTokenCount || 0,
    totalTokens: usage.totalTokenCount || 0
  };
}

function collectResponseParts(response, toolCalls, seenToolCalls = null) {
  let content = '';
  for (const candidate of response?.candidates || []) {
    for (const part of candidate.content?.parts || []) {
      if (part.text && part.thought !== true) content += part.text;
      if (!part.functionCall?.name) continue;

      const args = part.functionCall.args || {};
      const providerCallId = String(part.functionCall.id || '').trim();
      const signature = providerCallId
        || `${part.functionCall.name}:${JSON.stringify(args)}`;
      if (seenToolCalls?.has(signature)) continue;
      seenToolCalls?.add(signature);

      toolCalls.push({
        id: providerCallId
          || `call_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
        type: 'function',
        function: {
          name: part.functionCall.name,
          arguments: JSON.stringify(args),
          thought_signature: part.thoughtSignature
        }
      });
    }
  }
  return content;
}

class GoogleProvider extends BaseProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'google';
    this.models = [
      'gemini-3.5-pro',
      'gemini-3.5-flash',
      'gemini-3.1-pro',
      'gemini-3.1-flash-lite-preview',
      'gemini-2.5-pro',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-pro',
      'gemini-1.5-flash',
    ];
    this.contextWindows = {
      'gemini-3.5-pro': 2097152,
      'gemini-3.5-flash': 1048576,
      'gemini-3.1-pro': 2097152,
      'gemini-3.1-flash-lite-preview': 1048576,
      'gemini-2.5-pro': 1048576,
      'gemini-2.5-flash': 1048576,
      'gemini-2.0-flash': 1048576,
      'gemini-1.5-pro': 2097152,
      'gemini-1.5-flash': 1048576,
    };
    this.apiKey = config.apiKey || process.env.GOOGLE_AI_KEY;
    this.genAI = new GoogleGenAI({ apiKey: this.apiKey });
  }

  async listModels(signal = null) {
    const DROP = /tts|lyria|robotics|deep-research|antigravity|computer-use|-image(?!.*it)/i;
    const { response, text } = await fetchResponseText(
      'https://generativelanguage.googleapis.com/v1beta/models?pageSize=200',
      {
        headers: { 'x-goog-api-key': this.apiKey },
        maxResponseBytes: 5 * 1024 * 1024,
        serviceName: 'Google model catalog',
        signal,
      },
    );
    if (!response.ok) {
      const error = new Error(`Google models API returned ${response.status}`);
      error.status = response.status;
      error.headers = response.headers;
      throw error;
    }
    let payload;
    try {
      payload = JSON.parse(text || '{}');
    } catch {
      throw new Error('Google models API returned invalid JSON.');
    }
    const { models = [] } = payload;
    return models
      .filter((m) => {
        const id = m.name.replace('models/', '');
        return (m.supportedGenerationMethods || []).includes('generateContent')
          && !DROP.test(id);
      })
      .map((m) => {
        const id = m.name.replace('models/', '');
        this.contextWindows[id] = m.inputTokenLimit || 1048576;
        return { id, name: m.displayName || id };
      });
  }

  getContextWindow(model) {
    return this.contextWindows[model] || 1048576;
  }

  formatTools(tools) {
    const declarations = (Array.isArray(tools) ? tools : [])
      .filter((tool) => tool && typeof tool === 'object' && String(tool.name || '').trim())
      .map((tool) => ({
        name: String(tool.name).trim(),
        description: tool.description,
        parametersJsonSchema: tool.parameters || { type: 'object', properties: {} },
      }));
    return [{ functionDeclarations: declarations }];
  }

  buildGenerateConfig(systemInstruction, tools, options) {
    const config = {};
    if (systemInstruction) config.systemInstruction = systemInstruction;
    if (tools.length > 0) config.tools = this.formatTools(tools);
    if (options.signal) config.abortSignal = options.signal;
    const maxOutputTokens = Number(options.maxTokens);
    if (Number.isFinite(maxOutputTokens) && maxOutputTokens > 0) {
      config.maxOutputTokens = Math.floor(maxOutputTokens);
    }
    return config;
  }

  convertMessages(messages) {
    let systemInstruction = '';
    const history = [];

    for (const msg of messages) {
      if (msg.role === 'system') {
        systemInstruction += (systemInstruction ? '\n\n' : '') + msg.content;
        continue;
      }
      if (msg.role === 'tool') {
        const functionResponse = {
          name: msg.name || 'tool',
          response: { result: msg.content }
        };
        if (msg.tool_call_id) functionResponse.id = msg.tool_call_id;
        history.push({
          // The current Gemini API represents tool results as functionResponse
          // parts on a user turn.
          role: 'user',
          parts: [{ functionResponse }]
        });
        continue;
      }
      if (msg.role === 'assistant' && msg.tool_calls) {
        const parts = [];
        if (msg.content) parts.push({ text: msg.content });
        for (const tc of msg.tool_calls) {
          const name = tc?.function?.name || tc?.name;
          if (!name) continue;
          const functionCallPart = {
            functionCall: {
              name,
              args: parseToolArguments(tc?.function?.arguments ?? tc?.arguments)
            }
          };
          if (tc.id) functionCallPart.functionCall.id = tc.id;
          if (tc?.function?.thought_signature) {
            functionCallPart.thoughtSignature = tc.function.thought_signature;
          }
          parts.push(functionCallPart);
        }
        history.push({ role: 'model', parts });
        continue;
      }
      history.push({
        role: msg.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: msg.content || '' }]
      });
    }

    const normalizedHistory = [];
    let currentRole = null;
    let currentParts = [];

    for (const msg of history) {
      if (msg.role === currentRole) {
        currentParts.push(...msg.parts);
      } else {
        if (currentRole) {
          normalizedHistory.push({ role: currentRole, parts: currentParts });
        }
        currentRole = msg.role;
        currentParts = [...msg.parts];
      }
    }
    if (currentRole) {
      normalizedHistory.push({ role: currentRole, parts: currentParts });
    }

    // Structured helpers can consist entirely of system instructions. Gemini
    // still requires a user turn to trigger generation.
    if (
      normalizedHistory.length === 0
      || normalizedHistory[normalizedHistory.length - 1].role === 'model'
    ) {
      normalizedHistory.push({
        role: 'user',
        parts: [{ text: 'Provide the requested response using the system instructions.' }]
      });
    }

    if (normalizedHistory.length > 0 && normalizedHistory[0].role !== 'user') {
      normalizedHistory.unshift({
        role: 'user',
        parts: [{ text: '[Conversation Resumed]' }]
      });
    }

    return { systemInstruction, history: normalizedHistory };
  }

  async chat(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || this.getDefaultModel();
    const { systemInstruction, history } = this.convertMessages(messages);
    const response = await this.genAI.models.generateContent({
      model,
      contents: history,
      config: this.buildGenerateConfig(systemInstruction, tools, options)
    });
    const toolCalls = [];
    const content = collectResponseParts(response, toolCalls);
    return {
      content,
      toolCalls,
      finishReason: toolCalls.length > 0 ? 'tool_calls' : 'stop',
      usage: normalizeUsage(response.usageMetadata),
      model
    };
  }

  async *stream(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || this.getDefaultModel();
    const { systemInstruction, history } = this.convertMessages(messages);
    const responseStream = await this.genAI.models.generateContentStream({
      model,
      contents: history,
      config: this.buildGenerateConfig(systemInstruction, tools, options)
    });
    let content = '';
    const toolCalls = [];
    const seenToolCalls = new Set();
    let usage = null;

    for await (const chunk of responseStream) {
      const chunkContent = collectResponseParts(chunk, toolCalls, seenToolCalls);
      if (chunkContent) {
        content += chunkContent;
        yield { type: 'content', content: chunkContent };
      }
      if (chunk.usageMetadata) usage = chunk.usageMetadata;
    }

    yield {
      type: 'done',
      content,
      toolCalls,
      finishReason: toolCalls.length > 0 ? 'tool_calls' : 'stop',
      usage: normalizeUsage(usage),
      model
    };
  }
}

module.exports = { GoogleProvider };
