'use strict';

const db = require('../../../db/database');
const { resolveAgentId } = require('../../agents/manager');
const { createOAuthProvider } = require('../oauth_provider');
const { deleteSiblingConnections, upsertAccountApp } = require('../connection_store');
const { createCalendarTools } = require('../dav/calendar_tools');
const { createContactTools } = require('../dav/contact_tools');
const { createDavStore, discoverHome } = require('./dav_client');
const {
  FEED_APP, FEED_TOOLS, calendarName, executeFeedTool, fetchFeed, normalizeFeedUrl,
} = require('./feeds');
const { MAIL_APP, MAIL_TOOLS, executeMailTool, parseServer, verifyMailbox } = require('./mail');
const { PRESETS, findPreset } = require('./presets');
const { parseJsonObject, requireText, trimText: text } = require('../../../utils/text');

const PROVIDER_KEY = 'email';
const LABEL = 'Email & Calendar';
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const CALENDAR_APP = Object.freeze({
  id: 'calendar',
  label: 'Calendar',
  description: 'List calendars and create, update or delete events over CalDAV.',
});
const CONTACTS_APP = Object.freeze({
  id: 'contacts',
  label: 'Contacts',
  description: 'Look up, create and update contacts over CardDAV.',
});

const APPS = Object.freeze([MAIL_APP, CALENDAR_APP, CONTACTS_APP, FEED_APP]);
const APP_LABELS = Object.freeze(Object.fromEntries(APPS.map((app) => [app.id, app.label])));

const calendarTools = createCalendarTools({ prefix: 'caldav', label: LABEL, appId: CALENDAR_APP.id });
const contactTools = createContactTools({ prefix: 'carddav', label: LABEL, appId: CONTACTS_APP.id });

function connectionsOf(userId, agentId) {
  return db.prepare(`SELECT app_key, account_email, metadata_json FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=? AND status='connected' ORDER BY account_email`)
    .all(userId, agentId, PROVIDER_KEY);
}

function presetForClient(preset) {
  return {
    id: preset.id,
    label: preset.label,
    icon: preset.icon,
    help: preset.help,
    passwordUrl: preset.passwordUrl || null,
    custom: preset.custom === true,
    feed: preset.feed === true,
    unsupported: preset.unsupported === true,
    alternativeProvider: preset.alternativeProvider || null,
    calendar: preset.custom === true || Boolean(preset.caldavUrl),
    contacts: preset.custom === true || Boolean(preset.carddavUrl),
  };
}

// What the dialog shows: the providers to pick from and the accounts so far.
function getUserConfig({ userId, agentId }) {
  const accounts = new Map();
  for (const row of connectionsOf(Number(userId), resolveAgentId(Number(userId), agentId))) {
    const account = accounts.get(row.account_email) || {
      email: row.account_email,
      preset: parseJsonObject(row.metadata_json).preset || null,
      apps: [],
    };
    account.apps.push(APP_LABELS[row.app_key] || row.app_key);
    accounts.set(row.account_email, account);
  }
  return { presets: PRESETS.map(presetForClient), accounts: [...accounts.values()] };
}

/** The account a setup form describes, before anything is checked. */
function accountFromConfig(config) {
  const preset = findPreset(config.preset);
  if (!preset) throw new Error('Choose your mail provider.');
  if (preset.unsupported) throw new Error(preset.help);
  const email = text(config.email).toLowerCase();
  if (!EMAIL_PATTERN.test(email)) throw new Error('Enter a valid email address.');
  const rawPassword = requireText(config.password, 'App password');
  return {
    preset,
    account: {
      email,
      username: text(config.username) || email,
      // Providers display app passwords in groups; the spaces are not part of it.
      password: preset.custom ? rawPassword : rawPassword.replace(/\s+/g, ''),
      imap: preset.custom ? parseServer(config.imap, 'imap') : preset.imap,
      smtp: preset.custom ? parseServer(config.smtp, 'smtp') : preset.smtp,
      savesSentMail: preset.savesSentMail === true,
    },
    caldavUrl: config.calendar === false ? '' : text(preset.custom ? config.caldavUrl : preset.caldavUrl),
    carddavUrl: config.contacts === false ? '' : text(preset.custom ? config.carddavUrl : preset.carddavUrl),
  };
}

