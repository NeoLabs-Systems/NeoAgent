'use strict';

const WebSocket = require('ws');
const { requireApiKey } = require('./providers/credentials');

const FINAL_TIMEOUT_MS = 15000;
const OPEN_TIMEOUT_MS = 15000;
const MAX_BUFFERED_AMOUNT = 1024 * 1024;

function parseJson(value) {
  try {
    return JSON.parse(String(value || ''));
  } catch {
    return {};
  }
}

class StreamingSttAdapter {
  constructor({ provider }) {
    this.provider = provider;
    this.session = null;
    this.ws = null;
    this.finalTranscript = '';
    this.partialTranscript = '';
    this.finalWaiter = null;
  }

  async open(session) {
    this.session = session;
    const descriptor = this.#connectionDescriptor(session);
    this.ws = new WebSocket(descriptor.url, {
      headers: descriptor.headers,
      maxPayload: 16 * 1024 * 1024,
    });
    this.ws.on('message', (data) => { void this.#handleMessage(data); });
    this.ws.on('close', () => this.#rejectFinal(new Error(`${this.provider} STT disconnected.`)));
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`${this.provider} STT connection timed out.`)), OPEN_TIMEOUT_MS);
      timer.unref?.();
      this.ws.once('open', () => {
        clearTimeout(timer);
        resolve();
      });
      this.ws.once('error', (error) => {
        clearTimeout(timer);
        reject(error);
      });
    });
    if (this.provider === 'openai') {
      this.#sendJson({
        type: 'session.update',
        session: {
          type: 'transcription',
          audio: {
            input: {
              format: { type: 'audio/pcm', rate: session.voiceSettings.inputSampleRate },
              transcription: { model: session.voiceSettings.sttModel },
              turn_detection: null,
            },
          },
        },
      });
    }
  }

  async onInputStart(session, options = {}) {
    session.startTurn(options.turnId, options.mimeType);
    this.finalTranscript = '';
    this.partialTranscript = '';
    this.finalWaiter = null;
    if (this.provider === 'openai') this.#sendJson({ type: 'input_audio_buffer.clear' });
  }

  async appendAudioChunk(session, audioBytes, options = {}) {
    const result = session.appendInputChunk(audioBytes, options.mimeType, {
      turnId: options.turnId,
      sequence: options.sequence,
    });
    if ((this.ws?.bufferedAmount || 0) > MAX_BUFFERED_AMOUNT) {
      const error = new Error(`${this.provider} STT backpressure limit reached.`);
      error.code = 'VOICE_PROVIDER_BACKPRESSURE';
      throw error;
    }
    if (this.provider === 'openai') {
      this.#sendJson({
        type: 'input_audio_buffer.append',
        audio: Buffer.from(audioBytes).toString('base64'),
      });
    } else {
      this.ws.send(Buffer.from(audioBytes));
    }
    return result;
  }

  async commitInput(session, options = {}) {
    const commit = session.markCommitPending(options.turnId, options.finalSequence);
    if (!commit.ready) {
      throw new Error(
        `Voice input is incomplete for commit (${commit.receivedThrough}/${commit.finalSequence}).`,
      );
    }
    const promise = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.finalWaiter = null;
        reject(new Error(`${this.provider} STT final transcript timed out.`));
      }, FINAL_TIMEOUT_MS);
      timer.unref?.();
      this.finalWaiter = {
        resolve: (text) => {
          clearTimeout(timer);
          this.finalWaiter = null;
          resolve(text);
        },
        reject: (error) => {
          clearTimeout(timer);
          this.finalWaiter = null;
          reject(error);
        },
      };
    });
    if (this.provider === 'openai') this.#sendJson({ type: 'input_audio_buffer.commit' });
    else this.#sendJson({ type: 'Finalize' });
    try {
      return await promise;
    } finally {
      session.resetInput(session.inputMimeType);
    }
  }

  async interruptOutput() {}

  async close() {
    this.#rejectFinal(new Error(`${this.provider} STT session closed.`));
    const ws = this.ws;
    this.ws = null;
    if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
      ws.close(1000, 'voice STT session closed');
    }
  }

  #connectionDescriptor(session) {
    if (this.provider === 'openai') {
      const key = requireApiKey('OpenAI STT', ['OPENAI_API_KEY'], session.voiceSettings.sttApiKey);
      const base = String(session.voiceSettings.sttBaseUrl || 'https://api.openai.com/v1')
        .replace(/^https:/i, 'wss:')
        .replace(/^http:/i, 'ws:')
        .replace(/\/$/, '');
      return {
        url: `${base}/realtime?intent=transcription`,
        headers: { Authorization: `Bearer ${key}`, 'OpenAI-Beta': 'realtime=v1' },
      };
    }
    const key = requireApiKey('Deepgram STT', ['DEEPGRAM_API_KEY'], session.voiceSettings.sttApiKey);
    const query = new URLSearchParams({
      model: session.voiceSettings.sttModel,
      encoding: 'linear16',
      sample_rate: String(session.voiceSettings.inputSampleRate),
      channels: '1',
      language: 'multi',
      smart_format: 'true',
      interim_results: 'true',
      endpointing: 'false',
    });
    return {
      url: `wss://api.deepgram.com/v1/listen?${query}`,
      headers: { Authorization: `Token ${key}` },
    };
  }

  async #handleMessage(data) {
    const event = parseJson(data);
    if (this.provider === 'openai') {
      if (event.type === 'conversation.item.input_audio_transcription.delta') {
        this.partialTranscript += String(event.delta || '');
        await this.session.publishTranscriptPartial(this.partialTranscript, {
          turnId: this.session.activeTurnId,
        });
      } else if (event.type === 'conversation.item.input_audio_transcription.completed') {
        this.#resolveFinal(event.transcript);
      } else if (event.type === 'error') {
        this.#rejectFinal(new Error(event.error?.message || 'OpenAI STT failed.'));
      }
      return;
    }
    if (event.type === 'Results') {
      const transcript = String(event.channel?.alternatives?.[0]?.transcript || '').trim();
      if (!transcript) return;
      this.partialTranscript = transcript;
      await this.session.publishTranscriptPartial(transcript, {
        turnId: this.session.activeTurnId,
      });
      if (event.is_final || event.speech_final || event.from_finalize) this.#resolveFinal(transcript);
    } else if (event.type === 'Error') {
      this.#rejectFinal(new Error(event.description || 'Deepgram STT failed.'));
    }
  }

  #sendJson(event) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error(`${this.provider} STT connection is not open.`);
    }
    this.ws.send(JSON.stringify(event));
  }

  #resolveFinal(value) {
    this.finalTranscript = String(value || this.partialTranscript || '').trim();
    this.finalWaiter?.resolve(this.finalTranscript);
  }

  #rejectFinal(error) {
    this.finalWaiter?.reject(error);
  }
}

module.exports = {
  StreamingSttAdapter,
};
