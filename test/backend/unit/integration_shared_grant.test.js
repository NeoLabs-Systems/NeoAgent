'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

test('Google connects only the apps whose scopes were all granted', () => {
  const {
    getGrantedAppIds,
    GOOGLE_ACCOUNT_IDENTITY_SCOPES,
    GOOGLE_WORKSPACE_APPS,
  } = require('../../../server/services/integrations/google/provider');
  const scopesOf = (id) => GOOGLE_WORKSPACE_APPS.find((app) => app.id === id).scopes;

  assert.deepEqual(
    getGrantedAppIds([
      ...GOOGLE_ACCOUNT_IDENTITY_SCOPES,
      ...GOOGLE_WORKSPACE_APPS.flatMap((app) => app.scopes),
    ]),
    GOOGLE_WORKSPACE_APPS.map((app) => app.id),
  );
  // The user unticked Drive, Docs and Sheets on the consent screen.
  assert.deepEqual(
    getGrantedAppIds([...scopesOf('gmail'), ...scopesOf('calendar')]),
    ['gmail', 'calendar'],
  );
});

test('one sign-in connects every app its grant covers, and the grant outlives one app', async () => {
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db, { username: 'shared_grant_user' });
    const { IntegrationManager } = require('../../../server/services/integrations/manager');
    let issuedState = null;
    const revoked = [];
    const provider = {
      key: 'test_suite',
      label: 'Test Suite',
      requiresRefreshToken: false,
      getApp: (appKey) => ['mail', 'calendar', 'files'].includes(appKey) ? { id: appKey } : null,
      getEnvStatus: () => ({ configured: true }),
      beginOAuth({ state }) {
        issuedState = state;
        return { url: `https://provider.example.test/authorize?state=${state}` };
      },
      async finishOAuth({ appKey }) {
        return {
          accountEmail: 'person@example.test',
          credentials: { access_token: 'access-token' },
          scopes: ['mail', 'calendar'],
          metadata: { appId: appKey },
          alsoConnectsAppIds: ['calendar'],
        };
      },
      async disconnect(connection) {
        revoked.push(connection.app_key);
      },
    };
    const manager = new IntegrationManager();
    manager.registry = {
      get: (key) => key === provider.key ? provider : null,
      list: () => [provider],
    };
    const connectedEvents = [];
    manager.events.on('connected', (event) => connectedEvents.push(event.connection.app_key));

    await manager.beginOAuth(user.userId, provider.key, { appKey: 'mail' });
    await manager.finishOAuth(issuedState, 'authorization-code');

    const rows = manager.listConnections(user.userId, provider.key);
    assert.deepEqual(rows.map((row) => row.app_key).sort(), ['calendar', 'mail']);
    assert.ok(rows.every((row) => row.status === 'connected'));
    assert.deepEqual(
      rows.map((row) => JSON.parse(row.metadata_json).appId).sort(),
      ['calendar', 'mail'],
    );
    // Only the app that was asked for runs its connect hooks (the mail import).
    assert.deepEqual(connectedEvents, ['mail']);

    const mail = rows.find((row) => row.app_key === 'mail');
    const calendar = rows.find((row) => row.app_key === 'calendar');
    await manager.disconnect(user.userId, provider.key, { connectionId: mail.id });
    assert.deepEqual(revoked, [], 'calendar still uses the grant');
    await manager.disconnect(user.userId, provider.key, { connectionId: calendar.id });
    assert.deepEqual(revoked, ['calendar'], 'the last app revokes the grant');
    assert.equal(manager.listConnections(user.userId, provider.key).length, 0);
  } finally {
    teardownTestRuntime(ctx);
  }
});
