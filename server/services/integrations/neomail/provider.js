'use strict';

const crypto = require('crypto');
const db = require('../../../db/database');
const { resolveAgentId } = require('../../agents/manager');
const {
  deleteProviderConfig,
  getProviderConfig,
  setProviderConfig,
} = require('../provider_config_store');
const { getConnectionAccessMode } = require('../access');
const { decryptValue } = require('../secrets');
const { appendQuery, fetchJson } = require('../oauth_provider');
const { resolvePublicBaseUrl } = require('../env');

const NEOMAIL_PROVIDER_KEY = 'neomail';
const NEOMAIL_APP = Object.freeze({
  id: 'mailbox',
  label: 'Mailbox',
  description:
    'Search threads, read mail, draft replies, send messages, and trigger tasks from a connected NeoMail inbox.',
});
const NEOMAIL_COMPANION_SCOPES = Object.freeze([
  'mail:read',
  'mail:write',
  'drafts:write',
  'send:write',
  'ai:use',
]);
const TOOL_DEFINITIONS = Object.freeze([
  {
    appId: NEOMAIL_APP.id,
    name: 'neomail_list_accounts',
    access: 'read',
    description: 'List mailboxes available in the connected NeoMail account.',
    parameters: { type: 'object', properties: {} },
  },
  {
    appId: NEOMAIL_APP.id,
    name: 'neomail_list_threads',
    access: 'read',
    description: 'List threads from the connected NeoMail account.',
    parameters: {
      type: 'object',
      properties: {
        mail_account_id: {
          type: 'string',
          description: 'Optional NeoMail mailbox account ID.',
        },
        mail_account_email: {
          type: 'string',
          description: 'Optional NeoMail mailbox email address.',
        },
        folder: { type: 'string', description: 'Optional folder path like INBOX or archive.' },
        query: { type: 'string', description: 'Optional text query.' },
        unread_only: { type: 'boolean', description: 'Whether to return only unread threads.' },
        limit: { type: 'number', description: 'Maximum threads to return, default 25.' },
      },
    },
  },
  {
    appId: NEOMAIL_APP.id,
    name: 'neomail_get_thread',
    access: 'read',
    description: 'Read a full thread from NeoMail.',
    parameters: {
      type: 'object',
      properties: {
        thread_id: { type: 'string', description: 'NeoMail thread ID.' },
      },
      required: ['thread_id'],
    },
  },
  {
    appId: NEOMAIL_APP.id,
    name: 'neomail_search_messages',
    access: 'read',
    description: 'Search messages in NeoMail.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Search query.' },
        mail_account_id: {
          type: 'string',
          description: 'Optional NeoMail mailbox account ID.',
        },
        mail_account_email: {
          type: 'string',
          description: 'Optional NeoMail mailbox email address.',
        },
        limit: { type: 'number', description: 'Maximum results to return, default 20.' },
      },
      required: ['query'],
    },
  },
  {
    appId: NEOMAIL_APP.id,
    name: 'neomail_save_draft',
    access: 'write',
    description: 'Create or update a NeoMail draft.',
    parameters: {
      type: 'object',
      properties: {
        draft_id: { type: 'string', description: 'Optional existing draft ID.' },
        mail_account_id: {
          type: 'string',
          description: 'Optional NeoMail mailbox account ID.',
        },
        mail_account_email: {
          type: 'string',
          description: 'Optional NeoMail mailbox email address.',
        },
        thread_id: { type: 'string', description: 'Optional NeoMail thread ID.' },
        to: {
          type: 'array',
          items: {
            anyOf: [
              { type: 'string' },
              {
                type: 'object',
                properties: {
                  name: { type: 'string' },
                  address: { type: 'string' },
                },
                required: ['address'],
              },
            ],
          },
          description: 'Recipient list.',
        },
        cc: {
          type: 'array',
          items: {
            anyOf: [
              { type: 'string' },
              {
                type: 'object',
                properties: {
                  name: { type: 'string' },
                  address: { type: 'string' },
                },
                required: ['address'],
              },
            ],
          },
        },
        bcc: {
          type: 'array',
          items: {
            anyOf: [
              { type: 'string' },
              {
                type: 'object',
                properties: {
                  name: { type: 'string' },
                  address: { type: 'string' },
                },
                required: ['address'],
              },
            ],
          },
        },
        subject: { type: 'string', description: 'Draft subject.' },
        body_text: { type: 'string', description: 'Plain-text draft body.' },
        body_html: { type: 'string', description: 'Optional HTML draft body.' },
        scheduled_for: { type: 'string', description: 'Optional ISO datetime for send-later.' },
      },
      required: ['to'],
    },
  },
  {
    appId: NEOMAIL_APP.id,
    name: 'neomail_send_draft',
    access: 'write',
    description: 'Send a NeoMail draft immediately or leave it queued.',
    parameters: {
      type: 'object',
      properties: {
        draft_id: { type: 'string', description: 'NeoMail draft ID.' },
        immediate: { type: 'boolean', description: 'Whether to send immediately, default true.' },
      },
      required: ['draft_id'],
    },
  },
  {
    appId: NEOMAIL_APP.id,
    name: 'neomail_update_thread',
    access: 'write',
    description: 'Update NeoMail thread flags and labels.',
    parameters: {
      type: 'object',
      properties: {
        thread_id: { type: 'string', description: 'NeoMail thread ID.' },
        is_read: { type: 'boolean', description: 'Read state.' },
        starred: { type: 'boolean', description: 'Starred state.' },
        archived: { type: 'boolean', description: 'Archived state.' },
        trashed: { type: 'boolean', description: 'Trash state.' },
        labels: { type: 'array', items: { type: 'string' }, description: 'Optional labels.' },
      },
      required: ['thread_id'],
    },
  },
  {
    appId: NEOMAIL_APP.id,
    name: 'neomail_ai_summarize_thread',
    access: 'read',
    description: 'Generate an AI summary for a NeoMail thread.',
    parameters: {
      type: 'object',
      properties: {
        thread_id: { type: 'string', description: 'NeoMail thread ID.' },
      },
      required: ['thread_id'],
    },
  },
  {
    appId: NEOMAIL_APP.id,
    name: 'neomail_ai_improve_draft',
    access: 'write',
    description: 'Improve a NeoMail draft with NeoMail AI.',
    parameters: {
      type: 'object',
      properties: {
        draft_id: { type: 'string', description: 'NeoMail draft ID.' },
        instruction: { type: 'string', description: 'Optional rewrite instruction.' },
      },
      required: ['draft_id'],
    },
  },
  {
    appId: NEOMAIL_APP.id,
    name: 'neomail_ai_ask_inbox',
    access: 'read',
    description: 'Ask NeoMail AI a question about the inbox.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Inbox question.' },
      },
      required: ['query'],
    },
  },
]);

