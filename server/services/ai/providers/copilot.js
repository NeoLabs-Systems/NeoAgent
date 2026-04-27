const crypto = require('crypto');
const { CopilotClient, approveAll } = require('@github/copilot-sdk');
const { BaseProvider } = require('./base');

let fallbackToolCallCounter = 0;

function createUniqueToolCallId(toolName = 'tool') {
  const normalizedName =
    String(toolName || 'tool').trim().replace(/\s+/g, '_') || 'tool';
  if (typeof crypto.randomUUID === 'function') {
    return `${normalizedName}-${crypto.randomUUID()}`;
  }
  fallbackToolCallCounter += 1;
  return `${normalizedName}-${Date.now()}-${fallbackToolCallCounter}`;
}

function normalizePromptText(content) {
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (!part || typeof part !== 'object') return '';
        if (part.type === 'text') {
          return String(part.text ?? part.content ?? '').trim();
        }
        if (typeof part.text === 'string') return part.text.trim();
        if (typeof part.content === 'string') return part.content.trim();
        return '';
      })
      .filter(Boolean)
      .join(' ');
  }

  if (content == null) return '';
  if (typeof content === 'string') return content;
  if (typeof content === 'object') {
    if (typeof content.text === 'string') return content.text;
    if (typeof content.content === 'string') return content.content;
  }
  return String(content);
}

function serializeToolInput(eventData = {}) {
  const input = eventData.arguments ?? eventData.input ?? eventData.args ?? eventData.toolInput ?? {};
  if (typeof input === 'string') return input;
  try {
    return JSON.stringify(input);
  } catch {
    return String(input);
  }
}

