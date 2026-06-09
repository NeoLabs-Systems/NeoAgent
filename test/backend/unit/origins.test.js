'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  isAllowedOrigin,
  isChromeExtensionOrigin,
  isLoopbackOrigin,
} = require('../../../server/config/origins');

test('origin helpers identify loopback and Chrome extension origins', () => {
  assert.equal(isLoopbackOrigin('http://localhost:3333'), true);
  assert.equal(isLoopbackOrigin('http://127.0.0.1:3333'), true);
  assert.equal(isLoopbackOrigin('http://[::1]:3333'), true);
  assert.equal(isLoopbackOrigin('https://example.com'), false);
  assert.equal(isChromeExtensionOrigin('chrome-extension://abcdef'), true);
  assert.equal(isChromeExtensionOrigin('moz-extension://abcdef'), false);
});

test('origin policy allows missing same-origin and loopback but rejects external/null origins', () => {
  assert.equal(isAllowedOrigin(undefined), true);
  assert.equal(isAllowedOrigin(''), true);
  assert.equal(isAllowedOrigin('http://localhost:5173'), true);
  assert.equal(isAllowedOrigin('null'), false);
  assert.equal(isAllowedOrigin('https://evil.example'), false);
  assert.equal(isAllowedOrigin('', { allowMissingOrigin: false }), false);
  assert.equal(isAllowedOrigin('chrome-extension://abcdef'), false);
  assert.equal(isAllowedOrigin('chrome-extension://abcdef', { allowChromeExtension: true }), true);
});
