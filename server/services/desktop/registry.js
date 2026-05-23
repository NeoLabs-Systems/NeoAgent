const crypto = require('crypto');
const db = require('../../db/database');
const {
  DESKTOP_COMMANDS,
  FRAME_TYPE_VIDEO,
  DesktopCompanionSelectionError,
  DesktopCompanionUnavailableError,
  createDesktopCommandMessage,
  parseDesktopMessage,
} = require('./protocol');

const DEFAULT_COMMAND_TIMEOUT_MS = 30 * 1000;
const DEFAULT_HEARTBEAT_INTERVAL_MS = 25 * 1000;
const DEFAULT_HEARTBEAT_TIMEOUT_MS = 75 * 1000;
const DEFAULT_PRESENCE_TOUCH_INTERVAL_MS = 15 * 1000;

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

function compactDisplay(display = {}) {
  const id = String(display.id || '').trim();
  return {
    id: id || 'primary',
    label: String(display.label || display.name || id || 'Display').trim() || 'Display',
    width: Number(display.width || 0) || 0,
    height: Number(display.height || 0) || 0,
    scaleFactor: Number(display.scaleFactor || 1) || 1,
    primary: display.primary === true,
  };
}

class DesktopCompanionRegistry {
  constructor(options = {}) {
    this.db = options.db || db;
    this.commandTimeoutMs = Number(
      options.commandTimeoutMs
      || process.env.NEOAGENT_DESKTOP_COMMAND_TIMEOUT_MS
      || DEFAULT_COMMAND_TIMEOUT_MS,
    );
    this.heartbeatIntervalMs = Number(
      options.heartbeatIntervalMs
      || process.env.NEOAGENT_DESKTOP_HEARTBEAT_INTERVAL_MS
      || DEFAULT_HEARTBEAT_INTERVAL_MS,
    );
    this.heartbeatTimeoutMs = Number(
      options.heartbeatTimeoutMs
      || process.env.NEOAGENT_DESKTOP_HEARTBEAT_TIMEOUT_MS
      || DEFAULT_HEARTBEAT_TIMEOUT_MS,
    );
    this.presenceTouchIntervalMs = Number(
      options.presenceTouchIntervalMs
      || process.env.NEOAGENT_DESKTOP_PRESENCE_TOUCH_INTERVAL_MS
      || DEFAULT_PRESENCE_TOUCH_INTERVAL_MS,
    );
    this.connectionsByUser = new Map();
  }

  _getUserMap(userId, create = false) {
    const key = String(userId || '').trim();
    if (!key) return null;
    if (!this.connectionsByUser.has(key) && create) {
      this.connectionsByUser.set(key, new Map());
    }
    return this.connectionsByUser.get(key) || null;
  }

