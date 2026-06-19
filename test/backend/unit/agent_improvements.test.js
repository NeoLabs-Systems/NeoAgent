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
const { buildAnalysisPrompt, buildExecutionGuidance } = require('../../../server/services/ai/taskAnalysis');
const {
  buildCompletionDecisionPrompt,
} = require('../../../server/services/ai/loop/completion_judge');
const { buildLoopPolicy } = require('../../../server/services/ai/loopPolicy');
const {
  resolveTaskTriggerArgs,
} = require('../../../server/services/ai/tools');

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

test('loop policy keeps the iteration ceiling high and relies on the read-only no-progress cap', () => {
  const standard = buildLoopPolicy({}, 'messaging', 'execute');
  const complex = buildLoopPolicy({}, 'messaging', 'plan_execute', {
    autonomyPolicy: { complexity: 'complex', autonomy_level: 'high' },
  });
  const clamped = buildLoopPolicy(
    { max_iterations: 1_000_000, max_consecutive_read_only_iterations: 999 },
    'messaging',
    'execute',
  );

  // The ceiling is a runaway safety net, not the primary stop signal.
  assert.equal(standard.maxIterations, 250);
  assert.equal(complex.maxIterations, 250);
  assert.equal(clamped.maxIterations, 400);
  // The real "stop when stuck" guard: consecutive read-only turns without progress.
  assert.equal(standard.maxConsecutiveReadOnlyIterations, 8);
  assert.equal(clamped.maxConsecutiveReadOnlyIterations, 25);
});

test('create_task accepts schedule config as object, JSON string, or bare cron', () => {
  // Canonical object shape.
  const obj = resolveTaskTriggerArgs({
    trigger: { type: 'schedule', config: { mode: 'recurring', cronExpression: '0 11 * * 1-5' } },
  });
  assert.equal(obj.triggerType, 'schedule');
  assert.equal(obj.triggerConfig.cronExpression, '0 11 * * 1-5');

  // JSON-stringified config with a "cron" alias key.
  const stringified = resolveTaskTriggerArgs({
    trigger_type: 'schedule',
    trigger_config: '{"cron": "0 11 * * 1-5"}',
  });
  assert.equal(stringified.triggerConfig.cronExpression, '0 11 * * 1-5');

  // Bare 5-field cron string passed directly as the config.
  const bareCron = resolveTaskTriggerArgs({
    trigger: { type: 'schedule', config: '0 11 * * 1-5' },
  });
  assert.equal(bareCron.triggerConfig.mode, 'recurring');
  assert.equal(bareCron.triggerConfig.cronExpression, '0 11 * * 1-5');

  // Bare ISO datetime string becomes a one_time run.
  const oneTime = resolveTaskTriggerArgs({
    trigger_type: 'schedule',
    trigger_config: '2026-07-01T09:00:00+02:00',
  });
  assert.equal(oneTime.triggerConfig.mode, 'one_time');
  assert.equal(oneTime.triggerConfig.runAt, '2026-07-01T09:00:00+02:00');
});

test('calendar summarizeEvent flags all-day vs timed events', () => {
  const { summarizeEvent } = require('../../../server/services/integrations/google/calendar');

  const allDay = summarizeEvent({
    id: 'a',
    summary: 'Handy Geburtstag',
    start: { date: '2018-06-17' },
    end: { date: '2018-06-18' },
  });
  assert.equal(allDay.allDay, true);
  assert.equal(allDay.start, '2018-06-17');

  const timed = summarizeEvent({
    id: 'b',
    summary: 'Standup',
    start: { dateTime: '2026-06-17T09:00:00+02:00' },
    end: { dateTime: '2026-06-17T09:15:00+02:00' },
  });
  assert.equal(timed.allDay, false);
  assert.equal(timed.start, '2026-06-17T09:00:00+02:00');
});

test('calendar summarizeListedEvents exposes timed events separately for reminder logic', () => {
  const { summarizeListedEvents } = require('../../../server/services/integrations/google/calendar');

  const result = summarizeListedEvents([
    {
      id: 'all-day',
      summary: 'Abreise Bali',
      start: { date: '2026-06-19' },
      end: { date: '2026-06-20' },
    },
    {
      id: 'timed',
      summary: 'Airport transfer',
      start: { dateTime: '2026-06-19T03:15:00+02:00' },
      end: { dateTime: '2026-06-19T03:45:00+02:00' },
    },
  ]);

  assert.equal(result.count, 2);
  assert.equal(result.timedCount, 1);
  assert.equal(result.allDayCount, 1);
  assert.equal(result.hasTimedEvents, true);
  assert.equal(result.hasOnlyAllDayEvents, false);
  assert.equal(result.nextTimedEvent?.id, 'timed');
  assert.deepEqual(result.timedEvents.map((event) => event.id), ['timed']);
  assert.deepEqual(result.allDayEvents.map((event) => event.id), ['all-day']);
  assert.deepEqual(result.events.map((event) => event.id), ['timed', 'all-day']);
});

test('task analysis keeps source checkouts in the shared workspace', () => {
  const prompt = buildExecutionGuidance({
    analysis: {
      mode: 'execute',
      goal: 'Implement the issue.',
      success_criteria: ['Changes are made locally.'],
      suggested_tools: ['execute_command', 'read_files'],
      complexity: 'standard',
      autonomy_level: 'high',
      progress_update_policy: 'required',
    },
  });

  assert.match(prompt, /shared workspace/);
  assert.match(prompt, /Prefer the highest-level available tool/);
  assert.match(prompt, /pass those directly/);
  assert.match(prompt, /prefer file tools/);
  assert.doesNotMatch(prompt, /git clone[^\n]+\/tmp\/repo-name/);
});

test('completion judge accepts truthful terminal no-op and blocker replies', () => {
  const prompt = buildCompletionDecisionPrompt({
    triggerSource: 'messaging',
    messagingSent: false,
    goalContext: {
      effectiveGoal: 'Delete gym tasks.',
      persistedGoalPrompt: '',
      effectiveComplexity: 'simple',
      effectiveAutonomyLevel: 'normal',
      effectiveProgressPolicy: 'optional',
      effectiveCompletionConfidence: 'medium',
      successCriteria: ['Gym tasks are removed or the user is told none exist.'],
    },
    parallelWork: false,
    tools: [
      { name: 'list_tasks' },
      { name: 'delete_task' },
      { name: 'task_complete' },
    ],
    toolExecutions: [
      {
        toolName: 'list_tasks',
        evidenceSource: 'tasks',
        ok: true,
        summary: 'No tasks matching gym were found.',
      },
    ],
    lastReply: 'I found no gym tasks to delete.',
    iteration: 4,
    maxIterations: 20,
  });

  assert.match(prompt, /already done/);
  assert.match(prompt, /no-op/);
  assert.match(prompt, /unavailable required capability/);
  assert.match(prompt, /Repeated read-only inspection/);
  assert.match(prompt, /No tasks matching gym were found/);
});

test('structured data parser handles quoted delimiters and newlines', () => {
  assert.deepEqual(parseDelimited('name,note\nNeo,\"one,two\"\nA,\"line 1\nline 2\"\n', ','), [
    { name: 'Neo', note: 'one,two' },
    { name: 'A', note: 'line 1\nline 2' },
  ]);
});
