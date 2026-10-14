'use strict';

const { normalizeTrimmedText } = require('../security');
const { connectionConfig, listFrom, sequenceCursor, summaryParts } = require('./shared');

// Nextcloud numbers files in the order they arrive, so the file ID is the
// cursor: clients keep a file's original modified time when they upload it.
module.exports = {
  type: 'nextcloud_file_added',
  label: 'Nextcloud File Added',
  providerKey: 'nextcloud',
  appKey: 'files',
  configHint: '{ connectionId, path?: folder relative to the user root, e.g. "Documents" }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'nextcloud', 'files'),
      path: normalizeTrimmedText(config.path, 500),
    };
  },
  summarize(config = {}) {
    return summaryParts('Nextcloud new files', [config.path || '/']);
  },
  poll: {
    intervalMinutes: 5,
    cursor: 'ordered',
    baseline: 'latest',
    async fetchRows({ tool, config }) {
      const result = await tool('nextcloud_list_files', { path: config.path || undefined });
      return listFrom(result)
        .filter((entry) => entry?.type === 'file')
        .map((entry) => ({
          fingerprint: sequenceCursor(entry.fileId),
          timestamp: entry.lastModified || new Date().toISOString(),
          context: {
            triggerEvent: {
              provider: 'nextcloud',
              event: 'file_added',
              path: entry.path,
              name: entry.name,
              size: entry.size,
              mimeType: entry.mimeType,
            },
          },
        }))
        .filter((row) => row.fingerprint)
        .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
    },
  },
};
