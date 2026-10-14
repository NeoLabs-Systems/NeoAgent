'use strict';

const { createOpenRouterAuthProvider } = require('./openrouter');
const { createGoogleAuthProvider } = require('./google');

function createAuthProviderRegistry() {
  const providers = [
    createGoogleAuthProvider(),
    createOpenRouterAuthProvider(),
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
  createAuthProviderRegistry,
};
