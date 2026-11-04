'use strict';

const assert = require('node:assert/strict');
const { execFileSync, spawn, spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { after, afterEach, test } = require('node:test');

const { CLIExecutor } = require('../../../server/services/cli/executor');
const { GUEST_WORKSPACE_DIR } = require('../../../server/services/runtime/guest_paths');
const { compactToolResult } = require('../../../server/services/ai/toolResult');
const { parseTestOutput, readTestReport } = require('../../../server/services/ai/test_output');
const { applyTextEdits } = require('../../../server/services/workspace/text_edits');
const { searchWorkspace } = require('../../../server/services/workspace/code_search');
const { repoOverview } = require('../../../server/services/workspace/repo_inspect');
const { repoDiff } = require('../../../server/services/workspace/repo_diff');
const { runProjectTests } = require('../../../server/services/workspace/run_tests');
const { createWorkspaceShell } = require('../../../server/services/workspace/workspace_shell');
const { ensureCheckpoint, recordMutation } = require('../../../server/services/ai/runtime/workspace_checkpoint');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

// Real git, real grep and rg, real test runs, in throwaway directories. Commands go
// through the executor the guest agent and host companion use; only the mapping of
// the guest's workspace path onto a temp directory is the test's own.
const temps = [];
const RG_INSTALLED = spawnSync('rg', ['--version']).status === 0;
const SHELLS = [process.env.SHELL, '/bin/bash', '/bin/sh'].filter((shell, index, list) => shell && list.indexOf(shell) === index && fs.existsSync(shell));
const SYSTEM_PATH = '/usr/bin:/bin';

function tempDir(prefix = 'neoagent-coding-') {
  const dir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), prefix)));
  temps.push(dir);
  return dir;
}

after(() => {
  for (const dir of temps) fs.rmSync(dir, { recursive: true, force: true });
});

function write(root, file, content) {
  fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
  fs.writeFileSync(path.join(root, file), content);
}

function git(root, ...args) {
  return execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
}

function initRepo(root) {
  git(root, 'init', '-q');
  git(root, 'config', 'user.name', 'Test');
  git(root, 'config', 'user.email', 'test@example.test');
}

function commitAll(root, message = 'init') {
  git(root, 'add', '-A');
  git(root, 'commit', '-qm', message);
}

// NODE_TEST_CONTEXT would make a nested runner report in its parent's binary format.
function createComputer(root, { shellPath, env = {} } = {}) {
  const executor = new CLIExecutor();
  if (shellPath) executor.defaultShell = shellPath;
  return {
    commands: [],
    executeCliCommand(_userId, command, options = {}) {
      this.commands.push(command);
      return executor.execute(command, {
        cwd: options.cwd === GUEST_WORKSPACE_DIR ? root : options.cwd,
        timeout: options.timeout,
        signal: options.signal,
        env: { NODE_TEST_CONTEXT: undefined, ...env },
      });
    },
  };
}

function shellFor(root, options) {
  const computer = createComputer(root, options);
  return { computer, shell: { run: (script, opts = {}) => computer.executeCliCommand(1, script, { cwd: GUEST_WORKSPACE_DIR, timeout: opts.timeout || 60_000 }) } };
}

function nodeTestProject(root = tempDir()) {
  write(root, 'package.json', JSON.stringify({ name: 'p', version: '1.0.0', scripts: { test: 'node --test' } }));
  write(root, 'a.test.js', `
const assert = require('node:assert/strict');
const { describe, test } = require('node:test');
test('adds', () => assert.equal(1 + 1, 2));
describe('auth', () => {
  test('rejects expired token', () => assert.equal(401, 500));
  test('accepts fresh token', () => assert.equal(200, 200));
});
`);
  return root;
}

function realRun(root, command) {
  const { NODE_TEST_CONTEXT, ...env } = process.env;
  const run = spawnSync('/bin/sh', ['-c', command], { cwd: root, encoding: 'utf8', env, timeout: 60_000 });
  return { command, stdout: run.stdout, stderr: run.stderr };
}

// ---- parseTestOutput against real runners ----

for (const [label, command] of [
  ['spec', 'node --test --test-reporter=spec'],
  ['TAP', 'node --test --test-reporter=tap'],
  ['npm test, default reporter', 'npm test'],
  ['npm test, spec', 'npm test -- --test-reporter=spec'],
]) {
  test(`a real node:test run through ${label} reads as counts and the failing test`, () => {
    const parsed = parseTestOutput(realRun(nodeTestProject(), command));
    assert.equal(parsed.runner, 'node:test');
    assert.equal(parsed.passed, 2);
    assert.equal(parsed.failed, 1);
    assert.equal(parsed.summary, '1 failed, 2 passed');
    // The test that broke, not the suite around it.
    assert.equal(parsed.failures.length, 1);
    assert.equal(parsed.failures[0].test, 'rejects expired token');
    assert.match(parsed.failures[0].file, /a\.test\.js$/);
    assert.match(parsed.failures[0].message, /401 !== 500/);
  });
}

