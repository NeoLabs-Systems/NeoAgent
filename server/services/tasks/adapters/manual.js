'use strict';

module.exports = {
  type: 'manual',
  label: 'Manual Trigger',
  configHint: '{} — runs only when the user presses Run',
  async validateConfig() {
    return {};
  },
  summarize() {
    return 'Manual run only';
  },
};
