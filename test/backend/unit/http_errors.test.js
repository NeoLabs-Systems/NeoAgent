'use strict';

const assert = require('node:assert/strict');
const path = require('node:path');
const { test } = require('node:test');
const express = require('express');
const request = require('supertest');

const { registerErrorHandler, sendJsonError } = require('../../../server/http/errors');

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

test('sendJsonError sanitizes server failures and keeps client errors', () => {
  const captured = {};
  const res = {
    status(code) {
      captured.status = code;
      return this;
    },
    json(body) {
      captured.body = body;
      return this;
    },
  };

  const leakedPath = `${path.join(__dirname, '../../..')}/.env`;
  const serverError = new Error(`Failed to read ${leakedPath}`);
  serverError.statusCode = 500;
  sendJsonError(res, serverError);
  assert.equal(captured.status, 500);
  assert.equal(captured.body.error.includes(leakedPath), false);
  assert.match(captured.body.error, /~|\[app\]|\[path\]/);

  const clientError = new Error('planId is required.');
  clientError.statusCode = 400;
  sendJsonError(res, clientError);
  assert.equal(captured.status, 400);
  assert.equal(captured.body.error, 'planId is required.');
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
