'use strict';

const { randomUUID } = require('crypto');

const { getProviderRuntimeConfig } = require('../ai/models');
const { getVoiceRuntimeSettings } = require('./liveSettings');
const { VoiceLiveSession } = require('./liveSession');
const { OpenAiLiveRelayAdapter } = require('./openaiLiveRelayAdapter');
const { GeminiLiveRelayAdapter } = require('./geminiLiveRelayAdapter');
const { synthesizeVoiceReply, normalizeVoiceSynthesisOptions, synthesizeVoiceReplyStream } = require('./providers');
const { VoiceAgentBridge } = require('./agentBridge');

class VoiceRuntimeManager {
  constructor({ io, agentEngine, memoryManager }) {
    this.io = io;
    this.agentEngine = agentEngine;
    this.memoryManager = memoryManager;
    this.sessions = new Map();
    this.agentBridge = new VoiceAgentBridge({
      agentEngine,
      memoryManager,
      runtimeManager: this,
    });
  }

  getSession(sessionId) {
    return this.sessions.get(String(sessionId || '').trim()) || null;
  }

  async openFlutterSession({ userId, agentId = null, socket, sessionId = null } = {}) {
    if (!socket) {
      throw new Error('Socket is required to open a Flutter voice session.');
    }

    const voiceSettings = getVoiceRuntimeSettings(userId, agentId);
    const liveProviderRuntime = this.#getProviderRuntime(
      userId,
      voiceSettings.liveProvider,
      agentId,
    );
    const resolvedSessionId = String(sessionId || randomUUID()).trim();
    const adapter = this.#createAdapter(voiceSettings.liveProvider);
    await adapter.open();

    const session = new VoiceLiveSession({
      id: resolvedSessionId,
      userId,
      agentId,
      platform: 'voice_live',
      voiceSettings: {
        ...voiceSettings,
        liveApiKey: liveProviderRuntime.apiKey,
        liveBaseUrl: liveProviderRuntime.baseUrl,
      },
      sink: {
        publishReady: async (_session, extra = {}) => {
          socket.emit('voice:session_ready', {
            sessionId: resolvedSessionId,
            runtimeMode: voiceSettings.runtimeMode,
            provider: voiceSettings.liveProvider,
            model: voiceSettings.liveModel,
            voice: voiceSettings.liveVoice,
            ...extra,
          });
        },
        setState: async (_session, state, extra = {}) => {
          socket.emit('voice:assistant_state', {
            sessionId: resolvedSessionId,
            state,
            ...extra,
          });
        },
        publishTranscriptPartial: async (_session, content) => {
          socket.emit('voice:transcript_partial', {
            sessionId: resolvedSessionId,
            content,
          });
        },
        publishTranscriptFinal: async (_session, content) => {
          socket.emit('voice:transcript_final', {
            sessionId: resolvedSessionId,
            content,
          });
        },
        publishAssistantOutput: async (_session, content, options = {}) => {
          await this.#deliverFlutterAssistantOutput(socket, resolvedSessionId, session, content, options);
        },
        interruptOutput: async () => {
          socket.emit('voice:assistant_state', {
            sessionId: resolvedSessionId,
            state: 'interrupted',
          });
        },
        publishError: async (_session, message, extra = {}) => {
          socket.emit('voice:error', {
            sessionId: resolvedSessionId,
            error: message,
            ...extra,
          });
        },
        close: async () => {
          socket.emit('voice:assistant_state', {
            sessionId: resolvedSessionId,
            state: 'closed',
          });
        },
      },
    });

