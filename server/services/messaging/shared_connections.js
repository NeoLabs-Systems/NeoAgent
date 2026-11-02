'use strict';

// Runs the instance-wide messaging accounts inside MessagingManager. One adapter
// serves every linked person: inbound messages are authorized here before the
// adapter touches attachments, then enter the normal per-user pipeline, and each
// linked agent gets a SharedRoutePlatform for its replies. Direct messages only,
// because a group on a shared account would mix several people's agents.

const fs = require('fs');
const path = require('path');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');
const { httpError } = require('../../utils/http_error');
const { createServiceLogger } = require('../../utils/logger');
const { isAdminUser } = require('../access/admin');
const { normalizeWhatsAppId } = require('../../utils/whatsapp');
const { SharedRoutePlatform, SlidingWindowLimiter } = require('./shared_route');
const store = require('./shared_store');

const log = createServiceLogger('SharedMessaging');

const RECONCILE_INTERVAL_MS = 5000;
const RECONNECT_BASE_DELAY_MS = 2000;
const RECONNECT_MAX_DELAY_MS = 60000;
const LINK_ATTEMPTS_PER_WINDOW = 5;
const LINK_ATTEMPT_WINDOW_MS = 10 * 60 * 1000;
const INBOUND_MESSAGES_PER_MINUTE = 30;
const LINK_CONFIRMATION_EMOJI = '👍';

function sharedAuthDir(platform) {
  return path.join(AGENT_DATA_DIR, 'messaging-auth', 'shared', platform);
}

function accountDetails(platform, adapter) {
  const info = adapter.getAuthInfo?.() || {};
  if (platform === 'telegram' && info.username) {
    return { accountId: info.username, accountLabel: `@${info.username}` };
  }
  if (platform === 'whatsapp' && info.number) {
    return { accountId: info.number, accountLabel: `+${info.number}` };
  }
  return {};
}

function linkUrl(platform, accountId, code) {
  if (!accountId) return null;
  if (platform === 'telegram') return `https://t.me/${accountId}?start=${code}`;
  return `https://wa.me/${accountId}?text=${encodeURIComponent(code)}`;
}

function isActiveSharedChat(userId, agentId, platform, chatId) {
  const link = store.findLinkForUser(platform, userId);
  return link?.agent_id === agentId
    && link.chat_id === String(chatId)
    && store.getConnection(platform)?.available === 1;
}

class SharedMessagingConnections {
  constructor(manager, options = {}) {
    this.manager = manager;
    this.adapters = new Map();
    this.reconcileIntervalMs = options.reconcileIntervalMs ?? RECONCILE_INTERVAL_MS;
    this.reconnectBaseDelayMs = options.reconnectBaseDelayMs ?? RECONNECT_BASE_DELAY_MS;
    this.linkAttempts = new SlidingWindowLimiter(LINK_ATTEMPTS_PER_WINDOW, LINK_ATTEMPT_WINDOW_MS);
    this.inboundMessages = new SlidingWindowLimiter(INBOUND_MESSAGES_PER_MINUTE, 60 * 1000);
    this.timer = null;
    this.queue = Promise.resolve();
    this.stopped = false;
  }

  async start() {
    await this.reconcile();
    // The CLI changes these rows from another process, so the server looks for
    // changes instead of waiting to be told.
    this.timer = setInterval(() => {
      this.reconcile().catch((error) => log.error('Reconcile failed:', error?.message || error));
    }, this.reconcileIntervalMs);
    this.timer.unref?.();
  }

  async stop() {
    this.stopped = true;
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    const entries = [...this.adapters.values()];
    this.adapters.clear();
    await Promise.allSettled(entries.map((entry) => this._retire(entry)));
  }

  reconcile() {
    const run = this.queue.then(() => this._reconcileNow());
    this.queue = run.catch(() => {});
    return run;
  }

  async _reconcileNow() {
    if (this.stopped) return;
    for (const platform of Object.keys(store.SHARED_PLATFORMS)) {
      const row = store.getConnection(platform);
      const entry = this.adapters.get(platform);
      if (!row) {
        if (entry) await this._stopAdapter(platform);
        fs.rmSync(sharedAuthDir(platform), { recursive: true, force: true });
      } else if (row.enabled !== 1) {
        if (entry) await this._stopAdapter(platform);
        if (row.status !== 'disconnected') {
          store.updateConnectionState(platform, { status: 'disconnected', statusReason: null });
        }
      } else if (entry?.revision !== row.revision) {
        await this._startAdapter(platform, row);
      }
    }
    this._syncRoutes();
  }

