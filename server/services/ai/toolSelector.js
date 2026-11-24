'use strict';

/**
 * Tool selection strategy:
 *
 * Full JSON schemas are capped per model turn because several providers impose
 * schema-count limits. The stable search_tools control surface discovers the
 * remaining registry without injecting the complete catalog into every prompt.
 */

const { resolveToolMeta, toolNamesWithSelection } = require('./tools/metadata');

const MAX_TOOLS = 20;
const RETRIEVED_TOOLS = 3;
function requiredToolNames(options = {}) {
  return [
    ...toolNamesWithSelection('always'),
    ...(options.includeCoreFileTools ? [...toolNamesWithSelection('coding'), 'execute_command'] : []),
  ];
}

function toolFamily(tool) {
  const family = String(tool?.family || '').trim();
  return family || null;
}

function expandNamesByFamily(names = [], allTools = []) {
  const requested = [...new Set(
    (Array.isArray(names) ? names : [])
      .map((name) => String(name || '').trim())
      .filter(Boolean),
  )];
  const byName = new Map(
    (Array.isArray(allTools) ? allTools : []).map((tool) => [tool?.name, tool]),
  );
  const families = new Set();
  for (const name of requested) {
    const family = toolFamily(byName.get(name));
    if (family) families.add(family);
  }
  if (families.size === 0) return requested;

  const expanded = [...requested];
  for (const tool of allTools) {
    const name = String(tool?.name || '').trim();
    if (!name || expanded.includes(name)) continue;
    if (families.has(toolFamily(tool))) expanded.push(name);
  }
  return expanded;
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
      .normalize('NFC')
      .replace(/[_-]+/g, ' ')
      .split(/[^\p{L}\p{N}]+/u)
      .map((term) => term.trim())
      .filter((term) => term.length > 1),
  )];
}

