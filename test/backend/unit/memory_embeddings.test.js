'use strict';

const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const https = require('node:https');
const { afterEach, test } = require('node:test');

const originalRequest = https.request;
const originalGoogleKey = process.env.GOOGLE_AI_KEY;
const originalOpenAIKey = process.env.OPENAI_API_KEY;

function restoreEnv(name, value) {
  if (value == null) delete process.env[name];
  else process.env[name] = value;
}

function installRequestMock(handler) {
  https.request = (options, callback) => {
    const request = new EventEmitter();
    request.destroyed = false;
    request.destroy = (error) => {
      request.destroyed = true;
      if (error) setImmediate(() => request.emit('error', error));
    };
    request.end = (body) => handler({ body, callback, options, request });
    return request;
  };
}

function respondJson(callback, payload, options = {}) {
  const response = new EventEmitter();
  response.statusCode = options.statusCode || 200;
  response.headers = options.headers || {};
  response.destroyed = false;
  response.destroy = () => {
    response.destroyed = true;
  };
  callback(response);
  if (!response.destroyed) {
    const body = Buffer.from(JSON.stringify(payload));
    response.emit('data', body);
    response.emit('end');
  }
  return response;
}

afterEach(() => {
  https.request = originalRequest;
  restoreEnv('GOOGLE_AI_KEY', originalGoogleKey);
  restoreEnv('OPENAI_API_KEY', originalOpenAIKey);
});

test('Google memory embeddings use the current model without putting the API key in the URL', async () => {
  process.env.GOOGLE_AI_KEY = 'google-test-key';
  delete process.env.OPENAI_API_KEY;
  let captured = null;
  installRequestMock(({ body, callback, options }) => {
    captured = { body: JSON.parse(body), options };
    setImmediate(() => respondJson(callback, {
      embedding: { values: Array(768).fill(0.25) },
    }));
  });

  const {
    GOOGLE_MODEL,
    getEmbeddingWithMetadata,
  } = require('../../../server/services/memory/embeddings');
  const result = await getEmbeddingWithMetadata('find this memory', 'google', {
    inputType: 'query',
  });

  assert.equal(GOOGLE_MODEL, 'gemini-embedding-2');
  assert.equal(result.model, GOOGLE_MODEL);
  assert.equal(result.dimensions, 768);
  assert.equal(captured.options.path, `/v1beta/models/${GOOGLE_MODEL}:embedContent`);
  assert.equal(captured.options.path.includes('google-test-key'), false);
  assert.equal(captured.options.headers['x-goog-api-key'], 'google-test-key');
  assert.equal(captured.body.output_dimensionality, 768);
  assert.match(captured.body.content.parts[0].text, /^task: search result \| query:/);
});

test('embedding requests preserve caller cancellation and tear down the socket', async () => {
  delete process.env.GOOGLE_AI_KEY;
  process.env.OPENAI_API_KEY = 'openai-test-key';
  let request = null;
  installRequestMock((context) => {
    request = context.request;
  });

  const { getEmbeddingWithMetadata } = require('../../../server/services/memory/embeddings');
  const controller = new AbortController();
  const pending = getEmbeddingWithMetadata('cancel me', 'openai', {
    signal: controller.signal,
  });
  await new Promise((resolve) => setImmediate(resolve));

  const reason = new Error('ingestion stopped');
  controller.abort(reason);
  await assert.rejects(pending, (error) => error === reason);
  assert.equal(request.destroyed, true);
});

test('embedding responses reject oversized bodies without buffering them', async () => {
  delete process.env.GOOGLE_AI_KEY;
  process.env.OPENAI_API_KEY = 'openai-test-key';
  let response = null;
  installRequestMock(({ callback }) => {
    setImmediate(() => {
      response = respondJson(callback, {}, {
        headers: { 'content-length': String(3 * 1024 * 1024) },
      });
    });
  });

  const { getEmbeddingWithMetadata } = require('../../../server/services/memory/embeddings');
  assert.equal(await getEmbeddingWithMetadata('too large', 'openai'), null);
  assert.equal(response.destroyed, true);
});
