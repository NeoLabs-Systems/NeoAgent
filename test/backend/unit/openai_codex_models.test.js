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
