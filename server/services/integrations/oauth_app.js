'use strict';

const db = require('../../db/database');
const { resolveOAuthConfig } = require('./env');
const { decryptValue, encryptValue } = require('./secrets');

// Client IDs, secrets and tenant IDs are opaque printable tokens; anything with
// whitespace or control characters is a paste mistake.
const CREDENTIAL_PATTERN = /^[\x21-\x7e]{1,512}$/;

function text(value) {
  return String(value ?? '').trim();
}

function cleanCredential(value, label) {
  const cleaned = text(value);
  if (cleaned && !CREDENTIAL_PATTERN.test(cleaned)) {
    throw new Error(`${label} contains spaces or unsupported characters.`);
  }
  return cleaned;
}

/**
 * The OAuth client an official integration signs accounts in with. A server
 * app from `<envPrefix>_OAUTH_*` applies to every account and locks user setup;
 * without one, each user registers their own app. An OAuth app belongs to the
 * account, so it is stored encrypted per user and shared by all their agents.
 *
 * `fields` are optional extra settings (for example a Microsoft tenant), each
 * `{ name, label, env, defaultValue, hint }`. `alternatives` names other
 * integrations that reach the same data without registering an app.
 */
function createOAuthApp({
  providerKey, label, envPrefix, consoleUrl, notes, scopes = [], fields = [], alternatives = [],
}) {
  // Callers pass their { userId, agentId } scope; only the user matters here.
  function userIdOf({ userId } = {}) {
    const normalizedUserId = Number(userId);
    return Number.isInteger(normalizedUserId) && normalizedUserId > 0 ? normalizedUserId : null;
  }

  function storedConfig(userId) {
    if (!userId) return {};
    const row = db
      .prepare('SELECT config_json FROM integration_oauth_apps WHERE user_id = ? AND provider_key = ?')
      .get(userId, providerKey);
    try {
      return JSON.parse(decryptValue(row?.config_json || '') || '{}');
    } catch {
      return {};
    }
  }

  function fieldValues(read) {
    return Object.fromEntries(fields.map((field) => [field.name, read(field) || field.defaultValue]));
  }

  /** Full client config including the secret. Never send this to a client. */
  function resolve(context = {}) {
    const server = resolveOAuthConfig(envPrefix);
    if (server.configured) {
      return { ...server, ...fieldValues((field) => text(process.env[field.env])), source: 'server' };
    }
    const stored = storedConfig(userIdOf(context));
    const clientId = text(stored.clientId);
    const clientSecret = text(stored.clientSecret);
    return {
      clientId,
      clientSecret,
      redirectUri: server.redirectUri,
      ...fieldValues((field) => text(stored[field.name])),
      configured: Boolean(clientId && clientSecret),
      source: 'user',
    };
  }

  function getEnvStatus(context = {}) {
    const config = resolve(context);
    if (config.source === 'server') {
      return {
        configured: true,
        missing: [],
        summary: `${label} is ready for account connections.`,
        setupMode: 'server',
      };
    }
    return {
      configured: config.configured,
      missing: config.configured ? [] : ['clientId', 'clientSecret'].filter((name) => !config[name]),
      summary: config.configured
        ? `${label} is ready for account connections using your own OAuth app.`
        : `Add your own ${label} OAuth app to connect accounts.`,
      setupMode: 'user',
      alternatives,
    };
  }

  function assertUserManaged() {
    if (resolveOAuthConfig(envPrefix).configured) {
      throw new Error(`${label} is configured globally on this server, so it cannot be changed here.`);
    }
  }

  function requireUserId(context) {
    const userId = userIdOf(context);
    if (!userId) throw new Error(`A valid user is required to configure ${label}.`);
    return userId;
  }

  // What the setup dialog shows. The client secret is write-only.
  function getUserConfig(context = {}) {
    const config = resolve(context);
    const managedByServer = config.source === 'server';
    const stored = managedByServer ? {} : storedConfig(userIdOf(context));
    return {
      managedBy: config.source,
      configured: config.configured,
      clientId: managedByServer ? '' : text(stored.clientId),
      hasClientSecret: Boolean(text(stored.clientSecret)),
      redirectUri: config.redirectUri,
      consoleUrl,
      notes,
      scopes: Array.from(new Set(scopes)),
      fields: fields.map(({ name, label: fieldLabel, defaultValue, hint }) => ({
        name,
        label: fieldLabel,
        hint,
        defaultValue,
        value: managedByServer ? '' : text(stored[name]),
      })),
    };
  }

  function saveUserConfig({ config = {}, ...context }) {
    assertUserManaged();
    const userId = requireUserId(context);
    const stored = storedConfig(userId);
    const clientId = cleanCredential(config.clientId, 'Client ID');
    // A blank secret keeps the stored one so the dialog never has to echo it.
    const clientSecret = cleanCredential(config.clientSecret, 'Client secret') || text(stored.clientSecret);
    if (!clientId) throw new Error('Client ID is required.');
    if (!clientSecret) throw new Error('Client secret is required.');
    const next = { clientId, clientSecret };
    for (const field of fields) {
      const value = cleanCredential(config[field.name], field.label);
      if (value) next[field.name] = value;
    }
    db.prepare(
      `INSERT INTO integration_oauth_apps (user_id, provider_key, config_json)
       VALUES (?, ?, ?)
       ON CONFLICT(user_id, provider_key) DO UPDATE SET
         config_json = excluded.config_json,
         updated_at = datetime('now')`,
    ).run(userId, providerKey, encryptValue(JSON.stringify(next)));
    return getUserConfig({ userId });
  }

  // Connected accounts stay; they work again once an app is added back.
  function clearUserConfig(context = {}) {
    assertUserManaged();
    const userId = requireUserId(context);
    db.prepare('DELETE FROM integration_oauth_apps WHERE user_id = ? AND provider_key = ?')
      .run(userId, providerKey);
    return { cleared: true };
  }

  return {
    resolve,
    getEnvStatus,
    // Served by the generic /api/integrations/:provider/config routes.
    userConfigHandlers: { getUserConfig, saveUserConfig, clearUserConfig },
  };
}

module.exports = { createOAuthApp };
