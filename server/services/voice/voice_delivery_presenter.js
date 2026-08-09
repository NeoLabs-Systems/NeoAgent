'use strict';

const { synthesizeVoiceReplyStream, sanitizeSpeechText } = require('./providers');
const { createServiceLogger } = require('../../utils/logger');

const logger = createServiceLogger('VoiceDelivery');

class VoiceDeliveryPresenter {
  async present(session, entry) {
    const content = String(entry?.payload?.content || entry?.content || '').trim();
    if (!content) return { presented: false, reason: 'empty_content' };
    const kind = String(entry?.messageKind || entry?.kind || 'progress').trim();
    const messageId = String(entry?.id || entry?.messageId || '').trim();
    const runId = String(entry?.runId || '').trim() || null;
    const turnId = String(
      entry?.payload?.metadata?.turnId || session.currentTurnId || '',
    ).trim();
    const livenessState = String(
      entry?.payload?.metadata?.liveness?.status || '',
    ).trim();
    const presentationState = ['blocked', 'waiting'].includes(livenessState)
      ? livenessState
      : 'working';
    const metadata = {
      kind,
      messageId,
      runId,
      turnId,
      presentationState,
    };

    if (!session.attached || !session.sink) {
      session.pendingDeliveries = [
        ...(session.pendingDeliveries || []).filter((item) => item.kind === 'final'),
        { content, ...metadata },
      ].slice(-4);
      return { presented: false, queued: true };
    }
    if (session.state === 'listening' || session.state === 'transcribing') {
      session.pendingDeliveries = [
        ...(session.pendingDeliveries || []).filter((item) => item.kind === 'final'),
        { content, ...metadata },
      ].slice(-4);
      return { presented: false, queued: true };
    }

    if (kind !== 'final') {
      await session.setState(presentationState, metadata);
    }
    await session.publishAssistantText(content, metadata);
    if (session.voiceSettings?.mediaMode === 'duplex') {
      await session.adapter.presentDelivery(content, metadata);
      return { presented: true, native: true };
    }
    await this.#speakComposed(session, content, metadata);
    return { presented: true, native: false };
  }

  async flush(session) {
    const deliveries = session.pendingDeliveries || [];
    session.pendingDeliveries = [];
    for (const delivery of deliveries) {
      await this.present(session, delivery);
    }
  }

  async #speakComposed(session, content, metadata) {
    const spoken = sanitizeSpeechText(content);
    if (!spoken) return;
    await session.setState(
      metadata.kind === 'final' ? 'speaking' : metadata.presentationState,
      metadata,
    );
    let sequence = 0;
    try {
      await synthesizeVoiceReplyStream(
        spoken,
        {
          provider: session.voiceSettings.ttsProvider,
          model: session.voiceSettings.ttsModel,
          voice: session.voiceSettings.ttsVoice,
          apiKey: session.voiceSettings.ttsApiKey,
          baseUrl: session.voiceSettings.ttsBaseUrl,
          timeoutMs: 20000,
          signal: session.signal,
          transport: session.platform === 'wearable_live' ? 'wearable' : 'flutter',
        },
        async ({ audioBytes, mimeType }) => {
          await session.publishAudioChunk(audioBytes, {
            ...metadata,
            mimeType,
            sequence,
          });
          sequence += 1;
        },
      );
      await session.publishAudioDone({ ...metadata, totalChunks: sequence });
      if (metadata.kind === 'final') await session.setState('idle', metadata);
    } catch (error) {
      if (session.signal.aborted) return;
      logger.warn(`${session.voiceSettings.ttsProvider} TTS failed`, error?.message || error);
      await session.publishError('Voice playback failed. The text reply is still available.', {
        ...metadata,
        recoverable: true,
        phase: 'tts',
      });
      await session.setState('degraded', { ...metadata, phase: 'tts' });
    }
  }
}

module.exports = {
  VoiceDeliveryPresenter,
};
