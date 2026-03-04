const db = require('../../db/database');
const { WhatsAppPlatform } = require('./whatsapp');
const { TelnyxVoicePlatform } = require('./telnyx');
const { DiscordPlatform } = require('./discord');

class MessagingManager {
  constructor(io) {
    this.io = io;
    this.platforms = new Map();
    this.messageHandlers = [];
    this.platformTypes = {
      whatsapp: WhatsAppPlatform,
      telnyx:   TelnyxVoicePlatform,
      discord:  DiscordPlatform,
    };
  }

  registerHandler(handler) {
    this.messageHandlers.push(handler);
  }

  async connectPlatform(userId, platformName, config = {}) {
    const PlatformClass = this.platformTypes[platformName];
    if (!PlatformClass) throw new Error(`Unknown platform: ${platformName}`);

    // For Telnyx, inject saved whitelist into config before constructing
    if (platformName === 'telnyx') {
      const wlRow = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
        .get(userId, 'platform_whitelist_telnyx');
      if (wlRow) {
        try { config.allowedNumbers = JSON.parse(wlRow.value); } catch { /* ignore */ }
      }
    }

    // For Discord, inject saved allowedIds whitelist
    if (platformName === 'discord') {
      const wlRow = db.prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
        .get(userId, 'platform_whitelist_discord');
      if (wlRow) {
        try { config.allowedIds = JSON.parse(wlRow.value); } catch { /* ignore */ }
      }
    }

    const key = `${userId}:${platformName}`;
    let platform = this.platforms.get(key);

    if (platform) {
      await platform.disconnect().catch(() => {});
    }

    platform = new PlatformClass(config);
    this.platforms.set(key, platform);

    platform.on('qr', (qr) => {
      this.io.to(`user:${userId}`).emit('messaging:qr', { platform: platformName, qr });
      db.prepare('UPDATE platform_connections SET status = ?, config = ? WHERE user_id = ? AND platform = ?')
        .run('awaiting_qr', JSON.stringify(config), userId, platformName);
    });

    platform.on('connected', () => {
      this.io.to(`user:${userId}`).emit('messaging:connected', { platform: platformName });
      db.prepare('UPDATE platform_connections SET status = ?, last_connected = datetime(\'now\') WHERE user_id = ? AND platform = ?')
        .run('connected', userId, platformName);
    });

    platform.on('disconnected', (info) => {
      this.io.to(`user:${userId}`).emit('messaging:disconnected', { platform: platformName, ...info });
      db.prepare('UPDATE platform_connections SET status = ? WHERE user_id = ? AND platform = ?')
        .run('disconnected', userId, platformName);
    });

    platform.on('logged_out', () => {
      this.io.to(`user:${userId}`).emit('messaging:logged_out', { platform: platformName });
      db.prepare('UPDATE platform_connections SET status = ? WHERE user_id = ? AND platform = ?')
        .run('logged_out', userId, platformName);
      this.platforms.delete(key);
    });

    // Telnyx-specific: blocked inbound caller notification
    platform.on('blocked_caller', (info) => {
      this.io.to(`user:${userId}`).emit('messaging:blocked_sender', {
        platform: platformName,
        sender: info.caller,
        chatId: info.ccId,
        senderName: null
      });
    });

    // Discord-specific: blocked sender notification
    platform.on('blocked_sender', (info) => {
      this.io.to(`user:${userId}`).emit('messaging:blocked_sender', {
        platform: platformName,
        sender: info.sender,
        chatId: info.chatId,
        senderName: info.senderName || null,
        meta: info.guildName ? `Server: ${info.guildName}` : null,
      });
    });

    platform.on('message', async (msg) => {
      db.prepare('INSERT INTO messages (user_id, role, content, platform, platform_msg_id, platform_chat_id, metadata, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
        .run(userId, 'user', msg.content, platformName, msg.messageId, msg.chatId,
          JSON.stringify({ sender: msg.sender, senderName: msg.senderName, isGroup: msg.isGroup, mediaType: msg.mediaType }),
          msg.timestamp);

      this.io.to(`user:${userId}`).emit('messaging:message', {
        platform: platformName,
        ...msg
      });

      for (const handler of this.messageHandlers) {
        try {
          await handler(userId, msg);
        } catch (err) {
          console.error('Message handler error:', err.message);
        }
      }
    });

    const existing = db.prepare('SELECT id FROM platform_connections WHERE user_id = ? AND platform = ?').get(userId, platformName);
    if (!existing) {
      db.prepare('INSERT INTO platform_connections (user_id, platform, config, status) VALUES (?, ?, ?, ?)')
        .run(userId, platformName, JSON.stringify(config), 'connecting');
    } else {
      db.prepare('UPDATE platform_connections SET config = ?, status = ? WHERE user_id = ? AND platform = ?')
        .run(JSON.stringify(config), 'connecting', userId, platformName);
    }

    await platform.connect();
    return { status: platform.getStatus() };
  }

  async disconnectPlatform(userId, platformName) {
    const key = `${userId}:${platformName}`;
    const platform = this.platforms.get(key);
    if (!platform) return { status: 'not_connected' };

    await platform.disconnect();
    this.platforms.delete(key);

    db.prepare('UPDATE platform_connections SET status = ? WHERE user_id = ? AND platform = ?')
      .run('disconnected', userId, platformName);

    return { status: 'disconnected' };
  }

  async sendMessage(userId, platformName, to, content, mediaPath) {
    const key = `${userId}:${platformName}`;
    const platform = this.platforms.get(key);
    if (!platform) throw new Error(`Platform ${platformName} not connected`);

    // Sentinel: agent can choose not to reply by sending [NO RESPONSE]
    if (!mediaPath && typeof content === 'string' && content.trim().toUpperCase() === '[NO RESPONSE]') {
      return { success: true, suppressed: true };
    }

    const result = await platform.sendMessage(to, content, { mediaPath });

    db.prepare('INSERT INTO messages (user_id, role, content, platform, platform_chat_id, media_path) VALUES (?, ?, ?, ?, ?, ?)')
      .run(userId, 'assistant', content, platformName, to, mediaPath || null);

    // Notify the web UI so the sent message appears in chat
    this.io.to(`user:${userId}`).emit('messaging:sent', {
      platform: platformName,
      to,
      content,
      mediaPath: mediaPath || null
    });

    return { success: true, result };
  }

  getPlatformStatus(userId, platformName) {
    const key = `${userId}:${platformName}`;
    const platform = this.platforms.get(key);
    if (!platform) {
      const conn = db.prepare('SELECT status FROM platform_connections WHERE user_id = ? AND platform = ?').get(userId, platformName);
      return { status: conn?.status || 'not_configured' };
    }
    return {
      status: platform.getStatus(),
      authInfo: platform.getAuthInfo()
    };
  }

  getAllStatuses(userId) {
    const connections = db.prepare('SELECT platform, status, last_connected FROM platform_connections WHERE user_id = ?').all(userId);
    const statuses = {};

    for (const conn of connections) {
      const key = `${userId}:${conn.platform}`;
      const platform = this.platforms.get(key);
      statuses[conn.platform] = {
        status: platform ? platform.getStatus() : conn.status,
        lastConnected: conn.last_connected,
        authInfo: platform?.getAuthInfo() || null
      };
    }

    return statuses;
  }

  async logoutPlatform(userId, platformName) {
    const key = `${userId}:${platformName}`;
    const platform = this.platforms.get(key);
    if (platform && platform.logout) {
      await platform.logout();
    }
    this.platforms.delete(key);
    db.prepare('DELETE FROM platform_connections WHERE user_id = ? AND platform = ?').run(userId, platformName);
    return { status: 'logged_out' };
  }

  async restoreConnections() {
    const rows = db.prepare(
      "SELECT user_id, platform, config FROM platform_connections WHERE status IN ('connected', 'awaiting_qr')"
    ).all();
    for (const row of rows) {
      try {
        const config = row.config ? JSON.parse(row.config) : {};
        console.log(`[Messaging] Restoring ${row.platform} for user ${row.user_id}`);
        await this.connectPlatform(row.user_id, row.platform, config);
      } catch (err) {
        console.error(`[Messaging] Failed to restore ${row.platform} for user ${row.user_id}:`, err.message);
        db.prepare("UPDATE platform_connections SET status = 'disconnected' WHERE user_id = ? AND platform = ?")
          .run(row.user_id, row.platform);
      }
    }
  }

  async makeCall(userId, to, greeting) {
    const key = `${userId}:telnyx`;
    const platform = this.platforms.get(key);
    if (!platform) throw new Error('Telnyx Voice is not connected');
    if (!platform.initiateCall) throw new Error('Telnyx platform does not support outbound calls');
    const result = await platform.initiateCall(to, greeting);
    this.io.to(`user:${userId}`).emit('messaging:call_initiated', { platform: 'telnyx', to, callControlId: result.callControlId });
    return { success: true, ...result };
  }

  async markRead(userId, platformName, chatId, messageId) {
    const key = `${userId}:${platformName}`;
    const platform = this.platforms.get(key);
    if (!platform?.markRead) return;
    return platform.markRead(chatId, messageId);
  }

  async sendTyping(userId, platformName, chatId, isTyping) {
    const key = `${userId}:${platformName}`;
    const platform = this.platforms.get(key);
    if (!platform?.sendTyping) return;
    return platform.sendTyping(chatId, isTyping);
  }

  /**
   * Route a raw Telnyx webhook event to the correct user's platform instance.
   * We find the Telnyx platform instance that owns this call_control_id, or fall
   * back to the first connected Telnyx instance.
   */
  async handleTelnyxWebhook(event) {
    // Try to find the platform by connection_id or phone number from event payload
    for (const [key, platform] of this.platforms.entries()) {
      if (platform.name === 'telnyx') {
        await platform.handleWebhook(event);
        return true;
      }
    }
    return false;
  }

  /**
   * Update the allowed-numbers list on a live Telnyx platform instance.
   */
  updateTelnyxAllowedNumbers(userId, numbers) {
    const key = `${userId}:telnyx`;
    const platform = this.platforms.get(key);
    if (platform?.setAllowedNumbers) platform.setAllowedNumbers(numbers);
  }

  /**
   * Update the allowed-entries list on a live Discord platform instance.
   * Accepts prefixed strings: "user:ID", "guild:ID", "channel:ID"
   */
  updateDiscordAllowedIds(userId, ids) {
    const key = `${userId}:discord`;
    const platform = this.platforms.get(key);
    if (platform?.setAllowedEntries) platform.setAllowedEntries(ids);
    else if (platform?.setAllowedIds) platform.setAllowedIds(ids); // legacy fallback
  }
}

module.exports = { MessagingManager };