  _upsertDeviceRecord(userId, hello, sessionId = null) {
    const existing = this.db.prepare(
      `SELECT * FROM desktop_companion_devices WHERE user_id = ? AND device_id = ?`
    ).get(userId, hello.deviceId);

    if (existing?.revoked_at && existing.activation_id === hello.activationId) {
      const error = new Error('This desktop device was revoked. Disable and re-enable Companion Mode on that machine before reconnecting.');
      error.status = 403;
      error.code = 'DESKTOP_DEVICE_REVOKED';
      throw error;
    }

    const displays = (Array.isArray(hello.displays) ? hello.displays : []).map(compactDisplay);
    const now = new Date().toISOString();
    const metadata = {
      ...(hello.metadata || {}),
      displays,
    };

    const rowId = existing?.id || crypto.randomUUID();
    this.db.prepare(
      `INSERT INTO desktop_companion_devices (
         id, user_id, device_id, activation_id, label, hostname, platform, platform_version, app_version,
         companion_enabled, paused, status, display_count, active_display_id, permissions_json, capabilities_json,
         metadata_json, session_id, last_connected_at, last_seen_at, revoked_at, created_at, updated_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'online', ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?)
       ON CONFLICT(user_id, device_id) DO UPDATE SET
         activation_id = excluded.activation_id,
         revoked_at = NULL,
         label = excluded.label,
         hostname = excluded.hostname,
         platform = excluded.platform,
         platform_version = excluded.platform_version,
         app_version = excluded.app_version,
         companion_enabled = excluded.companion_enabled,
         paused = excluded.paused,
         status = 'online',
         display_count = excluded.display_count,
         active_display_id = excluded.active_display_id,
         permissions_json = excluded.permissions_json,
         capabilities_json = excluded.capabilities_json,
         metadata_json = excluded.metadata_json,
         session_id = excluded.session_id,
         last_connected_at = excluded.last_connected_at,
         last_seen_at = excluded.last_seen_at,
         updated_at = excluded.updated_at`
    ).run(
      rowId,
      userId,
      hello.deviceId,
      hello.activationId,
      hello.label || hello.hostname || `${hello.platform || 'Desktop'} device`,
      hello.hostname || null,
      hello.platform || null,
      hello.platformVersion || null,
      hello.appVersion || null,
      hello.companionEnabled ? 1 : 0,
      hello.paused ? 1 : 0,
      displays.length,
      hello.activeDisplayId || displays[0]?.id || null,
      safeJson(hello.permissions),
      safeJson(hello.capabilities),
      safeJson(metadata),
      sessionId,
      now,
      now,
      existing?.created_at || now,
      now,
    );

    // Remove stale offline entries for the same machine (e.g. after a re-install
    // that generated a new device_id but kept the same hostname).
    const hostname = hello.hostname ? String(hello.hostname).trim() : null;
    if (hostname) {
      this.db.prepare(
        `DELETE FROM desktop_companion_devices
         WHERE user_id = ? AND hostname = ? AND device_id != ? AND status = 'offline'`
      ).run(userId, hostname, hello.deviceId);
    }

    return this.getDeviceRecordByDeviceId(userId, hello.deviceId);
  }

  getDeviceRecordByDeviceId(userId, deviceId) {
    const row = this.db.prepare(
      `SELECT * FROM desktop_companion_devices WHERE user_id = ? AND device_id = ?`
    ).get(userId, String(deviceId || '').trim());
    return row ? this._mapDeviceRow(row) : null;
  }

  _mapDeviceRow(row) {
    const metadata = parseJson(row.metadata_json);
    return {
      id: row.id,
      userId: row.user_id,
      deviceId: row.device_id,
      activationId: row.activation_id || null,
      label: row.label,
      hostname: row.hostname || null,
      platform: row.platform || null,
      platformVersion: row.platform_version || null,
      appVersion: row.app_version || null,
      companionEnabled: row.companion_enabled === 1,
      paused: row.paused === 1,
      status: row.status || 'offline',
      displayCount: Number(row.display_count || 0) || 0,
      activeDisplayId: row.active_display_id || null,
      permissions: parseJson(row.permissions_json),
      capabilities: parseJson(row.capabilities_json),
      metadata,
      sessionId: row.session_id || null,
      lastConnectedAt: row.last_connected_at || null,
      lastSeenAt: row.last_seen_at || null,
      revokedAt: row.revoked_at || null,
      createdAt: row.created_at,
      updatedAt: row.updated_at || row.created_at,
      displays: Array.isArray(metadata.displays) ? metadata.displays.map(compactDisplay) : [],
      online: row.status === 'online',
    };
  }

