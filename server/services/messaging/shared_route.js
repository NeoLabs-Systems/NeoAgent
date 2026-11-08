'use strict';

const { normalizeWhatsAppId } = require('../../utils/whatsapp');
const { findLinkForUser } = require('./shared_store');

const OUTBOUND_LIMIT_PER_MINUTE = 60;

function chatKey(platform, value) {
  const raw = String(value || '').trim();
  if (platform === 'telegram') return raw.startsWith('dm_') ? raw.slice(3) : raw;
  if (platform === 'whatsapp') return normalizeWhatsAppId(raw);
  return raw;
}

// Whether this chat is the person's own direct chat with the shared account.
// Only such a chat may ever receive replies: on WhatsApp a broadcast list or
// status looks direct too, and its id would resolve to someone else's number.
function isSendersOwnChat(platform, chatId, externalId) {
  const chat = String(chatId || '');
  if (platform === 'telegram') return chat === `dm_${externalId}`;
  if (platform === 'whatsapp') {
    if (chat.endsWith('@lid')) return true;
    return chat.endsWith('@s.whatsapp.net') && normalizeWhatsAppId(chat) === String(externalId);
  }
  return false;
}

// The link this agent reaches a platform through, if it uses the shared account.
function sharedLinkFor(userId, agentId, platform) {
  const link = findLinkForUser(platform, userId);
  return link?.agent_id === agentId ? link : null;
}

function isLinkRecipient(platform, link, to) {
  const requested = chatKey(platform, to);
  return requested === chatKey(platform, link.chat_id) || requested === link.external_id;
}

// Whether a shared account would refuse this recipient for this agent. A
// personal connection has no such limit, so it never counts as refused.
function isRefusedSharedRecipient(userId, agentId, platform, to) {
  const link = sharedLinkFor(userId, agentId, platform);
  return Boolean(link) && !isLinkRecipient(platform, link, to);
}

// A saved destination the shared account would refuse falls back to the person's
// own chat, its only reachable one, so results keep arriving after a switch to it.
function reachableSharedTarget(userId, agentId, target) {
  if (!isRefusedSharedRecipient(userId, agentId, target.platform, target.to)) return target;
  return { platform: target.platform, to: sharedLinkFor(userId, agentId, target.platform).chat_id };
}

class SlidingWindowLimiter {
  constructor(limit, windowMs, maxKeys = 10000) {
    this.limit = limit;
    this.windowMs = windowMs;
    this.maxKeys = maxKeys;
    this.hits = new Map();
  }

  take(key, now = Date.now()) {
    const recent = (this.hits.get(key) || []).filter((at) => now - at < this.windowMs);
    if (recent.length >= this.limit) return false;
    recent.push(now);
    // Re-inserting keeps the map in last-seen order, so the oldest key goes first.
    this.hits.delete(key);
    this.hits.set(key, recent);
    if (this.hits.size > this.maxKeys) this.hits.delete(this.hits.keys().next().value);
    return true;
  }
}

// What one user's agent holds in place of a platform connection. MessagingManager
// treats it like any adapter, so runs, typing and delivery need no second path;
// this is where an instance-wide account gets narrowed to that user's own chat.
// The link is read on every call, so an unlink applies immediately.
class SharedRoutePlatform {
  constructor({ platform, userId, agentId, getAdapter }) {
    this.name = platform;
    this.isSharedRoute = true;
    this.userId = userId;
    this.agentId = agentId;
    this.getAdapter = getAdapter;
    this.outboundLimiter = new SlidingWindowLimiter(OUTBOUND_LIMIT_PER_MINUTE, 60 * 1000);
  }

  _activeLink() {
    return sharedLinkFor(this.userId, this.agentId, this.name);
  }

  // Replies always go to the chat stored on the link, whatever form `to` used.
  _deliveryTarget(to) {
    const link = this._activeLink();
    if (!link) throw new Error(`This agent is no longer linked to the shared ${this.name} account.`);
    if (!isSendersOwnChat(this.name, link.chat_id, link.external_id)) {
      const error = new Error(`The shared ${this.name} account can only message your own linked chat.`);
      error.code = 'SHARED_RECIPIENT_NOT_ALLOWED';
      throw error;
    }
    if (!isLinkRecipient(this.name, link, to)) {
      const error = new Error(`The shared ${this.name} account can only message your own linked chat.`);
      error.code = 'SHARED_RECIPIENT_NOT_ALLOWED';
      throw error;
    }
    const adapter = this.getAdapter();
    if (!adapter) throw new Error(`The shared ${this.name} account is not connected.`);
    return { adapter, chatId: link.chat_id };
  }

  async conversationChatIds(chatId) {
    return (await this.getAdapter()?.conversationChatIds?.(chatId)) || [chatId];
  }

  async sendMessage(to, content, options = {}) {
    const { adapter, chatId } = this._deliveryTarget(to);
    if (!this.outboundLimiter.take('send')) {
      const error = new Error(`Too many messages through the shared ${this.name} account; try again in a minute.`);
      error.code = 'SHARED_RATE_LIMITED';
      throw error;
    }
    return adapter.sendMessage(chatId, content, options);
  }

  // Absent on an adapter with nothing to tap, where the prompt is plain text.
  async sendApprovalPrompt(to, prompt) {
    const { adapter, chatId } = this._deliveryTarget(to);
    if (adapter.sendApprovalPrompt) return adapter.sendApprovalPrompt(chatId, prompt);
    return adapter.sendMessage(chatId, `${prompt.text}\n\n${prompt.replyHint}`);
  }

  async deleteApprovalPrompt(to, promptId) {
    const { adapter, chatId } = this._deliveryTarget(to);
    return adapter.deleteApprovalPrompt?.(chatId, promptId);
  }

  async sendTyping(to, isTyping, options = {}) {
    const { adapter, chatId } = this._deliveryTarget(to);
    return adapter.sendTyping?.(chatId, isTyping, options);
  }

  async markRead(to, messageId, options = {}) {
    const { adapter, chatId } = this._deliveryTarget(to);
    return adapter.markRead?.(chatId, messageId, options);
  }

  async sendReaction(to, messageId, emoji, options = {}) {
    const { adapter, chatId } = this._deliveryTarget(to);
    if (typeof adapter.sendReaction !== 'function') {
      throw new Error(`Platform ${this.name} cannot send reactions`);
    }
    return adapter.sendReaction(chatId, messageId, emoji, options);
  }

  getStatus() {
    if (!this._activeLink()) return 'disconnected';
    return this.getAdapter()?.getStatus() || 'disconnected';
  }

  // Never the adapter's own auth info: for WhatsApp that carries the login QR.
  getAuthInfo() {
    const link = this._activeLink();
    return link ? { shared: true, label: link.display_name || null } : null;
  }

  // The shared account keeps running for everyone else.
  async disconnect() {}
}

module.exports = {
  SharedRoutePlatform,
  SlidingWindowLimiter,
  chatKey,
  isRefusedSharedRecipient,
  isSendersOwnChat,
  reachableSharedTarget,
};
