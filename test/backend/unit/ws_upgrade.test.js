'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  createUpgradeLimiter,
  remoteAddressFromRequest,
} = require('../../../server/utils/ws_upgrade');

test('upgrade limiter allows a burst then rejects the same peer', () => {
  const allow = createUpgradeLimiter({ windowMs: 60_000, maxAttempts: 3 });
  assert.equal(allow('1.1.1.1'), true);
  assert.equal(allow('1.1.1.1'), true);
  assert.equal(allow('1.1.1.1'), true);
  assert.equal(allow('1.1.1.1'), false);
  assert.equal(allow('8.8.8.8'), true);
});

test('remote address uses X-Forwarded-For only when TRUST_PROXY is enabled', () => {
  const req = {
    socket: { remoteAddress: '10.0.0.2' },
    headers: { 'x-forwarded-for': '203.0.113.9, 10.0.0.1' },
  };
  const previous = process.env.TRUST_PROXY;
  try {
    delete process.env.TRUST_PROXY;
    assert.equal(remoteAddressFromRequest(req), '10.0.0.2');
    process.env.TRUST_PROXY = 'true';
    assert.equal(remoteAddressFromRequest(req), '203.0.113.9');
  } finally {
    if (previous === undefined) delete process.env.TRUST_PROXY;
    else process.env.TRUST_PROXY = previous;
  }
});