/** A read-only calendar from its iCal link, named after the calendar itself. */
async function saveFeed({ userId, agentId, config, signal }) {
  const url = normalizeFeedUrl(config.url);
  const calendar = await fetchFeed(url, signal);
  const name = text(config.name) || calendarName(calendar) || new URL(url).hostname;
  upsertAccountApp({
    userId,
    agentId,
    providerKey: PROVIDER_KEY,
    appKey: FEED_APP.id,
    accountEmail: name,
    scopes: ['ical:read'],
    credentials: { url, name },
    metadata: { preset: 'ical' },
  });
  return getUserConfig({ userId, agentId });
}

async function saveUserConfig({ userId, agentId, config = {}, signal }) {
  const normalizedUserId = Number(userId);
  const scopedAgentId = resolveAgentId(normalizedUserId, agentId);
  if (findPreset(config.preset)?.feed) {
    return saveFeed({ userId: normalizedUserId, agentId: scopedAgentId, config, signal });
  }
  const { preset, account, caldavUrl, carddavUrl } = accountFromConfig(config);
  const auth = { username: account.username, password: account.password };

  await verifyMailbox(account, signal);
  const credentials = {
    ...account,
    caldav: caldavUrl ? await discoverHome(caldavUrl, 'caldav', auth, { signal }) : null,
    carddav: carddavUrl ? await discoverHome(carddavUrl, 'carddav', auth, { signal }) : null,
  };

  const apps = [
    MAIL_APP,
    ...(credentials.caldav ? [CALENDAR_APP] : []),
    ...(credentials.carddav ? [CONTACTS_APP] : []),
  ];
  const key = { userId: normalizedUserId, agentId: scopedAgentId, providerKey: PROVIDER_KEY, accountEmail: account.email };
  for (const app of apps) {
    upsertAccountApp({ ...key, appKey: app.id, credentials, metadata: { preset: preset.id }, scopes: [app.id] });
  }
  db.prepare(`DELETE FROM integration_connections
    WHERE user_id=? AND agent_id=? AND provider_key=? AND account_email=? AND app_key NOT IN (${apps.map(() => '?').join(',')})`)
    .run(normalizedUserId, scopedAgentId, PROVIDER_KEY, account.email, ...apps.map((app) => app.id));
  return getUserConfig({ userId: normalizedUserId, agentId: scopedAgentId });
}

function createEmailProvider() {
  const provider = createOAuthProvider({
    key: PROVIDER_KEY,
    label: LABEL,
    description: 'Mail, calendar and contacts from Gmail, iCloud, Fastmail, Yahoo or any IMAP server with an app password, and calendars from their iCal link. No developer console needed.',
    icon: 'email',
    apps: APPS,
    toolDefinitions: [...MAIL_TOOLS, ...calendarTools.tools, ...contactTools.tools, ...FEED_TOOLS],
    connectPrompt: 'Pick your mail provider, paste an app password, and the agent can read and send mail and manage your calendar.',
    supportsMultipleAccounts: true,
    connectionMethod: 'user_config',
    getEnvStatus() {
      return {
        configured: true,
        missing: [],
        summary: `${LABEL} connects with an app password from your mail provider.`,
        setupMode: 'user',
      };
    },
    async beginOAuth() {
      throw new Error(`${LABEL} connects with an app password. Open Official Integrations to add an account.`);
    },
    async finishOAuth() {
      throw new Error(`${LABEL} does not use an OAuth callback.`);
    },
    async executeTool(toolName, args, context) {
      const credentials = context.credentials;
      const options = { signal: context.signal || null };
      const auth = { username: credentials.username, password: credentials.password };
      if (credentials.url) return executeFeedTool(toolName, args || {}, credentials, options);
      const result = await executeMailTool(toolName, args || {}, credentials, options)
        ?? (credentials.caldav && await calendarTools.execute(toolName, args || {}, createDavStore(credentials.caldav, auth), options))
        ?? (credentials.carddav && await contactTools.execute(toolName, args || {}, createDavStore(credentials.carddav, auth), options));
      if (result) return result;
      throw new Error(`Unsupported ${LABEL} tool: ${toolName}`);
    },
    async disconnect(connection) {
      deleteSiblingConnections(connection);
    },
    async testConnection(context) {
      if (context.credentials.url) await fetchFeed(context.credentials.url, context.signal);
      else await verifyMailbox(context.credentials, context.signal);
      return {};
    },
  });

  provider.getUserConfig = getUserConfig;
  provider.saveUserConfig = saveUserConfig;
  return provider;
}

module.exports = { createEmailProvider };
