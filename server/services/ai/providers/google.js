const { GoogleGenerativeAI } = require('@google/generative-ai');
const { BaseProvider } = require('./base');

class GoogleProvider extends BaseProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'google';
    this.models = [
      'gemini-2.0-flash',
      'gemini-2.0-pro',
      'gemini-1.5-pro',
      'gemini-1.5-flash',
      'gemini-3.1-flash-lite-preview'
    ];
    this.contextWindows = {
      'gemini-2.0-flash': 1048576,
      'gemini-2.0-pro': 2097152,
      'gemini-1.5-pro': 2097152,
      'gemini-1.5-flash': 1048576,
      'gemini-3.1-flash-lite-preview': 1048576
    };
    this.genAI = new GoogleGenerativeAI(config.apiKey || process.env.GOOGLE_AI_KEY);
  }

  getContextWindow(model) {
    return this.contextWindows[model] || 1048576;
  }

  formatTools(tools) {
    return [{
      functionDeclarations: tools.map(tool => ({
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters || { type: 'object', properties: {} }
      }))
    }];
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
        history.push({
          role: 'function',
          parts: [{
            functionResponse: {
              name: msg.name || 'tool',
              response: { result: msg.content }
            }
          }]
        });
        continue;
      }
      if (msg.role === 'assistant' && msg.tool_calls) {
        const parts = [];
        if (msg.content) parts.push({ text: msg.content });
        for (const tc of msg.tool_calls) {
          const functionCallPart = {
            functionCall: {
              name: tc.function.name,
              args: JSON.parse(tc.function.arguments || '{}')
            }
          };
          if (tc.function.thought_signature) {
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

    const genModel = this.genAI.getGenerativeModel({
      model,
      systemInstruction: systemInstruction || undefined,
      tools: tools.length > 0 ? this.formatTools(tools) : undefined
    });

    const lastMessage = history.pop();
    const chat = genModel.startChat({ history });
    const result = await chat.sendMessage(lastMessage.parts);
    const response = result.response;

    let content = '';
    const toolCalls = [];

    for (const candidate of response.candidates || []) {
      for (const part of candidate.content?.parts || []) {
        if (part.text) content += part.text;
        if (part.functionCall) {
          toolCalls.push({
            id: `call_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
            type: 'function',
            function: {
              name: part.functionCall.name,
              arguments: JSON.stringify(part.functionCall.args || {}),
              thought_signature: part.thoughtSignature
            }
          });
        }
      }
    }

    const usage = response.usageMetadata;
    return {
      content,
      toolCalls,
      finishReason: toolCalls.length > 0 ? 'tool_calls' : 'stop',
      usage: usage ? {
        promptTokens: usage.promptTokenCount || 0,
        completionTokens: usage.candidatesTokenCount || 0,
        totalTokens: usage.totalTokenCount || 0
      } : null,
      model
    };
  }

  async *stream(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || this.getDefaultModel();
    const { systemInstruction, history } = this.convertMessages(messages);

    const genModel = this.genAI.getGenerativeModel({
      model,
      systemInstruction: systemInstruction || undefined,
      tools: tools.length > 0 ? this.formatTools(tools) : undefined
    });

    const lastMessage = history.pop();
    const chat = genModel.startChat({ history });
    const result = await chat.sendMessageStream(lastMessage.parts);

    let content = '';
    const toolCalls = [];

    for await (const chunk of result.stream) {
      const text = chunk.text();
      if (text) {
        content += text;
        yield { type: 'content', content: text };
      }

      for (const candidate of chunk.candidates || []) {
        for (const part of candidate.content?.parts || []) {
          if (part.functionCall) {
            toolCalls.push({
              id: `call_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
              type: 'function',
              function: {
                name: part.functionCall.name,
                arguments: JSON.stringify(part.functionCall.args || {}),
                thought_signature: part.thoughtSignature
              }
            });
          }
        }
      }
    }

    const finalResponse = await result.response;
    const usage = finalResponse.usageMetadata;

    yield {
      type: 'done',
      content,
      toolCalls,
      finishReason: toolCalls.length > 0 ? 'tool_calls' : 'stop',
      usage: usage ? {
        promptTokens: usage.promptTokenCount || 0,
        completionTokens: usage.candidatesTokenCount || 0,
        totalTokens: usage.totalTokenCount || 0
      } : null
    };
  }
}

module.exports = { GoogleProvider };
