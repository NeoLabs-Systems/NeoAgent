'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const MANAGER = path.resolve(__dirname, '../../../lib/manager.js');

// The guard is exercised in a child process with its own HOME so it can never
// reach the developer's real NeoAgent service, and so a wrongly permissive
// guard kills the child's own listener instead of anything that matters.
function runPortGuard({ home, occupied }) {
  const script = `
    const net = require('node:net');
    const server = net.createServer(() => {});
    server.listen(0, '127.0.0.1', async () => {
      const port = server.address().port;
      if (!${occupied}) {
        await new Promise((resolve) => server.close(resolve));
      }
      const { releasePortForSetup } = require(${JSON.stringify(MANAGER)});
      let outcome = 'released';
      try {
        await releasePortForSetup(port);
      } catch (error) {
        outcome = error.code || 'unknown';
      }
      process.stdout.write(JSON.stringify({
        outcome,
        stillListening: server.listening,
      }));
      if (server.listening) server.close();
      process.exit(0);
    });
  `;
  const result = spawnSync(process.execPath, ['-e', script], {
    encoding: 'utf8',
    timeout: 60_000,
    env: {
      ...process.env,
      HOME: home,
      USERPROFILE: home,
      NEOAGENT_HOME: path.join(home, '.neoagent'),
    },
  });
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout);
}

function tempHome(t) {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-port-guard-'));
  t.after(() => fs.rmSync(home, { recursive: true, force: true }));
  return home;
}

test('setup leaves a free port alone', (t) => {
  assert.deepEqual(runPortGuard({ home: tempHome(t), occupied: false }), {
    outcome: 'released',
    stillListening: false,
  });
});

test('setup refuses a port owned by another program instead of killing it', (t) => {
  assert.deepEqual(runPortGuard({ home: tempHome(t), occupied: true }), {
    outcome: 'SETUP_PORT_IN_USE',
    stillListening: true,
  });
});
