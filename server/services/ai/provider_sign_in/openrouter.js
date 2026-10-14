'use strict';

const { isLoopbackOrigin } = require('../../../config/origins');
const { fetchResponseText } = require('../../network/http');

// Sign in with OpenRouter: OAuth PKCE that ends with OpenRouter minting a
// user-controlled API key. Without a callback URL, OpenRouter shows a one-time
// code for the person to paste back instead (its documented headless mode).
const AUTH_URL = 'https://openrouter.ai/auth';
const KEY_EXCHANGE_URL = 'https://openrouter.ai/api/v1/auth/keys';
const KEY_LABEL = 'NeoAgent';

function callbackUrlFor(baseUrl = '') {
  if (!baseUrl.startsWith('https://') && !isLoopbackOrigin(baseUrl)) return null;
  return `${baseUrl}/api/integrations/oauth/callback`;
}

function authorizationUrl({ state, codeChallenge, callbackUrl }) {
  const url = new URL(AUTH_URL);
  if (callbackUrl) {
    url.searchParams.set('callback_url', callbackUrl);
    url.searchParams.set('state', state);
  }
  url.searchParams.set('code_challenge', codeChallenge);
  url.searchParams.set('code_challenge_method', 'S256');
  url.searchParams.set('key_label', KEY_LABEL);
  return url.toString();
}

function errorMessage(data) {
  if (typeof data?.error === 'string') return data.error;
  if (typeof data?.error?.message === 'string') return data.error.message;
  if (typeof data?.message === 'string') return data.message;
  return '';
}

async function exchangeCode({ code, codeVerifier }) {
  const { response, text } = await fetchResponseText(KEY_EXCHANGE_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({
      code,
      code_verifier: codeVerifier,
      code_challenge_method: 'S256',
    }),
    maxResponseBytes: 64 * 1024,
    serviceName: 'OpenRouter sign-in',
  });
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = null;
  }
  const apiKey = typeof data?.key === 'string' ? data.key.trim() : '';
  if (!response.ok || !apiKey) {
    throw new Error(errorMessage(data) || `OpenRouter did not return a key (HTTP ${response.status}).`);
  }
  const providerUserId = typeof data?.user_id === 'string' ? data.user_id.trim() : '';
  return { apiKey, providerUserId };
}

module.exports = {
  providerId: 'openrouter',
  label: 'OpenRouter',
  callbackUrlFor,
  authorizationUrl,
  exchangeCode,
};
