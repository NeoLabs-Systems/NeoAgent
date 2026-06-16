'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { normalizeUsage, mergeUsage } = require('../../../server/services/ai/usage');
const {
  ToolRepetitionGuard,
  normalizeReadOnlyShellIntent,
  stableHash,
} = require('../../../server/services/ai/repetitionGuard');
const { parseDelimited } = require('../../../server/services/workspace/structured_data');
const {
  CORE_FILE_TOOLS,
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

test('repetition guard normalizes repeated read-only shell evidence fetches', () => {
  const guard = new ToolRepetitionGuard();
  const first = {
    command: 'curl -sL https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/README.md',
  };
  const second = {
    command: 'curl -sL https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/README.md | cat',
  };
  const third = {
    command: 'curl -sL https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/README.md > /tmp/readme.txt && wc -l /tmp/readme.txt',
  };
  const result = { stdout: 'same evidence' };

  guard.observe('execute_command', first, result);
  guard.observe('execute_command', second, result);

  assert.equal(guard.shouldBlock('execute_command', third), true);
  assert.deepEqual(normalizeReadOnlyShellIntent(first.command), normalizeReadOnlyShellIntent(second.command));
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

test('execute runs start with core file tools but direct runs stay lean', () => {
  const required = ['task_complete', 'activate_tools', 'think', 'send_message', 'send_interim_update'];
  const tools = [
    ...required.map((name) => ({ name, description: `${name} description` })),
    ...CORE_FILE_TOOLS.map((name) => ({ name, description: `${name} description` })),
    { name: 'execute_command', description: 'Run shell commands.' },
  ];

  const executeInitial = selectInitialTools(tools, ['execute_command'], { includeCoreFileTools: true });
  for (const toolName of CORE_FILE_TOOLS) {
    assert.equal(executeInitial.some((tool) => tool.name === toolName), true, `${toolName} should be active`);
  }

  const directInitial = selectInitialTools(tools, [], { includeCoreFileTools: false });
  assert.equal(directInitial.some((tool) => tool.name === 'read_files'), false);
  assert.equal(directInitial.some((tool) => tool.name === 'replace_file_range'), false);

  const crowdedTools = [
    ...tools,
    ...Array.from({ length: 30 }, (_, index) => ({ name: `extra_${index}`, description: `Extra ${index}` })),
  ];
  const crowdedInitial = selectInitialTools(
    crowdedTools,
    crowdedTools.slice(0, MAX_TOOLS).map((tool) => tool.name),
    { includeCoreFileTools: true },
  );
  const activated = activateTools(crowdedInitial, crowdedTools, ['extra_29'], { includeCoreFileTools: true });
  assert.equal(activated.tools.some((tool) => tool.name === 'extra_29'), true);
  for (const toolName of CORE_FILE_TOOLS) {
    assert.equal(activated.tools.some((tool) => tool.name === toolName), true, `${toolName} should remain active`);
  }
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

test('task analysis keeps short immediate work out of task automation flow', () => {
  const prompt = buildAnalysisPrompt({
    tools: [
      { name: 'create_task', description: 'Create a background task.' },
      { name: 'send_message', description: 'Send a message.' },
    ],
  });

  assert.match(prompt, /short immediate questions/);
  assert.match(prompt, /mode="direct_answer"/);
  assert.match(prompt, /progress_update_policy="none"/);
  assert.match(prompt, /Do not suggest create_task/);
  assert.match(prompt, /future, recurring, scheduled, monitored, background/);
});

test('structured data parser handles quoted delimiters and newlines', () => {
  assert.deepEqual(parseDelimited('name,note\nNeo,\"one,two\"\nA,\"line 1\nline 2\"\n', ','), [
    { name: 'Neo', note: 'one,two' },
    { name: 'A', note: 'line 1\nline 2' },
  ]);
});
