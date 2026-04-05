'use strict';

const { createGoogleWorkspaceProvider } = require('./google/provider');

function createIntegrationRegistry() {
  const providers = [createGoogleWorkspaceProvider()];
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
