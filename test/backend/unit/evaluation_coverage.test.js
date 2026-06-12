'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

test('representative evaluation suite covers every major run category', () => {
  const fixtures = JSON.parse(fs.readFileSync(
    path.join(__dirname, '../../evaluation/representative_tasks.json'),
    'utf8',
  ));
  const categories = new Set(fixtures.map((fixture) => fixture.category));
  for (const category of [
    'direct_answer',
    'research',
    'coding',
    'integration',
    'scheduled_task',
    'memory_correction',
    'recovery',
  ]) {
    assert.equal(categories.has(category), true, `missing ${category}`);
  }
  assert.equal(fixtures.every((fixture) => Array.isArray(fixture.requiredSignals)), true);
});
