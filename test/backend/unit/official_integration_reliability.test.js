'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, test } = require('node:test');

const {
  IntegrationManager,
} = require('../../../server/services/integrations/manager');
const {
  createFigmaProvider,
} = require('../../../server/services/integrations/figma/provider');
const {
  createMicrosoftProvider,
} = require('../../../server/services/integrations/microsoft/provider');
const {
  createSlackProvider,
} = require('../../../server/services/integrations/slack/provider');
const {
  createWhatsAppPersonalProvider,
} = require('../../../server/services/integrations/whatsapp/provider');
const { getAvailableTools } = require('../../../server/services/ai/tools');

const originalFetch = global.fetch;
const savedEnvironment = {};
const ENV_NAMES = [
  'FIGMA_OAUTH_CLIENT_ID',
  'FIGMA_OAUTH_CLIENT_SECRET',
  'MICROSOFT_OAUTH_CLIENT_ID',
  'MICROSOFT_OAUTH_CLIENT_SECRET',
  'SLACK_OAUTH_CLIENT_ID',
  'SLACK_OAUTH_CLIENT_SECRET',
];

function responseJson(value, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    statusText: status === 200 ? 'OK' : 'Error',
    headers: { get: () => null },
    text: async () => JSON.stringify(value),
  };
}

function expiredConnection(credentials) {
  return {
    id: 91,
    user_id: 1,
    agent_id: 'main',
    provider_key: 'provider',
    app_key: 'app',
    account_email: 'person@example.test',
    status: 'connected',
    credentials_json: JSON.stringify({
      ...credentials,
      expires_at: new Date(Date.now() - 60_000).toISOString(),
    }),
    metadata_json: '{}',
  };
}

function activeMicrosoftConnection() {
  return {
    ...expiredConnection({}),
    provider_key: 'microsoft_365',
    app_key: 'calendar',
    credentials_json: JSON.stringify({
      access_token: 'microsoft-access-active',
      refresh_token: 'microsoft-refresh-active',
      expires_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    }),
  };
}

beforeEach(() => {
  for (const name of ENV_NAMES) {
    savedEnvironment[name] = process.env[name];
    process.env[name] = `${name.toLowerCase()}-test-value`;
  }
});

afterEach(() => {
  global.fetch = originalFetch;
  for (const name of ENV_NAMES) {
    if (savedEnvironment[name] === undefined) delete process.env[name];
    else process.env[name] = savedEnvironment[name];
  }
});

test('Figma refreshes an expired token, retries with it, and returns credentials for persistence', async () => {
  const calls = [];
  const controller = new AbortController();
  global.fetch = async (url, options) => {
    calls.push({ url: String(url), options });
    if (String(url).endsWith('/v1/oauth/token')) {
      return responseJson({
        access_token: 'figma-access-new',
        token_type: 'bearer',
        expires_in: 3600,
      });
    }
    return responseJson({ id: 'figma-user', email: 'person@example.test' });
  };

  const provider = createFigmaProvider();
  const execution = await provider.executeTool(
    'figma_get_me',
    {},
    expiredConnection({
      access_token: 'figma-access-old',
      refresh_token: 'figma-refresh',
    }),
    { signal: controller.signal },
  );

  assert.equal(execution.result.id, 'figma-user');
  assert.equal(execution.credentials.access_token, 'figma-access-new');
  assert.equal(execution.credentials.refresh_token, 'figma-refresh');
  assert.ok(Date.parse(execution.credentials.expires_at) > Date.now());
  assert.equal(calls.length, 2);
  assert.match(calls[0].options.body, /grant_type=refresh_token/);
  assert.match(calls[0].options.body, /refresh_token=figma-refresh/);
  assert.ok(calls.every((call) => call.options.signal));
});

test('Microsoft refreshes expired credentials before a Graph request', async () => {
  const calls = [];
  global.fetch = async (url, options) => {
    calls.push({ url: String(url), options });
    if (String(url).includes('/oauth2/v2.0/token')) {
      return responseJson({
        access_token: 'microsoft-access-new',
        refresh_token: 'microsoft-refresh-new',
        expires_in: 3600,
        scope: 'offline_access Mail.Read',
        token_type: 'Bearer',
      });
    }
    return responseJson({ value: [] });
  };

  const provider = createMicrosoftProvider();
  const execution = await provider.executeTool(
    'microsoft_365_outlook_list_messages',
    {},
    expiredConnection({
      access_token: 'microsoft-access-old',
      refresh_token: 'microsoft-refresh-old',
      scope: 'offline_access Mail.Read',
    }),
  );

  assert.deepEqual(execution.result, { value: [] });
  assert.equal(execution.credentials.access_token, 'microsoft-access-new');
  assert.equal(execution.credentials.refresh_token, 'microsoft-refresh-new');
  assert.equal(calls.length, 2);
  assert.match(calls[0].options.body, /grant_type=refresh_token/);
});

