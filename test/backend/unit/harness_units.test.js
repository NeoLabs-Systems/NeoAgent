'use strict';

const { toolNamesWithSelection } = require('../../../server/services/ai/tools/metadata');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const { parseTestOutput, isTestCommand } = require('../../../server/services/ai/test_output');
const { compactToolResult } = require('../../../server/services/ai/toolResult');
const {
  decideMemoryRecall,
  exceedsMemoryBudget,
  filterRecalled,
} = require('../../../server/services/ai/runtime/memory_policy');
const {
  changesState,
  isParallelSafeCall,
  isReadOnlyCall,
  resolveToolMeta,
  stepTypeFor,
} = require('../../../server/services/ai/tools/metadata');
const { BUILT_IN_DEFINITIONS } = require('../../../server/services/ai/tools/definitions');
const { handlers } = require('../../../server/services/ai/tools/handlers');
const { ToolRepetitionGuard } = require('../../../server/services/ai/repetitionGuard');
const { MAX_RECOVERY_NOTES, applyRecovery, recoveryReason } = require('../../../server/services/ai/runtime/recovery');
const { buildTaskStateNote, mergeLedger, placeTaskStateNote } = require('../../../server/services/ai/runtime/task_state');
const {
  MAX_TOOLS,
  activateTools,
  buildToolDiscoverySummary,
  searchTools,
  selectToolCandidates,
} = require('../../../server/services/ai/toolSelector');
const { fitHistoryToBudget } = require('../../../server/services/ai/runtime/context_builder');
const { dropReasoningState, isReasoningReplayError } = require('../../../server/services/ai/runtime/reasoning_state');
const { estimatePromptMetrics } = require('../../../server/services/ai/runtime/prompt_metrics');
const { argsDigest, redactArgs } = require('../../../server/services/ai/runtime/events/redact');
const { summarizeRunEvents } = require('../../../server/services/ai/runtime/events/run_metrics');
const { OpenAICompatibleProvider } = require('../../../server/services/ai/providers/openaiCompatible');
const { AnthropicProvider } = require('../../../server/services/ai/providers/anthropic');
const { promptVersion, renderFragment, selectStableFragments } = require('../../../server/services/ai/prompts/registry');

// ---- tool metadata

test('every built-in tool has metadata and a handler, and every handler a definition', () => {
  const names = new Set(BUILT_IN_DEFINITIONS.map((tool) => tool.name));
  assert.equal(names.size, BUILT_IN_DEFINITIONS.length, 'tool names are unique');
  for (const tool of BUILT_IN_DEFINITIONS) {
    assert.ok(tool.group, `${tool.name} has a group`);
    assert.ok(['read', 'write', 'dynamic_http_method', 'dynamic_shell'].includes(tool.access), `${tool.name} declares its access`);
    assert.ok(tool.capabilities?.length, `${tool.name} has capabilities`);
    assert.ok(Object.hasOwn(handlers, tool.name), `${tool.name} has a handler`);
  }
  for (const name of Object.keys(handlers)) assert.ok(names.has(name), `${name} has a definition`);
});

test('a call\'s access can depend on its arguments', () => {
  const http = resolveToolMeta('http_request');
  assert.equal(isReadOnlyCall(http, { method: 'GET' }), true);
  assert.equal(isReadOnlyCall(http, { method: 'POST' }), false);
  const shell = resolveToolMeta('execute_command');
  assert.equal(isReadOnlyCall(shell, { command: 'git status' }), true);
  assert.equal(isReadOnlyCall(shell, { command: 'rm -rf build' }), false);
});

test('only independent reads run in parallel', () => {
  const parallel = (name, args = {}) => isParallelSafeCall(resolveToolMeta(name), args);
  assert.equal(parallel('read_file'), true);
  assert.equal(parallel('web_search'), true);
  assert.equal(parallel('edit_file'), false);
  // One shared page: an extract next to a navigation sees whichever won.
  assert.equal(parallel('browser_extract'), false);
  assert.equal(parallel('android_screenshot'), false);
  assert.equal(parallel('send_message'), false);
  // A read-only command can still depend on the one before it.
  assert.equal(parallel('execute_command', { command: 'ls' }), false);
});

test('third-party tools get the conservative reading', () => {
  const unknown = resolveToolMeta('linear_create_issue');
  assert.equal(unknown.known, false);
  assert.equal(unknown.untrusted, true);
  assert.equal(isParallelSafeCall(unknown, {}), false);
  // Declaring nothing is no claim of having changed anything.
  assert.equal(changesState(unknown, {}), false);
  const declared = resolveToolMeta('notion_search', { access: 'read', integration: 'notion' });
  assert.equal(declared.group, 'integration');
  assert.equal(isParallelSafeCall(declared, {}), true);
  assert.equal(stepTypeFor('mcp_srv_do', { serverId: 'srv' }), 'mcp');
});

// ---- repeat detection

test('a repeated read is suppressed until something it depends on changes', () => {
  const guard = new ToolRepetitionGuard();
  const args = { path: 'a.js' };
  const first = guard.fingerprint('read_file', args, 'workspace');
  assert.equal(guard.claimRead(first, 1), null);
  assert.equal(guard.claimRead(first, 2).stepIndex, 1);

  guard.noteStateChanged('workspace');
  const afterEdit = guard.fingerprint('read_file', args, 'workspace');
  assert.notEqual(afterEdit, first);
  assert.equal(guard.claimRead(afterEdit, 3), null);

  guard.noteStateChanged('browser');
  assert.equal(guard.fingerprint('read_file', args, 'workspace'), afterEdit, 'unrelated state does not count');

  guard.noteCompaction();
  assert.notEqual(guard.fingerprint('read_file', args, 'workspace'), afterEdit, 'the model may have lost the earlier answer');
});

test('an old answer stops standing in for a repeated read', () => {
  let now = 1_000;
  const guard = new ToolRepetitionGuard({ now: () => now });
  const fingerprint = guard.fingerprint('read_file', { path: 'a.js' }, 'workspace');
  assert.equal(guard.claimRead(fingerprint, 1), null);
  now += 11 * 60 * 1000;
  assert.equal(guard.claimRead(fingerprint, 2), null);
});

// ---- recovery

function recoverySession(streaks) {
  const events = [];
  return {
    runId: 'r',
    userId: 1,
    agentId: null,
    userMessage: 'Fix the build',
    options: {},
    iterations: 3,
    messages: [],
    toolExecutions: [{ toolName: 'execute_command', ok: false, error: 'make failed' }],
    engine: { getRunMeta: () => ({}) },
    guards: { streaks: () => streaks.current },
    eventBus: { publish: (event) => events.push(event) },
    events,
  };
}

