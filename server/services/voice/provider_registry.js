'use strict';

const { BufferedLiveRelayAdapter } = require('./bufferedLiveRelayAdapter');
const { OpenAiRealtimeShell } = require('./providers/openai_realtime_shell');
const {
  DEFAULT_STT_MODELS,
  DEFAULT_TTS_MODELS,
  DEFAULT_TTS_VOICES,
  resolveSttModel,
  resolveTtsModel,
  resolveTtsVoice,
} = require('./providers/provider_defaults');
const { StreamingSttAdapter } = require('./streaming_stt_adapter');
const { normalizeInputMode, normalizeMediaMode } = require('./voice_config');

const PROVIDERS = Object.freeze({
  openai: Object.freeze({
    id: 'openai',
    label: 'OpenAI',
    streamingStt: Object.freeze({ model: DEFAULT_STT_MODELS.openai, sampleRate: 24000 }),
    boundedStt: Object.freeze({ model: 'gpt-transcribe' }),
    streamingTts: Object.freeze({
      model: DEFAULT_TTS_MODELS.openai,
      voice: DEFAULT_TTS_VOICES.openai,
    }),
    duplexShell: Object.freeze({ model: 'gpt-realtime-2.1', voice: 'marin' }),
  }),
  deepgram: Object.freeze({
    id: 'deepgram',
    label: 'Deepgram',
    streamingStt: Object.freeze({ model: DEFAULT_STT_MODELS.deepgram, sampleRate: 24000 }),
    boundedStt: Object.freeze({ model: DEFAULT_STT_MODELS.deepgram }),
    streamingTts: Object.freeze({
      model: DEFAULT_TTS_MODELS.deepgram,
      voice: DEFAULT_TTS_VOICES.deepgram,
    }),
    duplexShell: null,
  }),
  gemini: Object.freeze({
    id: 'gemini',
    label: 'Gemini',
    streamingStt: null,
    boundedStt: Object.freeze({ model: DEFAULT_STT_MODELS.gemini }),
    streamingTts: Object.freeze({
      model: DEFAULT_TTS_MODELS.gemini,
      voice: DEFAULT_TTS_VOICES.gemini,
    }),
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
      sttModel: resolveSttModel(sttProvider, settings.sttModel)
        || provider.streamingStt?.model
        || provider.boundedStt.model,
      ttsProvider,
      ttsModel: resolveTtsModel(ttsProvider, settings.ttsModel),
      ttsVoice: resolveTtsVoice(ttsProvider, settings.ttsVoice),
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
