'use strict';

const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let userId;
let runtime;

before(async () => {
  ctx = createTestRuntime();
  userId = (await createTestUser(ctx.db, { username: 'runtime_kernel_user' })).userId;
  const { RunEventBus } = require('../../../server/services/ai/runtime/events/run_event_bus');
  runtime = {
    stateMachine: require('../../../server/services/ai/runtime/run_state_machine'),
    leases: require('../../../server/services/ai/runtime/leases'),
    outbox: require('../../../server/services/ai/runtime/delivery/outbox_repository'),
    decisionEngine: require('../../../server/services/ai/runtime/decision_engine'),
    createProgressBroker: require('../../../server/services/ai/runtime/delivery/progress_broker').createProgressBroker,
    recoverOrphanedRuns: require('../../../server/services/ai/runtime/recovery_startup').recoverOrphanedRuns,
    createRunGuards: require('../../../server/services/ai/runtime/run_guards').createRunGuards,
    eventStore: require('../../../server/services/ai/runtime/events/run_event_store'),
    EVENT_TYPES: require('../../../server/services/ai/runtime/events/event_types').EVENT_TYPES,
    RunEventBus,
  };
});

after(() => teardownTestRuntime(ctx));

function insertRun(id, patch = {}) {
  ctx.db.prepare(
    `INSERT INTO agent_runs (
      id, user_id, title, status, runtime_state, version
    ) VALUES (?, ?, ?, ?, ?, ?)`,
  ).run(
    id,
    userId,
    id,
    patch.status || 'running',
    patch.runtimeState || 'accepted',
    patch.version || 0,
  );
}

test('state machine rejects illegal transitions and honors version CAS', () => {
  insertRun('sm-run');
  const first = runtime.stateMachine.transition({
    runId: 'sm-run',
    toState: 'executing',
    reason: 'start',
    workerId: 'w1',
  });
  assert.equal(first.ok, true);
  assert.equal(first.run.runtimeState, 'executing');
  assert.equal(first.run.version, 1);

  const illegal = runtime.stateMachine.transition({
    runId: 'sm-run',
    toState: 'completed',
    reason: 'skip',
    workerId: 'w1',
  });
  assert.equal(illegal.ok, false);
  assert.equal(illegal.reason, 'illegal_transition');

  const stale = runtime.stateMachine.transition({
    runId: 'sm-run',
    toState: 'delivering',
    reason: 'plan',
    expectedVersion: 0,
    workerId: 'w1',
  });
  assert.equal(stale.ok, false);
  assert.equal(stale.reason, 'version_conflict');
});

test('final delivery CAS allows exactly one commit', () => {
  insertRun('cas-run');
  runtime.stateMachine.transition({
    runId: 'cas-run',
    toState: 'executing',
    workerId: 'w1',
  });
  runtime.stateMachine.transition({
    runId: 'cas-run',
    toState: 'delivering',
    workerId: 'w1',
  });

  const first = runtime.stateMachine.claimFinalDelivery({
    runId: 'cas-run',
    deliveryId: 'del-1',
    workerId: 'w1',
  });
  assert.equal(first.ok, true);
  assert.equal(first.run.finalDeliveryId, 'del-1');

  const second = runtime.stateMachine.claimFinalDelivery({
    runId: 'cas-run',
    deliveryId: 'del-2',
    workerId: 'w1',
  });
  assert.equal(second.ok, false);
  assert.equal(second.reason, 'already_committed');
  assert.equal(runtime.outbox.countFinalDeliveries('cas-run'), 0);

  runtime.outbox.enqueue({
    runId: 'cas-run',
    channel: 'web',
    messageKind: 'final',
    payload: { content: 'done' },
    sequence: 1,
    idempotencyKey: 'cas-run:final:1',
  });
  // Mark one delivered and ensure property holds via count helper.
  const entries = runtime.outbox.listForRun('cas-run', { messageKind: 'final' });
  assert.equal(entries.length, 1);
  runtime.outbox.markDelivered(entries[0].id, { platformMessageId: 'local:1' });
  assert.equal(runtime.outbox.countFinalDeliveries('cas-run'), 1);
});

test('run leases are exclusive while live', () => {
  insertRun('lease-run');
  const a = runtime.leases.acquire('lease-run', { workerId: 'worker-a', leaseMs: 60_000 });
  assert.ok(a);
  const b = runtime.leases.acquire('lease-run', { workerId: 'worker-b', leaseMs: 60_000 });
  assert.equal(b, null);
  assert.equal(runtime.leases.heartbeat('lease-run', 'worker-a'), true);
  assert.equal(runtime.leases.release('lease-run', 'worker-a'), true);
  const c = runtime.leases.acquire('lease-run', { workerId: 'worker-b', leaseMs: 60_000 });
  assert.ok(c);
});

