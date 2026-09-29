'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { OpenAICodexProvider } = require('../../../server/services/ai/providers/openaiCodex');

test('OpenAI Codex discovers selectable models from the live Codex catalog', async () => {
  let requestUrl = '';
  const provider = new OpenAICodexProvider({
    apiKey: 'codex-access-token',
    fetch: async (request) => {
      requestUrl = typeof request === 'string' ? request : request.url;
      return new Response(JSON.stringify({
        models: [
          {
            slug: 'gpt-live',
            display_name: 'GPT Live',
            supported_in_api: true,
            visibility: 'list',
          },
          {
            slug: 'gpt-hidden',
            display_name: 'GPT Hidden',
            supported_in_api: true,
            visibility: 'hide',
          },
          {
            slug: 'gpt-unsupported',
            display_name: 'GPT Unsupported',
            supported_in_api: false,
            visibility: 'list',
          },
        ],
      }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    },
  });

  const models = await provider.listModels();

  assert.deepEqual(models, [{ id: 'gpt-live', name: 'GPT Live' }]);
  const url = new URL(requestUrl);
  assert.equal(url.pathname, '/backend-api/codex/models');
  assert.equal(url.searchParams.get('client_version'), require('../../../package.json').version);
});

test('OpenAI Codex renews an expired access token once and retries the request', async () => {
  const fs = require('node:fs');
  const os = require('node:os');
  const path = require('node:path');
  const envFile = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'codex-refresh-')), '.env');
  process.env.NEOAGENT_ENV_FILE = envFile;
  process.env.OPENAI_CODEX_ACCESS_TOKEN = 'expired-token';
  process.env.OPENAI_CODEX_REFRESH_TOKEN = 'refresh-1';
  delete require.cache[require.resolve('../../../runtime/paths')];
  delete require.cache[require.resolve('../../../server/services/ai/providers/openaiCodex')];
  const { OpenAICodexProvider: FreshProvider } = require('../../../server/services/ai/providers/openaiCodex');

  const modelAuth = [];
  let refreshBody = null;
  const fetchImpl = async (request, init = {}) => {
    const url = typeof request === 'string' ? request : request.url;
    if (url === 'https://auth.openai.com/oauth/token') {
      refreshBody = JSON.parse(init.body);
      return new Response(JSON.stringify({ access_token: 'fresh-token', refresh_token: 'refresh-2' }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    }
    const headers = new Headers(init.headers || request.headers);
    modelAuth.push(headers.get('authorization'));
    if (headers.get('authorization') !== 'Bearer fresh-token') {
      return new Response(JSON.stringify({ detail: 'expired' }), {
        status: 401,
        headers: { 'content-type': 'application/json' },
      });
    }
    return new Response(JSON.stringify({ models: [{ slug: 'gpt-live', supported_in_api: true }] }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  };

  try {
    const provider = new FreshProvider({ apiKey: 'expired-token', fetch: fetchImpl });
    const models = await provider.listModels();

    assert.deepEqual(models, [{ id: 'gpt-live', name: 'gpt-live' }]);
    assert.deepEqual(modelAuth, ['Bearer expired-token', 'Bearer fresh-token']);
    assert.equal(refreshBody.grant_type, 'refresh_token');
    assert.equal(refreshBody.refresh_token, 'refresh-1');
    assert.equal(process.env.OPENAI_CODEX_ACCESS_TOKEN, 'fresh-token');
    assert.equal(process.env.OPENAI_CODEX_REFRESH_TOKEN, 'refresh-2');
    const saved = fs.readFileSync(envFile, 'utf8');
    assert.match(saved, /^OPENAI_CODEX_ACCESS_TOKEN=fresh-token$/m);
    assert.match(saved, /^OPENAI_CODEX_REFRESH_TOKEN=refresh-2$/m);
  } finally {
    delete process.env.NEOAGENT_ENV_FILE;
    delete process.env.OPENAI_CODEX_ACCESS_TOKEN;
    delete process.env.OPENAI_CODEX_REFRESH_TOKEN;
  }
});
