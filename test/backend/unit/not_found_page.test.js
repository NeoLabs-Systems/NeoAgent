'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const request = require('supertest');
const { registerStaticRoutes } = require('../../../server/http/static');

test('an unknown page in a browser gets the 404 page, API clients do not', async () => {
  const app = express();
  registerStaticRoutes(app);

  const page = await request(app).get('/no/such/page').set('Accept', 'text/html,application/xhtml+xml,*/*;q=0.8');
  assert.equal(page.status, 404);
  assert.match(page.headers['content-type'], /^text\/html/);
  assert.match(page.text, /It's not here/);

  for (const [url, accept] of [['/no/such/page', 'application/json'], ['/api/nope', 'text/html']]) {
    const api = await request(app).get(url).set('Accept', accept);
    assert.equal(api.status, 404, url);
    assert.doesNotMatch(api.text, /It's not here/, `${url} ${accept}`);
  }
});
