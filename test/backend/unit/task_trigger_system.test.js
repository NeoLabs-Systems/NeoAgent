'use strict';

const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { test } = require('node:test');

const adapters = require('../../../server/services/tasks/adapters');
const { EVENT_SOURCES, attachTriggerEventSources } = require('../../../server/services/tasks/trigger_events');
const { fetchTriggerRows, pollTriggerTask } = require('../../../server/services/tasks/trigger_polling');

const MINUTE = 60 * 1000;
const NOW = Date.parse('2026-10-07T10:00:00.000Z');

function toolManager(responses, calls = []) {
  return {
    async executeTool(_userId, toolName, args) {
      calls.push({ toolName, args });
      const response = responses[toolName];
      return typeof response === 'function' ? response(args) : response;
    },
  };
}

// Records checkpoints on the task the way the real runtime stores them.
function pollingRuntime(task, responses) {
  const fired = [];
  const checkpoints = [];
  return {
    fired,
    checkpoints,
    integrationManager: toolManager(responses),
    taskRepository: {
      markTaskTriggerCheckpoint(_taskId, fingerprint) {
        checkpoints.push(fingerprint);
        task.last_trigger_fingerprint = fingerprint;
      },
    },
    async fireTaskFromTrigger(_taskId, _userId, payload) {
      fired.push(payload);
      task.last_trigger_fingerprint = payload.fingerprint;
      return {};
    },
  };
}

let nextTaskId = 1000;
function polledTask(triggerType, config, checkpoint = '') {
  nextTaskId += 1;
  return {
    id: nextTaskId,
    user_id: null,
    agent_id: null,
    trigger_type: triggerType,
    trigger_config: JSON.stringify(config),
    last_trigger_fingerprint: checkpoint,
  };
}

test('every trigger adapter follows the contract', () => {
  const types = new Set();
  for (const adapter of adapters) {
    assert.ok(adapter.type && !types.has(adapter.type), `duplicate or missing type ${adapter.type}`);
    types.add(adapter.type);
    assert.ok(adapter.label, `${adapter.type} label`);
    assert.ok(adapter.configHint, `${adapter.type} configHint`);
    assert.equal(typeof adapter.validateConfig, 'function');
    assert.equal(typeof adapter.summarize, 'function');
    if (adapter.poll) {
      assert.ok(['list', 'ordered'].includes(adapter.poll.cursor), `${adapter.type} cursor`);
      if (adapter.poll.cursor === 'ordered') {
        assert.ok(['now', 'latest'].includes(adapter.poll.baseline), `${adapter.type} baseline`);
      }
      assert.equal(typeof adapter.poll.fetchRows, 'function');
    }
    if (adapter.event) {
      assert.ok(EVENT_SOURCES[adapter.event.source], `${adapter.type} event source`);
      assert.equal(typeof adapter.event.matches, 'function');
      assert.equal(typeof adapter.event.toPayload, 'function');
    }
  }
});

test('an ordered trigger starting now fires only what comes after its first poll', async () => {
  const runs = [
    { id: 1, updated_at: '2026-10-07T09:58:00Z', name: 'CI' },
    { id: 2, updated_at: '2026-10-07T10:03:00Z', name: 'CI' },
  ];
  const task = polledTask('github_workflow_run_failed', { connectionId: 1, repo: 'neo/agent' });
  const runtime = pollingRuntime(task, { github_list_workflow_runs: runs });

  await pollTriggerTask(runtime, task, { now: NOW });
  assert.equal(runtime.checkpoints[0], new Date(NOW).toISOString());
  assert.deepEqual(runtime.fired.map((row) => row.context.triggerEvent.runId), [2]);

  runs.push({ id: 3, updated_at: '2026-10-07T10:04:00Z', name: 'CI' });
  await pollTriggerTask(runtime, task, { now: NOW + 2 * MINUTE });
  assert.deepEqual(runtime.fired.map((row) => row.context.triggerEvent.runId), [2, 3]);
});

test('an ordered trigger starting from the latest item fires the first item of an empty folder', async () => {
  const files = [];
  const task = polledTask('nextcloud_file_added', { connectionId: 1, path: 'Inbox' });
  const runtime = pollingRuntime(task, { nextcloud_list_files: () => files });

  await pollTriggerTask(runtime, task, { now: NOW });
  assert.deepEqual(runtime.checkpoints, ['0']);
  assert.equal(runtime.fired.length, 0);

  files.push({ type: 'file', fileId: '42', path: 'Inbox/a.pdf', name: 'a.pdf' });
  await pollTriggerTask(runtime, task, { now: NOW + 5 * MINUTE });
  assert.deepEqual(runtime.fired.map((row) => row.context.triggerEvent.name), ['a.pdf']);
});