function searchTools(tools = [], query = '', {
  limit = 8,
  activeNames = [],
  excludeNames = [],
  alsoNames = [],
  minScore = 1,
} = {}) {
  const terms = toolSearchTerms(query);
  if (terms.length === 0 && alsoNames.length === 0) return [];
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
      const capabilityTerms = new Set(resolveToolMeta(name, tool).capabilities);
      let score = 0;
      for (const term of terms) {
        if (name.toLowerCase() === term) score += 12;
        if (nameTerms.includes(term)) score += 7;
        else if (nameTerms.some((candidate) => candidate.startsWith(term) || term.startsWith(candidate))) score += 4;
        if (capabilityTerms.has(term)) score += 5;
        if (descriptionTerms.has(term)) score += 2;
      }
      // Words find what they name; meaning finds the rest, in any language.
      const meaningRank = alsoNames.indexOf(name);
      if (meaningRank !== -1) score += Math.max(1, 6 - meaningRank);
      if (score < minScore) return null;
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

// Which group a tool is listed under: its kind of work, or for third-party tools
// the product or server it belongs to. Names alone tell tools apart well enough
// for built-ins and named integrations; an MCP server's names can be anything, so
// those keep a short description.
function catalogGroup(tool) {
  const name = String(tool?.name || '');
  const meta = resolveToolMeta(name, tool);
  if (tool?.serverId) return `mcp:${tool.serverId}`;
  if (meta.group === 'integration' || meta.group === 'external') return name.split('_')[0] || 'other';
  return meta.group;
}

function summarizeToolCatalog(tools = []) {
  const groups = new Map();
  for (const tool of tools) {
    const name = String(tool?.name || '').trim();
    if (!name) continue;
    const group = catalogGroup(tool);
    if (!groups.has(group)) groups.set(group, []);
    const description = tool?.serverId ? compactDescription(tool?.description, 72) : '';
    groups.get(group).push(description ? `${name} (${description})` : name);
  }
  return [...groups.entries()]
    .map(([group, names]) => `${group}: ${names.join(', ')}`)
    .join('\n');
}

// The inactive catalog is listed by name so the model can activate what it
// needs directly. Without it, every capability costs a search_tools turn
// before the activate_tools turn before the real call.
function buildToolDiscoverySummary(tools = [], activeTools = []) {
  const activeNames = new Set(activeTools.map((tool) => tool?.name));
  const inactiveCatalog = summarizeToolCatalog(tools.filter((tool) => !activeNames.has(tool?.name)));
  return inactiveCatalog ? `Inactive tools by group:\n${inactiveCatalog}` : '';
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

// Signals strong enough to spend a schema slot on before the model asks. None of
// them reads the request's meaning, so none depends on its language: a tool or
// product named outright, a request that is visibly about files or a repo, and
// the tools this conversation was just using. Everything else stays one
// activate_tools call away. The model still chooses among what is active; there
// is no router and no extra model call.
const CANDIDATE_SCORES = Object.freeze({
  control: 1,
  named: 0.9,
  conversation: 0.85,
  run_setup: 0.8,
  default: 0.7,
  retrieved: 0.65,
});

function namedToolNames(request, allTools) {
  const text = String(request || '').toLowerCase();
  if (!text) return [];
  const words = new Set(text.split(/[^\p{L}\p{N}_]+/u).filter((word) => word.length >= 4));
  const named = [];
  for (const tool of allTools) {
    const name = String(tool?.name || '');
    if (words.has(name.toLowerCase())) {
      named.push(name);
      continue;
    }
    const meta = resolveToolMeta(name, tool);
    if (meta.known || meta.group === 'mcp') continue;
    if (words.has(name.split('_')[0].toLowerCase())) named.push(name);
  }
  return named.slice(0, 8);
}

/**
 * Picks the tools a run starts with, and says why. A catalog within the schema
 * cap is simply all active. A larger one starts with the control tools and the
 * defaults plus whatever the signals above name, best score first; the model
 * activates the rest from the listed catalog itself.
 */
function selectToolCandidates(allTools = [], {
  request = '',
  conversationTools = [],
  preferredNames = [],
  retrieved = [],
  options = {},
} = {}) {
  if (allTools.length <= MAX_TOOLS) {
    return {
      tools: allTools.slice(),
      candidates: allTools.map((tool) => ({ name: tool?.name, source: 'all', score: 1 })),
    };
  }
  const byName = new Map(allTools.map((tool) => [tool?.name, tool]));
  const ranked = new Map();
  const add = (names, source) => {
    for (const name of expandNamesByFamily(names, allTools)) {
      if (byName.has(name) && !ranked.has(name)) ranked.set(name, { name, source, score: CANDIDATE_SCORES[source] });
    }
  };
  add(requiredToolNames(options), 'control');
  add(toolNamesWithSelection('default'), 'default');
  add(preferredNames, 'run_setup');
  add(namedToolNames(request, allTools), 'named');
  add(conversationTools, 'conversation');
  const codingTools = toolNamesWithSelection('coding');
  // After everything above, so these only ever add what is still missing.
  const similarity = new Map(retrieved.map((entry) => [entry.name, entry.similarity]));
  const missing = retrieved.map((entry) => entry.name).filter((name) => byName.has(name) && !ranked.has(name));
  add(missing.slice(0, RETRIEVED_TOOLS), 'retrieved');
  // One file tool without the others only gets the model halfway.
  if (missing.slice(0, RETRIEVED_TOOLS).some((name) => codingTools.includes(name))) add(codingTools, 'retrieved');
  for (const candidate of ranked.values()) {
    if (candidate.source === 'retrieved') candidate.similarity = similarity.get(candidate.name) ?? null;
  }

  // The score decides who makes the cut. Order stays as added, so the schema
  // list the provider caches does not shuffle between runs.
  const kept = new Set(
    [...ranked.values()].sort((left, right) => right.score - left.score).slice(0, MAX_TOOLS).map((candidate) => candidate.name),
  );
  const candidates = [...ranked.values()].filter((candidate) => kept.has(candidate.name));
  return {
    tools: candidates.map((candidate) => byName.get(candidate.name)),
    candidates,
  };
}

function selectInitialTools(allTools = [], preferredNames = [], options = {}) {
  return selectToolCandidates(allTools, { preferredNames, options }).tools;
}

// A catalog group's name stands for every tool listed under it.
function expandGroupNames(names = [], allTools = []) {
  const known = new Set(allTools.map((tool) => tool?.name));
  return (Array.isArray(names) ? names : []).flatMap((name) => {
    if (known.has(name)) return [name];
    const members = allTools.filter((tool) => catalogGroup(tool) === name).map((tool) => tool.name);
    return members.length ? members : [name];
  });
}

function activateTools(currentTools = [], allTools = [], requestedNames = [], options = {}) {
  const knownByName = new Map(allTools.map((tool) => [tool?.name, tool]));
  const requiredNames = requiredToolNames(options);
  let next = ensureRequiredTools(currentTools, allTools, options);
  const activated = [];
  const evicted = [];
  const unknown = [];
  const notActivated = [];
  const requested = expandNamesByFamily(expandGroupNames(requestedNames, allTools), allTools);
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

module.exports = {
  expandNamesByFamily,
  MAX_TOOLS,
  activateTools,
  buildToolDiscoverySummary,
  searchTools,
  selectInitialTools,
  selectToolCandidates,
};
