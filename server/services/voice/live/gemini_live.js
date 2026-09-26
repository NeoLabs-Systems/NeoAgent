'use strict';

const WebSocket = require('ws');
const { createServiceLogger } = require('../../../utils/logger');
const { parseMaybeJson } = require('../../../utils/text');

const logger = createServiceLogger('GeminiLiveVoice');
const DEFAULT_ORIGIN = 'https://generativelanguage.googleapis.com';
const LIVE_PATH = '/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';
const OPEN_TIMEOUT_MS = 15000;
const RUN_TASK = 'run_task';

// run_task returns at once with the task's real state. Gemini fills the silence
// of a pending (non-blocking) call by inventing an outcome, so the call never
// stays open: the outcome arrives later as a separate message.
const RUN_TASK_DECLARATION = Object.freeze({
  name: RUN_TASK,
  description: 'Start a request in the NeoAgent task runtime, which does the work with the owner\'s tools, integrations, memory, and approvals. Returns at once while the task keeps running in the background; its outcome, success or failure, arrives later as a separate message.',
  parameters: {
    type: 'OBJECT',
    properties: {
      request: {
        type: 'STRING',
        description: 'The complete, self-contained request in the owner\'s words, including every detail from the conversation the task needs.',
      },
    },
    required: ['request'],
  },
});
const TASK_STARTED = 'The task is now running in the background. Nothing is done yet: tell the owner you are on it, not that it is done. Its outcome will arrive as a separate message.';

function liveSocketUrl(baseUrl, apiKey) {
  const origin = new URL(baseUrl || DEFAULT_ORIGIN).origin.replace(/^http/i, 'ws');
  return `${origin}${LIVE_PATH}?key=${encodeURIComponent(apiKey)}`;
}

// Gemini Live has no startup history slot, so the recent thread rides along in
// the system instruction.
function withHistory(instructions, history = []) {
  if (!history.length) return instructions;
  const lines = history.map((message) => `${message.role === 'assistant' ? 'You' : 'Owner'}: ${message.text}`);
  return `${instructions}\n\nRecent conversation:\n${lines.join('\n')}`;
}

class GeminiLiveAdapter {
  constructor({ apiKey, baseUrl, model, voice, handlers }) {
    this.apiKey = apiKey;
    this.baseUrl = baseUrl;
    this.model = model;
    this.voice = voice;
    this.handlers = handlers;
    this.ws = null;
    this.closing = false;
    this.resumeHandle = null;
    this.requests = new Map();
  }

