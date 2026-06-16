'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, describe, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

function createMessagingManager() {
  const sent = [];
  const typing = [];
  return {
    sent,
    typing,
    async sendMessage(userId, platform, to, content, options = {}) {
      sent.push({ userId, platform, to, content, options });
      return { success: true };
    },
    async sendTyping(userId, platform, to, isTyping, options = {}) {
      typing.push({ userId, platform, to, isTyping, options });
      return { success: true };
    },
  };
}

describe('messaging progress supervisor', () => {
  let ctx;
  let user;
  let AgentEngine;
  let listRunEvents;

  beforeEach(async () => {
    ctx = createTestRuntime();
    user = await createTestUser(ctx.db);
    ({ AgentEngine } = require('../../../server/services/ai/engine'));
    ({ listRunEvents } = require('../../../server/services/ai/runEvents'));
  });

  afterEach(() => {
    teardownTestRuntime(ctx);
  });

  function insertRun(runId) {
    ctx.db.prepare(
      `INSERT INTO agent_runs (
        id, user_id, agent_id, title, status, trigger_type, trigger_source, model, metadata_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      runId,
      user.userId,
      null,
      'Messaging test run',
      'running',
      'user',
      'messaging',
      'test-model',
      '{}',
    );
  }

  function seedMessagingRun(engine, extra = {}) {
    const runId = extra.runId || `run-${Math.random().toString(16).slice(2)}`;
    insertRun(runId);
    const startedAt = Number(extra.startedAt || Date.now());
    const startedAtIso = extra.startedAtIso || new Date(startedAt).toISOString();
    const interimMessages = Array.isArray(extra.interimMessages) ? extra.interimMessages.slice() : [];
    const progressLedger = {
      currentStep: null,
      currentTool: null,
      currentStepStartedAt: null,
      lastVerifiedProgressAt: startedAtIso,
      lastUserVisibleUpdateAt: null,
      lastFinalDeliveryAt: null,
      heartbeatCount: 0,
      stallNotifiedAt: null,
      progressState: 'active',
      currentPhase: 'idle',
      ...(extra.progressLedger || {}),
    };
    const runMeta = {
      userId: user.userId,
      agentId: null,
      status: 'running',
      aborted: false,
      messagingSent: false,
      noResponse: false,
      explicitMessageSent: false,
      finalDeliverySent: false,
      lastSentMessage: '',
      sentMessages: [],
      widgetSnapshotSaved: false,
      triggerType: 'user',
      triggerSource: 'messaging',
      startedAt,
      startedAtIso,
      lastToolName: null,
      lastToolTarget: null,
      lastInterimMessage: interimMessages[interimMessages.length - 1]?.content || '',
      interimMessages,
      interimSignatures: new Set(),
      terminalInterim: null,
      voiceSessionId: null,
      // Simulates the agent loop authoring a dynamic progress line.
      composeProgressUpdate: async () => 'still working through the current step',
      steeringQueue: [],
      systemSteeringQueue: [],
      toolPids: new Set(),
      repetitionGuard: {},
      messagingContext: {
        platform: 'whatsapp',
        chatId: 'chat-1',
      },
      progressLedger,
      ...extra,
    };
    engine.activeRuns.set(runId, runMeta);
    engine.persistRunMetadata(runId, {
      progressLedger: engine.buildProgressLedgerSnapshot(runMeta),
    });
    return { runId, runMeta };
  }

  test('interim progress does not suppress final fallback delivery', async () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, {
      messagingManager,
      messagingDeliveryRetry: { maxAttempts: 1 },
    });
    const interimAt = new Date(Date.now() - 30_000).toISOString();
    const { runId } = seedMessagingRun(engine, {
      interimMessages: [{
        content: 'Alright let me read that first',
        kind: 'progress',
        expectsReply: false,
        deferFollowUp: false,
        createdAt: interimAt,
      }],
      progressLedger: {
        lastUserVisibleUpdateAt: interimAt,
      },
    });

    assert.equal(
      engine.shouldSendMessagingFinalFallback(
        engine.getRunMeta(runId),
        'Here is the finished answer.',
        'whatsapp',
      ),
      true,
    );

    const result = await engine.deliverMessagingFinalFallback({
      runId,
      userId: user.userId,
      agentId: null,
      platform: 'whatsapp',
      chatId: 'chat-1',
      content: 'Here is the finished answer.',
    });

    assert.equal(result.sent, true);
    assert.equal(messagingManager.sent.length, 1);
    assert.equal(messagingManager.sent[0].content, 'Here is the finished answer.');
    assert.equal(engine.getRunMeta(runId).messagingSent, true);
    assert.equal(engine.getRunMeta(runId).finalDeliverySent, true);
    assert.equal(engine.getRunMeta(runId).progressLedger.lastFinalDeliveryAt != null, true);
  });

  test('final fallback only sends once even when interim history exists', async () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, {
      messagingManager,
      messagingDeliveryRetry: { maxAttempts: 1 },
    });
    const { runId } = seedMessagingRun(engine, {
      interimMessages: [{
        content: 'Investigating the issue.',
        kind: 'progress',
        expectsReply: false,
        deferFollowUp: false,
        createdAt: new Date().toISOString(),
      }],
    });

    const first = await engine.deliverMessagingFinalFallback({
      runId,
      userId: user.userId,
      agentId: null,
      platform: 'whatsapp',
      chatId: 'chat-1',
      content: 'Recovered final answer.',
    });
    const second = await engine.deliverMessagingFinalFallback({
      runId,
      userId: user.userId,
      agentId: null,
      platform: 'whatsapp',
      chatId: 'chat-1',
      content: 'Recovered final answer.',
    });

    assert.equal(first.sent, true);
    assert.equal(second.sent, false);
    assert.equal(messagingManager.sent.length, 1);
  });

  test('failed final fallback delivery never records terminal delivery', async () => {
    const messagingManager = createMessagingManager();
    messagingManager.sendMessage = async () => ({
      success: false,
      error: 'transport unavailable',
    });
    const engine = new AgentEngine(null, {
      messagingManager,
      messagingDeliveryRetry: { maxAttempts: 1 },
    });
    const { runId } = seedMessagingRun(engine);

    await assert.rejects(
      engine.deliverMessagingFinalFallback({
        runId,
        userId: user.userId,
        agentId: null,
        platform: 'whatsapp',
        chatId: 'chat-1',
        content: 'This must reach the user.',
      }),
      (error) => error.code === 'MESSAGING_DELIVERY_FAILED',
    );

    const runMeta = engine.getRunMeta(runId);
    assert.equal(runMeta.finalDeliverySent, false);
    assert.equal(runMeta.lastSentMessage, '');
    assert.equal(runMeta.sentMessages.length, 0);
    assert.equal(runMeta.progressLedger.lastFinalDeliveryAt, null);
  });

  test('thrown final fallback delivery never records terminal delivery', async () => {
    const messagingManager = createMessagingManager();
    messagingManager.sendMessage = async () => {
      throw new Error('socket closed');
    };
    const engine = new AgentEngine(null, {
      messagingManager,
      messagingDeliveryRetry: { maxAttempts: 1 },
    });
    const { runId } = seedMessagingRun(engine);

    await assert.rejects(
      engine.deliverMessagingFinalFallback({
        runId,
        userId: user.userId,
        agentId: null,
        platform: 'whatsapp',
        chatId: 'chat-1',
        content: 'This must reach the user.',
      }),
      /socket closed/,
    );

    assert.equal(engine.getRunMeta(runId).finalDeliverySent, false);
  });

  test('final fallback retries delivery without replaying task work', async () => {
    const messagingManager = createMessagingManager();
    let attempts = 0;
    messagingManager.sendMessage = async (...args) => {
      attempts += 1;
      if (attempts === 1) {
        return { success: false, error: 'temporary transport failure' };
      }
      messagingManager.sent.push(args);
      return { success: true };
    };
    const engine = new AgentEngine(null, {
      messagingManager,
      messagingDeliveryRetry: {
        maxAttempts: 2,
        baseDelayMs: 0,
        maxDelayMs: 0,
      },
    });
    const { runId } = seedMessagingRun(engine);

    const result = await engine.deliverMessagingFinalFallback({
      runId,
      userId: user.userId,
      agentId: null,
      platform: 'whatsapp',
      chatId: 'chat-1',
      content: 'Completed result.',
    });

    assert.equal(result.sent, true);
    assert.equal(attempts, 2);
    assert.equal(engine.getRunMeta(runId).finalDeliverySent, true);
  });

  test('exhausted final delivery cannot trigger an autonomous task replay', async () => {
    const messagingManager = createMessagingManager();
    messagingManager.sendMessage = async () => ({
      success: false,
      error: 'transport unavailable',
    });
    const engine = new AgentEngine(null, {
      messagingManager,
      messagingDeliveryRetry: {
        maxAttempts: 2,
        baseDelayMs: 0,
        maxDelayMs: 0,
      },
    });
    const { runId } = seedMessagingRun(engine);

    await assert.rejects(
      engine.deliverMessagingFinalFallback({
        runId,
        userId: user.userId,
        agentId: null,
        platform: 'whatsapp',
        chatId: 'chat-1',
        content: 'Completed result.',
      }),
      (error) => (
        error.code === 'MESSAGING_DELIVERY_FAILED'
        && error.disableAutonomousRetry === true
      ),
    );

    assert.equal(engine.getRunMeta(runId).finalDeliverySent, false);
  });

  test('explicit final messaging delivery suppresses auto fallback', () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine, {
      explicitMessageSent: true,
      finalDeliverySent: true,
      lastSentMessage: 'Done already.',
      sentMessages: ['Done already.'],
      progressLedger: {
        lastFinalDeliveryAt: new Date().toISOString(),
      },
    });

    assert.equal(
      engine.shouldSendMessagingFinalFallback(
        engine.getRunMeta(runId),
        'Another answer',
        'whatsapp',
      ),
      false,
    );
  });

  test('task_complete is evaluated through the structured completion judge', async () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });

    assert.equal(
      typeof engine.evaluateTaskCompleteSignal,
      'function',
      'evaluateTaskCompleteSignal must exist on the engine',
    );
    assert.equal(
      typeof engine.decideLoopState,
      'function',
      'decideLoopState must exist on the engine',
    );
  });

  test('task_complete judge can reject a premature completion signal', async () => {
    const engine = new AgentEngine(null, { messagingManager: createMessagingManager() });
    const { runId } = seedMessagingRun(engine, {
      goalContract: {
        goal: 'Finish the requested implementation.',
        successCriteria: ['Tests pass.'],
        completionConfidenceRequired: 'high',
      },
    });
    let judgeCalls = 0;
    const result = await engine.evaluateTaskCompleteSignal({
      provider: {
        async chat() {
          judgeCalls += 1;
          return {
            content: '{"status":"continue","reason":"Tests have not been run."}',
            usage: { totalTokens: 7 },
          };
        },
      },
      providerName: 'test',
      model: 'test-model',
      messages: [],
      analysis: { goal: 'Finish the requested implementation.' },
      plan: null,
      tools: [],
      toolExecutions: [],
      finalMessage: 'Done.',
      confidence: 'high',
      iteration: 1,
      maxIterations: 5,
      options: { runId, userId: user.userId, triggerSource: 'messaging' },
    });

    assert.equal(judgeCalls, 1);
    assert.equal(result.accepted, false);
    assert.equal(result.status, 'continue');
    assert.match(result.reason, /Tests/);
  });

  test('task_complete low confidence is rejected before the judge when confidence requirement is high', async () => {
    const engine = new AgentEngine(null, { messagingManager: createMessagingManager() });
    const { runId } = seedMessagingRun(engine, {
      goalContract: {
        goal: 'Finish the requested implementation.',
        completionConfidenceRequired: 'high',
      },
    });
    let judgeCalls = 0;
    const result = await engine.evaluateTaskCompleteSignal({
      provider: {
        async chat() {
          judgeCalls += 1;
          return { content: '{"status":"complete"}' };
        },
      },
      providerName: 'test',
      model: 'test-model',
      messages: [],
      analysis: { goal: 'Finish the requested implementation.' },
      plan: null,
      tools: [],
      toolExecutions: [],
      finalMessage: 'Done.',
      confidence: 'low',
      iteration: 1,
      maxIterations: 5,
      options: { runId, userId: user.userId, triggerSource: 'messaging' },
    });

    assert.equal(judgeCalls, 0);
    assert.equal(result.accepted, false);
    assert.equal(result.status, 'continue');
    assert.match(result.reason, /below required/);
  });

  test('run goal contract merges and persists durable success criteria', () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine);

    engine.updateRunGoalContract(runId, {
      goal: 'Fix messaging reliability.',
      successCriteria: [
        'Final reply reaches the originating chat.',
      ],
      completionConfidenceRequired: 'high',
    });
    engine.updateRunGoalContract(runId, {
      successCriteria: [
        'Progress notes never suppress the final reply.',
        'Final reply reaches the originating chat.',
      ],
      progressUpdatePolicy: 'required',
    });

    const runMeta = engine.getRunMeta(runId);
    const persisted = JSON.parse(ctx.db.prepare(
      'SELECT metadata_json FROM agent_runs WHERE id = ?'
    ).get(runId).metadata_json || '{}');

    assert.equal(runMeta.goalContract.goal, 'Fix messaging reliability.');
    assert.deepEqual(runMeta.goalContract.successCriteria, [
      'Final reply reaches the originating chat.',
      'Progress notes never suppress the final reply.',
    ]);
    assert.equal(runMeta.goalContract.completionConfidenceRequired, 'high');
    assert.equal(runMeta.goalContract.progressUpdatePolicy, 'required');
    assert.deepEqual(persisted.goalContract.successCriteria, runMeta.goalContract.successCriteria);
  });

  test('the original run goal cannot be replaced by a later model summary', () => {
    const engine = new AgentEngine(null, {
      messagingManager: createMessagingManager(),
    });
    const { runId } = seedMessagingRun(engine);

    engine.updateRunGoalContract(runId, {
      goal: 'Implement the complete user request and verify the result.',
    });
    engine.updateRunGoalContract(runId, {
      goal: 'Send a short acknowledgement.',
      successCriteria: ['The requested implementation is complete.'],
    });

    const goalContract = engine.getRunMeta(runId).goalContract;
    assert.equal(
      goalContract.goal,
      'Implement the complete user request and verify the result.',
    );
    assert.deepEqual(goalContract.successCriteria, [
      'The requested implementation is complete.',
    ]);
  });

  test('idle supervisor queues an internal progress nudge without sending user text', async (t) => {
    t.mock.timers.enable({ apis: ['Date'] });
    t.mock.timers.setTime(0);

    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine, {
      startedAt: Date.now(),
      startedAtIso: new Date(Date.now()).toISOString(),
      progressLedger: {
        currentPhase: 'idle',
        currentStep: null,
        currentTool: null,
        currentStepStartedAt: null,
      },
    });

    t.mock.timers.setTime(61_000);
    const result = await engine.tickMessagingProgressSupervisor(runId);

    // Idle phase → enqueues steering, does not send a runtime message
    assert.equal(result.queued, true);
    assert.equal(messagingManager.sent.length, 0);

    const systemQueue = engine.activeRuns.get(runId)?.systemSteeringQueue ?? [];
    const nudgeText = systemQueue.map((s) => s.content ?? s).join(' ');
    assert.match(nudgeText, /Mandatory internal progress check/);
    assert.match(nudgeText, /send a concise model-authored interim update/);
    assert.match(nudgeText, /Do not continue silently/);
  });

  test('runtime heartbeat sends a visible update during tool work and still nudges the model', async (t) => {
    t.mock.timers.enable({ apis: ['Date'] });
    t.mock.timers.setTime(0);

    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine, {
      startedAt: Date.now(),
      startedAtIso: new Date(Date.now()).toISOString(),
      progressLedger: {
        currentPhase: 'tool',
        currentStep: 'step-1',
        currentTool: 'execute_command',
        currentStepStartedAt: new Date(Date.now()).toISOString(),
      },
    });

    t.mock.timers.setTime(61_000);
    const result = await engine.tickMessagingProgressSupervisor(runId);

    assert.equal(result.sent, true);
    assert.equal(result.heartbeat, true);
    assert.equal(messagingManager.sent.length, 1);
    assert.equal(engine.getRunMeta(runId).progressLedger.heartbeatCount, 1);
    assert.equal(engine.getRunMeta(runId).progressLedger.lastUserVisibleUpdateAt != null, true);

    const systemQueue = engine.activeRuns.get(runId)?.systemSteeringQueue ?? [];
    const steeringText = systemQueue.map((s) => s.content ?? s).join(' ');
    assert.match(steeringText, /Mandatory internal progress check/);
    assert.match(steeringText, /send a concise model-authored interim update/);
  });

  test('runtime heartbeat with no composed progress stays internal', async (t) => {
    t.mock.timers.enable({ apis: ['Date'] });
    t.mock.timers.setTime(0);

    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine, {
      startedAt: Date.now(),
      startedAtIso: new Date(Date.now()).toISOString(),
      composeProgressUpdate: async () => '',
      progressLedger: {
        currentPhase: 'model',
        currentStep: 'model:chat',
        currentTool: null,
        currentStepStartedAt: new Date(Date.now()).toISOString(),
      },
    });

    t.mock.timers.setTime(60_001);
    const result = await engine.tickMessagingProgressSupervisor(runId);

    assert.equal(result.sent, false);
    assert.equal(result.heartbeat, true);
    assert.equal(result.queued, true);
    assert.equal(messagingManager.sent.length, 0);
    assert.equal(engine.getRunMeta(runId).progressLedger.lastUserVisibleUpdateAt || null, null);

    const systemQueue = engine.activeRuns.get(runId)?.systemSteeringQueue ?? [];
    assert.equal(systemQueue.length, 1);
  });

  test('terminal interim question suppresses final fallback', () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine, {
      terminalInterim: {
        kind: 'question',
        content: 'Which file should I use?',
        createdAt: new Date().toISOString(),
      },
    });

    assert.equal(
      engine.shouldSendMessagingFinalFallback(
        engine.getRunMeta(runId),
        'This should not auto-send.',
        'whatsapp',
      ),
      false,
    );
  });

  test('tool-bound messaging run sends a visible heartbeat after the first threshold and respects the repeat cadence', async (t) => {
    t.mock.timers.enable({ apis: ['Date'] });
    t.mock.timers.setTime(0);

    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine, {
      startedAt: Date.now(),
      startedAtIso: new Date(Date.now()).toISOString(),
      progressLedger: {
        currentPhase: 'tool',
        currentStep: 'step-1',
        currentTool: 'execute_command',
        currentStepStartedAt: new Date(Date.now()).toISOString(),
      },
    });

    t.mock.timers.setTime(29_999);
    await engine.tickMessagingProgressSupervisor(runId);
    assert.equal(messagingManager.sent.length, 0);
    assert.equal(Number(engine.getRunMeta(runId).progressLedger.heartbeatCount || 0), 0);

    // First visible heartbeat fires after FIRST_UPDATE_MS (30s).
    t.mock.timers.setTime(30_001);
    await engine.tickMessagingProgressSupervisor(runId);
    assert.equal(messagingManager.sent.length, 1);
    assert.equal(engine.getRunMeta(runId).progressLedger.heartbeatCount, 1);

    // Within REPEAT_UPDATE_MS (75s) of the last visible update: no new heartbeat.
    t.mock.timers.setTime(104_000);
    await engine.tickMessagingProgressSupervisor(runId);
    assert.equal(engine.getRunMeta(runId).progressLedger.heartbeatCount, 1);

    // Past the repeat cadence: a second heartbeat fires.
    t.mock.timers.setTime(105_002);
    await engine.tickMessagingProgressSupervisor(runId);
    assert.equal(engine.getRunMeta(runId).progressLedger.heartbeatCount, 2);
    assert.equal(messagingManager.sent.length, 2);
  });

  test('runtime heartbeat marks user-visible progress after a successful send', async (t) => {
    t.mock.timers.enable({ apis: ['Date'] });
    t.mock.timers.setTime(0);

    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine, {
      startedAt: 0,
      startedAtIso: new Date(0).toISOString(),
      progressLedger: {
        currentPhase: 'tool',
        currentStep: 'step-3',
        currentTool: 'execute_command',
        currentStepStartedAt: new Date(119_000).toISOString(),
      },
    });

    t.mock.timers.setTime(120_000);
    await engine.tickMessagingProgressSupervisor(runId);

    assert.equal(messagingManager.sent.length, 1);
    assert.equal(engine.getRunMeta(runId).progressLedger.heartbeatCount, 1);
    assert.equal(engine.getRunMeta(runId).progressLedger.lastUserVisibleUpdateAt != null, true);
  });

  test('a slow model phase sends a visible progress heartbeat', async (t) => {
    t.mock.timers.enable({ apis: ['Date'] });
    t.mock.timers.setTime(0);

    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine, {
      startedAt: 0,
      startedAtIso: new Date(0).toISOString(),
      progressLedger: {
        currentPhase: 'model',
        currentStep: 'model:2',
        currentTool: null,
        currentStepStartedAt: new Date(0).toISOString(),
      },
    });

    t.mock.timers.setTime(60_001);
    await engine.tickMessagingProgressSupervisor(runId);

    assert.equal(messagingManager.sent.length, 1);
    assert.equal(engine.getRunMeta(runId).progressLedger.heartbeatCount, 1);
  });

  test('structured model phases stay visible to the supervisor until they settle', async (t) => {
    t.mock.timers.enable({ apis: ['Date'] });
    t.mock.timers.setTime(0);

    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine, {
      startedAt: 0,
      startedAtIso: new Date(0).toISOString(),
    });
    let resolveModel;
    const modelResult = new Promise((resolve) => {
      resolveModel = resolve;
    });

    const structuredCall = engine.requestStructuredJson({
      provider: {
        chat() {
          return modelResult;
        },
      },
      providerName: 'test',
      model: 'test-model',
      messages: [],
      prompt: 'Return JSON.',
      normalize: (value) => value,
      telemetry: {
        runId,
        userId: user.userId,
      },
      phase: 'completion_decision',
    });

    assert.equal(engine.getRunMeta(runId).progressLedger.currentPhase, 'model');
    assert.equal(
      engine.getRunMeta(runId).progressLedger.currentStep,
      'model:completion_decision',
    );

    t.mock.timers.setTime(60_001);
    await engine.tickMessagingProgressSupervisor(runId);

    assert.equal(messagingManager.sent.length, 1);
    assert.equal(engine.getRunMeta(runId).progressLedger.heartbeatCount, 1);

    resolveModel({
      content: '{"status":"complete"}',
      usage: { totalTokens: 3 },
    });
    await structuredCall;

    assert.equal(engine.getRunMeta(runId).progressLedger.currentPhase, 'idle');
    assert.equal(engine.getRunMeta(runId).progressLedger.currentStep, null);
  });

  test('runtime heartbeat does not depend on messaging delivery', async (t) => {
    t.mock.timers.enable({ apis: ['Date'] });
    t.mock.timers.setTime(0);

    const messagingManager = createMessagingManager();
    messagingManager.sendMessage = async () => ({
      success: false,
      reason: 'not connected',
    });
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine, {
      startedAt: 0,
      startedAtIso: new Date(0).toISOString(),
      progressLedger: {
        currentPhase: 'tool',
        currentStep: 'step-1',
        currentTool: 'execute_command',
        currentStepStartedAt: new Date(0).toISOString(),
      },
    });

    t.mock.timers.setTime(60_001);
    const result = await engine.tickMessagingProgressSupervisor(runId);

    const runMeta = engine.getRunMeta(runId);
    assert.equal(result.heartbeat, true);
    assert.equal(Number(runMeta.progressLedger.heartbeatCount || 0), 1);
    assert.equal(runMeta.progressLedger.lastUserVisibleUpdateAt || null, null);
    assert.equal(runMeta.interimMessages.length, 0);
    assert.equal(messagingManager.sent.length, 0);
  });

  test('stalled tool-bound messaging run records stalled state and resumes on verified progress', async (t) => {
    t.mock.timers.enable({ apis: ['Date'] });
    t.mock.timers.setTime(0);

    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine, {
      startedAt: Date.now(),
      startedAtIso: new Date(Date.now()).toISOString(),
      progressLedger: {
        currentPhase: 'tool',
        currentStep: 'step-2',
        currentTool: 'browser_navigate',
        currentStepStartedAt: new Date(Date.now()).toISOString(),
      },
    });

    t.mock.timers.setTime(240_001);
    await engine.tickMessagingProgressSupervisor(runId);

    const stalledRun = engine.getRunMeta(runId);
    assert.equal(stalledRun.progressLedger.progressState, 'stalled');
    assert.equal(stalledRun.progressLedger.stallNotifiedAt != null, true);
    assert.equal(messagingManager.sent.length, 1);
    assert.equal(listRunEvents(runId).some((event) => event.eventType === 'progress_stalled'), true);

    engine.updateRunProgress(runId, {
      currentPhase: 'idle',
      currentStep: null,
      currentTool: null,
      currentStepStartedAt: null,
    }, {
      verified: true,
    });

    const resumedRun = engine.getRunMeta(runId);
    assert.equal(resumedRun.progressLedger.progressState, 'active');
    assert.equal(resumedRun.progressLedger.stallNotifiedAt, null);
    assert.equal(listRunEvents(runId).some((event) => event.eventType === 'progress_resumed'), true);
  });

  test('missing artifact stat warning path is non-fatal and drops invalid candidates', async () => {
    const { extractArtifactsFromResult } = require('../../../server/services/ai/deliverables/artifact_helpers');
    const originalWarn = console.warn;
    const warnings = [];
    console.warn = (...args) => warnings.push(args.join(' '));

    try {
      const artifacts = await extractArtifactsFromResult('generate_report', {
        artifactPath: '/tmp/neoagent-missing-artifact.txt',
      });

      assert.equal(artifacts.length, 0);
      assert.equal(warnings.length, 1);
    } finally {
      console.warn = originalWarn;
    }
  });

  test('generic command output paths are not promoted to artifact candidates', async () => {
    const { extractArtifactsFromResult } = require('../../../server/services/ai/deliverables/artifact_helpers');

    const artifacts = await extractArtifactsFromResult('execute_command', {
      stdout: [
        '/server/services/ai/engine.js',
        '/README.md',
        '/Users/neo/.codex/attachments/missing/pasted-text.txt',
      ].join('\n'),
    });

    assert.equal(artifacts.length, 0);
  });

  test('generic command result path fields are not promoted to artifact candidates', async () => {
    const { extractArtifactsFromResult } = require('../../../server/services/ai/deliverables/artifact_helpers');
    const originalWarn = console.warn;
    const warnings = [];
    console.warn = (...args) => warnings.push(args.join(' '));

    try {
      const artifacts = await extractArtifactsFromResult('execute_command', {
        path: '/tmp/neoagent-missing-artifact.txt',
        files: [
          { path: '/README.md', type: 'blob' },
          { path: '/server/services/ai/engine.js', type: 'blob' },
        ],
      });

      assert.equal(artifacts.length, 0);
      assert.deepEqual(warnings, []);
    } finally {
      console.warn = originalWarn;
    }
  });

  test('github issue body paths are not promoted to artifact candidates', async () => {
    const { extractArtifactsFromResult } = require('../../../server/services/ai/deliverables/artifact_helpers');

    const artifacts = await extractArtifactsFromResult('github_list_issues', {
      items: [{
        title: 'Docs cleanup',
        body: 'Please update /README.md and /integrations.md when this is implemented.',
      }],
    });

    assert.equal(artifacts.length, 0);
  });

  test('generic api and webpage url fields are not promoted to artifact candidates', async () => {
    const { extractArtifactsFromResult } = require('../../../server/services/ai/deliverables/artifact_helpers');

    const artifacts = await extractArtifactsFromResult('github_get_content', {
      url: 'https://api.github.com/repos/NeoLabs-Systems/NeoAgent/contents/README.md',
      html_url: 'https://github.com/NeoLabs-Systems/NeoAgent/blob/main/README.md',
      download_url: 'https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/README.md',
      image: '//cdn.example.test/assets/logo.png',
      body: '<link rel="icon" href="/apple-touch-icon.png"><img src="//cdn.example.test/hero.jpg">',
    });

    assert.equal(artifacts.length, 0);
  });

  test('github tree path fields are not promoted to artifact candidates', async () => {
    const { extractArtifactsFromResult } = require('../../../server/services/ai/deliverables/artifact_helpers');
    const originalWarn = console.warn;
    const warnings = [];
    console.warn = (...args) => warnings.push(args.join(' '));

    try {
      const artifacts = await extractArtifactsFromResult('github_get_content', [
        { name: 'README.md', path: '/README.md', type: 'file' },
        { name: 'Icon-512.png', path: '/web/icons/Icon-512.png', type: 'file' },
      ]);

      assert.equal(artifacts.length, 0);
      assert.deepEqual(warnings, []);
    } finally {
      console.warn = originalWarn;
    }
  });

  test('explicit artifact container urls are still promoted to artifacts', async () => {
    const { extractArtifactsFromResult } = require('../../../server/services/ai/deliverables/artifact_helpers');
    const originalWarn = console.warn;
    const warnings = [];
    console.warn = (...args) => warnings.push(args.join(' '));

    try {
      const artifacts = await extractArtifactsFromResult('generate_report', {
        artifacts: [{
          url: 'https://example.test/reports/final.pdf',
          label: 'final report',
        }],
      });

      assert.equal(artifacts.length, 1);
      assert.equal(artifacts[0].uri, 'https://example.test/reports/final.pdf');
      assert.deepEqual(warnings, []);
    } finally {
      console.warn = originalWarn;
    }
  });

  test('blank reply after a failed tool continues while budget remains', () => {
    const {
      buildBlankAfterToolFailureGuidance,
      shouldContinueAfterBlankToolFailure,
    } = require('../../../server/services/ai/loop/blank_recovery');
    const failedExecutions = [{
      toolName: 'read_file',
      ok: false,
      error: 'EISDIR: illegal operation on a directory, read',
    }];

    assert.equal(shouldContinueAfterBlankToolFailure({
      lastContent: '',
      failedStepCount: 1,
      remainingIterations: 1,
      toolExecutions: failedExecutions,
    }), true);
    assert.match(
      buildBlankAfterToolFailureGuidance(failedExecutions),
      /task is not terminal/,
    );
  });

  test('blank reply after a failed tool does not continue when budget is exhausted', () => {
    const {
      shouldContinueAfterBlankToolFailure,
    } = require('../../../server/services/ai/loop/blank_recovery');

    assert.equal(shouldContinueAfterBlankToolFailure({
      lastContent: '',
      failedStepCount: 1,
      remainingIterations: 0,
      toolExecutions: [{
        toolName: 'read_file',
        ok: false,
        error: 'EISDIR: illegal operation on a directory, read',
      }],
    }), false);
  });

  test('interim-visible messaging state uses same-run error fallback instead of autonomous replay', () => {
    const {
      shouldRetryMessagingRun,
      shouldSendMessagingErrorFallback,
    } = require('../../../server/services/ai/loop/error_recovery');
    const interimOnlyRunMeta = {
      messagingSent: true,
      finalDeliverySent: false,
      lastInterimMessage: 'Working through the repo now.',
      deliveryState: {
        alreadySent: true,
        finalResponseSent: false,
        finalContentDelivered: false,
      },
    };

    assert.equal(shouldRetryMessagingRun({
      triggerSource: 'messaging',
      options: { source: 'whatsapp', chatId: 'chat-1' },
      runMeta: interimOnlyRunMeta,
      error: new Error('internal runtime failure'),
      retryCount: 0,
      retryLimit: 1,
    }), false);
    assert.equal(shouldSendMessagingErrorFallback({
      triggerSource: 'messaging',
      options: { source: 'whatsapp', chatId: 'chat-1' },
      runMeta: interimOnlyRunMeta,
    }), true);
  });

  test('terminal messaging delivery blocks error recovery retry and fallback', () => {
    const {
      shouldRetryMessagingRun,
      shouldSendMessagingErrorFallback,
    } = require('../../../server/services/ai/loop/error_recovery');
    const terminalRunMeta = {
      messagingSent: true,
      finalDeliverySent: true,
      deliveryState: {
        alreadySent: true,
        finalResponseSent: true,
        finalContentDelivered: true,
      },
    };

    assert.equal(shouldRetryMessagingRun({
      triggerSource: 'messaging',
      options: { source: 'whatsapp', chatId: 'chat-1' },
      runMeta: terminalRunMeta,
      error: new Error('internal runtime failure'),
      retryCount: 0,
      retryLimit: 1,
    }), false);
    assert.equal(shouldSendMessagingErrorFallback({
      triggerSource: 'messaging',
      options: { source: 'whatsapp', chatId: 'chat-1' },
      runMeta: terminalRunMeta,
    }), false);
  });

  test('runtime heartbeat sends nothing once a terminal interim is set', async (t) => {
    t.mock.timers.enable({ apis: ['Date'] });
    t.mock.timers.setTime(0);

    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine, {
      startedAt: 0,
      startedAtIso: new Date(0).toISOString(),
      terminalInterim: { kind: 'question', content: 'Which one?', createdAt: new Date(0).toISOString() },
      progressLedger: {
        currentPhase: 'tool',
        currentStep: 'step-1',
        currentTool: 'execute_command',
        currentStepStartedAt: new Date(0).toISOString(),
      },
    });

    t.mock.timers.setTime(60_001);
    const result = await engine.tickMessagingProgressSupervisor(runId);

    assert.equal(result.skipped, true);
    assert.equal(messagingManager.sent.length, 0);
  });
});
