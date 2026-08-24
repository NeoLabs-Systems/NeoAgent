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
  ALWAYS_INCLUDE_BUILT_INS,
  CORE_FILE_TOOLS,
  MAX_TOOLS,
  activateTools,
  buildToolDiscoverySummary,
  searchTools,
  selectInitialTools,
} = require('../../../server/services/ai/toolSelector');
const { buildExecutionGuidance } = require('../../../server/services/ai/taskAnalysis');
const {
  buildCompletionDecisionPrompt,
} = require('../../../server/services/ai/loop/completion_judge');
const { buildLoopPolicy } = require('../../../server/services/ai/loopPolicy');
const {
  resolveTaskTriggerArgs,
} = require('../../../server/services/ai/tools');
const { compactToolResult } = require('../../../server/services/ai/toolResult');
const { classifyToolExecution, gatheredNewEvidence } = require('../../../server/services/ai/toolEvidence');

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

test('tool activation replaces unrelated schemas while preserving control tools', () => {
  const required = [
    'task_complete',
    'search_tools',
    'activate_tools',
    'think',
    'send_message',
    'send_interim_update',
    'call_user',
  ];
  const tools = [
    ...required.map((name) => ({ name, description: `${name} description` })),
    ...Array.from({ length: 40 }, (_, index) => ({
      name: `tool_${index}`,
      description: `Capability ${index}`,
    })),
  ];
  const initial = selectInitialTools(tools, tools.slice(5, 20).map((tool) => tool.name));
  assert.equal(initial.length, MAX_TOOLS);
  const result = activateTools(initial, tools, ['tool_39']);
  assert.equal(result.tools.length, MAX_TOOLS);
  assert.equal(result.tools.some((tool) => tool.name === 'tool_39'), true);
  assert.deepEqual(result.unknown, []);
  assert.equal(result.evicted.length, 1);
});

test('tool discovery stays compact and searches inactive capabilities generically', () => {
  const tools = [
    { name: 'search_tools', description: 'Search tools.' },
    { name: 'activate_tools', description: 'Activate tools.' },
    { name: 'google_workspace_calendar_list_events', description: 'List Google Calendar events in a time window.' },
    { name: 'github_create_issue', description: 'Create a GitHub issue.' },
  ];
  const active = tools.slice(0, 2);
  const summary = buildToolDiscoverySummary(tools, active);
  assert.match(summary, /Discoverable tools: 4/);
  assert.doesNotMatch(summary, /google_workspace_calendar_list_events/);

  const matches = searchTools(tools, 'task calendar events', {
    activeNames: active.map((tool) => tool.name),
    excludeNames: ALWAYS_INCLUDE_BUILT_INS,
  });
  assert.equal(matches[0].name, 'google_workspace_calendar_list_events');
  assert.equal(matches.some((tool) => ALWAYS_INCLUDE_BUILT_INS.includes(tool.name)), false);
  assert.equal(matches[0].active, false);
  assert.match(matches[0].description, /Google Calendar/);
});

