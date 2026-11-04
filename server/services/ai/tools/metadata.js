'use strict';

const { isClearlyReadOnlyShellCommand } = require('../loop/progress_classification');
const { BUILT_IN_DEFINITIONS, INTEGRATED_TOOL_TRAITS } = require('./definitions');

// The one place the harness learns what a tool is. Scheduling, repeat
// detection, progress tracking, trust, result budgets, and the security policy
// all read this instead of keeping their own lists of tool names.
const DEFAULT_TRAITS = Object.freeze({
  group: 'external',
  stepType: null,
  access: null,
  sideEffect: 'none',
  stateScope: 'none',
  latencyClass: 'remote',
  repeatable: false,
  // Whether the result can carry content the owner did not write.
  untrusted: true,
  exclusive: false,
  capabilities: [],
  prerequisites: [],
  policy: {},
  whenToUse: [],
  whenNotToUse: [],
  // On the first turn: always, on every run, or for coding work.
  selection: null,
  // Outlasts the run, or can carry an argument off the machine: trust review reads these.
  persistent: false,
  egress: false,
  // Arguments naming who receives something, when they differ from the usual ones.
  recipientArgs: null,
  // How toolResult.js cuts the result down; without one it gets a plain summary.
  resultShape: null,
});

function normalizeTraits(name, traits) {
  return Object.freeze({ ...DEFAULT_TRAITS, ...traits, name, known: true });
}

const STATIC_META = new Map();
for (const definition of BUILT_IN_DEFINITIONS) STATIC_META.set(definition.name, normalizeTraits(definition.name, definition));
for (const [name, traits] of Object.entries(INTEGRATED_TOOL_TRAITS)) STATIC_META.set(name, normalizeTraits(name, traits));

// Integration, MCP, and skill tools declare at most their access and family, so
// they get the conservative reading: anything not declared read-only can have
// side effects, and their output is untrusted.
function metaFromDefinition(name, definition) {
  const access = String(definition?.access || '').trim().toLowerCase() || null;
  let group = 'external';
  if (definition?.integration || access) group = 'integration';
  if (definition?.serverId || name.startsWith('mcp_')) group = 'mcp';
  return Object.freeze({
    ...DEFAULT_TRAITS,
    name,
    known: false,
    group,
    access,
    sideEffect: access === 'read' ? 'none' : 'external',
    stateScope: 'external',
    repeatable: true,
    stepType: group === 'mcp' ? 'mcp' : null,
    resultShape: definition?.resultShape || null,
  });
}

function resolveToolMeta(name, definition = null) {
  const toolName = String(name || '').trim();
  return STATIC_META.get(toolName) || metaFromDefinition(toolName, definition);
}

function isReadMethod(args) {
  const method = String(args?.method ?? args?.http_method ?? 'GET').trim().toUpperCase() || 'GET';
  return ['GET', 'HEAD', 'OPTIONS'].includes(method);
}

// Whether this particular call can change anything outside the run. Tools whose
// answer depends on their arguments say so with a dynamic access value.
function resolveCallAccess(meta, args = {}) {
  switch (meta?.access) {
    case 'read':
    case 'write':
      return meta.access;
    case 'dynamic_http_method':
      return isReadMethod(args) ? 'read' : 'write';
    case 'dynamic_shell':
      return isClearlyReadOnlyShellCommand(args?.command || '') ? 'read' : 'write';
    default:
      return null;
  }
}

function isShellCall(meta) {
  return meta?.group === 'shell' || meta?.access === 'dynamic_shell';
}

function isReadOnlyCall(meta, args = {}) {
  return resolveCallAccess(meta, args) === 'read';
}

// Calls that act on one shared page or device stay in order even when each only
// reads: an extract next to a navigation sees whichever page won the race. The
// shell stays serial too, since a command that looks read-only can still depend
// on one before it.
const SHARED_STATE_GROUPS = new Set(['browser', 'desktop', 'android', 'shell', 'messaging']);

function isParallelSafeCall(meta, args = {}) {
  return isReadOnlyCall(meta, args) && !meta.exclusive && !SHARED_STATE_GROUPS.has(meta.group);
}

// Whether a successful call moved the work forward. A navigation only reads, but
// what the next browser call sees has changed. A tool that does not declare its
// access (MCP, skills) makes no claim, so its result counts as evidence, not as
// a change; repeat detection still catches it spinning.
function changesState(meta, args = {}) {
  if (meta?.sideEffect === 'navigation') return true;
  if (meta?.sideEffect === 'none') return false;
  return resolveCallAccess(meta, args) === 'write';
}

function stepTypeFor(name, definition = null) {
  const meta = resolveToolMeta(name, definition);
  if (meta.stepType) return meta.stepType;
  const byGroup = {
    browser: 'browser',
    desktop: 'desktop',
    android: 'android',
    shell: 'cli',
    files: 'files',
    memory: 'memory',
    tasks: 'tasks',
    mcp: 'mcp',
  };
  return byGroup[meta.group] || 'tool';
}

// Which result budget a tool's output is held to.
function resultBudgetFor(meta) {
  if (meta?.group === 'files') return 'file';
  if (meta?.group === 'browser') return 'browser';
  if (meta?.group === 'shell' || meta?.group === 'android') return 'command';
  return 'default';
}

function staticToolNames() {
  return [...STATIC_META.keys()];
}

function toolNamesWithSelection(selection) {
  return [...STATIC_META.values()].filter((meta) => meta.selection === selection).map((meta) => meta.name);
}

// Discovery/activation never grants authority. All handlers, including external
// fallback dispatch, use this same eligible-catalog and child-limit decision.
function runToolRefusal(catalog, options = {}, name, args = {}) {
  const definition = catalog?.find((tool) => tool?.name === name);
  if (Array.isArray(catalog) && !definition) return `${name} is not available to this run.`;
  if (options.disallowedToolNames?.includes(name)) return `${name} is not available to this run.`;
  if (Array.isArray(options.allowedToolNames) && !options.allowedToolNames.includes(name) && name !== 'task_ledger') {
    return `${name} is not available to this run.`;
  }
  const meta = resolveToolMeta(name, definition);
  if (options.readOnly && (isShellCall(meta) || !isReadOnlyCall(meta, args))) {
    return `This run may only read, and ${name} may change something or run commands.`;
  }
  return null;
}

module.exports = {
  runToolRefusal,
  toolNamesWithSelection,
  changesState,
  isParallelSafeCall,
  isReadOnlyCall,
  isShellCall,
  resolveCallAccess,
  resolveToolMeta,
  resultBudgetFor,
  staticToolNames,
  stepTypeFor,
};
