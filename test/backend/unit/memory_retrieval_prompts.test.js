'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  buildPlannerPrompt,
  buildRerankerPrompt,
} = require('../../../server/services/memory/retrieval_reasoning');

function candidate() {
  return {
    id: 'mem-1',
    content: 'Neo prefers   the Gmail integration\nfor email.',
    category: 'preferences',
    confidence: 0.8123456,
    score: 0.7345678,
    factContext: [
      {
        subject: 'Neo',
        predicate: 'prefers email tool',
        object: 'Gmail integration',
        relation: 'updates',
        previous: { id: 'fact-old', object: 'neo.eu.com', learnedAt: null },
        related: [{
          factId: 'fact-2',
          relation: 'derives',
          subject: 'Neo',
          predicate: 'email address',
          object: 'erhardt.neo@gmail.com',
        }],
      },
    ],
    sources: [{
      documentId: 'doc-1',
      chunkId: 'chunk-1',
      sourceType: 'whatsapp',
      title: 'Chat mit Neo',
      chunkIndex: 3,
      charStart: 100,
      charEnd: 400,
    }],
  };
}

test('reranker candidates are the memory statement and nothing else', () => {
  const prompt = buildRerankerPrompt('welches mail tool nutzt neo?', { query_variants: [] }, [candidate()]);

  assert.match(prompt, /Candidates:\n\[\{"id":"mem-1","content":"Neo prefers the Gmail integration for email\."\}\]/);
  for (const dropped of [
    /"relation"/, /"previous"/, /"related"/, /"facts"/, /"sources"/,
    /"category"/, /"confidence"/, /"score"/, /chunkId|charStart|documentId/,
  ]) {
    assert.doesNotMatch(prompt, dropped);
  }
});

test('planner candidates use the same statement-only shape', () => {
  const prompt = buildPlannerPrompt('welches mail tool nutzt neo?', [candidate()], '2026-09-13T16:56:50Z');

  assert.match(prompt, /Initial retrieval:\n\[\{"id":"mem-1","content":"Neo prefers the Gmail integration for email\."\}\]/);
});

test('over-long candidate content is capped', () => {
  const long = { id: 'mem-2', content: 'x'.repeat(2000) };
  const prompt = buildRerankerPrompt('note?', {}, [long]);

  assert.match(prompt, /"content":"x{1200}"/);
  assert.doesNotMatch(prompt, /x{1201}/);
});

test('reranker asks for scored top candidates only, without written reasons', () => {
  const prompt = buildRerankerPrompt('note?', {}, [candidate()]);

  assert.match(prompt, /at most 8/);
  assert.doesNotMatch(prompt, /"reason"/);
});