  registerConnection({ userId, sessionId, ws, hello, remoteAddress = null, userAgent = null }) {
    const record = this._upsertDeviceRecord(userId, hello, sessionId);
    const userMap = this._getUserMap(userId, true);
    const existing = userMap.get(record.deviceId);

    const connection = new DesktopCompanionConnection({
      registry: this,
      ws,
      userId,
      sessionId,
      deviceId: record.deviceId,
      recordId: record.id,
      meta: {
        remoteAddress,
        userAgent,
        label: record.label,
        hostname: record.hostname,
        platform: record.platform,
      },
      timeoutMs: this.commandTimeoutMs,
      heartbeatIntervalMs: this.heartbeatIntervalMs,
      heartbeatTimeoutMs: this.heartbeatTimeoutMs,
      presenceTouchIntervalMs: this.presenceTouchIntervalMs,
    });
    // Install the new connection in the map BEFORE closing the old one.
    // This ensures that when the old socket's async 'close' event fires and
    // calls unregisterConnection, it sees the new connection as the owner and
    // skips the DB status='offline' write — preventing a false offline report.
    userMap.set(record.deviceId, connection);

    if (existing && existing.ws !== ws) {
      existing.close('replaced by a newer desktop companion connection');
    }

    return {
      connection,
      device: this.getDeviceRecordByDeviceId(userId, record.deviceId),
    };
  }

  unregisterConnection(connection) {
    const userMap = this._getUserMap(connection.userId);
    const isOwner = userMap != null && userMap.get(connection.deviceId) === connection;
    if (isOwner) {
      userMap.delete(connection.deviceId);
      if (userMap.size === 0) {
        this.connectionsByUser.delete(String(connection.userId));
      }
      // Only mark offline in the DB when this connection is still the active owner.
      // If a newer connection has already taken over (reconnect race), its
      // _upsertDeviceRecord already wrote status='online' and we must not clobber it.
      this.db.prepare(
        `UPDATE desktop_companion_devices
         SET status = 'offline', updated_at = datetime('now')
         WHERE user_id = ? AND device_id = ?`
      ).run(connection.userId, connection.deviceId);
    }
  }

  touchConnection(userId, deviceId, patch = {}) {
    const existing = this.getDeviceRecordByDeviceId(userId, deviceId);
    if (!existing) return null;
    const displays = Array.isArray(patch.displays)
      ? patch.displays.map(compactDisplay)
      : existing.displays;
    const metadata = {
      ...(existing.metadata || {}),
      ...(patch.metadata && typeof patch.metadata === 'object' ? patch.metadata : {}),
      displays,
    };
    this.db.prepare(
      `UPDATE desktop_companion_devices
       SET label = ?,
           paused = ?,
           status = ?,
           display_count = ?,
           active_display_id = ?,
           permissions_json = ?,
           capabilities_json = ?,
           metadata_json = ?,
           last_seen_at = datetime('now'),
           updated_at = datetime('now')
       WHERE user_id = ? AND device_id = ?`
    ).run(
      patch.label || existing.label,
      patch.paused == null ? (existing.paused ? 1 : 0) : (patch.paused === true ? 1 : 0),
      patch.status || 'online',
      displays.length,
      patch.activeDisplayId || existing.activeDisplayId,
      safeJson(patch.permissions || existing.permissions),
      safeJson(patch.capabilities || existing.capabilities),
      safeJson(metadata),
      userId,
      deviceId,
    );
    return this.getDeviceRecordByDeviceId(userId, deviceId);
  }

  touchPresence(userId, deviceId) {
    const userMap = this._getUserMap(userId);
    const connection = userMap?.get(String(deviceId));
    if (!connection?.isOpen()) return;
    this.db.prepare(
      `UPDATE desktop_companion_devices
       SET status = 'online',
           last_seen_at = datetime('now'),
           updated_at = datetime('now')
       WHERE user_id = ? AND device_id = ? AND revoked_at IS NULL`
    ).run(userId, deviceId);
  }

  isConnected(userId) {
    const userMap = this._getUserMap(userId);
    return userMap != null && userMap.size > 0;
  }

  getConnection(userId, deviceId) {
    const userMap = this._getUserMap(userId);
    if (!userMap) return null;
    if (deviceId) return userMap.get(String(deviceId));
    return null;
  }

