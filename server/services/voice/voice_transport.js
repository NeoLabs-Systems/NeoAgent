'use strict';

class VoiceTransport {
  constructor(kind) {
    if (new.target === VoiceTransport) {
      throw new TypeError('VoiceTransport is an abstract transport boundary.');
    }
    this.kind = kind;
  }
}

class SocketVoiceTransport extends VoiceTransport {
  constructor(socket, getCapabilities) {
    super('socket');
    this.socket = socket;
    this.getCapabilities = getCapabilities;
  }

  #emit(event, session, payload = {}) {
    this.socket.emit(event, { sessionId: session.id, ...payload });
  }

  async publishReady(session, extra = {}) {
    const settings = session.voiceSettings;
    const duplex = settings.mediaMode === 'duplex';
    this.#emit('voice:session_ready', session, {
      mediaMode: settings.mediaMode,
      requestedMediaMode: settings.requestedMode,
      inputMode: settings.inputMode,
      provider: duplex ? settings.duplexProvider : settings.sttProvider,
      model: duplex ? settings.duplexModel : settings.sttModel,
      voice: duplex ? settings.duplexVoice : settings.ttsVoice,
      inputSampleRate: settings.inputSampleRate,
      capabilities: this.getCapabilities(),
      activeRunId: session.currentRunId,
      ...extra,
    });
  }

  async setState(session, state, extra = {}) {
    this.#emit('voice:assistant_state', session, { state, ...extra });
  }

  async publishTranscriptPartial(session, content, extra = {}) {
    this.#emit('voice:transcript_partial', session, { content, ...extra });
  }

  async publishTranscriptFinal(session, content, extra = {}) {
    this.#emit('voice:transcript_final', session, { content, ...extra });
  }

  async publishAssistantOutput(session, content, options = {}) {
    this.#emit('voice:assistant_text', session, { content, ...options });
  }

  async publishAudioChunk(session, bytes, options = {}) {
    this.#emit('voice:audio_chunk', session, {
      ...options,
      audioBase64: Buffer.from(bytes).toString('base64'),
    });
  }

  async publishAudioDone(session, options = {}) {
    this.#emit('voice:audio_done', session, options);
  }

  async interruptOutput(session) {
    this.#emit('voice:assistant_state', session, { state: 'interrupted' });
  }

  async publishError(session, message, extra = {}) {
    this.#emit('voice:error', session, { error: message, ...extra });
  }

  async close(session, reason) {
    this.#emit('voice:assistant_state', session, { state: 'closed', reason });
  }
}

module.exports = {
  SocketVoiceTransport,
  VoiceTransport,
};
