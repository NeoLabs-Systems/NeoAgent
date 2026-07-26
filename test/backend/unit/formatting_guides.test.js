'use strict';

const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

const {
  getPlatformFormattingProfile,
  normalizeOutgoingMessageForPlatform,
  splitOutgoingMessageForPlatform,
  buildPlatformFormattingGuide,
} = require('../../../server/services/messaging/formatting_guides');

// ── getPlatformFormattingProfile ────────────────────────────────────────────

describe('getPlatformFormattingProfile', () => {
  it('returns telnyx spoken-only profile', () => {
    const p = getPlatformFormattingProfile('telnyx');
    assert.equal(p.spokenOnly, true);
    assert.equal(p.inlineCode, false);
  });

  it('returns whatsapp non-spoken profile', () => {
    const p = getPlatformFormattingProfile('whatsapp');
    assert.equal(p.spokenOnly, false);
    assert.equal(p.inlineCode, true);
  });

  it('falls back to default for unknown platform', () => {
    const p = getPlatformFormattingProfile('unknown_platform');
    const def = getPlatformFormattingProfile('default');
    assert.deepEqual(p, def);
  });

  it('is case-insensitive', () => {
    const p = getPlatformFormattingProfile('TELNYX');
    assert.equal(p.spokenOnly, true);
  });

  it('handles null/undefined platform', () => {
    assert.doesNotThrow(() => getPlatformFormattingProfile(null));
    assert.doesNotThrow(() => getPlatformFormattingProfile(undefined));
  });
});

// ── normalizeOutgoingMessageForPlatform ─────────────────────────────────────

describe('normalizeOutgoingMessageForPlatform', () => {
  it('strips [NO RESPONSE] marker by default', () => {
    const result = normalizeOutgoingMessageForPlatform('default', 'Hello [NO RESPONSE] world');
    assert.ok(!result.includes('[NO RESPONSE]'));
  });

  it('preserves [NO RESPONSE] when stripNoResponseMarker is false', () => {
    const result = normalizeOutgoingMessageForPlatform('default', 'hello [NO RESPONSE]', {
      stripNoResponseMarker: false,
    });
    assert.ok(result.includes('[NO RESPONSE]'));
  });

  it('strips raw HTML tags', () => {
    const result = normalizeOutgoingMessageForPlatform('default', '<b>bold</b> text');
    assert.ok(!result.includes('<b>'));
    assert.ok(result.includes('bold text'));
  });

  it('collapses markdown code fences for whatsapp', () => {
    // normalizeVisualMarkdown is only applied by platform-specific adapters (whatsapp, telnyx)
    const input = '```js\nconsole.log("hi")\n```';
    const result = normalizeOutgoingMessageForPlatform('whatsapp', input);
    assert.ok(!result.includes('```'));
    assert.ok(result.includes('console.log'));
  });

  it('collapses markdown tables for whatsapp', () => {
    const input = '| A | B |\n|---|---|\n| 1 | 2 |';
    const result = normalizeOutgoingMessageForPlatform('whatsapp', input);
    assert.ok(!result.includes('|---|'));
    assert.ok(result.includes('A - B'));
    assert.ok(result.includes('1 - 2'));
  });

  it('normalises list markers to single dash for whatsapp', () => {
    const input = '* item one\n+ item two\n- item three';
    const result = normalizeOutgoingMessageForPlatform('whatsapp', input);
    assert.ok(!result.includes('* '));
    assert.ok(!result.includes('+ '));
  });

  it('converts literal newline tokens for whatsapp', () => {
    const input = 'first line /n second line\\nthird line';
    const result = normalizeOutgoingMessageForPlatform('whatsapp', input);
    assert.equal(result, 'first line\nsecond line\nthird line');
  });

  it('does not convert slash-n at the start of a word for whatsapp', () => {
    const input = 'See https://example.com/news for details';
    const result = normalizeOutgoingMessageForPlatform('whatsapp', input);
    assert.equal(result, input);
  });

  it('strips bold markdown for telnyx spoken output', () => {
    const result = normalizeOutgoingMessageForPlatform('telnyx', '**important** word');
    assert.ok(!result.includes('**'));
  });

  it('telnyx flattens newlines to spaces', () => {
    const result = normalizeOutgoingMessageForPlatform('telnyx', 'line one\nline two');
    assert.ok(!result.includes('\n'));
    assert.ok(result.includes('line one'));
    assert.ok(result.includes('line two'));
  });

  it('coerces object content with text key', () => {
    const result = normalizeOutgoingMessageForPlatform('default', { text: 'hello from object' });
    assert.ok(result.includes('hello from object'));
  });

  it('coerces object content with content key', () => {
    const result = normalizeOutgoingMessageForPlatform('default', { content: 'from content key' });
    assert.ok(result.includes('from content key'));
  });

  it('coerces null to empty string', () => {
    const result = normalizeOutgoingMessageForPlatform('default', null);
    assert.equal(result, '');
  });

  it('coerces number to string', () => {
    const result = normalizeOutgoingMessageForPlatform('default', 42);
    assert.ok(result.includes('42'));
  });

  it('collapses 3+ blank lines to double newline', () => {
    const result = normalizeOutgoingMessageForPlatform('default', 'a\n\n\n\nb');
    assert.ok(!result.includes('\n\n\n'));
  });
});

// ── splitOutgoingMessageForPlatform ─────────────────────────────────────────

describe('splitOutgoingMessageForPlatform', () => {
  it('returns empty array for empty content', () => {
    const result = splitOutgoingMessageForPlatform('default', '');
    assert.deepEqual(result, []);
  });

  it('splits on double newlines for chat platforms', () => {
    const result = splitOutgoingMessageForPlatform('default', 'para one\n\npara two');
    assert.equal(result.length, 2);
    assert.equal(result[0], 'para one');
    assert.equal(result[1], 'para two');
  });

  it('returns single chunk for telnyx (spoken-only, no splitting)', () => {
    const result = splitOutgoingMessageForPlatform('telnyx', 'sentence one\n\nsentence two');
    assert.equal(result.length, 1);
  });

  it('returns single chunk when no paragraph breaks', () => {
    const result = splitOutgoingMessageForPlatform('default', 'single paragraph text');
    assert.deepEqual(result, ['single paragraph text']);
  });

  it('filters out empty chunks', () => {
    const result = splitOutgoingMessageForPlatform('default', 'a\n\n\n\nb');
    assert.ok(result.every((chunk) => chunk.trim().length > 0));
  });

  it('preserves [NO RESPONSE] marker in split output (stripping is caller responsibility)', () => {
    // splitOutgoingMessageForPlatform passes stripNoResponseMarker:false so the
    // marker survives and callers can inspect the chunks before sending.
    const result = splitOutgoingMessageForPlatform('default', '[NO RESPONSE]');
    assert.deepEqual(result, ['[NO RESPONSE]']);
  });
});

// ── buildPlatformFormattingGuide ────────────────────────────────────────────

describe('buildPlatformFormattingGuide', () => {
  it('returns a non-empty string', () => {
    const guide = buildPlatformFormattingGuide('default');
    assert.ok(typeof guide === 'string' && guide.length > 0);
  });

  it('omits intro when options.intro is false', () => {
    const guide = buildPlatformFormattingGuide('default', { intro: false });
    assert.ok(!guide.startsWith('Reply formatting guide:'));
  });
});
