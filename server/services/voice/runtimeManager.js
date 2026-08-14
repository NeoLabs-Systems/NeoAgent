'use strict';

const { randomUUID } = require('crypto');
const { getProviderRuntimeConfig } = require('../ai/models');
const { waitForBoundedResult } = require('../network/http');
const { createServiceLogger } = require('../../utils/logger');
const { ChatTurnGateway } = require('./chat_turn_gateway');
const { VoiceLiveSession } = require('./liveSession');
const { getVoiceRuntimeSettings } = require('./liveSettings');
const { VoiceProviderRegistry } = require('./provider_registry');
const { VoiceDeliveryPresenter } = require('./voice_delivery_presenter');
const { SocketVoiceTransport } = require('./voice_transport');
const { sanitizeSpeechText, synthesizeVoiceReplyStream } = require('./providers');

const logger = createServiceLogger('VoiceRuntime');

function runtimeStoppedError() {
  const error = new Error('Voice runtime is shutting down.');
  error.name = 'AbortError';
  error.code = 'VOICE_RUNTIME_SHUTDOWN';
  return error;
}

class VoiceSessionCoordinator {
  constructor({ io, agentEngine, memoryManager }) {
    this.io = io;
    this.agentEngine = agentEngine;
    this.memoryManager = memoryManager;
    this.sessions = new Map();
    this.shuttingDown = false;
    this.shutdownPromise = null;
    this.providerRegistry = new VoiceProviderRegistry();
    this.deliveryPresenter = new VoiceDeliveryPresenter();
    this.chatTurnGateway = new ChatTurnGateway({ agentEngine, memoryManager });
  }

  getSession(sessionId) {
    return this.sessions.get(String(sessionId || '').trim()) || null;
  }

  getCapabilities() {
    return {
      mediaModes: ['auto', 'composed'],
      inputModes: ['ptt', 'hands_free'],
      providers: this.providerRegistry.describe(),
    };
  }

  async openSession({
    userId,
    agentId = null,
    sessionId = null,
    platform = 'voice_live',
    sink,
    outputMode = 'audio_and_text',
    originRunId = null,
    originConversationId = null,
    agentInitiated = false,
  } = {}) {
    if (this.shuttingDown) throw runtimeStoppedError();
    if (!sink) throw new Error('A voice session sink is required.');
    const resolvedId = String(sessionId || randomUUID()).trim();
    const existing = this.getSession(resolvedId);
    if (existing) {
      this.#assertOwner(existing, userId);
      clearTimeout(existing.detachedCleanupTimer);
      existing.detachedCleanupTimer = null;
      existing.attachSink(sink);
      existing.closed = false;
      await this.#replaceAdapter(existing);
      await existing.publishReady({ reconnected: true });
      await this.deliveryPresenter.flush(existing);
      return existing;
    }

    const stored = getVoiceRuntimeSettings(userId, agentId);
    const resolved = this.providerRegistry.resolve(stored);
    const runtimes = {
      stt: this.#providerRuntime(userId, resolved.sttProvider, agentId),
      tts: this.#providerRuntime(userId, resolved.ttsProvider, agentId),
      duplex: this.#providerRuntime(userId, resolved.duplexProvider, agentId),
    };
    const session = new VoiceLiveSession({
      id: resolvedId,
      userId,
      agentId,
      platform,
      sink,
      outputMode,
      runtimeManager: this,
      originRunId,
      originConversationId,
      agentInitiated,
      voiceSettings: {
        ...resolved,
        sttApiKey: runtimes.stt.apiKey,
        sttBaseUrl: runtimes.stt.baseUrl,
        ttsApiKey: runtimes.tts.apiKey,
        ttsBaseUrl: runtimes.tts.baseUrl,
        duplexApiKey: runtimes.duplex.apiKey,
        duplexBaseUrl: runtimes.duplex.baseUrl,
      },
    });
    this.sessions.set(resolvedId, session);
    try {
      await this.#replaceAdapter(session);
      await session.publishReady();
      return session;
    } catch (error) {
      this.sessions.delete(resolvedId);
      await session.adapter?.close?.().catch(() => {});
      throw error;
    }
  }

