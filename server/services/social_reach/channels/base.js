'use strict';

class SocialReachChannel {
  constructor(definition) {
    this.id = definition.id;
    this.label = definition.label;
    this.tier = definition.tier;
    this.setupKind = definition.setupKind;
    this.hosts = definition.hosts || [];
    this.domains = definition.domains || [];
  }

  canHandleUrl(url) {
    if (!this.hosts.length) return false;
    let parsed;
    try {
      parsed = new URL(String(url || ''));
    } catch {
      return false;
    }
    const host = parsed.hostname.toLowerCase().replace(/^www\./, '');
    return this.hosts.some((candidate) => {
      const normalized = String(candidate).toLowerCase().replace(/^www\./, '');
      return host === normalized || host.endsWith(`.${normalized}`);
    });
  }

  async check() {
    return {
      platform: this.id,
      label: this.label,
      ready: true,
      status: 'ok',
      activeBackend: 'node',
      tier: this.tier,
      setupKind: this.setupKind,
      message: 'Ready.',
    };
  }

  async read() {
    const error = new Error(`${this.label} reading is not implemented.`);
    error.status = 501;
    throw error;
  }

  async search() {
    const error = new Error(`${this.label} search is not implemented.`);
    error.status = 501;
    throw error;
  }
}

module.exports = {
  SocialReachChannel,
};
