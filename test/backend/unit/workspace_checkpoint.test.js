'use strict';

const assert = require('node:assert/strict');
const { execFileSync, spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { afterEach, test } = require('node:test');
const { ensureCheckpoint, recordMutation, rollbackWorkspace, changedPaths } = require('../../../server/services/ai/runtime/workspace_checkpoint');
const { repoDiff } = require('../../../server/services/workspace/repo_diff');
const { repoOverview } = require('../../../server/services/workspace/repo_inspect');
const { GUEST_WORKSPACE_DIR } = require('../../../server/services/runtime/guest_paths');
const roots = [];
afterEach(() => { for (const root of roots.splice(0)) fs.rmSync(root, { recursive: true, force: true }); });
function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'neo-checkpoint-')); roots.push(root);
  const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
  const write = (name, body) => fs.writeFileSync(path.join(root, name), body);
  git('init', '-q'); git('config', 'user.name', 'Test'); git('config', 'user.email', 'test@example.test');
  write('a.txt', 'before\n'); git('add', '.'); git('commit', '-qm', 'initial');
  const commands = [];
  const computer = { async executeCliCommand(_user, command, options = {}) {
    commands.push(command);
    const result = spawnSync('/bin/sh', ['-c', command], { cwd: options.cwd === GUEST_WORKSPACE_DIR ? root : (options.cwd || root), encoding: 'utf8' });
    return { exitCode: result.status, stdout: result.stdout, stderr: result.stderr };
  } };
  const events = [];
  const session = { userId: 1, runId: 'fixture', eventBus: { publish: (event) => events.push(event) }, engine: { runtimeManager: computer } };
  const shell = { run: (command) => computer.executeCliCommand(1, command, { cwd: root }) };
  return { root, git, write, computer, commands, session, shell, events };
}

test('raw snapshots track changes without touching index or branch', async () => {
  const f = fixture(); const index = fs.readFileSync(path.join(f.root, '.git/index'));
  const head = f.git('rev-parse', 'HEAD');
  const call = { name: 'edit_file', arguments: { path: 'a.txt' } };
  const start = await ensureCheckpoint(f.session, call); assert.ok(start?.tree);
  f.write('a.txt', 'after\n'); f.write('other.txt', 'external\n');
  assert.deepEqual(await recordMutation(f.session, start), ['a.txt']);
  assert.deepEqual(changedPaths(f.session), ['a.txt']);
  assert.deepEqual(fs.readFileSync(path.join(f.root, '.git/index')), index);
  assert.equal(f.git('rev-parse', 'HEAD'), head);
});

test('rollback refuses all shared-workspace restores, including concurrent external creations', async () => {
  const f = fixture();
  const start = await ensureCheckpoint(f.session, { name: 'execute_command', arguments: { cwd: f.root, command: 'sleep 1' } });
  f.write('notes.txt', 'external editor\n'); f.write('a.txt', 'changed\n');
  await recordMutation(f.session, start);
  const count = f.commands.length;
  const result = await rollbackWorkspace(f.session);
  assert.equal(result.success, false); assert.match(result.error, /disabled/);
  assert.equal(f.commands.length, count, 'refusal runs no restoration command');
  assert.equal(fs.readFileSync(path.join(f.root, 'notes.txt'), 'utf8'), 'external editor\n');
  assert.equal(fs.readFileSync(path.join(f.root, 'a.txt'), 'utf8'), 'changed\n');
});

test('diff, overview and checkpoints do not execute clean/process filters or fsmonitor', async () => {
  const f = fixture();
  f.git('config', 'filter.fixture.clean', 'touch filter-ran; cat');
  f.git('config', 'filter.fixture.process', 'touch process-ran; exit 1');
  f.git('config', 'core.fsmonitor', 'touch monitor-ran');
  f.write('.gitattributes', '*.txt filter=fixture\n'); f.write('a.txt', 'after\n');
  const diff = await repoDiff(f.shell, { scope: 'uncommitted' }); assert.ok(!diff.error, diff.error);
  assert.match(diff.diff, /after/);
  const overview = await repoOverview(f.shell); assert.ok(!overview.error, overview.error);
  const start = await ensureCheckpoint(f.session, { name: 'edit_file', arguments: { path: 'a.txt' } });
  assert.ok(start?.tree); await recordMutation(f.session, start);
  for (const marker of ['filter-ran', 'process-ran', 'monitor-ran']) assert.equal(fs.existsSync(path.join(f.root, marker)), false, marker);
});

test('snapshot preserves tracked ignored files and treats symlinks as bytes', async () => {
  const f = fixture(); f.write('.gitignore', 'a.txt\n');
  fs.symlinkSync('/outside/dummy', path.join(f.root, 'link'));
  const start = await ensureCheckpoint(f.session, { name: 'edit_file', arguments: { path: 'a.txt' } });
  f.write('a.txt', 'after\n'); await recordMutation(f.session, start);
  assert.deepEqual(changedPaths(f.session), ['a.txt']);
  const diff = await repoDiff(f.shell, { scope: 'uncommitted' });
  assert.match(diff.diff, /after/); assert.match(diff.diff, /outside\/dummy/);
});

test('known slow directories skip subsequent snapshots before shell execution', async () => {
  const f = fixture();
  const start = await ensureCheckpoint(f.session, { name: 'edit_file', arguments: { path: 'a.txt' } });
  await recordMutation(f.session, start);
  f.session.checkpoints.repositories.get(start.root).tooSlow = true;
  const count = f.commands.length;
  assert.equal(await ensureCheckpoint(f.session, { name: 'edit_file', arguments: { path: 'a.txt' } }), null);
  assert.equal(f.commands.length, count);
  assert.equal(f.session.checkpoints.untracked.at(-1).reason, 'repository_too_slow');
});
