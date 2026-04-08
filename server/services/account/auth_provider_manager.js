'use strict';

const bcrypt = require('bcrypt');
const crypto = require('crypto');
const db = require('../../db/database');
const { getDeploymentPolicy } = require('../../utils/deployment');
const { decryptValue, encryptValue } = require('../integrations/secrets');
const { createAuthProviderRegistry } = require('./auth_providers/registry');

const OAUTH_STATE_TTL_MS = 15 * 60 * 1000;

function normalizeMode(value) {
  const mode = String(value || '').trim().toLowerCase();
  return ['login', 'register', 'link'].includes(mode) ? mode : '';
}

function nowIso() {
  return new Date().toISOString();
}

function parseJsonObject(value) {
  try {
    const parsed = JSON.parse(value || '{}');
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function normalizeUsernameCandidate(value) {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, '')
    .replace(/^[._-]+|[._-]+$/g, '');
  if (normalized.length >= 3) {
    return normalized.slice(0, 32);
  }
  return '';
}

class AuthProviderManager {
  constructor() {
    this.registry = createAuthProviderRegistry();
  }

  getProvider(providerKey) {
    return this.registry.get(providerKey);
  }

  cleanupExpiredStates() {
    db.prepare(
      `DELETE FROM auth_oauth_states
       WHERE datetime(expires_at) <= datetime('now')
          OR status IN ('completed', 'failed') AND datetime(created_at) <= datetime('now', '-1 day')`,
    ).run();
  }

  listProviders() {
    this.cleanupExpiredStates();
    return this.registry.list().map((provider) => {
      const env = provider.getEnvStatus();
      return {
        id: provider.key,
        label: provider.label,
        icon: provider.icon || provider.key,
        configured: env.configured,
        summary: env.summary,
      };
    });
  }

  listUserProviders(userId) {
    const user = db
      .prepare('SELECT password_login_enabled FROM users WHERE id = ?')
      .get(userId);
    if (!user) return [];

    const rows = db.prepare(
      `SELECT *
       FROM user_auth_providers
       WHERE user_id = ?
       ORDER BY provider_key ASC, updated_at DESC, id DESC`,
    ).all(userId);
    const canFallBackToPassword = Number(user.password_login_enabled || 0) === 1;

    return rows.map((row) => {
      const provider = this.getProvider(row.provider_key);
      return {
        id: row.id,
        provider: row.provider_key,
        label: provider?.label || row.provider_key,
        icon: provider?.icon || row.provider_key,
        email: row.email || null,
        metadata: parseJsonObject(row.metadata_json),
        lastUsedAt: row.last_used_at || null,
        linkedAt: row.created_at || null,
        canUnlink: canFallBackToPassword || rows.length > 1,
      };
    });
  }

  async beginAuthorization({ providerKey, mode, userId = null }) {
    this.cleanupExpiredStates();
    const provider = this.getProvider(providerKey);
    if (!provider) {
      throw new Error(`Unknown sign-in provider: ${providerKey}`);
    }

    const normalizedMode = normalizeMode(mode);
    if (!normalizedMode) {
      throw new Error('A valid provider auth mode is required.');
    }
    if (normalizedMode === 'link' && !userId) {
      throw new Error('You must be signed in to link a provider.');
    }

    const env = provider.getEnvStatus();
    if (!env.configured) {
      throw new Error(env.summary);
    }

    const state = `auth_${crypto.randomBytes(24).toString('hex')}`;
    const codeVerifier = crypto.randomBytes(48).toString('base64url');
    const expiresAt = new Date(Date.now() + OAUTH_STATE_TTL_MS).toISOString();
    const { url } = await provider.beginOAuth({ state, codeVerifier });

    db.prepare(
      `INSERT INTO auth_oauth_states (
         user_id,
         provider_key,
         mode,
         state,
         code_verifier,
         expires_at
       ) VALUES (?, ?, ?, ?, ?, ?)`,
    ).run(
      userId || null,
      provider.key,
      normalizedMode,
      state,
      encryptValue(codeVerifier),
      expiresAt,
    );

    return {
      provider: provider.key,
      mode: normalizedMode,
      status: 'oauth_redirect',
      state,
      url,
    };
  }

  failAuthorization(state, message) {
    const stateRow = this.#getStateRow(state, false);
    if (!stateRow) return;
    db.prepare(
      `UPDATE auth_oauth_states
       SET status = 'failed',
           error_message = ?,
           completed_at = ?
       WHERE id = ?`,
    ).run(String(message || 'Authentication failed.'), nowIso(), stateRow.id);
  }

  async finishAuthorization(state, code) {
    const stateRow = this.#getStateRow(state);
    if (!stateRow) {
      throw new Error('OAuth state is missing or expired.');
    }

    const provider = this.getProvider(stateRow.provider_key);
    if (!provider) {
      throw new Error(`Unknown sign-in provider: ${stateRow.provider_key}`);
    }

    try {
      const identity = await provider.finishOAuth({
        code,
        codeVerifier: decryptValue(stateRow.code_verifier),
      });
      const result = await this.#resolveAuthorization(stateRow, provider, identity);
      db.prepare(
        `UPDATE auth_oauth_states
         SET status = 'completed',
             result_json = ?,
             error_message = NULL,
             completed_at = ?
         WHERE id = ?`,
      ).run(JSON.stringify(result), nowIso(), stateRow.id);
      return result;
    } catch (error) {
      db.prepare(
        `UPDATE auth_oauth_states
         SET status = 'failed',
             error_message = ?,
             completed_at = ?
         WHERE id = ?`,
      ).run(error.message || 'Authentication failed.', nowIso(), stateRow.id);
      throw error;
    }
  }

  consumeAuthorization(state) {
    this.cleanupExpiredStates();
    const stateRow = db.prepare(
      `SELECT *
       FROM auth_oauth_states
       WHERE state = ?`,
    ).get(String(state || '').trim());
    if (!stateRow) {
      const error = new Error('Authentication request was not found or has expired.');
      error.statusCode = 404;
      throw error;
    }

    if (stateRow.status === 'pending') {
      return {
        status: 'pending',
        mode: stateRow.mode,
        provider: stateRow.provider_key,
      };
    }

    db.prepare('DELETE FROM auth_oauth_states WHERE id = ?').run(stateRow.id);

    if (stateRow.status === 'failed') {
      const error = new Error(stateRow.error_message || 'Authentication failed.');
      error.statusCode = 400;
      throw error;
    }

    return {
      status: 'completed',
      mode: stateRow.mode,
      provider: stateRow.provider_key,
      result: parseJsonObject(stateRow.result_json),
    };
  }

  unlinkProvider(userId, linkId) {
    const numericId = Number(linkId);
    if (!Number.isInteger(numericId) || numericId <= 0) {
      throw new Error('A valid linked provider id is required.');
    }

    const row = db.prepare(
      `SELECT *
       FROM user_auth_providers
       WHERE id = ? AND user_id = ?`,
    ).get(numericId, userId);
    if (!row) {
      return { removed: false };
    }

    const user = db
      .prepare('SELECT password_login_enabled FROM users WHERE id = ?')
      .get(userId);
    const linkedCount = db.prepare(
      'SELECT COUNT(*) AS count FROM user_auth_providers WHERE user_id = ?',
    ).get(userId);
    const hasPassword = Number(user?.password_login_enabled || 0) === 1;
    if (!hasPassword && Number(linkedCount?.count || 0) <= 1) {
      throw new Error('Create a password or link another provider before removing this sign-in method.');
    }

    db.prepare('DELETE FROM user_auth_providers WHERE id = ? AND user_id = ?')
      .run(numericId, userId);
    return { removed: true };
  }

  #getStateRow(state, requirePending = true) {
    const row = db.prepare(
      `SELECT *
       FROM auth_oauth_states
       WHERE state = ?
         AND datetime(expires_at) > datetime('now')`,
    ).get(String(state || '').trim());
    if (!row) return null;
    if (requirePending && row.status !== 'pending') return null;
    return row;
  }

  async #resolveAuthorization(stateRow, provider, identity) {
    const existingLink = db.prepare(
      `SELECT *
       FROM user_auth_providers
       WHERE provider_key = ? AND provider_user_id = ?`,
    ).get(provider.key, identity.providerUserId);

    if (stateRow.mode === 'login') {
      if (!existingLink) {
        throw new Error('No NeoAgent account is linked to this provider. Register first or sign in and link it from account settings.');
      }
      this.#upsertLink(existingLink.user_id, provider.key, identity);
      return {
        action: 'login',
        userId: existingLink.user_id,
        provider: provider.key,
        providerLabel: provider.label,
        email: identity.email,
      };
    }

    if (stateRow.mode === 'link') {
      if (!stateRow.user_id) {
        throw new Error('You must be signed in to link a provider.');
      }
      if (existingLink && Number(existingLink.user_id) !== Number(stateRow.user_id)) {
        throw new Error('This provider account is already linked to another NeoAgent account.');
      }
      this.#upsertLink(stateRow.user_id, provider.key, identity);
      return {
        action: 'link',
        userId: stateRow.user_id,
        provider: provider.key,
        providerLabel: provider.label,
        email: identity.email,
      };
    }

    if (existingLink) {
      this.#upsertLink(existingLink.user_id, provider.key, identity);
      return {
        action: 'register',
        userId: existingLink.user_id,
        provider: provider.key,
        providerLabel: provider.label,
        email: identity.email,
        created: false,
      };
    }

    const emailOwner = db.prepare(
      'SELECT id FROM users WHERE lower(email) = ?',
    ).get(identity.email.toLowerCase());
    if (emailOwner) {
      throw new Error('That email already belongs to an existing account. Sign in first and link this provider from account settings.');
    }

    const policy = getDeploymentPolicy();
    const userCount = db.prepare('SELECT COUNT(*) AS count FROM users').get();
    if (Number(userCount?.count || 0) > 0 && !policy.registrationOpen) {
      throw new Error('Registration is closed');
    }

    const userId = await this.#createUserFromIdentity(identity);
    this.#upsertLink(userId, provider.key, identity);
    return {
      action: 'register',
      userId,
      provider: provider.key,
      providerLabel: provider.label,
      email: identity.email,
      created: true,
    };
  }

  async #createUserFromIdentity(identity) {
    const passwordHash = await bcrypt.hash(crypto.randomUUID(), 12);
    const username = this.#generateUniqueUsername(identity);
    const result = db.prepare(
      `INSERT INTO users (
         username,
         email,
         email_verified_at,
         password,
         password_login_enabled
       ) VALUES (?, ?, datetime('now'), ?, 0)`,
    ).run(username, identity.email.toLowerCase(), passwordHash);
    return Number(result.lastInsertRowid);
  }

  #generateUniqueUsername(identity) {
    const candidates = [
      normalizeUsernameCandidate(identity.displayName),
      normalizeUsernameCandidate(String(identity.email || '').split('@')[0]),
      'user',
    ].filter(Boolean);

    for (const candidate of candidates) {
      const value = this.#firstAvailableUsername(candidate);
      if (value) return value;
    }
    return this.#firstAvailableUsername('user');
  }

  #firstAvailableUsername(base) {
    const normalizedBase = normalizeUsernameCandidate(base) || 'user';
    for (let attempt = 0; attempt < 1000; attempt += 1) {
      const suffix = attempt === 0 ? '' : String(attempt + 1);
      const username = `${normalizedBase}${suffix}`.slice(0, 32);
      const existing = db.prepare(
        'SELECT id FROM users WHERE username = ?',
      ).get(username);
      if (!existing) return username;
    }
    return `user${Date.now().toString().slice(-6)}`;
  }

  #upsertLink(userId, providerKey, identity) {
    db.prepare(
      `INSERT INTO user_auth_providers (
         user_id,
         provider_key,
         provider_user_id,
         email,
         metadata_json,
         last_used_at,
         updated_at
       ) VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))
       ON CONFLICT(provider_key, provider_user_id) DO UPDATE SET
         user_id = excluded.user_id,
         email = excluded.email,
         metadata_json = excluded.metadata_json,
         last_used_at = excluded.last_used_at,
         updated_at = excluded.updated_at`,
    ).run(
      userId,
      providerKey,
      identity.providerUserId,
      identity.email.toLowerCase(),
      JSON.stringify({
        displayName: identity.displayName || null,
        avatarUrl: identity.avatarUrl || null,
        emailVerified: identity.emailVerified === true,
        ...(identity.metadata || {}),
      }),
    );
  }
}

module.exports = {
  AuthProviderManager,
};
