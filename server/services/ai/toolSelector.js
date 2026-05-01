'use strict';

/**
 * Tool selection strategy:
 *
 * Built-ins: always passed in full — descriptions are capped short by
 * compactToolDefinition({ includeDescriptions: true }) in tools.js, so the
 * overhead is a fixed ~100 tokens/tool and the model always knows every tool
 * that exists.
 *
 * MCP tools: user-defined and potentially numerous. Include all when the set
 * is small; keyword-filter when the registry grows large.
 */

const MCP_ALWAYS_INCLUDE_THRESHOLD = 20;

function selectMcpTools(task, mcpTools = []) {
  if (!mcpTools.length) return [];
  if (mcpTools.length <= MCP_ALWAYS_INCLUDE_THRESHOLD) return mcpTools;

  // Large MCP registry: match by tool name, original name, or server id so we
  // still surface the right tools without dumping hundreds of schemas.
  const normalized = String(task || '').toLowerCase();
  const explicitMcp = /\bmcp\b|\bmodel context protocol\b/.test(normalized);

  return mcpTools.filter((tool) => {
    if (explicitMcp) return true;
    const name = String(tool.name || '').toLowerCase();
    const original = String(tool.originalName || '').toLowerCase();
    const server = String(tool.serverId || '').toLowerCase();
    return normalized.includes(name) || normalized.includes(original) || (server && normalized.includes(server));
  });
}

function selectToolsForTask(task, builtInTools = [], mcpTools = [], _options = {}) {
  const MAX_TOOLS = 128; // Strict provider limit (e.g. Github Copilot / OpenAI)
  const selectedMcp = selectMcpTools(task, mcpTools);
  
  if (builtInTools.length + selectedMcp.length <= MAX_TOOLS) {
    return [...builtInTools, ...selectedMcp];
  }

  // If we exceed the limit, prioritize base tools and take as many MCP tools as fit
  const remainingSpace = MAX_TOOLS - builtInTools.length;
  if (remainingSpace > 0) {
    return [...builtInTools, ...selectedMcp.slice(0, remainingSpace)];
  }
  
  return builtInTools.slice(0, MAX_TOOLS);
}

module.exports = { selectToolsForTask, selectMcpTools };
