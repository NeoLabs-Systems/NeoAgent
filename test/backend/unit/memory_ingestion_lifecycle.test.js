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
    listIngestedObjectIds() {
      return new Set();
    },
    recordIngestionJob(_userId, job) {
      jobs.push(job);
      return job.id;
    },
  };
}

const gmailConnection = {
  id: 1,
  user_id: 10,
  agent_id: 'agent-10',
  provider_key: 'google_workspace',
  app_key: 'gmail',
  account_email: 'user@example.com',
  status: 'connected',
};

function createBlockingSweepService(memoryManager, collectorStarted) {
  let collectCount = 0;
  const service = new MemoryIngestionService({
    memoryManager,
    integrationManager: {
      getProvider() {
        return {
          collectMemorySweep({ signal }) {
            collectCount += 1;
            collectorStarted.resolve(signal);
            return new Promise((_, reject) => {
              signal.addEventListener('abort', () => reject(signal.reason), { once: true });
            });
          },
        };
      },
    },
  });
  return { service, collectCount: () => collectCount };
}

test('memory ingestion coalesces duplicate sweeps of one connection', async () => {
  const collectorStarted = deferred();
  const { service, collectCount } = createBlockingSweepService(
    createMemoryManager(),
    collectorStarted,
  );

  const first = service.sweepConnection(gmailConnection);
  const second = service.sweepConnection(gmailConnection);
  assert.equal(first, second);
  await collectorStarted.promise;
  assert.equal(collectCount(), 1);

  await service.stop();
  assert.equal((await first).status, 'cancelled');
});

test('memory ingestion stop aborts a running sweep without recording a failure', async () => {
  const collectorStarted = deferred();
  const memoryManager = createMemoryManager();
  const { service } = createBlockingSweepService(memoryManager, collectorStarted);

  const sweep = service.sweepConnection(gmailConnection);
  const signal = await collectorStarted.promise;
  const status = await service.stop();

  assert.equal(signal.aborted, true);
  assert.equal(status.state, 'stopped');
  assert.equal(status.lastError, null);
  assert.equal((await sweep).status, 'cancelled');
  assert.equal(memoryManager.jobs.some((job) => job.status === 'failed'), false);
  assert.equal(await service.handleConnected({ connection: gmailConnection, memorySweep: true }), null);
});

test('caller cancellation marks an in-progress ingestion job as cancelled', async () => {
  const extractStarted = deferred();
  const memoryManager = {
    ...createMemoryManager(),
    upsertIngestionDocument() {
      return 'document-1';
    },
  };
  const service = new MemoryIngestionService({
    memoryManager,
    extractFacts: (_userId, _agentId, { signal }) => {
      extractStarted.resolve();
      return new Promise((_, reject) => {
        signal.addEventListener('abort', () => reject(signal.reason), { once: true });
      });
    },
  });
  const controller = new AbortController();
  const pending = service.ingestDocuments(null, [{
    externalObjectId: 'message-1',
    sourceType: 'email',
    title: 'Subject',
    content: 'A durable source document with enough content to learn from.',
  }], {
    sourceType: 'email',
    signal: controller.signal,
  });
  await extractStarted.promise;

  const reason = new Error('request disconnected');
  controller.abort(reason);
  await assert.rejects(pending, (error) => error === reason);
  assert.equal(memoryManager.jobs.at(-1).status, 'cancelled');
  assert.equal(memoryManager.jobs.at(-1).error, null);
});