test('the 0/0 report: a real run that counts nothing is no result at all', () => {
  const empty = tempDir();
  write(empty, 'package.json', JSON.stringify({ name: 'p', version: '1.0.0', scripts: { test: 'node --test' } }));
  for (const command of ['node --test', 'node --test --test-reporter=spec', 'npm test']) {
    const run = realRun(empty, command);
    assert.match(`${run.stdout}`, /(?:#|ℹ) pass 0/, 'this is the output that used to read as passed 0, failed 0');
    assert.equal(parseTestOutput(run), null, command);
  }

  const skipped = tempDir();
  write(skipped, 'a.test.js', `require('node:test').test('later', { skip: true }, () => {});`);
  assert.equal(parseTestOutput(realRun(skipped, 'node --test')), null, 'every test skipped');
});

test('no-count output from other runners is no result either', () => {
  for (const [command, stdout] of [
    ['npm test', 'Tests passed\n'],
    ['npm test', 'Tests: all good\n'],
    ['npx jest', 'Tests:       0 total\n'],
    ['npx vitest run', '      Tests  no tests\n'],
    ['pytest -q', '===== no tests ran in 0.01s =====\n'],
    ['cargo test', 'test result: ok. 0 passed; 0 failed; 0 ignored\n'],
    ['bundle exec rspec', '0 examples, 0 failures\n'],
    ['npx mocha', '  0 passing (1ms)\n'],
    ['npm test', 'TAP version 13\nok 1 - adds\n'],
    ['npm test', 'ok then\n--- a/file.js\n+++ b/file.js\nFAIL something\n'],
  ]) {
    assert.equal(parseTestOutput({ command, stdout }), null, stdout);
  }
});

test('a real run whose tests were only cancelled is failed, not 0/0', () => {
  const root = tempDir();
  write(root, 'a.test.js', `
const { describe, before, test } = require('node:test');
describe('needs setup', () => {
  before(() => { throw new Error('database did not start'); });
  test('one', () => {});
  test('two', () => {});
});
test('hangs', { timeout: 20 }, () => new Promise(() => {}));
`);
  for (const command of ['node --test --test-reporter=tap', 'node --test --test-reporter=spec']) {
    const parsed = parseTestOutput(realRun(root, command));
    assert.equal(parsed.passed, 0, command);
    assert.ok(parsed.failed >= 2, `${command}: ${parsed.summary}`);
    assert.ok(parsed.failures.length > 0, command);
  }
});

test('a real chain of runs adds up, so a later failure is not hidden by the first summary', () => {
  const root = tempDir();
  write(root, 'empty/keep.txt', '');
  write(root, 'good/a.test.js', `require('node:test').test('fine', () => {});`);
  write(root, 'bad/b.test.js', `require('node:test').test('broken', () => { throw new Error('nope'); });`);
  for (const reporter of ['tap', 'spec']) {
    const command = `(cd empty && node --test --test-reporter=${reporter}); (cd good && node --test --test-reporter=${reporter}); cd bad && node --test --test-reporter=${reporter}`;
    const parsed = parseTestOutput({ ...realRun(root, command), command: 'npm test' });
    assert.equal(parsed.summary, '1 failed, 1 passed', reporter);
    assert.deepEqual(parsed.failures.map((failure) => failure.test), ['broken'], reporter);
  }
  const cargo = parseTestOutput({ command: 'cargo test', stdout: 'test result: ok. 0 passed; 0 failed; 0 ignored\ntest b ... FAILED\ntest result: FAILED. 3 passed; 1 failed; 0 ignored\n' });
  assert.equal(cargo.summary, '1 failed, 3 passed');
});

test('failing tests are capped, with the count of what was left out', () => {
  const report = readTestReport({
    stdout: `${Array.from({ length: 30 }, (_, i) => `not ok ${i + 1} - t${i}\n  ---\n  error: 'boom'\n  ...`).join('\n')}\n# pass 1\n# fail 30\n`,
  });
  assert.equal(report.failures.length, 20);
  assert.equal(report.failures_omitted, 10);
});

// ---- edit_file semantics ----

test('edits apply all or nothing, and report every problem at once', () => {
  const content = 'one\ntwo\nthree\nsame\nsame\n';
  const outcome = applyTextEdits(content, [
    { oldText: 'one', newText: 'ONE' },
    { oldText: 'missing', newText: 'x' },
    { oldText: 'same', newText: 'y' },
  ]);
  assert.equal(outcome.modified, false);
  assert.equal(outcome.content, content);
  assert.deepEqual(outcome.report.map((entry) => entry.success), [false, false, false]);
  assert.match(outcome.report[0].note, /not written/);
  assert.match(outcome.report[1].error, /not found/);
  assert.match(outcome.report[2].error, /matches 2 locations/);
  assert.deepEqual(outcome.report[2].locations, ['4: same', '5: same']);
});

test('a failed match shows the nearby lines to correct the text from', () => {
  const content = 'function add(a, b) {\n    return a + b;\n}\n\nfunction sub(a, b) {\n    return a - b;\n}\n';
  const indent = applyTextEdits(content, [{ oldText: 'function add(a, b) {\n  return a + b;', newText: 'x' }]);
  assert.match(indent.report[0].error, /not found/);
  assert.ok(indent.report[0].nearby_lines.includes('2:     return a + b;'));

  const similar = applyTextEdits(content, [{ oldText: 'function sub(x, y)', newText: 'x' }]);
  assert.ok(similar.report[0].nearby_lines.some((line) => line.startsWith('5: function sub')));

  const unrelated = applyTextEdits(content, [{ oldText: '@@@', newText: 'x' }]);
  assert.equal(unrelated.report[0].nearby_lines, undefined);
  const long = applyTextEdits(`${'q'.repeat(5000)}\nmarker\n`, [{ oldText: 'marker two', newText: 'x' }]);
  assert.ok(JSON.stringify(long.report).length < 600, 'a long line next to the match stays bounded');
});

test('later edits see earlier ones, and CRLF files keep their line endings', () => {
  const chained = applyTextEdits('a\n', [{ oldText: 'a', newText: 'b' }, { oldText: 'b', newText: 'c' }]);
  assert.equal(chained.content, 'c\n');
  assert.equal(chained.report[1].line, 1);

  const crlf = applyTextEdits('one\r\ntwo\r\nthree\r\n', [{ oldText: 'one\ntwo', newText: 'ONE\nTWO' }]);
  assert.equal(crlf.content, 'ONE\r\nTWO\r\nthree\r\n');
});

test('an edit with no newText or nothing to change is refused rather than guessed at', () => {
  assert.match(applyTextEdits('a\n', [{ oldText: 'a' }]).report[0].error, /newText is required/);
  assert.equal(applyTextEdits('a\n', [{ oldText: 'a', newText: '' }]).content, '\n');
  assert.match(applyTextEdits('a\n', [{ oldText: 'a', newText: 'a' }]).report[0].error, /same/);
  assert.match(applyTextEdits('a\n', []).report[0].error, /at least one/);
});

// ---- atomic writes ----

function pinnedWorkspace(root) {
  const { WorkspaceManager } = require('../../../server/services/workspace/manager');
  return new WorkspaceManager({ rootDir: root, pinned: true });
}

function leftovers(root) {
  return fs.readdirSync(root).filter((name) => name.endsWith('.tmp'));
}

test('writes keep the file mode, follow symlinks, and leave no temp file', () => {
  const root = tempDir();
  const workspace = pinnedWorkspace(root);
  write(root, 'run.sh', '#!/bin/sh\n');
  fs.chmodSync(path.join(root, 'run.sh'), 0o750);

  assert.equal(workspace.writeFile(1, { path: 'run.sh', content: '#!/bin/sh\necho hi\n' }).success, true);
  assert.equal(fs.statSync(path.join(root, 'run.sh')).mode & 0o777, 0o750);
  assert.equal(workspace.editFile(1, { path: 'run.sh', edits: [{ oldText: 'hi', newText: 'bye' }] }).success, true);
  assert.equal(fs.statSync(path.join(root, 'run.sh')).mode & 0o777, 0o750);
  assert.equal(workspace.replaceFileRange(1, { path: 'run.sh', start_line: 2, end_line: 2, content: 'echo range' }).success, true);
  assert.equal(fs.statSync(path.join(root, 'run.sh')).mode & 0o777, 0o750);
  assert.equal(fs.readFileSync(path.join(root, 'run.sh'), 'utf8'), '#!/bin/sh\necho range\n');

  write(root, 'real.txt', 'real\n');
  fs.symlinkSync('real.txt', path.join(root, 'link.txt'));
  workspace.writeFile(1, { path: 'link.txt', content: 'through the link\n' });
  assert.equal(fs.lstatSync(path.join(root, 'link.txt')).isSymbolicLink(), true);
  assert.equal(fs.readFileSync(path.join(root, 'real.txt'), 'utf8'), 'through the link\n');

  workspace.writeFile(1, { path: 'log.txt', content: 'one\n' });
  workspace.writeFile(1, { path: 'log.txt', content: 'two\n', mode: 'append' });
  assert.equal(fs.readFileSync(path.join(root, 'log.txt'), 'utf8'), 'one\ntwo\n');
  assert.deepEqual(leftovers(root), []);
});

test('a dangling symlink is replaced, not followed out of the workspace', () => {
  const root = tempDir();
  const outside = path.join(tempDir(), 'secret.txt');
  fs.symlinkSync(outside, path.join(root, 'dangling.txt'));
  const result = pinnedWorkspace(root).writeFile(1, { path: 'dangling.txt', content: 'x' });
  assert.equal(result.success, true);
  assert.equal(fs.existsSync(outside), false);
  assert.equal(fs.lstatSync(path.join(root, 'dangling.txt')).isSymbolicLink(), false);
});

test('a write that cannot finish leaves the old file whole and no temp file', { skip: process.getuid?.() === 0 }, () => {
  const root = tempDir();
  const workspace = pinnedWorkspace(root);
  write(root, 'locked/a.txt', 'old\n');
  fs.chmodSync(path.join(root, 'locked'), 0o555);
  try {
    const result = workspace.writeFile(1, { path: 'locked/a.txt', content: 'new\n' });
    assert.equal(result.success, false);
    assert.equal(fs.readFileSync(path.join(root, 'locked/a.txt'), 'utf8'), 'old\n');
    assert.deepEqual(leftovers(path.join(root, 'locked')), []);
  } finally {
    fs.chmodSync(path.join(root, 'locked'), 0o755);
  }

  write(root, 'readonly.txt', 'old\n');
  fs.chmodSync(path.join(root, 'readonly.txt'), 0o444);
  assert.equal(workspace.writeFile(1, { path: 'readonly.txt', content: 'new\n' }).success, false);
  assert.equal(fs.readFileSync(path.join(root, 'readonly.txt'), 'utf8'), 'old\n');
});

test('a process killed in the middle of writing never leaves a partial file', async () => {
  const root = tempDir();
  const size = 32 * 1024 * 1024;
  const script = `
    const { WorkspaceManager } = require(${JSON.stringify(path.resolve(__dirname, '../../../server/services/workspace/manager'))});
    const workspace = new WorkspaceManager({ rootDir: ${JSON.stringify(root)}, pinned: true });
    let letter = 'a';
    process.stdout.write('ready\\n');
    for (;;) {
      workspace.writeFile(1, { path: 'big.txt', content: letter.repeat(${size}) });
      letter = letter === 'a' ? 'b' : 'a';
    }
  `;
  write(root, 'big.txt', 'a'.repeat(size));
  const child = spawn(process.execPath, ['-e', script], {
    stdio: ['ignore', 'pipe', 'inherit'],
    env: { ...process.env, NEOAGENT_HOME: tempDir(), NODE_TEST_CONTEXT: undefined },
  });
  await new Promise((resolve) => child.stdout.once('data', resolve));
  await new Promise((resolve) => setTimeout(resolve, 150));
  child.kill('SIGKILL');
  await new Promise((resolve) => child.once('close', resolve));

  const body = fs.readFileSync(path.join(root, 'big.txt'), 'latin1');
  assert.equal(body.length, size);
  assert.ok(body === body[0].repeat(size), 'the file is one complete write');
});

// ---- search_files ----

function searchFixture() {
  const root = tempDir();
  initRepo(root);
  write(root, '.gitignore', 'ignored.js\n');
  write(root, 'src/auth.js', 'const a = 1;\nfunction validateSession(token) {\n  return token;\n}\n// validateSession note\n');
  write(root, 'src/deep/util.ts', 'export const validateSession = true;\n');
  write(root, 'test/auth.test.js', "validateSession('x');\n");
  write(root, '.github/workflow.yml', 'run: validateSession\n');
  write(root, 'ignored.js', 'validateSession\n');
  write(root, 'node_modules/dep/index.js', 'validateSession\n');
  write(root, '.env', 'API_KEY=validateSession\n');
  write(root, 'image.bin', Buffer.from([0, 1, 2, 0x76, 0x61, 0x6c, 0]));
  return root;
}

const ENGINES = [
  ...(RG_INSTALLED ? [['rg', {}]] : []),
  ['grep', { env: { PATH: SYSTEM_PATH } }],
];

for (const [engine, engineOptions] of ENGINES) {
  for (const shellPath of SHELLS) {
    test(`search_files through ${engine} in ${path.basename(shellPath)}: grouped, numbered, context, globs`, async (t) => {
      const root = searchFixture();
      const { shell } = shellFor(root, { ...engineOptions, shellPath });
      const found = await searchWorkspace(shell, { query: 'validateSession' });
      if (found.engine !== engine) return t.skip(`this login shell provides ${found.engine}`);

      const files = found.matches.filter((match) => match.file).map((match) => match.file).sort();
      assert.ok(files.includes('src/auth.js'));
      assert.ok(files.includes('src/deep/util.ts'));
      assert.ok(files.includes('.github/workflow.yml'), 'hidden directories are code too');
      assert.ok(!files.includes('node_modules/dep/index.js'));
      assert.ok(!files.includes('.env'), 'secrets stay out');
      assert.ok(!files.includes('image.bin'));
      if (engine === 'rg') assert.ok(!files.includes('ignored.js'), 'rg honors .gitignore');

      const first = found.matches.findIndex((match) => match.file === 'src/auth.js');
      assert.deepEqual(found.matches[first], { file: 'src/auth.js', line: 2, content: 'function validateSession(token) {' });
      assert.deepEqual(found.matches[first + 1], { line: 5, content: '// validateSession note' }, 'the name is not repeated within a file');

      const withContext = await searchWorkspace(shell, { query: 'validateSession', path: 'src/auth.js', context: 1 });
      assert.deepEqual(withContext.matches.map((match) => match.line), ['1-', 2, '3-', '4-', 5]);
      assert.equal(withContext.matches[0].file, 'src/auth.js');
      assert.equal(withContext.count, 2);

      const typed = await searchWorkspace(shell, { query: 'validateSession', include: '*.ts' });
      assert.deepEqual(typed.matches.map((match) => match.file), ['src/deep/util.ts']);
      const scoped = await searchWorkspace(shell, { query: 'validateSession', include: 'src/**/*.{ts,tsx}' });
      assert.deepEqual(scoped.matches.map((match) => match.file), ['src/deep/util.ts']);
      const shallow = await searchWorkspace(shell, { query: 'validateSession', path: 'src', maxDepth: 1 });
      assert.deepEqual(shallow.matches.filter((match) => match.file).map((match) => match.file), ['src/auth.js']);
    });
  }

  test(`search_files through ${engine}: literal by default, regex on request, hostile queries stay data`, async (t) => {
    const root = tempDir();
    write(root, 'a.js', 'call(x);\nfoo|bar\nFooBar\n--flag\nit\'s; touch pwned\n');
    const { shell } = shellFor(root, engineOptions);

    const literal = await searchWorkspace(shell, { query: 'call(x)' });
    if (literal.engine !== engine) return t.skip(`this login shell provides ${literal.engine}`);
    assert.equal(literal.count, 1);
    assert.equal((await searchWorkspace(shell, { query: 'call(' })).count, 1, 'not a broken pattern');

    assert.equal((await searchWorkspace(shell, { query: 'foo|baz' })).count, 0);
    assert.match((await searchWorkspace(shell, { query: 'foo|baz' })).note, /regex/);
    assert.equal((await searchWorkspace(shell, { query: 'call|FooBar', regex: true, case_sensitive: true })).count, 2);

    assert.equal((await searchWorkspace(shell, { query: 'foobar' })).count, 1, 'lower case ignores case');
    assert.equal((await searchWorkspace(shell, { query: 'Foobar' })).count, 0, 'a capital means it');

    assert.equal((await searchWorkspace(shell, { query: '--flag' })).count, 1);
    assert.equal((await searchWorkspace(shell, { query: "it's; touch pwned" })).count, 1);
    await searchWorkspace(shell, { query: 'x', include: "';touch pwned;'" });
    await searchWorkspace(shell, { query: 'x', path: "$(touch pwned)" });
    assert.equal(fs.existsSync(path.join(root, 'pwned')), false);

    const invalid = await searchWorkspace(shell, { query: '(', regex: true });
    assert.ok(invalid.error, 'a broken pattern is an error, not "no matches"');
    assert.equal((await searchWorkspace(shell, { query: 'a\nb' })).error, 'query must be a single line.');
  });

  test(`search_files through ${engine}: output is bounded`, async (t) => {
    const root = tempDir();
    for (let file = 0; file < 30; file += 1) {
      write(root, `f${String(file).padStart(2, '0')}.txt`, 'needle\n'.repeat(40));
    }
    write(root, 'minified.js', `needle${'x'.repeat(200_000)}\n`);
    const { shell } = shellFor(root, engineOptions);
    const found = await searchWorkspace(shell, { query: 'needle' });
    if (found.engine !== engine) return t.skip(`this login shell provides ${found.engine}`);
    assert.equal(found.truncated, true);
    assert.equal(found.matches.filter((match) => typeof match.line === 'number').length, 50);
    assert.ok(found.matches.every((match) => match.content.length <= 160));
    assert.ok(JSON.stringify(found).length < 6000, `${JSON.stringify(found).length} chars`);
    // No file crowds out the rest.
    assert.ok(new Set(found.matches.map((match) => match.file).filter(Boolean)).size >= 3);

    const oneFile = await searchWorkspace(shell, { query: 'needle', path: 'f00.txt', max_results: 40 });
    assert.equal(oneFile.count, 40);
    assert.equal(oneFile.truncated, false);
  });

  test(`search_files through ${engine}: never leaves the workspace`, async () => {
    const parent = tempDir();
    const root = path.join(parent, 'workspace');
    write(root, 'inside.txt', 'needle\n');
    write(parent, 'outside/secret.txt', 'needle\n');
    fs.symlinkSync(path.join(parent, 'outside'), path.join(root, 'dirlink'));
    fs.symlinkSync(path.join(parent, 'outside/secret.txt'), path.join(root, 'filelink.txt'));
    const { shell } = shellFor(root, engineOptions);

    assert.match((await searchWorkspace(shell, { query: 'needle', path: '..' })).error, /outside the workspace/);
    assert.match((await searchWorkspace(shell, { query: 'needle', path: '../outside/secret.txt' })).error, /outside the workspace/);
    assert.match((await searchWorkspace(shell, { query: 'needle', path: path.join(parent, 'outside') })).error, /outside the workspace/);
    assert.match((await searchWorkspace(shell, { query: 'needle', path: 'dirlink' })).error, /outside the workspace/);
    assert.ok((await searchWorkspace(shell, { query: 'needle', path: 'filelink.txt' })).error);
    assert.match((await searchWorkspace(shell, { query: 'needle', path: 'nope' })).error, /does not exist/);

    const all = await searchWorkspace(shell, { query: 'needle' });
    assert.deepEqual(all.matches.map((match) => match.file), ['inside.txt'], 'links in the tree are not followed');
  });
}

test('grouped search results survive compactToolResult as they are', async () => {
  const root = searchFixture();
  const { shell } = shellFor(root);
  const found = await searchWorkspace(shell, { query: 'validateSession', path: 'src', context: 1 });
  const compact = JSON.parse(compactToolResult('search_files', { query: 'validateSession' }, found, { softLimit: 24000, hardLimit: 48000 }));
  assert.deepEqual(compact.matches, found.matches);
  assert.equal(compact.count, found.count);
});

// ---- repo_overview ----

test('repo_overview describes a repository compactly', async () => {
  const root = nodeTestProject();
  initRepo(root);
  write(root, 'README.md', '# hi\n');
  write(root, 'server/a.js', 'a\n');
  write(root, 'server/b.js', 'b\n');
  write(root, 'scripts/c.py', 'c\n');
  commitAll(root, 'first commit');
  write(root, 'README.md', '# changed\n');
  write(root, 'new.txt', 'new\n');
  const before = git(root, 'status', '--porcelain');

  for (const shellPath of SHELLS) {
    const { shell } = shellFor(root, { shellPath });
    const overview = await repoOverview(shell, {});
    assert.equal(overview.git.toplevel, root, shellPath);
    assert.match(overview.git.head, /first commit/);
    assert.equal(overview.git.dirty, 2);
    assert.deepEqual(overview.git.dirty_files.sort(), [' M README.md', '?? new.txt']);
    assert.ok(overview.layout.includes('server/ (2)'), JSON.stringify(overview.layout));
    assert.ok(overview.languages.includes('js: 3'), JSON.stringify(overview.languages));
    assert.deepEqual(overview.manifests, ['package.json']);
    assert.deepEqual(overview.docs, ['README.md']);
    assert.equal(overview.test.command, 'npm test');
    assert.equal(overview.scripts.test, 'node --test');
  }
  assert.equal(git(root, 'status', '--porcelain'), before);
});

test('repo_overview stays bounded on a large, very dirty repository', async () => {
  const root = tempDir();
  initRepo(root);
  for (let index = 0; index < 300; index += 1) write(root, `file-${index}.txt`, 'x\n');
  const { shell } = shellFor(root);
  const overview = await repoOverview(shell, {});
  assert.equal(overview.git.dirty, 300);
  assert.equal(overview.git.dirty_files.length, 20);
  assert.equal(overview.git.dirty_files_omitted, 280);
  assert.ok(JSON.stringify(overview).length < 3000, `${JSON.stringify(overview).length} chars`);
});

test('repo_overview outside a repository points at the repositories inside', async () => {
  const root = tempDir();
  write(root, 'notes.md', 'x\n');
  write(root, 'node_modules/x.js', 'x\n');
  initRepo(path.join(root, (fs.mkdirSync(path.join(root, 'proj')), 'proj')));
  const { shell } = shellFor(root);
  const overview = await repoOverview(shell, {});
  assert.equal(overview.git, null);
  assert.deepEqual(overview.repos, ['proj/']);
  assert.deepEqual(overview.languages, ['md: 1']);
  assert.match(overview.test, /not detected/);
  assert.match((await repoOverview(shell, { path: '..' })).error, /outside/);
});

test('the test command is detected from what the project has', async () => {
  const cases = [
    [{ 'package.json': '{"scripts":{"test":"jest"}}' }, 'npm test'],
    [{ 'package.json': '{"scripts":{"test":"jest"}}', 'pnpm-lock.yaml': '' }, 'pnpm test'],
    [{ 'package.json': '{"scripts":{"test":"jest"}}', 'yarn.lock': '' }, 'yarn test'],
    [{ 'package.json': '{"scripts":{"test":"bun test"}}', 'bun.lock': '' }, 'bun run test'],
    [{ 'package.json': '{"scripts":{"test":"echo \\"Error: no test specified\\" && exit 1"}}' }, null],
    [{ 'package.json': '{"scripts":{}}', 'test/a.test.js': '' }, 'node --test'],
    [{ Makefile: 'build:\n\tcc\ntest: build\n\t./t\n', 'go.mod': 'module x\n' }, 'make test'],
    [{ 'go.mod': 'module x\n' }, 'go test ./...'],
    [{ 'Cargo.toml': '[package]\n' }, 'cargo test'],
    [{ 'pubspec.yaml': 'dependencies:\n  flutter:\n    sdk: flutter\n' }, 'flutter test'],
    [{ 'pubspec.yaml': 'name: x\n' }, 'dart test'],
    [{ 'pyproject.toml': '[tool.pytest.ini_options]\n' }, 'python3 -m pytest'],
    [{ 'requirements.txt': '', 'tests/test_a.py': '' }, 'python3 -m pytest'],
    [{ Gemfile: '', 'spec/a_spec.rb': '' }, 'bundle exec rspec'],
    [{ gradlew: '', 'build.gradle': '' }, './gradlew test'],
    [{ 'pom.xml': '' }, 'mvn test'],
    [{ 'notes.txt': '' }, null],
  ];
  for (const [files, expected] of cases) {
    const root = tempDir();
    for (const [name, content] of Object.entries(files)) write(root, name, content);
    const { shell } = shellFor(root);
    const { test: detected } = await repoOverview(shell, {});
    assert.equal(typeof detected === 'string' ? null : detected.command, expected, JSON.stringify(files));
  }
});

// ---- repo_diff ----

function diffFixture() {
  const root = tempDir();
  initRepo(root);
  write(root, 'a.js', 'one\ntwo\nthree\n');
  write(root, 'b.js', 'bee\n');
  write(root, 'gone.js', 'bye\n');
  commitAll(root);
  return root;
}

function gitState(root) {
  return {
    status: git(root, 'status', '--porcelain'),
    head: git(root, 'rev-parse', 'HEAD'),
    refs: git(root, 'for-each-ref'),
    staged: git(root, 'diff', '--cached', '--name-only'),
    index: fs.readFileSync(path.join(root, '.git/index')).toString('base64'),
  };
}

test('repo_diff shows everything uncommitted, new files included, and changes nothing', async () => {
  const root = diffFixture();
  write(root, 'a.js', 'one\nTWO\nthree\n');
  fs.rmSync(path.join(root, 'gone.js'));
  write(root, 'new.js', 'fresh\n');
  write(root, 'staged.js', 'staged\n');
  git(root, 'add', 'staged.js');
  const before = gitState(root);

  for (const shellPath of SHELLS) {
    const { shell } = shellFor(root, { shellPath });
    const diff = await repoDiff(shell, {});
    assert.equal(diff.scope, 'uncommitted');
    assert.deepEqual(diff.files, ['M a.js +1 -1', 'D gone.js +0 -1', 'A new.js +1 -0', 'A staged.js +1 -0'], shellPath);
    assert.match(diff.diff, /=== M a\.js \+1 -1\n@@ .* @@\n one\n-two\n\+TWO\n three/);
    assert.match(diff.diff, /=== A new\.js \+1 -0\n@@ .* @@\n\+fresh/);
    assert.doesNotMatch(diff.diff, /^index |^diff --git|^--- |^\+\+\+ /m);
    assert.equal(diff.truncated, false);
  }
  assert.deepEqual(gitState(root), before);
});

test('repo_diff does not call a tracked file that is also ignored deleted', async () => {
  const root = diffFixture();
  write(root, 'public/app.js', 'built\n');
  git(root, 'add', '-f', 'public/app.js');
  write(root, '.gitignore', 'public/\n');
  commitAll(root, 'tracked build output');
  write(root, 'a.js', 'one\nTWO\nthree\n');
  const diff = await repoDiff(shellFor(root).shell, {});
  assert.deepEqual(diff.files, ['M a.js +1 -1']);
});

test('repo_diff sees a same-size edit made right after a commit', async () => {
  const root = tempDir();
  initRepo(root);
  const { shell } = shellFor(root);
  for (let round = 0; round < 12; round += 1) {
    write(root, 'a.js', `round ${String(round).padStart(2, '0')} before\n`);
    commitAll(root, `round ${round}`);
    write(root, 'a.js', `round ${String(round).padStart(2, '0')} AFTER_\n`);
    assert.deepEqual((await repoDiff(shell, {})).files, ['M a.js +1 -1'], `round ${round}`);
  }
});

test('repo_diff reports a clean tree, a missing repository, and a repository with no commits', async () => {
  const root = diffFixture();
  const { shell } = shellFor(root);
  const clean = await repoDiff(shell, {});
  assert.deepEqual(clean.files, []);
  assert.equal(clean.diff, '');
  assert.equal(clean.note, 'No changes.');

  const plain = tempDir();
  assert.match((await repoDiff(shellFor(plain).shell, {})).error, /not a git repository/);
  assert.match((await repoDiff(shell, { path: '..' })).error, /outside/);

  const fresh = tempDir();
  initRepo(fresh);
  write(fresh, 'first.js', 'x\n');
  const unborn = await repoDiff(shellFor(fresh).shell, {});
  assert.deepEqual(unborn.files, ['A first.js +1 -0']);
});

test('repo_diff compares with where a ref branched off', async () => {
  const root = diffFixture();
  const main = git(root, 'symbolic-ref', '--short', 'HEAD');
  git(root, 'checkout', '-qb', 'feature');
  write(root, 'a.js', 'committed on the branch\n');
  commitAll(root, 'branch work');
  git(root, 'checkout', '-q', main);
  write(root, 'b.js', 'moved on\n');
  commitAll(root, 'main moved');
  git(root, 'checkout', '-q', 'feature');
  write(root, 'c.js', 'uncommitted\n');

  const { shell } = shellFor(root);
  const diff = await repoDiff(shell, { base: main });
  assert.equal(diff.scope, 'base');
  assert.deepEqual(diff.files, ['M a.js +1 -3', 'A c.js +1 -0']);
  assert.match((await repoDiff(shell, { base: 'no-such-ref' })).error, /not a commit/);
  assert.match((await repoDiff(shell, { base: '--output=/tmp/x' })).error, /git ref/);
});

test('repo_diff stays bounded and shares the room, so one huge file cannot hide the rest', async () => {
  const root = diffFixture();
  write(root, 'a.js', 'one\nTWO\nthree\n');
  write(root, 'generated.json', `${Array.from({ length: 20000 }, (_, i) => `line ${i}`).join('\n')}\n`);
  write(root, 'pic.png', Buffer.from([0, 1, 2, 3, 0, 255]));
  const { shell } = shellFor(root);

  const diff = await repoDiff(shell, {});
  assert.ok(diff.diff.length < 12_500, `${diff.diff.length} chars`);
  assert.equal(diff.truncated, true);
  assert.match(diff.diff, /\+TWO/, 'the small change is shown whole');
  assert.match(diff.diff, /\[cut: pass paths: \["generated\.json"\]/);
  assert.ok(diff.files.includes('A pic.png binary'));
  assert.ok(!diff.diff.includes('@@ pic'));

  const focused = await repoDiff(shell, { paths: ['a.js'] });
  assert.deepEqual(focused.files, ['M a.js +1 -1']);
  assert.equal(focused.truncated, false);

  const larger = await repoDiff(shell, { paths: ['generated.json'], max_chars: 25_000 });
  assert.ok(larger.diff.length > 20_000 && larger.diff.length < 26_000, `${larger.diff.length}`);
  const capped = await repoDiff(shell, { paths: ['generated.json'], max_chars: 10_000_000 });
  assert.ok(capped.diff.length < 31_000);
});

test('repo_diff stays bounded with very many changed files', async () => {
  const root = tempDir();
  initRepo(root);
  write(root, 'keep', 'x\n');
  commitAll(root);
  for (let index = 0; index < 150; index += 1) write(root, `f${index}.txt`, `content ${index}\n`);
  const { shell } = shellFor(root);
  const diff = await repoDiff(shell, {});
  assert.equal(diff.files.length, 100);
  assert.equal(diff.truncated, true);
  assert.ok(JSON.stringify(diff).length < 16_000, `${JSON.stringify(diff).length} chars`);
});

function checkpointSession(root) {
  const computer = createComputer(root);
  return {
    runId: 'run-1',
    userId: 1,
    agentId: null,
    deviceTarget: null,
    eventBus: { publish() {} },
    getActiveSignal: () => null,
    engine: { runtimeManager: computer },
    computer,
  };
}

test('with real checkpoints, repo_diff shows the run\'s work and leaves the user\'s alone', async () => {
  const root = diffFixture();
  write(root, 'b.js', 'the user was already editing this\n');
  write(root, 'notes.txt', 'the user\'s untracked notes\n');
  const session = checkpointSession(root);

  const agentEdit = async (file, content) => {
    const started = await ensureCheckpoint(session, { name: 'edit_file', arguments: { path: path.join(root, file) } });
    write(root, file, content);
    await recordMutation(session, started);
  };
  await agentEdit('a.js', 'one\nAGENT\nthree\n');
  await agentEdit('created-by-run.js', 'hello\n');
  write(root, 'b.js', 'the user kept editing\n');
  const before = gitState(root);

  const repositories = [...session.checkpoints.repositories].map(([repoRoot, repository]) => ({
    root: repoRoot,
    paths: [...repository.paths].map(([file, state]) => ({ path: file, source: state.source })),
  }));
  const { shell } = shellFor(root);
  const diff = await repoDiff(shell, {}, repositories);
  assert.equal(diff.scope, 'run');
  assert.deepEqual(diff.files, ['M a.js +1 -1', 'A created-by-run.js +1 -0']);
  assert.match(diff.diff, /\+AGENT/);
  assert.doesNotMatch(diff.diff, /user/);
  assert.equal(diff.other_uncommitted_files, 2);

  const everything = await repoDiff(shell, { scope: 'uncommitted' }, repositories);
  assert.equal(everything.scope, 'uncommitted');
  assert.ok(everything.files.some((line) => line.startsWith('M b.js')));

  assert.deepEqual((await repoDiff(shell, { paths: [path.join(root, 'a.js')] }, repositories)).files, ['M a.js +1 -1']);
  assert.deepEqual(gitState(root), before);
});

test('repo_diff follows the run into a repository outside the workspace, but will not be sent there', async () => {
  const workspace = tempDir();
  const elsewhere = diffFixture();
  const session = checkpointSession(elsewhere);
  const started = await ensureCheckpoint(session, { name: 'execute_command', arguments: { cwd: elsewhere } });
  write(elsewhere, 'a.js', 'changed by a shell command\n');
  await recordMutation(session, started);
  const repositories = [...session.checkpoints.repositories].map(([root, repository]) => ({
    root,
    paths: [...repository.paths].map(([file, state]) => ({ path: file, source: state.source })),
  }));
  const { shell } = shellFor(workspace);
  assert.deepEqual((await repoDiff(shell, {}, repositories)).files, ['M a.js +1 -3']);
  assert.match((await repoDiff(shell, { path: elsewhere })).error, /outside the workspace/);
});

test('repo_diff keeps a dropped executable bit visible', async () => {
  const root = diffFixture();
  write(root, 'run.sh', '#!/bin/sh\n');
  fs.chmodSync(path.join(root, 'run.sh'), 0o755);
  commitAll(root, 'script');
  fs.chmodSync(path.join(root, 'run.sh'), 0o644);
  const diff = await repoDiff(shellFor(root).shell, {});
  assert.deepEqual(diff.files, ['M run.sh +0 -0 mode 100755 -> 100644']);
});

// ---- run_tests ----

function memoryStore() {
  const saved = new Map();
  return {
    saved,
    async createBufferArtifact(_userId, options) {
      const artifactId = `art-${saved.size + 1}`;
      saved.set(artifactId, options.content.toString());
      return { artifactId };
    },
  };
}

test('run_tests detects the runner and returns counts and only the failures', async () => {
  const root = nodeTestProject();
  const { shell } = shellFor(root);
  const artifactStore = memoryStore();
  const result = await runProjectTests(shell, {}, { userId: 1, artifactStore });

  assert.equal(result.status, 'failed');
  assert.equal(result.command, 'npm test');
  assert.equal(result.detected_from, 'package.json');
  assert.equal(result.exitCode, 1);
  assert.equal(result.test_result.runner, 'node:test');
  assert.equal(result.test_result.summary, '1 failed, 2 passed');
  assert.equal(result.test_result.failures[0].test, 'rejects expired token');
  assert.equal(result.error, undefined, 'a failing test is a result, not a tool failure');
  assert.equal(result.stdout, undefined);
  assert.equal(result.output_tail, undefined);
  assert.ok(JSON.stringify(result).length < 1200, `${JSON.stringify(result).length} chars`);
  assert.match(artifactStore.saved.get(result.log_artifact_id), /accepts fresh token/, 'the passing tests are in the log');
});

test('run_tests reports a green run, and takes a command and a directory', async () => {
  const root = tempDir();
  write(root, 'pkg/good.test.js', `require('node:test').test('fine', () => {});`);
  write(root, 'pkg/bad.test.js', `require('node:test').test('broken', () => { throw new Error('x'); });`);
  const { shell } = shellFor(root);
  const result = await runProjectTests(shell, { command: 'node --test good.test.js', cwd: 'pkg' }, { userId: 1 });
  assert.equal(result.status, 'passed');
  assert.equal(result.cwd, 'pkg');
  assert.equal(result.test_result.summary, '0 failed, 1 passed');
  assert.deepEqual(result.test_result.failures, []);

  const custom = await runProjectTests(shell, { command: './check.sh || node --test good.test.js', cwd: 'pkg' }, { userId: 1 });
  assert.equal(custom.test_result.passed, 1, 'a command the matcher does not know is still read');
});

test('run_tests does not call a run with no counts a pass', async () => {
  const root = tempDir();
  const { shell } = shellFor(root);

  const silent = await runProjectTests(shell, { command: 'node --test' }, { userId: 1 });
  assert.equal(silent.status, 'unknown', 'found no tests');
  assert.equal(silent.test_result, undefined);
  assert.match(silent.note, /whether any test ran is unknown/);

  const crashed = await runProjectTests(shell, { command: 'echo starting; echo cannot find module >&2; exit 3' }, { userId: 1 });
  assert.equal(crashed.status, 'failed');
  assert.equal(crashed.exitCode, 3);
  assert.match(crashed.output_tail, /cannot find module/);

  write(root, 'ok.test.js', `require('node:test').test('fine', () => {});`);
  const lint = await runProjectTests(shell, { command: 'node --test ok.test.js; exit 9' }, { userId: 1 });
  assert.equal(lint.status, 'failed', 'tests passed but the command did not');
  assert.equal(lint.test_result.failed, 0);
  assert.match(lint.note, /exited 9/);

  assert.match((await runProjectTests(shell, {}, { userId: 1 })).error, /No test command/);
  assert.equal((await runProjectTests(shell, { command: 'true', cwd: '..' }, { userId: 1 })).exitCode, 0, 'approved as a shell command, so it may leave');
  assert.match((await runProjectTests(shell, { command: 'true', cwd: 'nope' }, { userId: 1 })).error, /does not exist/);
  assert.equal(fs.readdirSync(root).includes('nope'), false);
});

test('run_tests cut off by its timeout is an error and says the results are partial', async () => {
  const root = tempDir();
  const { shell } = shellFor(root);
  const result = await runProjectTests(shell, { command: 'echo partial; sleep 30', timeout: 200 }, { userId: 1 });
  assert.equal(result.status, 'interrupted');
  assert.equal(result.timedOut, true);
  assert.match(result.error, /timed out/);
  assert.match(result.output_tail, /partial/);
});

test('run_tests keeps its result bounded when the output is enormous', async () => {
  const root = tempDir();
  write(root, 'noisy.js', `
    for (let i = 0; i < 20000; i += 1) console.log('noise line ' + i);
    for (let i = 0; i < 200; i += 1) console.log('not ok ' + i + ' - t' + i + '\\n  ---\\n  error: boom' + 'y'.repeat(400) + '\\n  ...');
    for (let i = 0; i < 2000; i += 1) console.log('after ' + i);
    console.log('# pass 5\\n# fail 200');
    process.exitCode = 1;
  `);
  const { shell } = shellFor(root);
  const result = await runProjectTests(shell, { command: 'node noisy.js' }, { userId: 1, artifactStore: memoryStore() });
  assert.equal(result.test_result.failed, 200);
  assert.ok(JSON.stringify(result).length < 8000, `${JSON.stringify(result).length} chars`);
});

// ---- the tools, wired up ----

let runtime;
afterEach(() => {
  if (runtime) teardownTestRuntime(runtime);
  runtime = null;
});

test('the coding tools are registered with the traits the harness reads', () => {
  runtime = createTestRuntime();
  const { getAvailableTools } = require('../../../server/services/ai/tools');
  const { resolveToolMeta, isReadOnlyCall, isParallelSafeCall, changesState, resultBudgetFor } = require('../../../server/services/ai/tools/metadata');
  const { getCategoryForTool } = require('../../../server/services/security/tool_categories');

  const names = getAvailableTools(null, { includeDescriptions: true }).map((tool) => tool.name);
  for (const name of ['repo_overview', 'repo_diff', 'run_tests']) assert.ok(names.includes(name), name);

  for (const name of ['repo_overview', 'repo_diff']) {
    const meta = resolveToolMeta(name);
    assert.equal(isReadOnlyCall(meta, {}), true, name);
    assert.equal(isParallelSafeCall(meta, {}), true, name);
    assert.equal(changesState(meta, {}), false, name);
    assert.equal(resultBudgetFor(meta), 'file', name);
    assert.equal(getCategoryForTool(name), null, name);
    assert.deepEqual(meta.prerequisites, ['computer']);
  }

  // It runs arbitrary code, so it asks exactly as the shell does and is serialized.
  const tests = resolveToolMeta('run_tests');
  assert.equal(getCategoryForTool('run_tests', { command: 'rm -rf /' }), 'shell');
  assert.equal(isReadOnlyCall(tests, {}), false);
  assert.equal(isParallelSafeCall(tests, {}), false);
  assert.equal(changesState(tests, {}), true);
  assert.equal(resultBudgetFor(tests), 'command');
});

function runtimeServices(root, extras = {}) {
  const { WorkspaceManager } = require('../../../server/services/workspace/manager');
  const { ArtifactStore } = require('../../../server/services/artifacts/store');
  const workspaceManager = new WorkspaceManager({ rootDir: root, pinned: true });
  return {
    app: { locals: { artifactStore: new ArtifactStore(), workspaceManager, runtimeManager: createComputer(root), ...extras } },
  };
}

test('run_tests, end to end through executeTool: the log is readable with read_artifact', async () => {
  runtime = createTestRuntime();
  const user = await createTestUser(runtime.db, { username: 'run_tests_tool' });
  const { executeTool } = require('../../../server/services/ai/tools');
  const root = nodeTestProject();
  const { app } = runtimeServices(root);
  const context = { userId: user.userId, app };

  const result = await executeTool('run_tests', {}, context, {});
  assert.equal(result.test_result.summary, '1 failed, 2 passed');
  const log = await executeTool('read_artifact', { artifact_id: result.log_artifact_id }, context, {});
  assert.match(log.content, /accepts fresh token/);

  // Without a toolResult case of its own the failures still reach the model whole.
  const compact = compactToolResult('run_tests', {}, result, { softLimit: 16000, hardLimit: 32000 });
  assert.match(compact, /rejects expired token/);
  assert.match(compact, /401 !== 500/);
});

test('a long log is parsed from its artifact, so failures in the middle are not lost', async () => {
  runtime = createTestRuntime();
  const user = await createTestUser(runtime.db, { username: 'run_tests_long' });
  const { ArtifactStore } = require('../../../server/services/artifacts/store');
  const artifactStore = new ArtifactStore();
  const full = `${'noise\n'.repeat(1000)}not ok 1 - lost in the middle\n  ---\n  error: 'found it'\n  ...\n${'noise\n'.repeat(1000)}# pass 1\n# fail 1\n`;
  const stored = await artifactStore.createBufferArtifact(user.userId, {
    kind: 'command-output', backend: 'vm', extension: 'log', contentType: 'text/plain; charset=utf-8', content: Buffer.from(full),
  });
  const shell = {
    run: async (script) => (script.includes('@@neoagent') && !script.includes('fake-suite')
      ? { exitCode: 0, stdout: '' }
      : {
        exitCode: 1,
        stdout: '...[truncated preview, 12000 bytes total]\n# pass 1\n# fail 1',
        stderr: '',
        truncated: true,
        outputArtifact: { artifactId: stored.artifactId },
      }),
  };
  const result = await runProjectTests(shell, { command: 'fake-suite' }, { userId: user.userId, artifactStore });
  assert.equal(result.log_artifact_id, stored.artifactId);
  assert.equal(result.test_result.failures[0].test, 'lost in the middle');
});

test('search_files, read tools, and repo tools work through executeTool on a computer', async () => {
  runtime = createTestRuntime();
  const user = await createTestUser(runtime.db, { username: 'coding_tools_wired' });
  const { executeTool } = require('../../../server/services/ai/tools');
  const root = nodeTestProject();
  initRepo(root);
  commitAll(root);
  write(root, 'a.test.js', 'changed\n');
  const { app } = runtimeServices(root);
  const context = { userId: user.userId, app };

  const search = await executeTool('search_files', { query: 'changed' }, context, {});
  assert.equal(search.matches[0].file, 'a.test.js');
  const overview = await executeTool('repo_overview', {}, context, {});
  assert.equal(overview.git.toplevel, root);
  const diff = await executeTool('repo_diff', {}, context, {});
  assert.equal(diff.scope, 'uncommitted');
  assert.equal(diff.files.length, 1);
});

test('without a computer the repo tools say so, and search falls back to the server workspace', async () => {
  runtime = createTestRuntime();
  const user = await createTestUser(runtime.db, { username: 'coding_no_computer' });
  const { executeTool } = require('../../../server/services/ai/tools');
  const { WorkspaceManager } = require('../../../server/services/workspace/manager');
  const workspaceManager = new WorkspaceManager();
  workspaceManager.writeFile(user.userId, { path: 'a.txt', content: 'needle\n' });
  const context = { userId: user.userId };
  for (const name of ['repo_overview', 'repo_diff', 'run_tests']) {
    assert.match((await executeTool(name, {}, context, { workspaceManager })).error, /computer/, name);
  }
  assert.equal((await executeTool('search_files', { query: 'needle' }, context, { workspaceManager })).count, 1);
});

test('reads are bounded, say where they stopped, and pick up from there', async () => {
  runtime = createTestRuntime();
  const user = await createTestUser(runtime.db, { username: 'bounded_reads' });
  const { executeTool } = require('../../../server/services/ai/tools');
  const { WorkspaceManager } = require('../../../server/services/workspace/manager');
  const workspaceManager = new WorkspaceManager();
  const context = { userId: user.userId };
  const services = { workspaceManager };
  const long = Array.from({ length: 2000 }, (_, i) => `line ${i + 1}`).join('\n');
  workspaceManager.writeFile(user.userId, { path: 'long.txt', content: long });
  workspaceManager.writeFile(user.userId, { path: 'wide.txt', content: `${'w'.repeat(30000)}\nend\n` });
  workspaceManager.writeFile(user.userId, { path: 'small.txt', content: 'small\n' });
  fs.writeFileSync(workspaceManager.resolvePath(user.userId, 'bin.dat'), Buffer.from([1, 0, 2, 0]));

  const whole = await executeTool('read_file', { path: 'long.txt' }, context, services);
  assert.equal(whole.truncated, true);
  assert.deepEqual(whole.rangeShown, [1, 400]);
  assert.equal(whole.totalLines, 2000);
  assert.ok(whole.content.endsWith('line 400'), 'cut on a line');

  const next = await executeTool('read_file', { path: 'long.txt', start_line: 401, end_line: 900 }, context, services);
  assert.deepEqual(next.rangeShown, [401, 900]);
  assert.equal(next.truncated, undefined, 'an explicit range under the size limit is not cut by lines');

  const huge = await executeTool('read_file', { path: 'wide.txt' }, context, services);
  assert.ok(huge.content.length <= 16000);
  assert.equal(huge.truncated, true);

  assert.equal((await executeTool('read_file', { path: 'small.txt' }, context, services)).truncated, undefined);
  const binary = await executeTool('read_file', { path: 'bin.dat' }, context, services);
  assert.equal(binary.binary, true);
  assert.doesNotMatch(binary.content, /\0/);

  const many = await executeTool('read_files', { paths: ['long.txt', 'wide.txt', 'small.txt'] }, context, services);
  assert.ok(JSON.stringify(many).length < 22000, `${JSON.stringify(many).length} chars`);
  assert.equal(many.results[0].truncated, true);
  assert.equal(many.results[2].content, 'small\n');
});

test('edit_file is all or nothing through the tool, on the server workspace', async () => {
  runtime = createTestRuntime();
  const user = await createTestUser(runtime.db, { username: 'edit_atomic' });
  const { executeTool } = require('../../../server/services/ai/tools');
  const { WorkspaceManager } = require('../../../server/services/workspace/manager');
  const workspaceManager = new WorkspaceManager();
  const context = { userId: user.userId };
  const services = { workspaceManager };
  workspaceManager.writeFile(user.userId, { path: 'a.txt', content: 'one\ntwo\n' });

  const failed = await executeTool('edit_file', {
    path: 'a.txt',
    edits: [{ old_text: 'one', new_text: 'ONE' }, { old_text: 'three', new_text: 'THREE' }],
  }, context, services);
  assert.equal(failed.success, false);
  assert.equal(workspaceManager.readFile(user.userId, { path: 'a.txt' }).content, 'one\ntwo\n');

  const applied = await executeTool('edit_file', {
    path: 'a.txt',
    edits: [{ old_text: 'one', new_text: 'ONE' }, { old_text: 'two', new_text: 'TWO' }],
  }, context, services);
  assert.equal(applied.success, true);
  assert.equal(workspaceManager.readFile(user.userId, { path: 'a.txt' }).content, 'ONE\nTWO\n');
});

test('createWorkspaceShell starts commands at the path every computer maps to its workspace', async () => {
  const seen = [];
  const manager = { executeCliCommand: async (_user, _command, options) => { seen.push(options); return {}; } };
  const shell = await createWorkspaceShell({
    runtime: () => manager,
    computerWorkspace: () => ({ readFile() {} }),
    userId: 1,
    runId: 'r',
    stepId: 's',
    deviceTarget: 'local',
  });
  await shell.run('true');
  assert.equal(seen[0].cwd, GUEST_WORKSPACE_DIR);
  assert.equal(seen[0].deviceTarget, 'local');
  assert.equal(seen[0].runId, 'r');
});

// ---- the guest agent's own protocol ----

function startGuestAgent(workspaceDir) {
  const token = `test-${process.pid}-${Date.now()}`;
  const port = 20000 + Math.floor(Math.random() * 20000);
  const home = tempDir('neoagent-guest-home-');
  const { NODE_TEST_CONTEXT, ...env } = process.env;
  const child = spawn(process.execPath, [path.resolve(__dirname, '../../../server/guest_agent.js')], {
    stdio: ['ignore', 'pipe', 'pipe'],
    env: {
      ...env,
      HOME: home,
      NEOAGENT_HOME: home,
      NEOAGENT_DATA_DIR: path.join(home, 'data'),
      NEOAGENT_ENV_FILE: path.join(home, '.env'),
      NEOAGENT_VM_GUEST_TOKEN: token,
      NEOAGENT_GUEST_AGENT_PORT: String(port),
      NEOAGENT_GUEST_PROFILE: 'cli',
      NEOAGENT_WORKSPACE_DIR: workspaceDir,
    },
  });
  const request = async (method, pathname, body) => {
    const response = await fetch(`http://127.0.0.1:${port}${pathname}`, {
      method,
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || `HTTP ${response.status}`);
    return payload;
  };
  const ready = new Promise((resolve, reject) => {
    child.stdout.on('data', (chunk) => { if (String(chunk).includes('listening')) resolve(); });
    child.once('exit', (code) => reject(new Error(`guest agent exited ${code}`)));
  });
  return { child, request, ready };
}

test('the guest agent refuses a write that leads out of the workspace through a link', async (t) => {
  const workspace = tempDir('neoagent-guest-link-');
  const outside = tempDir('neoagent-guest-outside-');
  fs.writeFileSync(path.join(outside, 'file.txt'), 'kept\n');
  fs.symlinkSync(outside, path.join(workspace, 'out'));
  fs.symlinkSync(path.join(outside, 'file.txt'), path.join(workspace, 'file-link'));
  const guest = startGuestAgent(workspace);
  t.after(() => guest.child.kill('SIGKILL'));
  await guest.ready;
  const put = (target) => guest.request('PUT', '/workspace/files/content', { path: target, content: 'x' });
  await assert.rejects(put('out/new.txt'), /outside the computer workspace/);
  await assert.rejects(put('out/deep/new.txt'), /outside the computer workspace/);
  await assert.rejects(put('file-link'), /outside the computer workspace/);
  assert.equal(fs.readFileSync(path.join(outside, 'file.txt'), 'utf8'), 'kept\n');
  assert.deepEqual(fs.readdirSync(outside), ['file.txt'], 'not even a directory was made there');
  await put('fine/new.txt');
  assert.equal(fs.readFileSync(path.join(workspace, 'fine/new.txt'), 'utf8'), 'x');
});

test('every coding tool works over the real guest agent, as in a VM', async () => {
  runtime = createTestRuntime();
  const user = await createTestUser(runtime.db, { username: 'coding_guest' });
  const { executeTool } = require('../../../server/services/ai/tools');
  const { ArtifactStore } = require('../../../server/services/artifacts/store');
  const { ComputerWorkspaceClient } = require('../../../server/services/runtime/computer_workspace_client');
  const workspaceDir = tempDir('neoagent-guest-workspace-');
  const repo = path.join(workspaceDir, 'proj');
  nodeTestProject(repo);
  initRepo(repo);
  write(repo, 'run.sh', '#!/bin/sh\necho hi\n');
  fs.chmodSync(path.join(repo, 'run.sh'), 0o755);
  commitAll(repo);

  const guest = startGuestAgent(workspaceDir);
  try {
    await guest.ready;
    // Only the guest's home path differs from a VM's, so only that is translated.
    const runtimeManager = {
      requestComputer: (_userId, method, pathname, body) => guest.request(method, pathname, body),
      executeCliCommand: (_userId, command, options = {}) => guest.request('POST', '/exec', {
        command,
        cwd: options.cwd === GUEST_WORKSPACE_DIR ? workspaceDir : options.cwd,
        timeout: options.timeout,
      }),
    };
    const app = {
      locals: {
        runtimeManager,
        computerWorkspaceManager: new ComputerWorkspaceClient({ runtimeManager }),
        artifactStore: new ArtifactStore(),
      },
    };
    const context = { userId: user.userId, app };
    const call = (name, args) => executeTool(name, args, context, {});

    const overview = await call('repo_overview', { path: `${GUEST_WORKSPACE_DIR}/proj` });
    assert.equal(overview.path, 'proj');
    assert.equal(overview.test.command, 'npm test');
    assert.deepEqual((await call('repo_overview', {})).repos, ['proj/']);

    const found = await call('search_files', { query: 'rejects expired', path: 'proj' });
    assert.equal(found.matches[0].file, 'proj/a.test.js');
    assert.equal(found.count, 1);
    assert.match((await call('search_files', { query: 'x', path: '/etc' })).error, /outside the workspace/);

    const failedEdit = await call('edit_file', {
      path: 'proj/a.test.js',
      edits: [{ oldText: 'assert.equal(401, 500)', newText: 'assert.equal(401, 401)' }, { oldText: 'not in the file', newText: 'x' }],
    });
    assert.equal(failedEdit.success, false);
    assert.match(fs.readFileSync(path.join(repo, 'a.test.js'), 'utf8'), /401, 500/, 'all or nothing in the guest too');

    const failing = await call('run_tests', { cwd: 'proj' });
    assert.equal(failing.test_result.summary, '1 failed, 2 passed');
    assert.ok(failing.log_artifact_id);
    assert.match((await call('read_artifact', { artifact_id: failing.log_artifact_id })).content, /accepts fresh token/);

    const edit = await call('edit_file', {
      path: 'proj/a.test.js',
      edits: [{ oldText: 'assert.equal(401, 500)', newText: 'assert.equal(401, 401)' }],
    });
    assert.equal(edit.success, true);
    const passing = await call('run_tests', { command: 'npm test', cwd: `${GUEST_WORKSPACE_DIR}/proj` });
    assert.equal(passing.status, 'passed');
    assert.equal(passing.test_result.summary, '0 failed, 3 passed');

    const diff = await call('repo_diff', { path: 'proj' });
    assert.equal(diff.scope, 'uncommitted');
    assert.deepEqual(diff.files, ['M a.test.js +1 -1']);
    assert.match(diff.diff, /\+  test\('rejects expired token', \(\) => assert\.equal\(401, 401\)\);/);

    const read = await call('read_files', { files: [{ path: 'proj/a.test.js', start_line: 2, end_line: 3 }] });
    assert.deepEqual(read.results[0].rangeShown, [2, 3]);
  } finally {
    guest.child.kill('SIGTERM');
  }
});
