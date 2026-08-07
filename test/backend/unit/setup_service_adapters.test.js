'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  renderLaunchAgent,
  renderSystemdUnit,
} = require('../../../lib/setup/service_adapters');

test('launch agent rendering escapes user-controlled paths', () => {
  const rendered = renderLaunchAgent(
    '<string>__APP_DIR__</string><string>__NODE_BIN__</string>',
    {
      nodeBin: '/Applications/Node & Tools/node',
      appDir: '/Users/Neo & Team/NeoAgent',
      homeDir: '/Users/Neo',
      runtimeHome: '/Users/Neo/.neoagent',
      logDir: '/Users/Neo/.neoagent/data/logs',
    },
  );
  assert.match(rendered, /Neo &amp; Team/);
  assert.match(rendered, /Node &amp; Tools/);
  assert.doesNotMatch(rendered, /__[A-Z_]+__/);
});

test('systemd rendering quotes only the ExecStart argument list', () => {
  // WorkingDirectory=, EnvironmentFile=, StandardOutput=, and StandardError= take the
  // rest of the line verbatim in systemd unit syntax — wrapping them in literal quote
  // characters makes the quotes part of the value (e.g. a non-absolute WorkingDirectory).
  // Only ExecStart= is parsed as a command/argument list, where quoting matters.
  const rendered = renderSystemdUnit({
    appDir: '/opt/Neo Agent',
    envFile: '/home/neo/Neo Agent/.env',
    logDir: '/home/neo/Neo Agent/logs',
    nodeBin: '/opt/Node Runtime/node',
  });
  assert.match(rendered, /^WorkingDirectory=\/opt\/Neo Agent$/m);
  assert.match(
    rendered,
    /ExecStart="\/opt\/Node Runtime\/node" "\/opt\/Neo Agent\/server\/index\.js"/,
  );
  assert.match(rendered, /^EnvironmentFile=-\/home\/neo\/Neo Agent\/\.env$/m);
  assert.match(rendered, /^StandardError=append:\/home\/neo\/Neo Agent\/logs\//m);
});
