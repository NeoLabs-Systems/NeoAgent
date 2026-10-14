'use strict';

const openrouter = require('../../ai/provider_sign_in/openrouter');
const { setProviderSecret } = require('../../ai/settings');
const { base64UrlSha256 } = require('../../../utils/security');
const { readEnvBool } = require('../../../../runtime/env');

function isEnabled() {
  return readEnvBool('NEOAGENT_OPENROUTER_SIGN_IN_ENABLED', true);
}

function assertEnabled() {
  if (!isEnabled()) throw new Error('OpenRouter account sign-in is disabled by the administrator.');
}

function createOpenRouterAuthProvider() {
  return {
    key: 'openrouter',
    label: 'OpenRouter',
    icon: 'openrouter',
    assertEnabled,
    getEnvStatus({ baseUrl } = {}) {
      if (!isEnabled()) {
        return { configured: false, summary: 'OpenRouter account sign-in is disabled by the administrator.' };
      }
      const configured = Boolean(openrouter.callbackUrlFor(baseUrl));
      return {
        configured,
        summary: configured
          ? 'OpenRouter sign-in is available.'
          : 'OpenRouter account sign-in requires an HTTPS or localhost server URL.',
      };
    },
    async beginOAuth({ state, codeVerifier, baseUrl }) {
      assertEnabled();
      const callbackUrl = openrouter.callbackUrlFor(baseUrl);
      if (!callbackUrl) {
        throw new Error('OpenRouter account sign-in requires an HTTPS or localhost server URL.');
      }
      return {
        url: openrouter.authorizationUrl({
          state,
          codeChallenge: base64UrlSha256(codeVerifier),
          callbackUrl,
        }),
      };
    },
    async finishOAuth({ code, codeVerifier }) {
      assertEnabled();
      const { apiKey, providerUserId } = await openrouter.exchangeCode({ code, codeVerifier });
      if (!providerUserId) {
        throw new Error('OpenRouter did not return a usable account identity.');
      }
      return { providerUserId, email: null, emailVerified: false, apiKey };
    },
    saveCredentials(userId, identity) {
      assertEnabled();
      setProviderSecret(userId, openrouter.providerId, identity.apiKey);
    },
  };
}

module.exports = { createOpenRouterAuthProvider };
