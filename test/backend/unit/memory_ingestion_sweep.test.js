'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  MemoryIngestionService,
} = require('../../../server/services/memory/ingestion');
const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

const gmailConnection = {
  id: 7,
  user_id: 10,
  agent_id: 'agent-10',
  provider_key: 'google_workspace',
  app_key: 'gmail',
  account_email: 'person@example.com',
  status: 'connected',
};

function createSweepService({
  jobs = [],
  documents = [],
  ingestedIds = [],
  database,
  collectError = null,
} = {}) {
  const calls = { collect: [], ingest: [], extract: [], credentials: [], emitted: [] };
  const service = new MemoryIngestionService({
    database,
    io: {
      to: (room) => ({
        emit: (event, payload) => calls.emitted.push({ room, event, payload }),
      }),
    },
    memoryManager: {
      listIngestionJobs: () => jobs,
      recordIngestionJob: (_userId, job) => job.id,
      listIngestedObjectIds: () => new Set(ingestedIds),
      countMemoriesCreatedSince: (ids) => ids.length - 1,
    },
    integrationManager: {
      getProvider: () => ({
        async collectMemorySweep(options) {
          calls.collect.push(options);
          if (collectError) throw collectError;
          options.onProgress(1, documents.length);
          return {
            documents,
            cursor: {},
            credentials: { access_token: 'refreshed' },
          };
        },
      }),
      saveRefreshedCredentials: (connection, credentials) => {
        calls.credentials.push({ connectionId: connection.id, credentials });
      },
    },
  });
  service.ingestDocuments = async (userId, docs, options) => {
    calls.ingest.push({ userId, docs, options });
    options.onProgress(docs.length, docs.length);
    return {
      status: 'completed',
      documentIds: docs.map((doc) => doc.externalObjectId),
      memoryIds: ['memory-new', 'memory-existing'],
    };
  };
  return { service, calls };
}

test('sweep collects past mail and learns from it as the mailbox owner', async () => {
  const { service, calls } = createSweepService({
    documents: [{ externalObjectId: 'thread-1', title: 'Contract renewal' }],
  });

  const result = await service.sweepConnection(gmailConnection);

  assert.equal(result.status, 'completed');
  assert.equal(calls.collect.length, 1);
  assert.equal(calls.ingest[0].options.metadata.mode, 'sweep');
  assert.equal(calls.ingest[0].options.connectionId, 7);
  assert.equal(calls.ingest[0].options.agentId, 'agent-10');
  assert.deepEqual(calls.ingest[0].options.owner, { email: 'person@example.com', name: null });
  assert.deepEqual(calls.credentials, [
    { connectionId: 7, credentials: { access_token: 'refreshed' } },
  ]);
});

test('sweep runs once per connection', async () => {
  const { service, calls } = createSweepService({
    jobs: [{ connectionId: 7, status: 'completed', metadata: { mode: 'sweep' } }],
  });

  const result = await service.sweepConnection(gmailConnection);

  assert.equal(result.status, 'already_swept');
  assert.equal(calls.collect.length, 0);
  assert.equal(calls.extract.length, 0);
});

test('sweep skips connections that carry no mail', async () => {
  const { service, calls } = createSweepService();

  const result = await service.sweepConnection({ ...gmailConnection, app_key: 'calendar' });

  assert.equal(result.status, 'not_supported');
  assert.equal(calls.collect.length, 0);
});

test('a new connection sweeps only when opted in', async () => {
  const optedOut = createSweepService();
  await optedOut.service.handleConnected({ connection: gmailConnection, memorySweep: false });
  assert.equal(optedOut.calls.collect.length, 0);

  const optedIn = createSweepService();
  await optedIn.service.handleConnected({ connection: gmailConnection, memorySweep: true });
  assert.equal(optedIn.calls.collect.length, 1);
});