  listDevices(userId) {
    const rows = this.db.prepare(
      `SELECT * FROM desktop_companion_devices
       WHERE user_id = ?
       ORDER BY
         CASE WHEN status = 'online' THEN 0 ELSE 1 END,
         datetime(last_seen_at) DESC,
         datetime(created_at) DESC`
    ).all(userId);
    return rows.map((row) => this._mapDeviceRow(row));
  }

  getSelectedDeviceId(userId) {
    return this.db.prepare(
      `SELECT value FROM user_settings WHERE user_id = ? AND key = ?`
    ).get(userId, 'selected_desktop_device_id')?.value || null;
  }

  setSelectedDeviceId(userId, deviceId) {
    const normalized = String(deviceId || '').trim();
    this.db.prepare(
      `INSERT INTO user_settings (user_id, key, value) VALUES (?, ?, ?)
       ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`
    ).run(userId, 'selected_desktop_device_id', normalized);
    return { success: true, selectedDeviceId: normalized };
  }

  resolveDevice(userId, deviceId = null) {
    const all = this.listDevices(userId);
    const online = all.filter((device) => device.online && !device.revokedAt);
    const explicit = String(deviceId || '').trim();
    if (explicit) {
      const selected = online.find((device) => device.deviceId === explicit);
      if (!selected) {
        throw new DesktopCompanionUnavailableError();
      }
      return selected;
    }

    if (online.length === 1) {
      return online[0];
    }

    const saved = this.getSelectedDeviceId(userId);
    if (saved) {
      const selected = online.find((device) => device.deviceId === String(saved));
      if (selected) return selected;
    }

    if (online.length === 0) {
      throw new DesktopCompanionUnavailableError();
    }

    throw new DesktopCompanionSelectionError(
      'Multiple desktop companions are online. Select a device first.',
      {
        devices: online.map((device) => ({
          deviceId: device.deviceId,
          label: device.label,
          hostname: device.hostname,
          platform: device.platform,
        })),
      },
    );
  }

  async dispatch(userId, deviceId, command, payload = {}, options = {}) {
    const device = this.resolveDevice(userId, deviceId);
    const connection = this.getConnection(userId, device.deviceId);
    if (!connection || !connection.isOpen()) {
      throw new DesktopCompanionUnavailableError();
    }
    const result = await connection.sendCommand(command, payload, options);
    this.touchConnection(userId, device.deviceId, {
      label: result?.device?.label,
      paused: result?.paused === true,
      activeDisplayId: result?.activeDisplayId || result?.device?.activeDisplayId,
      permissions: result?.permissions,
      capabilities: result?.capabilities,
      displays: result?.displays || result?.device?.displays,
      metadata: result?.device?.metadata,
    });
    return {
      ...result,
      device: this.getDeviceRecordByDeviceId(userId, device.deviceId),
    };
  }

  async startStream(userId, deviceId, options = {}) {
    const device = this.resolveDevice(userId, deviceId);
    const connection = this.getConnection(userId, device.deviceId);
    if (!connection || !connection.isOpen()) {
      throw new DesktopCompanionUnavailableError();
    }
    const result = await connection.sendCommand(DESKTOP_COMMANDS.STREAM_START, {
      fps: options.fps,
      quality: options.quality,
      displayId: options.displayId || device.activeDisplayId || null,
    }, options);
    connection._streaming = true;
    return {
      ...result,
      success: result?.success !== false,
      deviceId: device.deviceId,
      device: this.getDeviceRecordByDeviceId(userId, device.deviceId),
    };
  }