    session.adapter = adapter;
    this.sessions.set(resolvedSessionId, session);
    await session.publishReady();
    return session;
  }

  async closeSession(sessionId, reason = 'closed') {
    const session = this.getSession(sessionId);
    if (!session) return;
    if (reason === 'socket_disconnected') {
      await this.abortActiveRun(session.id, 'voice_disconnect');
    }
    this.sessions.delete(session.id);
    await session.adapter?.close?.(session.id);
    await session.close(reason);
  }

  async beginInput(sessionId, options = {}) {
    const session = this.#requireSession(sessionId);
    await session.interruptOutput();
    await this.abortActiveRun(session.id, 'voice_interrupt');
    session.resetTurnState();
    await session.adapter.onInputStart(session, {
      mimeType: options.mimeType,
      turnId: options.turnId,
    });
    await session.setState('listening');
  }

  async appendInputAudio(sessionId, audioBytes, options = {}) {
    const session = this.#requireSession(sessionId);
    return session.adapter.appendAudioChunk(session, audioBytes, options);
  }

  async commitInput(sessionId, options = {}) {
    const session = this.#requireSession(sessionId);
    if (session.inputBytes === 0) {
      return { transcript: '' };
    }
    await session.setState('transcribing');
    const transcript = await session.adapter.commitInput(session, {
      turnId: options.turnId,
      finalSequence: options.finalSequence,
    });
    if (!transcript) {
      await session.setState('idle');
      return { transcript: '' };
    }

    const result = await this.agentBridge.runTranscriptTurn(session, transcript, {
      promptHint: options.promptHint,
      metadata: options.metadata,
    });
    return {
      transcript,
      runId: result.runId || null,
      replyText: result.replyText || '',
    };
  }

  async interruptSession(sessionId) {
    const session = this.#requireSession(sessionId);
    await this.abortActiveRun(session.id, 'voice_interrupt');
    await session.interruptOutput();
    session.resetTurnState();
    await session.setState('idle');
  }

  async publishInterimUpdate({ sessionId, content, kind = 'progress' } = {}) {
    const session = this.getSession(sessionId);
    if (!session || session.closed) {
      return { sent: false, skipped: true, reason: 'Voice session is not active.' };
    }
    await this.deliverAssistantMessage(session, content, { kind });
    return { sent: true };
  }

  async deliverAssistantMessage(session, content, options = {}) {
    if (!session || session.closed) return;
    const normalized = String(content || '').trim();
    if (!normalized) return;
    await session.publishAssistantOutput(normalized, options);
  }

  async startTelnyxTurn({
    userId,
    agentId = null,
    callId,
    transcript,
    sink,
    metadata = null,
  } = {}) {
    const sessionId = `telnyx:${userId}:${callId}`;
    let session = this.getSession(sessionId);
    if (!session) {
      const voiceSettings = getVoiceRuntimeSettings(userId, agentId);
      const liveProviderRuntime = this.#getProviderRuntime(
        userId,
        voiceSettings.liveProvider,
        agentId,
      );
      session = new VoiceLiveSession({
        id: sessionId,
        userId,
        agentId,
        platform: 'telnyx_live',
        sink,
        outputMode: 'text_only',
        voiceSettings: {
          ...voiceSettings,
          liveApiKey: liveProviderRuntime.apiKey,
          liveBaseUrl: liveProviderRuntime.baseUrl,
        },
      });
      session.adapter = this.#createAdapter(voiceSettings.liveProvider);
      await session.adapter.open();
      this.sessions.set(sessionId, session);
    }

    await session.interruptOutput();
    await session.setState('thinking');

    try {
      const result = await this.agentBridge.runTranscriptTurn(session, transcript, {
        metadata,
      });
      return result;
    } finally {
      await session.setState('idle');
    }
  }

  async abortActiveRun(sessionId, reason = 'voice_interrupt') {
    const session = this.getSession(sessionId);
    const runId = session?.currentRunId;
    if (!runId || !this.agentEngine) return;
    this.agentEngine.abort(runId, reason);
  }

  #createAdapter(provider) {
    if (String(provider || '').trim().toLowerCase() === 'gemini') {
      return new GeminiLiveRelayAdapter();
    }
    return new OpenAiLiveRelayAdapter();
  }

  #requireSession(sessionId) {
    const session = this.getSession(sessionId);
    if (!session) {
      throw new Error('Voice session was not found.');
    }
    return session;
  }

  #getProviderRuntime(userId, provider, agentId = null) {
    const providerId = String(provider || '').trim().toLowerCase() === 'gemini'
      ? 'google'
      : String(provider || '').trim().toLowerCase();
    if (!providerId || providerId === 'deepgram') {
      return { apiKey: '', baseUrl: '' };
    }
    try {
      const runtime = getProviderRuntimeConfig(userId, providerId, agentId);
      return {
        apiKey: typeof runtime.apiKey === 'string' ? runtime.apiKey.trim() : '',
        baseUrl: typeof runtime.baseUrl === 'string' ? runtime.baseUrl.trim() : '',
      };
    } catch {
      return { apiKey: '', baseUrl: '' };
    }
  }

  async #deliverFlutterAssistantOutput(socket, sessionId, session, content, options = {}) {
    const kind = String(options.kind || 'final').trim() || 'final';
    socket.emit('voice:assistant_text', {
      sessionId,
      content,
      kind,
    });

    if (kind === 'final') {
      await session.setState('speaking', { kind });
    }

    const voiceOptions = normalizeVoiceSynthesisOptions({
      provider: session.voiceSettings?.liveProvider,
      model: session.voiceSettings?.liveTtsModel,
      voice: session.voiceSettings?.liveVoice,
    });

    let index = 0;
    let streamError = null;
    const ttsAttempts = this.#buildTtsAttemptOrder(session, voiceOptions);
    try {
      for (const attempt of ttsAttempts) {
        index = 0;
        streamError = null;
        try {
          await synthesizeVoiceReplyStream(
            content,
            attempt,
            async ({ audioBytes, mimeType }) => {
              if (session.closed || session.interrupted) return;
              socket.emit('voice:audio_chunk', {
                sessionId,
                kind,
                index,
                audioBase64: audioBytes.toString('base64'),
                mimeType,
              });
              index += 1;
            },
          );
          streamError = null;
          break;
        } catch (error) {
          streamError = String(error?.message || error || 'Voice playback failed.');
        }
      }
    } catch (error) {
      streamError = String(error?.message || error || 'Voice playback failed.');
    }

    if (!streamError && !session.closed && !session.interrupted) {
      socket.emit('voice:audio_done', { sessionId, kind, totalChunks: index });
    } else if (kind === 'final' && !session.closed && !session.interrupted) {
      socket.emit('voice:error', {
        sessionId,
        error: streamError,
        recoverable: true,
        phase: 'tts',
      });
      await session.setState('degraded', { kind, phase: 'tts' });
    }

    if (kind === 'final' && !streamError) {
      await session.setState('idle');
    }
  }

  #buildTtsAttemptOrder(session, voiceOptions) {
    const attempts = [];
    const providers = [
      voiceOptions.provider,
      ...['openai', 'deepgram', 'gemini'].filter((provider) => provider !== voiceOptions.provider),
    ];
    for (const provider of providers) {
      const normalized = normalizeVoiceSynthesisOptions({
        provider,
        model: provider === voiceOptions.provider ? voiceOptions.model : null,
        voice: provider === voiceOptions.provider ? voiceOptions.voice : null,
      });
      const runtime = provider === voiceOptions.provider
        ? {
            apiKey: session.voiceSettings?.liveApiKey,
            baseUrl: session.voiceSettings?.liveBaseUrl,
          }
        : this.#getProviderRuntime(session.userId, provider, session.agentId);
      attempts.push({
        ...normalized,
        apiKey: runtime.apiKey,
        baseUrl: runtime.baseUrl,
        timeoutMs: 12000,
      });
    }
    return attempts;
  }
}

module.exports = {
  VoiceRuntimeManager,
};
