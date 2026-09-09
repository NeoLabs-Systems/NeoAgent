'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { shouldRunVerifier } = require('../../../server/services/ai/taskAnalysis');

const actionAnalysis = { verification_need: 'light', research_depth: 'none' };
const writeEvidence = [{ id: 's1', tool: 'write_file', summary: 'ok', success: true }];
const writeSideEffect = [{ id: 's1', tool_name: 'write_file', status: 'confirmed' }];

test('successful state-changing runs skip the semantic verifier', () => {
  assert.equal(shouldRunVerifier({
    analysis: actionAnalysis,
    toolExecutions: writeEvidence,
    sideEffects: writeSideEffect,
    finalReply: 'Written.',
  }), false);
});

test('a failed tool keeps the semantic verifier', () => {
  assert.equal(shouldRunVerifier({
    analysis: actionAnalysis,
    toolExecutions: [...writeEvidence, { id: 's2', tool: 'execute_command', summary: 'exit 1', success: false }],
    sideEffects: writeSideEffect,
    finalReply: 'Done.',
  }), true);
});

test('research replies and read-only runs keep the semantic verifier', () => {
  assert.equal(shouldRunVerifier({
    analysis: { verification_need: 'light', research_depth: 'light' },
    toolExecutions: [{ id: 's1', tool: 'web_search', summary: 'results', success: true }],
    sideEffects: [],
    finalReply: 'Answer.',
  }), true);
  assert.equal(shouldRunVerifier({
    analysis: actionAnalysis,
    toolExecutions: [{ id: 's1', tool: 'read_file', summary: 'content', success: true }],
    sideEffects: [],
    finalReply: 'Summary.',
  }), true);
});

test('explicit verification requirements and empty replies always verify', () => {
  assert.equal(shouldRunVerifier({
    analysis: { ...actionAnalysis, verification_need: 'required' },
    toolExecutions: writeEvidence,
    sideEffects: writeSideEffect,
    finalReply: 'Written.',
  }), true);
  assert.equal(shouldRunVerifier({
    analysis: actionAnalysis,
    toolExecutions: writeEvidence,
    sideEffects: writeSideEffect,
    finalReply: '',
  }), true);
});
