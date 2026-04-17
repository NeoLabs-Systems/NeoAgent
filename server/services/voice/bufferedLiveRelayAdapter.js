'use strict';

const { resolveSttModel, transcribeVoiceInput } = require('./providers');
const { writeTempAudioFile, removeTempFile } = require('./liveAudio');

const DEFAULT_PARTIAL_DEBOUNCE_MS = 1200;
const DEFAULT_MIN_PARTIAL_BYTES = 12000;

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

  async onInputStart(session) {
    session.resetInput();
    this._clearPartialTimer(session.id);
    this._partialInFlight.delete(session.id);
  }

  async appendAudioChunk(session, audioBytes, options = {}) {
    session.appendInputChunk(audioBytes, options.mimeType);
    this._schedulePartialTranscript(session);
  }

  async commitInput(session) {
    this._clearPartialTimer(session.id);
    const audioBytes = session.getInputAudioBuffer();
    if (!audioBytes.length) {
      return '';
    }
    return this._transcribeAudioSnapshot(audioBytes, session.inputMimeType, {
      model: session.voiceSettings?.liveSttModel,
      userId: session.userId,
      agentId: session.agentId,
    });
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
        const snapshot = session.getInputAudioBuffer();
        const transcript = await this._transcribeAudioSnapshot(snapshot, session.inputMimeType, {
          model: session.voiceSettings?.liveSttModel,
          userId: session.userId,
          agentId: session.agentId,
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
      const model = resolveSttModel(this.provider, options.model);
      const transcript = await transcribeVoiceInput(filePath, {
        provider: this.provider,
        model,
        mimeType: fileMimeType,
        userId: options.userId,
        agentId: options.agentId,
      });
      return String(transcript || '').trim();
    } finally {
      await removeTempFile(filePath);
    }
  }
}

module.exports = {
  BufferedLiveRelayAdapter,
};
