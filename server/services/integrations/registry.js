'use strict';

const fs = require('fs');
const path = require('path');

const PROVIDER_FILE_NAME = 'provider.js';
const PROVIDER_FACTORY_PATTERN = /^create[A-Z][A-Za-z0-9]*Provider$/;

function discoverProviderModules(rootDirectory = __dirname) {
  return fs.readdirSync(rootDirectory, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => path.join(rootDirectory, entry.name, PROVIDER_FILE_NAME))
    .filter((filePath) => fs.existsSync(filePath))
    .sort((left, right) => left.localeCompare(right));
}

function loadProviderFactory(filePath) {
  const providerModule = require(filePath);
  const factories = Object.entries(providerModule)
    .filter(([name, value]) =>
      PROVIDER_FACTORY_PATTERN.test(name) && typeof value === 'function')
    .map(([, value]) => value);
  if (factories.length !== 1) {
    throw new Error(
      `Official integration module ${filePath} must export exactly one create*Provider factory.`,
    );
  }
  return factories[0];
}

function validateProvider(provider, filePath) {
  if (!provider || typeof provider !== 'object') {
    throw new Error(`Official integration module ${filePath} did not create a provider.`);
  }
  for (const field of ['key', 'label', 'description']) {
    if (!String(provider[field] || '').trim()) {
      throw new Error(`Official integration module ${filePath} is missing provider.${field}.`);
    }
  }
  if (!Array.isArray(provider.apps) || provider.apps.length === 0) {
    throw new Error(`Official integration ${provider.key} must declare at least one app.`);
  }
  for (const method of [
    'getApp',
    'getEnvStatus',
    'getToolDefinitions',
    'supportsTool',
    'buildSnapshot',
  ]) {
    if (typeof provider[method] !== 'function') {
      throw new Error(`Official integration ${provider.key} is missing ${method}().`);
    }
  }
  return provider;
}

function createIntegrationRegistry(options = {}) {
  const providerModules = discoverProviderModules(options.providerRoot || __dirname);
  const providers = providerModules.map((filePath) =>
    validateProvider(loadProviderFactory(filePath)(options), filePath));
  const byKey = new Map();
  for (const provider of providers) {
    if (byKey.has(provider.key)) {
      throw new Error(`Duplicate official integration provider key: ${provider.key}`);
    }
    byKey.set(provider.key, provider);
  }

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
  discoverProviderModules,
  loadProviderFactory,
  validateProvider,
};