test('calendar reminders fire once per event at the configured lead time and skip all-day events', async () => {
  const calls = [];
  const events = [
    { id: 'standup', summary: 'Standup', start: '2026-10-07T10:10:00Z', allDay: false },
    { id: 'later', summary: 'Later', start: '2026-10-07T10:30:00Z', allDay: false },
    { id: 'holiday', summary: 'Holiday', start: '2026-10-07', allDay: true },
  ];
  const rows = await fetchTriggerRows({
    integrationManager: toolManager({ google_workspace_calendar_list_events: { upcomingTimedEvents: events } }, calls),
    userId: null,
    agentId: null,
    triggerType: 'google_calendar_event_starting',
    config: { connectionId: 1, minutesBefore: 10 },
    now: NOW,
  });

  assert.equal(calls[0].args.time_min, '2026-10-07T10:00:00.000Z');
  assert.equal(calls[0].args.time_max, '2026-10-07T10:11:00.000Z');
  assert.deepEqual(rows.map((row) => row.context.triggerEvent.title), ['Standup']);
  assert.equal(rows[0].fingerprint, '2026-10-07T10:00:00.000Z|standup');
});

test('a Home Assistant threshold fires when it is crossed, not on every reading above it', async () => {
  let reading = null;
  const task = polledTask('home_assistant_state_changed', {
    connectionId: 1,
    entityId: 'sensor.office',
    toState: '',
    above: 25,
    below: null,
  });
  const runtime = pollingRuntime(task, { home_assistant_get_state: () => reading });
  const readings = ['24', '26', '27', '23', '28'];
  for (const [minute, state] of readings.entries()) {
    reading = { entity_id: 'sensor.office', state, last_changed: new Date(NOW + minute * MINUTE).toISOString() };
    await pollTriggerTask(runtime, task, { now: NOW + minute * MINUTE });
  }

  assert.deepEqual(runtime.fired.map((row) => row.context.triggerEvent.state), ['26', '28']);
});

test('Google Sheets fires with the rows added since the last count', async () => {
  const values = [['Name'], ['Ada']];
  const task = polledTask('google_sheets_row_added', { connectionId: 1, spreadsheetId: 's', range: 'A:B' });
  const runtime = pollingRuntime(task, { google_workspace_sheets_get_values: () => ({ values }) });

  await pollTriggerTask(runtime, task, { now: NOW });
  assert.deepEqual(runtime.checkpoints, ['sheet_rows:000000002']);

  values.push(['Grace'], ['Linus']);
  await pollTriggerTask(runtime, task, { now: NOW + 5 * MINUTE });
  assert.deepEqual(runtime.fired[0].context.triggerEvent.rows, [['Grace'], ['Linus']]);
  assert.equal(runtime.fired[0].context.triggerEvent.firstRowNumber, 3);
});

test('a Trello card counts when created in or moved into the list, not when it leaves', async () => {
  const actions = [
    { id: 'a3', type: 'updateCard', date: '2026-10-07T10:03:00Z', data: { card: { name: 'Left' }, listBefore: { id: 'L1' }, listAfter: { id: 'L2' } } },
    { id: 'a2', type: 'updateCard', date: '2026-10-07T10:02:00Z', data: { card: { name: 'Moved' }, listBefore: { id: 'L0' }, listAfter: { id: 'L1' } } },
    { id: 'a1', type: 'createCard', date: '2026-10-07T10:01:00Z', data: { card: { name: 'Created' }, list: { id: 'L1' } } },
  ];
  const rows = await fetchTriggerRows({
    integrationManager: toolManager({ trello_list_actions: actions }),
    userId: null,
    agentId: null,
    triggerType: 'trello_card_entered_list',
    config: { connectionId: 1, listId: 'L1' },
  });
  assert.deepEqual(rows.map((row) => [row.context.triggerEvent.cardName, row.context.triggerEvent.how]), [
    ['Created', 'created'],
    ['Moved', 'moved'],
  ]);
});

function eventRuntime(tasks, sources = {}) {
  const fired = [];
  let running = 0;
  return {
    fired,
    stopping: false,
    events: new EventEmitter(),
    app: { locals: sources },
    taskRepository: {
      listEnabledEventTasks(userId, agentId, triggerType) {
        return tasks.filter((task) => task.user_id === userId
          && (agentId === null || task.agent_id === agentId)
          && task.trigger_type === triggerType);
      },
    },
    async fireTaskFromTrigger(taskId, _userId, payload) {
      running += 1;
      assert.equal(running, 1, 'one event at a time per task');
      await new Promise((resolve) => setImmediate(resolve));
      fired.push({ taskId, payload });
      running -= 1;
      return {};
    },
  };
}

const settle = () => new Promise((resolve) => setTimeout(resolve, 20));

