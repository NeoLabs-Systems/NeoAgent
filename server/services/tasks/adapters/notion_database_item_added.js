'use strict';

const { notionItemAdapter } = require('./notion_database_item');

module.exports = notionItemAdapter({
  type: 'notion_database_item_added',
  label: 'Notion Database Item Added',
  timestamp: 'created_time',
  verb: 'added',
});
