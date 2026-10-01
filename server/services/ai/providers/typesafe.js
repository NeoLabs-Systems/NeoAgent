'use strict';

const { BaseProvider } = require('./base');
const { fetchResponseText } = require('../../network/http');
const { postSystemOneDecision } = require('./system_one_api');

const TYPESAFE_BASE_URL = 'https://api.typesafe.ai/v1';

// TypeSafe serves its SystemOne models (Jev) directly. It has no chat models.
class TypeSafeProvider extends BaseProvider {
  constructor(config = {}) {
    super(config);
    this.name = 'typesafe';
    this.apiKey = config.apiKey || process.env.TYPESAFE_API_KEY || '';
  }

  async listModels() {
    return [];
  }

  async listDecisionModels(signal = null) {
    const { response, text } = await fetchResponseText(`${TYPESAFE_BASE_URL}/models`, {
      headers: { Authorization: `Bearer ${this.apiKey}` },
      maxResponseBytes: 1024 * 1024,
      serviceName: 'TypeSafe model catalog',
      signal,
    });
    if (!response.ok) {
      const error = new Error(`TypeSafe /models returned HTTP ${response.status}`);
      error.status = response.status;
      throw error;
    }
    let payload;
    try {
      payload = JSON.parse(text || '{}');
    } catch {
      throw new Error('TypeSafe /models returned invalid JSON.');
    }
    // { models: [{ name, description, release_date }] }
    return (Array.isArray(payload.models) ? payload.models : [])
      .filter((model) => typeof model?.name === 'string')
      .map((model) => ({ id: model.name, name: model.name }));
  }

  async decide({ model, state, questions, signal = null, timeoutMs } = {}) {
    return postSystemOneDecision(`${TYPESAFE_BASE_URL}/systemone`, {
      headers: { Authorization: `Bearer ${this.apiKey}` },
      model,
      state,
      questions,
      signal,
      timeoutMs,
    });
  }
}

module.exports = { TypeSafeProvider };
