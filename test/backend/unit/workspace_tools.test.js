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

test('file tool schemas expose compatibility aliases without over-requiring fields', () => {
  ctx = createTestRuntime();
  const { getAvailableTools } = require('../../../server/services/ai/tools');

  const tools = getAvailableTools(null, {
    names: ['read_file', 'read_files', 'write_file', 'edit_file', 'replace_file_range', 'list_directory', 'search_files'],
    includeDescriptions: true,
  });
  const readFile = tools.find((tool) => tool.name === 'read_file');
  const readFiles = tools.find((tool) => tool.name === 'read_files');
  const writeFile = tools.find((tool) => tool.name === 'write_file');
  const editFile = tools.find((tool) => tool.name === 'edit_file');
  const replaceRange = tools.find((tool) => tool.name === 'replace_file_range');
  const listDirectory = tools.find((tool) => tool.name === 'list_directory');
  const searchFiles = tools.find((tool) => tool.name === 'search_files');

  assert.equal(readFile.parameters.properties.file_path.type, 'string');
  assert.equal(readFile.parameters.properties.line_start.type, 'number');
  assert.equal(readFile.parameters.properties.line_count.type, 'number');
  assert.deepEqual(readFile.parameters.required, []);
  assert.equal(readFiles.parameters.properties.paths.type, 'array');
  assert.deepEqual(readFiles.parameters.required, []);
  assert.equal(writeFile.parameters.properties.file_path.type, 'string');
  assert.deepEqual(writeFile.parameters.required, ['content']);
  assert.equal(editFile.parameters.properties.file_path.type, 'string');
  assert.deepEqual(editFile.parameters.required, ['edits']);
  assert.equal(replaceRange.parameters.properties.file_path.type, 'string');
  assert.equal(replaceRange.parameters.properties.startLine.type, 'number');
  assert.deepEqual(replaceRange.parameters.required, ['content']);
  assert.deepEqual(listDirectory.parameters.required, []);
  assert.deepEqual(searchFiles.parameters.required, ['query']);
  assert.equal(searchFiles.parameters.properties.maxDepth.type, 'number');
  assert.match(readFile.description, /workspace/);
  assert.match(readFiles.description, /workspace/);
  assert.doesNotMatch(readFile.description, /cat \/tmp/);
  assert.doesNotMatch(readFiles.description, /cat \/tmp/);
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

test('read_files accepts a paths convenience array', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'read_files_paths' });
  const { WorkspaceManager } = require('../../../server/services/workspace/manager');
  const { executeTool } = require('../../../server/services/ai/tools');
  const workspaceManager = new WorkspaceManager();

  workspaceManager.writeFile(user.userId, { path: 'a.txt', content: 'aaa' });
  workspaceManager.writeFile(user.userId, { path: 'b.txt', content: 'bbb' });

  const result = await executeTool('read_files', {
    paths: ['a.txt', 'b.txt'],
  }, {
    userId: user.userId,
  }, {
    workspaceManager,
  });

  assert.equal(result.success, true);
  assert.equal(result.count, 2);
  assert.equal(result.results[0].content, 'aaa');
  assert.equal(result.results[1].content, 'bbb');
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

test('write and edit tools accept common path and edit aliases', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'write_edit_aliases' });
  const { WorkspaceManager } = require('../../../server/services/workspace/manager');
  const { executeTool } = require('../../../server/services/ai/tools');
  const workspaceManager = new WorkspaceManager();

  const write = await executeTool('write_file', {
    file_path: 'aliases.txt',
    content: 'alpha\nbeta\ngamma',
  }, {
    userId: user.userId,
  }, {
    workspaceManager,
  });
  assert.equal(write.success, true);

  const edit = await executeTool('edit_file', {
    file_path: 'aliases.txt',
    edits: [{ old_text: 'beta', new_text: 'BETA' }],
  }, {
    userId: user.userId,
  }, {
    workspaceManager,
  });
  assert.equal(edit.success, true);

  const range = await executeTool('replace_file_range', {
    file_path: 'aliases.txt',
    startLine: 3,
    endLine: 3,
    content: 'GAMMA',
  }, {
    userId: user.userId,
  }, {
    workspaceManager,
  });
  assert.equal(range.success, true);

  const read = workspaceManager.readFile(user.userId, { path: 'aliases.txt' });
  assert.equal(read.content, 'alpha\nBETA\nGAMMA');
});

test('list_directory and search_files default to workspace root', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'workspace_root_defaults' });
  const { WorkspaceManager } = require('../../../server/services/workspace/manager');
  const { executeTool } = require('../../../server/services/ai/tools');
  const workspaceManager = new WorkspaceManager();

  workspaceManager.writeFile(user.userId, {
    path: 'root-defaults.txt',
    content: 'needle',
  });

  const list = await executeTool('list_directory', {}, {
    userId: user.userId,
  }, {
    workspaceManager,
  });
  const search = await executeTool('search_files', {
    query: 'needle',
    include: '*.txt',
    maxDepth: 2,
  }, {
    userId: user.userId,
  }, {
    workspaceManager,
  });

  assert.ok(list.entries.some((entry) => entry.name === 'root-defaults.txt'));
  assert.equal(search.count, 1);
  assert.match(search.matches[0].file, /root-defaults\.txt$/);
});

test('file tool schemas expose batch read and line range edit', () => {
  ctx = createTestRuntime();
  const { getAvailableTools } = require('../../../server/services/ai/tools');

  const [readFiles, replaceRange] = getAvailableTools(null, {
    names: ['read_files', 'replace_file_range'],
  });

  assert.equal(readFiles.parameters.properties.files.type, 'array');
  assert.deepEqual(readFiles.parameters.required, []);
  assert.equal(replaceRange.parameters.properties.start_line.type, 'number');
  assert.deepEqual(replaceRange.parameters.required, ['content']);
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
  assert.match(result.error, /workspace/);
  assert.doesNotMatch(result.error, /cat \/tmp/);
  assert.doesNotMatch(result.error, /EISDIR/);
});
