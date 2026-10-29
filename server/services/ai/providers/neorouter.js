'use strict';

const { CustomOpenAIProvider } = require('./openai_compatible_custom');
const { postSystemOneDecision } = require('./system_one_api');
const { isDecisionModel, listModels } = require('../neorouter/client');
const { priceTierForCost } = require('../model_reference');

// NeoRouter's auto models: one per routing profile, and the same limited to
// free, subscription or paid models when the key may use more than one kind.
// "auto" alone is not a valid selection id, so the balanced profile is
// listed by its full name ("auto:balanced", "auto-free:balanced").
const isAuto = (id) => /^auto(-(free|plan|paid))?(:|$)/.test(String(id));
const selectableAutoId = (id) => (String(id).includes(':') ? String(id) : `${id}:balanced`);
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
    const profiles = models
      .filter((model) => isAuto(model.id))
      .map((model) => ({ id: selectableAutoId(model.id), name: `NeoRouter ${model.name || model.id}`, supportsTools: true }));
    const listed = models
      .filter((model) => !isAuto(model.id))
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

  // Auto models (NeoRouter picks the model per request) come first, under
  // their selectable ids.
  async listDecisionModels(signal = null) {
    const models = await listModels(this.connection, 'moderation', { signal });
    return models.filter(isDecisionModel).map((model) => ({
      id: isAuto(model.id) ? selectableAutoId(model.id) : model.id,
      name: isAuto(model.id) ? `NeoRouter ${model.name || model.id}` : model.name || model.id,
    }));
  }

  async listLiveVoiceModels(signal = null) {
    const models = await listModels(this.connection, 'live', { signal });
    return models.map((model) => ({
      id: isAuto(model.id) ? selectableAutoId(model.id) : model.id,
      name: isAuto(model.id) ? `NeoRouter ${model.name || model.id}` : model.name || model.id,
      protocols: model.neorouter?.protocols || [],
    }));
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
