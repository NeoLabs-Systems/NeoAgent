'use strict';

const WebSocket = require('ws');
const { createServiceLogger } = require('../../../utils/logger');
const { wrapPcmAsWav } = require('../shared_audio');
const {
  NEOAGENT_TURN_TOOL,
  SHELL_INSTRUCTIONS,
  buildRealtimeSessionUpdate,
  parseJson,
} = require('./openai_realtime_contract');
const { OpenAiNeoAgentBridge } = require('./openai_neoagent_bridge');

const logger = createServiceLogger('OpenAIRealtimeVoice');
const MAX_BUFFERED_AMOUNT = 1024 * 1024;
const OPEN_TIMEOUT_MS = 15000;

class OpenAiRealtimeShell {
  constructor({ config, runtimeManager }) {
    this.config = config;
    this.runtimeManager = runtimeManager;
    this.session = null;
    this.ws = null;
    this.openPromise = null;
    this.closed = false;
    this.responseContexts = new Map();
    this.bridge = null;
    this.committedTurnId = '';
  }

  async open(session) {
    this.session = session;
    this.closed = false;
    const apiKey = String(session.voiceSettings?.duplexApiKey || '').trim();
    if (!apiKey) {
      throw new Error('OpenAI duplex voice is selected but OPENAI_API_KEY is not configured.');
    }
    const baseUrl = String(session.voiceSettings?.duplexBaseUrl || 'https://api.openai.com/v1').trim();
    const wsBase = baseUrl
      .replace(/^https:/i, 'wss:')
      .replace(/^http:/i, 'ws:')
      .replace(/\/$/, '');
    const url = `${wsBase}/realtime?model=${encodeURIComponent(this.config.duplexModel)}`;
    this.ws = new WebSocket(url, {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'OpenAI-Beta': 'realtime=v1',
      },
      maxPayload: 16 * 1024 * 1024,
    });
    this.ws.on('message', (data) => this.#handleEvent(parseJson(data, {})));
    this.ws.on('error', (error) => this.#handleSocketError(error));
    this.ws.on('close', () => this.#handleSocketClose());
    this.openPromise = this.#waitForOpen();
    await this.openPromise;
    this.bridge = new OpenAiNeoAgentBridge({
      session,
      runtimeManager: this.runtimeManager,
      send: (event) => this.#send(event),
      getTurnId: () => this.committedTurnId || session.currentTurnId,
      isActive: () => !this.closed && session.adapter === this,
    });
    this.#send(buildRealtimeSessionUpdate(this.config));
  }

  async onInputStart(session, options = {}) {
    session.startTurn(options.turnId, options.mimeType);
    this.#send({ type: 'response.cancel' }, { allowClosed: true });
    this.#send({ type: 'input_audio_buffer.clear' });
  }

  async appendAudioChunk(session, audioBytes, options = {}) {
    const result = session.appendInputChunk(audioBytes, options.mimeType, {
      turnId: options.turnId,
      sequence: options.sequence,
    });
    if ((this.ws?.bufferedAmount || 0) > MAX_BUFFERED_AMOUNT) {
      const error = new Error('Realtime voice provider backpressure limit reached.');
      error.code = 'VOICE_PROVIDER_BACKPRESSURE';
      throw error;
    }
    this.#send({
      type: 'input_audio_buffer.append',
      audio: Buffer.from(audioBytes).toString('base64'),
    });
    return result;
  }

  async commitInput(session, options = {}) {
    const commit = session.markCommitPending(options.turnId, options.finalSequence);
    if (!commit.ready) {
      throw new Error(
        `Voice input is incomplete for commit (${commit.receivedThrough}/${commit.finalSequence}).`,
      );
    }
    this.committedTurnId = session.activeTurnId;
    session.resetInput(session.inputMimeType);
    this.#send({ type: 'input_audio_buffer.commit' });
    if (this.config.inputMode !== 'hands_free') this.#send({ type: 'response.create' });
    return { handledByShell: true };
  }

  async interruptOutput() {
    this.#send({ type: 'response.cancel' }, { allowClosed: true });
    this.#send({ type: 'output_audio_buffer.clear' }, { allowClosed: true });
  }

  async presentDelivery(content, options = {}) {
    if (this.bridge?.captureFinal(content, options)) return;
    await this.speakOutOfBand(content, options);
  }

