'use strict';

const { connectionConfig, listFrom, sequenceCursor, summaryParts } = require('./shared');

module.exports = {
  type: 'nextcloud_share_received',
  label: 'Nextcloud File Shared With You',
  providerKey: 'nextcloud',
  appKey: 'files',
  configHint: '{ connectionId }',
  async validateConfig(config = {}, context = {}) {
    return connectionConfig(config, context, 'nextcloud', 'files');
  },
  summarize() {
    return summaryParts('Nextcloud shares with you', []);
  },
  poll: {
    intervalMinutes: 10,
    cursor: 'ordered',
    baseline: 'latest',
    async fetchRows({ tool }) {
      const result = await tool('nextcloud_list_shares', { shared_with_me: true });
      return listFrom(result)
        .map((share) => ({
          fingerprint: sequenceCursor(share.id),
          timestamp: share.stime ? new Date(Number(share.stime) * 1000).toISOString() : new Date().toISOString(),
          context: {
            triggerEvent: {
              provider: 'nextcloud',
              event: 'share_received',
              shareId: share.id,
              path: share.file_target || share.path || null,
              itemType: share.item_type || null,
              owner: share.displayname_owner || share.uid_owner || null,
              note: share.note || null,
            },
          },
        }))
        .filter((row) => row.fingerprint)
        .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
    },
  },
};