test('Microsoft calendar reminders return event starts instead of overlapping long events', async () => {
  const calls = [];
  global.fetch = async (url, options) => {
    calls.push({ url: String(url), options });
    return responseJson({
      value: [
        {
          id: 'long-event',
          subject: 'Düsseldorf',
          start: { dateTime: '2026-08-27T05:30:00', timeZone: 'UTC' },
          end: { dateTime: '2026-08-30T16:00:00', timeZone: 'UTC' },
          isAllDay: false,
        },
        {
          id: 'upcoming-event',
          subject: 'Zahnarzt',
          start: { dateTime: '2026-08-29T12:30:00', timeZone: 'UTC' },
          end: { dateTime: '2026-08-29T13:00:00', timeZone: 'UTC' },
          isAllDay: false,
        },
        {
          id: 'all-day-event',
          subject: 'Geburtstag',
          start: { dateTime: '2026-08-29T00:00:00', timeZone: 'UTC' },
          end: { dateTime: '2026-08-30T00:00:00', timeZone: 'UTC' },
          isAllDay: true,
        },
      ],
    });
  };

  const provider = createMicrosoftProvider();
  const execution = await provider.executeTool(
    'microsoft_365_calendar_list_events',
    {
      start: '2026-08-29T12:00:00Z',
      end: '2026-08-29T13:00:00Z',
    },
    activeMicrosoftConnection(),
  );

  assert.deepEqual(execution.result.events.map((event) => event.id), [
    'upcoming-event',
  ]);
  assert.equal(execution.result.omittedOngoingTimedCount, 1);
  assert.equal(execution.result.omittedAllDayCount, 1);
  assert.equal(execution.result.windowMode, 'starts_within_window');
  assert.equal(calls[0].options.headers.Prefer, 'outlook.timezone="UTC"');
});

test('automatic Microsoft calendar checks reject unbounded event lists', async () => {
  const provider = createMicrosoftProvider();
  await assert.rejects(
    provider.executeTool(
      'microsoft_365_calendar_list_events',
      {},
      activeMicrosoftConnection(),
      { triggerSource: 'schedule', taskId: 'calendar-task' },
    ),
    /require both start and end/i,
  );
});

test('Slack persists both halves of a rotated user token pair', async () => {
  const calls = [];
  global.fetch = async (url, options) => {
    calls.push({ url: String(url), options });
    if (String(url).endsWith('/api/oauth.v2.access')) {
      return responseJson({
        ok: true,
        access_token: 'bot-access-new',
        authed_user: {
          access_token: 'user-access-new',
          refresh_token: 'user-refresh-new',
          expires_in: 43200,
          token_type: 'user',
        },
      });
    }
    return responseJson({ ok: true, channels: [] });
  };

  const provider = createSlackProvider();
  const execution = await provider.executeTool(
    'slack_list_conversations',
    {},
    expiredConnection({
      access_token: 'user-access-old',
      refresh_token: 'user-refresh-old',
      bot_access_token: 'bot-access-old',
    }),
  );

  assert.deepEqual(execution.result, { ok: true, channels: [] });
  assert.equal(execution.credentials.access_token, 'user-access-new');
  assert.equal(execution.credentials.refresh_token, 'user-refresh-new');
  assert.equal(execution.credentials.bot_access_token, 'bot-access-new');
  assert.ok(Date.parse(execution.credentials.expires_at) > Date.now());
  assert.equal(calls.length, 2);
});

