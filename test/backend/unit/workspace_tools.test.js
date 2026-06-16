'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

let ctx;

afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

test('read_file accepts model-emitted file_path and line range aliases', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'read_file_aliases' });
  const { WorkspaceManager } = require('../../../server/services/workspace/manager');
  const { executeTool } = require('../../../server/services/ai/tools');
  const workspaceManager = new WorkspaceManager();

  const writeResult = workspaceManager.writeFile(user.userId, {
    path: 'issues.txt',
    content: ['one', 'two', 'three', 'four'].join('\n'),
  });
  assert.equal(writeResult.success, true);

  const result = await executeTool('read_file', {
    file_path: 'issues.txt',
    line_start: 2,
    line_count: 2,
  }, {
    userId: user.userId,
  }, {
    workspaceManager,
  });

  assert.equal(result.error, undefined);
  assert.equal(result.content, 'two\nthree');
  assert.deepEqual(result.rangeShown, [2, 3]);
});

test('read_file schema exposes compatibility aliases without requiring only path', () => {
  ctx = createTestRuntime();
  const { getAvailableTools } = require('../../../server/services/ai/tools');

  const readFile = getAvailableTools(null, { names: ['read_file'] })[0];

  assert.equal(readFile.parameters.properties.file_path.type, 'string');
  assert.equal(readFile.parameters.properties.line_start.type, 'number');
  assert.equal(readFile.parameters.properties.line_count.type, 'number');
  assert.deepEqual(readFile.parameters.required, []);
});

test('read_file missing path fails explicitly instead of reading the workspace directory', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'read_file_missing_path' });
  const { WorkspaceManager } = require('../../../server/services/workspace/manager');
  const { executeTool } = require('../../../server/services/ai/tools');

  const result = await executeTool('read_file', {
    line_start: 1,
  }, {
    userId: user.userId,
  }, {
    workspaceManager: new WorkspaceManager(),
  });

  assert.match(result.error, /requires path or file_path/);
  assert.doesNotMatch(result.error, /EISDIR/);
});
