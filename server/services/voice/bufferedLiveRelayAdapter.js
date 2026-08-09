'use strict';

const { resolveSttModel, transcribeVoiceInput } = require('./providers');
const { writeTempAudioFile, removeTempFile } = require('./liveAudio');

class BufferedLiveRelayAdapter {
  constructor({ provider }) {
    this.provider = provider;
    this.sessionId = null;
  }

  async open(session) {
    if (!session?.id) throw new Error('Buffered voice adapter requires a session.');
    this.sessionId = session.id;
  }

  async close() {
    this.sessionId = null;
  }

  async onInputStart(session, options = {}) {
    if (this.sessionId !== session.id) {
      throw new Error('Buffered voice adapter is not bound to this session.');
    }
    session.startTurn(options.turnId, options.mimeType);
  }

  async appendAudioChunk(session, audioBytes, options = {}) {
    return session.appendInputChunk(audioBytes, options.mimeType, {
      turnId: options.turnId,
      sequence: options.sequence,
    });
  }

  async commitInput(session, options = {}) {
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
        model: session.voiceSettings?.sttModel,
        userId: session.userId,
        agentId: session.agentId,
        apiKey: session.voiceSettings?.sttApiKey,
        baseUrl: session.voiceSettings?.sttBaseUrl,
        timeoutMs: 20000,
        signal: session.signal,
      });
    } finally {
      // Release buffered audio immediately after commit so completed turns do
      // not retain large input chunks until the next turn or explicit close.
      session.resetInput(session.inputMimeType);
    }
  }

  async _transcribeAudioSnapshot(audioBytes, mimeType, options = {}) {
    const { filePath, mimeType: fileMimeType } = await writeTempAudioFile(audioBytes, mimeType);
    try {
      const transcript = await transcribeVoiceInput(filePath, {
        provider: this.provider,
        model: resolveSttModel(this.provider, options.model),
        mimeType: fileMimeType,
        userId: options.userId,
        agentId: options.agentId,
        apiKey: options.apiKey,
        baseUrl: options.baseUrl,
        timeoutMs: options.timeoutMs,
        signal: options.signal,
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