test('a model turn is work, the answer, or blank; prose never runs a tool', () => {
  const prose = runtime.decisionEngine.decisionFromModelResponse({
    content: 'call tool web_search with query=foo',
    tool_calls: [],
  });
  assert.equal(prose.kind, 'answer');

  const act = runtime.decisionEngine.decisionFromModelResponse({
    content: '',
    tool_calls: [{
      id: '1',
      function: { name: 'web_search', arguments: '{"query":"neoagent"}' },
    }],
  });
  assert.equal(act.kind, 'act');
  assert.equal(act.toolCalls[0].name, 'web_search');
  // Wire-format raw must survive re-normalization so the next provider turn
  // can read tool_calls[].function.name.
  assert.equal(act.toolCalls[0].raw.function.name, 'web_search');
  assert.equal(typeof act.toolCalls[0].raw.function.arguments, 'string');

  const blank = runtime.decisionEngine.decisionFromModelResponse({ content: '  ', tool_calls: [] });
  assert.equal(blank.kind, 'blank');
});

test('normalizeToolCalls is idempotent and keeps function wire shape', () => {
  const once = runtime.decisionEngine.normalizeToolCalls([{
    id: 'c1',
    type: 'function',
    function: { name: 'send_message', arguments: '{"purpose":"final_result"}' },
  }]);
  assert.equal(once.length, 1);
  assert.equal(once[0].name, 'send_message');
  assert.equal(once[0].raw.function.name, 'send_message');

  const twice = runtime.decisionEngine.normalizeToolCalls(once);
  assert.equal(twice.length, 1);
  assert.equal(twice[0].name, 'send_message');
  assert.equal(twice[0].raw.function.name, 'send_message');
  assert.equal(JSON.parse(twice[0].raw.function.arguments).purpose, 'final_result');
});

test('normalizeToolCalls keeps only a preview of unparseable arguments', () => {
  const junk = '{"content="' + '\n\t:\t""'.repeat(5000);
  const [call] = runtime.decisionEngine.normalizeToolCalls([{
    id: 'c1',
    type: 'function',
    function: { name: 'write_file', arguments: junk },
  }]);
  assert.equal(call.arguments._raw_length, junk.length);
  assert.equal(call.arguments._raw_preview.length, 400);
  assert.ok(call.arguments._parse_error);
  assert.ok(call.raw.function.arguments.length < 1000);
});

test('run guards stop a spinning run and never a productive one', () => {
  const productive = runtime.createRunGuards({ options: { maxIterations: 100 } });
  for (let turn = 0; turn < 40; turn += 1) {
    productive.recordModelTurn();
    productive.recordToolTurn({ progressed: true, allFailed: false });
  }
  assert.equal(productive.stopReason(), null);

  const idle = runtime.createRunGuards();
  for (let turn = 0; turn < 7; turn += 1) idle.recordToolTurn({ progressed: false, allFailed: false });
  assert.equal(idle.stopReason(), null);
  idle.recordToolTurn({ progressed: false, allFailed: false });
  assert.equal(idle.stopReason(), 'no_progress');

  const failing = runtime.createRunGuards();
  for (let turn = 0; turn < 5; turn += 1) failing.recordToolTurn({ progressed: false, allFailed: true });
  assert.equal(failing.stopReason(), 'tool_failures');

  const capped = runtime.createRunGuards({ options: { maxIterations: 2 } });
  capped.recordModelTurn();
  assert.equal(capped.stopReason(), null);
  capped.recordModelTurn();
  assert.equal(capped.stopReason(), 'turn_limit');
});

test('progress broker does not invent progress without deltas', async () => {
  insertRun('progress-run');
  let narratorCalls = 0;
  const broker = runtime.createProgressBroker({
    engine: { emit() {}, markRunVisibleProgress() {} },
    runId: 'progress-run',
    userId,
    narrator: async () => { narratorCalls += 1; return 'should never be asked'; },
    maxSilenceSeconds: 1,
    firstUpdateSeconds: 0,
    repeatUpdateSeconds: 0,
  });
  broker.markAccepted();
  const empty = await broker.maybePublish({
    delta: broker.buildDelta({}),
    force: true,
  });
  // No observed delta => the narrator is never even consulted, and there is no
  // canned status line to fall back to.
  assert.equal(empty.sent, false);
  assert.equal(empty.reason, 'no_real_delta');
  assert.equal(narratorCalls, 0);
});

test('progress broker publishes model-authored text and dedupes unchanged state', async () => {
  insertRun('progress-narrated');
  const sent = [];
  const broker = runtime.createProgressBroker({
    engine: {
      emit() {},
      markRunVisibleProgress() {},
    },
    runId: 'progress-narrated',
    userId,
    narrator: async ({ delta }) => `working on ${delta.currently_running.join(',')}`,
    firstUpdateSeconds: 0,
    repeatUpdateSeconds: 0,
  });
  broker.markAccepted();

  const first = await broker.maybePublish({
    delta: broker.buildDelta({ running: ['execute'], nextMilestone: 'finish' }),
  });
  assert.equal(first.sent, true);
  assert.equal(first.text, 'working on execute');
  sent.push(first.text);

  const repeat = await broker.maybePublish({
    delta: broker.buildDelta({ running: ['execute'], nextMilestone: 'finish' }),
  });
  assert.equal(repeat.sent, false);
  assert.equal(repeat.reason, 'unchanged');

  const moved = await broker.maybePublish({
    delta: broker.buildDelta({ running: ['verify'], nextMilestone: 'finish' }),
  });
  assert.equal(moved.sent, true);
  assert.equal(moved.text, 'working on verify');
});

