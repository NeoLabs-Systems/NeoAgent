'use strict';

const { createServiceLogger } = require('../../../utils/logger');
const { LIVE_VOICE_PROVIDERS } = require('./catalog');
const { GeminiLiveAdapter } = require('./gemini_live');
const { OpenAiLiveAdapter } = require('./openai_live');
const { buildLivePrompt } = require('./prompt');
const { LiveTaskBridge } = require('./task_bridge');
const { recordTaskReply, recordVoiceTurn } = require('./transcript_store');

const logger = createServiceLogger('LiveVoiceSession');
const ADAPTERS = Object.freeze({ openai: OpenAiLiveAdapter, google: GeminiLiveAdapter });
const MAX_PENDING_AUDIO_BYTES = 5 * 24000 * 2;
const SPEAKING_IDLE_MS = 700;
// GPT-Live announces a hand-off before the owner's transcript has fully
// arrived; waiting briefly lets the request carry the whole utterance.
const DELEGATION_SETTLE_MS = 500;
const MAX_RECONNECT_ATTEMPTS = 3;

// Transcript fragments arrive with or without their leading space depending on
// the provider; join them so words neither merge nor double-space.
function appendFragment(buffer, fragment) {
  if (!buffer) return fragment.trimStart();
  if (!fragment) return buffer;
  if (/\s$/.test(buffer) || /^[\s.,!?;:)]/.test(fragment)) return buffer + fragment;
  return `${buffer} ${fragment}`;
}

class LiveVoiceSession {
  constructor({
    id,
    userId,
    agentId,
    platform,
    sink,
    agentEngine,
    conversationId,
    settings,
    credentials,
    originRunId = null,
    agentInitiated = false,
    onIdle,
  }) {
    this.id = id;
    this.userId = userId;
    this.agentId = agentId;
    this.platform = platform;
    this.sink = sink;
    this.agentEngine = agentEngine;
    this.conversationId = conversationId;
    this.settings = settings;
    this.credentials = credentials;
    this.agentInitiated = agentInitiated;
    this.onIdle = onIdle;
    this.provider = LIVE_VOICE_PROVIDERS[settings.liveProvider];
    this.tasks = new LiveTaskBridge({ agentEngine, session: this, originRunId });
    this.adapter = null;
    this.ready = false;
    this.closed = false;
    this.pendingAudio = [];
    this.pendingAudioBytes = 0;
    this.userTurn = '';
    this.assistantTurn = '';
    this.lastUserTurn = '';
    this.outputSuppressed = false;
    this.pendingOnReady = [];
    this.state = 'connecting';
    this.speakingTimer = null;
    this.reconnectAttempts = 0;
  }

  get attached() {
    return Boolean(this.sink);
  }

