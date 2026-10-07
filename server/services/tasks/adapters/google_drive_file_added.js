'use strict';

const { normalizeTrimmedText } = require('../security');
const { connectionConfig, summaryParts, timeCursor } = require('./shared');

const DRIVE_ID_PATTERN = /^[A-Za-z0-9_-]+$/;

module.exports = {
  type: 'google_drive_file_added',
  label: 'Google Drive File Added',
  providerKey: 'google_workspace',
  appKey: 'drive',
  configHint: '{ connectionId, folderId?: Drive folder ID, otherwise anywhere in Drive }',
  async validateConfig(config = {}, context = {}) {
    const folderId = normalizeTrimmedText(config.folderId || config.folder_id, 200);
    if (folderId && !DRIVE_ID_PATTERN.test(folderId)) {
      throw new Error('Google Drive folder ID is not valid.');
    }
    return {
      ...connectionConfig(config, context, 'google_workspace', 'drive'),
      folderId,
    };
  },
  summarize(config = {}) {
    return summaryParts('Google Drive new files', [config.folderId && `folder: ${config.folderId}`]);
  },
  poll: {
    intervalMinutes: 5,
    cursor: 'ordered',
    baseline: 'now',
    async fetchRows({ tool, config }) {
      const response = await tool('google_workspace_drive_api_request', {
        method: 'GET',
        path: '/drive/v3/files',
        query: {
          q: config.folderId ? `'${config.folderId}' in parents and trashed = false` : 'trashed = false',
          orderBy: 'createdTime desc',
          pageSize: 20,
          fields: 'files(id,name,mimeType,createdTime,webViewLink)',
        },
      });
      const files = Array.isArray(response?.data?.files) ? response.data.files : [];
      return files
        .map((file) => ({
          fingerprint: timeCursor(file.createdTime, file.id),
          timestamp: file.createdTime,
          context: {
            triggerEvent: {
              provider: 'google_drive',
              event: 'file_added',
              fileId: file.id,
              name: file.name || '',
              mimeType: file.mimeType || null,
              url: file.webViewLink || null,
            },
          },
        }))
        .filter((row) => row.fingerprint)
        .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
    },
  },
};
