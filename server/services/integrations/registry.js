'use strict';

const { createFigmaProvider } = require('./figma/provider');
const { createGoogleWorkspaceProvider } = require('./google/provider');
const { createMicrosoftProvider } = require('./microsoft/provider');
const { createNotionProvider } = require('./notion/provider');
const { createSlackProvider } = require('./slack/provider');

function createIntegrationRegistry() {
  const providers = [
    createGoogleWorkspaceProvider(),
    createNotionProvider(),
    createMicrosoftProvider(),
    createSlackProvider(),
    createFigmaProvider(),
  ];
  const byKey = new Map(providers.map((provider) => [provider.key, provider]));

  return {
    list() {
      return providers.slice();
    },
    get(providerKey) {
      return byKey.get(String(providerKey || '').trim()) || null;
    },
  };
}

module.exports = {
  createIntegrationRegistry,
};
