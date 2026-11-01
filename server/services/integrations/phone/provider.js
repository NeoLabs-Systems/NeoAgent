'use strict';

const { createOAuthProvider } = require('../oauth_provider');
const { parseJsonObject, requireText, trimText: text } = require('../../../utils/text');
const store = require('./store');

const LABEL = 'Phone calendar & contacts';
const DAY_MS = 24 * 60 * 60 * 1000;
// A phone with the app open makes a change within a second or two.
const COMMAND_WAIT_MS = 12000;

const CALENDAR_APP = Object.freeze({
  id: 'calendar',
  label: 'Calendar',
  description: 'Every calendar on the phone (Google, Outlook, iCloud, Exchange), shared by the NeoAgent app.',
});
const CONTACTS_APP = Object.freeze({
  id: 'contacts',
  label: 'Contacts',
  description: 'The contacts on the phone, shared by the NeoAgent app.',
});

const EVENT_FIELDS = Object.freeze({
  title: { type: 'string', description: 'Event title.' },
  start: { type: 'string', description: 'Start as an ISO datetime, or YYYY-MM-DD for all-day events.' },
  end: { type: 'string', description: 'End as an ISO datetime, or YYYY-MM-DD for all-day events.' },
  all_day: { type: 'boolean', description: 'All-day event.' },
  location: { type: 'string', description: 'Location.' },
  notes: { type: 'string', description: 'Notes.' },
});

const TOOLS = Object.freeze([
  {
    appId: CALENDAR_APP.id,
    name: 'phone_list_calendars',
    access: 'read',
    description: 'List the calendars on the connected phone and whether each can be written to.',
    parameters: { type: 'object', properties: {} },
  },
  {
    appId: CALENDAR_APP.id,
    name: 'phone_list_events',
    access: 'read',
    description: 'List events from the phone\'s calendars. Defaults to the next 7 days. Covers 30 days back to 90 days ahead.',
    parameters: {
      type: 'object',
      properties: {
        start: { type: 'string', description: 'Inclusive ISO lower bound.' },
        end: { type: 'string', description: 'Exclusive ISO upper bound.' },
        query: { type: 'string', description: 'Text to find in title, location, notes or attendees.' },
        calendar_id: { type: 'string', description: 'Only this calendar, from phone_list_calendars.' },
      },
    },
  },
  {
    appId: CALENDAR_APP.id,
    name: 'phone_create_event',
    access: 'write',
    description: 'Create an event on the phone. It syncs on to the calendar\'s account (Google, Outlook, iCloud).',
    parameters: {
      type: 'object',
      properties: {
        calendar_id: { type: 'string', description: 'Writable calendar from phone_list_calendars. Defaults to the primary one.' },
        ...EVENT_FIELDS,
      },
      required: ['title', 'start', 'end'],
    },
  },
  {
    appId: CALENDAR_APP.id,
    name: 'phone_update_event',
    access: 'write',
    description: 'Change an event on the phone. Only the fields given change.',
    parameters: {
      type: 'object',
      properties: {
        event_id: { type: 'string', description: 'eventId from phone_list_events.' },
        ...EVENT_FIELDS,
      },
      required: ['event_id'],
    },
  },
  {
    appId: CALENDAR_APP.id,
    name: 'phone_delete_event',
    access: 'write',
    description: 'Delete an event from the phone (every occurrence of a repeating event).',
    parameters: {
      type: 'object',
      properties: { event_id: { type: 'string', description: 'eventId from phone_list_events.' } },
      required: ['event_id'],
    },
  },
  {
    appId: CONTACTS_APP.id,
    name: 'phone_search_contacts',
    access: 'read',
    description: 'Find contacts on the phone by name, email, phone number or organization.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Text to look for. Empty lists the first contacts.' },
        limit: { type: 'number', description: 'Maximum contacts (1-100), default 25.' },
      },
    },
  },
  {
    appId: CONTACTS_APP.id,
    name: 'phone_create_contact',
    access: 'write',
    description: 'Add a contact to the phone.',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Full name.' },
        email: { type: 'string', description: 'Email address.' },
        phone: { type: 'string', description: 'Phone number.' },
        organization: { type: 'string', description: 'Organization.' },
      },
      required: ['name'],
    },
  },
]);

function isoArg(value, name) {
  const date = new Date(text(value));
  if (Number.isNaN(date.getTime())) throw new Error(`${name} must be an ISO date or datetime.`);
  return date.toISOString();
}

function eventChanges(args) {
  const changes = {};
  for (const key of ['title', 'location', 'notes']) {
    if (args[key] !== undefined) changes[key] = text(args[key]);
  }
  if (args.start !== undefined) changes.start = isoArg(args.start, 'start');
  if (args.end !== undefined) changes.end = isoArg(args.end, 'end');
  if (typeof args.all_day === 'boolean') changes.allDay = args.all_day;
  return changes;
}