const toolAppMap = new Map(TOOL_DEFINITIONS.map((tool) => [tool.name, tool.appId]));

function trimText(value) {
  return String(value || '').trim();
}

function isPrivateHost(hostname) {
  const lower = String(hostname || '').trim().toLowerCase();
  if (!lower) return false;
  return lower === 'localhost'
    || lower === '::1'
    || lower === '[::1]'
    || lower.startsWith('127.')
    || lower.startsWith('10.')
    || lower.startsWith('192.168.')
    || /^172\.(1[6-9]|2\d|3[0-1])\./.test(lower);
}

function normalizeNeoMailBaseUrl(value) {
  const raw = trimText(value);
  if (!raw) {
    throw new Error('NeoMail backend URL is required.');
  }
  const withScheme = raw.includes('://')
    ? raw
    : `${isPrivateHost(raw.split('/')[0]) ? 'http' : 'https'}://${raw}`;
  let parsed;
  try {
    parsed = new URL(withScheme);
  } catch {
    throw new Error('NeoMail backend URL must be a valid HTTP or HTTPS URL.');
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error('NeoMail backend URL must use HTTP or HTTPS.');
  }
  if (parsed.hash) {
    throw new Error('NeoMail backend URL must not contain a fragment.');
  }
  parsed.pathname = parsed.pathname.replace(/\/+$/, '');
  return parsed.toString().replace(/\/+$/, '');
}

function parseConfigInput(rawConfig, existingConfig = {}) {
  const source = rawConfig && typeof rawConfig === 'object' ? rawConfig : {};
  return {
    baseUrl: trimText(source.baseUrl) || trimText(existingConfig.baseUrl),
  };
}

function getCallbackUrl() {
  return `${resolvePublicBaseUrl()}/api/integrations/oauth/callback`;
}

