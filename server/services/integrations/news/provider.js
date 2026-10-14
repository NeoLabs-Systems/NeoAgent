'use strict';

const db = require('../../../db/database');
const { resolveAgentId } = require('../../agents/manager');
const {
  deleteProviderConfig,
  getProviderConfig,
  setProviderConfig,
} = require('../provider_config_store');
const { decryptValue, encryptValue } = require('../secrets');
const { fetchJson } = require('../oauth_provider');
const { summarizeAppConnection } = require('../connection_summary');
const { upsertConnectedIntegration } = require('../connection_store');

const PROVIDER_KEY = 'news';
const ACCOUNT_LABEL = 'news:gnews';
const NEWS_APP = {
  id: 'headlines',
  label: 'Headlines',
  description: 'Top headlines from GNews, used by the World News task trigger.',
};

const NEWS_CATEGORIES = [
  'general', 'world', 'nation', 'business', 'technology',
  'entertainment', 'sports', 'science', 'health',
];

const NEWS_TOOL_DEFINITIONS = [
  {
    appId: NEWS_APP.id,
    name: 'news_get_headlines',
    access: 'read',
    description: 'Get the latest top news headlines, optionally filtered by keywords, category, language or country.',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Optional keywords to filter headlines.' },
        category: { type: 'string', description: `One of: ${NEWS_CATEGORIES.join(', ')}. Default world.` },
        lang: { type: 'string', description: 'Two-letter language code, default en.' },
        country: { type: 'string', description: 'Optional two-letter country code.' },
        max: { type: 'number', description: 'Maximum articles to return (1-10), default 10.' },
      },
    },
  },
];

function text(value) {
  return String(value || '').trim();
}

function credentialsOf(connection) {
  try {
    return JSON.parse(decryptValue(connection?.credentials_json || '{}') || '{}') || {};
  } catch {
    return {};
  }
}

function storedApiKey(userId, agentId) {
  return text(getProviderConfig(userId, PROVIDER_KEY, agentId).apiKey);
}

function loadConnection(userId, agentId) {
  return db.prepare(
    `SELECT * FROM integration_connections
     WHERE user_id = ? AND agent_id = ? AND provider_key = ?
     ORDER BY updated_at DESC, id DESC LIMIT 1`,
  ).get(userId, agentId, PROVIDER_KEY);
}

async function fetchHeadlines(apiKey, args = {}, signal = null) {
  const category = NEWS_CATEGORIES.includes(text(args.category).toLowerCase())
    ? text(args.category).toLowerCase()
    : 'world';
  const url = new URL('https://gnews.io/api/v4/top-headlines');
  url.searchParams.set('category', category);
  url.searchParams.set('lang', text(args.lang).toLowerCase() || 'en');
  url.searchParams.set('max', String(Math.max(1, Math.min(Number(args.max) || 10, 10))));
  if (text(args.query)) url.searchParams.set('q', text(args.query));
  if (text(args.country)) url.searchParams.set('country', text(args.country).toLowerCase());
  url.searchParams.set('apikey', apiKey);

  const result = await fetchJson(url.toString(), { method: 'GET', signal }, { serviceName: 'GNews' });
  const articles = Array.isArray(result?.articles) ? result.articles : [];
  return articles.map((article) => ({
    id: text(article.id) || text(article.url),
    title: text(article.title),
    description: text(article.description),
    url: text(article.url),
    source: text(article.source?.name),
    publishedAt: text(article.publishedAt),
  }));
}

function sanitizeConfigForClient(userId, agentId) {
  const connection = loadConnection(userId, agentId);
  const connected = connection?.status === 'connected';
  return {
    hasApiKey: Boolean(storedApiKey(userId, agentId)),
    configured: Boolean(storedApiKey(userId, agentId)),
    accountCount: connected ? 1 : 0,
    hasConnectedAccount: connected,
  };
}

