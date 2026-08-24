'use strict';

// Tool discovery regression guard. Provider schema caps mean only a slice of
// the registry can be active. Every surface must expose compact discovery and
// let search_tools find inactive built-in and MCP capabilities.

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { MAX_TOOLS } = require('../../../server/services/ai/toolSelector');

let ctx;
let userId;
let AgentEngine;

before(async () => {
  ctx = createTestRuntime();
  userId = (await createTestUser(ctx.db, { username: 'tool_surface_user' })).userId;

  const { ensureDefaultAiSettings } = require('../../../server/services/ai/settings');
  ensureDefaultAiSettings(userId, null);

  const providerPath = require.resolve('../../../server/services/ai/provider_selector');
  require(providerPath);
  require.cache[providerPath].exports.getProviderForUser = async () => ({
    provider: {},
    model: 'test-model',
    modelSelectionId: 'test/test-model',
    providerName: 'test',
  });

  const capPath = require.resolve('../../../server/services/ai/capabilityHealth');
  require(capPath);
  require.cache[capPath].exports.getCapabilityHealth = async () => ({});
  require.cache[capPath].exports.summarizeCapabilityHealth = () => '';

  for (const key of Object.keys(require.cache)) {
    if (
      key.includes('/server/services/ai/runtime/')
      || key.includes('/server/services/ai/loop/')
      || key.endsWith('/server/services/ai/engine.js')
    ) {
      delete require.cache[key];
    }
  }

  ({ AgentEngine } = require('../../../server/services/ai/engine'));
});

after(() => teardownTestRuntime(ctx));

// A catalog large enough that the integration tool cannot be in the active
// slice by accident — the same situation as a real install with ~167 tools.
function buildLargeCatalog() {
  const tools = [
    'task_complete',
    'search_tools',
    'activate_tools',
    'think',
    'send_message',
    'send_interim_update',
    'call_user',
    'read_file',
    'read_files',
    'list_directory',
    'search_files',
    'edit_file',
    'replace_file_range',
    'write_file',
  ].map((name) => ({ name, description: name, parameters: { type: 'object', properties: {} } }));

  for (let index = 0; index < 150; index += 1) {
    tools.push({
      name: `filler_${index}`,
      description: `filler ${index}`,
      parameters: { type: 'object', properties: {} },
    });
  }
  tools.push({
    name: 'google_workspace_calendar_list_events',
    description: 'List Google Calendar events in a time window',
    parameters: { type: 'object', properties: {} },
  });
  return tools;
}

async function observeFirstTurn(runOptions) {
  const engine = new AgentEngine(null);
  engine.emit = () => {};
  engine.buildSystemPrompt = async () => 'SYSTEM';
  engine.buildMemoryRecall = async () => null;
  engine.buildContextMessages = (prompt) => [{ role: 'system', content: prompt }];
  engine.buildUserMessage = (message) => ({ role: 'user', content: message });
  engine.getReasoningEffort = () => undefined;
  engine.requestStructuredJson = async ({ normalize, fallback }) => ({
    value: normalize({
      mode: 'execute',
      draft_reply: '',
      draft_status: 'needs_execution',
      goal: 'Do the thing',
      confidence: 0.8,
      suggested_tools: [],
    }, fallback || {}),
    raw: '',
    usage: 1,
  });
  engine.getAvailableTools = () => buildLargeCatalog();

  const observed = { discovery: '', activeNames: [], mcpRequested: false, searchResults: [] };
  engine.mcpManager = {
    getAllTools: () => {
      observed.mcpRequested = true;
      return [{
        name: 'mcp_srv_do_thing',
        description: 'mcp tool',
        parameters: { type: 'object', properties: {} },
      }];
    },
  };
  let modelTurn = 0;
  engine.requestModelResponse = async ({ messages, tools }) => {
    modelTurn += 1;
    if (!observed.discovery) {
      observed.discovery = messages
        .filter((message) => message.role === 'system')
        .map((message) => String(message.content || ''))
        .find((content) => content.includes('[Tool discovery]')) || '';
      observed.activeNames = tools.map((tool) => tool.name);
    }
    if (modelTurn === 1) {
      return {
        response: {
          content: '',
          toolCalls: [{
            id: 'search',
            type: 'function',
            function: {
              name: 'search_tools',
              arguments: JSON.stringify({ query: 'Google Calendar events MCP thing', limit: 12 }),
            },
          }],
          usage: { total_tokens: 1 },
        },
        streamContent: '',
      };
    }
    return {
      response: {
        content: '',
        toolCalls: [{
          id: 'done',
          type: 'function',
          function: { name: 'task_complete', arguments: JSON.stringify({ message: 'done' }) },
        }],
        usage: { total_tokens: 1 },
      },
      streamContent: '',
    };
  };
  engine.executeTool = async (name, args, context) => {
    if (name === 'search_tools') {
      const result = engine.searchToolsForRun(context.runId, args.query, args.limit);
      observed.searchResults = result.results;
      return result;
    }
    return { success: true };
  };
  engine.isReadOnlyToolCall = () => true;

  await engine.run(userId, 'do the thing', {
    stream: false,
    skipGlobalRecall: true,
    skipVerifier: true,
    maxIterations: 3,
    ...runOptions,
  });
  return observed;
}

const SURFACES = [
  ['web chat', { triggerSource: 'web' }],
  ['messaging', { triggerSource: 'messaging', source: 'whatsapp', chatId: 'chat-1' }],
  ['schedule automation', {
    triggerType: 'schedule',
    triggerSource: 'schedule',
    bypassUserRateLimits: true,
  }],
  ['background task', {
    triggerType: 'schedule',
    triggerSource: 'tasks',
    bypassUserRateLimits: true,
  }],
  ['subagent', {
    triggerType: 'subagent',
    triggerSource: 'agent',
    disallowedToolNames: ['spawn_subagent'],
  }],
];

for (const [label, runOptions] of SURFACES) {
  test(`${label}: inactive tools stay searchable without a full catalog dump`, async () => {
    const observed = await observeFirstTurn(runOptions);

    assert.ok(observed.discovery, 'no discovery summary reached the model');
    assert.doesNotMatch(observed.discovery, /google_workspace_calendar_list_events/);
    assert.ok(observed.searchResults.some((tool) => tool.name === 'google_workspace_calendar_list_events'));
    assert.ok(observed.searchResults.some((tool) => tool.name === 'mcp_srv_do_thing'));
    assert.ok(observed.mcpRequested, 'MCP tools were never collected');

    assert.ok(observed.activeNames.includes('search_tools'), 'search_tools must always be active');
    assert.ok(observed.activeNames.includes('activate_tools'), 'activate_tools must always be active');
    assert.ok(observed.activeNames.includes('task_complete'), 'task_complete must always be active');
    assert.ok(observed.activeNames.includes('call_user'), 'call_user must always be active');
    assert.ok(
      observed.activeNames.length <= MAX_TOOLS,
      `active schemas (${observed.activeNames.length}) exceed the provider cap`,
    );
  });
}
