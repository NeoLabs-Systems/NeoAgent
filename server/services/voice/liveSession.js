'use strict';

class VoiceLiveSession {
  constructor({
    id,
    userId,
    agentId = null,
    platform = 'voice_live',
    sink,
    voiceSettings,
    outputMode = 'audio_and_text',
  }) {
    this.id = String(id || '').trim();
    this.userId = userId;
    this.agentId = agentId;
    this.platform = String(platform || 'voice_live').trim() || 'voice_live';
    this.sink = sink;
    this.voiceSettings = voiceSettings || {};
    this.outputMode = outputMode;
    this.state = 'idle';
    this.currentRunId = null;
    this.interrupted = false;
    this.inputMimeType = 'audio/pcm;rate=16000;channels=1';
    this.inputChunks = new Map();
    this.inputBytes = 0;
    this.activeTurnId = '';
    this.highestContiguousSequence = -1;
    this.highestReceivedSequence = -1;
    this.finalSequence = null;
    this.lastPartialTranscript = '';
    this.lastFinalTranscript = '';
    this.lastAssistantText = '';
    this.assistantMessageCount = 0;
    this.closed = false;
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
    this.lastPartialTranscript = '';
    this.lastFinalTranscript = '';
    this.lastAssistantText = '';
    this.assistantMessageCount = 0;
    this.interrupted = false;
  }

  startTurn(turnId, mimeType = null) {
    this.resetInput(mimeType || this.inputMimeType);
    this.activeTurnId = String(turnId || '').trim();
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

  async publishTranscriptPartial(text) {
    const normalized = String(text || '').trim();
    if (!normalized || normalized === this.lastPartialTranscript) return;
    this.lastPartialTranscript = normalized;
    if (typeof this.sink?.publishTranscriptPartial === 'function') {
      await this.sink.publishTranscriptPartial(this, normalized);
    }
  }

  async publishTranscriptFinal(text) {
    const normalized = String(text || '').trim();
    this.lastFinalTranscript = normalized;
    this.lastPartialTranscript = normalized;
    if (typeof this.sink?.publishTranscriptFinal === 'function') {
      await this.sink.publishTranscriptFinal(this, normalized);
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

  async interruptOutput() {
    this.interrupted = true;
    if (typeof this.sink?.interruptOutput === 'function') {
      await this.sink.interruptOutput(this);
    }
  }

  async publishError(message, extra = {}) {
    if (typeof this.sink?.publishError === 'function') {
      await this.sink.publishError(this, String(message || 'Voice session error'), extra);
    }
  }

  async close(reason = 'closed') {
    this.closed = true;
    if (typeof this.sink?.close === 'function') {
      await this.sink.close(this, reason);
    }
  }
}

module.exports = {
  VoiceLiveSession,
};
