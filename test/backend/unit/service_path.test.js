'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { withToolPath } = require('../../../lib/cli/service_path');

test('the directory of the running node is on PATH, after what was there', () => {
  const env = withToolPath({ PATH: '/usr/bin:/bin' }, '/home/me/.nvm/versions/node/v22/bin/node');
  const dirs = env.PATH.split(':');
  assert.ok(dirs.includes('/home/me/.nvm/versions/node/v22/bin'));
  assert.deepEqual(dirs.slice(0, 2), ['/usr/bin', '/bin']);
  assert.equal(new Set(dirs).size, dirs.length);
});

test('a missing PATH still gets the node directory', () => {
  assert.ok(withToolPath({}, '/opt/node/bin/node').PATH.split(':').includes('/opt/node/bin'));
});
