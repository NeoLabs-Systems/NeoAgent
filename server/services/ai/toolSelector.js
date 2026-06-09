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
const MAX_TOOLS = 128; // Strict provider limit (e.g. Github Copilot / OpenAI)
const ALWAYS_INCLUDE_BUILT_INS = [
  'send_message',
  'create_task',
  'list_tasks',
  'delete_task',
  'update_task',
];

function ensureRequiredTools(selectedTools = [], builtInTools = [], options = {}) {
  const requiredNames = [...ALWAYS_INCLUDE_BUILT_INS];
  if (options.widgetId) requiredNames.push('save_widget_snapshot');
  if (!requiredNames.length) return selectedTools;

  const selected = Array.isArray(selectedTools) ? [...selectedTools] : [];

  for (const toolName of requiredNames) {
    if (selected.some((tool) => tool?.name === toolName)) continue;
    const required = builtInTools.find((tool) => tool?.name === toolName);
    if (!required) continue;

    if (selected.length < MAX_TOOLS) {
      selected.push(required);
      continue;
    }

    // Keep within provider tool cap: replace the last non-required tool.
    let replaced = false;
    for (let index = selected.length - 1; index >= 0; index -= 1) {
      const currentName = selected[index]?.name;
      if (!requiredNames.includes(currentName)) {
        selected[index] = required;
        replaced = true;
        break;
      }
    }
    if (!replaced && selected.length > 0) {
      selected[selected.length - 1] = required;
    }
  }

  return selected;
}

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
  const selectedMcp = selectMcpTools(task, mcpTools);
  const options = _options || {};
  let selected;
  
  if (builtInTools.length + selectedMcp.length <= MAX_TOOLS) {
    selected = [...builtInTools, ...selectedMcp];
    return ensureRequiredTools(selected, builtInTools, options);
  }

  // If we exceed the limit, prioritize base tools and take as many MCP tools as fit
  const remainingSpace = MAX_TOOLS - builtInTools.length;
  if (remainingSpace > 0) {
    selected = [...builtInTools, ...selectedMcp.slice(0, remainingSpace)];
    return ensureRequiredTools(selected, builtInTools, options);
  }
  
  selected = builtInTools.slice(0, MAX_TOOLS);
  return ensureRequiredTools(selected, builtInTools, options);
}

module.exports = { selectToolsForTask, selectMcpTools };
