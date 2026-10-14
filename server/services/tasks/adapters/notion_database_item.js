'use strict';

const { connectionConfig, listFrom, requiredText, summaryParts, timeCursor } = require('./shared');

function pageTitle(page) {
  const title = Object.values(page.properties || {}).find((property) => property?.type === 'title');
  return (title?.title || []).map((part) => part.plain_text || '').join('') || '';
}

// Added and updated items read the same database, newest first by the
// timestamp each one watches. Notion keeps those timestamps to the minute.
function notionItemAdapter({ type, label, timestamp, verb }) {
  return {
    type,
    label,
    providerKey: 'notion',
    appKey: 'notion',
    configHint: '{ connectionId, databaseId }',
    async validateConfig(config = {}, context = {}) {
      return {
        ...connectionConfig(config, context, 'notion', 'notion'),
        databaseId: requiredText(config.databaseId || config.database_id, 200, 'Notion database ID is required.'),
      };
    },
    summarize(config = {}) {
      return summaryParts(`Notion items ${verb}`, [config.databaseId]);
    },
    poll: {
      intervalMinutes: 5,
      cursor: 'ordered',
      baseline: 'now',
      async fetchRows({ tool, config }) {
        const result = await tool('notion_query_database', {
          database_id: config.databaseId,
          sorts: [{ timestamp, direction: 'descending' }],
          page_size: 20,
        });
        return listFrom(result, ['results'])
          .map((page) => ({
            fingerprint: timeCursor(page[timestamp], page.id),
            timestamp: page[timestamp],
            context: {
              triggerEvent: {
                provider: 'notion',
                event: `database_item_${verb}`,
                databaseId: config.databaseId,
                pageId: page.id,
                title: pageTitle(page),
                url: page.url || null,
                createdTime: page.created_time || null,
                lastEditedTime: page.last_edited_time || null,
                properties: page.properties || {},
              },
            },
          }))
          .filter((row) => row.fingerprint)
          .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
      },
    },
  };
}

module.exports = { notionItemAdapter };
