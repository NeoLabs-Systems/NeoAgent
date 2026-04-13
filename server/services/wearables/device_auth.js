const crypto = require('crypto');
const db = require('../../db/database');

const DEFAULT_PAIRING_TTL_MINUTES = 10;

function sha256(value) {
  return crypto.createHash('sha256').update(String(value || '')).digest('hex');
}

function randomToken(prefix = 'nwd_', bytes = 36) {
  return `${prefix}${crypto.randomBytes(bytes).toString('base64url')}`;
}

function randomDigits(length = 6) {
  const min = 10 ** (length - 1);
  const max = (10 ** length) - 1;
  return String(Math.floor(Math.random() * (max - min + 1)) + min);
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

class WearableDeviceAuth {
  createPairingCode(userId, options = {}) {
    const ttlMinutes = Math.max(1, Math.min(30, Number(options.ttlMinutes || DEFAULT_PAIRING_TTL_MINUTES)));
    const code = randomDigits(6);
    const pairingId = crypto.randomUUID();
    const expiresAt = isoDate(ttlMinutes * 60 * 1000);

    db.prepare(
      `INSERT INTO wearable_pairing_codes (
         id, user_id, agent_id, code_hash, status, metadata_json, expires_at
       ) VALUES (?, ?, ?, ?, 'active', ?, ?)`
    ).run(
      pairingId,
      userId,
      options.agentId || null,
      sha256(code),
      safeJson({
        source: options.source || 'app',
        deviceHint: options.deviceHint || null,
      }),
      expiresAt,
    );

    return {
      id: pairingId,
      code,
      expiresAt,
      ttlMinutes,
    };
  }

  claimPairingCode(code, payload = {}) {
    const row = db.prepare(
      `SELECT * FROM wearable_pairing_codes
       WHERE code_hash = ? AND status = 'active'
       ORDER BY datetime(created_at) DESC
       LIMIT 1`
    ).get(sha256(code));

    if (!row) {
      const error = new Error('Pairing code is invalid.');
      error.status = 404;
      throw error;
    }

    if (Date.parse(row.expires_at) <= Date.now()) {
      db.prepare(`UPDATE wearable_pairing_codes SET status = 'expired' WHERE id = ?`).run(row.id);
      const error = new Error('Pairing code expired.');
      error.status = 410;
      throw error;
    }

    const token = randomToken();
    const tokenId = crypto.randomUUID();
    const deviceId = String(payload.deviceId || '').trim().slice(0, 120) || crypto.randomUUID();
    const deviceName = String(payload.deviceName || 'Waveshare Wearable').trim().slice(0, 120);
    const macAddress = String(payload.macAddress || '').trim().slice(0, 64) || null;
    const protocol = String(payload.protocol || 'waveshare_amoled_1_8').trim().slice(0, 80);
    const firmwareVersion = String(payload.firmwareVersion || '').trim().slice(0, 80) || null;

    const tx = db.transaction(() => {
      db.prepare(
        `UPDATE wearable_pairing_codes
         SET status = 'claimed', claimed_at = datetime('now')
         WHERE id = ?`
      ).run(row.id);

      db.prepare(
        `INSERT INTO wearable_device_tokens (
           id, user_id, agent_id, token_hash, device_id, device_name,
           mac_address, protocol, firmware_version, status,
           last_seen_at, last_connected_at, metadata_json
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', datetime('now'), datetime('now'), ?)`
      ).run(
        tokenId,
        row.user_id,
        row.agent_id || null,
        sha256(token),
        deviceId,
        deviceName,
        macAddress,
        protocol,
        firmwareVersion,
        safeJson({
          pairingCodeId: row.id,
          claimedAt: new Date().toISOString(),
        }),
      );
    });

    tx();

    return {
      token,
      tokenId,
      userId: row.user_id,
      agentId: row.agent_id || null,
      deviceId,
      deviceName,
      protocol,
    };
  }

  validateBearerToken(token) {
    if (!token) return null;
    const row = db.prepare(
      `SELECT * FROM wearable_device_tokens
       WHERE token_hash = ? AND status = 'active' AND revoked_at IS NULL
       LIMIT 1`
    ).get(sha256(token));
    if (!row) return null;
    return row;
  }

  touchToken(tokenId) {
    db.prepare(
      `UPDATE wearable_device_tokens
       SET last_seen_at = datetime('now')
       WHERE id = ?`
    ).run(tokenId);
  }

  getLastCursor(tokenId) {
    const row = db.prepare(
      `SELECT last_message_id AS lastMessageId
       FROM wearable_device_message_cursors
       WHERE token_id = ?`
    ).get(tokenId);
    return Number(row?.lastMessageId || 0);
  }

  setLastCursor(tokenId, lastMessageId) {
    db.prepare(
      `INSERT INTO wearable_device_message_cursors (token_id, last_message_id, updated_at)
       VALUES (?, ?, datetime('now'))
       ON CONFLICT(token_id) DO UPDATE
       SET last_message_id = excluded.last_message_id,
           updated_at = datetime('now')`
    ).run(tokenId, Number(lastMessageId || 0));
  }

  getPendingResponses(tokenRow, limit = 5) {
    const lastId = this.getLastCursor(tokenRow.id);
    return db.prepare(
      `SELECT id, content, created_at AS createdAt, metadata
       FROM messages
       WHERE user_id = ?
         AND role = 'assistant'
         AND platform = 'waveshare_wearable'
         AND id > ?
       ORDER BY id ASC
       LIMIT ?`
    ).all(tokenRow.user_id, lastId, Math.max(1, Math.min(20, Number(limit || 5))));
  }

  listDevicesForUser(userId, options = {}) {
    const rows = db.prepare(
      `SELECT
         t.id,
         t.device_id AS deviceId,
         t.device_name AS name,
         t.mac_address AS macAddress,
         t.protocol,
         t.firmware_version AS firmwareVersion,
         t.status,
         t.last_seen_at AS lastSeenAt,
         t.last_connected_at AS lastConnectedAt,
         t.created_at AS createdAt,
         d.battery_level AS batteryLevel,
         d.updated_at AS deviceUpdatedAt,
         d.status AS runtimeStatus
       FROM wearable_device_tokens t
       LEFT JOIN wearable_devices d
         ON d.user_id = t.user_id
        AND d.mac_address = t.mac_address
       WHERE t.user_id = ?
         AND (? IS NULL OR t.agent_id = ?)
         AND t.status = 'active'
         AND t.revoked_at IS NULL
       ORDER BY datetime(t.last_seen_at) DESC, datetime(t.created_at) DESC`
    ).all(userId, options.agentId || null, options.agentId || null);

    const now = Date.now();
    return rows.map((row) => {
      const seenMs = row.lastSeenAt ? Date.parse(row.lastSeenAt) : 0;
      const isConnected = seenMs > 0 && (now - seenMs) <= 90_000;
      return {
        ...row,
        connected: isConnected,
      };
    });
  }
}

module.exports = {
  wearableDeviceAuth: new WearableDeviceAuth(),
};