  async stopStream(userId, deviceId) {
    const device = this.resolveDevice(userId, deviceId);
    const connection = this.getConnection(userId, device.deviceId);
    if (!connection || !connection.isOpen()) {
      throw new DesktopCompanionUnavailableError();
    }
    const result = await connection.sendCommand(DESKTOP_COMMANDS.STREAM_STOP, {});
    connection._streaming = false;
    return {
      ...result,
      success: result?.success !== false,
      deviceId: device.deviceId,
      device: this.getDeviceRecordByDeviceId(userId, device.deviceId),
    };
  }

  getStatus(userId) {
    const devices = this.listDevices(userId);
    const onlineDevices = devices.filter((device) => device.online);
    let selectedDeviceId = this.getSelectedDeviceId(userId);

    // Auto-select the most-recently-online device when there is no valid selection.
    // listDevices returns online devices first, ordered by last_seen_at DESC.
    const selectionIsOnline = selectedDeviceId && onlineDevices.some((d) => d.deviceId === selectedDeviceId);
    if (!selectionIsOnline && onlineDevices.length > 0) {
      selectedDeviceId = onlineDevices[0].deviceId;
      this.setSelectedDeviceId(userId, selectedDeviceId);
    }

    return {
      connected: onlineDevices.length > 0,
      selectedDeviceId,
      onlineCount: onlineDevices.length,
      devices,
    };
  }

  revoke(userId, deviceId) {
    const normalizedDeviceId = String(deviceId || '').trim();
    if (!normalizedDeviceId) {
      throw new DesktopCompanionUnavailableError();
    }
    const existing = this.getDeviceRecordByDeviceId(userId, normalizedDeviceId);
    if (!existing || existing.revokedAt) {
      throw new DesktopCompanionUnavailableError();
    }
    this.db.prepare(
      `UPDATE desktop_companion_devices
       SET revoked_at = datetime('now'),
           status = 'revoked',
           updated_at = datetime('now')
       WHERE user_id = ? AND device_id = ?`
    ).run(userId, normalizedDeviceId);
    const connection = this.getConnection(userId, normalizedDeviceId);
    if (connection) {
      connection.close('desktop device revoked');
    }
    return { success: true, deviceId: normalizedDeviceId };
  }

  pause(userId, deviceId, paused = true) {
    const normalizedDeviceId = String(deviceId || '').trim();
    if (!normalizedDeviceId) {
      throw new DesktopCompanionUnavailableError();
    }
    const existing = this.db.prepare(
      `SELECT device_id FROM desktop_companion_devices WHERE user_id = ? AND device_id = ?`
    ).get(userId, normalizedDeviceId);
    if (!existing) {
      throw new DesktopCompanionUnavailableError();
    }
    this.db.prepare(
      `UPDATE desktop_companion_devices
       SET paused = ?, updated_at = datetime('now')
       WHERE user_id = ? AND device_id = ?`
    ).run(paused ? 1 : 0, userId, normalizedDeviceId);
    const connection = this.getConnection(userId, normalizedDeviceId);
    if (connection) {
      void connection.sendCommand('pauseControl', { paused }).catch(() => {});
    }
    return {
      success: true,
      deviceId: normalizedDeviceId,
      paused,
    };
  }

  closeAll() {
    for (const userMap of this.connectionsByUser.values()) {
      for (const connection of userMap.values()) {
        connection.close('server shutdown');
      }
    }
    this.connectionsByUser.clear();
  }
}

