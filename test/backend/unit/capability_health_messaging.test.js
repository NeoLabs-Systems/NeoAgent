'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { getMessagingHealth } = require('../../../server/services/ai/capabilityHealth');

function appWith(statuses) {
  return { locals: { messagingManager: { getAllStatuses: () => statuses } } };
}

test('messaging health names each platform instead of a count', () => {
  const health = getMessagingHealth(1, appWith({ whatsapp: { status: 'connected' }, telegram: { status: 'disconnected' } }), null);
  assert.equal(health.healthy, true);
  assert.equal(health.degraded, true);
  assert.equal(health.summary, 'whatsapp: connected; telegram: disconnected');
});

test('the platform a run arrived through is reported as connected even when its snapshot says otherwise', () => {
  const health = getMessagingHealth(1, appWith({ whatsapp: { status: 'disconnected' } }), null, null, 'whatsapp');
  assert.equal(health.connected, true);
  assert.equal(health.healthy, true);
  assert.equal(health.summary, 'whatsapp: connected; this conversation is on whatsapp');

  const unknown = getMessagingHealth(1, appWith({}), null, null, 'telegram');
  assert.equal(unknown.configured, true);
  assert.match(unknown.summary, /^telegram: connected/);
});
