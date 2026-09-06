class BaseProvider {
  static readImageAsBase64(imagePath) {
    const fs = require('fs');
    return fs.readFileSync(imagePath).toString('base64');
  }

  constructor(config = {}) {
    this.config = config;
    this.name = 'base';
    this.models = [];
    this.onStatus = typeof config.onStatus === 'function' ? config.onStatus : null;
  }

  requireModel(options = {}) {
    const model = String(options.model || '').trim();
    if (model) return model;
    const error = new Error(
      `Provider '${this.name}' requires a model selected from its live catalog.`,
    );
    error.code = 'MODEL_SELECTION_REQUIRED';
    throw error;
  }

  formatTools(tools) {
    return (Array.isArray(tools) ? tools : [])
      .filter((tool) => tool && typeof tool === 'object' && String(tool.name || '').trim())
      .map((tool) => ({
        type: 'function',
        function: {
          name: String(tool.name).trim(),
          description: tool.description,
          parameters: tool.parameters || { type: 'object', properties: {} },
        },
      }));
  }

  async chat(messages, tools = [], options = {}) {
    throw new Error('chat() not implemented');
  }

  async *stream(messages, tools = [], options = {}) {
    throw new Error('stream() not implemented');
  }

  countTokensEstimate(text) {
    return Math.ceil(text.length / 4);
  }

  getContextWindow(model) {
    return 128000;
  }

  supportsVision() {
    return false;
  }

  async analyzeImage(_options = {}) {
    throw new Error(`Provider '${this.name}' does not support image analysis`);
  }
}

module.exports = { BaseProvider };