function getCompanionBootstrapUrl(baseUrl) {
  return `${baseUrl}/api/oauth/companion/neoagent/bootstrap`;
}

async function fetchNeoMailAuthStatus(baseUrl) {
  return fetchJson(
    `${baseUrl}/api/auth/status`,
    { method: 'GET' },
    { serviceName: 'NeoMail auth status' },
  );
}

async function bootstrapNeoMailCompanion(baseUrl) {
  return fetchJson(
    getCompanionBootstrapUrl(baseUrl),
    {
      method: 'POST',
      json: {
        redirectUri: getCallbackUrl(),
        appName: 'NeoAgent',
      },
    },
    { serviceName: 'NeoMail companion bootstrap' },
  );
}

async function exchangeNeoMailToken(baseUrl, form) {
  return fetchJson(
    `${baseUrl}/oauth/token`,
    {
      method: 'POST',
      form,
    },
    { serviceName: 'NeoMail OAuth token' },
  );
}

function buildApiPath(path, query = {}) {
  return appendQuery(path, query);
}

async function fetchAccounts(baseUrl, accessToken) {
  const response = await fetchJson(
    `${baseUrl}/api/v1/mail/accounts`,
    {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'application/json',
      },
    },
    { serviceName: 'NeoMail accounts' },
  );
  return Array.isArray(response?.accounts) ? response.accounts : [];
}

async function fetchUserInfo(baseUrl, accessToken) {
  return fetchJson(
    `${baseUrl}/oauth/userinfo`,
    {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'application/json',
      },
    },
    { serviceName: 'NeoMail userinfo' },
  );
}

function connectionLabelForUser(info = {}, baseUrl, accounts = []) {
  const email = trimText(info.email);
  if (email) return email;
  const username = trimText(info.preferred_username || info.username);
  const host = new URL(baseUrl).host;
  if (username) return `${username}@${host}`;
  if (Array.isArray(accounts) && accounts.length === 1) {
    const emailAddress = trimText(accounts[0]?.emailAddress);
    if (emailAddress) return emailAddress;
  }
  return `neomail:${host}`;
}

function decodeCredentials(connection) {
  try {
    return JSON.parse(decryptValue(connection.credentials_json || '{}') || '{}');
  } catch {
    return {};
  }
}

function summarizeAccountRow(row, envStatus) {
  if (!envStatus.configured) {
    return {
      id: row?.id || null,
      status: 'env_not_configured',
      connected: false,
      accountEmail: row?.account_email || null,
      lastConnectedAt: row?.last_connected_at || null,
      accessMode: 'read_write',
    };
  }
  if (!row) {
    return {
      id: null,
      status: 'not_connected',
      connected: false,
      accountEmail: null,
      lastConnectedAt: null,
      accessMode: 'read_write',
    };
  }
  return {
    id: row.id || null,
    status: row.status || 'not_connected',
    connected: row.status === 'connected',
    accountEmail: row.account_email || null,
    lastConnectedAt: row.last_connected_at || null,
    accessMode: getConnectionAccessMode(row),
  };
}

function buildSnapshot(provider, connectionRows, context = {}) {
  const env = provider.getEnvStatus(context);
  const accounts = (Array.isArray(connectionRows) ? connectionRows : [])
    .slice()
    .sort((left, right) => String(right.updated_at || '').localeCompare(String(left.updated_at || '')))
    .map((row) => summarizeAccountRow(row, env));
  const connectedAccounts = accounts.filter((account) => account.connected);
  return {
    id: provider.key,
    label: provider.label,
    description: provider.description,
    icon: provider.icon,
    apps: [
      {
        id: NEOMAIL_APP.id,
        label: NEOMAIL_APP.label,
        description: NEOMAIL_APP.description,
        accounts,
        connection: {
          status: !env.configured ? 'env_not_configured' : connectedAccounts.length > 0 ? 'connected' : 'not_connected',
          connected: connectedAccounts.length > 0,
          accountCount: connectedAccounts.length,
          accountEmail: connectedAccounts.length === 1 ? connectedAccounts[0].accountEmail : null,
          lastConnectedAt: connectedAccounts.map((account) => account.lastConnectedAt).filter(Boolean).sort().reverse()[0] || null,
        },
        availableToolCount:
          env.configured && connectedAccounts.length > 0 ? TOOL_DEFINITIONS.length : 0,
      },
    ],
    env,
    connection: {
      status: !env.configured ? 'env_not_configured' : connectedAccounts.length > 0 ? 'connected' : 'not_connected',
      connected: connectedAccounts.length > 0,
      accountEmail: connectedAccounts.length === 1 ? connectedAccounts[0].accountEmail : null,
      accountCount: connectedAccounts.length,
      appCount: connectedAccounts.length > 0 ? 1 : 0,
      lastConnectedAt: connectedAccounts.map((account) => account.lastConnectedAt).filter(Boolean).sort().reverse()[0] || null,
    },
    availableToolCount:
      env.configured && connectedAccounts.length > 0 ? TOOL_DEFINITIONS.length : 0,
    connectPrompt: provider.connectPrompt,
    supportsMultipleAccounts: provider.supportsMultipleAccounts,
    connectionMethod: provider.connectionMethod,
  };
}

