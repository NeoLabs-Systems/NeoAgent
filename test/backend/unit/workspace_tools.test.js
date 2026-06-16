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

test('read_files reads multiple files and line ranges in one call', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'read_files_batch' });
  const { WorkspaceManager } = require('../../../server/services/workspace/manager');
  const { executeTool } = require('../../../server/services/ai/tools');
  const workspaceManager = new WorkspaceManager();

  workspaceManager.writeFile(user.userId, {
    path: 'one.txt',
    content: ['a1', 'a2', 'a3'].join('\n'),
  });
  workspaceManager.writeFile(user.userId, {
    path: 'two.txt',
    content: ['b1', 'b2', 'b3', 'b4'].join('\n'),
  });

  const result = await executeTool('read_files', {
    files: [
      { path: 'one.txt', start_line: 2, end_line: 3 },
      { file_path: 'two.txt', line_start: 1, line_count: 2 },
    ],
  }, {
    userId: user.userId,
  }, {
    workspaceManager,
  });

  assert.equal(result.success, true);
  assert.equal(result.count, 2);
  assert.equal(result.results[0].content, 'a2\na3');
  assert.deepEqual(result.results[0].rangeShown, [2, 3]);
  assert.equal(result.results[1].content, 'b1\nb2');
  assert.deepEqual(result.results[1].rangeShown, [1, 2]);
});

test('replace_file_range replaces known line spans without exact text matching', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'replace_file_range' });
  const { WorkspaceManager } = require('../../../server/services/workspace/manager');
  const { executeTool } = require('../../../server/services/ai/tools');
  const workspaceManager = new WorkspaceManager();

  workspaceManager.writeFile(user.userId, {
    path: 'notes.txt',
    content: ['alpha', 'beta', 'gamma', 'delta'].join('\n'),
  });

  const edit = await executeTool('replace_file_range', {
    path: 'notes.txt',
    start_line: 2,
    end_line: 3,
    content: 'BETA\nGAMMA',
  }, {
    userId: user.userId,
  }, {
    workspaceManager,
  });
  const read = workspaceManager.readFile(user.userId, { path: 'notes.txt' });

  assert.equal(edit.success, true);
  assert.equal(edit.replacedLines, 2);
  assert.equal(edit.insertedLines, 2);
  assert.equal(read.content, ['alpha', 'BETA', 'GAMMA', 'delta'].join('\n'));
});

test('file tool schemas expose batch read and line range edit', () => {
  ctx = createTestRuntime();
  const { getAvailableTools } = require('../../../server/services/ai/tools');

  const [readFiles, replaceRange] = getAvailableTools(null, {
    names: ['read_files', 'replace_file_range'],
  });

  assert.equal(readFiles.parameters.properties.files.type, 'array');
  assert.deepEqual(readFiles.parameters.required, ['files']);
  assert.equal(replaceRange.parameters.properties.start_line.type, 'number');
  assert.deepEqual(replaceRange.parameters.required, ['path', 'start_line', 'end_line', 'content']);
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
