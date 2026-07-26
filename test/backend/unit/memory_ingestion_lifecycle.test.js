'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  MemoryIngestionService,
} = require('../../../server/services/memory/ingestion');

function deferred() {
  let resolve;
  const promise = new Promise((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

function createMemoryManager() {
  const jobs = [];
  return {
    jobs,
    listIngestionJobs() {
      return [];
    },
    recordIngestionJob(_userId, job) {
      jobs.push(job);
      return job.id;
    },
  };
}

function createTimerHarness() {
  const timers = [];
  const cleared = [];
  return {
    timers,
    cleared,
    setIntervalFn(callback, delay) {
      const timer = { callback, delay, unref() {} };
      timers.push(timer);
      return timer;
    },
    clearIntervalFn(timer) {
      cleared.push(timer);
    },
  };
}

test('memory ingestion start is idempotent and runs an immediate refresh', async () => {
  const timerHarness = createTimerHarness();
  let queryCount = 0;
  const service = new MemoryIngestionService({
    memoryManager: createMemoryManager(),
    intervalMs: 5000,
    database: {
      prepare() {
        return {
          all() {
            queryCount += 1;
            return [];
          },
        };
      },
    },
    ...timerHarness,
  });

  assert.equal(service.start().state, 'running');
  assert.equal(service.start().state, 'running');
  await service.refreshDueConnections();

  assert.equal(timerHarness.timers.length, 1);
  assert.equal(timerHarness.timers[0].delay, 5000);
  assert.equal(queryCount, 1);
  assert.equal((await service.stop()).state, 'stopped');
  assert.equal(timerHarness.cleared.length, 1);
});

test('memory ingestion isolates provider failures and continues later connections', async () => {
  const memoryManager = createMemoryManager();
  const connections = [
    {
      id: 1,
      user_id: 10,
      agent_id: 'agent-10',
      provider_key: 'google_workspace',
      app_key: 'gmail',
      account_email: 'first@example.com',
      status: 'connected',
    },
    {
      id: 2,
      user_id: 20,
      agent_id: 'agent-20',
      provider_key: 'microsoft_365',
      app_key: 'outlook',
      account_email: 'second@example.com',
      status: 'connected',
    },
  ];
  const service = new MemoryIngestionService({
    memoryManager,
    integrationManager: {
      getProvider(providerKey) {
        if (providerKey === 'google_workspace') {
          return {
            async collectMemoryDocuments() {
              throw new Error('provider unavailable');
            },
          };
        }
        return {};
      },
    },
    database: {
      prepare() {
        return { all: () => connections };
      },
    },
  });

  const result = await service.refreshDueConnections();

  assert.equal(result.refreshed, 2);
  assert.deepEqual(result.results.map((entry) => entry.status), ['failed', 'ready']);
  assert.equal(memoryManager.jobs.length, 2);
  assert.equal(memoryManager.jobs[0].connectionId, 1);
  assert.equal(memoryManager.jobs[0].status, 'failed');
  assert.equal(memoryManager.jobs[0].error, 'provider unavailable');
  assert.equal(memoryManager.jobs[1].connectionId, 2);
  assert.equal(memoryManager.jobs[1].status, 'ready');
  assert.equal(service.getStatus().lastError, 'provider unavailable');
});

test('memory ingestion coalesces duplicate connection refreshes', async () => {
  const release = deferred();
  let refreshCount = 0;
  const service = new MemoryIngestionService({
    memoryManager: createMemoryManager(),
  });
  service.refreshConnection = async () => {
    refreshCount += 1;
    await release.promise;
    return { connectionId: 1, status: 'completed' };
  };
  const connection = { id: 1, user_id: 10 };

  const first = service._refreshConnectionSafely(connection);
  const second = service._refreshConnectionSafely(connection);
  assert.equal(first, second);
  assert.equal(refreshCount, 0);

  await Promise.resolve();
  assert.equal(refreshCount, 1);
  release.resolve();
  assert.equal((await first).status, 'completed');
});

test('memory ingestion stop waits for active refresh and rejects later work', async () => {
  const timerHarness = createTimerHarness();
  const refreshStarted = deferred();
  const releaseRefresh = deferred();
  const connection = { id: 1, user_id: 10 };
  const service = new MemoryIngestionService({
    memoryManager: createMemoryManager(),
    intervalMs: 5000,
    database: {
      prepare() {
        return { all: () => [connection] };
      },
    },
    ...timerHarness,
  });
  service.refreshConnection = async () => {
    refreshStarted.resolve();
    await releaseRefresh.promise;
    return { connectionId: 1, status: 'completed' };
  };
  service.start();
  await refreshStarted.promise;

  let stopCompleted = false;
  const stop = service.stop().then((status) => {
    stopCompleted = true;
    return status;
  });
  assert.deepEqual(
    await service.refreshDueConnections(),
    { skipped: true, reason: 'service_stopping' },
  );
  await Promise.resolve();
  assert.equal(stopCompleted, false);

  releaseRefresh.resolve();
  assert.equal((await stop).state, 'stopped');
  assert.equal(service.getStatus().activeConnectionCount, 0);
});

test('memory ingestion rejects invalid polling intervals', () => {
  assert.throws(
    () => new MemoryIngestionService({
      memoryManager: createMemoryManager(),
      intervalMs: 999,
    }),
    /greater than or equal to 1000/,
  );
});

test('memory ingestion stop aborts a cooperative provider without recording a failure', async () => {
  const timerHarness = createTimerHarness();
  const collectorStarted = deferred();
  const memoryManager = createMemoryManager();
  const connection = {
    id: 1,
    user_id: 10,
    agent_id: 'agent-10',
    provider_key: 'google_workspace',
    app_key: 'gmail',
    account_email: 'user@example.com',
    status: 'connected',
  };
  const service = new MemoryIngestionService({
    memoryManager,
    integrationManager: {
      getProvider() {
        return {
          collectMemoryDocuments({ signal }) {
            collectorStarted.resolve(signal);
            return new Promise((_, reject) => {
              signal.addEventListener('abort', () => reject(signal.reason), { once: true });
            });
          },
        };
      },
    },
    intervalMs: 5000,
    database: {
      prepare() {
        return { all: () => [connection] };
      },
    },
    ...timerHarness,
  });

  service.start();
  const signal = await collectorStarted.promise;
  const status = await service.stop();

  assert.equal(signal.aborted, true);
  assert.equal(status.state, 'stopped');
  assert.equal(status.lastError, null);
  assert.equal(memoryManager.jobs.some((job) => job.status === 'failed'), false);
});

test('caller cancellation marks an in-progress ingestion job as cancelled', async () => {
  const saveStarted = deferred();
  const memoryManager = {
    ...createMemoryManager(),
    upsertIngestionDocument() {
      return 'document-1';
    },
    saveMemory(_userId, _content, _category, _importance, { signal }) {
      saveStarted.resolve();
      return new Promise((_, reject) => {
        signal.addEventListener('abort', () => reject(signal.reason), { once: true });
      });
    },
  };
  const service = new MemoryIngestionService({ memoryManager });
  const controller = new AbortController();
  const pending = service.ingestDocuments(null, [{
    externalObjectId: 'message-1',
    sourceType: 'email',
    title: 'Subject',
    content: 'A durable source document with enough content to create a chunk.',
  }], {
    sourceType: 'email',
    signal: controller.signal,
  });
  await saveStarted.promise;

  const reason = new Error('request disconnected');
  controller.abort(reason);
  await assert.rejects(pending, (error) => error === reason);
  assert.equal(memoryManager.jobs.at(-1).status, 'cancelled');
  assert.equal(memoryManager.jobs.at(-1).error, null);
  assert.equal(memoryManager.jobs.at(-1).nextSyncAt, null);
});
