const EventEmitter = require('events');

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
  }

  setAllowedEntries(entries) {
    if (Array.isArray(entries)) {
      this.allowedEntries = new Set(entries.map(String));
    }
  }

  _checkAccess(id) {
    if (this.allowedEntries.size === 0) return true;
    return this.allowedEntries.has(String(id));
  }

  async connect() { throw new Error('connect() not implemented'); }
  async disconnect() { throw new Error('disconnect() not implemented'); }
  async sendMessage(to, content, options) { throw new Error('sendMessage() not implemented'); }
  async getContacts() { return []; }
  async getChats() { return []; }
  getStatus() { return this.status; }
  getAuthInfo() { return null; }
}

module.exports = { BasePlatform };
