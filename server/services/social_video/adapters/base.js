'use strict';

class SocialVideoAdapter {
  constructor(options = {}) {
    this.platform = String(options.platform || 'unknown');
    this.hosts = Array.isArray(options.hosts)
      ? options.hosts.map((host) => String(host || '').toLowerCase()).filter(Boolean)
      : [];
    this.captionLanguages = Array.isArray(options.captionLanguages)
      ? options.captionLanguages.map((value) => String(value || '').toLowerCase()).filter(Boolean)
      : ['en', 'en-us'];
  }

  supportsHost(hostname) {
    const host = String(hostname || '').toLowerCase();
    return this.hosts.some((candidate) => host === candidate || host.endsWith(`.${candidate}`));
  }

  getCaptionLanguagePreferences() {
    return [...this.captionLanguages];
  }
}

module.exports = {
  SocialVideoAdapter,
};
