'use strict';

const { getProviderRuntimeConfig } = require('../ai/models');
const { resolveSttModel, transcribeVoiceInput } = require('./providers');
const { writeTempAudioFile, removeTempFile } = require('./liveAudio');

const DEFAULT_PARTIAL_DEBOUNCE_MS = 700;
const DEFAULT_MIN_PARTIAL_BYTES = 8000;

class BufferedLiveRelayAdapter {
  constructor({
    provider,
    partialDebounceMs = DEFAULT_PARTIAL_DEBOUNCE_MS,
    minPartialBytes = DEFAULT_MIN_PARTIAL_BYTES,
  }) {
    this.provider = provider;
    this.partialDebounceMs = partialDebounceMs;
    this.minPartialBytes = minPartialBytes;
    this._partialTimers = new Map();
    this._partialInFlight = new Set();
    this._closed = false;
  }

  async open() {
    this._closed = false;
  }

  async close(sessionId = null) {
    this._closed = true;
    if (sessionId) {
      this._clearPartialTimer(sessionId);
      this._partialInFlight.delete(sessionId);
    }
  }

  async onInputStart(session, options = {}) {
    session.startTurn(options.turnId, options.mimeType);
    this._clearPartialTimer(session.id);
    this._partialInFlight.delete(session.id);
  }

  async appendAudioChunk(session, audioBytes, options = {}) {
    const appendResult = session.appendInputChunk(audioBytes, options.mimeType, {
      turnId: options.turnId,
      sequence: options.sequence,
    });
    this._schedulePartialTranscript(session);
    return appendResult;
  }

  async commitInput(session, options = {}) {
    this._clearPartialTimer(session.id);
    const commitState = session.markCommitPending(options.turnId, options.finalSequence);
    if (!commitState.ready) {
      throw new Error(
        `Voice input is incomplete for commit (${commitState.receivedThrough}/${commitState.finalSequence}).`,
      );
    }
    const audioBytes = session.getInputAudioBuffer({
      throughSequence: commitState.finalSequence,
    });
    if (!audioBytes.length) {
      return '';
    }
    try {
      return await this._transcribeAudioSnapshot(audioBytes, session.inputMimeType, {
        model: session.voiceSettings?.liveSttModel,
        userId: session.userId,
        agentId: session.agentId,
        timeoutMs: 20000,
      });
    } finally {
      // Release buffered audio immediately after commit so completed turns do
      // not retain large input chunks until the next turn or explicit close.
      session.resetInput(session.inputMimeType);
    }
  }

  _schedulePartialTranscript(session) {
    if (session.inputBytes < this.minPartialBytes) {
      return;
    }
    this._clearPartialTimer(session.id);
    const timer = setTimeout(async () => {
      this._partialTimers.delete(session.id);
      if (this._closed || session.closed || this._partialInFlight.has(session.id)) {
        return;
      }
      this._partialInFlight.add(session.id);
      try {
        const snapshot = session.getInputAudioBuffer({
          contiguousOnly: true,
        });
        if (!snapshot.length) {
          return;
        }
        const transcript = await this._transcribeAudioSnapshot(snapshot, session.inputMimeType, {
          model: session.voiceSettings?.liveSttModel,
          userId: session.userId,
          agentId: session.agentId,
          timeoutMs: 6000,
        });
        if (transcript) {
          await session.publishTranscriptPartial(transcript);
        }
      } catch {
        // Partial guidance is best-effort only.
      } finally {
        this._partialInFlight.delete(session.id);
      }
    }, this.partialDebounceMs);
    timer.unref?.();
    this._partialTimers.set(session.id, timer);
  }

  _clearPartialTimer(sessionId) {
    const timer = this._partialTimers.get(sessionId);
    if (timer) {
      clearTimeout(timer);
      this._partialTimers.delete(sessionId);
    }
  }

  async _transcribeAudioSnapshot(audioBytes, mimeType, options = {}) {
    const { filePath, mimeType: fileMimeType } = await writeTempAudioFile(audioBytes, mimeType);
    try {
      let lastError = null;
      for (const attempt of this._buildSttAttempts(options)) {
        try {
          const transcript = await transcribeVoiceInput(filePath, {
            provider: attempt.provider,
            model: attempt.model,
            mimeType: fileMimeType,
            userId: options.userId,
            agentId: options.agentId,
            apiKey: attempt.apiKey,
            baseUrl: attempt.baseUrl,
            timeoutMs: options.timeoutMs,
          });
          return String(transcript || '').trim();
        } catch (error) {
          lastError = error;
        }
      }
      throw lastError || new Error('Voice transcription failed.');
    } finally {
      await removeTempFile(filePath);
    }
  }

  _buildSttAttempts(options = {}) {
    const attempts = [];
    const providers = [
      this.provider,
      ...['openai', 'deepgram', 'gemini'].filter((provider) => provider !== this.provider),
    ];
    for (const provider of providers) {
      const runtime = this._resolveProviderRuntime(provider, options.userId, options.agentId);
      attempts.push({
        provider,
        model: resolveSttModel(provider, provider === this.provider ? options.model : ''),
        apiKey: runtime.apiKey,
        baseUrl: runtime.baseUrl,
      });
    }
    return attempts;
  }

  _resolveProviderRuntime(provider, userId, agentId) {
    const normalizedProvider = String(provider || '').trim().toLowerCase();
    if (!normalizedProvider || normalizedProvider === 'deepgram') {
      return { apiKey: '', baseUrl: '' };
    }
    try {
      const runtime = getProviderRuntimeConfig(
        userId,
        normalizedProvider === 'gemini' ? 'google' : normalizedProvider,
        agentId,
      );
      return {
        apiKey: typeof runtime.apiKey === 'string' ? runtime.apiKey.trim() : '',
        baseUrl: typeof runtime.baseUrl === 'string' ? runtime.baseUrl.trim() : '',
      };
    } catch {
      return { apiKey: '', baseUrl: '' };
    }
  }
}

module.exports = {
  BufferedLiveRelayAdapter,
};
