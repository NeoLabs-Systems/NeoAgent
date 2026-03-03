class BaseProvider {
  constructor(config = {}) {
    this.config = config;
    this.name = 'base';
    this.models = [];
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
}

module.exports = { BaseProvider };
