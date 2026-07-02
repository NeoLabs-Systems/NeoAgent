'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { routeMemoryQuery } = require('../../../server/services/memory/routing');
const {
  getDecayedStrength,
  getReinforcedStrength,
  isArchiveEligible,
} = require('../../../server/services/memory/retention');

test('routeMemoryQuery recognizes procedural intent without hard failure modes', () => {
  const route = routeMemoryQuery('How do I run the same release checklist again?');

  assert.equal(route.intent, 'procedural');
  assert.ok(route.confidence >= 0.6);
  assert.ok(route.categoryBoosts.procedural > route.categoryBoosts.episodic);
});

test('routeMemoryQuery falls back to broad for low-signal queries', () => {
  const route = routeMemoryQuery('NeoAgent memory');

  assert.equal(route.intent, 'broad');
  assert.deepEqual(route.categoryBoosts, {});
});

test('retention reinforces accessed memories and protects pinned memories from archive', () => {
  const oldDate = '2020-01-01T00:00:00.000Z';
  const weakMemory = {
    category: 'episodic',
    importance: 3,
    memory_strength: 0.1,
    updated_at: oldDate,
    created_at: oldDate,
  };
  const pinnedMemory = {
    ...weakMemory,
    pinned: 1,
  };

  assert.ok(getReinforcedStrength(weakMemory) > weakMemory.memory_strength);
  assert.ok(getDecayedStrength(weakMemory) < weakMemory.memory_strength);
  assert.equal(isArchiveEligible(weakMemory, { minAgeDays: 1, strengthThreshold: 0.2 }), true);
  assert.equal(isArchiveEligible(pinnedMemory, { minAgeDays: 1, strengthThreshold: 0.2 }), false);
});
