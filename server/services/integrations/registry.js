'use strict';

const { createFigmaProvider } = require('./figma/provider');
const { createGoogleWorkspaceProvider } = require('./google/provider');
const { createMicrosoftProvider } = require('./microsoft/provider');
const { createNotionProvider } = require('./notion/provider');
const { createSlackProvider } = require('./slack/provider');
const { createWhatsAppPersonalProvider } = require('./whatsapp');

function createIntegrationRegistry(options = {}) {
  const providers = [
    createGoogleWorkspaceProvider(),
    createNotionProvider(),
    createMicrosoftProvider(),
    createSlackProvider(),
    createFigmaProvider(),
    createWhatsAppPersonalProvider(options),
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
