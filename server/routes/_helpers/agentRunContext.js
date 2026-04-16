'use strict';

const { buildAgentRunContext } = require('../../services/ai/runContext');

module.exports = {
  buildAgentRunContext: (options) => buildAgentRunContext({
    ...options,
    includeWebContext: true,
  }),
};