class DesktopCompanionConnection {
  constructor({
    registry,
    ws,
    userId,
    sessionId,
    deviceId,
    recordId,
    meta,
    timeoutMs,
    heartbeatIntervalMs,
    heartbeatTimeoutMs,
    presenceTouchIntervalMs,
  }) {
    this.registry = registry;
    this.ws = ws;
    this.userId = userId;
    this.sessionId = sessionId;
    this.deviceId = deviceId;
    this.recordId = recordId;
    this.meta = meta || {};
    this.timeoutMs = timeoutMs;
    this.heartbeatIntervalMs = heartbeatIntervalMs;
    this.heartbeatTimeoutMs = heartbeatTimeoutMs;
    this.presenceTouchIntervalMs = presenceTouchIntervalMs;
    this.pending = new Map();
    this.lastPongAt = Date.now();
    this.lastPresenceTouchAt = 0;
    this.heartbeatTimer = null;

    ws.on('message', (data) => this._handleMessage(data));
    ws.on('pong', () => {
      this.lastPongAt = Date.now();
      this.touchPresence();
    });
    ws.on('close', () => this._closePending(new DesktopCompanionUnavailableError('Desktop companion disconnected.')));
    ws.on('error', (error) => this._closePending(error));
    this._startHeartbeat();
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
    // unregisterConnection is intentionally called here (not inside _closePending)
    // so it runs synchronously before any async ws 'close' event can fire.
    this.registry.unregisterConnection(this);
    this._closePending(new DesktopCompanionUnavailableError('Desktop companion disconnected.'));
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
    this.registry.touchPresence(this.userId, this.deviceId);
  }

  sendCommand(command, payload = {}, options = {}) {
    if (!this.isOpen()) {
      return Promise.reject(new DesktopCompanionUnavailableError());
    }
    const id = crypto.randomUUID();
    const timeoutMs = Number(options.timeoutMs || this.timeoutMs);
    const message = createDesktopCommandMessage(id, command, payload);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Desktop companion command timed out: ${command}`));
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

  _handleMessage(data) {
    this.lastPongAt = Date.now();
    this.touchPresence();
    if (Buffer.isBuffer(data) && data.length > 0 && data[0] === FRAME_TYPE_VIDEO) {
      return;
    }
    let message;
    try {
      message = parseDesktopMessage(data);
    } catch {
      return;
    }
    if (!message) return;

    if (message.type === 'event') {
      if (message.event === 'statusChanged' || message.event === 'permissionsChanged') {
        this.registry.touchConnection(this.userId, this.deviceId, {
          ...message.payload,
          metadata: message.payload?.metadata,
        });
      }
      return;
    }

    if (message.type !== 'result' || !message.id) return;
    const pending = this.pending.get(message.id);
    if (!pending) return;
    clearTimeout(pending.timer);
    this.pending.delete(message.id);
    if (message.ok === false) {
      const error = new Error(String(message.error || `Desktop companion command failed: ${pending.command}`));
      error.code = message.code || null;
      pending.reject(error);
      return;
    }
    pending.resolve(message.payload || {});
  }

  _closePending(error) {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
    for (const pending of this.pending.values()) {
      clearTimeout(pending.timer);
      pending.reject(error);
    }
    this.pending.clear();
    // unregisterConnection is idempotent (ownership-checked) so calling it
    // here is safe whether we arrived via close(), the ws 'close' event, or
    // both. It ensures natural socket drops (no explicit close() call) still
    // mark the device offline.
    this.registry.unregisterConnection(this);
  }

  _startHeartbeat() {
    const intervalMs = Number(this.heartbeatIntervalMs);
    const timeoutMs = Number(this.heartbeatTimeoutMs);
    if (!Number.isFinite(intervalMs) || intervalMs <= 0) return;
    this.touchPresence({ force: true });
    this.heartbeatTimer = setInterval(() => {
      if (!this.isOpen()) {
        this._closePending(new DesktopCompanionUnavailableError('Desktop companion disconnected.'));
        return;
      }
      if (Number.isFinite(timeoutMs) && timeoutMs > 0 && Date.now() - this.lastPongAt > timeoutMs) {
        try { this.ws.terminate(); } catch {}
        this._closePending(new DesktopCompanionUnavailableError('Desktop companion heartbeat timed out.'));
        return;
      }
      this.touchPresence();
      try {
        this.ws.ping();
      } catch (error) {
        this._closePending(error);
      }
    }, intervalMs);
    this.heartbeatTimer.unref?.();
  }
}

module.exports = {
  DesktopCompanionRegistry,
};
