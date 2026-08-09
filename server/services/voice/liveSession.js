'use strict';

const MAX_INPUT_BYTES = 25 * 1024 * 1024;

function voiceAbortError(message, code) {
  const error = new Error(message);
  error.name = 'AbortError';
  error.code = code;
  return error;
}

class VoiceLiveSession {
  constructor({
    id,
    userId,
    agentId = null,
    platform = 'voice_live',
    sink,
    voiceSettings,
    outputMode = 'audio_and_text',
    runtimeManager = null,
  }) {
    this.id = String(id || '').trim();
    this.userId = userId;
    this.agentId = agentId;
    this.platform = String(platform || 'voice_live').trim() || 'voice_live';
    this.sink = sink;
    this.voiceSettings = voiceSettings || {};
    this.outputMode = outputMode;
    this.runtimeManager = runtimeManager;
    this.state = 'idle';
    this.currentRunId = null;
    this.lastRunId = null;
    this.interrupted = false;
    this.inputMimeType = 'audio/pcm;rate=16000;channels=1';
    this.inputChunks = new Map();
    this.inputBytes = 0;
    this.activeTurnId = '';
    this.currentTurnId = '';
    this.highestContiguousSequence = -1;
    this.highestReceivedSequence = -1;
    this.finalSequence = null;
    this.lastPartialTranscript = '';
    this.lastFinalTranscript = '';
    this.lastAssistantText = '';
    this.assistantMessageCount = 0;
    this.closed = false;
    this.attached = true;
    this.turnAbortController = new AbortController();
  }

  get signal() {
    return this.turnAbortController.signal;
  }

  resetInput(mimeType = 'audio/pcm;rate=16000;channels=1') {
    this.inputMimeType = String(mimeType || this.inputMimeType).trim() || 'audio/pcm;rate=16000;channels=1';
    this.inputChunks = new Map();
    this.inputBytes = 0;
    this.activeTurnId = '';
    this.highestContiguousSequence = -1;
    this.highestReceivedSequence = -1;
    this.finalSequence = null;
    this.lastPartialTranscript = '';
  }

  resetTurnState() {
    if (!this.turnAbortController.signal.aborted) {
      this.turnAbortController.abort(voiceAbortError(
        'Voice turn was reset.',
        'VOICE_TURN_RESET',
      ));
    }
    this.turnAbortController = new AbortController();
    this.lastPartialTranscript = '';
    this.lastFinalTranscript = '';
    this.lastAssistantText = '';
    this.assistantMessageCount = 0;
    this.interrupted = false;
  }

  startTurn(turnId, mimeType = null) {
    this.resetInput(mimeType || this.inputMimeType);
    this.activeTurnId = String(turnId || '').trim();
    this.currentTurnId = this.activeTurnId;
  }

