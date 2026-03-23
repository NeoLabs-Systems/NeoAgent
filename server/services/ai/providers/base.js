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

  getDefaultModel() {
    return this.models[0] || '';
  }

  formatTools(tools) {
    return tools.map(tool => ({
      type: 'function',
      function: {
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters || { type: 'object', properties: {} }
      }
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

  getDefaultVisionModel() {
    return null;
  }

  async analyzeImage(_options = {}) {
    throw new Error(`Provider '${this.name}' does not support image analysis`);
  }
}

module.exports = { BaseProvider };
