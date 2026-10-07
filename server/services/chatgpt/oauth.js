'use strict';

const crypto = require('crypto');
const { fetchResponseText } = require('../network/http');
const { base64UrlSha256 } = require('../../utils/security');

// Sign in with ChatGPT: OpenAI's OAuth server with dynamic client
// registration. The first authorization uses the placeholder client id and the
// callback returns the registered one, which every later request reuses.
const ISSUER = 'https://auth.openai.com';
const RESOURCE = 'https://api.openai.com/v1';
const DYNAMIC_CLIENT_ID = 'dynamic_agent_client';
const PLAN_USAGE_SCOPE = 'chatgpt.tokens.use.direct';
const SCOPES = ['openid', 'profile', 'email', 'offline_access', 'resource.invoke', PLAN_USAGE_SCOPE];
const CLIENT_ID_RE = /^[a-zA-Z0-9_-]{1,200}$/;
const REQUEST_TIMEOUT_MS = 15000;
const JWKS_TTL_MS = 60 * 60 * 1000;
const CLOCK_TOLERANCE_S = 5;

let discoveryPromise = null;
let jwksCache = null;

async function fetchJson(url, options, serviceName) {
  const { response, text } = await fetchResponseText(url, {
    ...options,
    timeoutMs: REQUEST_TIMEOUT_MS,
    maxResponseBytes: 512 * 1024,
    serviceName,
  });
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = null;
  }
  return { response, data };
}

function oauthError(data, status, fallback) {
  const code = typeof data?.error === 'string' ? data.error : '';
  const description = typeof data?.error_description === 'string' ? data.error_description : '';
  const error = new Error(description || code || `${fallback} (HTTP ${status})`);
  error.code = code || 'oauth_error';
  error.status = status;
  return error;
}

function discover() {
  discoveryPromise ??= (async () => {
    const { response, data } = await fetchJson(
      `${ISSUER}/.well-known/openid-configuration`,
      { method: 'GET', headers: { Accept: 'application/json' } },
      'ChatGPT sign-in discovery',
    );
    if (!response.ok || data?.issuer !== ISSUER) {
      throw new Error('ChatGPT sign-in configuration could not be verified.');
    }
    for (const key of ['authorization_endpoint', 'token_endpoint', 'jwks_uri', 'revocation_endpoint']) {
      const value = data[key];
      if (key === 'revocation_endpoint' && value === undefined) continue;
      if (typeof value !== 'string' || new URL(value).origin !== ISSUER) {
        throw new Error('ChatGPT sign-in configuration could not be verified.');
      }
    }
    return data;
  })().catch((error) => {
    discoveryPromise = null;
    throw error;
  });
  return discoveryPromise;
}

async function loadJwks(forceRefresh) {
  if (!forceRefresh && jwksCache && jwksCache.expiresAt > Date.now()) return jwksCache.keys;
  const config = await discover();
  const { response, data } = await fetchJson(
    config.jwks_uri,
    { method: 'GET', headers: { Accept: 'application/json' } },
    'ChatGPT sign-in keys',
  );
  if (!response.ok || !Array.isArray(data?.keys)) {
    throw new Error('ChatGPT identity verification is temporarily unavailable.');
  }
  jwksCache = { keys: data.keys, expiresAt: Date.now() + JWKS_TTL_MS };
  return data.keys;
}

async function findSigningKey(kid) {
  for (const forceRefresh of [false, true]) {
    const jwk = (await loadJwks(forceRefresh)).find((key) => key?.kid === kid && key?.kty === 'RSA');
    if (jwk) return crypto.createPublicKey({ key: jwk, format: 'jwk' });
  }
  throw new Error('ChatGPT signed the identity with an unknown key.');
}

function decodeSegment(segment) {
  return JSON.parse(Buffer.from(segment, 'base64url').toString('utf8'));
}

// Verifies an OpenID Connect ID token (RS256) and returns the identity it
// asserts. `nonce` is required for fresh sign-ins and absent on refreshes.
async function verifyIdToken(idToken, { clientId, nonce }) {
  const invalid = () => new Error('The ChatGPT identity could not be verified. Please sign in again.');
  const parts = String(idToken || '').split('.');
  if (parts.length !== 3) throw invalid();

  let header;
  let claims;
  try {
    header = decodeSegment(parts[0]);
    claims = decodeSegment(parts[1]);
  } catch {
    throw invalid();
  }
  if (header?.alg !== 'RS256' || typeof header.kid !== 'string') throw invalid();

  const key = await findSigningKey(header.kid);
  const signatureValid = crypto.verify(
    'RSA-SHA256',
    Buffer.from(`${parts[0]}.${parts[1]}`),
    key,
    Buffer.from(parts[2], 'base64url'),
  );
  if (!signatureValid) throw invalid();

  const nowS = Math.floor(Date.now() / 1000);
  const audiences = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  const claimsValid = claims.iss === ISSUER
    && audiences.includes(clientId)
    && (audiences.length === 1 || claims.azp === clientId)
    && (claims.azp === undefined || claims.azp === clientId)
    && typeof claims.exp === 'number' && claims.exp + CLOCK_TOLERANCE_S > nowS
    && typeof claims.iat === 'number'
    && typeof claims.sub === 'string' && claims.sub.length > 0
    && (nonce === undefined || claims.nonce === nonce);
  if (!claimsValid) throw invalid();

  return {
    subject: claims.sub,
    email: typeof claims.email === 'string' ? claims.email.trim().toLowerCase() : '',
    emailVerified: claims.email_verified === true,
    name: typeof claims.name === 'string' ? claims.name.trim() : '',
    picture: typeof claims.picture === 'string' ? claims.picture.trim() : '',
  };
}

