'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

test('Google model discovery follows every catalog page', async () => {
  const http = require('../../../server/services/network/http');
  const originalFetchResponseText = http.fetchResponseText;
  const googlePath = require.resolve('../../../server/services/ai/providers/google');
  const requestedUrls = [];

  http.fetchResponseText = async (url) => {
    requestedUrls.push(url);
    const secondPage = url.includes('pageToken=next-page');
    return {
      response: { ok: true, status: 200, headers: {} },
      text: JSON.stringify(secondPage
        ? {
          models: [{
            name: 'models/gemini-current-pro',
            displayName: 'Gemini Current Pro',
            supportedGenerationMethods: ['generateContent'],
          }],
        }
        : {
          models: [{
            name: 'models/gemini-current-flash',
            displayName: 'Gemini Current Flash',
            supportedGenerationMethods: ['generateContent'],
          }],
          nextPageToken: 'next-page',
        }),
    };
  };
  delete require.cache[googlePath];

  try {
    const { GoogleProvider } = require(googlePath);
    const provider = new GoogleProvider({ apiKey: 'test-key' });
    const models = await provider.listModels();

    assert.deepEqual(models.map((model) => model.id), [
      'gemini-current-flash',
      'gemini-current-pro',
    ]);
    assert.equal(requestedUrls.length, 2);
    assert.match(requestedUrls[0], /pageSize=1000/);
    assert.match(requestedUrls[1], /pageToken=next-page/);
  } finally {
    http.fetchResponseText = originalFetchResponseText;
    delete require.cache[googlePath];
  }
});

test('Google requests set thinking only on catalog thinking models, in the shape each generation accepts', async () => {
  const http = require('../../../server/services/network/http');
  const originalFetchResponseText = http.fetchResponseText;
  const googlePath = require.resolve('../../../server/services/ai/providers/google');
  const model = (id, thinking) => ({ name: `models/${id}`, supportedGenerationMethods: ['generateContent'], thinking });
  http.fetchResponseText = async () => ({
    response: { ok: true, status: 200, headers: {} },
    text: JSON.stringify({
      models: [model('gemini-2.5-flash', true), model('gemini-3.1-pro-preview', true), model('gemma-3-27b-it', false)],
    }),
  });
  delete require.cache[googlePath];

  try {
    const { GoogleProvider } = require(googlePath);
    const provider = new GoogleProvider({ apiKey: 'test-key' });
    await provider.listModels();
    const thinkingFor = (id, reasoningEffort) => provider
      .buildGenerateConfig('', [], { model: id, reasoningEffort }).thinkingConfig;

    assert.deepEqual(thinkingFor('gemini-2.5-flash', 'low'), { thinkingBudget: 1024 });
    assert.deepEqual(thinkingFor('gemini-3.1-pro-preview', 'low'), { thinkingLevel: 'LOW' });
    assert.equal(thinkingFor('gemma-3-27b-it', 'low'), undefined);
    assert.equal(thinkingFor('gemini-3.1-pro-preview', 'minimal'), undefined);
    assert.equal(thinkingFor('gemini-unlisted', 'low'), undefined);
  } finally {
    http.fetchResponseText = originalFetchResponseText;
    delete require.cache[googlePath];
  }
});