test('finishing OAuth emits connected with the sweep choice from the connect request', async () => {
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db, { username: 'oauth_sweep_user' });
    const { IntegrationManager } = require('../../../server/services/integrations/manager');
    const states = [];
    let account = 0;
    const provider = {
      key: 'test_oauth',
      label: 'Test OAuth',
      requiresRefreshToken: false,
      getApp: (appKey) => appKey === 'mail' ? { id: 'mail' } : null,
      getEnvStatus: () => ({ configured: true }),
      beginOAuth({ state }) {
        states.push(state);
        return { url: `https://provider.example.test/authorize?state=${state}` };
      },
      async finishOAuth() {
        account += 1;
        return {
          accountEmail: `person${account}@example.test`,
          credentials: { access_token: 'access-token' },
          scopes: ['mail.read'],
        };
      },
    };
    const manager = new IntegrationManager();
    manager.registry = {
      get: (key) => key === provider.key ? provider : null,
      list: () => [provider],
    };
    const events = [];
    manager.events.on('connected', (event) => events.push(event));

    await manager.beginOAuth(user.userId, provider.key, { appKey: 'mail', memorySweep: true });
    await manager.finishOAuth(states[0], 'code-1');
    await manager.beginOAuth(user.userId, provider.key, { appKey: 'mail' });
    await manager.finishOAuth(states[1], 'code-2');

    assert.equal(events.length, 2);
    assert.equal(events[0].memorySweep, true);
    assert.equal(events[0].connection.account_email, 'person1@example.test');
    assert.equal(events[1].memorySweep, false);
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('a repeat sweep runs again and skips threads already in memory', async () => {
  const { service, calls } = createSweepService({
    jobs: [{ connectionId: 7, status: 'completed', metadata: { mode: 'sweep' } }],
    ingestedIds: ['thread-1'],
  });

  const result = await service.sweepConnection(gmailConnection, { repeat: true });

  assert.equal(result.status, 'completed');
  assert.deepEqual([...calls.collect[0].skipObjectIds], ['thread-1']);
});

test('sweeping an app repeats the sweep for each of its connected accounts', async () => {
  const second = { ...gmailConnection, id: 8, account_email: 'other@example.com' };
  let queried = null;
  const { service, calls } = createSweepService({
    jobs: [{ connectionId: 7, status: 'completed', metadata: { mode: 'sweep' } }],
    database: {
      prepare: () => ({
        all: (...params) => {
          queried = params;
          return [gmailConnection, second];
        },
      }),
    },
  });

  const connectionIds = service.sweepApp(10, {
    agentId: 'agent-10',
    providerKey: 'google_workspace',
    appKey: 'gmail',
  });
  await Promise.all([...service.activeConnections.values()]);

  assert.deepEqual(connectionIds, [7, 8]);
  assert.deepEqual(queried.slice(2), ['google_workspace', 'gmail']);
  assert.deepEqual(calls.ingest.map((call) => call.options.connectionId), [7, 8]);
});

test('integration snapshots mark only sweepable mail apps as feeding memory', async () => {
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db, { username: 'snapshot_sweep_user' });
    // The test runtime swaps the database module, so load the service fresh.
    const { MemoryIngestionService: FreshService } = require('../../../server/services/memory/ingestion');
    const service = new FreshService({
      memoryManager: { listIngestionJobs: () => [] },
      integrationManager: {
        getProvider: (key) => (key === 'google_workspace' ? { collectMemorySweep() {} } : {}),
      },
    });
    const snapshot = (id, appIds) => ({
      id,
      apps: appIds.map((appId) => ({ id: appId, connection: { connected: true }, accounts: [] })),
    });

    const google = service.decorateProviderSnapshot(
      snapshot('google_workspace', ['gmail', 'calendar']),
      user.userId,
    );
    const microsoft = service.decorateProviderSnapshot(snapshot('microsoft_365', ['outlook']), user.userId);

    const [gmail, calendar] = google.apps;
    assert.equal(gmail.memorySweep, true);
    assert.equal(gmail.memoryCoverage.supported, true);
    assert.equal(calendar.memorySweep, false);
    assert.equal(calendar.memoryCoverage.supported, false);
    assert.equal(microsoft.apps[0].memorySweep, false);
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('a sweep reports each phase live and keeps the result for the snapshot', async () => {
  const { service, calls } = createSweepService({
    documents: [
      { externalObjectId: 'thread-1', title: 'Contract renewal' },
      { externalObjectId: 'thread-2', title: 'Offsite' },
    ],
  });

  await service.sweepConnection(gmailConnection);

  const events = calls.emitted.map((entry) => entry.payload);
  assert.ok(calls.emitted.every((entry) => entry.room === 'user:10'
    && entry.event === 'memory:sweep_progress'));
  assert.deepEqual(
    events.map((event) => [event.state, event.phase]),
    [
      ['running', 'reading'],
      ['running', 'learning'],
      ['completed', 'learning'],
    ],
  );
  assert.equal(events[0].connectionId, 7);
  assert.equal(events[0].appKey, 'gmail');
  const finalState = service.getSweepProgress(7);
  assert.equal(finalState.state, 'completed');
  assert.equal(finalState.imported, 2);
  // One of the two ids resolved to a memory that already existed.
  assert.equal(finalState.learned, 1);
  assert.equal(finalState.done, 2);
  assert.equal(finalState.total, 2);
});

test('a failed sweep reports the failure', async () => {
  const { service, calls } = createSweepService({ collectError: new Error('Gmail is unreachable') });

  const result = await service.sweepConnection(gmailConnection);

  assert.equal(result.status, 'failed');
  const last = calls.emitted.at(-1).payload;
  assert.equal(last.state, 'failed');
  assert.equal(last.error, 'Gmail is unreachable');
});
