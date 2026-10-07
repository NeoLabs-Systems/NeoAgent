'use strict';

const { base64UrlSha256 } = require('../../../utils/security');
const { createServiceLogger } = require('../../../utils/logger');
const {
  buildAuthorizationUrl,
  exchangeAuthorizationCode,
  resolveCallbackClientId,
} = require('../../chatgpt/oauth');
const { getInstallation, saveClientId } = require('../../chatgpt/installation');
const {
  PROVIDER_ID,
  disconnect,
  hasPlanUsage,
  saveConnection,
} = require('../../chatgpt/connections');
const { adoptChatGptAsDefaultModel, releaseChatGptDefaultModels } = require('../../chatgpt/default_model');
const { openLoopbackCallback } = require('./loopback_callback');

const log = createServiceLogger('ChatGPTSignIn');
const APP_NAME = 'NeoAgent';

// The OIDC nonce must be unpredictable and recoverable at code exchange; the
// PKCE verifier (secret, stored encrypted with the state) already is both.
function nonceFor(codeVerifier) {
  return base64UrlSha256(`nonce:${codeVerifier}`);
}

// OpenAI currently allows ChatGPT sign-in only for apps that run on the
// user's own machine, so it redirects to a 127.0.0.1 listener. That listener
// is reachable only when the browser runs on the same machine as this server.
function createChatGptAuthProvider() {
  return {
    key: PROVIDER_ID,
    label: 'ChatGPT',
    icon: 'chatgpt',
    getEnvStatus(context = {}) {
      if (context.sameMachine) {
        return { configured: true, summary: 'ChatGPT sign-in is available on this computer.' };
      }
      return {
        configured: false,
        summary: 'ChatGPT sign-in is only available when NeoAgent runs on this computer.',
      };
    },
    async beginOAuth({ state, codeVerifier, ttlMs, complete, fail }) {
      const installation = getInstallation();
      let redirectUri = '';
      const listener = await openLoopbackCallback({
        state,
        providerKey: PROVIDER_ID,
        ttlMs,
        async onCallback(params) {
          const error = params.get('error');
          if (error) {
            const message = params.get('error_description') || error;
            fail(message);
            throw new Error(message);
          }
          await complete({
            code: params.get('code') || '',
            clientId: params.get('client_id') || '',
            redirectUri,
          });
          return { message: 'You can close this tab and return to NeoAgent.' };
        },
      });
      redirectUri = listener.redirectUri;
      try {
        const url = await buildAuthorizationUrl({
          clientId: installation.clientId,
          redirectUri,
          state,
          nonce: nonceFor(codeVerifier),
          codeVerifier,
          appName: APP_NAME,
          hostId: installation.hostId,
        });
        return { url };
      } catch (error) {
        listener.close();
        throw error;
      }
    },
    async finishOAuth({ code, codeVerifier, clientId, redirectUri }) {
      if (!code) throw new Error('ChatGPT did not return an authorization code.');
      const registeredClientId = resolveCallbackClientId(clientId, getInstallation().clientId);
      // Keep the registration even if this code exchange fails, so the next
      // attempt does not register another app.
      saveClientId(registeredClientId);
      const { identity, credentials } = await exchangeAuthorizationCode({
        clientId: registeredClientId,
        code,
        codeVerifier,
        redirectUri,
        nonce: nonceFor(codeVerifier),
      });
      if (!identity.email) {
        throw new Error('ChatGPT did not share an email address for this account.');
      }
      const connection = {
        subject: identity.subject,
        email: identity.email,
        clientId: registeredClientId,
        credentials,
      };
      return {
        providerUserId: identity.subject,
        email: identity.email,
        emailVerified: identity.emailVerified,
        displayName: identity.name,
        avatarUrl: identity.picture || null,
        metadata: { planUsage: hasPlanUsage(connection) },
        connection,
      };
    },
    async onAuthorized({ userId, result, identity }) {
      saveConnection(userId, identity.connection);
      // A fresh account or an explicit link means the user chose ChatGPT;
      // a routine sign-in only renews tokens and keeps their model choice.
      if (!hasPlanUsage(identity.connection)) return;
      if (result.action !== 'link' && !result.created) return;
      try {
        await adoptChatGptAsDefaultModel(userId);
      } catch (error) {
        log.warn(`Could not set ChatGPT as the default model for user ${userId}: ${error.message}`);
      }
    },
    async onUnlinked({ userId }) {
      await disconnect(userId);
      releaseChatGptDefaultModels(userId);
    },
  };
}

module.exports = {
  createChatGptAuthProvider,
};