async function ensureValidAccessToken(connection) {
  const credentials = decodeCredentials(connection);
  const baseUrl = normalizeNeoMailBaseUrl(credentials.baseUrl);
  const accessToken = trimText(credentials.access_token);
  const refreshToken = trimText(credentials.refresh_token);
  const clientId = trimText(credentials.client_id);
  const expiresAtMs = Number(credentials.expires_at_ms || 0);
  const needsRefresh = !accessToken || !expiresAtMs || Date.now() >= (expiresAtMs - 60 * 1000);

  if (!needsRefresh) {
    return { baseUrl, accessToken, credentials };
  }
  if (!refreshToken || !clientId) {
    throw new Error('NeoMail refresh token is missing. Reconnect the NeoMail account.');
  }

  const refreshed = await exchangeNeoMailToken(baseUrl, {
    grant_type: 'refresh_token',
    client_id: clientId,
    refresh_token: refreshToken,
  });
  const nextCredentials = {
    ...credentials,
    access_token: trimText(refreshed.access_token),
    refresh_token: trimText(refreshed.refresh_token) || refreshToken,
    scope: trimText(refreshed.scope) || credentials.scope,
    token_type: trimText(refreshed.token_type) || 'Bearer',
    expires_at_ms: Date.now() + (Math.max(1, Number(refreshed.expires_in) || 3600) * 1000),
  };
  return {
    baseUrl,
    accessToken: nextCredentials.access_token,
    credentials: nextCredentials,
  };
}

async function requestNeoMail(connection, path, options = {}) {
  const { baseUrl, accessToken, credentials } = await ensureValidAccessToken(connection);
  const response = await fetchJson(
    `${baseUrl}${path.startsWith('/') ? '' : '/'}${path}`,
    {
      method: options.method || 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'application/json',
      },
      ...(options.json === undefined ? {} : { json: options.json }),
    },
    { serviceName: 'NeoMail API' },
  );
  return { response, credentials, baseUrl, accessToken };
}

async function fetchNeoMailTriggerEvents(connection, config = {}, options = {}) {
  const path = buildApiPath('/api/v1/mail/events', {
    accountId: trimText(config.mailAccountId || config.mail_account_id) || undefined,
    folder: trimText(config.folder) || undefined,
    q: trimText(config.query) || undefined,
    unread: config.unreadOnly === true ? 'true' : undefined,
    since: trimText(options.since) || undefined,
    limit:
      Number(options.limit) > 0
        ? String(Math.min(Number(options.limit), 200))
        : '100',
  });
  const { response, credentials } = await requestNeoMail(connection, path);
  const events = Array.isArray(response?.events) ? response.events : [];
  const rows = events.map((event) => {
    const messageId = trimText(event?.id);
    return {
      fingerprint: `neomail:${connection.id}:${messageId}`,
      timestamp: trimText(event?.createdAt) || new Date().toISOString(),
      context: {
        triggerEvent: {
          provider: 'neomail',
          connectionId: connection.id,
          messageId,
          threadId: trimText(event?.threadId) || null,
          accountId: trimText(event?.accountId) || null,
          accountEmail: trimText(event?.accountEmail) || null,
          accountLabel: trimText(event?.accountLabel) || null,
          remoteMessageId: trimText(event?.remoteMessageId) || null,
          from: event?.from && typeof event.from === 'object'
            ? {
                name: trimText(event.from.name),
                address: trimText(event.from.address),
              }
            : { name: '', address: '' },
          subject: trimText(event?.subject),
          snippet: trimText(event?.snippet),
          folderPath: trimText(event?.folderPath) || 'INBOX',
          receivedAt: trimText(event?.receivedAt) || null,
          sentAt: trimText(event?.sentAt) || null,
          createdAt: trimText(event?.createdAt) || null,
          updatedAt: trimText(event?.updatedAt) || null,
          isRead: event?.isRead === true,
        },
      },
    };
  });
  return { rows, credentials };
}