  openFlutterSession({
    userId,
    agentId = null,
    socket,
    sessionId = null,
    originRunId = null,
    originConversationId = null,
    agentInitiated = false,
  } = {}) {
    if (!socket) throw new Error('Socket is required to open a Flutter voice session.');
    return this.openSession({
      userId,
      agentId,
      sessionId,
      platform: 'voice_live',
      sink: new SocketVoiceTransport(socket, () => this.getCapabilities()),
      originRunId,
      originConversationId,
      agentInitiated,
    });
  }

  hasActiveSessionForUser(userId) {
    return Array.from(this.sessions.values()).some((session) => (
      String(session.userId) === String(userId) && !session.closed && session.attached
    ));
  }

  async prepareComposedSpeech({ userId, agentId = null, text, signal = null } = {}) {
    const content = sanitizeSpeechText(text);
    if (!content) return { chunks: [], mediaMode: 'composed' };
    const stored = getVoiceRuntimeSettings(userId, agentId);
    const resolved = this.providerRegistry.resolve(stored);
    if (resolved.mediaMode === 'duplex') {
      return { chunks: [], mediaMode: 'duplex' };
    }
    const runtime = this.#providerRuntime(userId, resolved.ttsProvider, agentId);
    const chunks = [];
    await synthesizeVoiceReplyStream(
      content,
      {
        provider: resolved.ttsProvider,
        model: resolved.ttsModel,
        voice: resolved.ttsVoice,
        apiKey: runtime.apiKey,
        baseUrl: runtime.baseUrl,
        timeoutMs: 30000,
        signal,
        transport: 'flutter',
      },
      async ({ audioBytes, mimeType }) => {
        if (audioBytes?.length) chunks.push({ audioBytes, mimeType });
      },
    );
    return { chunks, mediaMode: 'composed' };
  }

  openWearableSession({ userId, agentId = null, sessionId = null, sink } = {}) {
    return this.openSession({
      userId,
      agentId,
      sessionId,
      platform: 'wearable_live',
      sink,
    });
  }

  async beginInput(sessionId, options = {}, userId = null) {
    const session = this.#requireSession(sessionId, userId);
    await session.interruptOutput();
    session.resetTurnState();
    await session.adapter.onInputStart(session, options);
    await session.setState('listening', { turnId: options.turnId });
  }

  async appendInputAudio(sessionId, audioBytes, options = {}, userId = null) {
    const session = this.#requireSession(sessionId, userId);
    return session.adapter.appendAudioChunk(session, audioBytes, options);
  }

  async commitInput(sessionId, options = {}, userId = null) {
    const session = this.#requireSession(sessionId, userId);
    if (session.inputBytes === 0) {
      session.resetTurnState();
      await session.setState('idle');
      return { discarded: true };
    }
    await session.setState('transcribing', { turnId: options.turnId });
    const result = await session.adapter.commitInput(session, options);
    if (result?.handledByShell) return result;
    const transcript = String(result || '').trim();
    if (!transcript) {
      session.resetTurnState();
      await session.setState('idle');
      return { discarded: true };
    }
    return this.chatTurnGateway.submitTurn(session, transcript, options);
  }

  async interruptSession(sessionId, userId = null) {
    const session = this.#requireSession(sessionId, userId);
    await session.interruptOutput();
    session.resetTurnState();
    await session.setState(session.currentRunId ? 'working' : 'idle', {
      runId: session.currentRunId,
    });
  }

  async cancelTask(sessionId, userId = null) {
    const session = this.#requireSession(sessionId, userId);
    if (!session.currentRunId) return { cancelled: false };
    this.agentEngine.abort(session.currentRunId, {
      userId: session.userId,
      reason: 'voice_user_cancelled',
    });
    return { cancelled: true, runId: session.currentRunId };
  }

  async detachSession(sessionId, reason = 'transport_disconnected', userId = null) {
    const session = this.getSession(sessionId);
    if (!session) return;
    this.#assertOwner(session, userId);
    await session.adapter?.close?.().catch(() => {});
    session.detachSink();
    session.state = 'reconnecting';
    if (!session.currentRunId) this.sessions.delete(session.id);
    logger.info('Media detached', { sessionId: session.id, reason, runActive: Boolean(session.currentRunId) });
  }