test('credential-bearing integration executions are serialized by account', async () => {
  const manager = Object.create(IntegrationManager.prototype);
  manager.connectionExecutionQueues = new Map();
  const connection = {
    user_id: 1,
    agent_id: 'main',
    provider_key: 'slack',
    account_email: 'person@example.test',
  };

  const releaseFirst = await manager.acquireConnectionExecution(connection);
  let secondAcquired = false;
  const second = manager.acquireConnectionExecution(connection).then((release) => {
    secondAcquired = true;
    return release;
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(secondAcquired, false);

  releaseFirst();
  const releaseSecond = await second;
  assert.equal(secondAcquired, true);
  releaseSecond();
});

test('an aborted queued execution does not break serialization for the next caller', async () => {
  const manager = Object.create(IntegrationManager.prototype);
  manager.connectionExecutionQueues = new Map();
  const connection = {
    user_id: 1,
    agent_id: 'main',
    provider_key: 'slack',
    account_email: 'person@example.test',
  };
  const releaseFirst = await manager.acquireConnectionExecution(connection);
  const controller = new AbortController();
  const aborted = manager.acquireConnectionExecution(connection, controller.signal);
  controller.abort(new Error('queued run stopped'));
  await assert.rejects(aborted, /queued run stopped/);

  let thirdAcquired = false;
  const third = manager.acquireConnectionExecution(connection).then((release) => {
    thirdAcquired = true;
    return release;
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(thirdAcquired, false);

  releaseFirst();
  const releaseThird = await third;
  assert.equal(thirdAcquired, true);
  releaseThird();
});

test('integration manager rethrows cancellation instead of converting it to a tool result', async () => {
  const manager = Object.create(IntegrationManager.prototype);
  manager.connectionExecutionQueues = new Map();
  const connection = expiredConnection({ access_token: 'token' });
  connection.credentials_json = '{}';
  const cancelled = new Error('run cancelled');
  cancelled.name = 'AbortError';
  cancelled.code = 'ABORT_ERR';
  const provider = {
    key: 'fake',
    label: 'Fake',
    requiresRefreshToken: false,
    supportsTool: () => true,
    getEnvStatus: () => ({ configured: true }),
    getToolDefinitions: () => [{ name: 'fake_read', access: 'read' }],
    executeTool: async () => {
      throw cancelled;
    },
  };
  manager.registry = { list: () => [provider] };
  manager.selectToolConnection = () => ({ connection });
  manager.getConnectionById = () => connection;
  manager.parseCredentials = () => ({});

  await assert.rejects(
    manager.executeTool(1, 'fake_read', {}, 'main'),
    (error) => error === cancelled,
  );
});

test('tool compaction retains official integration access metadata for the agent loop', () => {
  const app = {
    locals: {
      integrationManager: {
        getToolDefinitions: () => [{
          name: 'fake_read',
          access: 'read',
          description: 'Read a fake resource.',
          parameters: { type: 'object', properties: {} },
        }],
      },
    },
  };

  const tools = getAvailableTools(app, { userId: 999_999, agentId: 'main' });
  const integrationTool = tools.find((tool) => tool.name === 'fake_read');
  assert.equal(integrationTool?.access, 'read');
});

test('aborting a WhatsApp tool wait does not clear the shared connection attempt', async () => {
  const provider = createWhatsAppPersonalProvider();
  const connection = { id: 44 };
  let resolveConnection;
  const connectPromise = new Promise((resolve) => {
    resolveConnection = resolve;
  });
  const client = {
    status: 'connecting',
    socket: null,
    connectPromise,
  };
  provider.clients.set(connection.id, client);
  const controller = new AbortController();
  const waiting = provider._ensureClient(connection, { signal: controller.signal });
  controller.abort(new Error('WhatsApp tool stopped'));
  await assert.rejects(waiting, /WhatsApp tool stopped/);
  assert.equal(client.connectPromise, connectPromise);

  client.status = 'connected';
  client.socket = {};
  resolveConnection();
  assert.equal(await provider._ensureClient(connection), client);
  await provider.shutdown();
});

test('WhatsApp shutdown clears reconnect work and closes each socket once', async () => {
  const provider = createWhatsAppPersonalProvider();
  let closes = 0;
  const socket = { end: () => { closes += 1; } };
  const reconnectTimer = setTimeout(() => {}, 60_000);
  const sessionTimer = setTimeout(() => {}, 60_000);
  provider.reconnectTimers.set(1, reconnectTimer);
  provider.sessionReconnectTimers.set('session', sessionTimer);
  provider.clients.set(1, { socket, manualDisconnect: false });
  provider.sessions.set('session', { socket });

  await provider.shutdown();

  assert.equal(provider.shuttingDown, true);
  assert.equal(provider.reconnectTimers.size, 0);
  assert.equal(provider.sessionReconnectTimers.size, 0);
  assert.equal(provider.clients.size, 0);
  assert.equal(provider.sessions.size, 0);
  assert.equal(closes, 1);
});
