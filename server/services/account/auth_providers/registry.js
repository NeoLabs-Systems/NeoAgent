'use strict';

const { createChatGptAuthProvider } = require('./chatgpt');
const { createGoogleAuthProvider } = require('./google');

function createAuthProviderRegistry() {
  const providers = [
    createGoogleAuthProvider(),
    createChatGptAuthProvider(),
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
