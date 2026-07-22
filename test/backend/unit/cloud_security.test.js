'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  isPrivateHost,
  validateAndroidIntentUrl,
  validateCloudUrl,
  validateCloudUrlWithDns,
} = require('../../../server/utils/cloud-security');

test('cloud URL validation uses an HTTP(S) allowlist', () => {
  assert.equal(validateCloudUrl('https://example.com/path').allowed, true);
  assert.equal(validateCloudUrl('http://example.com/path').allowed, true);
  assert.equal(validateCloudUrl('ftp://example.com/file').allowed, false);
  assert.equal(validateCloudUrl('mailto:user@example.com').allowed, false);
  assert.equal(validateCloudUrl('file:///etc/passwd').allowed, false);
});

test('Android intent validation allows deep links but blocks local-content schemes', async () => {
  assert.equal((await validateAndroidIntentUrl('geo:0,0?q=coffee')).allowed, true);
  assert.equal((await validateAndroidIntentUrl('smsto:+1234567890')).allowed, true);
  assert.equal((await validateAndroidIntentUrl('market://details?id=com.example')).allowed, true);
  assert.equal((await validateAndroidIntentUrl('file:///data/local/tmp/secret')).allowed, false);
  assert.equal((await validateAndroidIntentUrl('content://settings/system')).allowed, false);
});

test('private host validation covers reserved and special-use IP ranges', () => {
  for (const address of [
    '127.0.0.1',
    '169.254.169.254',
    '192.168.1.1',
    '198.18.0.1',
    '203.0.113.4',
    '::1',
    'fd00::1',
    'fe90::1',
    'fec0::1',
    'ff02::1',
    '100::1',
    '2001:db8::1',
  ]) {
    assert.equal(isPrivateHost(address), true, address);
  }
  assert.equal(isPrivateHost('8.8.8.8'), false);
});

test('DNS validation blocks hostnames that resolve to internal addresses', async () => {
  const privateResult = await validateCloudUrlWithDns('https://public-name.example', {
    lookup: async () => [{ address: '10.0.0.8', family: 4 }],
  });
  const mixedResult = await validateCloudUrlWithDns('https://rebinding.example', {
    lookup: async () => [
      { address: '93.184.216.34', family: 4 },
      { address: '127.0.0.1', family: 4 },
    ],
  });
  const publicResult = await validateCloudUrlWithDns('https://example.com', {
    lookup: async () => [{ address: '93.184.216.34', family: 4 }],
  });

  assert.equal(privateResult.allowed, false);
  assert.equal(mixedResult.allowed, false);
  assert.equal(publicResult.allowed, true);
});

test('DNS validation stops promptly when cancelled', async () => {
  const controller = new AbortController();
  const validation = validateCloudUrlWithDns('https://slow.example', {
    lookup: () => new Promise(() => {}),
    signal: controller.signal,
    timeoutMs: 5000,
  });
  controller.abort();

  await assert.rejects(validation, (error) => error.name === 'AbortError');
});
