'use strict';

const { BufferedLiveRelayAdapter } = require('./bufferedLiveRelayAdapter');
const { OpenAiRealtimeShell } = require('./providers/openai_realtime_shell');
const { StreamingSttAdapter } = require('./streaming_stt_adapter');
const { normalizeInputMode, normalizeMediaMode } = require('./voice_config');

const PROVIDERS = Object.freeze({
  openai: Object.freeze({
    id: 'openai',
    label: 'OpenAI',
    streamingStt: Object.freeze({ model: 'gpt-live-transcribe', sampleRate: 24000 }),
    boundedStt: Object.freeze({ model: 'gpt-transcribe' }),
    streamingTts: Object.freeze({ model: 'gpt-4o-mini-tts', voice: 'marin' }),
    duplexShell: Object.freeze({ model: 'gpt-realtime-2.1', voice: 'marin' }),
  }),
  deepgram: Object.freeze({
    id: 'deepgram',
    label: 'Deepgram',
    streamingStt: Object.freeze({ model: 'nova-3', sampleRate: 24000 }),
    boundedStt: Object.freeze({ model: 'nova-3' }),
    streamingTts: Object.freeze({ model: 'aura-2-thalia-en', voice: '' }),
    duplexShell: null,
  }),
  gemini: Object.freeze({
    id: 'gemini',
    label: 'Gemini',
    streamingStt: null,
    boundedStt: Object.freeze({ model: 'gemini-3-flash-preview' }),
    streamingTts: Object.freeze({ model: 'gemini-2.5-flash-preview-tts', voice: 'Kore' }),
    duplexShell: null,
  }),
});

function normalizeProvider(value, capability) {
  const provider = String(value || '').trim().toLowerCase();
  if (PROVIDERS[provider]?.[capability]) return provider;
  return 'openai';
}

class VoiceProviderRegistry {
  describe() {
    return Object.values(PROVIDERS).map((provider) => ({
      id: provider.id,
      label: provider.label,
      streamingStt: provider.streamingStt,
      boundedStt: provider.boundedStt,
      streamingTts: provider.streamingTts,
      duplexShell: provider.duplexShell,
    }));
  }

  resolve(settings = {}) {
    const sttProvider = normalizeProvider(settings.sttProvider, 'boundedStt');
    const ttsProvider = normalizeProvider(settings.ttsProvider, 'streamingTts');
    const requestedMode = normalizeMediaMode(settings.mediaMode);
    const duplex = requestedMode === 'auto'
      && sttProvider === ttsProvider
      && Boolean(PROVIDERS[sttProvider].duplexShell);
    const provider = PROVIDERS[sttProvider];
    return {
      mediaMode: duplex ? 'duplex' : 'composed',
      requestedMode,
      inputMode: normalizeInputMode(settings.inputMode),
      sttProvider,
      sttModel: String(settings.sttModel || '').trim()
        || provider.streamingStt?.model
        || provider.boundedStt.model,
      ttsProvider,
      ttsModel: String(settings.ttsModel || '').trim()
        || PROVIDERS[ttsProvider].streamingTts.model,
      ttsVoice: String(settings.ttsVoice || '').trim()
        || PROVIDERS[ttsProvider].streamingTts.voice,
      duplexProvider: duplex ? sttProvider : null,
      duplexModel: duplex ? PROVIDERS[sttProvider].duplexShell.model : null,
      duplexVoice: duplex
        ? (String(settings.ttsVoice || '').trim() || PROVIDERS[sttProvider].duplexShell.voice)
        : null,
      inputSampleRate: duplex
        ? PROVIDERS[sttProvider].streamingStt.sampleRate
        : (provider.streamingStt?.sampleRate || 24000),
    };
  }

  createMediaAdapter(resolved, options = {}) {
    if (resolved.mediaMode === 'duplex' && resolved.duplexProvider === 'openai') {
      return new OpenAiRealtimeShell({ ...options, config: resolved });
    }
    if (resolved.sttProvider === 'openai' || resolved.sttProvider === 'deepgram') {
      return new StreamingSttAdapter({ provider: resolved.sttProvider });
    }
    return new BufferedLiveRelayAdapter({
      ...options,
      provider: resolved.sttProvider,
    });
  }
}

module.exports = {
  PROVIDERS,
  VoiceProviderRegistry,
  normalizeProvider,
};