  async closeSession(sessionId, reason = 'closed', userId = null, options = {}) {
    const session = this.getSession(sessionId);
    if (!session) return;
    this.#assertOwner(session, userId);
    if (options.cancelTask === true && session.currentRunId) {
      await this.cancelTask(sessionId, userId);
    }
    if (session.currentRunId && options.cancelTask !== true) {
      await this.detachSession(sessionId, reason, userId);
      this.agentCallCoordinator?.notifySessionClosed(session, reason);
      return;
    }
    this.sessions.delete(session.id);
    await session.adapter?.close?.().catch(() => {});
    await session.close(reason);
    this.agentCallCoordinator?.notifySessionClosed(session, reason);
  }

  async presentDelivery(entry) {
    const session = this.getSession(entry?.recipient);
    if (!session) return { delivered: true, detached: true };
    const result = await this.deliveryPresenter.present(session, entry);
    return { delivered: true, ...result };
  }

  async presentControlReply(session, content, metadata = {}) {
    return this.deliveryPresenter.present(session, {
      content,
      kind: 'control',
      messageId: metadata.messageId || randomUUID(),
      runId: metadata.runId,
    });
  }

  async publishInterimUpdate({ sessionId, content, kind = 'progress' } = {}) {
    const session = this.getSession(sessionId);
    if (!session) return { sent: false, skipped: true };
    await this.presentControlReply(session, content, { kind, runId: session.currentRunId });
    return { sent: true };
  }

  handleRunTerminal(runId) {
    const normalizedRunId = String(runId || '').trim();
    if (!normalizedRunId) return;
    for (const session of this.sessions.values()) {
      if (session.currentRunId !== normalizedRunId) continue;
      session.currentRunId = null;
      if (!['listening', 'transcribing', 'speaking'].includes(session.state)) {
        void session.setState('idle', { runId: '', clearRunId: true });
      }
      this.releaseDetachedSession(session);
    }
  }

  releaseDetachedSession(session) {
    if (!session || session.attached || session.currentRunId || session.detachedCleanupTimer) return;
    session.detachedCleanupTimer = setTimeout(() => {
      if (!session.attached && !session.currentRunId) this.sessions.delete(session.id);
    }, 10 * 60 * 1000);
    session.detachedCleanupTimer.unref?.();
  }

  shutdown() {
    if (this.shutdownPromise) return this.shutdownPromise;
    this.shuttingDown = true;
    const closing = Promise.allSettled(Array.from(this.sessions.values()).map(async (session) => {
      if (session.currentRunId) {
        this.agentEngine.abort(session.currentRunId, {
          userId: session.userId,
          reason: 'voice_session_closed',
        });
      }
      await session.adapter?.close?.();
      await session.close('server_shutdown');
    }));
    this.sessions.clear();
    this.shutdownPromise = waitForBoundedResult(closing, {
      serviceName: 'Voice runtime shutdown',
      timeoutMs: 10000,
    }).then(() => ({ state: 'stopped', timedOut: false }));
    return this.shutdownPromise;
  }

  async #replaceAdapter(session) {
    await session.adapter?.close?.().catch(() => {});
    session.adapter = this.providerRegistry.createMediaAdapter(session.voiceSettings, {
      runtimeManager: this,
    });
    await session.adapter.open(session);
  }

  #requireSession(sessionId, userId) {
    if (this.shuttingDown) throw runtimeStoppedError();
    const session = this.getSession(sessionId);
    if (!session) throw new Error('Voice session was not found.');
    this.#assertOwner(session, userId);
    return session;
  }

  #assertOwner(session, userId) {
    if (userId == null || session.userId == null || String(session.userId) !== String(userId)) {
      throw new Error('Voice session access denied.');
    }
  }

  #providerRuntime(userId, provider, agentId) {
    const id = provider === 'gemini' ? 'google' : provider;
    if (!id || id === 'deepgram') return { apiKey: '', baseUrl: '' };
    try {
      const runtime = getProviderRuntimeConfig(userId, id, agentId);
      return {
        apiKey: String(runtime.apiKey || '').trim(),
        baseUrl: String(runtime.baseUrl || '').trim(),
      };
    } catch {
      return { apiKey: '', baseUrl: '' };
    }
  }

}

module.exports = {
  VoiceRuntimeManager: VoiceSessionCoordinator,
  VoiceSessionCoordinator,
};