test('execute runs start with core file tools but direct runs stay lean', () => {
  const required = [
    'task_complete',
    'search_tools',
    'activate_tools',
    'think',
    'send_message',
    'send_interim_update',
    'call_user',
  ];
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
  assert.equal(directInitial.some((tool) => tool.name === 'call_user'), true);
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

test('loop policy supports bounded agent settings and per-run overrides', () => {
  const configured = buildLoopPolicy({
    max_iterations: 320,
    max_consecutive_read_only_iterations: 14,
    max_consecutive_tool_failures: 12,
    max_model_failure_recoveries: 7,
    compaction_threshold: 0.72,
  });
  assert.equal(configured.maxIterations, 320);
  assert.equal(configured.maxConsecutiveReadOnlyIterations, 14);
  assert.equal(configured.maxConsecutiveToolFailures, 12);
  assert.equal(configured.maxModelFailureRecoveries, 7);
  assert.equal(configured.compactionThreshold, 0.72);

  const overridden = buildLoopPolicy(configured, 'messaging', 'execute', {
    maxIterations: 350,
    maxConsecutiveReadOnlyIterations: 18,
    maxConsecutiveToolFailures: 16,
    maxModelFailureRecoveries: 9,
    compactionThreshold: 0.9,
  });
  assert.equal(overridden.maxIterations, 350);
  assert.equal(overridden.maxConsecutiveReadOnlyIterations, 18);
  assert.equal(overridden.maxConsecutiveToolFailures, 16);
  assert.equal(overridden.maxModelFailureRecoveries, 9);
  assert.equal(overridden.compactionThreshold, 0.9);
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

test('execution guidance keeps source checkouts in the shared workspace', () => {
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

test('calendar compaction surfaces every event instead of truncating the array', () => {
  // A realistic flood: one stale verbose timed event followed by many all-day
  // markers. The generic JSON path would clamp this and drop the events; the
  // dedicated digest must keep them all so the model never re-queries blindly.
  const events = [
    {
      id: 'stale', status: 'confirmed', summary: 'Abreise Bali', allDay: false,
      start: '2018-09-01T10:00:00+02:00', end: '2018-09-01T12:00:00+02:00',
      description: 'x'.repeat(4000), htmlLink: 'https://calendar.google.com/'.padEnd(300, 'y'),
      attendees: ['a@example.com', 'b@example.com'],
    },
    {
      id: 'real', status: 'confirmed', summary: 'Zahnarzt Termin', allDay: false,
      start: '2026-06-22T14:30:00+02:00', end: '2026-06-22T15:00:00+02:00',
      location: 'Praxis Dr. Müller',
    },
    ...Array.from({ length: 9 }, (_, i) => ({
      id: `ad${i}`, status: 'confirmed', summary: `Geburtstag Person ${i}`, allDay: true,
      start: '2026-06-22', end: '2026-06-23',
    })),
  ];
  const result = {
    count: events.length, timedCount: 2, allDayCount: 9,
    hasTimedEvents: true, hasOnlyAllDayEvents: false,
    nextTimedEvent: events[0], timedEvents: events.slice(0, 2), allDayEvents: events.slice(2), events,
  };
  const compact = compactToolResult('google_workspace_calendar_list_events', {}, result, {
    softLimit: 2400, hardLimit: 4800,
  });
  const parsed = JSON.parse(compact);
  assert.equal(parsed.timed.length, 2, 'all timed events survive compaction');
  assert.equal(parsed.allDay.length, 9, 'all all-day events survive compaction');
  assert.ok(parsed.timed.some((e) => e.summary === 'Zahnarzt Termin'), 'the real upcoming event is visible');
  assert.ok(!compact.includes('xxxx'), 'verbose description noise is dropped');
  assert.ok(compact.length <= 4800, 'digest stays within the hard budget');
});

test('truncated workspace results explain how to recover omitted evidence', () => {
  const file = JSON.parse(compactToolResult('read_file', { path: 'large.js' }, {
    content: `${'x'.repeat(900)}\n...[truncated, 3000 chars total]`,
  }, { softLimit: 600, hardLimit: 1000 }));
  assert.equal(file.truncated, true);
  assert.match(file.note, /narrower line range/);

  const compactedPreview = JSON.parse(compactToolResult('read_file', { path: 'many-lines.js' }, {
    content: Array.from({ length: 30 }, (_, index) => `line ${index + 1}`).join('\n'),
  }, { softLimit: 900, hardLimit: 1400 }));
  assert.equal(compactedPreview.truncated, true);
  assert.match(compactedPreview.note, /narrower line range/);

  const search = JSON.parse(compactToolResult('search_files', { pattern: 'handler' }, {
    count: 9,
    matches: Array.from({ length: 9 }, (_, index) => ({
      file: `file-${index}.js`, line: index + 1, content: 'handler',
    })),
  }, { softLimit: 900, hardLimit: 1400 }));
  assert.equal(search.truncated, true);
  assert.equal(search.matches.length, 6);
  assert.match(search.note, /Narrow the path or search pattern/);
});

test('new-evidence reads count as progress but churn does not', () => {
  const freshSearch = classifyToolExecution('web_search', { query: 'cafeteria menu' }, {
    results: [{ title: 'Menu', url: 'https://example.com' }],
  });
  assert.equal(gatheredNewEvidence(freshSearch, { unchangedCount: 1 }), true);

  // Re-running the same call to an unchanged result is churn, not progress.
  assert.equal(gatheredNewEvidence(freshSearch, { unchangedCount: 2 }), false);

  // A failed read is not progress.
  const failedRead = classifyToolExecution('read_file', { path: '/missing' }, { error: 'not found' });
  assert.equal(gatheredNewEvidence(failedRead, { unchangedCount: 1 }), false);

  // Pure thinking gathers no evidence.
  const thought = classifyToolExecution('think', { thought: 'hmm' }, { thought: 'hmm' });
  assert.equal(gatheredNewEvidence(thought, { unchangedCount: 1 }), false);
});
