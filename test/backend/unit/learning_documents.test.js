'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  isUsableProposal,
  normalizeProposal,
  proposalFailureMessage,
} = require('../../../server/services/skills/learning_documents');

function completeSkill(overrides = {}) {
  return {
    name: 'export-report',
    description: 'Export the current report.',
    trigger: 'Use when exporting a report from the reports interface.',
    steps: [
      'Inspect the reports view and activate Export.',
      'Verify that the requested report file appears.',
    ],
    verification: ['The requested report exists in the workspace.'],
    ...overrides,
  };
}

test('normalizeProposal accepts complete skills when approved is omitted or loosely typed', () => {
  const omitted = normalizeProposal({ skill: completeSkill() });
  assert.equal(omitted.approved, true);
  assert.equal(isUsableProposal(omitted), true);

  const stringFlag = normalizeProposal({
    approved: 'true',
    skill: completeSkill({
      steps: '1. Inspect the reports view and activate Export.\n2. Verify that the requested report file appears.',
      verification: 'The requested report exists in the workspace.',
    }),
  });
  assert.equal(stringFlag.approved, true);
  assert.equal(stringFlag.steps.length, 2);
  assert.equal(stringFlag.verification.length, 1);
  assert.equal(isUsableProposal(stringFlag), true);

  const numbered = normalizeProposal(completeSkill({
    steps: '1. Inspect the reports view. 2. Verify the exported file.',
  }));
  assert.equal(numbered.approved, true);
  assert.deepEqual(numbered.steps, [
    'Inspect the reports view.',
    'Verify the exported file.',
  ]);
});

test('normalizeProposal keeps explicit rejections and reports a usable failure', () => {
  const rejected = normalizeProposal({
    approved: false,
    reason: 'Pointer events alone are not a reusable procedure.',
    skill: {},
  });
  assert.equal(rejected.approved, false);
  assert.equal(isUsableProposal(rejected), false);
  assert.equal(
    proposalFailureMessage(rejected),
    'Pointer events alone are not a reusable procedure.',
  );

  const incomplete = normalizeProposal({ approved: true, skill: { name: 'export-report' } });
  assert.equal(isUsableProposal(incomplete), false);
  assert.match(proposalFailureMessage(incomplete), /missing description, trigger, steps, verification/);
});
