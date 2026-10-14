'use strict';

const { normalizeTrimmedText } = require('../security');
const { connectionConfig, listFrom, summaryParts, timeCursor } = require('./shared');

module.exports = {
  type: 'onedrive_file_added',
  label: 'OneDrive File Added',
  providerKey: 'microsoft_365',
  appKey: 'onedrive',
  configHint: '{ connectionId, folderId?: OneDrive item ID, otherwise the root folder }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'microsoft_365', 'onedrive'),
      folderId: normalizeTrimmedText(config.folderId || config.folder_id, 200),
    };
  },
  summarize(config = {}) {
    return summaryParts('OneDrive new files', [config.folderId && `folder: ${config.folderId}`]);
  },
  poll: {
    intervalMinutes: 5,
    cursor: 'ordered',
    baseline: 'now',
    async fetchRows({ tool, config }) {
      const result = await tool('microsoft_365_onedrive_list_children', {
        item_id: config.folderId || undefined,
        top: 200,
      });
      return listFrom(result, ['value'])
        .filter((item) => item && item.file)
        .map((item) => ({
          fingerprint: timeCursor(item.createdDateTime, item.id),
          timestamp: item.createdDateTime,
          context: {
            triggerEvent: {
              provider: 'onedrive',
              event: 'file_added',
              fileId: item.id,
              name: item.name || '',
              size: item.size ?? null,
              url: item.webUrl || null,
            },
          },
        }))
        .filter((row) => row.fingerprint)
        .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
    },
  },
};
