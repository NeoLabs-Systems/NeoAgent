'use strict';

const chatgptConnections = require('../chatgpt/connections');

// Providers whose credential is a user's own account sign-in rather than an
// API key. Each store resolves the user's current access token; its provider
// class refreshes the token through the same store.
const ACCOUNT_CREDENTIAL_STORES = Object.freeze({
  [chatgptConnections.PROVIDER_ID]: chatgptConnections,
});

function getAccountAccessToken(userId, providerId) {
  const store = ACCOUNT_CREDENTIAL_STORES[providerId];
  if (!store || !userId) return '';
  return store.getAccessToken(userId);
}

module.exports = {
  getAccountAccessToken,
};