function normalizeAddressList(values) {
  const list = Array.isArray(values) ? values : [];
  return list
    .map((entry) => {
      if (typeof entry === 'string') {
        const address = trimText(entry);
        return address ? { address } : null;
      }
      if (entry && typeof entry === 'object') {
        const address = trimText(entry.address);
        if (!address) return null;
        const name = trimText(entry.name);
        return name ? { name, address } : { address };
      }
      return null;
    })
    .filter(Boolean);
}

async function resolveMailAccountSelector(connection, args, options = {}) {
  const directId = trimText(args.mail_account_id || args.account_id);
  if (directId) {
    return { id: directId, accounts: null, credentials: null };
  }

  const selectorEmail = trimText(args.mail_account_email).toLowerCase();
  const { response, credentials } = await requestNeoMail(connection, '/api/v1/mail/accounts');
  const accounts = Array.isArray(response?.accounts) ? response.accounts : [];
  if (selectorEmail) {
    const match = accounts.find(
      (account) => trimText(account?.emailAddress).toLowerCase() === selectorEmail,
    );
    if (!match) {
      throw new Error(`No NeoMail mailbox matches ${selectorEmail}.`);
    }
    return { id: String(match.id), accounts, credentials };
  }
  if (options.required === true) {
    if (accounts.length === 0) {
      throw new Error('The connected NeoMail account has no mailboxes yet.');
    }
    if (accounts.length > 1) {
      const labels = accounts
        .map((account) => trimText(account?.emailAddress) || String(account?.id || 'unknown'))
        .join(', ');
      throw new Error(
        `Multiple NeoMail mailboxes are available (${labels}). Re-run the tool with mail_account_id or mail_account_email.`,
      );
    }
    return { id: String(accounts[0].id), accounts, credentials };
  }
  return { id: null, accounts, credentials };
}

