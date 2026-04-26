'use strict';

module.exports = {
  type: 'manual',
  label: 'Manual Trigger',
  async validateConfig() {
    return {};
  },
  summarize() {
    return 'Manual run only';
  },
};
