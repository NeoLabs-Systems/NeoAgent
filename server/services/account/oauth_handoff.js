'use strict';

const crypto = require('crypto');

// An OAuth state is a bearer handle: whoever finishes or polls it gets the
// result. These helpers tie it to the client that started the flow.
//
// The starting client's session records the state. When the provider redirects
// back into that same browser (web popup), the callback finishes directly.
// Native apps finish in the system browser, which has a different session, so
// the callback is held until the person in that browser confirms it. That way
// a link someone else started cannot silently complete in a victim's browser.

const BOUND_STATE_TTL_MS = 30 * 60 * 1000;
const HELD_CALLBACK_TTL_MS = 10 * 60 * 1000;

const heldCallbacks = new Map();

function bindOAuthState(session, state) {
  const now = Date.now();
  const bound = {};
  for (const [key, startedAt] of Object.entries(session.oauthStates || {})) {
    if (now - startedAt < BOUND_STATE_TTL_MS) bound[key] = startedAt;
  }
  bound[state] = now;
  session.oauthStates = bound;
}

function isOAuthStateBound(session, state) {
  const startedAt = session?.oauthStates?.[state];
  return Boolean(startedAt) && Date.now() - startedAt < BOUND_STATE_TTL_MS;
}

function releaseOAuthState(session, state) {
  if (!session?.oauthStates?.[state]) return;
  const { [state]: _released, ...rest } = session.oauthStates;
  session.oauthStates = rest;
}

function pruneHeldCallbacks(now) {
  for (const [token, entry] of heldCallbacks) {
    if (entry.expiresAt <= now) heldCallbacks.delete(token);
  }
}

// Returns a one-time token that releases the callback once confirmed.
function holdOAuthCallback(state, callback) {
  const now = Date.now();
  pruneHeldCallbacks(now);
  const token = crypto.randomBytes(24).toString('base64url');
  heldCallbacks.set(token, { state, callback, expiresAt: now + HELD_CALLBACK_TTL_MS });
  return token;
}

function takeOAuthCallback(token) {
  pruneHeldCallbacks(Date.now());
  const entry = heldCallbacks.get(String(token || ''));
  if (!entry) return null;
  heldCallbacks.delete(String(token));
  return { state: entry.state, callback: entry.callback };
}

module.exports = {
  bindOAuthState,
  holdOAuthCallback,
  isOAuthStateBound,
  releaseOAuthState,
  takeOAuthCallback,
};
