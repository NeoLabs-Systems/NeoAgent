'use strict';

const { BUILT_IN_DEFINITIONS, INTEGRATED_TOOL_TRAITS } = require('../ai/tools/definitions');
const { DEFAULT_POLICY } = require('./default_policy');

// Categories, safe tools, and the built-in list all come from the tool
// definitions. A name that is in none of them is third-party and lands in
// 'external', so a new capability can never silently bypass policy.
const TOOL_CATEGORIES = Object.fromEntries(Object.keys(DEFAULT_POLICY).map((category) => [category, []]));
const SAFE_TOOLS = new Set();
const BUILT_IN_TOOLS = new Set();
const toolToCategory = {};

for (const [name, policy] of [
  ...BUILT_IN_DEFINITIONS.map((tool) => [tool.name, tool.policy || {}]),
  ...Object.entries(INTEGRATED_TOOL_TRAITS).map(([toolName, traits]) => [toolName, traits.policy || {}]),
]) {
  if (policy.external) continue;
  BUILT_IN_TOOLS.add(name);
  if (policy.safe) SAFE_TOOLS.add(name);
  if (policy.category) {
    TOOL_CATEGORIES[policy.category].push(name);
    toolToCategory[name] = policy.category;
  }
}

/**
 * Returns the category for a tool.
 * - Known built-in tools may return null when they are read-only or otherwise
 *   intentionally left uncategorized.
 * - Unknown tool names are treated as external capabilities and must never
 *   silently bypass policy checks.
 */
function getCategoryForTool(toolName, toolArgs = {}) {
  if (toolName === 'http_request') {
    // Model-supplied args can be any shape; a non-string method must never
    // throw here, or every security hook after this would fail open.
    const method = String(toolArgs?.method ?? 'GET').trim().toUpperCase() || 'GET';
    return ['GET', 'HEAD', 'OPTIONS'].includes(method) ? null : 'network_write';
  }
  if (toolToCategory[toolName]) return toolToCategory[toolName];
  if (BUILT_IN_TOOLS.has(toolName) || SAFE_TOOLS.has(toolName)) return null;
  return 'external';
}

module.exports = {
  TOOL_CATEGORIES,
  SAFE_TOOLS,
  DEFAULT_POLICY,
  BUILT_IN_TOOLS,
  getCategoryForTool,
};
