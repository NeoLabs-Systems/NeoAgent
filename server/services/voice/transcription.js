'use strict';

const { getProviderRuntimeConfig } = require('../ai/models');
const { getVoiceRuntimeSettings } = require('./liveSettings');
const { AUTO_STT_PROVIDER, STT_PROVIDERS, transcribeVoiceInput } = require('./providers');
const { resolveApiKey } = require('./providers/credentials');

// A key set in the app's AI provider settings wins over the server env, the
// same precedence the chat models use.
const CREDENTIAL_SOURCES = Object.freeze({
  openai: { aiProvider: 'openai', env: ['OPENAI_API_KEY'] },
  gemini: { aiProvider: 'google', env: ['GOOGLE_AI_KEY', 'GEMINI_API_KEY'] },
  deepgram: { aiProvider: null, env: ['DEEPGRAM_API_KEY'] },
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
  resolveSttTarget,
  transcribeForUser,
};
