'use strict';

const { notionItemAdapter } = require('./notion_database_item');

module.exports = notionItemAdapter({
  type: 'notion_database_item_updated',
  label: 'Notion Database Item Updated',
  timestamp: 'last_edited_time',
  verb: 'updated',
});
