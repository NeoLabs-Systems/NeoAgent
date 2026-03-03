const db = require('../../db/database');
const { WhatsAppPlatform } = require('./whatsapp');

class MessagingManager {
  constructor(io) {
    this.io = io;
    this.platforms = new Map();
    this.messageHandlers = [];
    this.platformTypes = {
      whatsapp: WhatsAppPlatform
    };
  }

  registerHandler(handler) {
    this.messageHandlers.push(handler);
  }

  async connectPlatform(userId, platformName, config = {}) {
    const PlatformClass = this.platformTypes[platformName];
    if (!PlatformClass) throw new Error(`Unknown platform: ${platformName}`);

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
}

module.exports = { MessagingManager };
