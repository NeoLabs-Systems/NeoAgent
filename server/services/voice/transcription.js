'use strict';

const { getProviderRuntimeConfig } = require('../ai/models');
const { getVoiceRuntimeSettings } = require('./liveSettings');
const { AUTO_STT_PROVIDER, STT_PROVIDERS, transcribeVoiceInput } = require('./providers');
const { DEFAULT_STT_MODELS } = require('./providers/provider_defaults');
const { resolveApiKey } = require('./providers/credentials');
const { forRole } = require('../ai/neorouter/connection');

// A key set in the app's AI provider settings wins over the server env, the
// same precedence the chat models use.
const CREDENTIAL_SOURCES = Object.freeze({
  openai: { aiProvider: 'openai', env: ['OPENAI_API_KEY'], label: 'OpenAI' },
  gemini: { aiProvider: 'google', env: ['GOOGLE_AI_KEY', 'GEMINI_API_KEY'], label: 'Google Gemini' },
  deepgram: { aiProvider: null, env: ['DEEPGRAM_API_KEY'], label: 'Deepgram' },
});

function sttCredentials(userId, agentId, provider) {
  const { aiProvider, env } = CREDENTIAL_SOURCES[provider];
  const runtime = aiProvider ? getProviderRuntimeConfig(userId, aiProvider, agentId) : {};
  return {
    apiKey: String(runtime.apiKey || '').trim() || resolveApiKey(env),
    baseUrl: String(runtime.baseUrl || '').trim(),
  };
}

function resolveSttTarget(userId, agentId, settings) {
  // On automatic, a NeoRouter that handles transcription picks the model; it
  // speaks OpenAI's transcription API.
  const router = settings.sttProvider === AUTO_STT_PROVIDER ? forRole(userId, agentId, 'transcription') : null;
  if (router) return { provider: 'openai', model: 'auto', apiKey: router.apiKey, baseUrl: router.apiBase };
  if (settings.sttProvider !== AUTO_STT_PROVIDER) {
    return {
      provider: settings.sttProvider,
      model: settings.sttModel,
      ...sttCredentials(userId, agentId, settings.sttProvider),
    };
  }
  for (const provider of STT_PROVIDERS) {
    const credentials = sttCredentials(userId, agentId, provider);
    if (credentials.apiKey) return { provider, model: '', ...credentials };
  }
  throw new Error(
    'No speech-to-text provider has an API key. Add an OpenAI, Google Gemini or Deepgram key, '
    + 'or choose a provider under Settings → Voice.',
  );
}

// What Settings → Voice offers: each provider and whether it has a key, and
// whether automatic goes through a NeoRouter.
function describeSttProviders(userId, agentId = null) {
  return {
    neorouter: Boolean(forRole(userId, agentId, 'transcription')),
    providers: STT_PROVIDERS.map((id) => ({
      id,
      label: CREDENTIAL_SOURCES[id].label,
      defaultModel: DEFAULT_STT_MODELS[id],
      available: Boolean(sttCredentials(userId, agentId, id).apiKey),
    })),
  };
}

// Transcribes recorded audio with the user's configured speech-to-text
// provider: voice notes, dictation, the transcribe_audio tool, social video.
async function transcribeForUser(filePath, { userId, agentId = null, mimeType, signal, timeoutMs } = {}) {
  const target = resolveSttTarget(userId, agentId, getVoiceRuntimeSettings(userId, agentId));
  const transcript = await transcribeVoiceInput(filePath, {
    ...target,
    mimeType,
    signal,
    timeoutMs,
  });
  return String(transcript || '').trim();
}

module.exports = {
  describeSttProviders,
  resolveSttTarget,
  transcribeForUser,
};
