'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  isGoogleApisHost,
  requireGoogleApiUrl,
} = require('../../../server/services/integrations/google/common');

test('Google API URLs pin to googleapis.com hosts over HTTPS', () => {
  assert.equal(isGoogleApisHost('www.googleapis.com'), true);
  assert.equal(isGoogleApisHost('sheets.googleapis.com'), true);
  assert.equal(isGoogleApisHost('googleapis.com'), true);
  assert.equal(isGoogleApisHost('evilgoogleapis.com'), false);
  assert.equal(isGoogleApisHost('googleapis.com.attacker.example'), false);

  assert.equal(
    requireGoogleApiUrl('/drive/v3/files'),
    'https://www.googleapis.com/drive/v3/files',
  );
  assert.equal(
    requireGoogleApiUrl('https://docs.googleapis.com/v1/documents/abc'),
    'https://docs.googleapis.com/v1/documents/abc',
  );
  assert.throws(
    () => requireGoogleApiUrl('https://evilgoogleapis.com/v1'),
    /googleapis\.com host/,
  );
  assert.throws(
    () => requireGoogleApiUrl('http://www.googleapis.com/v1'),
    /googleapis\.com host/,
  );
});
