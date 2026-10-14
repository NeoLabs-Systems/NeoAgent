'use strict';

const { connectionConfig, listFrom, summaryParts, timeCursor } = require('./shared');

// A day's summary is rewritten while the day goes on; it fires once it is final.
module.exports = {
  type: 'neorecall_daily_summary_created',
  label: 'NeoRecall Daily Summary Ready',
  providerKey: 'neorecall',
  appKey: 'recall',
  configHint: '{ connectionId }',
  async validateConfig(config = {}, context = {}) {
    return connectionConfig(config, context, 'neorecall', 'recall');
  },
  summarize() {
    return summaryParts('NeoRecall daily summary', []);
  },
  poll: {
    intervalMinutes: 15,
    cursor: 'ordered',
    baseline: 'now',
    async fetchRows({ tool }) {
      const result = await tool('neorecall_list_daily_summaries', { limit: 5 });
      return listFrom(result, ['items'])
        .filter((summary) => summary?.state === 'final')
        .map((summary) => ({
          fingerprint: timeCursor(summary.updated_at, summary.id),
          timestamp: summary.updated_at,
          context: {
            triggerEvent: {
              provider: 'neorecall',
              event: 'daily_summary_ready',
              date: summary.local_date,
              summary: summary.summary_en || '',
              sourceCount: summary.source_count ?? null,
            },
          },
        }))
        .filter((row) => row.fingerprint)
        .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
    },
  },
};
