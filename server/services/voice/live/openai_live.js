'use strict';

const WebSocket = require('ws');
const { createServiceLogger } = require('../../../utils/logger');
const { parseMaybeJson } = require('../../../utils/text');
const { splitForAppend } = require('./text_chunks');

const logger = createServiceLogger('OpenAILiveVoice');
const OPEN_TIMEOUT_MS = 15000;
const SAMPLE_RATE = 24000;
// GPT-Live advances its conversation timeline with the audio it receives, so a
// push-to-talk release or a stalled microphone stream is filled with silence
// to let it hear the end of the turn. The gap threshold stays well above any
// microphone chunk interval so real speech is never split.
const SILENCE_TICK_MS = 100;
const SILENCE_GAP_MS = 500;
const SILENCE_FRAME = Buffer.alloc((SAMPLE_RATE * 2 * SILENCE_TICK_MS) / 1000);
// Startup history is capped by the API at 128 messages and 8,192 tokens.
const MAX_STARTUP_HISTORY_CHARS = 24000;
const MAX_APPEND_CHARS = 1800;

function liveSocketUrl(baseUrl) {
  const base = String(baseUrl || 'https://api.openai.com/v1').trim()
    .replace(/^https:/i, 'wss:')
    .replace(/^http:/i, 'ws:')
    .replace(/\/$/, '');
  return `${base}/live/sessions`;
}

function startupInput(history = []) {
  const items = [];
  let budget = MAX_STARTUP_HISTORY_CHARS;
  for (const message of [...history].reverse()) {
    budget -= message.text.length;
    if (budget < 0 || items.length >= 128) break;
    items.unshift({
      type: 'message',
      role: message.role,
      content: [{
        type: message.role === 'assistant' ? 'output_text' : 'input_text',
        text: message.text,
      }],
    });
  }
  return items;
}

class OpenAiLiveAdapter {
  constructor({ apiKey, baseUrl, model, voice, handlers }) {
    this.apiKey = apiKey;
    this.baseUrl = baseUrl;
    this.model = model;
    this.voice = voice;
    this.handlers = handlers;
    this.ws = null;
    this.closing = false;
    this.lastAudioAt = 0;
    this.inputEnded = false;
    this.silenceTimer = null;
    this.delegations = new Set();
  }

  async connect({ instructions, history }) {
    if (!this.apiKey) {
      throw new Error('GPT-Live is selected but no OpenAI API key is configured.');
    }
    this.ws = new WebSocket(liveSocketUrl(this.baseUrl), {
      headers: { Authorization: `Bearer ${this.apiKey}` },
      maxPayload: 16 * 1024 * 1024,
    });
    const started = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error('GPT-Live did not start the session in time.'));
        this.ws?.terminate();
      }, OPEN_TIMEOUT_MS);
      timer.unref?.();
      this.pendingStart = {
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
    this.ws.on('message', (data) => this.#handleEvent(parseMaybeJson(data, {})));
    this.ws.on('error', (error) => {
      logger.warn('Socket error', error?.message || error);
      this.pendingStart?.reject(error);
    });
    this.ws.on('close', () => this.#handleClose('connection_lost'));
    this.ws.once('open', () => {
      this.#send({
        type: 'session.start',
        session: {
          model: this.model,
          instructions,
          input: startupInput(history),
          audio: { output: { voice: this.voice } },
          delegation: { type: 'client' },
        },
      });
    });
    await started;
    this.silenceTimer = setInterval(() => this.#fillSilence(), SILENCE_TICK_MS);
    this.silenceTimer.unref?.();
  }

  appendAudio(pcm) {
    this.lastAudioAt = Date.now();
    this.inputEnded = false;
    this.#send({ type: 'session.input_audio.append', audio: pcm.toString('base64') });
  }

  startInput() {
    this.inputEnded = false;
  }

  endInput() {
    this.inputEnded = true;
  }

  say(text) {
    this.#append('session.commentary.append', null, text);
  }

  note(text) {
    this.#append('session.thinking.append', null, text);
  }

  // A hand-off from an earlier connection is unknown to this session, so its
  // updates go in as general context instead.
  acknowledgeTask(handle, text) {
    this.#append('session.thinking.append', this.#known(handle), text);
  }

  taskProgress(handle, text, { speak = false } = {}) {
    this.#append(speak ? 'session.commentary.append' : 'session.thinking.append', this.#known(handle), text);
  }

  completeTask(handle, text) {
    this.#append('session.commentary.append', this.#known(handle), text);
  }

  async close() {
    this.closing = true;
    clearInterval(this.silenceTimer);
    const ws = this.ws;
    if (!ws) return;
    if (ws.readyState === WebSocket.OPEN) {
      this.#send({ type: 'session.close' });
      setTimeout(() => ws.close(1000), 1000).unref?.();
    } else if (ws.readyState === WebSocket.CONNECTING) {
      ws.terminate();
    }
  }

  #known(handle) {
    return this.delegations.has(handle) ? handle : null;
  }

  #fillSilence() {
    if (!this.inputEnded && Date.now() - this.lastAudioAt < SILENCE_GAP_MS) return;
    this.#send({ type: 'session.input_audio.append', audio: SILENCE_FRAME.toString('base64') });
  }

  #append(type, delegationId, text) {
    for (const content of splitForAppend(text, MAX_APPEND_CHARS)) {
      this.#send({ type, delegation_id: delegationId, content });
    }
  }

  #send(event) {
    if (this.ws?.readyState !== WebSocket.OPEN) return false;
    this.ws.send(JSON.stringify(event));
    return true;
  }

  #handleEvent(event) {
    switch (event?.type) {
      case 'session.started':
        this.pendingStart?.resolve();
        this.pendingStart = null;
        return;
      case 'session.output_audio.delta':
        if (event.delta) this.handlers.onAudio(Buffer.from(event.delta, 'base64'));
        return;
      case 'session.input_transcript.delta':
        this.handlers.onInputTranscript(String(event.delta || ''));
        return;
      case 'session.output_transcript.delta':
        this.handlers.onOutputTranscript(String(event.delta || ''));
        return;
      case 'session.delegation.created':
        if (event.delegation?.target === 'client' && event.delegation.id) {
          this.delegations.add(event.delegation.id);
          this.handlers.onDelegation({ handle: event.delegation.id, request: '' });
        }
        return;
      case 'session.closed':
        this.#handleClose(event.reason || 'closed');
        return;
      case 'error': {
        const error = new Error(event.error?.message || 'GPT-Live reported an error.');
        error.code = event.error?.code;
        if (this.pendingStart) {
          this.pendingStart.reject(error);
          this.pendingStart = null;
          return;
        }
        this.handlers.onError(error);
        return;
      }
      default:
    }
  }

  // A connection that never started is reported through connect()'s rejection,
  // not as a dropped session.
  #handleClose(reason) {
    clearInterval(this.silenceTimer);
    const neverStarted = Boolean(this.pendingStart);
    if (neverStarted) {
      this.pendingStart.reject(new Error(`GPT-Live closed before the session started (${reason}).`));
      this.pendingStart = null;
    }
    if (this.closing || neverStarted) return;
    this.closing = true;
    this.handlers.onClosed({ reason });
  }
}

module.exports = {
  OpenAiLiveAdapter,
};