  async connect({ reconnected = false, resumeHandle = null } = {}) {
    this.ready = false;
    this.#setState(reconnected ? 'reconnecting' : 'connecting');
    // A reattaching client may arrive before the old provider connection was
    // dropped; never leave two billed live sessions open.
    const previous = this.adapter;
    this.adapter = null;
    await previous?.close().catch(() => {});
    const prompt = await buildLivePrompt({
      agentEngine: this.agentEngine,
      userId: this.userId,
      agentId: this.agentId,
      conversationId: this.conversationId,
    });
    const Adapter = ADAPTERS[this.provider.id];
    const adapter = new Adapter({
      apiKey: this.credentials.apiKey,
      baseUrl: this.credentials.baseUrl,
      model: this.settings.liveModel,
      voice: this.settings.liveVoice,
      handlers: this.#handlersFor(() => this.adapter === adapter),
    });
    this.adapter = adapter;
    await adapter.connect({ ...prompt, resumeHandle });
    if (this.adapter !== adapter || this.closed) {
      await adapter.close();
      return;
    }
    this.ready = true;
    this.reconnectAttempts = 0;
    for (const chunk of this.pendingAudio) adapter.appendAudio(chunk);
    this.pendingAudio = [];
    this.pendingAudioBytes = 0;
    for (const deliver of this.pendingOnReady.splice(0)) deliver();
    this.#emit('session_ready', {
      provider: this.provider.id,
      model: this.settings.liveModel,
      voice: this.settings.liveVoice,
      inputMode: this.settings.inputMode,
      inputSampleRate: this.provider.inputSampleRate,
      outputSampleRate: this.provider.outputSampleRate,
      activeRunId: this.tasks.activeRunId,
      reconnected,
    });
    this.#setState('listening');
  }

  appendAudio(pcm) {
    if (!pcm.length) return;
    if (this.ready) {
      this.adapter.appendAudio(pcm);
      return;
    }
    this.pendingAudio.push(pcm);
    this.pendingAudioBytes += pcm.length;
    while (this.pendingAudioBytes > MAX_PENDING_AUDIO_BYTES) {
      this.pendingAudioBytes -= this.pendingAudio.shift().length;
    }
  }

  endInput() {
    if (this.ready) this.adapter.endInput();
  }

  // The owner asked the assistant to stop talking: drop what is still coming
  // until they speak again.
  interruptOutput() {
    this.outputSuppressed = true;
    this.#emit('interrupted');
    this.#flushAssistantTurn();
    this.#setState('listening');
  }

  say(text) {
    this.adapter?.say(text);
  }

  presentDelivery(entry) {
    if (!this.attached) return { detached: true };
    this.#whenReady(() => this.tasks.present(entry));
    return { detached: false };
  }

  deliverTaskOutcome({ handle, runId, outcome, reply }) {
    if (this.attached) {
      this.#whenReady(() => this.adapter.completeTask(handle, outcome));
      return;
    }
    if (reply) {
      recordTaskReply({
        userId: this.userId,
        agentId: this.agentId,
        conversationId: this.conversationId,
        runId,
        content: reply,
      });
    }
    this.releaseIfIdle();
  }

  publishTask({ runId, status, request }) {
    this.#emit('task', { runId, status, ...(request ? { request } : {}) });
  }

  async attach(sink) {
    this.sink = sink;
    await this.connect({ reconnected: true });
  }

  async detach() {
    this.sink = null;
    await this.#closeAdapter();
    this.#flushTurns();
    this.releaseIfIdle();
  }

  releaseIfIdle() {
    if (!this.attached && !this.tasks.hasRunningWork) this.onIdle(this);
  }

  async close(reason, { cancelTasks = false } = {}) {
    if (cancelTasks) this.tasks.abortAll('voice_session_closed');
    this.#flushTurns();
    this.#emit('state', { state: 'closed', reason });
    this.closed = true;
    this.sink = null;
    await this.#closeAdapter();
  }

  // Results that arrive while the provider connection is being re-established
  // are spoken once it is back.
  #whenReady(deliver) {
    if (this.ready) deliver();
    else this.pendingOnReady.push(deliver);
  }

  async #closeAdapter() {
    this.ready = false;
    clearTimeout(this.speakingTimer);
    const adapter = this.adapter;
    this.adapter = null;
    await adapter?.close().catch(() => {});
  }

  #handlersFor(isCurrent) {
    const guard = (fn) => (...args) => {
      if (!isCurrent() || this.closed) return;
      try {
        fn(...args);
      } catch (error) {
        logger.warn('Live event handling failed', error?.message || error);
      }
    };
    return {
      onAudio: guard((pcm) => this.#handleAudio(pcm)),
      onInputTranscript: guard((text) => this.#handleInputTranscript(text)),
      onOutputTranscript: guard((text) => this.#handleOutputTranscript(text)),
      onInterrupted: guard(() => {
        this.#emit('interrupted');
        this.#flushAssistantTurn();
        this.#setState('listening');
      }),
      onTurnComplete: guard(() => {
        this.#flushAssistantTurn();
      }),
      onDelegation: guard((delegation) => this.#handleDelegation(delegation)),
      onError: guard((error) => {
        logger.warn('Live provider error', { sessionId: this.id, error: error.message });
        this.#emit('error', { error: error.message, recoverable: true });
      }),
      onClosed: guard(({ reason, resumeHandle }) => {
        void this.#reconnect(reason, resumeHandle);
      }),
    };
  }

  #handleAudio(pcm) {
    if (this.outputSuppressed) return;
    this.#emit('audio', { audioBase64: pcm.toString('base64') });
    this.#setState('speaking');
    clearTimeout(this.speakingTimer);
    this.speakingTimer = setTimeout(() => this.#setState('listening'), SPEAKING_IDLE_MS);
    this.speakingTimer.unref?.();
  }

  #handleInputTranscript(text) {
    if (!text) return;
    this.outputSuppressed = false;
    this.#flushAssistantTurn();
    this.userTurn = appendFragment(this.userTurn, text);
    this.#emit('transcript', { role: 'user', content: this.userTurn, final: false });
  }

  #handleOutputTranscript(text) {
    if (!text || this.outputSuppressed) return;
    this.#flushUserTurn();
    this.assistantTurn = appendFragment(this.assistantTurn, text);
    this.#emit('transcript', { role: 'assistant', content: this.assistantTurn, final: false });
  }

  // GPT-Live hands off without task text: the request is the owner's latest
  // turn, and the run reads the rest of the conversation from its history.
  #handleDelegation({ handle, request }) {
    if (request) {
      this.tasks.delegate({ handle, request });
      return;
    }
    const timer = setTimeout(() => {
      if (this.closed || !this.ready) return;
      this.tasks.delegate({ handle, request: this.userTurn || this.lastUserTurn });
    }, DELEGATION_SETTLE_MS);
    timer.unref?.();
  }

  async #reconnect(reason, resumeHandle) {
    this.ready = false;
    this.#flushTurns();
    if (!this.attached || this.closed) return;
    this.reconnectAttempts += 1;
    if (this.reconnectAttempts > MAX_RECONNECT_ATTEMPTS) {
      this.#emit('error', { error: `The live voice connection ended (${reason}).`, recoverable: false });
      this.#emit('state', { state: 'closed', reason });
      await this.detach();
      return;
    }
    logger.info('Reconnecting live voice', { sessionId: this.id, reason, attempt: this.reconnectAttempts });
    try {
      await this.connect({ reconnected: true, resumeHandle });
    } catch (error) {
      await this.#reconnect(error.message, null);
    }
  }

  #flushUserTurn() {
    const content = this.userTurn.trim();
    this.userTurn = '';
    if (!content) return;
    this.lastUserTurn = content;
    this.#persistTurn('user', content);
  }

  #flushAssistantTurn() {
    const content = this.assistantTurn.trim();
    this.assistantTurn = '';
    if (!content) return;
    this.#persistTurn('assistant', content);
  }

  #flushTurns() {
    this.#flushUserTurn();
    this.#flushAssistantTurn();
  }

  #persistTurn(role, content) {
    this.#emit('transcript', { role, content, final: true });
    try {
      recordVoiceTurn({
        userId: this.userId,
        agentId: this.agentId,
        conversationId: this.conversationId,
        sessionId: this.id,
        role,
        content,
      });
    } catch (error) {
      logger.warn('Failed to store voice turn', error?.message || error);
    }
  }

  #setState(state) {
    if (this.state === state) return;
    this.state = state;
    this.#emit('state', { state });
  }

  #emit(kind, payload = {}) {
    this.sink?.send(kind, { sessionId: this.id, ...payload });
  }
}

module.exports = {
  LiveVoiceSession,
  appendFragment,
};
