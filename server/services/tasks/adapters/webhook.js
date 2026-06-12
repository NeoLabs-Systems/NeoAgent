'use strict';

module.exports = {
  type: 'webhook',
  label: 'Signed Webhook',
  async validateConfig(config = {}) {
    return {
      sourceLabel: String(config.sourceLabel || config.source_label || '').trim() || null,
    };
  },
  summarize(config = {}) {
    return config.sourceLabel ? `Signed webhook from ${config.sourceLabel}` : 'Signed webhook';
  },
};
