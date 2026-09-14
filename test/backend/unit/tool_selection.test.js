'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  activateTools,
  expandNamesByFamily,
  selectInitialTools,
  suggestsCoreFileWork,
} = require('../../../server/services/ai/toolSelector');
const { getAvailableTools } = require('../../../server/services/ai/tools');

test('suggested file work is recognized so the shell can be added to it', () => {
  assert.equal(suggestsCoreFileWork(['write_file']), true);
  assert.equal(suggestsCoreFileWork(['execute_command']), true);
  assert.equal(suggestsCoreFileWork(['web_search']), false);
  assert.equal(suggestsCoreFileWork(undefined), false);
});

test('selecting one tool in a family activates the rest of that family', () => {
  const catalog = [
    { name: 'web_search', description: 'search' },
    { name: 'browser_navigate', family: 'browser_page', description: 'open url' },
    { name: 'browser_click', family: 'browser_page', description: 'click' },
    { name: 'browser_type', family: 'browser_page', description: 'type' },
    { name: 'browser_extract', family: 'browser_page', description: 'extract' },
    { name: 'browser_evaluate', description: 'js' },
  ];

  assert.deepEqual(
    expandNamesByFamily(['browser_navigate'], catalog),
    ['browser_navigate', 'browser_click', 'browser_type', 'browser_extract'],
  );
  assert.deepEqual(expandNamesByFamily(['web_search'], catalog), ['web_search']);

  const initial = selectInitialTools(catalog, ['browser_navigate']);
  assert.deepEqual(
    initial.map((tool) => tool.name),
    ['browser_navigate', 'browser_click', 'browser_type', 'browser_extract'],
  );
  assert.equal(initial.some((tool) => tool.name === 'browser_evaluate'), false);

  const activated = activateTools(
    [{ name: 'web_search' }],
    catalog,
    ['browser_click'],
  );
  assert.deepEqual(activated.activated.sort(), [
    'browser_click',
    'browser_extract',
    'browser_navigate',
    'browser_type',
  ]);
});

test('browser page tools keep their family through schema compaction', () => {
  const tools = getAvailableTools(null, { includeDescriptions: true });
  const pageTools = tools.filter((tool) => String(tool.name || '').startsWith('browser_'));
  const familyMembers = pageTools.filter((tool) => tool.family === 'browser_page').map((tool) => tool.name);
  assert.deepEqual(familyMembers.sort(), [
    'browser_click',
    'browser_extract',
    'browser_navigate',
    'browser_type',
  ]);
  assert.equal(pageTools.find((tool) => tool.name === 'browser_evaluate')?.family, undefined);
});
