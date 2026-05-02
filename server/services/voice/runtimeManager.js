'use strict';

const { randomUUID } = require('crypto');
const db = require('../../db/database');

const { getProviderRuntimeConfig } = require('../ai/models');
const { isMainAgent, resolveAgentId } = require('../agents/manager');
const { getVoiceRuntimeSettings } = require('./liveSettings');
const { VoiceLiveSession } = require('./liveSession');
const { OpenAiLiveRelayAdapter } = require('./openaiLiveRelayAdapter');
const { GeminiLiveRelayAdapter } = require('./geminiLiveRelayAdapter');
const {
  synthesizeVoiceReply,
  normalizeVoiceSynthesisOptions,
  synthesizeVoiceReplyStream,
  sanitizeSpeechText,
} = require('./providers');
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

  async openSession({
    userId,
    agentId = null,
    sessionId = null,
    platform = 'voice_live',
    sink,
    outputMode = 'audio_and_text',
  } = {}) {
    if (!sink) {
      throw new Error('A voice session sink is required.');
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
      platform,
      voiceSettings: {
        ...voiceSettings,
        liveApiKey: liveProviderRuntime.apiKey,
        liveBaseUrl: liveProviderRuntime.baseUrl,
      },
      sink,
      outputMode,
    });

    session.adapter = adapter;
    this.sessions.set(resolvedSessionId, session);
    await session.publishReady();
    return session;
  }

  async openFlutterSession({ userId, agentId = null, socket, sessionId = null } = {}) {
    if (!socket) {
      throw new Error('Socket is required to open a Flutter voice session.');
    }
    return this.openSession({
      userId,
      agentId,
      sessionId,
      platform: 'voice_live',
      outputMode: 'audio_and_text',
      sink: {
        publishReady: async (_session, extra = {}) => {
          const voiceSettings = getVoiceRuntimeSettings(userId, agentId);
          socket.emit('voice:session_ready', {
            sessionId: String(sessionId || _session.id).trim(),
            runtimeMode: voiceSettings.runtimeMode,
            provider: voiceSettings.liveProvider,
            model: voiceSettings.liveModel,
            voice: voiceSettings.liveVoice,
            ...extra,
          });
        },
        setState: async (_session, state, extra = {}) => {
          socket.emit('voice:assistant_state', {
            sessionId: _session.id,
            state,
            ...extra,
          });
        },
        publishTranscriptPartial: async (_session, content) => {
          socket.emit('voice:transcript_partial', {
            sessionId: _session.id,
            content,
          });
        },
        publishTranscriptFinal: async (_session, content) => {
          socket.emit('voice:transcript_final', {
            sessionId: _session.id,
            content,
          });
        },
        publishAssistantOutput: async (_session, content, options = {}) => {
          await this.#deliverFlutterAssistantOutput(socket, _session.id, _session, content, options);
        },
        interruptOutput: async (_session) => {
          socket.emit('voice:assistant_state', {
            sessionId: _session.id,
            state: 'interrupted',
          });
        },
        publishError: async (_session, message, extra = {}) => {
          socket.emit('voice:error', {
            sessionId: _session.id,
            error: message,
            ...extra,
          });
        },
        close: async (_session) => {
          socket.emit('voice:assistant_state', {
            sessionId: _session.id,
            state: 'closed',
          });
        },
      },
    });
  }

  async openWearableSession({ userId, agentId = null, sessionId = null, sink } = {}) {
    return this.openSession({
      userId,
      agentId,
      sessionId,
      platform: 'wearable_live',
      outputMode: 'audio_and_text',
      sink,
    });
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

  async publishInterimUpdate({ sessionId, content, kind = 'progress', deferFollowUp = false } = {}) {
    const session = this.getSession(sessionId);
    if (!session || session.closed) {
      return { sent: false, skipped: true, reason: 'Voice session is not active.' };
    }
    if (deferFollowUp === true) {
      session.deferFollowUpRequested = true;
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

  async prepareDeferredVoiceFollowUp(session) {
    if (!session || session.closed) return null;
    if (String(session.platform || '').trim() !== 'voice_live') return null;

    const target = this.#resolvePreferredMessagingTarget(session.userId, session.agentId);
    if (!target) return null;
    return {
      target,
    };
  }

  async deliverDeferredVoiceFollowUp(session, followUpPlan, replyText, runId = null) {
    if (!session || session.closed || !followUpPlan || session.deferFollowUpRequested !== true) {
      return { sent: false, skipped: true };
    }
    const manager = this.#messagingManager();
    if (!manager || typeof manager.sendMessage !== 'function') {
      return { sent: false, skipped: true, reason: 'Messaging manager unavailable.' };
    }

    const target = followUpPlan.target;
    if (!target?.platform || !target?.to) {
      return { sent: false, skipped: true, reason: 'No deferred follow-up target.' };
    }

    const status = typeof manager.getPlatformStatus === 'function'
      ? manager.getPlatformStatus(session.userId, target.platform, { agentId: session.agentId })
      : null;
    if (status && status.status !== 'connected') {
      return { sent: false, skipped: true, reason: `Platform ${target.platform} is not connected.` };
    }

    const body = String(replyText || '').trim();
    if (!body) {
      return { sent: false, skipped: true, reason: 'Reply text is empty.' };
    }

    const followUpContent = [
      'Update from your voice request:',
      '',
      body,
    ].join('\n');

    let sendResult;
    try {
      sendResult = await manager.sendMessage(
        session.userId,
        target.platform,
        target.to,
        followUpContent,
        {
          agentId: session.agentId,
          runId,
          persistConversation: true,
        },
      );
    } catch (err) {
      console.error('Failed to send deferred voice follow-up:', err);
      return {
        sent: false,
        skipped: false,
        success: false,
        error: err instanceof Error ? err.message : String(err),
        runId,
      };
    }

    session.deferFollowUpRequested = false;
    const label = this.#platformLabel(target.platform);
    await this.deliverAssistantMessage(
      session,
      `I sent the full result to your ${label} chat.`,
      { kind: 'final' },
    );

    return {
      sent: true,
      target,
      result: sendResult,
    };
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

  #messagingManager() {
    return this.agentEngine?.messagingManager || this.agentEngine?.app?.locals?.messagingManager || null;
  }

  #readScopedSetting(userId, agentId, key) {
    const row = db.prepare(
      'SELECT value FROM agent_settings WHERE user_id = ? AND agent_id = ? AND key = ?'
    ).get(userId, agentId, key);
    if (row) {
      try {
        return JSON.parse(row.value);
      } catch {
        return row.value;
      }
    }
    if (!isMainAgent(userId, agentId)) return null;
    const userRow = db.prepare(
      'SELECT value FROM user_settings WHERE user_id = ? AND key = ?'
    ).get(userId, key);
    if (!userRow) return null;
    try {
      return JSON.parse(userRow.value);
    } catch {
      return userRow.value;
    }
  }

  #resolvePreferredMessagingTarget(userId, agentId = null) {
    const manager = this.#messagingManager();
    if (!manager) return null;
    const scopedAgentId = resolveAgentId(userId, agentId);
    const platform = String(this.#readScopedSetting(userId, scopedAgentId, 'last_platform') || '').trim();
    const to = String(this.#readScopedSetting(userId, scopedAgentId, 'last_chat_id') || '').trim();
    if (!platform || !to) return null;

    const status = typeof manager.getPlatformStatus === 'function'
      ? manager.getPlatformStatus(userId, platform, { agentId: scopedAgentId })
      : null;
    if (!status || status.status !== 'connected') return null;
    return { platform, to };
  }

  #platformLabel(platformName) {
    const raw = String(platformName || '').trim();
    if (!raw) return 'message';
    return raw.replace(/[_-]+/g, ' ');
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
    const spokenContent = sanitizeSpeechText(content);

    let index = 0;
    let streamError = null;
    const ttsAttempts = this.#buildTtsAttemptOrder(session, voiceOptions);
    if (spokenContent) {
      try {
      for (const attempt of ttsAttempts) {
        index = 0;
        streamError = null;
        let attemptChunks = 0;
        try {
          await synthesizeVoiceReplyStream(
            spokenContent,
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
              attemptChunks += 1;
              index += 1;
            },
          );
          if (attemptChunks === 0) {
            throw new Error(`${attempt.provider} TTS produced no audio chunks.`);
          }
          streamError = null;
          break;
        } catch (error) {
          streamError = String(error?.message || error || 'Voice playback failed.');
          console.warn(`[VoiceRuntime] ${attempt.provider} TTS failed for flutter session ${sessionId}: ${streamError}`);
          if (attemptChunks > 0) {
            break;
          }
        }
      }
      } catch (error) {
        streamError = String(error?.message || error || 'Voice playback failed.');
      }
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

  async deliverWearableAssistantOutput(ws, sessionId, content, options = {}) {
    const session = this.getSession(sessionId);
    if (!session) {
      return;
    }
    const kind = String(options.kind || 'final').trim() || 'final';
    ws.send(JSON.stringify({
      type: 'voice:assistant_text',
      sessionId,
      content,
      kind,
    }));

    if (kind === 'final') {
      await session.setState('speaking', { kind });
    }

    const voiceOptions = normalizeVoiceSynthesisOptions({
      provider: session.voiceSettings?.liveProvider,
      model: session.voiceSettings?.liveTtsModel,
      voice: session.voiceSettings?.liveVoice,
      transport: 'wearable',
      responseFormat: 'wav',
    });
    const spokenContent = sanitizeSpeechText(content);
    let index = 0;
    let streamError = null;
    const ttsAttempts = this.#buildTtsAttemptOrder(session, voiceOptions);

    if (spokenContent) {
      try {
        for (const attempt of ttsAttempts) {
          index = 0;
          streamError = null;
          let attemptChunks = 0;
          try {
            await synthesizeVoiceReplyStream(
              spokenContent,
              attempt,
              async ({ audioBytes, mimeType }) => {
                if (session.closed || session.interrupted) return;
                ws.send(JSON.stringify({
                  type: 'voice:audio_chunk',
                  sessionId,
                  kind,
                  index,
                  audioBase64: audioBytes.toString('base64'),
                  mimeType,
                }));
                attemptChunks += 1;
                index += 1;
              },
            );
            if (attemptChunks === 0) {
              throw new Error(`${attempt.provider} TTS produced no audio chunks.`);
            }
            break;
          } catch (error) {
            streamError = String(error?.message || error || 'Voice playback failed.');
            console.warn(`[VoiceRuntime] ${attempt.provider} TTS failed for wearable session ${sessionId}: ${streamError}`);
            if (attemptChunks > 0) {
              break;
            }
          }
        }
      } catch (error) {
        streamError = String(error?.message || error || 'Voice playback failed.');
      }
    }

    if (!streamError && !session.closed && !session.interrupted) {
      ws.send(JSON.stringify({
        type: 'voice:audio_done',
        sessionId,
        kind,
        totalChunks: index,
      }));
    } else if (kind === 'final' && !session.closed && !session.interrupted) {
      ws.send(JSON.stringify({
        type: 'voice:error',
        sessionId,
        error: streamError,
        recoverable: true,
        phase: 'tts',
      }));
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
        transport: voiceOptions.transport,
        responseFormat: voiceOptions.responseFormat,
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
        timeoutMs: 20000,
      });
    }
    return attempts;
  }
}

module.exports = {
  VoiceRuntimeManager,
};
