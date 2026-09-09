'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');
const { execSync } = require('node:child_process');

const { diagnosticsCommand, runFileDiagnostics } = require('../../../server/services/ai/file_diagnostics');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;

afterEach(() => {
  if (ctx) teardownTestRuntime(ctx);
  ctx = null;
});

test('diagnostics commands cover python and javascript, quote paths, and skip other files', () => {
  assert.match(diagnosticsCommand('src/a b.py'), /^python3 -c '[\s\S]*' 'src\/a b\.py'$/);
  assert.match(diagnosticsCommand("it's.js"), /^node --check 'it'\\''s\.js'$/);
  assert.equal(diagnosticsCommand('notes.md'), null);
  assert.equal(diagnosticsCommand(''), null);
});

test('runFileDiagnostics reports only a real checker verdict', async () => {
  const verdict = await runFileDiagnostics({
    async executeCliCommand() { return { exitCode: 1, stderr: 'SyntaxError: bad', stdout: '' }; },
  }, 1, 'x.py');
  assert.deepEqual(verdict, { ok: false, output: 'SyntaxError: bad' });

  const missingInterpreter = await runFileDiagnostics({
    async executeCliCommand() { return { exitCode: 127, stderr: 'python3: not found' }; },
  }, 1, 'x.py');
  assert.equal(missingInterpreter, null);

  const clean = await runFileDiagnostics({
    async executeCliCommand() { return { exitCode: 0, stderr: '' }; },
  }, 1, 'x.py');
  assert.equal(clean, null);

  assert.equal(await runFileDiagnostics(null, 1, 'x.py'), null);
});

test('write_file surfaces a syntax error in its result and stays silent for valid code', async () => {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: 'diag_user' });
  const { WorkspaceManager } = require('../../../server/services/workspace/manager');
  const { executeTool } = require('../../../server/services/ai/tools');
  const workspaceManager = new WorkspaceManager();
  const root = workspaceManager.resolvePath(user.userId, '', 'path');
  const runtimeManager = {
    async executeCliCommand(_userId, command) {
      try {
        return { exitCode: 0, stdout: execSync(command, { cwd: root, stdio: 'pipe' }).toString(), stderr: '' };
      } catch (error) {
        return { exitCode: error.status, stdout: '', stderr: String(error.stderr || '') };
      }
    },
  };
  const services = { workspaceManager, runtimeManager };
  const context = { userId: user.userId };

  const broken = await executeTool('write_file', { path: 'broken.py', content: 'def f(:\n  pass\n' }, context, services);
  assert.equal(broken.success, true);
  assert.equal(broken.diagnostics.ok, false);
  assert.match(broken.diagnostics.output, /SyntaxError/);

  const fine = await executeTool('write_file', { path: 'fine.py', content: 'def f():\n    return 1\n' }, context, services);
  assert.equal(fine.success, true);
  assert.equal(fine.diagnostics, undefined);
});
