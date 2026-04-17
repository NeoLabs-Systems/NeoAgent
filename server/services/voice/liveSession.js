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
    this.inputMimeType = 'audio/pcm;rate=16000;channels=1';
    this.inputChunks = [];
    this.inputBytes = 0;
    this.lastPartialTranscript = '';
    this.lastFinalTranscript = '';
    this.lastAssistantText = '';
    this.assistantMessageCount = 0;
    this.closed = false;
  }

  resetInput(mimeType = 'audio/pcm;rate=16000;channels=1') {
    this.inputMimeType = String(mimeType || this.inputMimeType).trim() || 'audio/pcm;rate=16000;channels=1';
    this.inputChunks = [];
    this.inputBytes = 0;
    this.lastPartialTranscript = '';
  }

  resetTurnState() {
    this.lastPartialTranscript = '';
    this.lastFinalTranscript = '';
    this.lastAssistantText = '';
    this.assistantMessageCount = 0;
  }

  appendInputChunk(chunk, mimeType = null) {
    if (mimeType) {
      this.inputMimeType = String(mimeType).trim() || this.inputMimeType;
    }
    const payload = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk || []);
    if (payload.length === 0) return;
    this.inputChunks.push(payload);
    this.inputBytes += payload.length;
  }

  getInputAudioBuffer() {
    return this.inputChunks.length === 1
      ? Buffer.from(this.inputChunks[0])
      : Buffer.concat(this.inputChunks);
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
