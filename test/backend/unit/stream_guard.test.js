'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  createJsonPrefixTracker,
  createStreamGuard,
  degenerateOutputError,
  isDegenerateOutputError,
} = require('../../../server/services/ai/providers/stream_guard');

function feedByChar(text, chunk = 1) {
  const tracker = createJsonPrefixTracker();
  for (let i = 0; i < text.length; i += chunk) {
    if (!tracker.feed(text.slice(i, i + chunk))) return i;
  }
  return -1;
}

test('json prefix tracker accepts every prefix of valid JSON, in any chunking', () => {
  const docs = [
    JSON.stringify({ path: 'a/b.py', content: 'def f():\n    return "x\\y" é \t', mode: 'write', n: -12.5e-3, ok: true, none: null, list: [1, [2, { a: [] }], {}], nested: { k: 'v' } }),
    '  {"a" : 1 , "b" : [ true , false , null , 0 , 1.5 , -2e10 ] }  ',
    '[]', '{}', '"just a string"', '42', 'null',
    JSON.stringify({ unicode: '\\u00e9 and 😀', escaped: 'quote " backslash \\ newline \n' }),
  ];
  for (const doc of docs) {
    for (const chunk of [1, 3, 7, 1000]) {
      assert.equal(feedByChar(doc, chunk), -1, `rejected valid JSON at chunk ${chunk}: ${doc.slice(0, 40)}`);
    }
  }
});

test('json prefix tracker rejects an undeclared top-level key as soon as it closes', () => {
  const tracker = createJsonPrefixTracker({ isKnownKey: (key) => ['path', 'content'].includes(key) });
  assert.equal(tracker.feed('{"content='), true);
  assert.equal(tracker.feed('"'), false);
  assert.equal(tracker.reason, 'unknown_argument_key');

  const nested = createJsonPrefixTracker({ isKnownKey: (key) => key === 'edits' });
  assert.equal(nested.feed('{"edits":[{"oldText":"a","newText":"b"}]}'), true, 'nested keys are not checked');
});

test('json prefix tracker rejects malformed JSON at the first bad byte', () => {
  assert.equal(feedByChar('{"content=":"x"}'), -1, 'well-formed JSON with an odd key is a JSON problem for the key check, not this one');
  assert.ok(feedByChar('{"a":1,}') >= 0);
  assert.ok(feedByChar('{"a" 1}') >= 0);
  assert.ok(feedByChar('[1 2]') >= 0);
  assert.ok(feedByChar('{"a":tru e}') >= 0);
  assert.ok(feedByChar('{"a":1} x') >= 0);
  assert.ok(feedByChar('{"a":01}') >= 0);
  assert.ok(feedByChar('[1,]') >= 0);
  assert.equal(feedByChar('{"a":{},"b":[[]]}'), -1);
});

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
