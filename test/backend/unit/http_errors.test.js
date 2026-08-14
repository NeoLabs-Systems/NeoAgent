'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const express = require('express');
const request = require('supertest');

const { registerErrorHandler } = require('../../../server/http/errors');

function createErrorApp(error) {
  const app = express();
  app.get('/api/failure', () => {
    throw error;
  });
  registerErrorHandler(app);
  return app;
}

test('API errors expose stable machine codes for user-facing recovery', async () => {
  const error = new Error('The computer needs more free storage.');
  error.status = 507;
  error.code = 'COMPUTER_STORAGE_CAPACITY';

  const response = await request(createErrorApp(error))
    .get('/api/failure')
    .expect(507);

  assert.deepEqual(response.body, {
    error: 'The computer needs more free storage.',
    code: 'COMPUTER_STORAGE_CAPACITY',
  });
});

test('API errors do not expose arbitrary internal code values', async () => {
  const error = new Error('Request failed.');
  error.status = 500;
  error.code = 'private/path/value';

  const response = await request(createErrorApp(error))
    .get('/api/failure')
    .expect(500);

  assert.deepEqual(response.body, { error: 'Request failed.' });
});
