'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const worldNews = require('../../../server/services/tasks/adapters/world_news');
const { fetchTriggerRows, pollTriggerTask } = require('../../../server/services/tasks/trigger_polling');

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

test('world news polling batches only articles newer than the checkpoint', async () => {
  const calls = [];
  const base = {
    integrationManager: feedManager(articles, calls),
    userId: null,
    agentId: null,
    triggerType: 'world_news',
    config: { connectionId: 9, category: 'world', lang: 'en', checkIntervalMinutes: 30 },
  };

  const first = await fetchTriggerRows(base);
  assert.equal(calls[0].toolName, 'news_get_headlines');
  assert.equal(first.length, 1);
  assert.equal(first[0].fingerprint, 'news:9:2026-09-30T11:00:00Z:b');
  assert.deepEqual(first[0].context.triggerEvent.articles.map((a) => a.title), ['First', 'Second']);

  const resumed = await fetchTriggerRows({ ...base, checkpoint: 'news:9:2026-09-30T10:00:00Z:a' });
  assert.deepEqual(resumed[0].context.triggerEvent.articles.map((a) => a.title), ['Second']);

  assert.deepEqual(await fetchTriggerRows({ ...base, checkpoint: first[0].fingerprint }), []);
});

test('world news tasks poll on their own interval', async () => {
  const calls = [];
  const runtime = {
    integrationManager: feedManager(articles, calls),
    taskRepository: { markTaskTriggerCheckpoint() {} },
    fireTaskFromTrigger: async () => ({}),
  };
  const task = {
    id: 101,
    user_id: null,
    agent_id: null,
    trigger_type: 'world_news',
    trigger_config: JSON.stringify({ connectionId: 9, category: 'world', lang: 'en', checkIntervalMinutes: 30 }),
    last_trigger_fingerprint: '',
  };
  const start = Date.parse('2026-09-30T12:00:00Z');

  await pollTriggerTask(runtime, task, { now: start });
  await pollTriggerTask(runtime, task, { now: start + 29 * 60 * 1000 });
  assert.equal(calls.length, 1);
  await pollTriggerTask(runtime, task, { now: start + 30 * 60 * 1000 });
  assert.equal(calls.length, 2);
});
