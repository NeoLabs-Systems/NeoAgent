'use strict';

const db = require('../../../db/database');
const { abortableDelay } = require('../../../utils/retry');
const { parseJsonObject, trimText: text } = require('../../../utils/text');
const { upsertAccountApp } = require('../connection_store');
const { decryptValue, encryptValue } = require('../secrets');

const PROVIDER_KEY = 'phone';
const KINDS = Object.freeze(['calendar', 'contacts']);
const PLATFORMS = new Set(['android', 'ios']);
const DEVICE_ID_PATTERN = /^[A-Za-z0-9-]{8,64}$/;
const LIMITS = Object.freeze({ calendars: 200, events: 5000, contacts: 10000 });
const COMMAND_POLL_MS = 500;

function clip(value, max) {
  return text(value).slice(0, max);
}

function isoOrNull(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function list(values, max, itemMax = 200) {
  return (Array.isArray(values) ? values : []).map((value) => clip(value, itemMax)).filter(Boolean).slice(0, max);
}

// What a phone may send, trimmed to known fields and sizes.
const NORMALIZE = Object.freeze({
  calendar(item) {
    const id = clip(item.id, 200);
    if (!id) return null;
    return {
      key: id,
      payload: {
        id,
        name: clip(item.name, 200) || 'Calendar',
        account: clip(item.account, 200) || null,
        writable: item.writable === true,
        primary: item.primary === true,
      },
    };
  },
  event(item) {
    const start = isoOrNull(item.start);
    const end = isoOrNull(item.end) || start;
    const key = clip(item.key, 300);
    if (!key || !start) return null;
    return {
      key,
      startsAt: start,
      endsAt: end,
      payload: {
        eventId: clip(item.eventId, 200),
        calendarId: clip(item.calendarId, 200),
        title: clip(item.title, 500),
        start,
        end,
        allDay: item.allDay === true,
        location: clip(item.location, 500) || null,
        notes: clip(item.notes, 2000) || null,
        attendees: list(item.attendees, 30),
      },
    };
  },
  contact(item) {
    const key = clip(item.key, 200);
    const name = clip(item.name, 300);
    if (!key || !name) return null;
    return {
      key,
      payload: {
        name,
        emails: list(item.emails, 10),
        phones: list(item.phones, 10, 60),
        organization: clip(item.organization, 300) || null,
      },
    };
  },
});

function parsePayload(row) {
  return parseJsonObject(decryptValue(row.payload_json));
}

/** The phone's connection rows (one per shared kind) for this agent. */
function deviceConnections(userId, agentId, deviceId) {
  return db.prepare(`SELECT * FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=?`)
    .all(userId, agentId, PROVIDER_KEY)
    .filter((row) => parseJsonObject(row.metadata_json).deviceId === deviceId);
}

function deleteDeviceData(userId, agentId, deviceId, kinds = ['calendar', 'event', 'contact']) {
  const placeholders = kinds.map(() => '?').join(',');
  db.prepare(`DELETE FROM device_sync_items WHERE user_id=? AND agent_id=? AND device_id=? AND kind IN (${placeholders})`)
    .run(userId, agentId, deviceId, ...kinds);
}

function parseDevice(device = {}) {
  const id = text(device.id);
  if (!DEVICE_ID_PATTERN.test(id)) throw new Error('A valid device id is required.');
  const platform = text(device.platform).toLowerCase();
  if (!PLATFORMS.has(platform)) throw new Error('Phone sync runs on Android and iOS.');
  return { id, platform, name: clip(device.name, 60) || (platform === 'ios' ? 'iPhone' : 'Android phone') };
}

// Two phones with the same name stay apart in the account list.
function accountLabel(userId, agentId, device) {
  const taken = db.prepare(`SELECT account_email, metadata_json FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=? AND account_email=?`)
    .all(userId, agentId, PROVIDER_KEY, device.name)
    .some((row) => parseJsonObject(row.metadata_json).deviceId !== device.id);
  return taken ? `${device.name} (${device.id.slice(-4)})` : device.name;
}

/** Starts sharing the chosen kinds from a phone, or changes which it shares. */
function registerDevice({ userId, agentId, device: rawDevice, kinds: rawKinds }) {
  const device = parseDevice(rawDevice);
  const kinds = KINDS.filter((kind) => (Array.isArray(rawKinds) ? rawKinds : []).includes(kind));
  if (!kinds.length) throw new Error('Choose calendar, contacts or both.');
  const existing = deviceConnections(userId, agentId, device.id);
  const accountEmail = existing[0]?.account_email || accountLabel(userId, agentId, device);
  for (const kind of kinds) {
    upsertAccountApp({
      userId,
      agentId,
      providerKey: PROVIDER_KEY,
      appKey: kind,
      accountEmail,
      scopes: [kind],
      credentials: { deviceId: device.id },
      metadata: { deviceId: device.id, platform: device.platform },
    });
  }
  for (const row of existing.filter((connection) => !kinds.includes(connection.app_key))) {
    db.prepare('DELETE FROM integration_connections WHERE id=?').run(row.id);
    deleteDeviceData(userId, agentId, device.id, row.app_key === 'calendar' ? ['calendar', 'event'] : ['contact']);
  }
  return { connected: true, kinds, accountEmail };
}

/** Everything a phone shared goes when it is disconnected, from either side. */
function forgetDevice(userId, agentId, deviceId) {
  const remove = db.prepare('DELETE FROM integration_connections WHERE id=?');
  for (const row of deviceConnections(userId, agentId, deviceId)) remove.run(row.id);
  deleteDeviceData(userId, agentId, deviceId);
  db.prepare('DELETE FROM device_sync_commands WHERE user_id=? AND agent_id=? AND device_id=?')
    .run(userId, agentId, deviceId);
}

function replaceItems(userId, agentId, deviceId, kind, items, limit) {
  deleteDeviceData(userId, agentId, deviceId, [kind]);
  const insert = db.prepare(`INSERT OR REPLACE INTO device_sync_items
    (user_id, agent_id, device_id, kind, item_key, starts_at, ends_at, payload_json)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)`);
  for (const item of items.slice(0, limit).map(NORMALIZE[kind]).filter(Boolean)) {
    insert.run(
      userId, agentId, deviceId, kind, item.key,
      item.startsAt || null, item.endsAt || null,
      encryptValue(JSON.stringify(item.payload)),
    );
  }
}

function pendingCommands(userId, agentId, deviceId) {
  return db.prepare(`SELECT id, action, payload_json FROM device_sync_commands
    WHERE user_id=? AND agent_id=? AND device_id=? AND status='pending' ORDER BY id`)
    .all(userId, agentId, deviceId)
    .map((row) => ({ id: row.id, action: row.action, payload: parsePayload(row) }));
}

/**
 * One sync from a phone: replaces what it sent (a list left out means
 * unchanged), records the results of changes it made, and hands back the
 * changes still waiting for it.
 */
const syncDevice = db.transaction(({ userId, agentId, body = {} }) => {
  const deviceId = text(body.deviceId);
  const connections = deviceConnections(userId, agentId, deviceId);
  if (!connections.length) return { connected: false };
  const kinds = connections.map((row) => row.app_key);
  if (kinds.includes('calendar')) {
    if (Array.isArray(body.calendars)) replaceItems(userId, agentId, deviceId, 'calendar', body.calendars, LIMITS.calendars);
    if (Array.isArray(body.events)) replaceItems(userId, agentId, deviceId, 'event', body.events, LIMITS.events);
  }
  if (kinds.includes('contacts') && Array.isArray(body.contacts)) {
    replaceItems(userId, agentId, deviceId, 'contact', body.contacts, LIMITS.contacts);
  }
  const complete = db.prepare(`UPDATE device_sync_commands
    SET status=?, result_json=?, error=?, completed_at=datetime('now')
    WHERE id=? AND user_id=? AND agent_id=? AND device_id=? AND status='pending'`);
  for (const result of Array.isArray(body.results) ? body.results : []) {
    complete.run(
      result.ok === true ? 'done' : 'failed',
      encryptValue(JSON.stringify(result.result ?? null)),
      result.ok === true ? null : clip(result.error, 500) || 'The phone could not make this change.',
      Number(result.id), userId, agentId, deviceId,
    );
  }
  const syncedAt = new Date().toISOString();
  const touch = db.prepare('UPDATE integration_connections SET metadata_json=? WHERE id=?');
  for (const row of connections) {
    touch.run(JSON.stringify({ ...parseJsonObject(row.metadata_json), syncedAt }), row.id);
  }
  return { connected: true, kinds, commands: pendingCommands(userId, agentId, deviceId) };
});

function itemsOf(scope, kind, extraSql = '', params = []) {
  return db.prepare(`SELECT * FROM device_sync_items
    WHERE user_id=? AND agent_id=? AND device_id=? AND kind=? ${extraSql}`)
    .all(scope.userId, scope.agentId, scope.deviceId, kind, ...params)
    .map(parsePayload);
}

function matches(values, query) {
  const needle = text(query).toLowerCase();
  return !needle || values.flat().some((value) => text(value).toLowerCase().includes(needle));
}

function listCalendars(scope) {
  return itemsOf(scope, 'calendar');
}

function listEvents(scope, { start, end, query, calendarId, limit = 100 }) {
  return itemsOf(scope, 'event', 'AND starts_at < ? AND ends_at >= ? ORDER BY starts_at', [end, start])
    .filter((event) => !calendarId || event.calendarId === calendarId)
    .filter((event) => matches([event.title, event.location, event.notes, event.attendees], query))
    .slice(0, limit);
}

function searchContacts(scope, { query, limit = 25 }) {
  return itemsOf(scope, 'contact', 'ORDER BY item_key')
    .filter((contact) => matches([contact.name, contact.emails, contact.phones, contact.organization], query))
    .slice(0, limit);
}

function enqueueCommand(scope, action, payload) {
  return db.prepare(`INSERT INTO device_sync_commands (user_id, agent_id, device_id, action, payload_json)
    VALUES (?, ?, ?, ?, ?)`)
    .run(scope.userId, scope.agentId, scope.deviceId, action, encryptValue(JSON.stringify(payload)))
    .lastInsertRowid;
}

/** Waits for the phone to report a change, or returns null when it stays pending. */
async function awaitCommand(id, { timeoutMs, signal }) {
  const read = db.prepare('SELECT status, result_json, error FROM device_sync_commands WHERE id=?');
  for (let waited = 0; waited <= timeoutMs; waited += COMMAND_POLL_MS) {
    const row = read.get(id);
    if (row && row.status !== 'pending') {
      return row.status === 'done'
        ? { ok: true, result: JSON.parse(decryptValue(row.result_json) || 'null') }
        : { ok: false, error: row.error };
    }
    await abortableDelay(COMMAND_POLL_MS, signal);
  }
  return null;
}

module.exports = {
  KINDS,
  PROVIDER_KEY,
  awaitCommand,
  enqueueCommand,
  forgetDevice,
  listCalendars,
  listEvents,
  registerDevice,
  searchContacts,
  syncDevice,
};