  // Links also change without this process knowing: the CLI, or an account or
  // agent being deleted. A stale route is harmless, since it re-reads the link
  // on every call, but it should not linger in the status list.
  _syncRoutes() {
    const links = store.listAllLinks();
    const wanted = new Set(links.map((link) => this.manager._key(link.user_id, link.agent_id, link.platform)));
    for (const [key, platform] of this.manager.platforms.entries()) {
      if (platform.isSharedRoute && !wanted.has(key)) this.manager.platforms.delete(key);
    }
    for (const link of links) this._ensureRoute(link.platform, link.user_id, link.agent_id);
  }

  _ensureRoute(platform, userId, agentId) {
    const key = this.manager._key(userId, agentId, platform);
    if (this.manager.platforms.has(key)) return;
    this.manager.platforms.set(key, new SharedRoutePlatform({
      platform,
      userId,
      agentId,
      getAdapter: () => this.adapters.get(platform)?.adapter || null,
    }));
  }

  async _retire(entry) {
    entry.retired = true;
    if (entry.timer) clearTimeout(entry.timer);
    await Promise.resolve(entry.adapter?.disconnect?.()).catch(() => {});
  }

  async _stopAdapter(platform) {
    const entry = this.adapters.get(platform);
    if (!entry) return;
    this.adapters.delete(platform);
    await this._retire(entry);
    this._notifyLinked(platform, 'messaging:disconnected');
  }

  async _startAdapter(platform, row) {
    const previous = this.adapters.get(platform);
    if (previous) await this._retire(previous);
    const entry = { adapter: null, revision: row.revision, attempts: 0, timer: null, retired: false };
    this.adapters.set(platform, entry);
    await this._connect(platform, entry);
  }

  async _connect(platform, entry) {
    if (entry.retired || this.stopped) return;
    try {
      const PlatformClass = this.manager.platformTypes[platform];
      entry.adapter = new PlatformClass({
        ...store.decodeConnectionConfig(store.getConnection(platform)),
        accessGate: (context) => this._gate(platform, context),
        artifactStore: this.manager.artifactStore,
        authDir: sharedAuthDir(platform),
      });
      this._wireAdapter(platform, entry);
      store.updateConnectionState(platform, { status: 'connecting', statusReason: null });
      await this.manager._runOperation({}, `shared ${platform} connection`, () => entry.adapter.connect());
    } catch (error) {
      if (entry.retired) return;
      // Raw errors from a platform library can quote the credential.
      log.warn(`Shared ${platform} account failed to connect.`);
      if (error?.requiresUserAction === true) {
        store.updateConnectionState(platform, {
          status: 'error',
          statusReason: error.reason || 'reconnect_required',
        });
        return;
      }
      this._scheduleReconnect(platform, entry);
    }
  }

  _scheduleReconnect(platform, entry) {
    if (entry.retired || entry.timer || this.stopped) return;
    entry.attempts += 1;
    const delay = Math.min(
      this.reconnectBaseDelayMs * (2 ** Math.min(entry.attempts - 1, 10)),
      RECONNECT_MAX_DELAY_MS,
    );
    store.updateConnectionState(platform, { status: 'reconnecting', statusReason: 'connection_failed' });
    entry.timer = setTimeout(() => {
      entry.timer = null;
      Promise.resolve(entry.adapter?.disconnect?.()).catch(() => {}).finally(() => this._connect(platform, entry));
    }, delay);
    entry.timer.unref?.();
  }

  _wireAdapter(platform, entry) {
    const { adapter } = entry;
    const live = () => !entry.retired && !this.stopped && entry.adapter === adapter;

    adapter.on('qr', (qr) => {
      if (live()) store.updateConnectionState(platform, { status: 'awaiting_qr', qr });
    });
    adapter.on('connected', () => {
      if (!live()) return;
      entry.attempts = 0;
      store.updateConnectionState(platform, {
        status: 'connected',
        statusReason: null,
        ...accountDetails(platform, adapter),
      });
      this._notifyLinked(platform, 'messaging:connected');
      void this.manager.recoverPendingInbound({ platform }).catch((error) => {
        log.error('Inbound recovery failed:', error?.message || error);
      });
    });
    adapter.on('disconnected', (info) => {
      if (!live() || info?.manual === true) return;
      this._notifyLinked(platform, 'messaging:disconnected');
      if (info?.requiresUserAction === true || info?.shouldReconnect === false) {
        store.updateConnectionState(platform, {
          status: 'error',
          statusReason: info.reason || 'reconnect_required',
        });
      } else if (info?.willReconnect === true) {
        store.updateConnectionState(platform, { status: 'reconnecting' });
      } else {
        this._scheduleReconnect(platform, entry);
      }
    });
    adapter.on('logged_out', () => {
      if (!live()) return;
      store.updateConnectionState(platform, { status: 'logged_out', statusReason: 'authentication_required' });
      this._notifyLinked(platform, 'messaging:disconnected');
    });
    adapter.on('error', (info) => {
      if (!live()) return;
      if (info?.requiresUserAction === true) {
        store.updateConnectionState(platform, {
          status: 'error',
          statusReason: info.reason || 'reconnect_required',
        });
      } else if (info?.willReconnect !== true) {
        this._scheduleReconnect(platform, entry);
      }
    });
    adapter.on('message', (msg) => {
      if (live()) this._routeMessage(platform, msg);
    });
    adapter.on('reaction', (reaction) => {
      if (live()) this._routeReaction(platform, reaction);
    });
  }

