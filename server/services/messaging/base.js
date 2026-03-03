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
