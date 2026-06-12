'use strict';

/**
 * Tool selection strategy:
 *
 * Every tool stays visible in the catalog. Only full JSON schemas are limited
 * per model turn because several providers enforce schema-count limits.
 */

const MAX_TOOLS = 20;
const ALWAYS_INCLUDE_BUILT_INS = [
  'task_complete',
  'activate_tools',
  'think',
  'send_message',
  'send_interim_update',
];

function compactDescription(value, maxChars = 180) {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  if (text.length <= maxChars) return text;
  return `${text.slice(0, maxChars - 3).trimEnd()}...`;
}

function buildToolCatalog(tools = []) {
  return tools
    .filter((tool) => String(tool?.name || '').trim())
    .map((tool) => ({
      name: String(tool.name).trim(),
      description: compactDescription(tool.description),
      source: tool.serverId ? `mcp:${tool.serverId}` : 'built-in',
    }))
    .sort((left, right) => left.name.localeCompare(right.name))
    .map((tool) => `${tool.name} | ${tool.source} | ${tool.description || 'No description supplied.'}`)
    .join('\n');
}

function ensureRequiredTools(selectedTools = [], builtInTools = [], options = {}) {
  const limit = Number(options.maxTools) || MAX_TOOLS;
  const requiredNames = [...ALWAYS_INCLUDE_BUILT_INS];
  if (options.widgetId) requiredNames.push('save_widget_snapshot');
  if (!requiredNames.length) return selectedTools;

  const selected = Array.isArray(selectedTools) ? [...selectedTools] : [];

  for (const toolName of requiredNames) {
    if (selected.some((tool) => tool?.name === toolName)) continue;
    const required = builtInTools.find((tool) => tool?.name === toolName);
    if (!required) continue;

    if (selected.length < limit) {
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

function selectInitialTools(allTools = [], suggestedNames = [], options = {}) {
  const requested = new Set(
    (Array.isArray(suggestedNames) ? suggestedNames : [])
      .map((name) => String(name || '').trim())
      .filter(Boolean),
  );
  const selected = allTools.filter((tool) => requested.has(tool?.name));
  return ensureRequiredTools(selected.slice(0, MAX_TOOLS), allTools, options).slice(0, MAX_TOOLS);
}

function activateTools(currentTools = [], allTools = [], requestedNames = [], options = {}) {
  const knownByName = new Map(allTools.map((tool) => [tool?.name, tool]));
  let next = ensureRequiredTools(currentTools, allTools, options);
  const activated = [];
  const evicted = [];
  const unknown = [];
  const notActivated = [];
  const requested = [...new Set(
    (Array.isArray(requestedNames) ? requestedNames : [])
      .map((rawName) => String(rawName || '').trim())
      .filter(Boolean),
  )];
  for (const name of requested) {
    const tool = knownByName.get(name);
    if (!tool) {
      unknown.push(name);
      continue;
    }
    if (next.some((item) => item?.name === name)) continue;
    if (next.length >= MAX_TOOLS) {
      const replaceIndex = next.findIndex((item) => (
        !ALWAYS_INCLUDE_BUILT_INS.includes(item?.name)
        && !requested.includes(item?.name)
      ));
      if (replaceIndex === -1) {
        notActivated.push(name);
        continue;
      }
      evicted.push(next[replaceIndex].name);
      next.splice(replaceIndex, 1);
    }
    next.push(tool);
    activated.push(name);
  }
  next = ensureRequiredTools(next, allTools, options).slice(0, MAX_TOOLS);
  return {
    tools: next,
    activated,
    evicted,
    unknown,
    notActivated,
  };
}

function selectMcpTools(_task, mcpTools = []) {
  return Array.isArray(mcpTools) ? mcpTools : [];
}

function selectToolsForTask(task, builtInTools = [], mcpTools = [], _options = {}) {
  const selectedMcp = selectMcpTools(task, mcpTools);
  void _options;
  return [...builtInTools, ...selectedMcp];
}

module.exports = {
  MAX_TOOLS,
  activateTools,
  buildToolCatalog,
  selectInitialTools,
  selectToolsForTask,
  selectMcpTools,
};
