'use strict';

const { CustomOpenAIProvider } = require('./openai_compatible_custom');
const { postSystemOneDecision } = require('./system_one_api');
const { listModels } = require('../neorouter/client');
const { DECISION_MODEL } = require('../neorouter/offer');
const { priceTierForCost } = require('../model_reference');

// NeoRouter routing profiles, offered as models. "auto" alone is not a valid
// selection id, so the balanced profile is listed by its full name.
const PROFILE_NAMES = Object.freeze({
  'auto:balanced': 'NeoRouter Auto',
  'auto:fast': 'NeoRouter Auto (fastest)',
  'auto:cheap': 'NeoRouter Auto (cheapest)',
  'auto:best': 'NeoRouter Auto (best)',
  'auto:smart': 'NeoRouter Auto (smartest)',
  'auto:reliable': 'NeoRouter Auto (most reliable)',
});
const contextWindows = new Map();

// A NeoRouter speaks the OpenAI API for every kind of model and routes each
// request across all of its providers. Its own model list carries prices and
// abilities, so NeoAgent need not look them up elsewhere.
class NeoRouterProvider extends CustomOpenAIProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'neorouter';
  }

  get connection() {
    return { apiBase: this.baseURL.replace(/\/+$/, ''), apiKey: this.client.apiKey };
  }

  async listModels(signal = null) {
    const models = await listModels(this.connection, 'chat', { signal });
    const profiles = Object.entries(PROFILE_NAMES).map(([id, name]) => ({ id, name, supportsTools: true }));
    const listed = models
      .filter((model) => !String(model.id).startsWith('auto'))
      .map((model) => {
        if (model.context_length) contextWindows.set(model.id, model.context_length);
        const facts = model.neorouter || {};
        const perToken = Number(model.pricing?.prompt);
        const priceTier = facts.free || facts.plan ? 'free' : priceTierForCost(Number.isFinite(perToken) && model.pricing?.prompt !== null ? perToken * 1e6 : null);
        return { id: model.id, name: model.name || model.id, supportsTools: facts.tools ?? null, ...(priceTier ? { priceTier } : {}) };
      });
    this.models = [...profiles, ...listed].map((model) => model.id);
    return [...profiles, ...listed];
  }

  getContextWindow(model) {
    return contextWindows.get(model) ?? 128000;
  }

  // NeoRouter sends images only to models that can see them.
  supportsVision() {
    return true;
  }

  async listDecisionModels(signal = null) {
    const models = await listModels(this.connection, 'moderation', { signal });
    return models.filter((model) => DECISION_MODEL.test(model.id)).map((model) => ({ id: model.id, name: model.name || model.id }));
  }

  async listLiveVoiceModels(signal = null) {
    const models = await listModels(this.connection, 'live', { signal });
    return models.map((model) => ({ id: model.id, name: model.name || model.id, protocols: model.neorouter?.protocols || [] }));
  }

  async decide({ model, state, questions, signal = null, timeoutMs } = {}) {
    return postSystemOneDecision(`${this.connection.apiBase}/systemone`, {
      headers: { Authorization: `Bearer ${this.client.apiKey}` },
      model,
      state,
      questions,
      signal,
      timeoutMs,
    });
  }
}

module.exports = { NeoRouterProvider };
