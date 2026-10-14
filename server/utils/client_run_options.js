'use strict';

// What a browser or app may set when it starts a run. Attachment paths, trust,
// rate-limit bypass, workspace root, and trigger source are chosen by the
// server entry point that accepted the request.
const CLIENT_RUN_OPTION_KEYS = Object.freeze(['agentId', 'agent_id', 'conversationId']);

function clientRunOptions(options) {
  if (!options || typeof options !== 'object' || Array.isArray(options)) return {};
  const picked = {};
  for (const key of CLIENT_RUN_OPTION_KEYS) {
    if (Object.prototype.hasOwnProperty.call(options, key)) picked[key] = options[key];
  }
  return picked;
}

module.exports = {
  CLIENT_RUN_OPTION_KEYS,
  clientRunOptions,
};
