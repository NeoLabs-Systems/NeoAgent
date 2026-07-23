'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { BitwardenCli } = require('../../../server/services/credentials/bitwarden_cli');

test('Bitwarden master password and session remain process inputs and never appear in status', async (t) => {
  const calls = [];
  const cli = new BitwardenCli({
    cliScript: '/fake/bw.js',
    async runner(command, args, options) {
      calls.push({ command, args, env: options.env });
      return 'opaque-session-key';
    },
  });
  t.after(() => cli.shutdown());

  const status = await cli.unlock(1, 'agent-1', 'master-password', 12);
  assert.equal(status.unlocked, true);
  assert.equal(status.idleTimeoutMinutes, 12);
  assert.equal(JSON.stringify(status).includes('master-password'), false);
  assert.equal(JSON.stringify(status).includes('opaque-session-key'), false);
  assert.equal(calls[0].args.includes('master-password'), false);
  assert.equal(calls[0].env.NEOAGENT_BITWARDEN_MASTER_PASSWORD, 'master-password');
  assert.equal(calls[0].env.SESSION_SECRET, undefined);
});
