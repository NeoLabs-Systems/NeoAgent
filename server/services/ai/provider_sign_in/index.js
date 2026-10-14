'use strict';

const crypto = require('crypto');
const db = require('../../../db/database');
const { createServiceLogger } = require('../../../utils/logger');
const { base64UrlSha256, sanitizeError } = require('../../../utils/security');
const { setProviderSecret } = require('../settings');
const openrouter = require('./openrouter');

// "Sign in with <provider>" for model providers: an OAuth flow that ends with
// the provider handing over an API key, saved exactly like a pasted BYOK key.
// A method module exports { providerId, label, authorizationUrl, exchangeCode };
// supporting another provider means adding its module to METHODS.
const METHODS = new Map([openrouter].map((method) => [method.providerId, method]));

const STATE_RE = /^model_[a-f0-9]{48}$/;
// Providers expire authorization codes after about ten minutes, so no flow
// needs to outlive that.
const FLOW_TTL_MS = 10 * 60 * 1000;
const EXPIRED_MESSAGE = 'This sign-in has expired. Start again from NeoAgent.';

// state -> { method, userId, agentId, codeVerifier, callbackUrl, startedAt, status, error }
const flows = new Map();
const logger = createServiceLogger('ProviderSignIn');

function hasSignInMethod(providerId) {
  return METHODS.has(providerId);
}

function isSignInState(state) {
  return STATE_RE.test(String(state || ''));
}

function pruneExpired(now) {
  for (const [state, flow] of flows) {
    if (now - flow.startedAt >= FLOW_TTL_MS) flows.delete(state);
  }
}

function pendingFlow(state) {
  pruneExpired(Date.now());
  const flow = flows.get(String(state || ''));
  return flow?.status === 'pending' ? flow : null;
}

function begin({ providerId, userId, agentId, baseUrl }) {
  const method = METHODS.get(providerId);
  if (!method) throw new Error('Sign-in is not available for this provider.');

  const now = Date.now();
  pruneExpired(now);
  const state = `model_${crypto.randomBytes(24).toString('hex')}`;
  const codeVerifier = crypto.randomBytes(48).toString('base64url');
  const callbackUrl = openrouter.callbackUrlFor(baseUrl);
  flows.set(state, {
    method,
    userId,
    agentId,
    codeVerifier,
    callbackUrl,
    startedAt: now,
    status: 'pending',
    error: null,
  });
  return {
    state,
    mode: callbackUrl ? 'redirect' : 'code',
    url: method.authorizationUrl({
      state,
      codeChallenge: base64UrlSha256(codeVerifier),
      callbackUrl,
    }),
  };
}

// What a person is approving when a held callback asks for confirmation.
function describePending(state) {
  const flow = pendingFlow(state);
  if (!flow) return null;
  const user = db.prepare('SELECT username FROM users WHERE id = ?').get(flow.userId);
  return {
    providerLabel: flow.method.label,
    username: user?.username || null,
    startedAt: new Date(flow.startedAt).toISOString().replace('T', ' ').slice(0, 19),
  };
}

// Exchanges the code and stores the key. `userId` is required when the code
// arrives from the app (paste flow); the browser callback is already tied to
// its owner through the OAuth handoff. A wrong pasted code reopens the flow
// so the person can paste again. The exchange is not tied to the request: a
// closed tab must not leave a minted key unstored.
async function complete(state, code, { userId = null } = {}) {
  const flow = pendingFlow(state);
  if (!flow || (userId !== null && flow.userId !== userId)) {
    throw new Error(EXPIRED_MESSAGE);
  }
  // Codes are single-use; claim the flow so a second callback or confirm
  // click cannot race this exchange.
  flow.status = 'exchanging';
  try {
    const { apiKey } = await flow.method.exchangeCode({ code, codeVerifier: flow.codeVerifier });
    setProviderSecret(flow.userId, flow.method.providerId, apiKey, flow.agentId);
    flow.status = 'completed';
    return { status: 'completed', providerId: flow.method.providerId };
  } catch (error) {
    const message = sanitizeError(error);
    logger.warn(`${flow.method.label} code exchange failed: ${message}`);
    if (flow.callbackUrl) {
      flow.status = 'failed';
      flow.error = message;
    } else {
      flow.status = 'pending';
    }
    throw error;
  }
}

function fail(state, message) {
  const flow = pendingFlow(state);
  if (!flow) return;
  flow.status = 'failed';
  flow.error = String(message || 'Sign-in failed.');
}

// Polled by the app that started a redirect sign-in. Only the owner may read
// it, and a finished result is handed out once.
function status(state, userId) {
  pruneExpired(Date.now());
  const flow = flows.get(String(state || ''));
  if (!flow || flow.userId !== userId) return null;
  const finished = flow.status === 'completed' || flow.status === 'failed';
  if (finished) flows.delete(state);
  return {
    status: finished ? flow.status : 'pending',
    providerId: flow.method.providerId,
    error: flow.error,
  };
}

module.exports = {
  EXPIRED_MESSAGE,
  begin,
  complete,
  describePending,
  fail,
  hasSignInMethod,
  isSignInState,
  status,
};
