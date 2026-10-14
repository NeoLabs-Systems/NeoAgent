'use strict';

// 'auto' picks the first provider in STT_PROVIDERS that has an API key.
const AUTO_STT_PROVIDER = 'auto';
const STT_PROVIDERS = Object.freeze(['openai', 'gemini', 'deepgram']);
const DEFAULT_STT_MODELS = Object.freeze({
  openai: 'gpt-transcribe',
  gemini: 'gemini-3-flash-preview',
  deepgram: 'nova-3',
});

function normalizeSttProvider(provider) {
  const value = String(provider || '').trim().toLowerCase();
  return STT_PROVIDERS.includes(value) ? value : AUTO_STT_PROVIDER;
}

// With 'auto' the model stays empty until a concrete provider is chosen.
function resolveSttModel(provider, requestedModel) {
  const requested = String(requestedModel || '').trim();
  const id = normalizeSttProvider(provider);
  if (id === AUTO_STT_PROVIDER) return requested;
  return requested || DEFAULT_STT_MODELS[id];
}

module.exports = {
  AUTO_STT_PROVIDER,
  DEFAULT_STT_MODELS,
  STT_PROVIDERS,
  normalizeSttProvider,
  resolveSttModel,
};
