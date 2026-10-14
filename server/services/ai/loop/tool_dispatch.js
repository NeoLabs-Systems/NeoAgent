'use strict';

const { resolveDeclaredToolAccess } = require('../toolEvidence');

function getAvailableTools(_engine, app, options = {}) {
  const { getAvailableTools: loadAvailableTools } = require('../tools');
  return loadAvailableTools(app, options);
}

async function executeTool(engine, toolName, args, context) {
  const { executeTool: runTool } = require('../tools');
  return runTool(toolName, args, context, engine);
}

function isReadOnlyToolCall(toolCall, toolDefinition = null) {
  const name = String(toolCall?.function?.name || '');
  let toolArgs = {};
  try {
    toolArgs = typeof toolCall?.function?.arguments === 'string'
      ? JSON.parse(toolCall.function.arguments || '{}')
      : (toolCall?.function?.arguments || {});
  } catch {
    return false;
  }

  const declaredAccess = resolveDeclaredToolAccess(toolDefinition, toolArgs);
  if (declaredAccess === 'read') return true;
  if (declaredAccess === 'write') return false;

  const readOnly = new Set([
    'read_file',
    'read_files',
    'read_artifact',
    'list_directory',
    'search_files',
    'code_navigate',
    'query_structured_data',
    'memory_recall',
    'memory_read',
    'session_search',
    'web_search',
    'list_tasks',
    'list_skills',
    'list_subagents',
    'read_health_data',
    'search_tools',
    'browser_extract',
    'browser_screenshot',
    'desktop_observe',
    'desktop_get_tree',
    'android_list_devices',
    'android_list_apps',
    'android_observe',
    'android_screenshot',
    'android_ui_dump',
  ]);
  if (name === 'http_request') {
    return String(toolArgs.method || 'GET').toUpperCase() === 'GET';
  }
  return readOnly.has(name);
}

module.exports = {
  executeTool,
  getAvailableTools,
  isReadOnlyToolCall,
};