test('progress broker permits a grounded repeat heartbeat for a still-running tool', async () => {
  insertRun('progress-tool-heartbeat');
  let narratorCalls = 0;
  const broker = runtime.createProgressBroker({
    engine: { emit() {}, markRunVisibleProgress() {} },
    runId: 'progress-tool-heartbeat',
    userId,
    narrator: async () => {
      narratorCalls += 1;
      return `tool heartbeat ${narratorCalls}`;
    },
    firstUpdateSeconds: 0,
    repeatUpdateSeconds: 0,
  });
  broker.markAccepted();
  broker.noteToolStarted('execute_command');
  const delta = broker.buildDelta({
    running: ['execute_command'],
    nextMilestone: 'command completes',
  });

  const first = await broker.maybePublish({ delta });
  const heartbeat = await broker.maybePublish({ delta });

  assert.equal(first.sent, true);
  assert.equal(heartbeat.sent, true);
  assert.equal(narratorCalls, 2);
});

test('progress broker stays silent once the run delivered or was suppressed', async () => {
  insertRun('progress-suppressed');
  let suppressed = false;
  const broker = runtime.createProgressBroker({
    engine: { emit() {}, markRunVisibleProgress() {} },
    runId: 'progress-suppressed',
    userId,
    narrator: async () => 'still working',
    isSuppressed: () => suppressed,
    firstUpdateSeconds: 0,
    repeatUpdateSeconds: 0,
  });
  broker.markAccepted();

  assert.equal(
    (await broker.maybePublish({ delta: broker.buildDelta({ running: ['execute'] }) })).sent,
    true,
  );
  suppressed = true;
  const afterFinal = await broker.maybePublish({
    delta: broker.buildDelta({ running: ['verify'] }),
  });
  assert.equal(afterFinal.sent, false);
  assert.equal(afterFinal.reason, 'suppressed');
});

test('a long-running tool is live, not stalled', async () => {
  insertRun('progress-liveness');
  const broker = runtime.createProgressBroker({
    engine: { emit() {} },
    runId: 'progress-liveness',
    userId,
    maxSilenceSeconds: 0,
  });
  broker.markAccepted();
  await new Promise((resolve) => { setTimeout(resolve, 5); });

  // Nothing happening for longer than the silence threshold.
  assert.equal(broker.evaluateLiveness().status, 'stalled');

  // A tool that is still executing is real work, however long it takes.
  broker.noteToolStarted('execute_command');
  const working = broker.evaluateLiveness();
  assert.equal(working.status, 'working');
  assert.equal(working.runningTools, 1);

  broker.noteToolFinished('execute_command');
  assert.equal(broker.evaluateLiveness().runningTools, 0);
});

test('crash recovery closes runs a dead process left non-terminal', () => {
  insertRun('orphan-run', { runtimeState: 'executing', status: 'running' });
  ctx.db.prepare(
    `UPDATE agent_runs SET lease_owner = ?, lease_expires_at = datetime('now', '-5 minutes'),
      heartbeat_at = datetime('now', '-5 minutes') WHERE id = ?`,
  ).run('worker_dead', 'orphan-run');
  insertRun('paused-run', { runtimeState: 'paused', status: 'paused' });

  const result = runtime.recoverOrphanedRuns();
  assert.ok(result.recovered.includes('orphan-run'));

  const orphan = ctx.db.prepare(
    'SELECT status, runtime_state, error, completed_at FROM agent_runs WHERE id = ?',
  ).get('orphan-run');
  assert.equal(orphan.status, 'failed');
  assert.equal(orphan.runtime_state, 'failed');
  assert.ok(orphan.error);
  assert.ok(orphan.completed_at);

  // A paused run is resumable by design and must survive a restart untouched.
  const paused = ctx.db.prepare(
    'SELECT status, runtime_state FROM agent_runs WHERE id = ?',
  ).get('paused-run');
  assert.equal(paused.runtime_state, 'paused');
});

test('event store sequences are monotonic per run', () => {
  insertRun('evt-run');
  const bus = new runtime.RunEventBus();
  const a = bus.publish({
    runId: 'evt-run',
    userId,
    eventType: runtime.EVENT_TYPES.RUN_ACCEPTED,
    payload: { n: 1 },
  });
  const b = bus.publish({
    runId: 'evt-run',
    userId,
    eventType: runtime.EVENT_TYPES.RUN_STATE_CHANGED,
    payload: { n: 2 },
  });
  assert.equal(a.sequenceIndex + 1, b.sequenceIndex);
  const listed = runtime.eventStore.listEvents('evt-run');
  assert.equal(listed.length >= 2, true);
  assert.ok(listed[0].sequenceIndex < listed[1].sequenceIndex);
});
