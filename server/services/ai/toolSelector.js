'use strict';

/**
 * Tool selection strategy:
 *
 * Full JSON schemas are capped per model turn because several providers impose
 * schema-count limits. The stable search_tools control surface discovers the
 * remaining registry without injecting the complete catalog into every prompt.
 */

const MAX_TOOLS = 20;
const ALWAYS_INCLUDE_BUILT_INS = [
  'task_complete',
  'search_tools',
  'activate_tools',
  'think',
  'send_message',
  'send_interim_update',
  'request_user_input',
  'call_user',
];
const CORE_FILE_TOOLS = [
  'read_file',
  'read_files',
  'read_artifact',
  'list_directory',
  'search_files',
  'edit_file',
  'replace_file_range',
  'write_file',
];

function requiredToolNames(options = {}) {
  const requiredNames = [...ALWAYS_INCLUDE_BUILT_INS];
  if (options.includeCoreFileTools) requiredNames.push(...CORE_FILE_TOOLS);
  return requiredNames;
}

function compactDescription(value, maxChars = 180) {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  if (text.length <= maxChars) return text;
  return `${text.slice(0, maxChars - 3).trimEnd()}...`;
}

function toolSearchTerms(value) {
  return [...new Set(
    String(value || '')
      .toLowerCase()
      .replace(/[_-]+/g, ' ')
      .split(/[^a-z0-9]+/)
      .map((term) => term.trim())
      .filter((term) => term.length > 1),
  )];
}

function searchTools(tools = [], query = '', {
  limit = 8,
  activeNames = [],
  excludeNames = [],
} = {}) {
  const terms = toolSearchTerms(query);
  if (terms.length === 0) return [];
  const active = new Set(activeNames.map(String));
  const excluded = new Set(excludeNames.map(String));
  const boundedLimit = Math.max(1, Math.min(Number(limit) || 8, 12));

  return tools
    .map((tool) => {
      const name = String(tool?.name || '').trim();
      if (!name || excluded.has(name)) return null;
      const nameTerms = toolSearchTerms(name);
      const description = compactDescription(tool.description, 260);
      const descriptionTerms = new Set(toolSearchTerms(description));
      let score = 0;
      for (const term of terms) {
        if (name.toLowerCase() === term) score += 12;
        if (nameTerms.includes(term)) score += 7;
        else if (nameTerms.some((candidate) => candidate.startsWith(term) || term.startsWith(candidate))) score += 4;
        if (descriptionTerms.has(term)) score += 2;
      }
      if (score === 0) return null;
      return {
        name,
        description,
        source: tool.serverId ? `mcp:${tool.serverId}` : 'built-in',
        active: active.has(name),
        score,
      };
    })
    .filter(Boolean)
    .sort((left, right) => right.score - left.score || left.name.localeCompare(right.name))
    .slice(0, boundedLimit)
    .map(({ score, ...result }) => result);
}

function buildToolDiscoverySummary(tools = [], activeTools = []) {
  const sourceCounts = new Map();
  for (const tool of tools) {
    const source = tool?.serverId ? `mcp:${tool.serverId}` : 'built-in';
    sourceCounts.set(source, (sourceCounts.get(source) || 0) + 1);
  }
  const sources = [...sourceCounts.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([source, count]) => `${source}:${count}`)
    .join(', ');
  return [
    `Active tools: ${activeTools.map((tool) => tool.name).join(', ') || 'none'}.`,
    `Discoverable tools: ${tools.length}${sources ? ` (${sources})` : ''}.`,
    'Use search_tools with a capability description when a needed schema is missing. Matching tools become active on the next model turn; use activate_tools only to select different exact names.',
  ].join('\n');
}

function ensureRequiredTools(selectedTools = [], builtInTools = [], options = {}) {
  const limit = Number(options.maxTools) || MAX_TOOLS;
  const requiredNames = requiredToolNames(options);
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
  const requiredNames = requiredToolNames(options);
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
        !requiredNames.includes(item?.name)
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
  ALWAYS_INCLUDE_BUILT_INS,
  CORE_FILE_TOOLS,
  MAX_TOOLS,
  activateTools,
  buildToolDiscoverySummary,
  searchTools,
  selectInitialTools,
  selectToolsForTask,
  selectMcpTools,
};