async function executeNeoMailTool(toolName, args, connection) {
  if (toolName === 'neomail_list_accounts') {
    const { response, credentials } = await requestNeoMail(connection, '/api/v1/mail/accounts');
    return { result: response, credentials };
  }

  if (toolName === 'neomail_list_threads') {
    const resolved = await resolveMailAccountSelector(connection, args, { required: false });
    const { response, credentials } = await requestNeoMail(
      connection,
      buildApiPath('/api/v1/mail/threads', {
        accountId: resolved.id || undefined,
        folder: trimText(args.folder) || undefined,
        q: trimText(args.query) || undefined,
        unread: args.unread_only === true ? 'true' : undefined,
        limit: Number(args.limit) > 0 ? String(Math.min(Number(args.limit), 100)) : undefined,
      }),
    );
    return { result: response, credentials: resolved.credentials || credentials };
  }

  if (toolName === 'neomail_get_thread') {
    const threadId = trimText(args.thread_id);
    if (!threadId) throw new Error('thread_id is required.');
    const { response, credentials } = await requestNeoMail(connection, `/api/v1/mail/threads/${encodeURIComponent(threadId)}`);
    return { result: response, credentials };
  }

  if (toolName === 'neomail_search_messages') {
    const query = trimText(args.query);
    if (!query) throw new Error('query is required.');
    const resolved = await resolveMailAccountSelector(connection, args, { required: false });
    const { response, credentials } = await requestNeoMail(
      connection,
      buildApiPath('/api/v1/mail/search', {
        accountId: resolved.id || undefined,
        q: query,
        limit: Number(args.limit) > 0 ? String(Math.min(Number(args.limit), 100)) : undefined,
      }),
    );
    return { result: response, credentials: resolved.credentials || credentials };
  }

  if (toolName === 'neomail_save_draft') {
    const resolved = await resolveMailAccountSelector(connection, args, { required: true });
    const payload = {
      ...(trimText(args.thread_id) ? { threadId: trimText(args.thread_id) } : {}),
      accountId: resolved.id,
      to: normalizeAddressList(args.to),
      cc: normalizeAddressList(args.cc),
      bcc: normalizeAddressList(args.bcc),
      subject: trimText(args.subject),
      bodyText: String(args.body_text || ''),
      ...(trimText(args.body_html) ? { bodyHtml: String(args.body_html) } : {}),
      ...(trimText(args.scheduled_for) ? { scheduledFor: trimText(args.scheduled_for) } : {}),
    };
    if (payload.to.length === 0) {
      throw new Error('At least one recipient is required in to.');
    }
    const draftId = trimText(args.draft_id);
    const { response, credentials } = await requestNeoMail(
      connection,
      draftId
        ? `/api/v1/mail/drafts/${encodeURIComponent(draftId)}`
        : '/api/v1/mail/drafts',
      {
        method: draftId ? 'PUT' : 'POST',
        json: payload,
      },
    );
    return { result: response, credentials: resolved.credentials || credentials };
  }

  if (toolName === 'neomail_send_draft') {
    const draftId = trimText(args.draft_id);
    if (!draftId) throw new Error('draft_id is required.');
    const { response, credentials } = await requestNeoMail(
      connection,
      `/api/v1/mail/send/draft/${encodeURIComponent(draftId)}`,
      {
        method: 'POST',
        json: { immediate: args.immediate !== false },
      },
    );
    return { result: response, credentials };
  }

  if (toolName === 'neomail_update_thread') {
    const threadId = trimText(args.thread_id);
    if (!threadId) throw new Error('thread_id is required.');
    const payload = {};
    if (args.is_read !== undefined) payload.isRead = args.is_read === true;
    if (args.starred !== undefined) payload.starred = args.starred === true;
    if (args.archived !== undefined) payload.archived = args.archived === true;
    if (args.trashed !== undefined) payload.trashed = args.trashed === true;
    if (Array.isArray(args.labels)) payload.labels = args.labels.map((label) => String(label || '')).filter(Boolean);
    const { response, credentials } = await requestNeoMail(
      connection,
      `/api/v1/mail/threads/${encodeURIComponent(threadId)}`,
      {
        method: 'PATCH',
        json: payload,
      },
    );
    return { result: response, credentials };
  }

  if (toolName === 'neomail_ai_summarize_thread') {
    const threadId = trimText(args.thread_id);
    if (!threadId) throw new Error('thread_id is required.');
    const { response, credentials } = await requestNeoMail(
      connection,
      `/api/v1/mail/ai/thread/${encodeURIComponent(threadId)}/summary`,
      { method: 'POST', json: {} },
    );
    return { result: response, credentials };
  }

  if (toolName === 'neomail_ai_improve_draft') {
    const draftId = trimText(args.draft_id);
    if (!draftId) throw new Error('draft_id is required.');
    const { response, credentials } = await requestNeoMail(
      connection,
      `/api/v1/mail/ai/draft/${encodeURIComponent(draftId)}/improve`,
      {
        method: 'POST',
        json: trimText(args.instruction)
          ? { instruction: trimText(args.instruction) }
          : {},
      },
    );
    return { result: response, credentials };
  }

  if (toolName === 'neomail_ai_ask_inbox') {
    const query = trimText(args.query);
    if (!query) throw new Error('query is required.');
    const { response, credentials } = await requestNeoMail(
      connection,
      '/api/v1/mail/ai/ask',
      {
        method: 'POST',
        json: { query },
      },
    );
    return { result: response, credentials };
  }

  throw new Error(`Unsupported NeoMail tool: ${toolName}`);
}

