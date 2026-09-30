'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const worldNews = require('../../../server/services/tasks/adapters/world_news');
const { fetchTriggerRows } = require('../../../server/services/tasks/integration_runtime');

const connectedNews = {
  getConnectionById: () => ({
    id: 9,
    provider_key: 'news',
    app_key: 'headlines',
    status: 'connected',
    account_email: 'news:gnews',
  }),
};

function feedManager(articles, calls = []) {
  return {
    async executeTool(_userId, toolName, args) {
      calls.push({ toolName, args });
      return { count: articles.length, articles };
    },
  };
}

const articles = [
  { id: 'b', title: 'Second', publishedAt: '2026-09-30T11:00:00Z', source: 'Wire' },
  { id: 'a', title: 'First', publishedAt: '2026-09-30T10:00:00Z', source: 'Wire' },
];

test('world news trigger normalizes config and rejects unknown categories', async () => {
  const context = { integrationManager: connectedNews, userId: null };
  const config = await worldNews.validateConfig({
    connectionId: 9,
    topics: ' ceasefire ',
    checkIntervalMinutes: 1,
  }, context);

  assert.equal(config.category, 'world');
  assert.equal(config.query, 'ceasefire');
  assert.equal(config.lang, 'en');
  assert.equal(config.checkIntervalMinutes, 15);
  await assert.rejects(
    worldNews.validateConfig({ connectionId: 9, category: 'gossip' }, context),
    /category must be one of/,
  );
});

test('world news polling batches only articles newer than the checkpoint and honours the interval', async () => {
  const calls = [];
  const base = {
    integrationManager: feedManager(articles, calls),
    userId: null,
    agentId: null,
    triggerType: 'world_news',
    config: { connectionId: 9, category: 'world', lang: 'en', checkIntervalMinutes: 30 },
  };

  const first = await fetchTriggerRows({ ...base, taskId: 101 });
  assert.equal(calls[0].toolName, 'news_get_headlines');
  assert.equal(first.length, 1);
  assert.equal(first[0].fingerprint, 'news:9:2026-09-30T11:00:00Z:b');
  assert.deepEqual(first[0].context.triggerEvent.articles.map((a) => a.title), ['First', 'Second']);

  assert.deepEqual(await fetchTriggerRows({ ...base, taskId: 101 }), []);
  assert.equal(calls.length, 1);

  const resumed = await fetchTriggerRows({
    ...base,
    taskId: 102,
    checkpoint: 'news:9:2026-09-30T10:00:00Z:a',
  });
  assert.deepEqual(resumed[0].context.triggerEvent.articles.map((a) => a.title), ['Second']);

  const caughtUp = await fetchTriggerRows({
    ...base,
    taskId: 103,
    checkpoint: first[0].fingerprint,
  });
  assert.deepEqual(caughtUp, []);
});
