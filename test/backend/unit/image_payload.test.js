'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  decodeBase64Image,
  validateImageBuffer,
} = require('../../../server/utils/image_payload');

const ONE_PIXEL_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  'base64',
);

test('decodes a bounded PNG data URL and verifies its real byte type', () => {
  const image = decodeBase64Image(`data:image/png;base64,${ONE_PIXEL_PNG.toString('base64')}`);

  assert.equal(image.contentType, 'image/png');
  assert.equal(image.extension, 'png');
  assert.equal(image.width, 1);
  assert.equal(image.height, 1);
  assert.deepEqual(image.buffer, ONE_PIXEL_PNG);
});

test('rejects malformed base64 and MIME spoofing', () => {
  assert.throws(() => decodeBase64Image('%%%not-base64%%%'), /base64 payload is malformed/i);
  assert.throws(
    () => decodeBase64Image(`data:image/jpeg;base64,${ONE_PIXEL_PNG.toString('base64')}`),
    /type does not match/i,
  );
});

test('rejects oversized and non-image screenshot bytes', () => {
  const oversized = Buffer.concat([ONE_PIXEL_PNG, Buffer.alloc(2048)]);
  assert.throws(
    () => validateImageBuffer(oversized, { maxBytes: 1024 }),
    (error) => error.code === 'IMAGE_PAYLOAD_TOO_LARGE',
  );
  assert.throws(
    () => validateImageBuffer(Buffer.from('not an image')),
    /not a valid PNG or JPEG/i,
  );
});