test('member joins fire the tasks watching that platform and server, one at a time', async () => {
  const messagingManager = new EventEmitter();
  const tasks = [
    { id: 1, user_id: 1, agent_id: 'main', trigger_type: 'messaging_member_joined', trigger_config: JSON.stringify({ platform: 'discord', spaceId: 'G1' }) },
    { id: 2, user_id: 1, agent_id: 'main', trigger_type: 'messaging_member_joined', trigger_config: JSON.stringify({ platform: 'discord', spaceId: 'G2' }) },
    { id: 3, user_id: 1, agent_id: 'main', trigger_type: 'messaging_member_joined', trigger_config: JSON.stringify({ platform: 'telegram', spaceId: '' }) },
  ];
  const runtime = eventRuntime(tasks, { messagingManager });
  const cleanups = attachTriggerEventSources(runtime);
  const join = (memberId) => messagingManager.emit('member_joined', {
    userId: 1,
    agentId: 'main',
    platform: 'discord',
    spaceId: 'G1',
    memberId,
    memberName: `User ${memberId}`,
    dmChatId: `dm_${memberId}`,
    occurredAt: '2026-10-07T10:00:00.000Z',
  });
  join('42');
  join('43');
  await settle();

  assert.deepEqual(runtime.fired.map((entry) => entry.taskId), [1, 1]);
  assert.equal(runtime.fired[1].payload.context.triggerEvent.dmChatId, 'dm_43');
  for (const cleanup of cleanups) cleanup();
  assert.equal(messagingManager.listenerCount('member_joined'), 0);
});

test('a finished task triggers the tasks chained to it until the chain is too deep', async () => {
  const tasks = [
    { id: 7, user_id: 1, agent_id: 'main', trigger_type: 'task_run_finished', trigger_config: JSON.stringify({ sourceTaskId: 5, outcome: 'failed' }) },
  ];
  const runtime = eventRuntime(tasks);
  attachTriggerEventSources(runtime);
  const finish = (outcome, chainDepth) => runtime.events.emit('task_run_finished', {
    userId: 1,
    agentId: 'main',
    taskId: 5,
    taskName: 'Backup',
    outcome,
    error: outcome === 'failed' ? 'disk full' : null,
    chainDepth,
    runId: `run-${outcome}-${chainDepth}`,
    finishedAt: '2026-10-07T10:00:00.000Z',
  });
  finish('succeeded', 1);
  finish('failed', 1);
  finish('failed', 4);
  await settle();

  assert.deepEqual(runtime.fired.map((entry) => entry.payload.context.triggerEvent.error), ['disk full']);
});

test('a task cannot be chained to itself', async () => {
  const chained = adapters.find((adapter) => adapter.type === 'task_run_finished');
  await assert.rejects(chained.validateConfig({ sourceTaskId: 7 }, { taskId: 7 }), /own runs/);
});

test('health syncs fire on the newest matching sample', async () => {
  const tasks = [
    { id: 9, user_id: 1, agent_id: 'main', trigger_type: 'health_metric_recorded', trigger_config: JSON.stringify({ metricType: 'heart_rate', above: 100, below: null }) },
  ];
  const runtime = eventRuntime(tasks);
  attachTriggerEventSources(runtime);
  runtime.events.emit('health_sync', {
    userId: 1,
    syncedAt: '2026-10-07T10:00:00.000Z',
    records: [
      { metricType: 'HeartRate', recordId: 'a', numericValue: 110, recordedAt: '2026-10-07T09:00:00Z' },
      { metricType: 'heart_rate', recordId: 'b', numericValue: 120, recordedAt: '2026-10-07T09:30:00Z' },
      { metricType: 'heart_rate', recordId: 'c', numericValue: 80, recordedAt: '2026-10-07T09:45:00Z' },
    ],
  });
  await settle();

  assert.equal(runtime.fired.length, 1);
  assert.equal(runtime.fired[0].payload.context.triggerEvent.value, 120);
  assert.equal(runtime.fired[0].payload.context.triggerEvent.matchingSamples, 2);
});

test('Gmail reads the raw API response and Outlook uses the fixed list tool', async () => {
  const gmail = await fetchTriggerRows({
    integrationManager: toolManager({
      google_workspace_gmail_api_request: { status: 200, data: { messages: [{ id: '18b', threadId: 't1' }] } },
    }),
    userId: null,
    agentId: null,
    triggerType: 'gmail_message_received',
    config: { connectionId: 1 },
  });
  assert.deepEqual(gmail.map((row) => row.context.triggerEvent.messageId), ['18b']);

  const calls = [];
  const outlook = await fetchTriggerRows({
    integrationManager: toolManager({
      microsoft_365_outlook_list_messages: {
        value: [
          { id: 'm1', isRead: true, receivedDateTime: '2026-10-07T09:00:00Z' },
          { id: 'm2', isRead: false, receivedDateTime: '2026-10-07T09:05:00Z' },
        ],
      },
    }, calls),
    userId: null,
    agentId: null,
    triggerType: 'outlook_email_received',
    config: { connectionId: 1, unreadOnly: true },
  });
  assert.equal(calls[0].toolName, 'microsoft_365_outlook_list_messages');
  assert.deepEqual(outlook.map((row) => row.context.triggerEvent.messageId), ['m2']);
});
