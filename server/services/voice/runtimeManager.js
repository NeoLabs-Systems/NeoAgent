'use strict';

const { randomUUID } = require('crypto');
const { getProviderRuntimeConfig } = require('../ai/models');
const { waitForBoundedResult } = require('../network/http');
const { createServiceLogger } = require('../../utils/logger');
const { LIVE_VOICE_PROVIDERS, describeLiveVoiceCatalog } = require('./live/catalog');
const { LiveVoiceSession } = require('./live/session');
const { getVoiceRuntimeSettings } = require('./liveSettings');
const { DEFAULT_STT_MODELS, STT_PROVIDERS } = require('./providers/provider_defaults');
const { createSocketVoiceSink } = require('./voice_transport');

const logger = createServiceLogger('VoiceRuntime');

function runtimeStoppedError() {
  const error = new Error('Voice runtime is shutting down.');
  error.name = 'AbortError';
  error.code = 'VOICE_RUNTIME_SHUTDOWN';
  return error;
}

class VoiceRuntimeManager {
  constructor({ agentEngine, memoryManager }) {
    this.agentEngine = agentEngine;
    this.memoryManager = memoryManager;
    this.sessions = new Map();
    this.shuttingDown = false;
    this.shutdownPromise = null;
    this.agentCallCoordinator = null;
  }

  // What the settings UI offers: live voice models, plus the transcription
  // providers used for voice notes and dictation.
  getCapabilities() {
    return {
      ...describeLiveVoiceCatalog(),
      transcription: {
        providers: STT_PROVIDERS.map((id) => ({ id, defaultModel: DEFAULT_STT_MODELS[id] })),
      },
    };
  }

  getSession(sessionId) {
    return this.sessions.get(String(sessionId || '').trim()) || null;
  }

  // Reopening a known session id (a reconnecting client, or a client coming back
  // while a hand-off is still running) reattaches instead of starting over.
  async openSession({
    userId,
    agentId = null,
    sessionId = null,
    platform = 'voice_live',
    sink,
    originRunId = null,
    originConversationId = null,
    agentInitiated = false,
  } = {}) {
    if (this.shuttingDown) throw runtimeStoppedError();
    const existing = this.getSession(sessionId);
    if (existing) {
      this.#assertOwner(existing, userId);
      await existing.attach(sink);
      return existing;
    }

    const settings = getVoiceRuntimeSettings(userId, agentId);
    const provider = LIVE_VOICE_PROVIDERS[settings.liveProvider];
    const runtime = getProviderRuntimeConfig(userId, provider.runtimeProvider, agentId);
    const session = new LiveVoiceSession({
      id: String(sessionId || randomUUID()).trim(),
      userId,
      agentId,
      platform,
      sink,
      agentEngine: this.agentEngine,
      memoryManager: this.memoryManager,
      conversationId: originConversationId
        || this.memoryManager.getDefaultWebConversationId(userId, { agentId }),
      settings,
      credentials: {
        apiKey: String(runtime.apiKey || '').trim(),
        baseUrl: String(runtime.baseUrl || '').trim(),
      },
      originRunId,
      agentInitiated,
      onIdle: (idle) => this.#forget(idle),
    });
    this.sessions.set(session.id, session);
    try {
      await session.connect();
      return session;
    } catch (error) {
      this.sessions.delete(session.id);
      await session.close('connect_failed');
      throw error;
    }
  }

  openFlutterSession({ socket, ...options } = {}) {
    if (!socket) throw new Error('Socket is required to open a voice session.');
    return this.openSession({ ...options, platform: 'voice_live', sink: createSocketVoiceSink(socket) });
  }

  openWearableSession({ sink, ...options } = {}) {
    return this.openSession({ ...options, platform: 'wearable_live', sink });
  }

  hasActiveSessionForUser(userId) {
    return Array.from(this.sessions.values()).some((session) => (
      String(session.userId) === String(userId) && session.attached
    ));
  }

  appendAudio(sessionId, pcm, userId) {
    this.#requireSession(sessionId, userId).appendAudio(pcm);
  }

  startInput(sessionId, userId) {
    this.#requireSession(sessionId, userId).startInput();
  }

  endInput(sessionId, userId) {
    this.#requireSession(sessionId, userId).endInput();
  }

  interruptOutput(sessionId, userId) {
    this.#requireSession(sessionId, userId).interruptOutput();
  }

  cancelTask(sessionId, userId) {
    return this.#requireSession(sessionId, userId).tasks.cancel();
  }

  // The client went away; running hand-offs keep going and the session stays
  // reattachable until they finish.
  async detachSession(sessionId, reason, userId) {
    const session = this.getSession(sessionId);
    if (!session) return;
    this.#assertOwner(session, userId);
    logger.info('Voice client detached', { sessionId, reason, runActive: session.tasks.hasRunningWork });
    await session.detach();
  }

  async closeSession(sessionId, reason, userId, { cancelTask = false } = {}) {
    const session = this.getSession(sessionId);
    if (!session) return;
    this.#assertOwner(session, userId);
    if (session.tasks.hasRunningWork && !cancelTask) {
      await session.detach();
    } else {
      this.sessions.delete(session.id);
      await session.close(reason, { cancelTasks: cancelTask });
    }
    this.agentCallCoordinator?.notifySessionClosed(session, reason);
  }

  // Outbox deliveries for voice-originated runs. A session whose client is gone
  // reports detached, and the delivery worker shows the result in chat instead.
  presentDelivery(entry) {
    const session = this.getSession(entry?.recipient);
    if (!session) return { detached: true };
    return session.presentDelivery(entry);
  }

  handleRunTerminal(runId) {
    for (const session of this.sessions.values()) {
      session.tasks.handleRunTerminal(runId);
    }
  }

  say(sessionId, text) {
    this.getSession(sessionId)?.say(text);
  }

  shutdown() {
    if (this.shutdownPromise) return this.shutdownPromise;
    this.shuttingDown = true;
    const closing = Promise.allSettled(Array.from(this.sessions.values()).map(
      (session) => session.close('server_shutdown', { cancelTasks: true }),
    ));
    this.sessions.clear();
    this.shutdownPromise = waitForBoundedResult(closing, {
      serviceName: 'Voice runtime shutdown',
      timeoutMs: 10000,
    }).then(() => ({ state: 'stopped', timedOut: false }));
    return this.shutdownPromise;
  }

  #forget(session) {
    if (this.sessions.get(session.id) !== session) return;
    this.sessions.delete(session.id);
    void session.close('released');
  }

  #requireSession(sessionId, userId) {
    if (this.shuttingDown) throw runtimeStoppedError();
    const session = this.getSession(sessionId);
    if (!session) throw new Error('Voice session was not found.');
    this.#assertOwner(session, userId);
    return session;
  }

  #assertOwner(session, userId) {
    if (userId == null || String(session.userId) !== String(userId)) {
      throw new Error('Voice session access denied.');
    }
  }
}

module.exports = {
  VoiceRuntimeManager,
};
