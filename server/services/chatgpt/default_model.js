'use strict';

const { getSupportedModels } = require('../ai/models');
const { releaseDefaultModels, setDefaultModels } = require('../ai/settings');
const { PROVIDER_ID } = require('./connections');

// Points the user's main agent at their ChatGPT plan. The first model the
// account lists is the one ChatGPT itself offers first.
async function adoptChatGptAsDefaultModel(userId) {
  const models = await getSupportedModels(userId);
  const model = models.find((candidate) => candidate.provider === PROVIDER_ID && candidate.available);
  if (!model) throw new Error('No ChatGPT models are available for this account.');
  setDefaultModels(userId, model.id);
}

function releaseChatGptDefaultModels(userId) {
  releaseDefaultModels(userId, PROVIDER_ID);
}

module.exports = {
  adoptChatGptAsDefaultModel,
  releaseChatGptDefaultModels,
};