  // Runs before the adapter does anything expensive with a message. Only the
  // platform's own sender field identifies the person. Refusals are quiet: a
  // stranger gets no reply, no log line and no notification to anyone.
  _gate(platform, context) {
    const refuse = (reason) => ({ allowed: false, reason });
    if (context?.isDirect !== true) return refuse('shared_disabled');
    if (store.getConnection(platform)?.available !== 1) return refuse('unavailable');
    const externalId = String(context.stableSenderId || context.senderId || '');
    if (!externalId) return refuse('unlinked');

    const code = store.extractLinkCode(context.text);
    if (code) {
      if (this.linkAttempts.take(`${platform}:${externalId}`)) {
        this._redeem(platform, code, externalId, context);
      }
      return refuse('link_attempt');
    }

    const link = store.findLinkByExternalId(platform, externalId);
    if (!link) return refuse('unlinked');
    const route = this.manager.platforms.get(this.manager._key(link.user_id, link.agent_id, platform));
    // A personal connection in this slot would send as a different identity.
    if (route?.isSharedRoute !== true) return refuse('unlinked');
    if (!this.inboundMessages.take(`${platform}:${externalId}`)) return refuse('rate_limited');
    if (context.chatId && link.chat_id !== context.chatId) store.updateLinkChat(link.id, context.chatId);
    return { allowed: true, ownerUserId: link.user_id };
  }

  _redeem(platform, code, externalId, context) {
    const result = store.redeemLinkCode(platform, code, {
      externalId,
      chatId: context.chatId,
      displayName: this._identityLabel(platform, externalId, context),
    });
    if (result.reason === 'identity_taken') {
      this.manager.io.to(`user:${result.userId}`).emit('messaging:link_failed', {
        platform,
        agentId: result.agentId,
        reason: result.reason,
      });
      return;
    }
    if (!result.linked) return;
    void this._finishLink(platform, result, context).catch((error) => {
      log.error('Could not finish linking:', error?.message || error);
    });
  }

  _identityLabel(platform, externalId, context) {
    if (context.senderName) return String(context.senderName).slice(0, 80);
    return platform === 'whatsapp' ? `+${normalizeWhatsAppId(externalId)}` : externalId;
  }

  // Redeeming a code is the user switching to the shared account, so it retires
  // their personal connection on this agent instead of running both.
  async _finishLink(platform, { userId, agentId, previousAgentId }, context) {
    if (previousAgentId && previousAgentId !== agentId) {
      this.manager.platforms.delete(this.manager._key(userId, previousAgentId, platform));
    }
    const current = this.manager.platforms.get(this.manager._key(userId, agentId, platform));
    if (current && !current.isSharedRoute) {
      await this.manager.disconnectPlatform(userId, platform, { agentId });
    }
    this._ensureRoute(platform, userId, agentId);
    const room = this.manager.io.to(`user:${userId}`);
    room.emit('messaging:linked', { platform, agentId });
    room.emit('messaging:connected', { platform, agentId });
    if (context.messageId) {
      await this.adapters.get(platform)?.adapter?.sendReaction?.(
        context.chatId,
        context.messageId,
        LINK_CONFIRMATION_EMOJI,
      )?.catch?.(() => {});
    }
  }

  _routeMessage(platform, msg) {
    const link = store.findLinkByChat(platform, msg.chatId);
    if (!link) return;
    void this.manager.ingestMessage(
      link.user_id,
      platform,
      { ...msg, metadata: { ...(msg.metadata || {}), sharedConnection: true } },
      { agentId: link.agent_id },
    ).catch((error) => {
      log.error('Failed to persist or dispatch inbound message:', error?.message || error);
    });
  }

