'use strict';

const assert = require('node:assert/strict');
const { describe, test } = require('node:test');

const {
  buildConnectedAppSummary,
  sortConnections,
  summarizeAccountRow,
  summarizeAppConnection,
  summarizeProviderConnection,
} = require('../../../server/services/integrations/connection_summary');

const CONFIGURED = { configured: true, missing: [], summary: '' };
const UNCONFIGURED = { configured: false, missing: ['CLIENT_ID'], summary: '' };

function connectionRow(overrides = {}) {
  return {
    id: 1,
    status: 'connected',
    account_email: 'a@example.com',
    last_connected_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    metadata_json: '{}',
    ...overrides,
  };
}

describe('integration connection summary', () => {
  test('reports the stored access mode rather than assuming read/write', () => {
    const readOnly = connectionRow({
      metadata_json: JSON.stringify({ access_mode: 'read_only' }),
    });
    assert.equal(summarizeAccountRow(readOnly, CONFIGURED).accessMode, 'read_only');
  });

  test('every account summary carries an access mode, including unconfigured envs', () => {
    const branches = [
      summarizeAccountRow(connectionRow(), CONFIGURED),
      summarizeAccountRow(null, CONFIGURED),
      summarizeAccountRow(connectionRow(), UNCONFIGURED),
      summarizeAccountRow(null, UNCONFIGURED),
    ];
    for (const account of branches) {
      assert.equal(account.accessMode, 'read_write');
    }
  });

  test('an unconfigured environment marks accounts as not connected', () => {
    const account = summarizeAccountRow(connectionRow(), UNCONFIGURED);
    assert.equal(account.status, 'env_not_configured');
    assert.equal(account.connected, false);
  });

  test('connections sort by account, then most recently updated first', () => {
    const rows = [
      connectionRow({ id: 1, account_email: 'b@example.com', updated_at: '2026-01-01' }),
      connectionRow({ id: 2, account_email: 'a@example.com', updated_at: '2026-01-01' }),
      connectionRow({ id: 3, account_email: 'a@example.com', updated_at: '2026-02-01' }),
    ];
    assert.deepEqual(sortConnections(rows).map((row) => row.id), [3, 2, 1]);
  });

  test('an app with a connected account is connected and exposes its tools', () => {
    const app = { id: 'mail', label: 'Mail', description: 'Mail app', toolDefinitions: [{}, {}, {}] };
    const snapshot = summarizeAppConnection(app, [connectionRow()], CONFIGURED);
    assert.equal(snapshot.connection.status, 'connected');
    assert.equal(snapshot.connection.accountCount, 1);
    assert.equal(snapshot.connection.accountEmail, 'a@example.com');
    assert.equal(snapshot.availableToolCount, 3);
  });

  test('an app with only an authorizing account reports that, and no tools', () => {
    const app = { id: 'mail', label: 'Mail', description: 'Mail app', toolDefinitions: [{}] };
    const snapshot = summarizeAppConnection(app, [connectionRow({ status: 'authorizing' })], CONFIGURED);
    assert.equal(snapshot.connection.status, 'authorizing');
    assert.equal(snapshot.connection.connected, false);
    assert.equal(snapshot.availableToolCount, 0);
  });

  test('an explicit tool count overrides the app definition', () => {
    const app = { id: 'home', label: 'Home', description: 'Home app' };
    const snapshot = summarizeAppConnection(app, [connectionRow()], CONFIGURED, { toolCount: 7 });
    assert.equal(snapshot.availableToolCount, 7);
  });

  test('several connected accounts hide the single-account email', () => {
    const app = { id: 'mail', label: 'Mail', description: 'Mail app', toolDefinitions: [] };
    const snapshot = summarizeAppConnection(app, [
      connectionRow({ id: 1, account_email: 'a@example.com', last_connected_at: '2026-01-01' }),
      connectionRow({ id: 2, account_email: 'b@example.com', last_connected_at: '2026-03-01' }),
    ], CONFIGURED);
    assert.equal(snapshot.connection.accountCount, 2);
    assert.equal(snapshot.connection.accountEmail, null);
    assert.equal(snapshot.connection.lastConnectedAt, '2026-03-01');
  });
});

describe('provider-level rollup', () => {
  const app = (id, accounts) => ({
    id,
    label: id,
    description: id,
    accounts,
    connection: { connected: accounts.some((a) => a.connected) },
    availableToolCount: accounts.some((a) => a.connected) ? 2 : 0,
  });
  const account = (email, connected, lastConnectedAt = null) => ({
    id: email,
    accountEmail: email,
    connected,
    lastConnectedAt,
  });

  test('a provider with no connected account reports not_connected and no tools', () => {
    const rollup = summarizeProviderConnection(
      [app('mail', [account('a@example.com', false)])],
      CONFIGURED,
    );
    assert.equal(rollup.connection.status, 'not_connected');
    assert.equal(rollup.connection.appCount, 0);
    assert.equal(rollup.availableToolCount, 0);
  });

  test('tool counts add up across connected apps', () => {
    const rollup = summarizeProviderConnection([
      app('mail', [account('a@example.com', true)]),
      app('drive', [account('a@example.com', true)]),
      app('chat', [account('b@example.com', false)]),
    ], CONFIGURED);
    assert.equal(rollup.connection.status, 'connected');
    assert.equal(rollup.connection.appCount, 2);
    assert.equal(rollup.connection.accountCount, 2);
    assert.equal(rollup.availableToolCount, 4);
  });

  test('an unconfigured environment outranks any connected account', () => {
    const rollup = summarizeProviderConnection(
      [app('mail', [account('a@example.com', true)])],
      UNCONFIGURED,
    );
    assert.equal(rollup.connection.status, 'env_not_configured');
  });

  test('the newest connection time wins across apps', () => {
    const rollup = summarizeProviderConnection([
      app('mail', [account('a@example.com', true, '2026-01-01')]),
      app('drive', [account('b@example.com', true, '2026-05-01')]),
    ], CONFIGURED);
    assert.equal(rollup.connection.lastConnectedAt, '2026-05-01');
    assert.equal(rollup.connection.accountEmail, null);
  });

  test('the model summary names every connected account', () => {
    const summary = buildConnectedAppSummary([
      app('mail', [account('a@example.com', true), account('b@example.com', false)]),
      app('drive', [account('c@example.com', true)]),
      app('chat', [account('d@example.com', false)]),
    ]);
    assert.equal(summary, 'mail: a@example.com | drive: c@example.com');
  });
});
