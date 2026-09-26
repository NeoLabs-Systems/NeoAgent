'use strict';

const { markSetupSectionComplete } = require('../setup/onboarding');
const { cleanLine, persistEnv, maskSecret } = require('./env_config');
const { httpError } = require('../../utils/http_error');

// Server-wide AI and tool provider credentials, stored as env keys.
const PROVIDERS = [
  { key: 'ANTHROPIC_API_KEY', label: 'Anthropic (Claude)', type: 'key' },
  { key: 'OPENAI_API_KEY', label: 'OpenAI', type: 'key' },
  { key: 'OPENAI_COMPATIBLE_API_KEY', label: 'Custom OpenAI-compatible token', type: 'key' },
  { key: 'OPENAI_COMPATIBLE_BASE_URL', label: 'Custom OpenAI-compatible base URL', type: 'url' },
  { key: 'XAI_API_KEY', label: 'xAI (Grok)', type: 'key' },
  { key: 'GOOGLE_AI_KEY', label: 'Google (Gemini)', type: 'key' },
  { key: 'MINIMAX_API_KEY', label: 'MiniMax', type: 'key' },
  { key: 'NVIDIA_API_KEY', label: 'NVIDIA NIM', type: 'key' },
  { key: 'OPENROUTER_API_KEY', label: 'OpenRouter', type: 'key' },
  { key: 'BRAVE_SEARCH_API_KEY', label: 'Brave Search', type: 'key' },
  { key: 'DEEPGRAM_API_KEY', label: 'Deepgram (Voice)', type: 'key' },
  { key: 'GITHUB_COPILOT_ACCESS_TOKEN', label: 'GitHub Copilot', type: 'key' },
  { key: 'OPENAI_CODEX_ACCESS_TOKEN', label: 'OpenAI Codex', type: 'key' },
  { key: 'OLLAMA_URL', label: 'Ollama (Local)', type: 'url' },
  { key: 'OPENAI_BASE_URL', label: 'OpenAI Base URL override', type: 'url' },
  { key: 'ANTHROPIC_BASE_URL', label: 'Anthropic Base URL override', type: 'url' },
  { key: 'XAI_BASE_URL', label: 'xAI Base URL override', type: 'url' },
];

const PROVIDER_BY_KEY = new Map(PROVIDERS.map((provider) => [provider.key, provider]));

function listProviders() {
  const providers = PROVIDERS.map(({ key, label, type }) => {
    const value = process.env[key] || '';
    return {
      key,
      label,
      type,
      configured: Boolean(value),
      hint: type === 'url' ? value : maskSecret(value),
    };
  });
  return { providers };
}

function assertProviderUrl(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw httpError(400, 'Provider URL must be a valid HTTP or HTTPS URL');
  }
  if (!['http:', 'https:'].includes(url.protocol) || !url.hostname) {
    throw httpError(400, 'Provider URL must use HTTP or HTTPS');
  }
  if (url.username || url.password) {
    throw httpError(400, 'Provider URL must not contain embedded credentials');
  }
}

/** Sets or (with an empty value) clears one provider credential. */
function updateProvider(key, value) {
  const provider = PROVIDER_BY_KEY.get(key);
  if (!provider) throw httpError(400, 'Unknown provider key');
  const cleaned = cleanLine(value || '');
  if (provider.type === 'url' && cleaned) assertProviderUrl(cleaned);
  persistEnv(key, cleaned);
  if (cleaned) markSetupSectionComplete('providers');
  return { ok: true };
}

module.exports = { listProviders, updateProvider };
