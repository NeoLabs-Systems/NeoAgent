'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { extractForLLM } = require('../../../server/services/browser/contentExtractor');

test('browser content extractor converts HTML into LLM-readable markdown', () => {
  const result = extractForLLM(`
    <!doctype html>
    <html>
      <head>
        <title>ESP32 NodeMCU library</title>
        <meta name="description" content="Footprint and symbol downloads">
      </head>
      <body>
        <nav>Global navigation</nav>
        <main>
          <h1>ESP32 NodeMCU CH340</h1>
          <p>The Fusion library includes a symbol and a module footprint for the USB-C ESP32 board.</p>
          <a href="/downloads/esp32.kicad_mod">Download footprint</a>
        </main>
      </body>
    </html>
  `, { url: 'https://example.test/parts/esp32' });

  assert.equal(result.metadata.title, 'ESP32 NodeMCU library');
  assert.match(result.markdown, /ESP32 NodeMCU CH340/);
  assert.match(result.markdown, /Download footprint/);
  assert.ok(result.wordCount > 0);
});
