'use strict';

// Storage for instance-wide messaging accounts, the people verified on them and
// the one-time codes that link the two. The running server and the CLI both
// write here; the server picks changes up from `revision`.

const crypto = require('crypto');
const db = require('../../db/database');
const { decryptValue, encryptValue } = require('../integrations/secrets');
const { recordAccessEvent } = require('../access/audit');
const { httpError } = require('../../utils/http_error');

const LINK_CODE_TTL_MS = 10 * 60 * 1000;
const LINK_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const LINK_CODE_PATTERN = /\bNEO-[A-HJ-NP-Z2-9]{10}\b/;
const TELEGRAM_TOKEN_PATTERN = /^\d+:[\w-]{20,}$/;

// Discord and Slack are absent on purpose: see docs/shared-messaging.md.
const SHARED_PLATFORMS = Object.freeze({
  telegram: Object.freeze({ authMethod: 'token' }),
  whatsapp: Object.freeze({ authMethod: 'qr' }),
});

function assertSharedPlatform(platform) {
  if (!Object.hasOwn(SHARED_PLATFORMS, platform)) {
    throw httpError(400, `${platform} cannot use an instance-wide account`, 'SHARED_PLATFORM_UNSUPPORTED');
  }
}

function getConnection(platform) {
  return db.prepare('SELECT * FROM messaging_shared_connections WHERE platform = ?').get(platform) || null;
}

function listConnections() {
  return db.prepare('SELECT * FROM messaging_shared_connections').all();
}

function decodeConnectionConfig(row) {
  if (!row?.config) return {};
  return JSON.parse(decryptValue(row.config));
}

function nextConfig(platform, existing, input) {
  const config = decodeConnectionConfig(existing);
  if (platform !== 'telegram') return config;
  if (input.botToken !== undefined) {
    const token = String(input.botToken).trim();
    if (!TELEGRAM_TOKEN_PATTERN.test(token)) {
      throw httpError(400, 'That does not look like a Telegram bot token', 'SHARED_TOKEN_INVALID');
    }
    config.botToken = token;
  }
  if (!config.botToken) {
    throw httpError(400, 'A Telegram bot token is required', 'SHARED_TOKEN_REQUIRED');
  }
  return config;
}

// Fields left out keep their value. Any write that changes the account or asks
// for a reconnect bumps `revision`, which is what makes the server re-apply it.
function configureConnection(platform, input = {}, { actorUserId = null, source = 'app' } = {}) {
  assertSharedPlatform(platform);
  const existing = getConnection(platform);
  const config = nextConfig(platform, existing, input);
  const flag = (value, current) => (value === undefined ? current : (value === true ? 1 : 0));
  const enabled = flag(input.enabled, existing?.enabled ?? 1);
  const available = flag(input.available, existing?.available ?? 1);
  const allowPersonal = flag(input.allowPersonal, existing?.allow_personal ?? 1);
  const reconnect = !existing
    || input.botToken !== undefined
    || input.reconnect === true
    || enabled !== existing.enabled;

  db.transaction(() => {
    db.prepare(`
      INSERT INTO messaging_shared_connections (platform, config, enabled, available, allow_personal)
      VALUES (@platform, @config, @enabled, @available, @allowPersonal)
      ON CONFLICT(platform) DO UPDATE SET
        config = excluded.config,
        enabled = excluded.enabled,
        available = excluded.available,
        allow_personal = excluded.allow_personal,
        revision = revision + @bump,
        status = CASE
          WHEN excluded.enabled = 0 THEN 'disconnected'
          WHEN @bump = 1 THEN 'connecting'
          ELSE status
        END,
        status_reason = CASE WHEN @bump = 1 THEN NULL ELSE status_reason END,
        qr = CASE WHEN @bump = 1 THEN NULL ELSE qr END,
        updated_at = datetime('now')
    `).run({
      platform,
      config: encryptValue(JSON.stringify(config)),
      enabled,
      available,
      allowPersonal,
      bump: reconnect ? 1 : 0,
    });
    recordAccessEvent('messaging.shared_configure', {
      actorUserId,
      detail: { platform, source, enabled: enabled === 1, available: available === 1, allowPersonal: allowPersonal === 1 },
    });
  })();
  return getConnection(platform);
}

function removeConnection(platform, { actorUserId = null, source = 'app' } = {}) {
  assertSharedPlatform(platform);
  db.transaction(() => {
    db.prepare('DELETE FROM messaging_link_codes WHERE platform = ?').run(platform);
    db.prepare('DELETE FROM messaging_identity_links WHERE platform = ?').run(platform);
    db.prepare('DELETE FROM messaging_shared_connections WHERE platform = ?').run(platform);
    recordAccessEvent('messaging.shared_remove', { actorUserId, detail: { platform, source } });
  })();
}

function updateConnectionState(platform, state) {
  const row = getConnection(platform);
  if (!row) return;
  db.prepare(`
    UPDATE messaging_shared_connections
    SET status = @status, status_reason = @statusReason, qr = @qr,
        account_id = @accountId, account_label = @accountLabel,
        last_connected = CASE WHEN @status = 'connected' THEN datetime('now') ELSE last_connected END
    WHERE platform = @platform
  `).run({
    platform,
    status: state.status ?? row.status,
    statusReason: state.statusReason === undefined ? row.status_reason : state.statusReason,
    qr: state.qr ? encryptValue(state.qr) : null,
    accountId: state.accountId === undefined ? row.account_id : state.accountId,
    accountLabel: state.accountLabel === undefined ? row.account_label : state.accountLabel,
  });
}

