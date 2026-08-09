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

test('command artifact references survive working-memory and node completion', () => {
  insertRun('artifact-node-run');
  runtime.workGraph.createGraph('artifact-node-run', [{
    id: 'execute',
    kind: 'execute',
    objective: 'Run verification command',
    dependencies: [],
  }]);
  const memory = runtime.createWorkingMemory();
  memory.addArtifact({ artifactId: 'command-artifact', kind: 'command-output' });
  memory.addArtifact({ artifactId: 'command-artifact', kind: 'command-output' });
  assert.deepEqual(memory.snapshot().artifacts, [{
    artifactId: 'command-artifact',
    kind: 'command-output',
  }]);

  const node = runtime.workGraph.listNodes('artifact-node-run')[0];
  runtime.workGraph.updateNode(node.id, { artifactIds: ['command-artifact'] });
  runtime.workGraph.completeNode(node.id, { evidence: [{ summary: 'Command finished' }] });
  assert.deepEqual(runtime.workGraph.listNodes('artifact-node-run')[0].artifactIds, [
    'command-artifact',
  ]);
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
  // Wire-format raw must survive validateDecision re-normalization so the next
  // provider turn can read tool_calls[].function.name.
  assert.equal(act.decision.toolCalls[0].raw.function.name, 'web_search');
  assert.equal(typeof act.decision.toolCalls[0].raw.function.arguments, 'string');

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

test('task_complete message alias and high confidence labels normalize', () => {
  const complete = runtime.decisionEngine.decisionFromModelResponse({
    content: '',
    tool_calls: [{
      id: '2',
      function: {
        name: 'task_complete',
        arguments: JSON.stringify({ message: 'Done via message field', confidence: 'high' }),
      },
    }],
  });
  assert.equal(complete.ok, true);
  assert.equal(complete.decision.kind, 'complete');
  assert.equal(complete.decision.completionClaim.summary, 'Done via message field');
  assert.equal(complete.decision.completionClaim.confidence, 0.9);
});

test('task_result deliverable is satisfied by final text content', () => {
  const contract = runtime.taskContract.normalizeContract({
    goal: 'Morning recap',
    intent: 'execute',
    deliverables: [{ id: 'result', type: 'task_result', required: true }],
    open_obligations: [
      { id: 'execution', type: 'execution', required: true },
      { id: 'verification', type: 'verification', required: true },
    ],
    evidence_requirements: [],
  });
  const openWithoutContent = runtime.taskContract.evaluateOpenObligations(contract, {
    completedNodeKeys: ['execute'],
    evidence: [{ summary: 'looked up calendar', success: true }],
    finalContent: '',
  });
  assert.ok(openWithoutContent.open.some((o) => o.type === 'deliverable'));

  const openWithContent = runtime.taskContract.evaluateOpenObligations(contract, {
    completedNodeKeys: ['execute'],
    evidence: [{ summary: 'looked up calendar', success: true }],
    finalContent: 'No meetings today.',
  });
  assert.equal(openWithContent.satisfied, true);
  assert.equal(openWithContent.open.length, 0);
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

test('unchanged failed semantic verification is reused until evidence changes', async () => {
  insertRun('verify-fingerprint-run');
  runtime.workGraph.createGraph('verify-fingerprint-run', [{
    id: 'verify',
    kind: 'verification',
    objective: 'Verify the response',
    dependencies: [],
  }]);
  const base = {
    runId: 'verify-fingerprint-run',
    contract: {
      version: 3,
      goal: 'Answer with evidence',
      open_obligations: [],
      deliverables: [{ id: 'reply', type: 'text', required: true }],
      evidence_requirements: [],
      verification_required: true,
    },
    contractVersion: 3,
    claim: { summary: 'Answer', confidence: 0.9 },
    finalContent: 'Answer',
    path: 'durable',
    evidence: [
      { id: 'e1', summary: 'Observed A', success: true },
      { id: 'e-order', summary: 'Observed ordering marker', success: true },
    ],
    artifacts: [],
    sideEffects: [{ id: 's1', status: 'confirmed' }],
  };
  let calls = 0;
  const semanticVerifier = async () => {
    calls += 1;
    return {
      status: 'needs_revision',
      defects: [{ severity: 'major', criterion: 'proof', evidence: 'Need stronger proof' }],
      reopen_nodes: [],
    };
  };

  const first = await runtime.verifyRun({ ...base, semanticVerifier });
  assert.equal(first.status, 'repair_required');
  assert.equal(calls, 1);

  const unchanged = await runtime.verifyRun({
    ...base,
    evidence: [...base.evidence].reverse(),
    semanticVerifier,
    previousSemanticFailure: first.semanticFailure,
  });
  assert.equal(unchanged.unchanged, true);
  assert.deepEqual(unchanged.defects, first.defects);
  assert.equal(calls, 1);

  const changedEvidence = await runtime.verifyRun({
    ...base,
    evidence: [...base.evidence, { id: 'e2', summary: 'Observed B', success: true }],
    semanticVerifier,
    previousSemanticFailure: unchanged.semanticFailure,
  });
  assert.equal(calls, 2);

  const changedArtifact = await runtime.verifyRun({
    ...base,
    evidence: [...base.evidence, { id: 'e2', summary: 'Observed B', success: true }],
    artifacts: [{ artifactId: 'artifact-1', complete: true }],
    semanticVerifier,
    previousSemanticFailure: changedEvidence.semanticFailure,
  });
  assert.equal(calls, 3);

  const changedSideEffect = await runtime.verifyRun({
    ...base,
    evidence: [...base.evidence, { id: 'e2', summary: 'Observed B', success: true }],
    artifacts: [{ artifactId: 'artifact-1', complete: true }],
    sideEffects: [{ id: 's1', status: 'failed' }],
    semanticVerifier,
    previousSemanticFailure: changedArtifact.semanticFailure,
  });
  assert.equal(calls, 4);

  const changedFinal = await runtime.verifyRun({
    ...base,
    claim: { summary: 'Revised answer', confidence: 0.9 },
    finalContent: 'Revised answer',
    evidence: [...base.evidence, { id: 'e2', summary: 'Observed B', success: true }],
    artifacts: [{ artifactId: 'artifact-1', complete: true }],
    sideEffects: [{ id: 's1', status: 'failed' }],
    semanticVerifier,
    previousSemanticFailure: changedSideEffect.semanticFailure,
  });
  assert.equal(calls, 5);

  const verifyNode = runtime.workGraph.listNodes('verify-fingerprint-run')[0];
  runtime.workGraph.updateNode(verifyNode.id, { status: 'completed' });
  await runtime.verifyRun({
    ...base,
    claim: { summary: 'Revised answer', confidence: 0.9 },
    finalContent: 'Revised answer',
    evidence: [...base.evidence, { id: 'e2', summary: 'Observed B', success: true }],
    artifacts: [{ artifactId: 'artifact-1', complete: true }],
    sideEffects: [{ id: 's1', status: 'failed' }],
    semanticVerifier,
    previousSemanticFailure: changedFinal.semanticFailure,
  });
  assert.equal(calls, 6);
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
