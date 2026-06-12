'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { normalizeUsage, mergeUsage } = require('../../../server/services/ai/usage');
const { ToolRepetitionGuard, stableHash } = require('../../../server/services/ai/repetitionGuard');
const { parseDelimited } = require('../../../server/services/workspace/structured_data');
const {
  MAX_TOOLS,
  activateTools,
  buildToolCatalog,
  selectInitialTools,
} = require('../../../server/services/ai/toolSelector');
const { buildAnalysisPrompt } = require('../../../server/services/ai/taskAnalysis');

test('usage normalization preserves reasoning and cache token categories', () => {
  assert.deepEqual(normalizeUsage({
    input_tokens: 100,
    output_tokens: 20,
    cache_read_input_tokens: 60,
    cache_creation_input_tokens: 10,
    completion_tokens_details: { reasoning_tokens: 5 },
  }), {
    inputTokens: 100,
    outputTokens: 20,
    reasoningTokens: 5,
    cachedReadTokens: 60,
    cacheWriteTokens: 10,
    totalTokens: 120,
  });
  assert.equal(mergeUsage({ inputTokens: 4 }, { outputTokens: 3 }).totalTokens, 7);
});

test('repetition guard blocks the third unchanged result but allows progress', () => {
  const guard = new ToolRepetitionGuard();
  const args = { query: 'same', filters: { b: 2, a: 1 } };
  assert.equal(guard.shouldBlock('search_files', args), false);
  guard.observe('search_files', args, { matches: [] });
  guard.observe('search_files', args, { matches: [] });
  assert.equal(guard.shouldBlock('search_files', args), true);

  const progressing = new ToolRepetitionGuard();
  progressing.observe('wait_subagent', { handle: 'one' }, { status: 'running' });
  progressing.observe('wait_subagent', { handle: 'one' }, { status: 'completed' });
  assert.equal(progressing.shouldBlock('wait_subagent', { handle: 'one' }), false);
});

test('stable hashes ignore object key order', () => {
  assert.equal(stableHash({ b: 2, a: 1 }), stableHash({ a: 1, b: 2 }));
});

test('tool catalog retains every tool and activation replaces unrelated schemas', () => {
  const required = ['task_complete', 'activate_tools', 'think', 'send_message', 'send_interim_update'];
  const tools = [
    ...required.map((name) => ({ name, description: `${name} description` })),
    ...Array.from({ length: 40 }, (_, index) => ({
      name: `tool_${index}`,
      description: `Capability ${index}`,
    })),
  ];
  const catalog = buildToolCatalog(tools);
  for (const tool of tools) assert.match(catalog, new RegExp(`^${tool.name} \\|`, 'm'));

  const initial = selectInitialTools(tools, tools.slice(5, 20).map((tool) => tool.name));
  assert.equal(initial.length, MAX_TOOLS);
  const result = activateTools(initial, tools, ['tool_39']);
  assert.equal(result.tools.length, MAX_TOOLS);
  assert.equal(result.tools.some((tool) => tool.name === 'tool_39'), true);
  assert.deepEqual(result.unknown, []);
  assert.equal(result.evicted.length, 1);
});

test('task analysis receives the complete tool inventory', () => {
  const tools = Array.from({ length: 140 }, (_, index) => ({
    name: `capability_${index}`,
    description: `Description for capability ${index}`,
  }));
  const prompt = buildAnalysisPrompt({ tools });
  assert.match(prompt, /capability_0: Description for capability 0/);
  assert.match(prompt, /capability_139: Description for capability 139/);
  assert.doesNotMatch(prompt, /\.\.\.\(\d+ more\)/);
});

test('structured data parser handles quoted delimiters and newlines', () => {
  assert.deepEqual(parseDelimited('name,note\nNeo,\"one,two\"\nA,\"line 1\nline 2\"\n', ','), [
    { name: 'Neo', note: 'one,two' },
    { name: 'A', note: 'line 1\nline 2' },
  ]);
});