test('recovery fires once a problem shows, re-arms when it clears, and stays bounded', () => {
  assert.equal(recoveryReason({ failedTurns: 2 }), 'tool_failures');
  assert.equal(recoveryReason({ sameActionTurns: 2 }), 'same_action');
  assert.equal(recoveryReason({ idleTurns: 2 }), 'no_progress');
  assert.equal(recoveryReason({ failedTurns: 1, idleTurns: 1 }), null);

  const streaks = { current: { failedTurns: 2, idleTurns: 0, sameActionTurns: 0 } };
  const session = recoverySession(streaks);
  assert.equal(applyRecovery(session), 'tool_failures');
  assert.match(session.messages[0].content, /^\[Recovery\]/);
  assert.match(session.messages[0].content, /Fix the build/);
  assert.match(session.messages[0].content, /make failed/);
  assert.equal(applyRecovery(session), null, 'one note per problem');

  streaks.current = { failedTurns: 0, idleTurns: 0, sameActionTurns: 0 };
  assert.equal(applyRecovery(session), null);
  for (let round = 1; round < MAX_RECOVERY_NOTES + 3; round += 1) {
    streaks.current = { failedTurns: 2, idleTurns: 0, sameActionTurns: 0 };
    applyRecovery(session);
    streaks.current = { failedTurns: 0, idleTurns: 0, sameActionTurns: 0 };
    applyRecovery(session);
  }
  assert.equal(session.messages.length, MAX_RECOVERY_NOTES);
});

// ---- task ledger

test('the ledger merges what changed and survives a compaction word for word', () => {
  let ledger = mergeLedger(null, { goal: 'Fix auth tests', steps: [{ id: 'inspect', status: 'done' }, { id: 'patch', status: 'nonsense' }] });
  ledger = mergeLedger(ledger, { observations: ['failure reproduced in auth.test.js'] });
  assert.equal(ledger.goal, 'Fix auth tests');
  assert.deepEqual(ledger.steps[1], { id: 'patch', status: 'pending' });
  assert.deepEqual(ledger.observations, ['failure reproduced in auth.test.js']);

  const session = {
    runId: 'r',
    userMessage: 'x',
    options: {},
    changedPaths: new Set(['src/auth.js']),
    lastCheck: 'npm test: 1 failed, 2 passed',
    engine: { getRunMeta: () => ({ ledger }) },
    messages: [
      { role: 'system', content: 'prompt' },
      { role: 'system', content: '[Previous conversation summary]\nolder' },
      { role: 'user', content: 'go' },
    ],
  };
  const note = buildTaskStateNote(session);
  assert.match(note, /Goal: Fix auth tests/);
  assert.match(note, /Your notes \(not checked by anything\): failure reproduced/);
  assert.match(note, /src\/auth\.js/);
  assert.match(note, /1 failed, 2 passed/);

  placeTaskStateNote(session);
  placeTaskStateNote(session);
  const notes = session.messages.filter((message) => String(message.content).startsWith('[Task state]'));
  assert.equal(notes.length, 1, 'replaced, not stacked');
  assert.equal(session.messages[2], notes[0], 'in the leading section later compactions keep');
});

// ---- tool candidates

function bigCatalog() {
  return [
    ...toolNamesWithSelection('always').map((name) => ({ name })),
    ...['web_search', 'http_request', 'execute_command', 'memory_recall', 'memory_save', 'create_task'].map((name) => ({ name })),
    ...['read_file', 'read_files', 'search_files', 'list_directory', 'edit_file', 'write_file'].map((name) => ({ name })),
    { name: 'notion_search', access: 'read' },
    { name: 'notion_create_page', access: 'write' },
    ...Array.from({ length: 30 }, (_, index) => ({ name: `android_extra_${index}` })),
  ];
}

test('the signals that pick tools do not read a request\'s meaning', () => {
  const names = (request, extra = {}) => selectToolCandidates(bigCatalog(), { request, ...extra }).tools.map((tool) => tool.name);
  const plain = names('Wie wird das Wetter morgen?');
  assert.deepEqual(plain, names('What will the weather be tomorrow?'), 'language does not matter');
  assert.equal(plain.includes('read_file'), false);
  assert.deepEqual(names('Fix the bug in server/auth/session.js'), names('修复登录问题'), 'request phrases do not grant schema slots');
  assert.ok(names('schau in notion nach dem Plan').includes('notion_search'), 'a named product');
  assert.ok(names('und jetzt weiter', { conversationTools: ['search_files'] }).includes('search_files'), 'what this conversation was using');
  assert.ok(names('x').length <= MAX_TOOLS);
});

test('a small catalog is simply all active, and scores never reorder the schemas', () => {
  const small = [{ name: 'b' }, { name: 'a' }];
  assert.deepEqual(selectToolCandidates(small).tools, small);
  const first = selectToolCandidates(bigCatalog(), { request: 'x', conversationTools: ['read_file'] }).tools.map((tool) => tool.name);
  assert.ok(first.indexOf('search_tools') < first.indexOf('web_search'));
  assert.ok(first.indexOf('web_search') < first.indexOf('read_file'), 'added later, listed later');
});