function createNeoMailProvider() {
  return {
    key: NEOMAIL_PROVIDER_KEY,
    label: 'NeoMail',
    description:
      'Connect a self-hosted NeoMail server so NeoAgent can search inboxes, draft replies, send mail, and trigger automations from new email.',
    icon: 'neomail',
    apps: [NEOMAIL_APP],
    connectPrompt:
      'Add the NeoMail backend URL once, then connect with OAuth. NeoAgent can work across every mailbox visible to that NeoMail user.',
    supportsMultipleAccounts: true,
    connectionMethod: 'oauth',
    getApp(appId) {
      return String(appId || '').trim() === NEOMAIL_APP.id ? NEOMAIL_APP : null;
    },
    getToolAppId(toolName) {
      return toolAppMap.get(String(toolName || '').trim()) || null;
    },
    getEnvStatus(context = {}) {
      const normalizedUserId = Number(context.userId);
      const config = Number.isInteger(normalizedUserId) && normalizedUserId > 0
        ? parseConfigInput(getProviderConfig(normalizedUserId, NEOMAIL_PROVIDER_KEY, context.agentId))
        : { baseUrl: '' };
      const configured = Boolean(trimText(config.baseUrl));
      return {
        configured,
        missing: configured ? [] : ['baseUrl'],
        summary: configured
          ? 'NeoMail is ready for account connections.'
          : 'Add the NeoMail backend URL to enable account connections.',
        setupMode: 'user',
      };
    },
    getToolDefinitions(options = {}) {
      const connectedAppIds = new Set(options.connectedAppIds || []);
      return connectedAppIds.has(NEOMAIL_APP.id) ? TOOL_DEFINITIONS.slice() : [];
    },
    supportsTool(toolName) {
      return toolAppMap.has(String(toolName || '').trim());
    },
    buildSnapshot(connectionRows, context = {}) {
      return buildSnapshot(this, connectionRows, context);
    },
    summarizeForModel(snapshot) {
      if (!snapshot?.env?.configured) {
        return 'NeoMail: setup is not complete for this user yet. Tell them to add the NeoMail backend URL in Official Integrations first.';
      }
      if (!snapshot.connection?.connected) {
        return 'NeoMail: setup is ready, but no NeoMail account is connected yet. Tell the user to connect NeoMail in Official Integrations first.';
      }
      return 'NeoMail: native inbox access is connected in this run with tools for account listing, inbox search, thread reads, drafts, sending, thread updates, and inbox AI.';
    },
    async beginOAuth({ state, codeVerifier, userId, agentId, appKey }) {
      if (String(appKey || '').trim() !== NEOMAIL_APP.id) {
        throw new Error(`Unknown NeoMail app: ${appKey || 'missing app key'}`);
      }
      const config = parseConfigInput(
        getProviderConfig(Number(userId), NEOMAIL_PROVIDER_KEY, resolveAgentId(Number(userId), agentId || null)),
      );
      const baseUrl = normalizeNeoMailBaseUrl(config.baseUrl);
      const bootstrap = await bootstrapNeoMailCompanion(baseUrl);
      const clientId = trimText(bootstrap.clientId);
      if (!clientId) {
        throw new Error('NeoMail companion bootstrap did not return a client ID.');
      }
      const scope = Array.isArray(bootstrap.scopes) && bootstrap.scopes.length > 0
        ? bootstrap.scopes.join(' ')
        : NEOMAIL_COMPANION_SCOPES.join(' ');
      const authorizeUrl = appendQuery(
        trimText(bootstrap.authorizationEndpoint) || `${baseUrl}/oauth/authorize`,
        {
          response_type: 'code',
          client_id: clientId,
          redirect_uri: trimText(bootstrap.redirectUri) || getCallbackUrl(),
          state,
          code_challenge: crypto
            .createHash('sha256')
            .update(String(codeVerifier || ''))
            .digest('base64')
            .replace(/\+/g, '-')
            .replace(/\//g, '_')
            .replace(/=+$/g, ''),
          code_challenge_method: 'S256',
          scope,
        },
      );
      return { url: authorizeUrl };
    },
    async finishOAuth({ userId, agentId, code, codeVerifier }) {
      const config = parseConfigInput(
        getProviderConfig(Number(userId), NEOMAIL_PROVIDER_KEY, resolveAgentId(Number(userId), agentId || null)),
      );
      const baseUrl = normalizeNeoMailBaseUrl(config.baseUrl);
      const bootstrap = await bootstrapNeoMailCompanion(baseUrl);
      const tokenSet = await exchangeNeoMailToken(baseUrl, {
        grant_type: 'authorization_code',
        client_id: trimText(bootstrap.clientId),
        code: trimText(code),
        redirect_uri: trimText(bootstrap.redirectUri) || getCallbackUrl(),
        code_verifier: trimText(codeVerifier),
      });
      const accessToken = trimText(tokenSet.access_token);
      const refreshToken = trimText(tokenSet.refresh_token);
      if (!accessToken || !refreshToken) {
        throw new Error('NeoMail did not return durable OAuth credentials.');
      }

      const [userInfo, mailAccounts] = await Promise.all([
        fetchUserInfo(baseUrl, accessToken),
        fetchAccounts(baseUrl, accessToken).catch(() => []),
      ]);

      const metadata = {
        baseUrl,
        username: trimText(userInfo?.preferred_username),
        email: trimText(userInfo?.email) || null,
        mailboxCount: Array.isArray(mailAccounts) ? mailAccounts.length : 0,
        mailboxes: Array.isArray(mailAccounts)
          ? mailAccounts.slice(0, 20).map((account) => ({
              id: account.id,
              emailAddress: account.emailAddress || null,
              label: account.label || null,
            }))
          : [],
      };

      return {
        accountEmail: connectionLabelForUser(userInfo, baseUrl, mailAccounts),
        scopes: trimText(tokenSet.scope).split(/\s+/g).filter(Boolean),
        credentials: {
          baseUrl,
          client_id: trimText(bootstrap.clientId),
          access_token: accessToken,
          refresh_token: refreshToken,
          scope: trimText(tokenSet.scope),
          token_type: trimText(tokenSet.token_type) || 'Bearer',
          expires_at_ms: Date.now() + (Math.max(1, Number(tokenSet.expires_in) || 3600) * 1000),
        },
        metadata,
      };
    },
    async executeTool(toolName, args, connection) {
      return executeNeoMailTool(toolName, args || {}, connection);
    },
    async fetchTriggerEvents({ connection, config, since, limit }) {
      return fetchNeoMailTriggerEvents(connection, config, { since, limit });
    },
    getUserConfig({ userId, agentId }) {
      const normalizedUserId = Number(userId);
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      const storedConfig = parseConfigInput(
        getProviderConfig(normalizedUserId, NEOMAIL_PROVIDER_KEY, scopedAgentId),
      );
      const accountCount = db.prepare(
        `SELECT COUNT(*) AS count
         FROM integration_connections
         WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND status = 'connected'`,
      ).get(normalizedUserId, scopedAgentId, NEOMAIL_PROVIDER_KEY)?.count || 0;
      return {
        baseUrl: storedConfig.baseUrl,
        configured: Boolean(storedConfig.baseUrl),
        accountCount,
        hasConnectedAccount: accountCount > 0,
      };
    },
    async saveUserConfig({ userId, agentId, config }) {
      const normalizedUserId = Number(userId);
      if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
        throw new Error('A valid user is required to save NeoMail configuration.');
      }
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      const existingConfig = parseConfigInput(
        getProviderConfig(normalizedUserId, NEOMAIL_PROVIDER_KEY, scopedAgentId),
      );
      const parsedConfig = parseConfigInput(config, existingConfig);
      const baseUrl = normalizeNeoMailBaseUrl(parsedConfig.baseUrl);
      const authStatus = await fetchNeoMailAuthStatus(baseUrl);
      await bootstrapNeoMailCompanion(baseUrl);

      setProviderConfig(normalizedUserId, NEOMAIL_PROVIDER_KEY, { baseUrl }, scopedAgentId);

      if (existingConfig.baseUrl && existingConfig.baseUrl !== baseUrl) {
        db.prepare(
          'DELETE FROM integration_connections WHERE user_id = ? AND agent_id = ? AND provider_key = ?',
        ).run(normalizedUserId, scopedAgentId, NEOMAIL_PROVIDER_KEY);
      }

      const accountCount = db.prepare(
        `SELECT COUNT(*) AS count
         FROM integration_connections
         WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND status = 'connected'`,
      ).get(normalizedUserId, scopedAgentId, NEOMAIL_PROVIDER_KEY)?.count || 0;

      return {
        baseUrl,
        configured: true,
        hasConnectedAccount: accountCount > 0,
        accountCount,
        authenticatedOnServer: authStatus?.authenticated === true,
        hasUser: authStatus?.hasUser === true,
      };
    },
    clearUserConfig({ userId, agentId }) {
      const normalizedUserId = Number(userId);
      if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
        throw new Error('A valid user is required to clear NeoMail configuration.');
      }
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      deleteProviderConfig(normalizedUserId, NEOMAIL_PROVIDER_KEY, scopedAgentId);
      db.prepare(
        'DELETE FROM integration_connections WHERE user_id = ? AND agent_id = ? AND provider_key = ?',
      ).run(normalizedUserId, scopedAgentId, NEOMAIL_PROVIDER_KEY);
      return { cleared: true };
    },
  };
}

module.exports = {
  createNeoMailProvider,
};
