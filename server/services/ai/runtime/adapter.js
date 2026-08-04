'use strict';

const { runOrchestrator } = require('./run_orchestrator');
const { getFailureFallbackModelId } = require('./model_fallback');

/**
 * Compatibility adapter for the legacy conversation_loop entry point.
 * All surfaces continue to call runConversation(...); the durable runtime
 * kernel owns control flow underneath.
 */
async function runConversation(engine, userId, userMessage, options = {}, modelOverride = null) {
  return runOrchestrator(engine, userId, userMessage, options, modelOverride);
}

module.exports = {
  runConversation,
  getFailureFallbackModelId,
};
