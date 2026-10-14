'use strict';

const crypto = require('crypto');
const db = require('../../db/database');
const {
  assertSignupKeyUsable,
  isSignupKeyRequired,
} = require('../access/signup_keys');
const { httpError } = require('../../utils/http_error');
const { validateNewUsername } = require('./credentials');
const { createProviderAccount, saveProviderAccount, hasUsernameCandidate } = require('./provider_accounts');
const { decryptValue, encryptValue } = require('../integrations/secrets');
const { createAuthProviderRegistry } = require('./auth_providers/registry');
const { parseJsonObject } = require('../../utils/text');

const OAUTH_STATE_TTL_MS = 15 * 60 * 1000;

function normalizeMode(value) {
  const mode = String(value || '').trim().toLowerCase();
  return ['login', 'register', 'link'].includes(mode) ? mode : '';
}

function nowIso() {
  return new Date().toISOString();
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

  listProviders({ baseUrl } = {}) {
    this.cleanupExpiredStates();
    return this.registry.list().map((provider) => {
      const env = provider.getEnvStatus({ baseUrl });
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

  async beginAuthorization({ providerKey, mode, userId = null, signupKey = null, baseUrl }) {
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
    // Checked here so a bad key fails before the provider round trip; it is
    // spent only when the callback creates the account.
    const keyCode = normalizedMode === 'register' && isSignupKeyRequired()
      ? assertSignupKeyUsable(signupKey)
      : null;

    const env = provider.getEnvStatus({ baseUrl });
    if (!env.configured) {
      throw new Error(env.summary);
    }

    const state = `auth_${crypto.randomBytes(24).toString('hex')}`;
    const codeVerifier = crypto.randomBytes(48).toString('base64url');
    const expiresAt = new Date(Date.now() + OAUTH_STATE_TTL_MS).toISOString();
    const { url } = await provider.beginOAuth({ state, codeVerifier, baseUrl });

    db.prepare(
      `INSERT INTO auth_oauth_states (
         user_id,
         provider_key,
         mode,
         state,
         code_verifier,
         expires_at,
         signup_key
       ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
    ).run(
      userId || null,
      provider.key,
      normalizedMode,
      state,
      encryptValue(codeVerifier),
      expiresAt,
      keyCode,
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
    const stateRow = this.#getStateRow(state);
    if (!stateRow) return;
    db.prepare(
      `UPDATE auth_oauth_states
       SET status = 'failed',
           error_message = ?,
           completed_at = ?
       WHERE id = ?`,
    ).run(String(message || 'Authentication failed.'), nowIso(), stateRow.id);
  }

  // What a person is approving when a held callback asks for confirmation.
  describePendingAuthorization(state) {
    const stateRow = this.#getStateRow(state);
    if (!stateRow) return null;
    const linkedUser = stateRow.user_id
      ? db.prepare('SELECT username FROM users WHERE id = ?').get(stateRow.user_id)
      : null;
    return {
      providerLabel: this.getProvider(stateRow.provider_key)?.label || stateRow.provider_key,
      mode: stateRow.mode,
      username: linkedUser?.username || null,
      startedAt: stateRow.created_at,
    };
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

    const claimed = db.prepare(
      "UPDATE auth_oauth_states SET status = 'exchanging' WHERE id = ? AND status = 'pending'",
    ).run(stateRow.id);
    if (!claimed.changes) throw new Error('OAuth state is missing or expired.');

    try {
      const identity = await provider.finishOAuth({
        code,
        codeVerifier: decryptValue(stateRow.code_verifier),
      });
      const result = await this.#resolveAuthorization(stateRow, provider, identity);
      if (result.requiresUsername) {
        db.prepare("UPDATE auth_oauth_states SET status = 'requires_username', result_json = ? WHERE id = ?")
          .run(encryptValue(JSON.stringify(identity)), stateRow.id);
        return result;
      }
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

    if (stateRow.status === 'pending' || stateRow.status === 'exchanging') {
      return {
        status: 'pending',
        mode: stateRow.mode,
        provider: stateRow.provider_key,
      };
    }

    if (stateRow.status === 'requires_username') {
      this.getProvider(stateRow.provider_key)?.assertEnabled?.();
      return { status: 'requires_username', requiresUsername: true, provider: stateRow.provider_key };
    }

    db.prepare('DELETE FROM auth_oauth_states WHERE id = ?').run(stateRow.id);

    if (stateRow.status === 'failed') {
      const error = new Error(stateRow.error_message || 'Authentication failed.');
      error.statusCode = 400;
      throw error;
    }

    this.getProvider(stateRow.provider_key)?.assertEnabled?.();

    return {
      status: 'completed',
      mode: stateRow.mode,
      provider: stateRow.provider_key,
      result: parseJsonObject(stateRow.result_json),
    };
  }

  async completeRegistration(state, username) {
    this.cleanupExpiredStates();
    const row = db.prepare("SELECT * FROM auth_oauth_states WHERE state = ? AND status = 'requires_username'")
      .get(String(state || '').trim());
    if (!row) throw httpError(404, 'Registration request was not found or has expired.');
    const provider = this.getProvider(row.provider_key);
    provider.assertEnabled?.();
    const selectedUsername = typeof username === 'string' ? username.trim() : '';
    validateNewUsername(selectedUsername);
    const identity = JSON.parse(decryptValue(row.result_json));
    db.prepare("UPDATE auth_oauth_states SET status = 'exchanging' WHERE id = ?").run(row.id);
    try {
      const result = await this.#resolveAuthorization(row, provider, identity, selectedUsername);
      db.prepare("UPDATE auth_oauth_states SET status = 'completed', result_json = ?, completed_at = ? WHERE id = ?")
        .run(JSON.stringify(result), nowIso(), row.id);
      return { status: 'completed' };
    } catch (error) {
      const retryable = error.code === 'USERNAME_TAKEN' || error.code === 'USERNAME_TOO_SHORT';
      db.prepare('UPDATE auth_oauth_states SET status = ?, error_message = ? WHERE id = ?')
        .run(retryable ? 'requires_username' : 'failed', error.message, row.id);
      throw error;
    }
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

  #getStateRow(state) {
    const row = db.prepare(
      `SELECT *
       FROM auth_oauth_states
       WHERE state = ?
         AND datetime(expires_at) > datetime('now')`,
    ).get(String(state || '').trim());
    if (!row) return null;
    if (row.status !== 'pending') return null;
    return row;
  }

  async #resolveAuthorization(stateRow, provider, identity, username = null) {
    const existingLink = db.prepare(
      `SELECT *
       FROM user_auth_providers
       WHERE provider_key = ? AND provider_user_id = ?`,
    ).get(provider.key, identity.providerUserId);

    if (stateRow.mode === 'login') {
      if (!existingLink) {
        throw new Error(`No NeoAgent account is linked to this ${provider.label} account. Register first or sign in and link it from account settings.`);
      }
      saveProviderAccount(existingLink.user_id, provider, identity);
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
        throw new Error(`This ${provider.label} account is already linked to another NeoAgent account.`);
      }
      saveProviderAccount(stateRow.user_id, provider, identity);
      return {
        action: 'link',
        userId: stateRow.user_id,
        provider: provider.key,
        providerLabel: provider.label,
        email: identity.email,
      };
    }

    if (existingLink) {
      saveProviderAccount(existingLink.user_id, provider, identity);
      return {
        action: 'register',
        userId: existingLink.user_id,
        provider: provider.key,
        providerLabel: provider.label,
        email: identity.email,
        created: false,
      };
    }

    const emailOwner = identity.email && db.prepare(
      'SELECT id FROM users WHERE lower(email) = ?',
    ).get(identity.email.toLowerCase());
    if (emailOwner) {
      throw new Error('That email already belongs to an existing account. Sign in first and link this provider from account settings.');
    }

    if (!username && !hasUsernameCandidate(identity)) {
      return { action: 'register', provider: provider.key, requiresUsername: true };
    }
    const account = await createProviderAccount(identity, stateRow.signup_key, provider, username);
    return {
      action: 'register',
      userId: account.userId,
      provider: provider.key,
      providerLabel: provider.label,
      email: identity.email,
      created: account.created,
    };
  }

}

module.exports = {
  AuthProviderManager,
};