function readTokenResponse(data, previousScopes = []) {
  const scope = typeof data?.scope === 'string' ? data.scope : previousScopes.join(' ');
  const scopes = scope.split(/\s+/).filter(Boolean);
  const valid = typeof data?.access_token === 'string' && data.access_token
    && String(data.token_type || '').toLowerCase() === 'bearer'
    && typeof data.expires_in === 'number' && data.expires_in > 0
    && typeof data.refresh_token === 'string' && data.refresh_token;
  if (!valid) {
    throw new Error('ChatGPT returned incomplete credentials. Please sign in again.');
  }
  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresAt: Date.now() + data.expires_in * 1000,
    scopes,
  };
}

async function tokenRequest(params, failureLabel) {
  const config = await discover();
  const { response, data } = await fetchJson(config.token_endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Accept: 'application/json',
    },
    body: new URLSearchParams({ ...params, resource: RESOURCE }).toString(),
  }, 'ChatGPT token exchange');
  if (!response.ok) throw oauthError(data, response.status, failureLabel);
  return data || {};
}

async function buildAuthorizationUrl({ clientId, redirectUri, state, nonce, codeVerifier, appName, hostId }) {
  const config = await discover();
  const url = new URL(config.authorization_endpoint);
  url.search = new URLSearchParams({
    client_id: clientId || DYNAMIC_CLIENT_ID,
    response_type: 'code',
    redirect_uri: redirectUri,
    scope: SCOPES.join(' '),
    resource: RESOURCE,
    state,
    nonce,
    code_challenge_method: 'S256',
    code_challenge: base64UrlSha256(codeVerifier),
    ext_agent_host_id: hostId,
  }).toString();
  if (!clientId) url.searchParams.set('agent_name_hint', appName);
  return url.toString();
}

// The callback carries the registered client id; a registration that did not
// complete comes back without one (or with the placeholder).
function resolveCallbackClientId(returnedClientId, savedClientId) {
  const clientId = returnedClientId || savedClientId || '';
  if (!CLIENT_ID_RE.test(clientId) || clientId === DYNAMIC_CLIENT_ID) {
    throw new Error('ChatGPT did not complete app registration. Please try signing in again.');
  }
  if (savedClientId && returnedClientId && savedClientId !== returnedClientId) {
    throw new Error('ChatGPT returned a different app registration. Please try signing in again.');
  }
  return clientId;
}

async function exchangeAuthorizationCode({ clientId, code, codeVerifier, redirectUri, nonce }) {
  const data = await tokenRequest({
    grant_type: 'authorization_code',
    client_id: clientId,
    code,
    code_verifier: codeVerifier,
    redirect_uri: redirectUri,
  }, 'ChatGPT sign-in failed');
  if (typeof data.id_token !== 'string') {
    throw new Error('ChatGPT did not return a verifiable identity. Please try signing in again.');
  }
  const identity = await verifyIdToken(data.id_token, { clientId, nonce });
  return { identity, credentials: readTokenResponse(data) };
}

async function refreshCredentials({ clientId, refreshToken, subject, scopes }) {
  const data = await tokenRequest({
    grant_type: 'refresh_token',
    client_id: clientId,
    refresh_token: refreshToken,
  }, 'ChatGPT token refresh failed');
  if (typeof data.id_token === 'string') {
    const identity = await verifyIdToken(data.id_token, { clientId });
    if (identity.subject !== subject) {
      throw new Error('The refreshed ChatGPT identity does not match this account. Sign in again.');
    }
  }
  return readTokenResponse(data, scopes);
}

async function revokeRefreshToken({ clientId, refreshToken }) {
  const config = await discover();
  if (!config.revocation_endpoint) return;
  const { response } = await fetchJson(config.revocation_endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      token: refreshToken,
      token_type_hint: 'refresh_token',
      client_id: clientId,
    }).toString(),
  }, 'ChatGPT token revocation');
  if (response.status !== 200) {
    throw new Error(`ChatGPT token revocation returned HTTP ${response.status}.`);
  }
}

module.exports = {
  PLAN_USAGE_SCOPE,
  RESOURCE,
  buildAuthorizationUrl,
  exchangeAuthorizationCode,
  refreshCredentials,
  resolveCallbackClientId,
  revokeRefreshToken,
};
