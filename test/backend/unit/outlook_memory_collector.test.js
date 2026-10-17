'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, test } = require('node:test');

const {
  createMicrosoftProvider,
} = require('../../../server/services/integrations/microsoft/provider');

const originalFetch = global.fetch;
const ENV_NAMES = ['MICROSOFT_OAUTH_CLIENT_ID', 'MICROSOFT_OAUTH_CLIENT_SECRET'];
const savedEnvironment = {};

function responseJson(value, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    statusText: status === 200 ? 'OK' : 'Error',
    headers: { get: () => null },
    text: async () => JSON.stringify(value),
  };
}

function outlookConnection(expiresInMs = 60 * 60 * 1000) {
  return {
    id: 5,
    user_id: 1,
    agent_id: 'main',
    provider_key: 'microsoft_365',
    app_key: 'outlook',
    account_email: 'person@example.test',
    status: 'connected',
    credentials_json: JSON.stringify({
      access_token: 'microsoft-access',
      refresh_token: 'microsoft-refresh',
      expires_at: new Date(Date.now() + expiresInMs).toISOString(),
    }),
    metadata_json: '{}',
  };
}

function message(id, conversationId, extra = {}) {
  return {
    id,
    conversationId,
    subject: `Subject ${conversationId}`,
    from: { emailAddress: { name: 'Ana', address: 'ana@example.test' } },
    toRecipients: [{ emailAddress: { address: 'person@example.test' } }],
    receivedDateTime: '2026-09-01T10:00:00Z',
    body: { content: `Body of ${id}` },
    bodyPreview: `Preview ${id}`,
    importance: 'normal',
    flag: { flagStatus: 'notFlagged' },
    inferenceClassification: 'focused',
    ...extra,
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

test('Outlook sweep follows nextLink, groups conversations, and adds sent mail', async () => {
  const calls = [];
  global.fetch = async (url, options) => {
    const target = new URL(String(url));
    calls.push({ url: target, options });
    if (target.pathname === '/v1.0/me/messages' && !target.searchParams.get('page')) {
      return responseJson({
        value: [
          message('m1', 'c1', { importance: 'high' }),
          message('m2', 'c2'),
        ],
        '@odata.nextLink': 'https://graph.microsoft.com/v1.0/me/messages?page=2',
      });
    }
    if (target.pathname === '/v1.0/me/messages') {
      return responseJson({ value: [message('m3', 'c1', { subject: 'Older reply' })] });
    }
    if (target.pathname === '/v1.0/me/mailFolders/sentitems/messages') {
      return responseJson({
        value: [
          message('s1', 'c2'),
          message('s2', 'c3', { sentDateTime: '2026-08-01T09:00:00Z', receivedDateTime: null }),
        ],
      });
    }
    throw new Error(`Unexpected request ${target}`);
  };

  const provider = createMicrosoftProvider();
  const collected = await provider.collectMemorySweep({
    connection: outlookConnection(),
    sourceTypes: ['email'],
  });

  assert.deepEqual(
    collected.documents.map((doc) => doc.externalObjectId),
    ['c1', 'c2', 'c3'],
  );
  const first = collected.documents[0];
  assert.equal(first.title, 'Subject c1');
  assert.match(first.content, /Messages: 2/);
  assert.match(first.content, /Participants: Ana <ana@example.test>, person@example.test/);
  assert.match(first.content, /Body of m1/);
  assert.equal(first.salience, 8);
  assert.equal(collected.documents[2].salience, 7);
  assert.equal(collected.documents[2].sourceTimestamp, '2026-08-01T09:00:00Z');

  const firstFilter = calls[0].url.searchParams.get('$filter');
  assert.match(firstFilter, /receivedDateTime ge .* and \(importance eq 'high'/);
  assert.equal(calls[0].options.headers.Prefer, 'outlook.body-content-type="text"');
  assert.equal(calls[1].url.searchParams.get('page'), '2');
  assert.equal(calls.length, 3);
});

test('Outlook sweep falls back to a date filter when Graph rejects the combined filter', async () => {
  const filters = [];
  global.fetch = async (url) => {
    const target = new URL(String(url));
    if (target.pathname === '/v1.0/me/messages') {
      const filter = target.searchParams.get('$filter');
      filters.push(filter);
      if (filter.includes('importance')) {
        return responseJson({ error: { code: 'InefficientFilter' } }, 400);
      }
      return responseJson({
        value: [
          message('m1', 'c1', { inferenceClassification: 'other' }),
          message('m2', 'c2', { flag: { flagStatus: 'flagged' }, inferenceClassification: 'other' }),
        ],
      });
    }
    return responseJson({ value: [] });
  };

  const provider = createMicrosoftProvider();
  const collected = await provider.collectMemorySweep({
    connection: outlookConnection(),
    sourceTypes: ['email'],
  });

  assert.equal(filters.length, 2);
  assert.doesNotMatch(filters[1], /importance/);
  assert.deepEqual(collected.documents.map((doc) => doc.externalObjectId), ['c2']);
});

test('Outlook sweep returns refreshed credentials for persistence', async () => {
  global.fetch = async (url) => {
    if (String(url).includes('/oauth2/v2.0/token')) {
      return responseJson({
        access_token: 'microsoft-access-new',
        refresh_token: 'microsoft-refresh-new',
        expires_in: 3600,
        token_type: 'Bearer',
      });
    }
    return responseJson({ value: [] });
  };

  const provider = createMicrosoftProvider();
  const collected = await provider.collectMemorySweep({
    connection: outlookConnection(-60_000),
    sourceTypes: ['email'],
  });

  assert.deepEqual(collected.documents, []);
  assert.equal(collected.credentials.access_token, 'microsoft-access-new');
});

test('Outlook offers no recurring memory sync', () => {
  assert.equal(createMicrosoftProvider().collectMemoryDocuments, undefined);
});

test('Outlook sweep skips conversations already in memory', async () => {
  global.fetch = async (url) => {
    const target = new URL(String(url));
    if (target.pathname === '/v1.0/me/messages') {
      return responseJson({ value: [message('m1', 'c1'), message('m2', 'c2')] });
    }
    return responseJson({ value: [] });
  };

  const provider = createMicrosoftProvider();
  const collected = await provider.collectMemorySweep({
    connection: outlookConnection(),
    sourceTypes: ['email'],
    skipObjectIds: new Set(['c1']),
  });

  assert.deepEqual(collected.documents.map((doc) => doc.externalObjectId), ['c2']);
});
