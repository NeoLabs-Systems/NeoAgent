'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

function deferred() {
  let resolve;
  const promise = new Promise((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

test('official OAuth state is claimed before token exchange and cannot race', async () => {
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db, { username: 'oauth_state_user' });
    const { IntegrationManager } = require('../../../server/services/integrations/manager');
    const exchangeStarted = deferred();
    const releaseExchange = deferred();
    let exchangeCount = 0;
    let issuedState = null;
    const provider = {
      key: 'test_oauth',
      label: 'Test OAuth',
      requiresRefreshToken: false,
      getApp: (appKey) => appKey === 'mail' ? { id: 'mail' } : null,
      getEnvStatus: () => ({ configured: true }),
      beginOAuth({ state }) {
        issuedState = state;
        return { url: `https://provider.example.test/authorize?state=${state}` };
      },
      async finishOAuth() {
        exchangeCount += 1;
        exchangeStarted.resolve();
        await releaseExchange.promise;
        return {
          accountEmail: 'person@example.test',
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

    await manager.beginOAuth(user.userId, provider.key, { appKey: 'mail' });
    const first = manager.finishOAuth(issuedState, 'authorization-code');
    await exchangeStarted.promise;

    await assert.rejects(
      manager.finishOAuth(issuedState, 'replayed-code'),
      /missing or expired/,
    );
    assert.equal(exchangeCount, 1);

    releaseExchange.resolve();
    const completed = await first;
    assert.equal(completed.accountEmail, 'person@example.test');
    assert.equal(
      ctx.db.prepare('SELECT COUNT(*) AS count FROM integration_oauth_states WHERE state = ?')
        .get(issuedState).count,
      0,
    );
  } finally {
    teardownTestRuntime(ctx);
  }
});
