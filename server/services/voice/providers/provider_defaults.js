'use strict';

const DEFAULT_STT_PROVIDER = 'openai';
const DEFAULT_TTS_PROVIDER = 'openai';
const STT_PROVIDERS = Object.freeze(['openai', 'deepgram', 'gemini']);
const TTS_PROVIDERS = STT_PROVIDERS;
const DEFAULT_STT_MODELS = Object.freeze({
  openai: 'gpt-live-transcribe',
  deepgram: 'nova-3',
  gemini: 'gemini-3-flash-preview',
});
const DEFAULT_TTS_MODELS = Object.freeze({
  openai: 'gpt-4o-mini-tts',
  deepgram: 'aura-2-thalia-en',
  gemini: 'gemini-3.1-flash-tts-preview',
});
const RETIRED_DEFAULT_TTS_MODELS = Object.freeze({
  gemini: Object.freeze(['gemini-2.5-flash-preview-tts']),
});
const DEFAULT_TTS_VOICES = Object.freeze({
  openai: 'marin',
  deepgram: '',
  gemini: 'Kore',
});
const EMOJI_SPEECH_REGEX = /[\p{Extended_Pictographic}\p{Emoji_Presentation}\p{Regional_Indicator}\u200D\uFE0F\u20E3]/gu;

function normalizeProvider(provider, supported, fallback) {
  const value = String(provider || '').trim().toLowerCase();
  return supported.includes(value) ? value : fallback;
}

function normalizeSttProvider(provider) {
  return normalizeProvider(provider, STT_PROVIDERS, DEFAULT_STT_PROVIDER);
}

function normalizeTtsProvider(provider) {
  return normalizeProvider(provider, TTS_PROVIDERS, DEFAULT_TTS_PROVIDER);
}

function resolveSttModel(provider, requestedModel) {
  const id = normalizeSttProvider(provider);
  return String(requestedModel || '').trim() || DEFAULT_STT_MODELS[id];
}

function resolveTtsModel(provider, requestedModel) {
  const id = normalizeTtsProvider(provider);
  const requested = String(requestedModel || '').trim();
  if (!requested || RETIRED_DEFAULT_TTS_MODELS[id]?.includes(requested)) {
    return DEFAULT_TTS_MODELS[id];
  }
  return requested;
}

function resolveTtsVoice(provider, requestedVoice) {
  const id = normalizeTtsProvider(provider);
  return String(requestedVoice || '').trim() || DEFAULT_TTS_VOICES[id];
}

function normalizeVoiceSynthesisOptions(options = {}) {
  const provider = normalizeTtsProvider(options.provider);
  return {
    provider,
    model: resolveTtsModel(provider, options.model),
    voice: resolveTtsVoice(provider, options.voice),
    transport: String(options.transport || '').trim().toLowerCase(),
    responseFormat: String(options.responseFormat || '').trim().toLowerCase(),
  };
}

function sanitizeSpeechText(value) {
  return String(value || '')
    .replace(EMOJI_SPEECH_REGEX, ' ')
    .replace(/[ \t]{2,}/g, ' ')
    .replace(/\s+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

module.exports = {
  DEFAULT_STT_MODELS,
  DEFAULT_STT_PROVIDER,
  DEFAULT_TTS_MODELS,
  DEFAULT_TTS_PROVIDER,
  DEFAULT_TTS_VOICES,
  STT_PROVIDERS,
  TTS_PROVIDERS,
  normalizeSttProvider,
  normalizeTtsProvider,
  normalizeVoiceSynthesisOptions,
  resolveSttModel,
  resolveTtsModel,
  resolveTtsVoice,
  sanitizeSpeechText,
};
