'use strict';

// A NeoRouter that NeoAgent works through. There are two kinds: the server's,
// set up by an admin and kept in the environment, and a user's own, from
// their sign-in and stored like a BYOK key. A user's own connection wins.
// Each connection lists the kinds of work (roles) that go through it; the
// rest keep their usual providers.
const ROLES = Object.freeze(['chat', 'system_one', 'transcription', 'live', 'embeddings', 'images', 'search']);
const ENV = Object.freeze({ baseUrl: 'NEOROUTER_BASE_URL', apiKey: 'NEOROUTER_API_KEY', roles: 'NEOROUTER_ROLES' });
const PROVIDER_ID = 'neorouter';

// "router.local:3333", "https://router.example.com/app/" → the /v1 API base.
function apiBaseFor(address) {
  const raw = String(address || '').trim();
  if (!raw) return null;
  try {
    const url = new URL(/^https?:\/\//i.test(raw) ? raw : `https://${raw}`);
    if (url.username || url.password) return null;
    return `${url.origin}/v1`;
  } catch {
    return null;
  }
}

// Unset means every role; a stored list keeps only the known ones.
function normalizeRoles(value) {
  if (value == null) return [...ROLES];
  const list = Array.isArray(value) ? value : String(value).split(',');
  const wanted = new Set(list.map((role) => String(role).trim()));
  return ROLES.filter((role) => wanted.has(role));
}

function build(scope, apiBase, apiKey, roles) {
  if (!apiBase || !apiKey) return null;
  return { scope, apiBase, origin: new URL(apiBase).origin, apiKey, roles: new Set(roles) };
}

function serverConnection() {
  const env = (name) => String(process.env[name] || '').trim();
  return build('server', apiBaseFor(env(ENV.baseUrl)), env(ENV.apiKey), normalizeRoles(process.env[ENV.roles] || null));
}

function userConnection(userId, agentId = null) {
  if (!userId) return null;
  // Lazy: the settings module loads the voice catalogs, which use this one.
  const { getAiSettings, getProviderConfigs, getProviderSecrets } = require('../settings');
  const apiKey = String(getProviderSecrets(userId, agentId)[PROVIDER_ID] || '').trim();
  if (!apiKey) return null;
  const apiBase = apiBaseFor(getProviderConfigs(userId, agentId)[PROVIDER_ID]?.baseUrl);
  return build('user', apiBase, apiKey, normalizeRoles(getAiSettings(userId, agentId).neorouter_roles));
}

function connectionFor(userId, agentId = null) {
  return userConnection(userId, agentId) || serverConnection();
}

/** The connection that handles `role` for this user, or null. */
function forRole(userId, agentId, role) {
  const connection = connectionFor(userId, agentId);
  return connection?.roles.has(role) ? connection : null;
}

// Other providers are always allowed; NeoRouter only for the roles it has.
function providerServesRole(providerId, userId, agentId, role) {
  return providerId !== PROVIDER_ID || Boolean(forRole(userId, agentId, role));
}

module.exports = {
  ENV,
  PROVIDER_ID,
  ROLES,
  apiBaseFor,
  connectionFor,
  forRole,
  normalizeRoles,
  providerServesRole,
  serverConnection,
  userConnection,
};
