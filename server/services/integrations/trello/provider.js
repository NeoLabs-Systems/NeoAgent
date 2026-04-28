'use strict';

const db = require('../../../db/database');
const { resolveAgentId } = require('../../agents/manager');
const {
  deleteProviderConfig,
  getProviderConfig,
  setProviderConfig,
} = require('../provider_config_store');
const { getConnectionAccessMode } = require('../access');
const { fetchJson } = require('../oauth_provider');

const TRELLO_APP = {
  id: 'trello',
  label: 'Trello',
  description: 'Connect Trello for board, list, card, and comment tools.',
};

const TRELLO_TOOL_DEFINITIONS = [
  {
    appId: TRELLO_APP.id,
    name: 'trello_get_me',
    access: 'read',
    description: 'Get the connected Trello member profile.',
    parameters: { type: 'object', properties: {} },
  },
  {
    appId: TRELLO_APP.id,
    name: 'trello_list_boards',
    access: 'read',
    description: 'List boards visible to the connected Trello member.',
    parameters: {
      type: 'object',
      properties: {
        filter: { type: 'string', description: 'Optional board filter such as open, closed, or all.' },
        limit: { type: 'number', description: 'Maximum boards to return, default 50.' },
      },
    },
  },
  {
    appId: TRELLO_APP.id,
    name: 'trello_get_board',
    access: 'read',
    description: 'Get a Trello board and optional list/card summary.',
    parameters: {
      type: 'object',
      properties: {
        board_id: { type: 'string', description: 'Trello board ID.' },
        fields: { type: 'string', description: 'Optional comma-separated board fields to return.' },
        lists: { type: 'string', description: 'Optional list expansion, default open.' },
        cards: { type: 'string', description: 'Optional card expansion, default none.' },
      },
      required: ['board_id'],
    },
  },
  {
    appId: TRELLO_APP.id,
    name: 'trello_list_lists',
    access: 'read',
    description: 'List the lists on a Trello board.',
    parameters: {
      type: 'object',
      properties: {
        board_id: { type: 'string', description: 'Trello board ID.' },
        fields: { type: 'string', description: 'Optional comma-separated list fields to return.' },
      },
      required: ['board_id'],
    },
  },
  {
    appId: TRELLO_APP.id,
    name: 'trello_list_cards',
    access: 'read',
    description: 'List cards on a Trello board or list.',
    parameters: {
      type: 'object',
      properties: {
        board_id: { type: 'string', description: 'Optional Trello board ID.' },
        list_id: { type: 'string', description: 'Optional Trello list ID.' },
        filter: { type: 'string', description: 'Optional Trello card filter, default open.' },
        fields: { type: 'string', description: 'Optional comma-separated card fields to return.' },
        limit: { type: 'number', description: 'Maximum cards to return, default 100.' },
      },
    },
  },
  {
    appId: TRELLO_APP.id,
    name: 'trello_get_card',
    access: 'read',
    description: 'Get a Trello card by ID.',
    parameters: {
      type: 'object',
      properties: {
        card_id: { type: 'string', description: 'Trello card ID.' },
        fields: { type: 'string', description: 'Optional comma-separated card fields to return.' },
      },
      required: ['card_id'],
    },
  },
  {
    appId: TRELLO_APP.id,
    name: 'trello_search',
    access: 'read',
    description: 'Search Trello boards, cards, members, and organizations.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Search text.' },
        model_types: {
          type: 'string',
          description: 'Optional comma-separated model types, default cards,boards,lists,members,organizations.',
        },
        limit: { type: 'number', description: 'Maximum combined results to return, default 20.' },
      },
      required: ['query'],
    },
  },
  {
    appId: TRELLO_APP.id,
    name: 'trello_create_card',
    access: 'write',
    description: 'Create a Trello card on a list.',
    parameters: {
      type: 'object',
      properties: {
        list_id: { type: 'string', description: 'Target Trello list ID.' },
        name: { type: 'string', description: 'Card title.' },
        desc: { type: 'string', description: 'Optional card description.' },
        due: { type: 'string', description: 'Optional ISO 8601 due date.' },
      },
      required: ['list_id', 'name'],
    },
  },
  {
    appId: TRELLO_APP.id,
    name: 'trello_update_card',
    access: 'write',
    description: 'Update a Trello card.',
    parameters: {
      type: 'object',
      properties: {
        card_id: { type: 'string', description: 'Trello card ID.' },
        name: { type: 'string', description: 'Optional new card title.' },
        desc: { type: 'string', description: 'Optional new card description.' },
        closed: { type: 'boolean', description: 'Optional archived state.' },
        idList: { type: 'string', description: 'Optional target list ID.' },
        pos: { type: 'string', description: 'Optional position value such as top, bottom, or a number.' },
        due: { type: 'string', description: 'Optional ISO 8601 due date.' },
        dueComplete: { type: 'boolean', description: 'Optional due-complete state.' },
      },
      required: ['card_id'],
    },
  },
  {
    appId: TRELLO_APP.id,
    name: 'trello_add_comment',
    access: 'write',
    description: 'Add a comment to a Trello card.',
    parameters: {
      type: 'object',
      properties: {
        card_id: { type: 'string', description: 'Trello card ID.' },
        text: { type: 'string', description: 'Comment text.' },
      },
      required: ['card_id', 'text'],
    },
  },
  {
    appId: TRELLO_APP.id,
    name: 'trello_api_request',
    access: 'dynamic_http_method',
    description: 'Make an authenticated Trello REST API request for advanced operations.',
    parameters: {
      type: 'object',
      properties: {
        method: { type: 'string', description: 'HTTP method: GET, POST, PUT, PATCH, or DELETE.' },
        path: { type: 'string', description: 'Trello API path under /1, for example /1/cards/{id}.' },
        query: { type: 'object', description: 'Optional query parameters.' },
        body: { type: 'object', description: 'Optional request fields, sent as Trello query parameters.' },
      },
      required: ['method', 'path'],
    },
  },
];

