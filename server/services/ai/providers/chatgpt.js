'use strict';

const { OpenAICodexProvider } = require('./openaiCodex');
const { wrapProviderError } = require('./provider_error');
const { RESOURCE } = require('../../chatgpt/oauth');
const { getFreshAccessToken, refreshAccessToken } = require('../../chatgpt/connections');

// Models from the user's own ChatGPT plan, through the public Responses API
// with the access token from Sign in with ChatGPT. Request building and
// streaming are the Codex provider's; only auth, model listing and the
// request fields this route accepts differ.
class ChatGPTProvider extends OpenAICodexProvider {
  constructor(config = {}) {
    if (!config.apiKey || !config.userId) {
      throw new Error('ChatGPT is not connected for this account.');
    }
    super(config);
    this.name = 'chatgpt';
    this.displayName = 'ChatGPT';
    this.userId = config.userId;
    // Plan usage is served as a stream, sometimes without a content type.
    this.streamOnly = true;
  }

  _resolveBaseUrl() {
    return RESOURCE;
  }

  _refreshAccessToken() {
    return refreshAccessToken(this.userId);
  }

  async _withTokenRefresh(request) {
    this.client.apiKey = await getFreshAccessToken(this.userId);
    return super._withTokenRefresh(request);
  }

  async listModels(signal = null) {
    try {
      const response = await this._withTokenRefresh(() => this.client.get('/models', { signal }));
      return (Array.isArray(response?.models) ? response.models : [])
        .filter((model) => model?.visibility === 'list' && typeof model.slug === 'string' && model.slug.trim())
        .map((model) => ({ id: model.slug, name: model.display_name || model.slug }));
    } catch (error) {
      throw wrapProviderError(error, 'Failed to list ChatGPT models', { signal });
    }
  }

  _buildRequest(messages = [], tools = [], options = {}, model = '') {
    const request = super._buildRequest(messages, tools, options, model);
    request.store = false;
    delete request.max_output_tokens;
    delete request.temperature;
    return request;
  }
}

module.exports = { ChatGPTProvider };
