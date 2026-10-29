'use strict';

const crypto = require('crypto');
const os = require('os');
const { fetchResponseText } = require('../../network/http');
const { createServiceLogger } = require('../../../utils/logger');
const { sanitizeError } = require('../../../utils/security');
const { ENV, PROVIDER_ID, ROLES, apiBaseFor, serverConnection, userConnection } = require('./connection');
const { describeOffer } = require('./offer');

// "Connect NeoRouter": NeoRouter's device sign-in (OAuth 2.0 device flow). The
// person approves NeoAgent in NeoRouter, choosing what it may use, while this
// server polls for the key. No callback reaches NeoAgent, so it works the same
// for a NeoRouter on the home network as for a public one.
// scope 'server' stores the connection for everyone (admins only); 'user'
// stores it as the person's own key.
const CLIENT_ID = 'neoagent';
const FLOW_TTL_MS = 10 * 60 * 1000;
const SCOPES = 'chat moderation transcription live embedding image search';
const LIVE_PROVIDER_BY_PROTOCOL = Object.freeze({ openai_live: 'neorouter_openai', gemini_live: 'neorouter_google' });

const logger = createServiceLogger('NeoRouterSignIn');
// id -> { scope, userId, agentId, apiBase, deviceCode, intervalMs, expiresAt, status, error }
const flows = new Map();

function pruneExpired(now = Date.now()) {
  for (const [id, flow] of flows) {
    if (flow.expiresAt <= now && flow.status === 'pending') flows.delete(id);
  }
}

async function postForm(url, fields) {
  const { response, text } = await fetchResponseText(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body: new URLSearchParams(fields).toString(),
    maxResponseBytes: 64 * 1024,
    serviceName: 'NeoRouter sign-in',
    timeoutMs: 15000,
  });
  let data = null;
  try {
    data = JSON.parse(text || 'null');
  } catch {
    data = null;
  }
  return { ok: response.ok, status: response.status, data };
}

// The live voice provider that reaches the router's live models, if any.
function liveProviderFor(offer) {
  const protocol = ['openai_live', 'gemini_live'].find((item) => offer.liveProtocols.includes(item));
  return protocol ? LIVE_PROVIDER_BY_PROTOCOL[protocol] : null;
}

const isNeoRouterLive = (provider) => Object.values(LIVE_PROVIDER_BY_PROTOCOL).includes(provider);

// Whether live voice can work with this provider: it needs a key.
function liveProviderUsable(provider, { scope, userId, agentId }) {
  const { LIVE_VOICE_PROVIDERS, normalizeLiveProvider } = require('../../voice/live/catalog');
  const { getProviderRuntimeConfig } = require('../models');
  const { runtimeProvider } = LIVE_VOICE_PROVIDERS[normalizeLiveProvider(provider)];
  return Boolean(getProviderRuntimeConfig(scope === 'server' ? null : userId, runtimeProvider, agentId).apiKey);
}

// Live voice is picked per server or person. Connecting, or switching the
// live role on, hands it to NeoRouter; switching the role off gives the
// choice back. `onlyIfUnusable` is for later checks: once the router has
// live models, voice moves to it only when the current choice cannot work
// (models often arrive after connecting, or once paid ones are allowed).
async function applyLiveChoice(connection, { scope, userId, agentId, onlyIfUnusable = false, offer = null }) {
  const { persistEnv } = require('../../admin/env_config');
  const { applySettingsUpdate } = require('../../settings/store');
  const current = scope === 'server'
    ? String(process.env.VOICE_LIVE_PROVIDER || '')
    : require('../settings').getAiSettings(userId, agentId).voice_live_provider;
  let next = current;
  if (connection?.roles.has('live')) {
    const known = offer || await describeOffer(connection).catch(() => null);
    const routed = known && liveProviderFor(known);
    const keep = onlyIfUnusable && liveProviderUsable(current, { scope, userId, agentId })
      && (!isNeoRouterLive(current) || routed === current);
    next = keep ? current : routed || current;
  } else if (isNeoRouterLive(current)) {
    next = '';
  }
  if (next === current) return;
  if (scope === 'server') persistEnv('VOICE_LIVE_PROVIDER', next);
  else applySettingsUpdate({ userId, agentId, patch: { voice_live_provider: next, voice_live_model: '' }, source: 'neorouter' });
}

async function store(flow, apiKey) {
  const { persistEnv } = require('../../admin/env_config');
  const { setProviderConfig, setProviderSecret, getAiSettings } = require('../settings');
  const { applySettingsUpdate } = require('../../settings/store');
  if (flow.scope === 'server') {
    persistEnv(ENV.baseUrl, flow.apiBase);
    persistEnv(ENV.apiKey, apiKey);
    persistEnv(ENV.roles, ROLES.join(','));
    await applyLiveChoice(serverConnection(), flow);
    return;
  }
  setProviderConfig(flow.userId, PROVIDER_ID, { baseUrl: flow.apiBase, enabled: true }, flow.agentId);
  setProviderSecret(flow.userId, PROVIDER_ID, apiKey, flow.agentId);
  const patch = { neorouter_roles: [...ROLES] };
  const connection = userConnection(flow.userId, flow.agentId);
  const offer = await describeOffer(connection).catch(() => null);
  // System One is off until someone picks it; connecting a router with
  // decision models is that choice.
  if (offer?.roles.system_one > 0 && getAiSettings(flow.userId, flow.agentId).system_one_model === 'off') patch.system_one_model = 'auto';
  applySettingsUpdate({ userId: flow.userId, agentId: flow.agentId, patch, source: 'neorouter' });
  await applyLiveChoice(connection, flow);
}