function readConnectionQr(row) {
  return row?.qr ? decryptValue(row.qr) : null;
}

function countLinks(platform) {
  return db.prepare('SELECT COUNT(*) AS n FROM messaging_identity_links WHERE platform = ?').get(platform).n;
}

function listAllLinks() {
  return db.prepare('SELECT * FROM messaging_identity_links').all();
}

function findLinkByExternalId(platform, externalId) {
  return db.prepare('SELECT * FROM messaging_identity_links WHERE platform = ? AND external_id = ?')
    .get(platform, String(externalId)) || null;
}

function findLinkByChat(platform, chatId) {
  return db.prepare('SELECT * FROM messaging_identity_links WHERE platform = ? AND chat_id = ?')
    .get(platform, String(chatId)) || null;
}

function findLinkForUser(platform, userId) {
  return db.prepare('SELECT * FROM messaging_identity_links WHERE platform = ? AND user_id = ?')
    .get(platform, userId) || null;
}

function listLinksForUser(userId) {
  return db.prepare('SELECT * FROM messaging_identity_links WHERE user_id = ?').all(userId);
}

function updateLinkChat(linkId, chatId) {
  db.prepare('UPDATE messaging_identity_links SET chat_id = ? WHERE id = ?').run(chatId, linkId);
}

function unlinkIdentity(platform, userId, { actorUserId = userId, source = 'app' } = {}) {
  const removed = db.transaction(() => {
    const { changes } = db.prepare('DELETE FROM messaging_identity_links WHERE platform = ? AND user_id = ?')
      .run(platform, userId);
    if (changes > 0) {
      recordAccessEvent('messaging.identity_unlink', {
        actorUserId,
        subjectUserId: userId,
        detail: { platform, source },
      });
    }
    return changes > 0;
  })();
  return removed;
}

function hashLinkCode(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

function extractLinkCode(text) {
  return String(text || '').match(LINK_CODE_PATTERN)?.[0] || null;
}

// A user holds one live code per platform, so asking again retires the last one.
function createLinkCode(platform, userId, agentId, now = Date.now()) {
  let suffix = '';
  for (let i = 0; i < 10; i += 1) {
    suffix += LINK_CODE_ALPHABET[crypto.randomInt(LINK_CODE_ALPHABET.length)];
  }
  const code = `NEO-${suffix}`;
  const expiresAt = now + LINK_CODE_TTL_MS;
  db.transaction(() => {
    db.prepare('DELETE FROM messaging_link_codes WHERE expires_at <= ? OR (platform = ? AND user_id = ?)')
      .run(now, platform, userId);
    db.prepare('INSERT INTO messaging_link_codes (code_hash, platform, user_id, agent_id, expires_at) VALUES (?, ?, ?, ?, ?)')
      .run(hashLinkCode(code), platform, userId, agentId, expiresAt);
  })();
  return { code, expiresAt };
}

// The identity comes from the platform's own sender field, never from anything
// the person typed. An identity already linked to someone else stays theirs
// until they unlink it: a code never takes it over.
function redeemLinkCode(platform, code, identity, now = Date.now()) {
  return db.transaction(() => {
    const hash = hashLinkCode(code);
    const row = db.prepare('SELECT * FROM messaging_link_codes WHERE code_hash = ? AND platform = ?').get(hash, platform);
    if (!row || row.expires_at <= now) return { linked: false, reason: 'invalid_code' };
    db.prepare('DELETE FROM messaging_link_codes WHERE code_hash = ?').run(hash);

    const holder = findLinkByExternalId(platform, identity.externalId);
    if (holder && holder.user_id !== row.user_id) {
      recordAccessEvent('messaging.identity_conflict', { subjectUserId: row.user_id, detail: { platform } });
      return { linked: false, reason: 'identity_taken', userId: row.user_id, agentId: row.agent_id };
    }

    const previous = findLinkForUser(platform, row.user_id);
    db.prepare('DELETE FROM messaging_identity_links WHERE platform = ? AND user_id = ?').run(platform, row.user_id);
    db.prepare(`
      INSERT INTO messaging_identity_links (platform, external_id, chat_id, display_name, user_id, agent_id)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(platform, identity.externalId, identity.chatId, identity.displayName || null, row.user_id, row.agent_id);
    recordAccessEvent('messaging.identity_link', { subjectUserId: row.user_id, detail: { platform } });
    return {
      linked: true,
      userId: row.user_id,
      agentId: row.agent_id,
      previousAgentId: previous?.agent_id || null,
    };
  })();
}

module.exports = {
  LINK_CODE_TTL_MS,
  SHARED_PLATFORMS,
  assertSharedPlatform,
  configureConnection,
  countLinks,
  createLinkCode,
  decodeConnectionConfig,
  extractLinkCode,
  findLinkByChat,
  findLinkByExternalId,
  findLinkForUser,
  getConnection,
  listAllLinks,
  listConnections,
  listLinksForUser,
  readConnectionQr,
  redeemLinkCode,
  removeConnection,
  unlinkIdentity,
  updateConnectionState,
  updateLinkChat,
};