  async connect({ instructions, history, resumeHandle = null }) {
    if (!this.apiKey) {
      throw new Error('Gemini Live is selected but no Google AI API key is configured.');
    }
    this.ws = new WebSocket(liveSocketUrl(this.baseUrl, this.apiKey), {
      maxPayload: 16 * 1024 * 1024,
    });
    const ready = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error('Gemini Live did not complete setup in time.'));
        this.ws?.terminate();
      }, OPEN_TIMEOUT_MS);
      timer.unref?.();
      this.pendingSetup = {
        resolve: () => {
          clearTimeout(timer);
          resolve();
        },
        reject: (error) => {
          clearTimeout(timer);
          reject(error);
        },
      };
    });
    this.ws.on('message', (data) => this.#handleMessage(parseMaybeJson(data, {})));
    this.ws.on('error', (error) => {
      logger.warn('Socket error', error?.message || error);
      this.pendingSetup?.reject(error);
    });
    this.ws.on('close', (code, reason) => this.#handleClose(
      String(reason || '').trim() || `connection_closed_${code}`,
    ));
    this.ws.once('open', () => {
      this.#send({
        setup: {
          model: `models/${this.model}`,
          generationConfig: {
            responseModalities: ['AUDIO'],
            speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: this.voice } } },
          },
          systemInstruction: { parts: [{ text: withHistory(instructions, history) }] },
          tools: [{ functionDeclarations: [RUN_TASK_DECLARATION] }],
          inputAudioTranscription: {},
          outputAudioTranscription: {},
          sessionResumption: resumeHandle ? { handle: resumeHandle } : {},
          contextWindowCompression: { slidingWindow: {} },
        },
      });
    });
    await ready;
  }

  appendAudio(pcm) {
    this.#send({
      realtimeInput: { audio: { mimeType: 'audio/pcm;rate=16000', data: pcm.toString('base64') } },
    });
  }

  endInput() {
    this.#send({ realtimeInput: { audioStreamEnd: true } });
  }

  say(text) {
    this.#clientText(`Tell the owner now, in your own words:\n${text}`, true);
  }

  note(text) {
    this.#clientText(`Context update (do not read aloud unless it becomes relevant):\n${text}`, false);
  }

  acknowledgeTask(_handle, text) {
    this.note(text);
  }

  taskProgress(handle, text, { speak = false } = {}) {
    const labelled = this.#forTask(handle, text);
    if (speak) this.say(labelled);
    else this.note(labelled);
  }

  completeTask(handle, text) {
    this.say(this.#forTask(handle, `The task finished. Its outcome:\n${text}`));
    this.requests.delete(handle);
  }

  async close() {
    this.closing = true;
    const ws = this.ws;
    if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
      ws.close(1000);
    }
  }

  #forTask(handle, text) {
    const request = this.requests.get(handle);
    return request ? `Task "${request}": ${text}` : text;
  }

  #clientText(text, turnComplete) {
    this.#send({
      clientContent: { turns: [{ role: 'user', parts: [{ text }] }], turnComplete },
    });
  }

  #send(message) {
    if (this.ws?.readyState !== WebSocket.OPEN) return false;
    this.ws.send(JSON.stringify(message));
    return true;
  }

  #handleMessage(message) {
    if (message.setupComplete) {
      this.pendingSetup?.resolve();
      this.pendingSetup = null;
    }
    if (message.sessionResumptionUpdate?.resumable && message.sessionResumptionUpdate.newHandle) {
      this.resumeHandle = message.sessionResumptionUpdate.newHandle;
    }
    const content = message.serverContent;
    if (content) {
      if (content.inputTranscription?.text) {
        this.handlers.onInputTranscript(content.inputTranscription.text);
      }
      for (const part of content.modelTurn?.parts || []) {
        if (part.inlineData?.data) this.handlers.onAudio(Buffer.from(part.inlineData.data, 'base64'));
      }
      if (content.outputTranscription?.text) {
        this.handlers.onOutputTranscript(content.outputTranscription.text);
      }
      if (content.interrupted) this.handlers.onInterrupted();
      if (content.turnComplete) this.handlers.onTurnComplete();
    }
    for (const call of message.toolCall?.functionCalls || []) {
      if (call.name !== RUN_TASK || !call.id) continue;
      const request = String(call.args?.request || '');
      this.requests.set(call.id, request);
      this.#send({
        toolResponse: {
          functionResponses: [{ id: call.id, name: RUN_TASK, response: { result: TASK_STARTED } }],
        },
      });
      this.handlers.onDelegation({ handle: call.id, request });
    }
    if (message.goAway) {
      this.#handleClose('go_away');
      this.ws?.close(1000);
    }
    if (message.error) {
      const error = new Error(message.error.message || 'Gemini Live reported an error.');
      if (this.pendingSetup) {
        this.pendingSetup.reject(error);
        this.pendingSetup = null;
      } else {
        this.handlers.onError(error);
      }
    }
  }

  // A connection that never completed setup is reported through connect()'s
  // rejection, not as a dropped session.
  #handleClose(reason) {
    const neverStarted = Boolean(this.pendingSetup);
    if (neverStarted) {
      this.pendingSetup.reject(new Error(`Gemini Live closed before setup completed (${reason}).`));
      this.pendingSetup = null;
    }
    if (this.closing || neverStarted) return;
    this.closing = true;
    this.handlers.onClosed({ reason, resumeHandle: this.resumeHandle });
  }
}

module.exports = {
  GeminiLiveAdapter,
  RUN_TASK_DECLARATION,
};