function schedule(id, delayMs) {
  setTimeout(() => poll(id).catch((error) => logger.warn(`Polling failed: ${sanitizeError(error)}`)), delayMs).unref?.();
}

async function poll(id) {
  const flow = flows.get(id);
  if (!flow || flow.status !== 'pending') return;
  if (Date.now() >= flow.expiresAt) {
    flow.status = 'failed';
    flow.error = 'The sign-in expired. Start again.';
    return;
  }
  const { ok, data } = await postForm(`${new URL(flow.apiBase).origin}/oauth/token`, {
    grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
    device_code: flow.deviceCode,
    client_id: CLIENT_ID,
  }).catch((error) => ({ ok: false, data: { error: 'network', error_description: error.message } }));
  if (ok && data?.access_token) {
    try {
      await store(flow, String(data.access_token));
      flow.status = 'completed';
    } catch (error) {
      flow.status = 'failed';
      flow.error = sanitizeError(error);
    }
    return;
  }
  const code = data?.error;
  if (code === 'slow_down') flow.intervalMs += 5000;
  if (code === 'authorization_pending' || code === 'slow_down' || code === 'network') {
    schedule(id, flow.intervalMs);
    return;
  }
  flow.status = 'failed';
  flow.error = code === 'access_denied' ? 'The connection was declined in NeoRouter.' : (data?.error_description || 'NeoRouter did not hand out a key.');
}

/**
 * Starts connecting. Returns the link that opens NeoRouter's approval page
 * and the code it shows, for the person to compare.
 */
async function begin({ scope, userId, agentId = null, address }) {
  pruneExpired();
  const apiBase = apiBaseFor(address);
  if (!apiBase) throw new Error('Enter the address of your NeoRouter, for example https://router.example.com.');
  const origin = new URL(apiBase).origin;
  let started;
  try {
    started = await postForm(`${origin}/oauth/device/code`, {
      client_id: CLIENT_ID,
      client_name: `NeoAgent (${os.hostname()})`,
      scope: SCOPES,
    });
  } catch {
    throw new Error(`Could not reach NeoRouter at ${origin}.`);
  }
  if (!started.ok || !started.data?.device_code) {
    throw new Error(`${origin} did not answer like a NeoRouter. Check the address.`);
  }
  const id = crypto.randomBytes(18).toString('hex');
  flows.set(id, {
    scope,
    userId,
    agentId,
    apiBase,
    deviceCode: String(started.data.device_code),
    intervalMs: Math.max(1, Number(started.data.interval) || 5) * 1000,
    expiresAt: Date.now() + Math.min(FLOW_TTL_MS, (Number(started.data.expires_in) || 600) * 1000),
    status: 'pending',
    error: null,
  });
  schedule(id, Math.max(1, Number(started.data.interval) || 5) * 1000);
  return {
    id,
    url: String(started.data.verification_uri_complete || started.data.verification_uri),
    userCode: String(started.data.user_code || ''),
  };
}

// Polled by the app. Only the person who started it may read it; a finished
// result is handed out once.
function status(id, userId) {
  pruneExpired();
  const flow = flows.get(String(id || ''));
  if (!flow || flow.userId !== userId) return null;
  if (flow.status !== 'pending') flows.delete(id);
  return { status: flow.status, error: flow.error };
}

async function disconnect({ scope, userId, agentId = null }) {
  if (scope === 'server') {
    const { persistEnv } = require('../../admin/env_config');
    for (const key of Object.values(ENV)) persistEnv(key, '');
    await applyLiveChoice(null, { scope, userId, agentId });
    return;
  }
  const { setProviderConfig, setProviderSecret } = require('../settings');
  setProviderSecret(userId, PROVIDER_ID, '', agentId);
  setProviderConfig(userId, PROVIDER_ID, { baseUrl: '' }, agentId);
  await applyLiveChoice(null, { scope, userId, agentId });
}

async function updateRoles({ scope, userId, agentId = null, roles }) {
  const { normalizeRoles } = require('./connection');
  const list = normalizeRoles(roles);
  if (scope === 'server') {
    require('../../admin/env_config').persistEnv(ENV.roles, list.join(','));
    await applyLiveChoice(serverConnection(), { scope, userId, agentId });
    return list;
  }
  require('../../settings/store').applySettingsUpdate({ userId, agentId, patch: { neorouter_roles: list }, source: 'neorouter' });
  await applyLiveChoice(userConnection(userId, agentId), { scope, userId, agentId });
  return list;
}

module.exports = { applyLiveChoice, begin, disconnect, status, updateRoles };