class CopilotProvider extends BaseProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'copilot';
    this.models = [
      'gpt-5',
      'gpt-4.1',
      'claude-sonnet-4.5',
      'claude-3-5-sonnet-20241022',
      'o3',
      'o4-mini'
    ];
    this.contextWindows = {
      'gpt-5': 400000,
      'gpt-4.1': 1048576,
      'claude-sonnet-4.5': 200000,
      'claude-3-5-sonnet-20241022': 200000,
      'o3': 200000,
      'o4-mini': 200000
    };
    this.gitHubToken = config.gitHubToken || process.env.COPILOT_GITHUB_TOKEN || process.env.GH_TOKEN || process.env.GITHUB_TOKEN || null;
    this.cliPath = config.cliPath || null;
    this.cliUrl = config.cliUrl || null;
    this._client = null;
    this._clientPromise = null;
    this._session = null;
  }

  _createClient() {
    const options = {
      autoStart: false,
      useLoggedInUser: !this.gitHubToken,
    };
    if (this.gitHubToken) {
      options.gitHubToken = this.gitHubToken;
      options.useLoggedInUser = false;
    }
    if (this.cliPath) {
      options.cliPath = this.cliPath;
    }
    if (this.cliUrl) {
      options.cliUrl = this.cliUrl;
    }
    return new CopilotClient(options);
  }

  async _ensureClient() {
    if (this._client) {
      return this._client;
    }

    if (!this._clientPromise) {
      this._clientPromise = (async () => {
        const client = this._createClient();
        await client.start();
        this._client = client;
        return client;
      })().catch((error) => {
        this._clientPromise = null;
        throw error;
      });
    }

    return this._clientPromise;
  }

  async _createSession(model, tools = []) {
    const client = await this._ensureClient();
    if (this._session) {
      try {
        await this._session.disconnect();
      } catch (_) {}
    }

    const sessionConfig = {
      model: model || this.getDefaultModel(),
      onPermissionRequest: approveAll,
      streaming: true,
    };

    if (tools && tools.length > 0) {
      const { defineTool } = require('@github/copilot-sdk');
      sessionConfig.tools = tools.map((tool) =>
        defineTool(tool.name, {
          description: tool.description || '',
          parameters: tool.parameters || { type: 'object', properties: {} },
          handler: async (args, context) => {
            if (typeof tool.handler === 'function') {
              return await tool.handler(args, context);
            }
            if (typeof tool.execute === 'function') {
              return await tool.execute(args, context);
            }
            throw new Error(`Tool ${tool.name} does not expose a handler or execute function.`);
          }
        })
      );
    }

    this._session = await client.createSession(sessionConfig);
    return this._session;
  }

  getDefaultModel() {
    return 'gpt-5';
  }

  getContextWindow(model) {
    for (const [id, size] of Object.entries(this.contextWindows)) {
      if (model === id || model.startsWith(id + '-')) return size;
    }
    return 200000;
  }

  supportsVision() {
    return true;
  }

  getDefaultVisionModel() {
    return 'gpt-4.1';
  }

  async chat(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || this.getDefaultModel();
    const session = await this._createSession(model, tools);

    const fullPrompt = this._buildPromptFromMessages(messages);

    return new Promise((resolve, reject) => {
      let content = '';
      let toolCalls = [];
      let done = false;

      const handleMessage = (event) => {
        if (done) return;
        const delta = String(event?.data?.deltaContent || '');
        if (delta) content += delta;
      };

      const handleMessageComplete = (event) => {
        if (done) return;
        content = event?.data?.content || content;
      };

      const handleToolComplete = (event) => {
        if (done) return;
        const tc = {
          id: event?.data?.toolCallId || createUniqueToolCallId(event?.data?.toolName),
          type: 'function',
          function: {
            name: event?.data?.toolName || '',
            arguments: serializeToolInput(event?.data),
          }
        };
        toolCalls.push(tc);
      };

      const handleIdle = () => {
        if (done) return;
        done = true;
        cleanup();
        resolve({
          content,
          toolCalls,
          finishReason: 'stop',
          usage: null,
          model
        });
      };

      const handleError = (err) => {
        if (!done) {
          done = true;
          cleanup();
          reject(err?.error || err);
        }
      };

      const cleanup = () => {
        session.off('assistant.message_delta', handleMessage);
        session.off('assistant.message', handleMessageComplete);
        session.off('tool.execution_complete', handleToolComplete);
        session.off('session.idle', handleIdle);
        session.off('session.error', handleError);
      };

      session.on('assistant.message_delta', handleMessage);
      session.on('assistant.message', handleMessageComplete);
      session.on('tool.execution_complete', handleToolComplete);
      session.on('session.idle', handleIdle);
      session.on('session.error', handleError);

      session.sendAndWait({ prompt: fullPrompt }, 120000).catch(handleError);
    });
  }

  _buildPromptFromMessages(messages) {
    return messages.map((m) => {
      const content = normalizePromptText(m.content);
      if (m.role === 'system') {
        return `System: ${content}`;
      }
      return `${m.role === 'user' ? 'User' : 'Assistant'}: ${content}`;
    }).join('\n\n');
  }

  async *stream(messages, tools = [], options = {}) {
    const model = options.model || this.config.model || this.getDefaultModel();
    const session = await this._createSession(model, tools);

    const fullPrompt = this._buildPromptFromMessages(messages);
    let content = '';
    let toolCalls = [];
    let done = false;
    let sendError = null;
    const pendingYields = [];
    let resolveNext = null;

    const handleDelta = (event) => {
      if (done) return;
      const delta = String(event?.data?.deltaContent || '');
      if (delta) {
        content += delta;
        pendingYields.push({ type: 'content', content: delta });
      }
      if (resolveNext) {
        resolveNext();
        resolveNext = null;
      }
    };

    const handleReasoningDelta = (event) => {
      if (done) return;
      const delta = String(event?.data?.deltaContent || '');
      if (delta) {
        pendingYields.push({ type: 'reasoning', content: delta });
      }
      if (resolveNext) {
        resolveNext();
        resolveNext = null;
      }
    };

    const handleToolStart = (event) => {
      if (done) return;
      const eventData = event?.data && typeof event.data === 'object'
        ? event.data
        : {};
      const toolName = String(eventData.toolName || '');
      const originalMissingId = !eventData.toolCallId;
      const toolCallId = originalMissingId
        ? createUniqueToolCallId(toolName)
        : String(eventData.toolCallId);
      if (originalMissingId) {
        eventData._fallbackToolCallId = toolCallId;
      }

      toolCalls.push({
        id: toolCallId,
        type: 'function',
        originalMissingId,
        completed: false,
        function: {
          name: toolName,
          arguments: serializeToolInput(eventData),
        }
      });
    };

    const handleToolComplete = (event) => {
      if (done) return;
      const eventData = event?.data && typeof event.data === 'object'
        ? event.data
        : {};
      const explicitId = String(eventData.toolCallId || '').trim();
      const fallbackId = String(eventData._fallbackToolCallId || '').trim();
      const toolName = String(eventData.toolName || '');

      let idx = -1;
      if (explicitId) {
        idx = toolCalls.findIndex((tc) => tc.id === explicitId);
      } else if (fallbackId) {
        idx = toolCalls.findIndex((tc) => tc.id === fallbackId);
      }

      if (idx < 0 && !explicitId) {
        for (let i = toolCalls.length - 1; i >= 0; i -= 1) {
          const call = toolCalls[i];
          const nameMatches = !toolName || call.function?.name === toolName;
          if (call.originalMissingId && !call.completed && nameMatches) {
            idx = i;
            break;
          }
        }
      }

      if (idx >= 0) {
        toolCalls[idx].function.arguments = serializeToolInput(eventData);
        toolCalls[idx].completed = true;
      }
    };

    const handleIdle = () => {
      if (done) return;
      done = true;
      pendingYields.push({
        type: 'done',
        content,
        toolCalls: toolCalls.filter((tc) => tc.id),
        finishReason: 'stop',
        usage: null
      });
      if (resolveNext) {
        resolveNext();
        resolveNext = null;
      }
    };

    const handleSessionError = (err) => {
      if (done) return;
      sendError = err?.error || err || new Error('Copilot session error');
      done = true;
      if (resolveNext) {
        resolveNext();
        resolveNext = null;
      }
    };

    session.on('assistant.message_delta', handleDelta);
    session.on('assistant.reasoning_delta', handleReasoningDelta);
    session.on('tool.execution_start', handleToolStart);
    session.on('tool.execution_complete', handleToolComplete);
    session.on('session.idle', handleIdle);
    session.on('session.error', handleSessionError);

    try {
      session.sendAndWait({ prompt: fullPrompt }, 120000).catch((err) => {
        sendError = err?.error || err;
        done = true;
        if (resolveNext) {
          resolveNext();
          resolveNext = null;
        }
      });

      while (pendingYields.length > 0 || !done) {
        if (pendingYields.length > 0) {
          yield pendingYields.shift();
        } else {
          await new Promise((r) => {
            resolveNext = r;
            setTimeout(r, 25);
          });
        }
      }

      if (sendError) {
        throw sendError;
      }
    } finally {
      session.off('assistant.message_delta', handleDelta);
      session.off('assistant.reasoning_delta', handleReasoningDelta);
      session.off('tool.execution_start', handleToolStart);
      session.off('tool.execution_complete', handleToolComplete);
      session.off('session.idle', handleIdle);
      session.off('session.error', handleSessionError);
    }
  }

  async analyzeImage(options = {}) {
    const model = options.model || this.getDefaultVisionModel();
    const b64 = BaseProvider.readImageAsBase64(options.imagePath);

    const messages = [{
      role: 'user',
      content: [
        { type: 'text', text: options.question || 'Describe this image in detail.' },
        { type: 'image_url', image_url: { url: `data:${options.mimeType || 'image/jpeg'};base64,${b64}` } }
      ]
    }];

    const result = await this.chat(messages, [], { model });
    return {
      content: result.content,
      model
    };
  }

  async stop() {
    if (this._session) {
      try {
        await this._session.disconnect();
      } catch (_) {}
      this._session = null;
    }
    if (this._client) {
      try {
        await this._client.stop();
      } catch (_) {}
      this._client = null;
    }
    this._clientPromise = null;
  }
}

module.exports = { CopilotProvider };