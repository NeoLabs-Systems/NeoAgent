'use strict';

const { isReadOnlyCall, resolveToolMeta } = require('../tools/metadata');

function getAvailableTools(engine, app, options = {}) {
  const { getAvailableTools: loadAvailableTools } = require('../tools');
  const resolvedApp = app || engine.app || {};
  return loadAvailableTools({ ...resolvedApp, locals: { ...resolvedApp.locals, skillRunner: resolvedApp.locals?.skillRunner || engine.skillRunner } }, options);
}

async function executeTool(engine, toolName, args, context) {
  const { executeTool: runTool } = require('../tools');
  return runTool(toolName, args, context, engine);
}

function isReadOnlyToolCall(toolCall, toolDefinition = null) {
  let toolArgs = {};
  try {
    toolArgs = typeof toolCall?.function?.arguments === 'string'
      ? JSON.parse(toolCall.function.arguments || '{}')
      : (toolCall?.function?.arguments || {});
  } catch {
    return false;
  }
  return isReadOnlyCall(resolveToolMeta(toolCall?.function?.name, toolDefinition), toolArgs);
}

module.exports = {
  executeTool,
  getAvailableTools,
  isReadOnlyToolCall,
};
