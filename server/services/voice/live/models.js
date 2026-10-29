'use strict';

const { refreshProviderModelList } = require('../../ai/model_discovery');
const { PROVIDER_FACTORIES, getProviderRuntimeConfig } = require('../../ai/models');
const {
  INPUT_MODES,
  LIVE_VOICE_PROVIDERS,
  configuredLiveModel,
  resolveLiveVoice,
  serverDefaultProvider,
} = require('./catalog');
const { providerServesRole } = require('../../ai/neorouter/connection');

// A provider's live models come from its own model list, refreshed and cached
// like the chat models; the last list serves while the next one loads. Without
// a key there is nothing to list.
// Whether this person can call through the provider at all: it needs a key,
// and a NeoRouter also needs live voice switched on for it.
function liveProviderReady({ userId = null, agentId = null, providerId }) {
  const { runtimeProvider } = LIVE_VOICE_PROVIDERS[providerId];
  const runtime = getProviderRuntimeConfig(userId, runtimeProvider, agentId);
  return Boolean(runtime.apiKey) && providerServesRole(runtimeProvider, userId, agentId, 'live');
}

async function listLiveModels({ userId = null, agentId = null, providerId }) {
  const { runtimeProvider, protocol } = LIVE_VOICE_PROVIDERS[providerId];
  if (!liveProviderReady({ userId, agentId, providerId })) return [];
  const runtime = getProviderRuntimeConfig(userId, runtimeProvider, agentId);
  const models = await refreshProviderModelList({
    providerId: runtimeProvider,
    factory: PROVIDER_FACTORIES[runtimeProvider],
    userId,
    apiKey: runtime.apiKey,
    baseUrl: runtime.baseUrl,
    catalog: 'voice',
    staleOk: true,
  });
  // A NeoRouter lists its live models once, with the protocols that reach each.
  return protocol ? models.filter((model) => (model.protocols || []).includes(protocol)) : models;
}

function versionOf(modelId) {
  const match = String(modelId).match(/\d+(?:\.\d+)?/);
  return match ? Number(match[0]) : 0;
}

// A router's plain auto model first, then released models before
// previews, the newest version first, and the plain model before its variants. The first one is what a call uses when nobody
// picked a model.
function rankLiveModels(models) {
  // A router's auto model picks the best live model per call, so it leads.
  const isAuto = (model) => Number(/^auto(-(free|plan|paid))?:default$/.test(model.id));
  return [...models].sort((a, b) => (
    isAuto(b) - isAuto(a)
    || Number(/preview/i.test(a.id)) - Number(/preview/i.test(b.id))
    || versionOf(b.id) - versionOf(a.id)
    || a.id.length - b.id.length
  ));
}

// The configured model, or the provider's default. What the model list says
// about it (whether it thinks) comes along; a configured model the list does
// not show is used as given.
async function resolveLiveModel({ userId, agentId, providerId, configured }) {
  const models = await listLiveModels({ userId, agentId, providerId });
  if (!configured) return rankLiveModels(models)[0] || null;
  return models.find((model) => model.id === configured) || { id: configured };
}

// What the settings and the admin console offer.
async function describeLiveVoiceCatalog({ userId = null, agentId = null } = {}) {
  const providers = await Promise.all(Object.values(LIVE_VOICE_PROVIDERS).map(async (provider) => {
    const models = rankLiveModels(await listLiveModels({ userId, agentId, providerId: provider.id }));
    return {
      id: provider.id,
      label: provider.label,
      available: liveProviderReady({ userId, agentId, providerId: provider.id }),
      defaultModel: configuredLiveModel(provider.id, '') || models[0]?.id || null,
      models: models.map((model) => model.id),
      defaultVoice: resolveLiveVoice(provider.id, ''),
      voices: [...provider.voices],
    };
  }));
  return {
    defaultProvider: serverDefaultProvider(),
    inputModes: [...INPUT_MODES],
    providers,
  };
}

module.exports = {
  describeLiveVoiceCatalog,
  rankLiveModels,
  resolveLiveModel,
};