// The phone's changes, as the native sync code expects them.
const COMMANDS = Object.freeze({
  phone_create_event: (args) => ['create_event', {
    calendarId: text(args.calendar_id) || null,
    ...eventChanges({ ...args, title: requireText(args.title, 'title') }),
  }],
  phone_update_event: (args) => ['update_event', { eventId: requireText(args.event_id, 'event_id'), ...eventChanges(args) }],
  phone_delete_event: (args) => ['delete_event', { eventId: requireText(args.event_id, 'event_id') }],
  phone_create_contact: (args) => ['create_contact', {
    name: requireText(args.name, 'name'),
    email: text(args.email) || null,
    phone: text(args.phone) || null,
    organization: text(args.organization) || null,
  }],
});

function scopeOf(context) {
  return {
    userId: context.connection.user_id,
    agentId: context.connection.agent_id,
    deviceId: context.credentials.deviceId,
  };
}

function freshness(context) {
  return {
    device: context.connection.account_email,
    syncedAt: parseJsonObject(context.connection.metadata_json).syncedAt || null,
  };
}

function readTool(toolName, args, scope) {
  switch (toolName) {
    case 'phone_list_calendars':
      return { calendars: store.listCalendars(scope) };
    case 'phone_list_events': {
      const start = args.start ? isoArg(args.start, 'start') : new Date().toISOString();
      const end = args.end ? isoArg(args.end, 'end') : new Date(Date.parse(start) + 7 * DAY_MS).toISOString();
      return { events: store.listEvents(scope, { start, end, query: args.query, calendarId: text(args.calendar_id) }) };
    }
    case 'phone_search_contacts':
      return {
        contacts: store.searchContacts(scope, {
          query: args.query,
          limit: Math.max(1, Math.min(Number(args.limit) || 25, 100)),
        }),
      };
    default:
      return null;
  }
}

function createPhoneProvider(options = {}) {
  const wake = (userId, deviceId) => {
    const io = options.io || options.app?.locals?.io;
    io?.to(`user:${userId}`).emit('device_sync:wake', { deviceId });
  };

  async function writeTool(toolName, args, context) {
    const [action, payload] = COMMANDS[toolName](args);
    const scope = scopeOf(context);
    const id = store.enqueueCommand(scope, action, payload);
    wake(scope.userId, scope.deviceId);
    const outcome = await store.awaitCommand(id, { timeoutMs: COMMAND_WAIT_MS, signal: context.signal });
    if (!outcome) {
      return {
        status: 'queued',
        ...freshness(context),
        note: 'The phone has not picked this up yet. It will make the change the next time it syncs; tell the user it is pending, not done.',
      };
    }
    if (!outcome.ok) throw new Error(outcome.error);
    return { status: 'done', ...freshness(context), ...outcome.result };
  }

  const provider = createOAuthProvider({
    key: store.PROVIDER_KEY,
    label: LABEL,
    description: 'Calendars and contacts from your phone, shared by the NeoAgent app. Works with whatever accounts the phone already syncs, with no developer console.',
    icon: 'phone',
    apps: [CALENDAR_APP, CONTACTS_APP],
    toolDefinitions: TOOLS,
    connectPrompt: 'Open NeoAgent on your phone and turn on calendar and contacts sharing.',
    supportsMultipleAccounts: true,
    connectionMethod: 'device',
    getEnvStatus() {
      return {
        configured: true,
        missing: [],
        summary: 'Set up from the NeoAgent app on your phone.',
        setupMode: 'device',
      };
    },
    async beginOAuth() {
      throw new Error(`${LABEL} is set up from the NeoAgent phone app.`);
    },
    async finishOAuth() {
      throw new Error(`${LABEL} does not use an OAuth callback.`);
    },
    async executeTool(toolName, args, context) {
      if (COMMANDS[toolName]) return { result: await writeTool(toolName, args || {}, context) };
      const result = readTool(toolName, args || {}, scopeOf(context));
      if (!result) throw new Error(`Unsupported ${LABEL} tool: ${toolName}`);
      return { result: { ...freshness(context), ...result } };
    },
    async disconnect(connection) {
      store.forgetDevice(connection.user_id, connection.agent_id, parseJsonObject(connection.metadata_json).deviceId);
    },
    async testConnection(context) {
      if (!freshness(context).syncedAt) throw new Error('The phone has not synced yet. Open NeoAgent on it.');
      return {};
    },
  });

  provider.summarizeForModel = (snapshot) => {
    if (!snapshot.connection?.connected) {
      return `${LABEL}: not shared yet. If the user wants their calendar or contacts, they can turn on sharing in the NeoAgent phone app.`;
    }
    return [
      `${LABEL}: shared from the user's phone (${snapshot.apps.filter((app) => app.connection.connected).map((app) => app.label).join(', ')}).`,
      'Reads come from the last sync; mention syncedAt when it matters. Changes are made by the phone and can be pending while it is offline.',
    ].join(' ');
  };

  return provider;
}

module.exports = { createPhoneProvider };
