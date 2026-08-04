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
  runtime = require('../../../server/services/ai/runtime');
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
    toState: 'triaging',
    reason: 'start',
    workerId: 'w1',
  });
  assert.equal(first.ok, true);
  assert.equal(first.run.runtimeState, 'triaging');
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
    toState: 'planning',
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
    toState: 'triaging',
    workerId: 'w1',
  });
  runtime.stateMachine.transition({
    runId: 'cas-run',
    toState: 'responding',
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

test('fast-path gate blocks research and open obligations', () => {
  const chat = runtime.taskContract.contractFromAnalysis({
    mode: 'direct_answer',
    goal: 'Say hello',
    draft_reply: 'Hello!',
    draft_status: 'final',
    confidence: 0.95,
    research_depth: 'none',
    needs_verification: false,
    complexity: 'simple',
  }, 'hello');
  const ok = runtime.taskContract.evaluateFastPathEligibility(chat, {
    draftReply: 'Hello!',
    analysis: {
      mode: 'direct_answer',
      draft_status: 'final',
      draft_reply: 'Hello!',
    },
  });
  assert.equal(ok.eligible, true);

  const research = runtime.taskContract.contractFromAnalysis({
    mode: 'execute',
    goal: 'Research NeoAgent runtime',
    draft_status: 'needs_execution',
    research_depth: 'deep',
    research_targets: ['NeoAgent'],
    needs_verification: true,
    confidence: 0.8,
  }, 'research neoagent');
  const blocked = runtime.taskContract.evaluateFastPathEligibility(research, {
    draftReply: 'I will look into it',
    analysis: {
      mode: 'execute',
      draft_status: 'needs_execution',
    },
  });
  assert.equal(blocked.eligible, false);
  assert.ok(blocked.reasons.length > 0);
});

test('completion gate rejects open required work nodes', () => {
  insertRun('gate-run');
  runtime.workGraph.createGraph('gate-run', [
    {
      id: 'execute',
      kind: 'execute',
      objective: 'Do the work',
      success_criteria: ['done'],
      dependencies: [],
    },
    {
      id: 'verify',
      kind: 'verification',
      objective: 'Verify',
      dependencies: ['execute'],
    },
  ]);
  const contract = runtime.taskContract.normalizeContract({
    goal: 'Do the work',
    intent: 'execute',
    deliverables: [{ id: 'result', type: 'task_result', required: true }],
    open_obligations: [{ id: 'execution', type: 'execution', required: true }],
    evidence_requirements: [],
    verification_required: true,
  });
  const rejected = runtime.evaluateCompletionClaim({
    runId: 'gate-run',
    contract,
    claim: { summary: 'done', confidence: 0.9 },
    finalContent: 'done',
    path: 'durable',
  });
  assert.equal(rejected.accepted, false);
  assert.ok(rejected.failures.some((f) => f.code === 'open_work_node' || f.code === 'open_obligation'));

  const nodes = runtime.workGraph.listNodes('gate-run');
  const execute = nodes.find((n) => n.nodeKey === 'execute');
  runtime.workGraph.completeNode(execute.id, { evidence: [{ summary: 'ok' }] });
  runtime.workGraph.completeNode(nodes.find((n) => n.nodeKey === 'verify').id, {
    evidence: [{ summary: 'verified' }],
  });
  const accepted = runtime.evaluateCompletionClaim({
    runId: 'gate-run',
    contract: {
      ...contract,
      open_obligations: [],
      deliverables: [{ id: 'reply', type: 'text', required: true }],
    },
    claim: { summary: 'done', confidence: 0.9, completed_node_ids: ['execute', 'verify'] },
    finalContent: 'done',
    path: 'durable',
  });
  assert.equal(accepted.accepted, true);
});

test('typed decisions reject prose tool syntax without executable calls', () => {
  const invalid = runtime.decisionEngine.decisionFromModelResponse({
    content: 'call tool web_search with query=foo',
    tool_calls: [],
  });
  assert.equal(invalid.ok, true);
  assert.equal(invalid.decision.kind, 'respond');

  const act = runtime.decisionEngine.decisionFromModelResponse({
    content: '',
    tool_calls: [{
      id: '1',
      function: { name: 'web_search', arguments: '{"query":"neoagent"}' },
    }],
  });
  assert.equal(act.ok, true);
  assert.equal(act.decision.kind, 'act');
  assert.equal(act.decision.toolCalls[0].name, 'web_search');

  const complete = runtime.decisionEngine.decisionFromModelResponse({
    content: '',
    tool_calls: [{
      id: '2',
      function: { name: 'task_complete', arguments: '{"summary":"All done","confidence":0.9}' },
    }],
  });
  assert.equal(complete.ok, true);
  assert.equal(complete.decision.kind, 'complete');
});

test('budget manager hard-stops on model turn ceiling', () => {
  const budget = runtime.createBudgetManager({
    options: { maxIterations: 2 },
    analysisMode: 'execute',
  });
  budget.recordModelTurn();
  budget.recordModelTurn();
  const decision = budget.shouldContinue({
    openObligations: [{ id: 'x' }],
    hasNextAction: true,
    progressDelta: true,
  });
  assert.equal(decision.continue, false);
  assert.equal(decision.reason, 'hard_budget');
});

test('verification reopens nodes instead of terminal failure', async () => {
  insertRun('verify-run');
  runtime.workGraph.createGraph('verify-run', [
    {
      id: 'execute',
      kind: 'execute',
      objective: 'Implement',
      dependencies: [],
    },
  ]);
  const execute = runtime.workGraph.listNodes('verify-run')[0];
  runtime.workGraph.completeNode(execute.id, { evidence: [{ summary: 'patch' }] });

  const result = await runtime.verifyRun({
    runId: 'verify-run',
    contract: {
      goal: 'Implement',
      open_obligations: [{ id: 'execute', type: 'execution', required: true }],
      deliverables: [{ id: 'code', type: 'repository_patch', required: true }],
      evidence_requirements: ['tests passed'],
      verification_required: true,
    },
    claim: { summary: 'done', confidence: 0.9 },
    finalContent: 'done',
    path: 'durable',
    evidence: [],
    artifacts: [],
  });
  assert.equal(result.status, 'repair_required');
  assert.ok((result.defects || []).length > 0);
  const reopened = runtime.workGraph.listNodes('verify-run');
  assert.ok(
    reopened.some((n) => n.status === 'reopened' || n.status === 'ready' || n.status === 'pending'),
    `expected a reopened node, got ${reopened.map((n) => `${n.nodeKey}:${n.status}`).join(',')}`,
  );
});

test('memory write pipeline deduplicates exact candidates', () => {
  const first = runtime.memoryWritePipeline.enqueueCandidate({
    userId,
    agentId: null,
    runId: null,
    writeClass: 'semantic',
    candidate: {
      subject: 'User',
      predicate: 'prefers',
      object: 'concise updates',
      sourceEventId: 'evt-1',
    },
  });
  assert.equal(first.ok, true);
  assert.ok(first.id);

  const second = runtime.memoryWritePipeline.enqueueCandidate({
    userId,
    agentId: null,
    runId: null,
    writeClass: 'semantic',
    candidate: {
      subject: 'User',
      predicate: 'prefers',
      object: 'concise updates',
      sourceEventId: 'evt-1',
    },
  });
  assert.equal(second.ok, true);
  assert.equal(second.duplicate, true);
  assert.equal(second.id, first.id);
});

test('progress broker does not invent progress without deltas', async () => {
  insertRun('progress-run');
  const broker = runtime.createProgressBroker({
    engine: { emit() {}, markRunVisibleProgress() {} },
    runId: 'progress-run',
    userId,
    maxSilenceSeconds: 1,
    firstUpdateSeconds: 0,
    repeatUpdateSeconds: 0,
  });
  broker.markAccepted();
  const empty = await broker.maybePublish({
    delta: broker.buildDelta({}),
    force: true,
  });
  // No completed/running/blocker content => no fabricated milestone text except stall path.
  assert.equal(empty.sent, false);
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
