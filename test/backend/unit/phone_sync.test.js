'use strict';

const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;
afterEach(() => {
  teardownTestRuntime(ctx);
  ctx = null;
});

const DEVICE = { id: 'a1b2c3d4e5f60718', name: 'Pixel 9', platform: 'android' };

function soon(days) {
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();
}

async function setup() {
  ctx = createTestRuntime();
  const user = await createTestUser(ctx.db, { username: `phone_${Date.now()}` });
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  const agentId = ensureMainAgent(user.userId).id;
  const store = require('../../../server/services/integrations/phone/store');
  const { createPhoneProvider } = require('../../../server/services/integrations/phone/provider');
  const emitted = [];
  const provider = createPhoneProvider({ io: { to: () => ({ emit: (...event) => emitted.push(event) }) } });
  const connection = (appKey) => ctx.db.prepare(
    "SELECT * FROM integration_connections WHERE user_id=? AND provider_key='phone' AND app_key=?",
  ).get(user.userId, appKey);
  return { user, agentId, store, provider, emitted, connection };
}

test('a phone shares calendar and contacts, stored encrypted and read back by the tools', async () => {
  const { user, agentId, store, provider, connection } = await setup();
  const registered = store.registerDevice({ userId: user.userId, agentId, device: DEVICE, kinds: ['calendar', 'contacts', 'mail'] });
  assert.deepEqual(registered, { connected: true, kinds: ['calendar', 'contacts'], accountEmail: 'Pixel 9' });

  const synced = store.syncDevice({
    userId: user.userId,
    agentId,
    body: {
      deviceId: DEVICE.id,
      calendars: [{ id: '3', name: 'Work', account: 'me@example.test', writable: true, primary: true }],
      events: [
        { key: '9:1', eventId: '9', calendarId: '3', title: 'Dentist', start: soon(1), end: soon(1.05), attendees: ['Dr. Who'] },
        { key: '10:1', eventId: '10', calendarId: '3', title: 'Far away', start: soon(60), end: soon(60.1) },
      ],
      contacts: [{ key: 'k1', name: 'Ada Lovelace', emails: ['ada@example.test'], phones: ['+44 1'] }],
    },
  });
  assert.deepEqual(synced, { connected: true, kinds: ['calendar', 'contacts'], commands: [] });
  const raw = ctx.db.prepare("SELECT payload_json FROM device_sync_items WHERE kind='event' LIMIT 1").get();
  assert.match(raw.payload_json, /^enc:v1:/);

  const events = await provider.executeTool('phone_list_events', {}, connection('calendar'));
  assert.equal(events.result.device, 'Pixel 9');
  assert.ok(events.result.syncedAt);
  assert.deepEqual(events.result.events.map((event) => event.title), ['Dentist']);
  const contacts = await provider.executeTool('phone_search_contacts', { query: 'ada@' }, connection('contacts'));
  assert.equal(contacts.result.contacts[0].name, 'Ada Lovelace');
});

test('a change the agent asks for waits for the phone and reports what it did', async () => {
  const { user, agentId, store, provider, emitted, connection } = await setup();
  store.registerDevice({ userId: user.userId, agentId, device: DEVICE, kinds: ['calendar'] });

  const pending = provider.executeTool('phone_create_event', {
    title: 'Lunch', start: '2026-10-21T12:00:00Z', end: '2026-10-21T13:00:00Z',
  }, connection('calendar'));
  await new Promise((resolve) => setTimeout(resolve, 50));
  assert.deepEqual(emitted[0], ['device_sync:wake', { deviceId: DEVICE.id }]);

  const first = store.syncDevice({ userId: user.userId, agentId, body: { deviceId: DEVICE.id } });
  assert.equal(first.commands.length, 1);
  assert.equal(first.commands[0].action, 'create_event');
  assert.equal(first.commands[0].payload.title, 'Lunch');
  assert.equal(first.commands[0].payload.start, '2026-10-21T12:00:00.000Z');

  const done = store.syncDevice({
    userId: user.userId,
    agentId,
    body: { deviceId: DEVICE.id, results: [{ id: first.commands[0].id, ok: true, result: { eventId: '42' } }] },
  });
  assert.deepEqual(done.commands, []);
  const result = await pending;
  assert.equal(result.result.status, 'done');
  assert.equal(result.result.eventId, '42');
});

test('disconnecting forgets the phone, and its next sync learns it was forgotten', async () => {
  const { user, agentId, store, provider, connection } = await setup();
  store.registerDevice({ userId: user.userId, agentId, device: DEVICE, kinds: ['calendar', 'contacts'] });
  store.syncDevice({ userId: user.userId, agentId, body: { deviceId: DEVICE.id, contacts: [{ key: 'k', name: 'Bob' }] } });

  await provider.disconnect(connection('contacts'));
  assert.equal(connection('calendar'), undefined);
  assert.equal(ctx.db.prepare('SELECT COUNT(*) AS count FROM device_sync_items').get().count, 0);
  assert.deepEqual(store.syncDevice({ userId: user.userId, agentId, body: { deviceId: DEVICE.id } }), { connected: false });
  assert.throws(
    () => store.registerDevice({ userId: user.userId, agentId, device: { ...DEVICE, platform: 'windows' }, kinds: ['calendar'] }),
    /Android and iOS/,
  );
});
