'use strict';

const { connectionConfig, listFrom, requiredText, summaryParts, timeCursor } = require('./shared');

module.exports = {
  type: 'figma_comment_added',
  label: 'Figma Comment Added',
  providerKey: 'figma',
  appKey: 'figma',
  configHint: '{ connectionId, fileKey: from the Figma file URL }',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'figma', 'figma'),
      fileKey: requiredText(config.fileKey || config.file_key, 100, 'Figma file key is required.'),
    };
  },
  summarize(config = {}) {
    return summaryParts('Figma comments', [config.fileKey]);
  },
  poll: {
    intervalMinutes: 10,
    cursor: 'ordered',
    baseline: 'now',
    async fetchRows({ tool, config }) {
      const result = await tool('figma_get_comments', { file_key: config.fileKey });
      return listFrom(result, ['comments'])
        .map((comment) => ({
          fingerprint: timeCursor(comment.created_at, comment.id),
          timestamp: comment.created_at,
          context: {
            triggerEvent: {
              provider: 'figma',
              event: 'comment_added',
              fileKey: config.fileKey,
              commentId: comment.id,
              message: comment.message || '',
              author: comment.user?.handle || null,
              replyTo: comment.parent_id || null,
            },
          },
        }))
        .filter((row) => row.fingerprint)
        .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
    },
  },
};
