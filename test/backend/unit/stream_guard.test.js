'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  createStreamGuard,
  degenerateOutputError,
  isDegenerateOutputError,
} = require('../../../server/services/ai/providers/stream_guard');

function feedAll(guard, text, chunk = 37) {
  for (let i = 0; i < text.length; i += chunk) {
    const verdict = guard.feed(text.slice(i, i + chunk));
    if (verdict) return verdict;
  }
  return null;
}

test('stream guard lets ordinary code through', () => {
  const guard = createStreamGuard();
  let code = '';
  for (let i = 0; i < 400; i += 1) {
    code += `def fn_${i}(x):\n    return x * ${i} + ${i * 7 % 13}\n\n`;
  }
  assert.equal(feedAll(guard, code), null);
});

test('stream guard leaves repetitive but real data alone', () => {
  const zeros = `{"content":"matrix = [${'0, '.repeat(2000)}0]"}`;
  assert.equal(feedAll(createStreamGuard(), zeros), null);
  const rows = `{"content":"${'| a | b |\\n'.repeat(400)}"}`;
  assert.equal(feedAll(createStreamGuard(), rows), null);
});

test('stream guard trips on a short pattern repeated until the window is full', () => {
  const guard = createStreamGuard();
  const junk = '{"content="\n\n    \t:\t0' + '\n    \t,\t\t""\n    \t:\t""'.repeat(400);
  const verdict = feedAll(guard, junk);
  assert.equal(verdict.reason, 'degenerate_repetition');
  assert.ok(verdict.bytes < 1400, `tripped late: ${verdict.bytes} bytes`);
});

test('stream guard trips on whitespace runs and on the byte ceiling', () => {
  assert.equal(feedAll(createStreamGuard(), 'x'.repeat(10) + ' '.repeat(3000)).reason, 'degenerate_repetition');
  const verdict = feedAll(createStreamGuard({ maxBytes: 500, windowBytes: 100000 }), 'abc'.repeat(200));
  assert.equal(verdict.reason, 'output_limit');
});

test('degenerate output errors carry a stable code', () => {
  const error = degenerateOutputError('openrouter', { reason: 'output_limit', bytes: 12 });
  assert.equal(error.code, 'MODEL_DEGENERATE_OUTPUT');
  assert.equal(isDegenerateOutputError(error), true);
  assert.equal(isDegenerateOutputError(new Error('other')), false);
});
