'use strict';

const { createGoogleAuthProvider } = require('./google');

function createAuthProviderRegistry() {
  const providers = [
    createGoogleAuthProvider(),
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
