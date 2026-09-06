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
