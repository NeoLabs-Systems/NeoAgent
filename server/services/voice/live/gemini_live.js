'use strict';

const WebSocket = require('ws');
const { createServiceLogger } = require('../../../utils/logger');
const { parseMaybeJson } = require('../../../utils/text');

const logger = createServiceLogger('GeminiLiveVoice');
const DEFAULT_ORIGIN = 'https://generativelanguage.googleapis.com';
const LIVE_PATH = '/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';
const OPEN_TIMEOUT_MS = 15000;
const RUN_TASK = 'run_task';

const RUN_TASK_DECLARATION = Object.freeze({
  name: RUN_TASK,
  description: 'Hand a request to the NeoAgent task runtime, which does the work with the owner\'s tools, integrations, memory, and approvals. Runs in the background; the result arrives later as this call\'s response.',
  behavior: 'NON_BLOCKING',
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
    this.openCalls = new Set();
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

  acknowledgeTask(handle, text) {
    this.#respond(handle, text, 'SILENT');
  }

  taskProgress(_handle, text, { speak = false } = {}) {
    if (speak) this.say(text);
    else this.note(text);
  }

  // A call the model cancelled, or one opened on an earlier connection, can no
  // longer take a function response; its result is spoken as a new turn.
  completeTask(handle, text) {
    if (!this.#respond(handle, text, 'WHEN_IDLE')) this.say(text);
  }

  async close() {
    this.closing = true;
    const ws = this.ws;
    if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
      ws.close(1000);
    }
  }

  #respond(handle, text, scheduling) {
    if (!this.openCalls.delete(handle)) return false;
    return this.#send({
      toolResponse: {
        functionResponses: [{
          id: handle,
          name: RUN_TASK,
          response: { result: String(text || ''), scheduling },
        }],
      },
    });
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
      this.openCalls.add(call.id);
      this.handlers.onDelegation({ handle: call.id, request: String(call.args?.request || '') });
    }
    for (const id of message.toolCallCancellation?.ids || []) {
      this.openCalls.delete(id);
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
