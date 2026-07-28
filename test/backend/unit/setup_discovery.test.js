'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const { buildDiscoveryTxt } = require('../../../server/services/setup/discovery');

test('local discovery TXT records contain no credentials or network addresses', () => {
  const txt = buildDiscoveryTxt({
    instanceId: '2d84589f-e05a-4e80-a363-a3cbf40cc714',
    protocolVersion: 1,
    serverVersion: '3.4.0',
    claimed: false,
  });
  assert.deepEqual(txt, {
    instanceId: '2d84589f-e05a-4e80-a363-a3cbf40cc714',
    protocolVersion: '1',
    serverVersion: '3.4.0',
    claimed: '0',
    transport: 'http',
  });
  assert.equal(JSON.stringify(txt).includes('password'), false);
  assert.equal(JSON.stringify(txt).includes('token'), false);
});
