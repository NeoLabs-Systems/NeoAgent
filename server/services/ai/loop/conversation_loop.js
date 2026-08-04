'use strict';

/**
 * Legacy entry surface for the agent loop.
 *
 * The monolithic conversation_loop control plane has been replaced by the
 * durable runtime kernel under server/services/ai/runtime/.
 * This module remains as a stable import path for engine + tests.
 */

const {
  runConversation,
  getFailureFallbackModelId,
} = require('../runtime/adapter');

module.exports = {
  runConversation,
  getFailureFallbackModelId,
};