test('the catalog lists names by group, and a group can be activated by name', () => {
  const catalog = [
    { name: 'search_tools' },
    { name: 'browser_navigate' },
    { name: 'browser_click' },
    { name: 'notion_search', access: 'read' },
    { name: 'mcp_srv_do', serverId: 'srv', description: 'Does the thing on the server.' },
  ];
  const summary = buildToolDiscoverySummary(catalog, [catalog[0]]);
  assert.match(summary, /browser: browser_navigate, browser_click/);
  assert.match(summary, /notion: notion_search/);
  assert.match(summary, /mcp:srv: mcp_srv_do \(Does the thing/);
  assert.equal(buildToolDiscoverySummary(catalog, catalog), '');

  const activated = activateTools([catalog[0]], catalog, ['browser']);
  assert.deepEqual(activated.activated.sort(), ['browser_click', 'browser_navigate']);
});

test('search uses what a tool is for, not only its name', () => {
  const tools = BUILT_IN_DEFINITIONS.map((tool) => ({ name: tool.name, description: tool.description }));
  assert.equal(searchTools(tools, 'reminder').some((tool) => tool.name === 'create_task'), true);
  assert.equal(searchTools(tools, 'undo rollback').some((tool) => tool.name === 'workspace_rollback'), true);
});

// ---- memory

test('recall policy uses the same relevance threshold in every language', () => {
  assert.equal(decideMemoryRecall('👍').recall, false);
  const requests = ['ok', 'danke', 'Erinnerst du dich an den Plan?', 'what did we decide last time', 'wie heißt mein Hund', 'explain my setup', '解释我的设置'];
  const policy = decideMemoryRecall(requests[0]);
  for (const request of requests) assert.deepEqual(decideMemoryRecall(request), policy);
});

test('only memories with real evidence of matching reach the prompt', () => {
  const memory = (id, semantic, extra = {}) => ({ id, scoreBreakdown: { semantic, ...extra } });
  const kept = (recalled, minSignal) => filterRecalled(recalled, { minSignal }).map((entry) => entry.id);
  assert.deepEqual(kept([memory('strong', 0.8), memory('weak', 0.1)], 0.2), ['strong']);
  assert.deepEqual(kept([memory('a', 0.9), memory('far', 0.3)], 0.2), ['a'], 'far weaker than the best match');
  assert.deepEqual(kept([memory('entity', 0.1, { entity: 0.48 })], 0.45), ['entity']);
  assert.deepEqual(kept([{ id: 'unscored', score: 0.3 }], 0.45), ['unscored']);
  assert.equal(exceedsMemoryBudget('x'.repeat(4000), 10_000), true);
  assert.equal(exceedsMemoryBudget('x'.repeat(400), 10_000), false);
});

// ---- context

test('history over its budget loses whole turns from the old end', () => {
  const history = [
    { role: 'user', content: 'a'.repeat(4000) },
    { role: 'assistant', content: 'b'.repeat(4000) },
    { role: 'user', content: 'c'.repeat(400) },
    { role: 'assistant', content: 'd'.repeat(400) },
  ];
  assert.equal(fitHistoryToBudget(history, 100_000).dropped, 0);
  const fitted = fitHistoryToBudget(history, 400);
  assert.equal(fitted.dropped, 2);
  assert.equal(fitted.history[0].content[0], 'c');
});

test('prompt metrics say which section a request\'s tokens went to', () => {
  const metrics = estimatePromptMetrics([
    { role: 'system', content: 'x'.repeat(400) },
    { role: 'system', content: 'y'.repeat(40) },
    { role: 'system', content: `[Tool discovery]\n${'t'.repeat(80)}` },
    { role: 'system', content: `[Recalled context]\n${'m'.repeat(80)}` },
    { role: 'user', content: 'hello' },
    { role: 'tool', content: 'r'.repeat(200), tool_call_id: 'c' },
  ], [{ name: 'a', parameters: {} }]);
  assert.ok(metrics.systemPromptTokens >= 100);
  assert.ok(metrics.toolCatalogTokens >= 20);
  assert.ok(metrics.recalledMemoryTokens >= 20);
  assert.ok(metrics.toolReplayTokens >= 50);
  assert.ok(metrics.toolSchemaTokens > 0);
  assert.equal(metrics.totalEstimatedTokens, Object.entries(metrics)
    .filter(([key]) => key !== 'totalEstimatedTokens')
    .reduce((sum, [, value]) => sum + value, 0));
});

// ---- reasoning

test('reasoning goes back in the field it came in, and only to its own model', () => {
  const provider = new OpenAICompatibleProvider({});
  const toolCalls = [{ id: 'c', type: 'function', function: { name: 'x', arguments: '{}' } }];
  const [deepseek] = provider.prepareMessages([{ role: 'assistant', content: '', tool_calls: toolCalls, reasoningState: { reasoning_content: 'because' } }]);
  assert.equal(deepseek.reasoning_content, 'because');
  assert.equal(deepseek.reasoningState, undefined);

  const details = [{ type: 'reasoning.encrypted', data: 'abc' }];
  const [openrouter] = provider.prepareMessages([{ role: 'assistant', content: '', tool_calls: toolCalls, reasoningState: { reasoning_details: details } }]);
  assert.deepEqual(openrouter.reasoning_details, details);

  const messages = [{ role: 'assistant', reasoningState: { reasoning: 'x' } }, { role: 'assistant', providerContentBlocks: [{}] }, { role: 'user' }];
  assert.equal(dropReasoningState(messages), true);
  assert.equal(messages[0].reasoningState, undefined);
  assert.equal(messages[1].providerContentBlocks, undefined);
  assert.equal(dropReasoningState(messages), false);

  assert.equal(isReasoningReplayError(Object.assign(new Error('Invalid signature in thinking block'), { status: 400 })), true);
  assert.equal(isReasoningReplayError(Object.assign(new Error('reasoning model overloaded'), { status: 503 })), false);
  assert.equal(isReasoningReplayError(Object.assign(new Error('bad tool schema'), { status: 400 })), false);
});

test('reasoning streamed in pieces is reassembled exactly', async () => {
  const provider = new OpenAICompatibleProvider({});
  async function* stream() {
    yield { choices: [{ delta: { reasoning_details: [{ index: 0, type: 'reasoning.text', text: 'first ' }] } }] };
    yield { choices: [{ delta: { reasoning_details: [{ index: 0, text: 'second', signature: 'sig' }] } }] };
    yield { choices: [{ delta: { tool_calls: [{ index: 0, id: 'c1', function: { name: 'do_it', arguments: '{}' } }] } }] };
    yield { choices: [{ delta: {}, finish_reason: 'tool_calls' }] };
  }
  const chunks = [];
  for await (const chunk of provider.readStream(stream(), [])) chunks.push(chunk);
  const final = chunks[chunks.length - 1];
  assert.equal(final.type, 'tool_calls');
  assert.deepEqual(final.reasoningState.reasoning_details, [{ index: 0, type: 'reasoning.text', text: 'first second', signature: 'sig' }]);
});

// ---- prompt caching

test('input tokens include what the cache served, whichever provider answered', async () => {
  const anthropic = new AnthropicProvider({ apiKey: 'test' });
  anthropic.client = {
    messages: {
      create: async () => ({
        content: [{ type: 'text', text: 'ok' }],
        usage: { input_tokens: 10, cache_read_input_tokens: 900, cache_creation_input_tokens: 90, output_tokens: 5 },
        stop_reason: 'end_turn',
      }),
    },
  };
  const { usage } = await anthropic.chat([{ role: 'user', content: 'hi' }], [], { model: 'claude-x', maxTokens: 10 });
  assert.equal(usage.inputTokens, 1000);
  assert.equal(usage.promptTokens, 1000);
  assert.equal(usage.totalTokens, 1005);
  assert.equal(usage.cachedReadTokens, 900);
});

test('the cache hit rate is what the cache served of what was sent', async () => {
  const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
  const ctx = createTestRuntime();
  try {
    const user = await createTestUser(ctx.db);
    const agentId = 'agent-report';
    ctx.db.prepare("INSERT INTO agents (id, user_id, slug, display_name) VALUES (?, ?, 'report', 'Report')").run(agentId, user.userId);
    const insert = (metrics) => ctx.db.prepare(
      `INSERT INTO agent_runs (id, user_id, agent_id, title, status, metrics_json, created_at)
       VALUES (?, ?, ?, 't', 'completed', ?, datetime('now'))`,
    ).run(`run-${Math.random()}`, user.userId, agentId, JSON.stringify(metrics));
    const { buildHarnessReport } = require('../../../server/services/ai/runtime/events/harness_report');

    insert({ tokens: { input: 1000, cachedRead: 900 } });
    assert.equal(buildHarnessReport(user.userId, agentId).rates.prompt_cache_hit, 0.9);
    // A row from before input counted cached tokens on Anthropic.
    insert({ tokens: { input: 10, cachedRead: 5000 } });
    assert.equal(buildHarnessReport(user.userId, agentId).rates.prompt_cache_hit, 1);
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('Anthropic requests cache tools, the stable block, and the newest turn', async () => {
  const provider = new AnthropicProvider({ apiKey: 'test' });
  let params = null;
  provider.client = {
    messages: {
      create: async (input) => {
        params = input;
        return { content: [{ type: 'text', text: 'ok' }], usage: { input_tokens: 1, output_tokens: 1 }, stop_reason: 'end_turn' };
      },
    },
  };
  await provider.chat([
    { role: 'system', content: 'stable policy' },
    { role: 'system', content: 'dynamic state' },
    { role: 'user', content: 'do it' },
    {
      role: 'assistant',
      content: '',
      tool_calls: [{ id: 'c1', type: 'function', function: { name: 'x', arguments: '{}' } }],
    },
    { role: 'tool', tool_call_id: 'c1', content: 'result' },
    { role: 'system', content: '[Recovery]\nnote' },
  ], [{ name: 'x', description: 'd', parameters: { type: 'object', properties: {} } }, { name: 'y', description: 'd', parameters: { type: 'object', properties: {} } }], { model: 'claude-test' });

  assert.equal(params.tools[0].cache_control, undefined);
  assert.deepEqual(params.tools[1].cache_control, { type: 'ephemeral' });
  assert.deepEqual(params.system[0].cache_control, { type: 'ephemeral' });
  assert.equal(params.system[1].cache_control, undefined);
  assert.equal(params.system.length, 2, 'a note added mid-run leaves the cached system block alone');
  const last = params.messages[params.messages.length - 1];
  assert.equal(last.role, 'user');
  assert.match(last.content[0].text, /\[Recovery\]/);
  assert.deepEqual(last.content[0].cache_control, { type: 'ephemeral' });
});

// ---- test output

test('a test run reads as counts and failures, for every common runner', () => {
  const nodeOutput = [
    '✔ passes (1ms)',
    'ℹ tests 3',
    'ℹ pass 2',
    'ℹ fail 1',
    '✖ failing tests:',
    '',
    'test at test/auth.test.js:81:1',
    '✖ rejects expired token (2ms)',
    '  AssertionError: expected 401, received 500',
  ].join('\n');
  const node = parseTestOutput({ command: 'npm test', stdout: nodeOutput });
  assert.equal(node.summary, '1 failed, 2 passed');
  assert.equal(node.failures[0].test, 'rejects expired token');
  assert.equal(node.failures[0].file, 'test/auth.test.js');
  assert.match(node.failures[0].message, /expected 401/);

  const cases = [
    ['npx jest', 'Tests:       1 failed, 4 passed, 5 total\n  ● auth › rejects token\n\n    expect(received).toBe(expected)', 'jest', '1 failed, 4 passed'],
    ['npx vitest run', ' FAIL  src/a.test.ts > adds\nAssertionError: nope\n      Tests  1 failed | 3 passed (4)', 'vitest', '1 failed, 3 passed'],
    ['pytest -q', 'FAILED tests/test_a.py::test_x - assert 1 == 2\n===== 1 failed, 9 passed in 0.12s =====', 'pytest', '1 failed, 9 passed'],
    ['go test ./...', '--- FAIL: TestX (0.00s)\n    a_test.go:12: boom\nFAIL\nFAIL\texample.com/a\t0.1s', 'go test', '1 failed, 0 passed'],
    ['cargo test', 'test a::b ... FAILED\ntest result: FAILED. 4 passed; 1 failed; 0 ignored', 'cargo test', '1 failed, 4 passed'],
    ['npx mocha', '  5 passing (3ms)\n  1 failing\n', 'mocha', '1 failed, 5 passed'],
    ['bundle exec rspec', '6 examples, 2 failures\nrspec ./spec/a_spec.rb:4 # A does B', 'rspec', '2 failed, 4 passed'],
    ['flutter test', '00:01 +3 -1: Some tests failed.', 'dart test', '1 failed, 3 passed'],
  ];
  for (const [command, stdout, runner, summary] of cases) {
    const parsed = parseTestOutput({ command, stdout });
    assert.equal(parsed?.runner, runner, command);
    assert.equal(parsed?.summary, summary, command);
  }
});

test('ordinary command output is never mistaken for a test result', () => {
  assert.equal(isTestCommand('ls -la'), false);
  assert.equal(isTestCommand('cat latest.test.log'), false);
  assert.equal(isTestCommand('npm run test:unit'), true);
  assert.equal(parseTestOutput({ command: 'cat report.txt', stdout: 'ℹ pass 3\nℹ fail 1' }), null);
  assert.equal(parseTestOutput({ command: 'npm test', stdout: 'nothing readable here' }), null);
});

test('a failing test run reaches the model as failures rather than a wall of log', () => {
  const log = `${'noise line\n'.repeat(4000)}ℹ pass 186\nℹ fail 1\n✖ failing tests:\n\ntest at test/a.test.js:1:1\n✖ the broken one (1ms)\n  boom\n`;
  const compacted = JSON.parse(compactToolResult('execute_command', { command: 'npm test' }, { exitCode: 1, stdout: log, stderr: '' }, { softLimit: 8000, hardLimit: 16000 }));
  assert.equal(compacted.test_result.summary, '1 failed, 186 passed');
  assert.equal(compacted.test_result.failures[0].test, 'the broken one');
  assert.ok(compacted.stdout.length < 1500, 'the log gives way to the summary');
});

// ---- telemetry

test('metadata arguments retain only a digest and count', () => {
  const args = { query: 'auth', api_key: 'dummy-secret', command: 'inline dummy credential', content: 'private fixture' };
  assert.deepEqual(redactArgs(args), { count: 4, digest: argsDigest(args) });
  assert.ok(!JSON.stringify(redactArgs(args)).includes('dummy'));
  assert.equal(argsDigest({ a: 1, b: 2 }), argsDigest({ b: 2, a: 1 }));
});

test('a run summary splits latency and counts what happened', () => {
  const at = (ms) => new Date(1_700_000_000_000 + ms).toISOString();
  const event = (eventType, ms, payload = {}) => ({ eventType, payload: { timestamp: at(ms), ...payload } });
  const metrics = summarizeRunEvents([
    event('run.started', 0),
    event('context.built', 100, { startup_ms: 100, prompt_version: 'abc' }),
    event('tools.selected', 100, { kind: 'initial', selection: { catalog_size: 80, eligible_count: 60, active_count: 13 } }),
    event('model.request', 110, { context: { estimated_tokens: 1000 } }),
    event('model.response', 900, { phase: 'model_turn', duration_ms: 790, retry_count: 1 }),
    event('tool.call', 910, { tool: { name: 'execute_command' } }),
    event('tool.result', 1910, { duration_ms: 1000, sandbox_ms: 200, tool: { name: 'execute_command', call_fingerprint: 'f1' }, outcome: { status: 'success' } }),
    event('tool.suppressed', 1920, {}),
    event('memory.recall', 50, { recalled: true, tokens: 100 }),
    event('recovery.triggered', 1930, {}),
    event('delivery.sent', 2000, { purpose: 'final', duration_ms: 50 }),
    event('delivery.suppressed', 2001, { purpose: 'reply' }),
    event('model.response', 1950, { phase: 'wrap_up', duration_ms: 10 }),
    event('run.completed', 2010),
  ], { usage: [{ input_tokens: 500, output_tokens: 20, cached_read_tokens: 100, total_tokens: 520 }], run: { status: 'completed' } });

  assert.equal(metrics.turns, 1);
  assert.equal(metrics.side_calls, 1);
  assert.equal(metrics.retries, 1);
  assert.equal(metrics.duration_ms, 2010);
  assert.equal(metrics.first_action_ms, 910);
  assert.deepEqual(metrics.latency, { queue_ms: 100, model_ms: 800, tool_ms: 800, sandbox_ms: 200, delivery_ms: 50 });
  assert.equal(metrics.tools.calls, 1);
  assert.equal(metrics.tools.suppressed, 1);
  assert.equal(metrics.selection.catalog_size, 80);
  assert.equal(metrics.tokens.cachedRead, 100);
  assert.equal(metrics.memory.tokens, 100);
  assert.equal(metrics.memory.share_of_prompt, 0.1);
  assert.equal(metrics.recoveries, 1);
  assert.equal(metrics.delivery.final_sent, 1);
  assert.equal(metrics.delivery.suppressed, 1);
  assert.equal(metrics.prompt_version, 'abc');
});

// ---- shell

test('a command that cannot start reports an error instead of crashing the process', async () => {
  const { CLIExecutor } = require('../../../server/services/cli/executor');
  const crashes = [];
  const onCrash = (error) => crashes.push(error);
  process.on('uncaughtException', onCrash);
  try {
    const result = await new CLIExecutor().execute('echo hi', { cwd: '/definitely/not/here' });
    assert.equal(result.exitCode, -1);
    assert.match(result.error, /ENOENT/);
    // The 'close' event comes after 'error', on a later tick.
    await new Promise((resolve) => setTimeout(resolve, 100));
    assert.deepEqual(crashes, []);
  } finally {
    process.off('uncaughtException', onCrash);
  }
});

test('commands get a fixed environment, not what the server uses', async () => {
  const { CLIExecutor } = require('../../../server/services/cli/executor');
  const { buildWorkerEnv } = require('../../../server/services/cli/shell_worker_pool');
  const secrets = { HARNESS_PROBE_API_KEY: 'a', ORDINARY_NAME: 'b' };
  Object.assign(process.env, secrets);
  try {
    const result = await new CLIExecutor({ baseEnvironment: () => buildWorkerEnv(process.env, []) })
      .execute('echo "[$HARNESS_PROBE_API_KEY][$ORDINARY_NAME][$HOME]"', { cwd: '/tmp' });
    assert.ok(result.stdout.startsWith('[][]['), result.stdout);
    assert.ok(result.stdout.trim().length > '[][][]'.length, 'ordinary things like HOME stay');
  } finally {
    for (const name of Object.keys(secrets)) delete process.env[name];
  }
});

test('a command reading stdin gets end of input instead of hanging', async () => {
  const { CLIExecutor } = require('../../../server/services/cli/executor');
  const started = Date.now();
  const result = await new CLIExecutor().execute('cat', { cwd: '/tmp', timeout: 20_000 });
  assert.equal(result.exitCode, 0);
  assert.ok(Date.now() - started < 10_000, 'it returned at once');
});

// ---- what came of a run

test('the task outcome comes from receipts, never from what the model said', () => {
  const { summarizeRunEvents } = require('../../../server/services/ai/runtime/events/run_metrics');
  const ts = '2026-11-04T10:00:00.000Z';
  const result = (sequenceIndex, receipt) => ({ sequenceIndex, eventType: 'tool.result', payload: { timestamp: ts, tool: { name: 'execute_command' }, receipt } });
  const changed = (sequenceIndex, paths) => ({ sequenceIndex, eventType: 'workspace.changed', payload: { timestamp: ts, count: paths.length, paths } });
  const outcome = (events, status = 'completed') => summarizeRunEvents(events, { run: { status } }).outcome;

  assert.equal(outcome([]).task_outcome, 'answered');
  assert.equal(outcome([], 'failed').task_outcome, 'failed');
  assert.equal(outcome([result(1, { mutating: false, ok: false })]).task_outcome, 'answered', 'looking things up changes nothing');
  assert.equal(outcome([result(1, { mutating: true, ok: false })]).task_outcome, 'action_failed');
  assert.equal(outcome([result(1, { mutating: true, ok: false }), result(2, { mutating: true, ok: true })]).task_outcome, 'actions_done', 'a later attempt worked');

  const edit = result(1, { mutating: true, ok: true });
  assert.equal(outcome([edit, changed(2, ['a.js'])]).task_outcome, 'unverified');
  const failing = outcome([edit, changed(2, ['a.js']), result(3, { mutating: true, ok: true, test: { runner: 'jest', passed: 3, failed: 1, exit_ok: false } })]);
  assert.equal(failing.task_outcome, 'tests_failing');
  assert.equal(failing.evidence.last_test.failed, 1);
  assert.equal(failing.evidence.files_changed, 1);
  const passing = outcome([edit, changed(2, ['a.js']), result(3, { mutating: true, ok: true, test: { runner: 'jest', passed: 4, failed: 0, exit_ok: true } })]);
  assert.equal(passing.task_outcome, 'verified');
  // Passing tests prove nothing about a change made after them.
  const stale = outcome([edit, result(3, { mutating: true, ok: true, test: { runner: 'jest', passed: 4, failed: 0, exit_ok: true } }), changed(4, ['a.js'])]);
  assert.equal(stale.task_outcome, 'unverified');
  const untracked = outcome([edit, { sequenceIndex: 2, eventType: 'workspace.changed', payload: { timestamp: ts, untracked: true, reason: 'read_failed' } }]);
  assert.equal(untracked.task_outcome, 'unverified');
  assert.equal(untracked.evidence.changes_untracked, 1);
  // Outside a repository nothing is tracked, so nothing counts as changed.
  const outside = outcome([edit, { sequenceIndex: 2, eventType: 'workspace.changed', payload: { timestamp: ts, untracked: true, reason: 'not_a_repository' } }]);
  assert.equal(outside.task_outcome, 'actions_done');
  assert.deepEqual([outside.evidence.changes_untracked, outside.evidence.outside_repositories], [0, 1]);
});

test('passes from a command that failed are not verification, and a rollback is said', () => {
  const { summarizeRunEvents } = require('../../../server/services/ai/runtime/events/run_metrics');
  const ts = '2026-11-04T10:00:00.000Z';
  const result = (sequenceIndex, receipt) => ({ sequenceIndex, eventType: 'tool.result', payload: { timestamp: ts, tool: { name: 'execute_command' }, receipt } });
  const changed = (sequenceIndex) => ({ sequenceIndex, eventType: 'workspace.changed', payload: { timestamp: ts, count: 1, paths: ['a.js'] } });
  const outcome = (events) => summarizeRunEvents(events, { run: { status: 'completed' } }).outcome.task_outcome;
  const edit = result(1, { mutating: true, ok: true });
  // Jest with a suite that failed to compile, or `npm test && tsc`: passes, exit 1.
  assert.equal(outcome([edit, changed(2), result(3, { mutating: true, ok: false, test: { runner: 'jest', passed: 5, failed: 0, exit_ok: false } })]), 'tests_failing');
  assert.equal(outcome([edit, changed(2), result(3, { mutating: true, ok: true, test: { runner: 'jest', passed: 0, failed: 0, exit_ok: true } })]), 'actions_done', 'no tests ran');
  assert.equal(outcome([edit, changed(2), { sequenceIndex: 3, eventType: 'checkpoint.restored', payload: { timestamp: ts, restored: 1 } }]), 'rolled_back');
  // An untracked change after the tests puts them out of date.
  assert.equal(outcome([edit, changed(2), result(3, { mutating: true, ok: true, test: { runner: 'jest', passed: 2, failed: 0, exit_ok: true } }), { sequenceIndex: 4, eventType: 'workspace.changed', payload: { timestamp: ts, untracked: true } }]), 'unverified');
});

test('a read-only classification means it really only reads', () => {
  const { isClearlyReadOnlyShellCommand: readOnly } = require('../../../server/services/ai/loop/progress_classification');
  for (const command of ['ls -la', 'git status', 'git log --oneline | head -5', 'grep -rn foo src', 'cat a.txt && wc -l a.txt', "sed -n '1,5p' a.txt", 'find . -name "*.js"', 'git branch', 'git branch -a', 'ls 2>&1', 'ls 2>/dev/null', "ls \\\n  -la", 'ls\ngit status']) {
    assert.equal(readOnly(command), true, command);
  }
  for (const command of [
    "sed -i 's/a/b/' f", "sed 's/a/b/w out' f", 'find . -delete', 'find . -exec rm {} ;', 'tee f', 'echo x | tee f', 'env rm -rf src',
    'curl -X POST https://x.test', 'curl https://x.test?d=1', 'git branch -D main', 'git branch newname', 'ls & rm -rf x', 'ls; rm x', 'cat $(rm x)', 'cat `rm x`',
    'awk \'BEGIN{system("rm x")}\' f', 'python3 -c "print(1)"', 'sort -o out f', 'git diff --output=f', 'rg --pre rm x',
    'ls\nrm x', 'ls #note\nrm y', 'sed "1e rm x" a', 'sed -n 1p -e "1e rm x" a', "sed 's/a/b/' f",
    'git diff --ext-diff', 'git grep -O"rm y" foo', 'sort --compress-program=rm a', 'rg --hostname-bin=rm x', 'less a',
    'GIT_EXTERNAL_DIFF=rm git diff', 'PAGER=rm git log', 'LD_PRELOAD=/tmp/x.so ls', 'cat a > /tmp/../home/x',
  ]) {
    assert.equal(readOnly(command), false, command);
  }
});

test('text that may be a written-out tool call is held back while streaming', () => {
  const { mayBeRawToolCall, isRawToolCall } = require('../../../server/services/ai/outputSanitizer');
  for (const text of ['{"na', '```json\n{', '<tool_c', '<invoke name="x">', '{"name":"x","arguments":{}}']) assert.equal(mayBeRawToolCall(text), true, text);
  for (const text of ['Hello', 'Die Datei ist fertig.', '- a list']) assert.equal(mayBeRawToolCall(text), false, text);
  assert.equal(isRawToolCall('Plain answer about <b>tags</b>'), false);
});

test('a message that is a written-out tool call is never delivered', async () => {
  const { commitDelivery } = require('../../../server/services/ai/runtime/delivery/delivery_worker');
  let sent = 0;
  const outcome = await commitDelivery({
    run: { id: 'raw-run', user_id: 1 },
    channel: 'web',
    purpose: 'interim',
    slot: 'a',
    content: '{"name":"send_message","arguments":{"text":"hi"}}',
    transmit: async () => { sent += 1; },
  });
  assert.deepEqual([outcome.ok, outcome.reason, sent], [false, 'raw_tool_call', 0]);
});

test('weak memory does not bypass relevance because of request wording', () => {
  const weak = { id: 1, scoreBreakdown: { semantic: 0.2 } };
  for (const request of ['remember my dentist', 'Erinnerst du dich?', '解释我的设置']) {
    assert.deepEqual(filterRecalled([weak], decideMemoryRecall(request)), []);
  }
});

test('tool discovery falls back to words when embeddings fail or cover too little', async (t) => {
  const embeddings = require('../../../server/services/memory/embeddings');
  const { retrieveTools } = require('../../../server/services/ai/tool_retrieval');
  const tools = ['send_email: send an email to someone', 'read_file: read a file', 'web_search: search the web'].map((line) => {
    const [name, description] = line.split(': ');
    return { name, description, parameters: {} };
  });
  t.mock.method(embeddings, 'getEmbeddingWithMetadata', async () => null);
  const found = await retrieveTools(tools, 'please send an email to the whole team about the outage', {});
  assert.ok(found.some((tool) => tool.name === 'send_email'), JSON.stringify(found));
  // Short requests still get language-neutral discovery.
  assert.ok((await retrieveTools(tools, 'send email', {})).some((tool) => tool.name === 'send_email'));
});

// ---- commands

test('a path at the start of a message is a message', () => {
  const { parseCommand } = require('../../../server/services/commands/router');
  assert.equal(parseCommand('/tmp/project/orders.csv is broken', 'http'), null);
  assert.equal(parseCommand('/help', 'http').command, 'help');
});

test('the router address works with or without /v1', () => {
  const { NeoRouterProvider } = require('../../../server/services/ai/providers/neorouter');
  for (const baseUrl of ['https://r.example/', 'https://r.example', 'https://r.example/v1', 'https://r.example/v1/']) {
    assert.equal(new NeoRouterProvider({ apiKey: 'k', baseUrl }).connection.apiBase, 'https://r.example/v1');
  }
});

// ---- finding tools

test('older tool results shrink in batches, and asking again is not a repeat', () => {
  const { ageToolResults } = require('../../../server/services/ai/runtime/context/tool_result_aging');
  let compactions = 0;
  const session = {
    runId: 'r',
    engine: { getRunMeta: () => ({ repetitionGuard: { noteCompaction: () => { compactions += 1; } } }) },
    messages: Array.from({ length: 13 }, (_, index) => ({ role: 'tool', content: `${index} ${'x'.repeat(1000)}` })),
  };
  assert.equal(ageToolResults(session), false, 'nothing is touched below the threshold');
  session.messages.push({ role: 'tool', content: `13 ${'x'.repeat(1000)}` });
  assert.equal(ageToolResults(session), true);
  assert.ok(session.messages[0].content.length < 600);
  assert.match(session.messages[5].content, /older result shortened/);
  assert.equal(session.messages[6].content.length, 1000 + '6 '.length, 'recent results stay whole');
  assert.equal(compactions, 1);
  assert.equal(ageToolResults(session), false, 'the prefix stays stable until the next batch is due');
});

test('without an embedding match a longer request still finds tools by words', async () => {
  const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');
  const ctx = createTestRuntime();
  const keys = { GOOGLE_AI_KEY: process.env.GOOGLE_AI_KEY, OPENAI_API_KEY: process.env.OPENAI_API_KEY };
  delete process.env.GOOGLE_AI_KEY;
  delete process.env.OPENAI_API_KEY;
  try {
    const { retrieveTools } = require('../../../server/services/ai/tool_retrieval');
    const tools = [{ name: 'generate_image', description: 'Draw a picture from a prompt' }, { name: 'list_tasks', description: 'List scheduled tasks' }];
    assert.deepEqual((await retrieveTools(tools, 'please generate an image of a fox', {})).map((tool) => tool.name), ['generate_image']);
    assert.deepEqual(await retrieveTools(tools, 'draw', {}), [], 'too short to pay for retrieval');
  } finally {
    Object.assign(process.env, Object.fromEntries(Object.entries(keys).filter(([, value]) => value)));
    teardownTestRuntime(ctx);
  }
});

test('one embedding call serves everyone asking at the same moment', async () => {
  const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');
  const ctx = createTestRuntime();
  try {
    const { shareQueryEmbedding } = require('../../../server/services/memory/embeddings');
    let calls = 0;
    const start = () => {
      calls += 1;
      return new Promise((resolve) => setTimeout(() => resolve('vector'), 30));
    };
    const giving = new AbortController();
    const first = shareQueryEmbedding('k', start, giving.signal);
    const second = shareQueryEmbedding('k', start);
    giving.abort();
    await assert.rejects(first);
    assert.equal(await second, 'vector', 'one caller giving up does not cancel it for the other');
    assert.equal(calls, 1);
    assert.equal(await shareQueryEmbedding('k', start), 'vector');
    assert.equal(calls, 1, 'still reused moments later');
  } finally {
    teardownTestRuntime(ctx);
  }
});

test('coding tool selection uses retrieval rather than language-specific request phrases', () => {
  const all = BUILT_IN_DEFINITIONS;
  for (const request of ['Fix the login race condition.', 'Behebe den Fehler im Login.', '修复登录问题']) {
    const plain = selectToolCandidates(all, { request }).tools.map((tool) => tool.name);
    assert.ok(!plain.includes('edit_file'), request);
    const retrieved = selectToolCandidates(all, { request, retrieved: [{ name: 'search_files', similarity: 0.7 }] }).tools.map((tool) => tool.name);
    assert.ok(retrieved.includes('edit_file') && retrieved.includes('read_file'));
  }
});

test('tool search reads non-English words and takes matches by meaning', () => {
  const { searchTools } = require('../../../server/services/ai/toolSelector');
  const tools = [
    { name: 'wetter_abfrage', description: 'Prüft das Wetter für Öffnungszeiten' },
    { name: 'generate_image', description: 'Draw a picture' },
  ];
  assert.deepEqual(searchTools(tools, 'Öffnungszeiten').map((tool) => tool.name), ['wetter_abfrage']);
  assert.deepEqual(searchTools(tools, 'Bild malen').map((tool) => tool.name), []);
  assert.deepEqual(searchTools(tools, 'Bild malen', { alsoNames: ['generate_image'] }).map((tool) => tool.name), ['generate_image']);
});

test('retrieved tools only add what is missing, stay few, and are named as such', () => {
  const { selectToolCandidates } = require('../../../server/services/ai/toolSelector');
  const all = BUILT_IN_DEFINITIONS.map((definition) => ({ name: definition.name, description: definition.description }));
  const plain = selectToolCandidates(all, { request: 'hallo' });
  const { tools, candidates } = selectToolCandidates(all, {
    request: 'hallo',
    retrieved: [
      { name: 'web_search', similarity: 0.9 },
      { name: 'generate_image', similarity: 0.8 },
      { name: 'android_open_app', similarity: 0.7 },
      { name: 'list_tasks', similarity: 0.6 },
      { name: 'memory_forget', similarity: 0.5 },
      { name: 'no_such_tool', similarity: 0.4 },
    ],
  });
  assert.deepEqual(
    tools.map((tool) => tool.name).slice(0, plain.tools.length),
    plain.tools.map((tool) => tool.name),
    'the list stays in order, so the part a provider cached still matches',
  );
  const added = candidates.filter((candidate) => candidate.source === 'retrieved');
  assert.deepEqual(added.map((candidate) => candidate.name), ['generate_image', 'android_open_app', 'list_tasks']);
  assert.equal(added[0].similarity, 0.8);
});

test('without an embedding provider a run just goes without retrieval', async () => {
  const { createTestRuntime, teardownTestRuntime } = require('../../helpers/db');
  const ctx = createTestRuntime();
  const keys = { GOOGLE_AI_KEY: process.env.GOOGLE_AI_KEY, OPENAI_API_KEY: process.env.OPENAI_API_KEY };
  delete process.env.GOOGLE_AI_KEY;
  delete process.env.OPENAI_API_KEY;
  try {
    const { retrieveTools } = require('../../../server/services/ai/tool_retrieval');
    assert.deepEqual(await retrieveTools([{ name: 'x', description: 'y' }], 'hallo wie geht es dir', { provider: 'google' }), []);
    assert.deepEqual(await retrieveTools([{ name: 'x', description: 'y' }], '   ', {}), []);
  } finally {
    Object.assign(process.env, Object.fromEntries(Object.entries(keys).filter(([, value]) => value)));
    teardownTestRuntime(ctx);
  }
});

test('the selector finds a tool for at least as many requests as it did', () => {
  const { selectToolCandidates } = require('../../../server/services/ai/toolSelector');
  const { selectionCases } = require('../../harness_eval/selection_set');
  const all = BUILT_IN_DEFINITIONS.map((definition) => ({ name: definition.name, description: definition.description }));
  const found = selectionCases().filter((entry) => {
    const active = new Set(selectToolCandidates(all, { request: entry.request }).tools.map((tool) => tool.name));
    return entry.tools.some((name) => active.has(name));
  });
  // Without retrieval. Offline, so it says nothing about retrieval itself.
  assert.ok(found.length >= 34, `found ${found.length}`);
});

// ---- what a run reports about itself

test('a run\'s summary says what selection missed and what the guard got wrong', () => {
  const { summarizeRunEvents } = require('../../../server/services/ai/runtime/events/run_metrics');
  const event = (sequenceIndex, eventType, payload) => ({ sequenceIndex, eventType, payload: { timestamp: '2026-11-04T10:00:00.000Z', ...payload } });
  const metrics = summarizeRunEvents([
    event(1, 'context.built', { sections: { total_tokens: 8000, tool_schema_tokens: 4000, tool_catalog_tokens: 1000, history_tokens: 10 } }),
    event(2, 'tools.selected', { kind: 'initial', selection: {}, candidates: [{ name: 'read_file' }] }),
    event(3, 'tool.result', { tool: { name: 'read_file', call_fingerprint: 'a' } }),
    event(4, 'tool.suppressed', { tool: { name: 'read_file', call_fingerprint: 'a' } }),
    event(5, 'tool.result', { tool: { name: 'read_file', call_fingerprint: 'a' } }),
    event(6, 'tool.result', { tool: { name: 'activate_tools', call_fingerprint: 'c' } }),
    event(7, 'tool.result', { tool: { name: 'web_search', call_fingerprint: 'b' } }),
    event(8, 'delivery.failed', { purpose: 'final', ambiguous: true }),
  ]);
  assert.deepEqual(metrics.selection.missed_first_turn, ['web_search']);
  assert.equal(metrics.selection.tools_used, 2);
  assert.equal(metrics.tools.suppressed_then_ran, 1);
  assert.equal(metrics.delivery.ambiguous, 1);
  assert.equal(metrics.context.tool_tokens, 5000);

  const { diagnoseRun } = require('../../../server/services/ai/runtime/events/run_diagnostics');
  const codes = diagnoseRun(metrics).map((entry) => entry.code);
  for (const code of ['delivery_ambiguous', 'suppression_overruled', 'tool_not_on_first_turn', 'tools_fill_context']) {
    assert.ok(codes.includes(code), code);
  }
  assert.deepEqual(diagnoseRun({ duration_ms: 4000, latency: { model_ms: 3900 }, tools: {}, delivery: {} }), []);
  assert.deepEqual(diagnoseRun({ duration_ms: 20000, latency: { model_ms: 18000 }, tools: {}, delivery: {} }), [{ code: 'slow_model_loop', share: 0.9 }]);
  assert.deepEqual(diagnoseRun(null), []);
});

test('the delivery rules catch every way a message can go out twice', () => {
  const { deliveryViolations } = require('../../harness_eval/invariants');
  const row = (id, purpose, status, content, extra = {}) => ({
    id, run_id: 'r1', scope_id: 's1', recipient: 'c1', purpose, status, payload_json: JSON.stringify({ content }), ...extra,
  });
  const rules = (rows, options) => deliveryViolations(rows, options).map((entry) => entry.rule);

  assert.deepEqual(rules([row('a', 'final', 'delivered', 'Hi'), row('b', 'progress', 'delivered', 'Working')]), []);
  assert.deepEqual(rules([row('a', 'final', 'delivered', 'One'), row('b', 'final', 'delivered', 'Two')]), ['one_final_per_scope']);
  // A second recipient of the same run gets its own answer.
  assert.deepEqual(rules([row('a', 'final', 'delivered', 'One'), row('b', 'final', 'delivered', 'One', { recipient: 'c2' })]), []);
  assert.deepEqual(rules([row('a', 'final', 'ambiguous', 'Hi'), row('b', 'final', 'delivered', 'Hi  ')]), ['ambiguous_not_resent']);
  assert.deepEqual(rules([row('a', 'progress', 'delivered', 'Done'), row('b', 'final', 'delivered', 'Done')]), ['interim_is_not_final']);
  assert.deepEqual(
    rules([row('a', 'final', 'delivered', 'Hi', { run_id: 'r2', scope_id: 'r2' })], { resumedRuns: new Map([['r2', 'r1']]) }),
    ['resumed_run_keeps_scope'],
  );
});

// ---- progress updates

test('a messaging run\'s progress names its platform, and only the owner\'s chat gets it', () => {
  const { allowsProgressUpdates, progressDeliveryMetadata } = require('../../../server/services/ai/runtime/delivery/delivery_channel');
  assert.deepEqual(
    progressDeliveryMetadata('messaging', { source: 'telegram', chatId: '42' }),
    { platform: 'telegram', chatId: '42' },
  );
  assert.deepEqual(progressDeliveryMetadata('voice_live', { sessionBinding: { sessionId: 's1' } }), { sessionId: 's1' });
  assert.deepEqual(progressDeliveryMetadata('web', {}), {});

  assert.equal(allowsProgressUpdates('web', {}), true);
  assert.equal(allowsProgressUpdates('messaging', { audience: 'owner', memoryAudience: 'owner' }), true);
  assert.equal(allowsProgressUpdates('messaging', { audience: 'shared', memoryAudience: 'shared' }), false);
  assert.equal(allowsProgressUpdates('messaging', { audience: 'public' }), false);
  assert.equal(allowsProgressUpdates('messaging', { context: { socialIntelligence: { isGroup: true } } }), false);
});

// ---- prompt registry

test('prompt fragments are versioned, selected by context, and rendered with values', () => {
  const web = selectStableFragments({ triggerSource: 'web' }).map((fragment) => fragment.id);
  assert.ok(web.includes('base.behavior'));
  assert.equal(web.includes('capability.messaging'), false);
  const messaging = selectStableFragments({ triggerSource: 'messaging' }).map((fragment) => fragment.id);
  assert.ok(messaging.includes('capability.messaging'));
  const version = promptVersion(selectStableFragments({ triggerSource: 'web' }));
  assert.ok(version.fragments.includes('base.behavior@3'));
  assert.notEqual(version.digest, promptVersion(selectStableFragments({ triggerSource: 'messaging' })).digest);
  assert.match(renderFragment('runtime/wrap_up.md', { why: 'the sky fell' }), /because the sky fell/);
  assert.doesNotMatch(renderFragment('runtime/recovery.md', { reason: 'r', goal: 'g', actions: 'a', failures: '' }), /\{\{/);
});
