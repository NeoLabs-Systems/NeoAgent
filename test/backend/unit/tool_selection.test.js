'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { suggestsCoreFileWork } = require('../../../server/services/ai/toolSelector');

test('suggested file work is recognized so the shell can be added to it', () => {
  assert.equal(suggestsCoreFileWork(['write_file']), true);
  assert.equal(suggestsCoreFileWork(['execute_command']), true);
  assert.equal(suggestsCoreFileWork(['web_search']), false);
  assert.equal(suggestsCoreFileWork(undefined), false);
});
