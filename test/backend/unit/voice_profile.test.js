'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  collectStyleNotes,
  formatStyleNotesForPrompt,
  styleNoteFromFact,
  mergeStyleNotes,
} = require('../../../server/services/behavior/modules/voice_profile');

test('collectStyleNotes gathers freeform prose without enum seeds', () => {
  const notes = collectStyleNotes({
    selfStateIdentity: { voice: { notes: ['short and dry', 'roast ok'] } },
    aiPersonality: 'prefer german mix',
    behaviorNotes: 'keep it chill',
  });
  assert.deepEqual(notes, ['short and dry', 'roast ok', 'prefer german mix', 'keep it chill']);
});

test('collectStyleNotes folds legacy structured fields into prose', () => {
  const notes = collectStyleNotes({
    selfStateIdentity: {
      voice: { humor: 'dry', casing: 'lowercase_preferred', notes: ['old note'] },
    },
  });
  assert.ok(notes.includes('old note'));
  assert.ok(notes.some((n) => /humor:\s*dry/i.test(n)));
  assert.ok(notes.some((n) => /casing:/i.test(n)));
});

test('formatStyleNotesForPrompt stays guidance not scripts', () => {
  const block = formatStyleNotesForPrompt(['short replies', 'lowercase lean']);
  assert.match(block, /Living Style Notes/);
  assert.match(block, /rigid knobs/i);
  assert.match(block, /short replies/);
  assert.doesNotMatch(block, /How can I help you/);
  assert.doesNotMatch(block, /casual_preferred/);
});

test('styleNoteFromFact returns freeform notes for style facts', () => {
  const note = styleNoteFromFact({
    predicate: 'writing_style',
    object: 'short dry replies, lowercase ok',
  });
  assert.equal(note, 'short dry replies, lowercase ok');

  const humor = styleNoteFromFact({
    predicate: 'humor',
    object: 'dry',
  });
  assert.equal(humor, 'humor: dry');

  const unrelated = styleNoteFromFact({
    predicate: 'birthday',
    object: 'march 3',
  });
  assert.equal(unrelated, null);
});

test('mergeStyleNotes dedupes and caps', () => {
  const merged = mergeStyleNotes(
    ['keep it short', 'dry'],
    ['keep it short', 'roast ok'],
  );
  assert.deepEqual(merged, ['keep it short', 'dry', 'roast ok']);
});