const toolAppMap = new Map(TRELLO_TOOL_DEFINITIONS.map((tool) => [tool.name, tool.appId]));

function trimText(value) {
  return String(value || '').trim();
}

function requireText(value, label) {
  const text = trimText(value);
  if (!text) {
    throw new Error(`${label} is required.`);
  }
  return text;
}

function parseConfigInput(rawConfig, existingConfig = {}) {
  const source = rawConfig && typeof rawConfig === 'object' ? rawConfig : {};
  return {
    apiKey: trimText(source.apiKey) || trimText(existingConfig.apiKey),
    token: trimText(source.token) || trimText(existingConfig.token),
  };
}

function resolveTrelloConfigForUser(userId) {
  const normalizedUserId = Number(userId);
  const config =
    Number.isInteger(normalizedUserId) && normalizedUserId > 0
      ? parseConfigInput(getProviderConfig(normalizedUserId, 'trello'))
      : { apiKey: '', token: '' };
  const envApiKey = trimText(process.env.TRELLO_API_KEY || '');
  const apiKey = envApiKey || config.apiKey;
  const missing = [];
  if (!apiKey) missing.push('apiKey');
  if (!config.token) missing.push('token');
  return { apiKey, token: config.token, configured: missing.length === 0, missing };
}

function sanitizeTrelloUserConfigForClient(rawConfig) {
  const config = parseConfigInput(rawConfig);
  const envApiKey = trimText(process.env.TRELLO_API_KEY || '');
  const apiKeyConfigured = Boolean(envApiKey || config.apiKey);
  return {
    apiKey: config.apiKey,
    apiKeyConfigured,
    hasToken: Boolean(config.token),
    configured: Boolean(apiKeyConfigured && config.token),
  };
}

function trelloUrl(path, query = {}, config = {}) {
  const apiKey = trimText(config.apiKey);
  const token = trimText(config.token);
  if (!apiKey) {
    throw new Error('Trello API key is required.');
  }
  if (!token) {
    throw new Error('Trello token is required.');
  }

  const rawPath = trimText(path);
  const url = new URL(
    rawPath.startsWith('http')
      ? rawPath
      : `https://api.trello.com${rawPath.startsWith('/') ? '' : '/'}${rawPath}`,
  );
  if (url.hostname !== 'api.trello.com') {
    throw new Error('Trello API request URL must target api.trello.com.');
  }

  url.searchParams.set('key', apiKey);
  url.searchParams.set('token', token);
  for (const [key, value] of Object.entries(query || {})) {
    if (value === undefined || value === null) continue;
    const text = String(value).trim();
    if (!text) continue;
    url.searchParams.set(key, text);
  }
  return url.toString();
}

