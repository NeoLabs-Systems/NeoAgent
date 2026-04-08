'use strict';

const crypto = require('crypto');
const { google } = require('googleapis');
const {
  describeEnvStatus,
  resolveGoogleOAuthConfig,
} = require('../../integrations/env');

const GOOGLE_AUTH_SCOPES = [
  'openid',
  'https://www.googleapis.com/auth/userinfo.email',
  'https://www.googleapis.com/auth/userinfo.profile',
];

function base64UrlSha256(value) {
  return crypto
    .createHash('sha256')
    .update(String(value || ''))
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function createOAuthClient() {
  const config = resolveGoogleOAuthConfig();
  return {
    config,
    client: new google.auth.OAuth2(
      config.clientId,
      config.clientSecret,
      config.redirectUri,
    ),
  };
}

function createGoogleAuthProvider() {
  return {
    key: 'google',
    label: 'Google',
    icon: 'google',
    getEnvStatus() {
      return describeEnvStatus(resolveGoogleOAuthConfig(), {
        label: 'Google sign-in',
      });
    },
    async beginOAuth({ state, codeVerifier }) {
      const { client, config } = createOAuthClient();
      if (!config.configured) {
        throw new Error('Google sign-in is not configured.');
      }
      const url = client.generateAuthUrl({
        access_type: 'offline',
        scope: GOOGLE_AUTH_SCOPES,
        state,
        prompt: 'select_account',
        code_challenge_method: 'S256',
        code_challenge: base64UrlSha256(codeVerifier),
      });
      return { url };
    },
    async finishOAuth({ code, codeVerifier }) {
      const { client, config } = createOAuthClient();
      if (!config.configured) {
        throw new Error('Google sign-in is not configured.');
      }
      const tokenResponse = await client.getToken({
        code,
        codeVerifier,
        redirect_uri: config.redirectUri,
      });
      client.setCredentials(tokenResponse.tokens || {});

      const oauth2 = google.oauth2({ auth: client, version: 'v2' });
      const response = await oauth2.userinfo.get();
      const profile = response.data || {};
      const providerUserId = String(profile.id || '').trim();
      const email = String(profile.email || '').trim().toLowerCase();
      if (!providerUserId || !email) {
        throw new Error('Google did not return a usable account identity.');
      }

      return {
        providerUserId,
        email,
        emailVerified: profile.verified_email === true,
        displayName: String(profile.name || '').trim(),
        avatarUrl: String(profile.picture || '').trim() || null,
        metadata: {
          givenName: String(profile.given_name || '').trim() || null,
          familyName: String(profile.family_name || '').trim() || null,
          locale: String(profile.locale || '').trim() || null,
        },
      };
    },
  };
}

module.exports = {
  createGoogleAuthProvider,
};
