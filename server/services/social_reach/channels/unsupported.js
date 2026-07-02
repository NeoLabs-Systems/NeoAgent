'use strict';

const { SocialReachChannel } = require('./base');
const { getPlatformDefinition } = require('../platforms');

const MESSAGES = Object.freeze({
  twitter: 'X/Twitter requires brittle authenticated browser/API access. It is listed for setup visibility but not implemented under the Node-only constraint.',
  reddit: 'Reddit search/read currently needs authenticated browser or third-party tooling for reliable access. It is not implemented under the Node-only constraint.',
  facebook: 'Facebook content access requires a logged-in browser session or approved Graph API app. It is not implemented under the Node-only constraint.',
  instagram: 'Instagram content access requires a logged-in browser session or approved Graph API app. It is not implemented under the Node-only constraint.',
  bilibili: 'Bilibili support in Agent-Reach depends on non-Node tooling. It is not implemented under the Node-only constraint.',
  xiaohongshu: 'Xiaohongshu support depends on authenticated browser automation or non-Node tooling. It is not implemented under the Node-only constraint.',
  xiaoyuzhou: 'Xiaoyuzhou transcription needs media download and Whisper-style transcription setup. It is not implemented under the Node-only constraint.',
  exa_search: 'Exa MCP setup depends on external MCP tooling. Use NeoAgent web search or configure an MCP server separately.',
});

class UnsupportedChannel extends SocialReachChannel {
  constructor(platform) {
    super(getPlatformDefinition(platform));
  }

  async check() {
    return {
      platform: this.id,
      label: this.label,
      ready: false,
      status: 'off',
      activeBackend: null,
      tier: this.tier,
      setupKind: this.setupKind,
      message: MESSAGES[this.id] || `${this.label} is unavailable in Node-only mode.`,
    };
  }

  async read() {
    const status = await this.check();
    const error = new Error(status.message);
    error.status = 501;
    throw error;
  }

  async search() {
    return this.read();
  }
}

module.exports = {
  UnsupportedChannel,
};