  appendInputChunk(chunk, mimeType = null, options = {}) {
    if (mimeType) {
      this.inputMimeType = String(mimeType).trim() || this.inputMimeType;
    }
    const turnId = String(options.turnId || '').trim();
    if (turnId && this.activeTurnId && turnId !== this.activeTurnId) {
      throw new Error('Audio chunk turn does not match the active voice turn.');
    }
    if (turnId && !this.activeTurnId) {
      this.activeTurnId = turnId;
    }
    const sequence = Number(options.sequence);
    if (!Number.isInteger(sequence) || sequence < 0) {
      throw new Error('Audio chunk sequence must be a non-negative integer.');
    }
    const payload = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk || []);
    if (payload.length === 0) {
      return {
        duplicate: false,
        receivedThrough: this.highestContiguousSequence,
        highestReceived: this.highestReceivedSequence,
      };
    }
    if (this.inputChunks.has(sequence)) {
      return {
        duplicate: true,
        receivedThrough: this.highestContiguousSequence,
        highestReceived: this.highestReceivedSequence,
      };
    }
    if (this.inputBytes + payload.length > MAX_INPUT_BYTES) {
      const error = new Error('Voice input exceeds the 25 MB session limit.');
      error.code = 'VOICE_INPUT_TOO_LARGE';
      throw error;
    }
    this.inputChunks.set(sequence, payload);
    this.inputBytes += payload.length;
    if (sequence > this.highestReceivedSequence) {
      this.highestReceivedSequence = sequence;
    }
    while (this.inputChunks.has(this.highestContiguousSequence + 1)) {
      this.highestContiguousSequence += 1;
    }
    return {
      duplicate: false,
      receivedThrough: this.highestContiguousSequence,
      highestReceived: this.highestReceivedSequence,
    };
  }

  markCommitPending(turnId, finalSequence) {
    const normalizedTurnId = String(turnId || '').trim();
    if (normalizedTurnId && this.activeTurnId && normalizedTurnId !== this.activeTurnId) {
      throw new Error('Voice commit turn does not match the active voice turn.');
    }
    if (normalizedTurnId && !this.activeTurnId) {
      this.activeTurnId = normalizedTurnId;
    }
    const normalizedFinalSequence = Number(finalSequence);
    if (!Number.isInteger(normalizedFinalSequence) || normalizedFinalSequence < 0) {
      throw new Error('Voice commit finalSequence must be a non-negative integer.');
    }
    this.finalSequence = normalizedFinalSequence;
    return {
      finalSequence: this.finalSequence,
      receivedThrough: this.highestContiguousSequence,
      ready: this.hasInputThrough(normalizedFinalSequence),
    };
  }

  hasInputThrough(sequence) {
    const normalizedSequence = Number(sequence);
    if (!Number.isInteger(normalizedSequence) || normalizedSequence < 0) {
      return false;
    }
    return this.highestContiguousSequence >= normalizedSequence;
  }

  getInputAudioBuffer(options = {}) {
    const contiguousOnly = options.contiguousOnly !== false;
    const throughSequence = Number.isInteger(options.throughSequence)
      ? Number(options.throughSequence)
      : null;
    const maxSequence = throughSequence != null
      ? throughSequence
      : (contiguousOnly ? this.highestContiguousSequence : this.highestReceivedSequence);
    if (!Number.isInteger(maxSequence) || maxSequence < 0) {
      return Buffer.alloc(0);
    }
    const ordered = [];
    for (let sequence = 0; sequence <= maxSequence; sequence += 1) {
      const chunk = this.inputChunks.get(sequence);
      if (!chunk) {
        if (contiguousOnly || throughSequence != null) {
          break;
        }
        continue;
      }
      ordered.push(chunk);
    }
    if (ordered.length === 0) {
      return Buffer.alloc(0);
    }
    return ordered.length === 1
      ? Buffer.from(ordered[0])
      : Buffer.concat(ordered);
  }

  async setState(state, extra = {}) {
    this.state = String(state || 'idle').trim() || 'idle';
    if (typeof this.sink?.setState === 'function') {
      await this.sink.setState(this, this.state, extra);
    }
  }

  async publishReady(extra = {}) {
    if (typeof this.sink?.publishReady === 'function') {
      await this.sink.publishReady(this, extra);
    }
  }

  async publishTranscriptPartial(text, metadata = {}) {
    const normalized = String(text || '').trim();
    if (!normalized || normalized === this.lastPartialTranscript) return;
    this.lastPartialTranscript = normalized;
    if (typeof this.sink?.publishTranscriptPartial === 'function') {
      await this.sink.publishTranscriptPartial(this, normalized, metadata);
    }
  }

  async publishTranscriptFinal(text, metadata = {}) {
    const normalized = String(text || '').trim();
    if (!normalized || normalized === this.lastFinalTranscript) return;
    this.lastFinalTranscript = normalized;
    this.lastPartialTranscript = normalized;
    if (typeof this.sink?.publishTranscriptFinal === 'function') {
      await this.sink.publishTranscriptFinal(this, normalized, metadata);
    }
  }

  async publishAssistantOutput(content, options = {}) {
    const normalized = String(content || '').trim();
    if (!normalized) return;
    this.lastAssistantText = normalized;
    this.assistantMessageCount += 1;
    if (typeof this.sink?.publishAssistantOutput === 'function') {
      await this.sink.publishAssistantOutput(this, normalized, options);
    }
  }

  async publishAssistantText(content, options = {}) {
    await this.publishAssistantOutput(content, { ...options, textOnly: true });
  }

  async publishAudioChunk(audioBytes, options = {}) {
    if (typeof this.sink?.publishAudioChunk === 'function') {
      await this.sink.publishAudioChunk(this, audioBytes, options);
    }
  }

  async publishAudioDone(options = {}) {
    if (typeof this.sink?.publishAudioDone === 'function') {
      await this.sink.publishAudioDone(this, options);
    }
  }

  async interruptPlayback() {
    this.interrupted = true;
    if (typeof this.sink?.interruptOutput === 'function') {
      await this.sink.interruptOutput(this);
    }
    await this.adapter?.interruptOutput?.(this);
  }

  async interruptOutput() {
    await this.interruptPlayback();
    if (!this.turnAbortController.signal.aborted) {
      this.turnAbortController.abort(voiceAbortError(
        'Voice output was interrupted.',
        'VOICE_INTERRUPTED',
      ));
    }
  }

  detachSink() {
    this.attached = false;
    this.sink = null;
  }

  attachSink(sink) {
    this.sink = sink;
    this.attached = true;
  }

  async publishError(message, extra = {}) {
    if (typeof this.sink?.publishError === 'function') {
      await this.sink.publishError(this, String(message || 'Voice session error'), extra);
    }
  }

  async close(reason = 'closed') {
    this.closed = true;
    if (!this.turnAbortController.signal.aborted) {
      this.turnAbortController.abort(voiceAbortError(
        `Voice session closed: ${reason}.`,
        'VOICE_SESSION_CLOSED',
      ));
    }
    if (typeof this.sink?.close === 'function') {
      await this.sink.close(this, reason);
    }
  }
}

module.exports = {
  VoiceLiveSession,
};
