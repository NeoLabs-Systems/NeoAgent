'use strict';

const assert = require('node:assert/strict');
const { after, before, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');
const { createTestApp, loginAs } = require('../helpers/app');
const { agent } = require('../helpers/supertest');

// Regression coverage: /api/screen-history/search used to pass the raw query
// straight into an FTS5 MATCH, so any hyphen or AND/OR/NOT keyword threw a
// query-time error and 500'd the request. It now routes through buildFtsQuery.
describe('screen history search route', () => {
  let ctx;
  let app;
  let client;
  let user;

  before(async () => {
    ctx = createTestRuntime();
    app = createTestApp().app;
    user = await createTestUser(ctx.db, { username: 'screen_user' });
    client = agent(app);
    await loginAs(client, user);

    ctx.db.prepare(
      'INSERT INTO screen_history (user_id, app_name, text_content) VALUES (?, ?, ?)'
    ).run(user.userId, 'Browser', 'opened the covid-19 vaccine dashboard and a status report');
  });

  after(() => teardownTestRuntime(ctx));

  test('hyphenated query returns 200 and finds the matching row', async () => {
    const res = await client.get('/api/screen-history/search').query({ q: 'covid-19' }).expect(200);
    assert.ok(Array.isArray(res.body.results));
    assert.equal(res.body.results.length, 1);
    assert.match(res.body.results[0].text_content, /covid-19 vaccine/);
  });

  test('FTS operator keywords no longer 500 the request', async () => {
    for (const q of ['AND report', 'OR status', 'NOT missing']) {
      const res = await client.get('/api/screen-history/search').query({ q }).expect(200);
      assert.ok(Array.isArray(res.body.results));
    }
  });

  test('query with no usable tokens returns an empty result set, not an error', async () => {
    const res = await client.get('/api/screen-history/search').query({ q: '!!' }).expect(200);
    assert.deepEqual(res.body.results, []);
  });
});