function createNewsProvider() {
  return {
    key: PROVIDER_KEY,
    label: 'World News',
    description: 'Official news integration powered by GNews. Needs a GNews API key (free tier available).',
    icon: 'news',
    apps: [{ ...NEWS_APP }],
    connectPrompt: 'Save a GNews API key to read top headlines and trigger tasks on major world news.',
    supportsMultipleAccounts: false,
    connectionMethod: 'user_config',
    getApp(appId) {
      return text(appId) === NEWS_APP.id ? { ...NEWS_APP } : null;
    },
    getToolAppId(toolName) {
      return this.supportsTool(toolName) ? NEWS_APP.id : null;
    },
    getEnvStatus(context = {}) {
      const userId = Number(context.userId);
      const hasKey = Number.isInteger(userId) && userId > 0
        && Boolean(storedApiKey(userId, resolveAgentId(userId, context.agentId || null)));
      return {
        configured: hasKey,
        missing: hasKey ? [] : ['apiKey'],
        summary: hasKey
          ? 'World News is ready for account connections.'
          : 'Add a GNews API key in Official Integrations.',
        setupMode: 'user',
      };
    },
    buildSnapshot(connectionRows, context = {}) {
      const env = this.getEnvStatus(context);
      const app = summarizeAppConnection(NEWS_APP, connectionRows, env, {
        toolCount: NEWS_TOOL_DEFINITIONS.length,
      });
      return {
        id: this.key,
        label: this.label,
        description: this.description,
        icon: this.icon,
        apps: [app],
        env,
        connection: {
          status: app.connection.status,
          connected: app.connection.connected,
          accountCount: app.connection.accountCount,
          appCount: app.connection.connected ? 1 : 0,
          accountEmail: app.connection.accountEmail,
          lastConnectedAt: app.connection.lastConnectedAt,
        },
        availableToolCount: app.availableToolCount,
        connectPrompt: this.connectPrompt,
        supportsMultipleAccounts: this.supportsMultipleAccounts,
        connectionMethod: this.connectionMethod,
      };
    },
    summarizeForModel(snapshot) {
      if (!snapshot?.env?.configured) {
        return 'World News: setup is not complete. Tell the user to add a GNews API key in Official Integrations.';
      }
      if (!snapshot.connection?.connected) {
        return 'World News: API key saved but not connected. Ask the user to reconnect it in Official Integrations.';
      }
      return 'World News: connected with a top-headlines tool (news_get_headlines).';
    },
    getToolDefinitions({ connectedAppIds } = {}) {
      return new Set(connectedAppIds || []).has(NEWS_APP.id) ? NEWS_TOOL_DEFINITIONS.slice() : [];
    },
    supportsTool(toolName) {
      return NEWS_TOOL_DEFINITIONS.some((tool) => tool.name === text(toolName));
    },
    async executeTool(toolName, args, connection, executionOptions = {}) {
      if (toolName !== 'news_get_headlines') return null;
      const apiKey = text(credentialsOf(connection).apiKey);
      if (!apiKey) throw new Error('GNews API key is missing. Save it again in Official Integrations.');
      const articles = await fetchHeadlines(apiKey, args, executionOptions.signal || null);
      return { result: { count: articles.length, articles } };
    },
    getUserConfig({ userId, agentId }) {
      const normalizedUserId = Number(userId);
      return sanitizeConfigForClient(normalizedUserId, resolveAgentId(normalizedUserId, agentId || null));
    },
    async saveUserConfig({ userId, agentId, config, signal }) {
      const normalizedUserId = Number(userId);
      if (!Number.isInteger(normalizedUserId) || normalizedUserId <= 0) {
        throw new Error('A valid user is required to save World News configuration.');
      }
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      const apiKey = text(config?.apiKey) || storedApiKey(normalizedUserId, scopedAgentId);
      if (!apiKey) throw new Error('GNews API key is required.');

      try {
        await fetchHeadlines(apiKey, { max: 1 }, signal);
      } catch (error) {
        const message = text(error?.message).toLowerCase();
        if (message.includes('401') || message.includes('403') || message.includes('api key')) {
          throw new Error('GNews rejected the API key. Check it and try again.');
        }
        throw error;
      }

      setProviderConfig(normalizedUserId, PROVIDER_KEY, { apiKey }, scopedAgentId);
      upsertConnectedIntegration({
        userId: normalizedUserId,
        agentId: scopedAgentId,
        providerKey: PROVIDER_KEY,
        appKey: NEWS_APP.id,
        accountEmail: ACCOUNT_LABEL,
        scopes: ['gnews:read'],
        credentialsJson: encryptValue(JSON.stringify({ apiKey })),
        metadata: { source: 'gnews' },
      });
      return sanitizeConfigForClient(normalizedUserId, scopedAgentId);
    },
    clearUserConfig({ userId, agentId }) {
      const normalizedUserId = Number(userId);
      const scopedAgentId = resolveAgentId(normalizedUserId, agentId || null);
      deleteProviderConfig(normalizedUserId, PROVIDER_KEY, scopedAgentId);
      db.prepare('DELETE FROM integration_connections WHERE user_id = ? AND agent_id = ? AND provider_key = ?')
        .run(normalizedUserId, scopedAgentId, PROVIDER_KEY);
      return { cleared: true };
    },
  };
}

module.exports = {
  NEWS_CATEGORIES,
  createNewsProvider,
};
