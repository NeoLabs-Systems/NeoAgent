const crypto = require('crypto');
const db = require('../../../db/database');
const {
  ExtensionBrowserUnavailableError,
  createCommandMessage,
  parseExtensionMessage,
} = require('./protocol');

const DEFAULT_PAIRING_TTL_MS = 10 * 60 * 1000;
const DEFAULT_COMMAND_TIMEOUT_MS = 30 * 1000;
const DEFAULT_HEARTBEAT_INTERVAL_MS = 25 * 1000;
const DEFAULT_HEARTBEAT_TIMEOUT_MS = 75 * 1000;
const DEFAULT_PRESENCE_TOUCH_INTERVAL_MS = 15 * 1000;

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
    this.heartbeatIntervalMs = Number(options.heartbeatIntervalMs || process.env.NEOAGENT_BROWSER_EXTENSION_HEARTBEAT_INTERVAL_MS || DEFAULT_HEARTBEAT_INTERVAL_MS);
    this.heartbeatTimeoutMs = Number(options.heartbeatTimeoutMs || process.env.NEOAGENT_BROWSER_EXTENSION_HEARTBEAT_TIMEOUT_MS || DEFAULT_HEARTBEAT_TIMEOUT_MS);
    this.presenceTouchIntervalMs = Number(options.presenceTouchIntervalMs || process.env.NEOAGENT_BROWSER_EXTENSION_PRESENCE_TOUCH_INTERVAL_MS || DEFAULT_PRESENCE_TOUCH_INTERVAL_MS);
    this.connectionsByUser = new Map();
  }

  #getUserConnections(userId, create = false) {
    const key = String(userId || '').trim();
    if (!key) return null;
    if (!this.connectionsByUser.has(key) && create) {
      this.connectionsByUser.set(key, new Map());
    }
    return this.connectionsByUser.get(key) || null;
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
      // Find other active tokens with the same name for this user.
      // If they are currently offline, revoke them to clean up old installs/duplicates.
      const duplicates = this.db.prepare(
        `SELECT id FROM browser_extension_tokens
         WHERE user_id = ? AND name = ? AND status = 'active'`
      ).all(row.user_id, extensionName);

      for (const dup of duplicates) {
        if (!this.isConnected(row.user_id, dup.id)) {
          this.db.prepare(
            `UPDATE browser_extension_tokens
             SET status = 'revoked', revoked_at = datetime('now')
             WHERE id = ?`
          ).run(dup.id);
        }
      }

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

      // Auto-select the newly paired token on claim
      const write = this.db.prepare(
        `INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?)
         ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`
      );
      write.run(row.user_id, 'browser_extension_token_id', tokenId);
      write.run(row.user_id, 'selected_browser_extension_token_id', tokenId);
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
    const userMap = this.#getUserConnections(userId, true);
    const existing = userMap.get(tokenRow.id);
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
      heartbeatIntervalMs: this.heartbeatIntervalMs,
      heartbeatTimeoutMs: this.heartbeatTimeoutMs,
      presenceTouchIntervalMs: this.presenceTouchIntervalMs,
    });
    userMap.set(tokenRow.id, connection);
    this.db.prepare(
      `UPDATE browser_extension_tokens
       SET last_connected_at = datetime('now'), last_seen_at = datetime('now')
       WHERE id = ?`
    ).run(tokenRow.id);
    return connection;
  }

  unregisterConnection(connection) {
    const userId = String(connection.userId);
    const userMap = this.#getUserConnections(userId);
    if (userMap?.get(connection.tokenId) === connection) {
      userMap.delete(connection.tokenId);
      if (userMap.size === 0) {
        this.connectionsByUser.delete(userId);
      }
    }
  }

  getSelectedTokenId(userId) {
    const value = this.db.prepare(
      `SELECT value FROM user_settings WHERE user_id = ? AND key = ?`
    ).get(userId, 'browser_extension_token_id')?.value || null;
    const normalized = String(value || '').trim();
    if (!normalized || normalized === 'null') return null;
    const existing = this.db.prepare(
      `SELECT id FROM browser_extension_tokens WHERE user_id = ? AND id = ? AND status = 'active'`
    ).get(userId, normalized);
    if (!existing) return null;
    return normalized;
  }

  setSelectedTokenId(userId, tokenId) {
    const normalized = String(tokenId || '').trim();
    if (!normalized) {
      const error = new Error('Browser extension token id is required.');
      error.status = 400;
      throw error;
    }
    const existing = this.db.prepare(
      `SELECT id FROM browser_extension_tokens WHERE user_id = ? AND id = ? AND status = 'active'`
    ).get(userId, normalized);
    if (!existing) {
      const error = new Error('Browser extension device not found.');
      error.status = 404;
      throw error;
    }
    const write = this.db.prepare(
      `INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?)
       ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`
    );
    write.run(userId, 'browser_extension_token_id', normalized);
    write.run(userId, 'selected_browser_extension_token_id', normalized);
    return { success: true, selectedTokenId: normalized };
  }

  getConnection(userId, tokenId = null) {
    const userMap = this.#getUserConnections(userId);
    if (!userMap) return null;
    const explicit = String(tokenId || '').trim();
    if (explicit) return userMap.get(explicit) || null;

    const selected = this.getSelectedTokenId(userId);
    if (selected && userMap.get(selected)?.isOpen()) {
      return userMap.get(selected);
    }

    // Auto-select online connection if selected is offline/unset
    const online = Array.from(userMap.values()).filter((connection) => connection.isOpen());
    if (online.length > 0) {
      online.sort((a, b) => String(b.connectedAt || '').localeCompare(String(a.connectedAt || '')));
      const activeConnection = online[0];
      try {
        const write = this.db.prepare(
          `INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?)
           ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`
        );
        write.run(userId, 'browser_extension_token_id', activeConnection.tokenId);
        write.run(userId, 'selected_browser_extension_token_id', activeConnection.tokenId);
      } catch (err) {
        console.error('[Registry] failed to auto-select online extension', err);
      }
      return activeConnection;
    }

    if (selected) {
      return userMap.get(selected) || null;
    }
    return null;
  }

  isConnected(userId, tokenId = null) {
    return Boolean(this.getConnection(userId, tokenId)?.isOpen());
  }

  touchPresence(userId, tokenId) {
    const userMap = this.#getUserConnections(userId);
    const connection = userMap?.get(String(tokenId));
    if (!connection?.isOpen()) return;
    this.db.prepare(
      `UPDATE browser_extension_tokens SET last_seen_at = datetime('now') WHERE id = ?`
    ).run(tokenId);
  }

  async dispatch(userId, command, payload = {}, options = {}) {
    const connection = this.getConnection(userId, options.tokenId || payload.tokenId || null);
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
    const userMap = this.#getUserConnections(userId);
    let selectedTokenId = this.getSelectedTokenId(userId);
    let connected = selectedTokenId
      ? userMap?.get(selectedTokenId)
      : null;
    if (!connected?.isOpen()) {
      connected = this.getConnection(userId);
      if (connected?.isOpen()) {
        selectedTokenId = connected.tokenId;
      }
    }
    const effectiveSelectedTokenId = selectedTokenId || connected?.tokenId || null;
    const tokens = this.db.prepare(
      `SELECT id, name, status, last_connected_at, last_seen_at, revoked_at, created_at, metadata_json
       FROM browser_extension_tokens
       WHERE user_id = ?
       ORDER BY created_at DESC`
    ).all(userId).map((row) => {
      const connection = userMap?.get(row.id) || null;
      return {
        ...row,
        tokenId: row.id,
        deviceId: row.id,
        connected: Boolean(connection?.isOpen()),
        online: Boolean(connection?.isOpen()),
        selected: row.id === effectiveSelectedTokenId,
        metadata: parseJson(row.metadata_json),
        connectedMeta: connection?.meta || null,
        metadata_json: undefined,
      };
    });
    return {
      connected: Boolean(connected?.isOpen()),
      activeTokenId: connected?.tokenId || null,
      selectedTokenId: effectiveSelectedTokenId,
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

    const connection = this.getConnection(userId, targetTokenId);
    if (connection && (!targetTokenId || connection.tokenId === targetTokenId)) {
      connection.close('extension token revoked');
    }
    return { success: true };
  }

  closeAll() {
    for (const connection of this.connectionsByUser.values()) {
      if (connection instanceof Map) {
        for (const nested of connection.values()) {
          nested.close('server shutdown');
        }
      } else {
        connection.close('server shutdown');
      }
    }
    this.connectionsByUser.clear();
  }
}

