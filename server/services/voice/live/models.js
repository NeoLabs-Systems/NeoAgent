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

// A provider's live models come from its own model list, refreshed and cached
// like the chat models; the last list serves while the next one loads. Without
// a key there is nothing to list.
async function listLiveModels({ userId = null, agentId = null, providerId }) {
  const runtimeProvider = LIVE_VOICE_PROVIDERS[providerId].runtimeProvider;
  const runtime = getProviderRuntimeConfig(userId, runtimeProvider, agentId);
  if (!runtime.apiKey) return [];
  return refreshProviderModelList({
    providerId: runtimeProvider,
    factory: PROVIDER_FACTORIES[runtimeProvider],
    userId,
    apiKey: runtime.apiKey,
    baseUrl: runtime.baseUrl,
    catalog: 'voice',
    staleOk: true,
  });
}

function versionOf(modelId) {
  const match = String(modelId).match(/\d+(?:\.\d+)?/);
  return match ? Number(match[0]) : 0;
}

// Released models before previews, the newest version first, and the plain
// model before its variants. The first one is what a call uses when nobody
// picked a model.
function rankLiveModels(models) {
  return [...models].sort((a, b) => (
    Number(/preview/i.test(a.id)) - Number(/preview/i.test(b.id))
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
