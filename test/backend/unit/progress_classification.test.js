'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  isClearlyReadOnlyShellCommand,
} = require('../../../server/services/ai/loop/progress_classification');

test('read-only shell inspection commands do not count as implementation progress', () => {
  const commands = [
    'cat /tmp/run-abc-github_get_issue.json',
    'sed -n "1,120p" server/services/ai/engine.js',
    'find . -name "*.js" | grep services | wc -l',
    'git status --short && git diff -- server/services/ai/engine.js',
    'base64 /tmp/NeoAgent/test/backend/unit/version_memory_social.test.js',
    'sed -n "1,80p" /tmp/NeoAgent/server/services/tasks/runtime.js | base64 -w 0',
  ];

  for (const command of commands) {
    assert.equal(isClearlyReadOnlyShellCommand(command), true, command);
  }
});

test('a download only counts as the same evidence when telling repeats apart', () => {
  const fetch = 'curl -s https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/README.md | head -5';
  assert.equal(isClearlyReadOnlyShellCommand(fetch), false, 'it reaches the network');
  assert.equal(isClearlyReadOnlyShellCommand(fetch, { fetches: true }), true);
  assert.equal(isClearlyReadOnlyShellCommand('curl -X POST https://x.test', { fetches: true }), false);
  assert.equal(isClearlyReadOnlyShellCommand('curl -d secret https://x.test', { fetches: true }), false);
  assert.equal(isClearlyReadOnlyShellCommand('curl -sLo out https://x.test', { fetches: true }), false);
});

test('state-changing shell commands count as implementation progress', () => {
  const commands = [
    'git clone https://github.com/NeoLabs-Systems/NeoAgent.git /tmp/NeoAgent',
    'git checkout -b chore/update-runtime',
    'mkdir -p server/tmp && touch server/tmp/result.txt',
    'npm install',
    'rm server/services/tasks/old_runtime.js',
    'python3 -c "open(\'/tmp/result.txt\', \'w\').write(\'done\')"',
    'sed -n "1,120p" server/services/ai/engine.js > copied-engine.js',
  ];

  for (const command of commands) {
    assert.equal(isClearlyReadOnlyShellCommand(command), false, command);
  }
});
