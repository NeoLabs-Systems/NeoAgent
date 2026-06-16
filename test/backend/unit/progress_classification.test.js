'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  isClearlyReadOnlyShellCommand,
  isProgressToolCall,
} = require('../../../server/services/ai/loop/progress_classification');

test('read-only shell inspection commands do not count as implementation progress', () => {
  const commands = [
    'curl -s https://api.github.com/repos/NeoLabs-Systems/NeoAgent/issues/91 | python3 -m json.tool | head -80',
    'cat /tmp/run-abc-github_get_issue.json',
    'sed -n "1,120p" server/services/ai/engine.js',
    'find . -name "*.js" | grep widgets | wc -l',
    'git status --short && git diff -- server/services/ai/engine.js',
    'curl -s https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/README.md > /tmp/readme.txt && wc -l /tmp/readme.txt',
    'base64 /tmp/NeoAgent/test/backend/unit/version_memory_social.test.js',
    'sed -n "1,80p" /tmp/NeoAgent/server/services/widgets/service.js | base64 -w 0',
  ];

  for (const command of commands) {
    assert.equal(isClearlyReadOnlyShellCommand(command), true, command);
    assert.equal(isProgressToolCall('execute_command', { command }), false, command);
  }
});

test('state-changing shell commands count as implementation progress', () => {
  const commands = [
    'git clone https://github.com/NeoLabs-Systems/NeoAgent.git /tmp/NeoAgent',
    'git checkout -b chore/remove-widget',
    'mkdir -p server/tmp && touch server/tmp/result.txt',
    'npm install',
    'rm server/services/widgets/old_widget.js',
    'python3 -c "open(\'/tmp/result.txt\', \'w\').write(\'done\')"',
    'sed -n "1,120p" server/services/ai/engine.js > copied-engine.js',
  ];

  for (const command of commands) {
    assert.equal(isProgressToolCall('execute_command', { command }), true, command);
  }
});

test('structured tool progress classification treats reads and writes differently', () => {
  assert.equal(isProgressToolCall('github_get_issue', { owner_repo: 'NeoLabs-Systems/NeoAgent' }), false);
  assert.equal(isProgressToolCall('github_list_issues', { owner_repo: 'NeoLabs-Systems/NeoAgent' }), false);
  assert.equal(isProgressToolCall('github_create_pr', { owner_repo: 'NeoLabs-Systems/NeoAgent' }), true);
  assert.equal(isProgressToolCall('github_api_request', { method: 'GET' }), false);
  assert.equal(isProgressToolCall('github_api_request', { method: 'POST' }), true);
  assert.equal(isProgressToolCall('http_request', { method: 'GET' }), false);
  assert.equal(isProgressToolCall('http_request', { method: 'POST' }), true);
  assert.equal(isProgressToolCall('send_interim_update', { content: 'I am checking this.' }), false);
  assert.equal(isProgressToolCall('send_message', { content: 'Final result.' }), true);
});
