const crypto = require('crypto');
const db = require('../../../db/database');
const {
  ExtensionBrowserUnavailableError,
  createCommandMessage,
  parseExtensionMessage,
} = require('./protocol');

const DEFAULT_PAIRING_TTL_MS = 10 * 60 * 1000;
const DEFAULT_COMMAND_TIMEOUT_MS = 30 * 1000;

function sha256(value) {
  return crypto.createHash('sha256').update(String(value || '')).digest('hex');
}

function randomSecret(bytes = 32) {
  return crypto.randomBytes(bytes).toString('base64url');
}

function isoDate(offsetMs = 0) {
  return new Date(Date.now() + offsetMs).toISOString();
}

function safeJson(value) {
  try {
    return JSON.stringify(value || {});
  } catch {
    return '{}';
  }
}

function parseJson(value) {
  try {
    return JSON.parse(value || '{}') || {};
  } catch {
    return {};
  }
}

class BrowserExtensionRegistry {
  constructor(options = {}) {
    this.db = options.db || db;
    this.commandTimeoutMs = Number(options.commandTimeoutMs || process.env.NEOAGENT_BROWSER_EXTENSION_COMMAND_TIMEOUT_MS || DEFAULT_COMMAND_TIMEOUT_MS);
    this.pairingTtlMs = Number(options.pairingTtlMs || process.env.NEOAGENT_BROWSER_EXTENSION_PAIRING_TTL_MS || DEFAULT_PAIRING_TTL_MS);
    this.connectionsByUser = new Map();
  }

  createPairingRequest(options = {}) {
    const pairingId = crypto.randomUUID();
    const pairingSecret = randomSecret(48);
    const expiresAt = isoDate(this.pairingTtlMs);
    this.db.prepare(
      `INSERT INTO browser_extension_pairing_requests (
         id, pairing_secret_hash, status, expires_at, metadata_json
       ) VALUES (?, ?, 'pending', ?, ?)`
    ).run(pairingId, sha256(pairingSecret), expiresAt, safeJson({
      extensionName: options.extensionName || null,
      userAgent: options.userAgent || null,
    }));
    return { pairingId, pairingSecret, expiresAt };
  }

  getPairingRequest(pairingId) {
    return this.db.prepare(
      `SELECT * FROM browser_extension_pairing_requests WHERE id = ?`
    ).get(String(pairingId || '')) || null;
  }

  approvePairing(pairingId, userId) {
    const row = this.getPairingRequest(pairingId);
    if (!row) {
      const error = new Error('Pairing request not found.');
      error.status = 404;
      throw error;
    }
    if (row.status !== 'pending') {
      const error = new Error('Pairing request is no longer pending.');
      error.status = 409;
      throw error;
    }
    if (Date.parse(row.expires_at) <= Date.now()) {
      this.db.prepare(
        `UPDATE browser_extension_pairing_requests SET status = 'expired' WHERE id = ?`
      ).run(row.id);
      const error = new Error('Pairing request expired.');
      error.status = 410;
      throw error;
    }
    this.db.prepare(
      `UPDATE browser_extension_pairing_requests
       SET user_id = ?, status = 'approved', approved_at = datetime('now')
       WHERE id = ?`
    ).run(userId, row.id);
    return { success: true, pairingId: row.id };
  }

  claimPairing(pairingId, pairingSecret, options = {}) {
    const row = this.getPairingRequest(pairingId);
    if (!row) {
      const error = new Error('Pairing request not found.');
      error.status = 404;
      throw error;
    }
    if (row.status !== 'approved' || !row.user_id) {
      const error = new Error('Pairing request is not approved.');
      error.status = 409;
      throw error;
    }
    if (Date.parse(row.expires_at) <= Date.now()) {
      this.db.prepare(
        `UPDATE browser_extension_pairing_requests SET status = 'expired' WHERE id = ?`
      ).run(row.id);
      const error = new Error('Pairing request expired.');
      error.status = 410;
      throw error;
    }
    if (sha256(pairingSecret) !== row.pairing_secret_hash) {
      const error = new Error('Invalid pairing secret.');
      error.status = 401;
      throw error;
    }

    const tokenId = crypto.randomUUID();
    const token = `nbe_${randomSecret(36)}`;
    const extensionName = String(options.extensionName || 'Chrome Extension').slice(0, 120);
    const metadata = {
      extensionName,
      userAgent: options.userAgent || null,
    };

    const tx = this.db.transaction(() => {
      this.db.prepare(
        `UPDATE browser_extension_pairing_requests
         SET status = 'claimed', claimed_at = datetime('now')
         WHERE id = ?`
      ).run(row.id);
      this.db.prepare(
        `INSERT INTO browser_extension_tokens (
           id, user_id, token_hash, name, status, metadata_json
         ) VALUES (?, ?, ?, ?, 'active', ?)`
      ).run(tokenId, row.user_id, sha256(token), extensionName, safeJson(metadata));
    });
    tx();

    return {
      token,
      tokenId,
      userId: row.user_id,
      extensionName,
    };
  }

  validateToken(token) {
    const row = this.db.prepare(
      `SELECT * FROM browser_extension_tokens
       WHERE token_hash = ? AND status = 'active'`
    ).get(sha256(token));
    if (!row) return null;
    return {
      ...row,
      metadata: parseJson(row.metadata_json),
    };
  }