  _routeReaction(platform, reaction) {
    const link = store.findLinkByChat(platform, reaction.chatId);
    if (!link) return;
    try {
      this.manager.recordInboundReaction(link.user_id, platform, reaction, { agentId: link.agent_id });
    } catch (error) {
      log.error('Failed to record inbound reaction:', error?.message || error);
    }
    this.manager.emit('reaction_added', { ...reaction, userId: link.user_id, agentId: link.agent_id, platform });
  }

  _notifyLinked(platform, event) {
    for (const link of store.listAllLinks()) {
      if (link.platform !== platform) continue;
      this.manager.io.to(`user:${link.user_id}`).emit(event, { platform, agentId: link.agent_id });
    }
  }

  // --- User-facing ---

  listOptions(userId) {
    const links = store.listLinksForUser(userId);
    const options = [];
    for (const [platform, spec] of Object.entries(store.SHARED_PLATFORMS)) {
      const row = store.getConnection(platform);
      if (row?.enabled !== 1 || row.available !== 1) continue;
      const link = links.find((item) => item.platform === platform) || null;
      if (row.status !== 'connected' && !link) continue;
      options.push({
        platform,
        authMethod: spec.authMethod,
        status: row.status,
        accountLabel: row.account_label,
        personalAllowed: row.allow_personal === 1 || isAdminUser(userId),
        link: link && {
          agentId: link.agent_id,
          displayName: link.display_name,
          linkedAt: link.linked_at,
        },
      });
    }
    return options;
  }

  startLink(userId, agentId, platform) {
    store.assertSharedPlatform(platform);
    const row = store.getConnection(platform);
    if (row?.enabled !== 1 || row.available !== 1 || row.status !== 'connected') {
      throw httpError(409, `The shared ${platform} account is not available right now`, 'SHARED_UNAVAILABLE');
    }
    const { code, expiresAt } = store.createLinkCode(platform, userId, agentId);
    return {
      platform,
      code,
      expiresAt: new Date(expiresAt).toISOString(),
      accountLabel: row.account_label,
      url: linkUrl(platform, row.account_id, code),
    };
  }

  unlink(userId, platform, { agentId = null } = {}) {
    store.assertSharedPlatform(platform);
    const link = store.findLinkForUser(platform, userId);
    if (!link || (agentId && link.agent_id !== agentId)) return { status: 'not_configured' };
    store.unlinkIdentity(platform, userId);
    this.manager.platforms.delete(this.manager._key(userId, link.agent_id, platform));
    return { status: 'disconnected' };
  }

  // A person choosing their own account on this agent replaces the shared one;
  // it never happens on its own, and the two never run in the same slot.
  beforePersonalConnect(userId, agentId, platform) {
    if (!Object.hasOwn(store.SHARED_PLATFORMS, platform)) return;
    const row = store.getConnection(platform);
    const offered = row?.enabled === 1 && row.available === 1;
    if (offered && row.allow_personal !== 1 && !isAdminUser(userId)) {
      throw httpError(403, `This server only allows the shared ${platform} account`, 'PERSONAL_NOT_ALLOWED');
    }
    this.unlink(userId, platform, { agentId });
  }

  statusEntries(userId, agentId) {
    const entries = {};
    for (const link of store.listLinksForUser(userId)) {
      if (link.agent_id !== agentId) continue;
      const row = store.getConnection(link.platform);
      const route = this.manager.platforms.get(this.manager._key(userId, agentId, link.platform));
      if (route && !route.isSharedRoute) continue;
      entries[link.platform] = {
        status: route?.isSharedRoute ? route.getStatus() : (row?.status || 'disconnected'),
        agentId,
        lastConnected: row?.last_connected || null,
        authInfo: route?.isSharedRoute ? route.getAuthInfo() : null,
      };
    }
    return entries;
  }
}

function adminOverview() {
  return Object.entries(store.SHARED_PLATFORMS).map(([platform, spec]) => {
    const row = store.getConnection(platform);
    return {
      platform,
      authMethod: spec.authMethod,
      configured: Boolean(row),
      enabled: row?.enabled === 1,
      available: row ? row.available === 1 : true,
      allowPersonal: row ? row.allow_personal === 1 : true,
      status: row?.status || 'not_configured',
      statusReason: row?.status_reason || null,
      accountLabel: row?.account_label || null,
      lastConnected: row?.last_connected || null,
      qr: store.readConnectionQr(row),
      linkedUsers: store.countLinks(platform),
    };
  });
}

module.exports = { SharedMessagingConnections, adminOverview, isActiveSharedChat };