  async speakOutOfBand(content, options = {}) {
    const text = String(content || '').trim();
    if (!text || this.closed || !this.ws) return;
    this.#send({
      type: 'response.create',
      response: {
        conversation: 'none',
        metadata: {
          delivery_kind: String(options.kind || 'progress'),
          message_id: String(options.messageId || ''),
          run_id: String(options.runId || ''),
          turn_id: String(options.turnId || this.session.currentTurnId || ''),
        },
        output_modalities: ['audio'],
        tool_choice: 'none',
        input: [{
          type: 'message',
          role: 'user',
          content: [{
            type: 'input_text',
            text: `Speak exactly this NeoAgent update, without adding anything:\n${text}`,
          }],
        }],
      },
    });
  }

  async close() {
    this.closed = true;
    const ws = this.ws;
    this.ws = null;
    if (!ws) return;
    if (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING) {
      ws.close(1000, 'voice session closed');
    }
  }

  #waitForOpen() {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error('OpenAI realtime voice connection timed out.'));
        this.ws?.terminate();
      }, OPEN_TIMEOUT_MS);
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
  }

  #send(event, { allowClosed = false } = {}) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      if (allowClosed) return false;
      throw new Error('OpenAI realtime voice connection is not open.');
    }
    this.ws.send(JSON.stringify(event));
    return true;
  }

  async #handleEvent(event) {
    if (!event?.type || !this.session || this.closed) return;
    try {
      if (event.type === 'conversation.item.input_audio_transcription.delta') {
        const partial = `${this.session.lastPartialTranscript || ''}${event.delta || ''}`;
        await this.session.publishTranscriptPartial(partial, {
          turnId: this.committedTurnId || this.session.activeTurnId,
        });
        return;
      }
      if (event.type === 'conversation.item.input_audio_transcription.completed') {
        await this.session.publishTranscriptFinal(event.transcript, {
          turnId: this.committedTurnId || this.session.activeTurnId,
        });
        return;
      }
      if (event.type === 'input_audio_buffer.speech_started') {
        await this.session.interruptPlayback();
        await this.session.setState('listening');
        return;
      }
      if (event.type === 'response.created') {
        const context = {
          kind: event.response?.metadata?.delivery_kind || 'shell',
          messageId: event.response?.metadata?.message_id || event.response?.id || '',
          runId: event.response?.metadata?.run_id || null,
          turnId: event.response?.metadata?.turn_id || this.committedTurnId,
          sequence: 0,
        };
        if (event.response?.id) this.responseContexts.set(event.response.id, context);
        return;
      }
      if (event.type === 'response.output_audio.delta') {
        const pcm = Buffer.from(String(event.delta || ''), 'base64');
        if (pcm.length) {
          const responseId = event.response_id || '';
          const context = this.responseContexts.get(responseId) || { kind: 'shell' };
          await this.session.setState('speaking', {
            runId: context.runId,
            messageId: context.messageId,
          });
          await this.session.publishAudioChunk(wrapPcmAsWav(pcm), {
            ...context,
            turnId: context.turnId || this.committedTurnId,
            mimeType: 'audio/wav',
            sequence: context.sequence || 0,
          });
          context.sequence = (context.sequence || 0) + 1;
          this.responseContexts.set(responseId, context);
        }
        return;
      }
      if (event.type === 'response.output_audio_transcript.done') {
        const text = String(event.transcript || '').trim();
        const kind = this.responseContexts.get(event.response_id || '')?.kind || 'shell';
        if (text && !this.bridge?.inFlight && kind !== 'final') {
          await this.session.publishAssistantText(text, { kind: 'preamble' });
        }
        return;
      }
      if (event.type === 'response.done') {
        await this.#handleResponseDone(event.response);
        return;
      }
      if (event.type === 'error') {
        throw new Error(event.error?.message || 'OpenAI realtime voice failed.');
      }
    } catch (error) {
      await this.session.publishError(error.message, {
        recoverable: true,
        phase: 'duplex',
      });
    }
  }

  async #handleResponseDone(response = {}) {
    const functionCall = Array.isArray(response.output)
      ? response.output.find((item) => item?.type === 'function_call' && item.name === 'neoagent_turn')
      : null;
    if (!functionCall) {
      const context = this.responseContexts.get(response.id) || { kind: 'shell', sequence: 0 };
      if (context.kind === 'shell') {
        await this.session.interruptPlayback();
        await this.session.publishError(
          'Realtime voice provider did not route the turn through NeoAgent.',
          { recoverable: true, phase: 'bridge' },
        );
        this.responseContexts.delete(response.id);
        return;
      }
      await this.session.publishAudioDone({
        ...context,
        totalChunks: context.sequence || 0,
      });
      await this.session.setState(
        this.session.currentRunId ? 'working' : 'idle',
        { runId: this.session.currentRunId },
      );
      this.responseContexts.delete(response.id);
      return;
    }
    const args = parseJson(functionCall.arguments, {});
    const transcript = String(args?.transcript || this.session.lastFinalTranscript || '').trim();
    if (!transcript) throw new Error('Realtime voice tool call did not include a transcript.');
    const shellContext = this.responseContexts.get(response.id);
    if (shellContext) {
      await this.session.publishAudioDone({
        ...shellContext,
        totalChunks: shellContext.sequence || 0,
      });
      this.responseContexts.delete(response.id);
    }
    await this.bridge.handle(functionCall, transcript);
  }

  #handleSocketError(error) {
    logger.warn('Realtime socket error', error?.message || error);
  }

  #handleSocketClose() {
    if (this.closed || !this.session || this.session.closed) return;
    void this.session.publishError('Realtime voice provider disconnected.', {
      recoverable: true,
      phase: 'reconnecting',
    });
  }
}

module.exports = {
  NEOAGENT_TURN_TOOL,
  OpenAiRealtimeShell,
  SHELL_INSTRUCTIONS,
};
