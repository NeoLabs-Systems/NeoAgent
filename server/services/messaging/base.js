const EventEmitter = require('events');
const {
  createDefaultAccessPolicy,
  normalizeAccessPolicy,
  getPlatformAccessCapabilities,
  evaluateAccessPolicy,
  buildBlockedSenderPayload,
} = require('./access_policy');
const { createServiceLogger, maskSenderId } = require('../../utils/logger');

const log = createServiceLogger('Messaging');

const ACCESS_DENIED_HINTS = Object.freeze({
  direct_disabled: 'direct messages are switched off for this platform',
  direct_not_allowed: 'the sender is not on the direct-message allowlist',
  shared_disabled: 'group messages are switched off for this platform',
  shared_not_allowed: 'the group is not on the allowlist',
  unsupported_context: 'the message was neither a direct nor a group message',
});

class BasePlatform extends EventEmitter {
  constructor(name, config = {}) {
    super();
    this.name = name;
    this.config = config;
    this.status = 'disconnected';
    this.supportsGroups = false;
    this.supportsMedia = false;
    this.supportsVoice = false;
    this.allowedEntries = new Set();
    this.accessCapabilities = getPlatformAccessCapabilities(name);
    this.accessPolicy = createDefaultAccessPolicy(name);
    if (config.accessPolicy) {
      this.setAccessPolicy(config.accessPolicy);
    }
  }

  setAllowedEntries(entries) {
    if (Array.isArray(entries)) {
      this.allowedEntries = new Set(entries.map(String));
    }
  }

  setAccessPolicy(policy) {
    this.accessPolicy = normalizeAccessPolicy(this.name, policy);
    return this.accessPolicy;
  }

  getAccessPolicy() {
    return this.accessPolicy;
  }

  getAccessCapabilities() {
    return this.accessCapabilities;
  }

  _checkAccess(id) {
    if (this.allowedEntries.size === 0) return true;
    return this.allowedEntries.has(String(id));
  }

  evaluateAccess(context) {
    return evaluateAccessPolicy(this.accessPolicy, context, this.name);
  }

  _checkInboundAccess(context, options = {}) {
    const result = this.evaluateAccess(context);
    if (result.allowed) {
      return result;
    }
    // Without this line a refused message leaves no trace: the socket event
    // below only reaches a client that happens to be open at that moment.
    log.warn(
      `${this.name}: ignored a message from ${maskSenderId(context?.senderId || context?.phoneNumber)}`
      + ` because ${ACCESS_DENIED_HINTS[result.reason] || result.reason}.`
      + ' Allow the sender under Messaging access to let it through.',
    );
    this.emit('blocked_sender', buildBlockedSenderPayload(this.name, context, options));
    return result;
  }

  async connect() { throw new Error('connect() not implemented'); }
  async disconnect() { throw new Error('disconnect() not implemented'); }
  async sendMessage(to, content, options) { throw new Error('sendMessage() not implemented'); }
  async getContacts() { return []; }
  async getChats() { return []; }
  async listAccessTargets() { return []; }
  getStatus() { return this.status; }
  getAuthInfo() { return null; }
}

module.exports = { BasePlatform };