async function trelloRequest(config, options = {}) {
  return fetchJson(
    trelloUrl(options.path, options.query, config),
    { method: String(options.method || 'GET').toUpperCase() },
    { serviceName: 'Trello' },
  );
}

async function fetchTrelloMemberProfile(config) {
  return trelloRequest(config, {
    path: '/1/members/me',
    query: { fields: 'id,username,fullName,url,initials' },
  });
}

function trelloAccountEmail(profile = {}) {
  const username = trimText(profile.username);
  const memberId = trimText(profile.id);
  const fallback = trimText(profile.fullName) || 'member';
  return `trello:${username || memberId || fallback}`;
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

function summarizeAppConnection(app, connectionRows, envStatus) {
  const summarizedAccounts = (Array.isArray(connectionRows) ? connectionRows : []).map((row) =>
    summarizeAccountRow(row, envStatus),
  );
  const connectedAccounts = summarizedAccounts.filter((account) => account.connected);
  const latestConnectedAt =
    connectedAccounts
      .map((account) => account.lastConnectedAt)
      .filter(Boolean)
      .sort()
      .reverse()[0] || null;
  const status = !envStatus.configured
    ? 'env_not_configured'
    : connectedAccounts.length > 0
      ? 'connected'
      : summarizedAccounts.some((account) => account.status === 'authorizing')
        ? 'authorizing'
        : 'not_connected';

  return {
    id: app.id,
    label: app.label,
    description: app.description,
    accounts: summarizedAccounts,
    connection: {
      status,
      connected: connectedAccounts.length > 0,
      accountCount: connectedAccounts.length,
      accountEmail:
        connectedAccounts.length === 1 ? connectedAccounts[0].accountEmail : null,
      lastConnectedAt: latestConnectedAt,
    },
    availableToolCount:
      envStatus.configured && connectedAccounts.length > 0 ? TRELLO_TOOL_DEFINITIONS.length : 0,
  };
}

function buildConnectedAppSummary(appSnapshots) {
  return appSnapshots
    .filter((app) => app.connection.connected)
    .map((app) => {
      const emails = app.accounts
        .filter((account) => account.connected)
        .map((account) => account.accountEmail || `connection ${account.id}`)
        .join(', ');
      return `${app.label}: ${emails}`;
    })
    .join(' | ');
}

function resolveTrelloEnvStatus(userId) {
  try {
    const config = resolveTrelloConfigForUser(userId);
    return {
      configured: config.configured,
      missing: config.missing,
      summary: config.configured
        ? 'Trello is ready for account connections.'
        : 'Add your Trello API key and token in Official Integrations to enable Trello tools.',
      setupMode: 'user',
    };
  } catch (error) {
    return {
      configured: false,
      missing: ['apiKey', 'token'],
      summary: `Trello setup is invalid: ${error?.message || 'unknown error'}`,
      setupMode: 'user',
    };
  }
}

function loadExistingAccessMode(userId, agentId) {
  const connection = db
    .prepare(
      `SELECT metadata_json
       FROM integration_connections
       WHERE user_id = ? AND agent_id = ? AND provider_key = ?`,
    )
    .get(userId, agentId, TRELLO_APP.id);
  return getConnectionAccessMode(connection || null);
}

function upsertTrelloConnection(userId, agentId, profile) {
  const accountEmail = trelloAccountEmail(profile);
  const accessMode = loadExistingAccessMode(userId, agentId);

  db.prepare(
    'DELETE FROM integration_connections WHERE user_id = ? AND agent_id = ? AND provider_key = ?',
  ).run(userId, agentId, TRELLO_APP.id);

  db.prepare(
    `INSERT INTO integration_connections (
       user_id,
       agent_id,
       provider_key,
       app_key,
       status,
       account_email,
       scopes_json,
       credentials_json,
       metadata_json,
       last_connected_at,
       updated_at
     ) VALUES (?, ?, ?, ?, 'connected', ?, ?, ?, ?, datetime('now'), datetime('now'))`,
  ).run(
    userId,
    agentId,
    TRELLO_APP.id,
    TRELLO_APP.id,
    accountEmail,
    JSON.stringify(['trello:api']),
    JSON.stringify({}),
    JSON.stringify({
      access_mode: accessMode,
      trelloMemberId: profile.id || null,
      username: profile.username || null,
      fullName: profile.fullName || null,
      url: profile.url || null,
    }),
  );

  const connection = db
    .prepare(
      `SELECT * FROM integration_connections
       WHERE user_id = ? AND agent_id = ? AND provider_key = ? AND app_key = ? AND account_email = ?`,
    )
    .get(userId, agentId, TRELLO_APP.id, TRELLO_APP.id, accountEmail);

  return { connection, accountEmail };
}

function createTrelloConnectionResult(profile) {
  return {
    apiKey: profile.apiKey || '',
    hasToken: true,
    configured: true,
    accountEmail: trelloAccountEmail(profile),
    memberId: profile.id || null,
    username: profile.username || null,
    fullName: profile.fullName || null,
  };
}

async function executeTrelloTool(toolName, args, connection) {
  const config = resolveTrelloConfigForUser(connection?.user_id);
  if (!config.configured) {
    throw new Error('Trello API key and token are required. Reopen Official Integrations and save your setup again.');
  }

  switch (toolName) {
    case 'trello_get_me': {
      const me = await fetchTrelloMemberProfile(config);
      return {
        result: {
          id: me?.id || null,
          username: me?.username || null,
          fullName: me?.fullName || null,
          initials: me?.initials || null,
          url: me?.url || null,
        },
      };
    }
    case 'trello_list_boards': {
      const boards = await trelloRequest(config, {
        path: '/1/members/me/boards',
        query: {
          fields: 'name,url,closed,dateLastActivity',
          filter: trimText(args.filter) || 'open',
        },
      });
      const limit = Math.max(1, Math.min(Number(args.limit) || 50, 200));
      return { result: Array.isArray(boards) ? boards.slice(0, limit) : [] };
    }
    case 'trello_get_board': {
      const board = await trelloRequest(config, {
        path: `/1/boards/${encodeURIComponent(requireText(args.board_id, 'board_id'))}`,
        query: {
          fields: trimText(args.fields) || 'name,desc,url,closed,dateLastActivity',
          lists: trimText(args.lists) || 'open',
          cards: trimText(args.cards) || 'none',
        },
      });
      return { result: board };
    }
    case 'trello_list_lists': {
      const lists = await trelloRequest(config, {
        path: `/1/boards/${encodeURIComponent(requireText(args.board_id, 'board_id'))}/lists`,
        query: { fields: trimText(args.fields) || 'name,closed,pos' },
      });
      return { result: Array.isArray(lists) ? lists : [] };
    }
    case 'trello_list_cards': {
      const boardId = trimText(args.board_id);
      const listId = trimText(args.list_id);
      const limit = Math.max(1, Math.min(Number(args.limit) || 100, 500));
      const cards = await trelloRequest(config, {
        path: listId
          ? `/1/lists/${encodeURIComponent(listId)}/cards`
          : `/1/boards/${encodeURIComponent(requireText(boardId, 'board_id'))}/cards`,
        query: {
          fields: trimText(args.fields) || 'name,desc,idList,closed,pos,due,dueComplete,url',
          filter: trimText(args.filter) || 'open',
        },
      });
      return { result: Array.isArray(cards) ? cards.slice(0, limit) : [] };
    }
    case 'trello_get_card': {
      const card = await trelloRequest(config, {
        path: `/1/cards/${encodeURIComponent(requireText(args.card_id, 'card_id'))}`,
        query: { fields: trimText(args.fields) || 'name,desc,idList,closed,pos,due,dueComplete,url' },
      });
      return { result: card };
    }
    case 'trello_search': {
      const queryText = requireText(args.query, 'query');
      const searchResult = await trelloRequest(config, {
        path: '/1/search',
        query: {
          query: queryText,
          modelTypes:
            trimText(args.model_types) || 'cards,boards,lists,members,organizations',
        },
      });
      const limit = Math.max(1, Math.min(Number(args.limit) || 20, 100));
      const results = [];
      for (const [type, items] of Object.entries(searchResult || {})) {
        if (!Array.isArray(items)) continue;
        for (const item of items) {
          results.push({ type, ...item });
        }
      }
      return { result: { query: queryText, count: results.length, results: results.slice(0, limit) } };
    }
    case 'trello_create_card': {
      const result = await trelloRequest(config, {
        method: 'POST',
        path: '/1/cards',
        query: {
          idList: requireText(args.list_id, 'list_id'),
          name: requireText(args.name, 'name'),
          ...(trimText(args.desc) ? { desc: trimText(args.desc) } : {}),
          ...(trimText(args.due) ? { due: trimText(args.due) } : {}),
        },
      });
      return { result };
    }
    case 'trello_update_card': {
      const query = {};
      for (const [key, value] of Object.entries({
        name: args.name,
        desc: args.desc,
        closed: args.closed,
        idList: args.idList,
        pos: args.pos,
        due: args.due,
        dueComplete: args.dueComplete,
      })) {
        if (value === undefined || value === null) continue;
        if (typeof value === 'string' && !trimText(value)) continue;
        query[key] = value;
      }
      if (Object.keys(query).length === 0) {
        throw new Error('At least one update field is required.');
      }
      const result = await trelloRequest(config, {
        method: 'PUT',
        path: `/1/cards/${encodeURIComponent(requireText(args.card_id, 'card_id'))}`,
        query,
      });
      return { result };
    }
    case 'trello_add_comment': {
      const result = await trelloRequest(config, {
        method: 'POST',
        path: `/1/cards/${encodeURIComponent(requireText(args.card_id, 'card_id'))}/actions/comments`,
        query: { text: requireText(args.text, 'text') },
      });
      return { result };
    }
    case 'trello_api_request': {
      const result = await trelloRequest(config, {
        method: args.method,
        path: requireText(args.path, 'path'),
        query: {
          ...(args.query && typeof args.query === 'object' ? args.query : {}),
          ...(args.body && typeof args.body === 'object' ? args.body : {}),
        },
      });
      return { result };
    }
    default:
      return null;
  }
}

function createTrelloProvider() {
  return {
    key: 'trello',
    label: 'Trello',
    description:
      'Official Trello integration for user-managed API key and token setup with board, list, card, and comment tools.',
    icon: 'trello',
    apps: [TRELLO_APP],
    connectPrompt:
      'Save your Trello API key and token to expose structured board, list, card, and comment tools.',
    getApp(appId) {
      return String(appId || '').trim() === TRELLO_APP.id ? TRELLO_APP : null;
    },
    getToolAppId(toolName) {
      return toolAppMap.get(String(toolName || '').trim()) || null;
    },
    getEnvStatus(context = {}) {
      return resolveTrelloEnvStatus(context.userId);
    },
    getToolDefinitions(options = {}) {
      const connectedAppIds = new Set(options.connectedAppIds || []);
      return connectedAppIds.has(TRELLO_APP.id) ? TRELLO_TOOL_DEFINITIONS.slice() : [];
    },
    supportsTool(toolName) {
      return toolAppMap.has(String(toolName || '').trim());
    },
    buildSnapshot(connectionRows, context = {}) {
      const env = this.getEnvStatus(context);
      const byApp = new Map();
      for (const row of Array.isArray(connectionRows) ? connectionRows : []) {
        const appId = String(row.app_key || '').trim();
        if (!byApp.has(appId)) byApp.set(appId, []);
        byApp.get(appId).push(row);
      }

      const appSnapshots = [TRELLO_APP].map((app) => {
        const snapshot = summarizeAppConnection(app, byApp.get(app.id) || [], env);
        snapshot.availableToolCount =
          env.configured && snapshot.connection.connected
            ? TRELLO_TOOL_DEFINITIONS.length
            : 0;
        return snapshot;
      });
      const connectedApps = appSnapshots.filter((app) => app.connection.connected);
      const connectedAccounts = connectedApps.flatMap((app) =>
        app.accounts.filter((account) => account.connected),
      );

      return {
        id: this.key,
        label: this.label,
        description: this.description,
        icon: this.icon,
        apps: appSnapshots,
        env,
        connection: {
          status: !env.configured
            ? 'env_not_configured'
            : connectedAccounts.length > 0
              ? 'connected'
              : 'not_connected',
          connected: connectedAccounts.length > 0,
          accountEmail:
            connectedAccounts.length === 1 ? connectedAccounts[0].accountEmail : null,
          accountCount: connectedAccounts.length,
          appCount: connectedApps.length,
          lastConnectedAt:
            connectedAccounts
              .map((account) => account.lastConnectedAt)
              .filter(Boolean)
              .sort()
              .reverse()[0] || null,
        },
        availableToolCount: appSnapshots.reduce((total, app) => total + app.availableToolCount, 0),
        connectPrompt: this.connectPrompt,
      };
    },
    summarizeForModel(snapshot) {
      if (!snapshot?.env?.configured) {
        return 'Trello: setup is not complete for this user yet. Tell them to finish Trello setup in Official Integrations first.';
      }
      if (!snapshot.connection?.connected) {
        return 'Trello: setup is ready, but no Trello account is connected yet. Tell the user to finish setup in Official Integrations first.';
      }
      return 'Trello: native Trello access is connected in this run with board, list, card, comment, and search tools.';
    },
    async executeTool(toolName, args, connection) {
      return executeTrelloTool(toolName, args, connection);
    },
    getUserConfig({ userId }) {
      return sanitizeTrelloUserConfigForClient(getProviderConfig(Number(userId), 'trello'));
    },
    async saveUserConfig({ userId, agentId, config }) {
      const normalizedUserId = Number(userId);
      if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
        throw new Error('A valid user is required to save Trello configuration.');
      }

      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      const rawConfig = config && typeof config === 'object' ? config : {};
      const existingConfig = parseConfigInput(getProviderConfig(normalizedUserId, 'trello'));
      const envApiKey = trimText(process.env.TRELLO_API_KEY || '');
      
      // Resolve API key: from env, new config, or existing config
      const apiKey = envApiKey || trimText(rawConfig.apiKey) || trimText(existingConfig.apiKey);
      const token = trimText(rawConfig.token) || trimText(existingConfig.token);

      if (!apiKey) {
        throw new Error('Trello API key is required (set via environment or configuration).');
      }
      if (!token) {
        throw new Error('Trello token is required.');
      }

      let profile;
      try {
        profile = await fetchTrelloMemberProfile({ apiKey, token });
      } catch (error) {
        const message = String(error?.message || '').toLowerCase();
        if (
          message.includes('invalid key') ||
          message.includes('invalid token') ||
          message.includes('unauthorized') ||
          message.includes('401')
        ) {
          throw new Error(
            'Trello rejected the API key/token pair. If you changed the API key, paste the matching token too.',
          );
        }
        throw error;
      }
      
      // Store only the token if API key is from environment
      const configToStore = envApiKey ? { token } : { apiKey, token };
      setProviderConfig(normalizedUserId, 'trello', configToStore);
      upsertTrelloConnection(normalizedUserId, scopedAgentId, profile || {});
      return createTrelloConnectionResult({
        ...profile,
        apiKey,
      });
    },
    clearUserConfig({ userId, agentId }) {
      const normalizedUserId = Number(userId);
      if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
        throw new Error('A valid user is required to clear Trello configuration.');
      }
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      deleteProviderConfig(normalizedUserId, 'trello');
      db.prepare(
        'DELETE FROM integration_connections WHERE user_id = ? AND agent_id = ? AND provider_key = ?',
      ).run(normalizedUserId, scopedAgentId, TRELLO_APP.id);
      return { cleared: true };
    },
  };
}

module.exports = {
  createTrelloProvider,
};