  registerConnection(tokenRow, ws, meta = {}) {
    const userId = String(tokenRow.user_id);
    const existing = this.connectionsByUser.get(userId);
    if (existing && existing.ws !== ws) {
      existing.close('replaced by a newer extension connection');
    }

    const connection = new ExtensionBrowserConnection({
      registry: this,
      ws,
      userId,
      tokenId: tokenRow.id,
      meta: { ...tokenRow.metadata, ...meta },
      timeoutMs: this.commandTimeoutMs,
    });
    this.connectionsByUser.set(userId, connection);
    this.db.prepare(
      `UPDATE browser_extension_tokens
       SET last_connected_at = datetime('now'), last_seen_at = datetime('now')
       WHERE id = ?`
    ).run(tokenRow.id);
    return connection;
  }

  unregisterConnection(connection) {
    const userId = String(connection.userId);
    if (this.connectionsByUser.get(userId) === connection) {
      this.connectionsByUser.delete(userId);
    }
  }

  getConnection(userId) {
    return this.connectionsByUser.get(String(userId));
  }

  isConnected(userId) {
    return Boolean(this.getConnection(userId)?.isOpen());
  }

  async dispatch(userId, command, payload = {}, options = {}) {
    const connection = this.getConnection(userId);
    if (!connection || !connection.isOpen()) {
      throw new ExtensionBrowserUnavailableError();
    }
    const result = await connection.sendCommand(command, payload, options);
    this.db.prepare(
      `UPDATE browser_extension_tokens SET last_seen_at = datetime('now') WHERE id = ?`
    ).run(connection.tokenId);
    return result;
  }

  getStatus(userId) {
    const connected = this.getConnection(userId);
    const tokens = this.db.prepare(
      `SELECT id, name, status, last_connected_at, last_seen_at, revoked_at, created_at, metadata_json
       FROM browser_extension_tokens
       WHERE user_id = ?
       ORDER BY created_at DESC`
    ).all(userId).map((row) => ({
      ...row,
      metadata: parseJson(row.metadata_json),
      metadata_json: undefined,
    }));
    return {
      connected: Boolean(connected?.isOpen()),
      activeTokenId: connected?.tokenId || null,
      tokens,
      connectedMeta: connected?.meta || null,
    };
  }

  revoke(userId, tokenId = null) {
    const targetTokenId = tokenId ? String(tokenId) : null;
    if (targetTokenId) {
      this.db.prepare(
        `UPDATE browser_extension_tokens
         SET status = 'revoked', revoked_at = datetime('now')
         WHERE user_id = ? AND id = ?`
      ).run(userId, targetTokenId);
    } else {
      this.db.prepare(
        `UPDATE browser_extension_tokens
         SET status = 'revoked', revoked_at = datetime('now')
         WHERE user_id = ? AND status = 'active'`
      ).run(userId);
    }

    const connection = this.getConnection(userId);
    if (connection && (!targetTokenId || connection.tokenId === targetTokenId)) {
      connection.close('extension token revoked');
    }
    return { success: true };
  }

  closeAll() {
    for (const connection of this.connectionsByUser.values()) {
      connection.close('server shutdown');
    }
    this.connectionsByUser.clear();
  }
}

class ExtensionBrowserConnection {
  constructor({ registry, ws, userId, tokenId, meta, timeoutMs }) {
    this.registry = registry;
    this.ws = ws;
    this.userId = userId;
    this.tokenId = tokenId;
    this.meta = meta || {};
    this.timeoutMs = timeoutMs;
    this.pending = new Map();

    ws.on('message', (data) => this.#handleMessage(data));
    ws.on('close', () => this.#closePending(new ExtensionBrowserUnavailableError('Extension browser disconnected.')));
    ws.on('error', (error) => this.#closePending(error));
  }

  isOpen() {
    return this.ws && this.ws.readyState === 1;
  }

  close(reason) {
    try {
      if (this.isOpen()) {
        this.ws.close(1000, String(reason || 'closing').slice(0, 120));
      }
    } catch {}
    this.registry.unregisterConnection(this);
    this.#closePending(new ExtensionBrowserUnavailableError('Extension browser disconnected.'));
  }

  sendCommand(command, payload = {}, options = {}) {
    if (!this.isOpen()) {
      return Promise.reject(new ExtensionBrowserUnavailableError());
    }
    const id = crypto.randomUUID();
    const timeoutMs = Number(options.timeoutMs || this.timeoutMs);
    const message = createCommandMessage(id, command, payload);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Browser extension command timed out: ${command}`));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer, command });
      try {
        this.ws.send(JSON.stringify(message));
      } catch (error) {
        clearTimeout(timer);
        this.pending.delete(id);
        reject(error);
      }
    });
  }

  #handleMessage(data) {
    let message;
    try {
      message = parseExtensionMessage(data);
    } catch {
      return;
    }
    if (!message || message.type !== 'result' || !message.id) {
      return;
    }
    const pending = this.pending.get(message.id);
    if (!pending) return;
    clearTimeout(pending.timer);
    this.pending.delete(message.id);
    if (message.ok === false) {
      pending.reject(new Error(message.error || `Browser extension command failed: ${pending.command}`));
      return;
    }
    pending.resolve(message.result || {});
  }

  #closePending(error) {
    this.registry.unregisterConnection(this);
    for (const pending of this.pending.values()) {
      clearTimeout(pending.timer);
      pending.reject(error);
    }
    this.pending.clear();
  }
}

module.exports = {
  BrowserExtensionRegistry,
  sha256,
};