class ExtensionBrowserConnection {
  constructor({ registry, ws, userId, tokenId, meta, timeoutMs, heartbeatIntervalMs, heartbeatTimeoutMs, presenceTouchIntervalMs }) {
    this.registry = registry;
    this.ws = ws;
    this.userId = userId;
    this.tokenId = tokenId;
    this.meta = meta || {};
    this.timeoutMs = timeoutMs;
    this.heartbeatIntervalMs = heartbeatIntervalMs;
    this.heartbeatTimeoutMs = heartbeatTimeoutMs;
    this.presenceTouchIntervalMs = presenceTouchIntervalMs;
    this.pending = new Map();
    this.connectedAt = new Date().toISOString();
    this.lastPongAt = Date.now();
    this.lastPresenceTouchAt = 0;
    this.heartbeatTimer = null;

    ws.on('message', (data) => this.#handleMessage(data));
    ws.on('pong', () => {
      this.lastPongAt = Date.now();
      this.touchPresence();
    });
    ws.on('close', () => this.#closePending(new ExtensionBrowserUnavailableError('Extension browser disconnected.')));
    ws.on('error', (error) => this.#closePending(error));
    this.#startHeartbeat();
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

  touchPresence({ force = false } = {}) {
    const now = Date.now();
    const intervalMs = Number(this.presenceTouchIntervalMs);
    if (
      !force
      && Number.isFinite(intervalMs)
      && intervalMs > 0
      && now - this.lastPresenceTouchAt < intervalMs
    ) {
      return;
    }
    this.lastPresenceTouchAt = now;
    this.registry.touchPresence(this.userId, this.tokenId);
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
    this.lastPongAt = Date.now();
    this.touchPresence();
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
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
    for (const pending of this.pending.values()) {
      clearTimeout(pending.timer);
      pending.reject(error);
    }
    this.pending.clear();
  }

  #startHeartbeat() {
    const intervalMs = Number(this.heartbeatIntervalMs);
    const timeoutMs = Number(this.heartbeatTimeoutMs);
    if (!Number.isFinite(intervalMs) || intervalMs <= 0) return;
    this.touchPresence({ force: true });
    this.heartbeatTimer = setInterval(() => {
      if (!this.isOpen()) {
        this.#closePending(new ExtensionBrowserUnavailableError('Extension browser disconnected.'));
        return;
      }
      if (Number.isFinite(timeoutMs) && timeoutMs > 0 && Date.now() - this.lastPongAt > timeoutMs) {
        try { this.ws.terminate(); } catch {}
        this.#closePending(new ExtensionBrowserUnavailableError('Extension browser heartbeat timed out.'));
        return;
      }
      this.touchPresence();
      try {
        this.ws.ping();
      } catch (error) {
        this.#closePending(error);
      }
    }, intervalMs);
    this.heartbeatTimer.unref?.();
  }
}

module.exports = {
  BrowserExtensionRegistry,
  sha256,
};
