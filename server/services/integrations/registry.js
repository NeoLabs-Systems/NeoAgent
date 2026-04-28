'use strict';

const { createFigmaProvider } = require('./figma/provider');
const { createGoogleWorkspaceProvider } = require('./google/provider');
const { createGithubProvider } = require('./github/provider');
const { createHomeAssistantProvider } = require('./home_assistant/provider');
const { createMicrosoftProvider } = require('./microsoft/provider');
const { createNotionProvider } = require('./notion/provider');
const { createSpotifyProvider } = require('./spotify/provider');
const { createSlackProvider } = require('./slack/provider');
const { createWeatherProvider } = require('./weather/provider');
const { createWhatsAppPersonalProvider } = require('./whatsapp');

function createIntegrationRegistry(options = {}) {
  const providers = [
    createGoogleWorkspaceProvider(),
    createGithubProvider(),
    createNotionProvider(),
    createMicrosoftProvider(),
    createSlackProvider(),
    createFigmaProvider(),
    createHomeAssistantProvider(),
    createWeatherProvider(),
    createSpotifyProvider(),
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
