'use strict';

const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { after, before, test } = require('node:test');

const { runScriptedCases } = require('./runner');
const { checkGate } = require('./gate');

let report;

before(async () => {
  report = await runScriptedCases();
});

after(() => {
  process.exitCode = process.exitCode || 0;
});

test('every scripted harness case holds', () => {
  const failing = report.results.filter((entry) => !entry.ok).map((entry) => `${entry.id}: ${entry.detail}`);
  assert.deepEqual(failing, []);
});

test('the regression gate passes against the stored baseline', () => {
  const baseline = JSON.parse(fs.readFileSync(path.join(__dirname, 'baseline.json'), 'utf8'));
  const verdict = checkGate(report.summary, baseline);
  assert.deepEqual(verdict.failures, []);
});

test('the gate has no tolerance for duplicate messages or security failures', () => {
  const clean = { eval_set_version: 1, success_rate: 1, duplicate_messages: 0, security_failures: 0 };
  assert.equal(checkGate(clean, null).ok, true);
  assert.equal(checkGate({ ...clean, duplicate_messages: 1 }, null).ok, false);
  assert.equal(checkGate({ ...clean, security_failures: 1 }, null).ok, false);
  const baseline = { eval_set_version: 1, success_rate: 1, tolerance: { success_rate: 0.1 } };
  assert.equal(checkGate({ ...clean, success_rate: 0.95 }, baseline).ok, true);
  assert.equal(checkGate({ ...clean, success_rate: 0.8 }, baseline).ok, false);
});
