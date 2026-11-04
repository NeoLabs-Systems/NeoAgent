'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

const font = fs.readFileSync(path.join(__dirname,
  '../../../firmware/neoagent_wearable_stickc_plus2/components/board_support/fonts/neoagent_latin_16.c'), 'utf8');

test('StickC font contains German characters in the format supported by LVGL', () => {
  assert.match(font, /\.bitmap_format\s*=\s*0/);
  for (const codepoint of ['00C4', '00D6', '00DC', '00DF', '00E4', '00F6', '00FC']) {
    assert.ok(font.includes(`U+${codepoint}`), `missing U+${codepoint}`);
  }
});
