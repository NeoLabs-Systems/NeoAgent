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
        content: 'Still working on it',
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

  test('task_complete judge rejects a high-confidence progress-only candidate', async () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine);

    engine.requestStructuredJson = async () => ({
      value: {
        status: 'continue',
        reason: 'The draft is only a status update and more investigation is still possible.',
      },
      usage: 17,
    });

    const result = await engine.evaluateTaskCompleteSignal({
      provider: {},
      providerName: 'test',
      model: 'test-model',
      messages: [],
      analysis: { goal: 'Fix the requested issue.' },
      plan: { success_criteria: ['Confirm the bug', 'Implement the fix'] },
      tools: [],
      toolExecutions: [{ toolName: 'execute_command', error: 'owner_repo must be in format "owner/repo"' }],
      finalMessage: 'The branch has no changes yet. Let me investigate properly.',
      confidence: 'high',
      triggerSource: 'messaging',
      messagingSent: false,
      iteration: 3,
      maxIterations: 8,
      options: {
        source: 'whatsapp',
        runId,
        userId: user.userId,
        agentId: null,
      },
    });

    assert.equal(result.decision.status, 'continue');
    assert.equal(result.usage, 17);
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

  test('shared completion judge includes the persisted run goal contract', async () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine);
    engine.updateRunGoalContract(runId, {
      goal: 'Fix the WhatsApp reliability issue.',
      successCriteria: [
        'The final answer must be sent back to the original messaging chat.',
        'A progress update must never count as completion.',
      ],
      completionConfidenceRequired: 'high',
      progressUpdatePolicy: 'required',
    });

    let capturedPrompt = '';
    engine.requestStructuredJson = async ({ prompt }) => {
      capturedPrompt = prompt;
      return {
        value: {
          status: 'continue',
          reason: 'More work remains.',
        },
        usage: 0,
      };
    };

    await engine.decideLoopState({
      provider: {},
      providerName: 'test',
      model: 'test-model',
      messages: [],
      analysis: {},
      plan: {},
      tools: [],
      toolExecutions: [],
      lastReply: 'Still checking this.',
      triggerSource: 'messaging',
      messagingSent: false,
      iteration: 2,
      maxIterations: 8,
      options: {
        source: 'whatsapp',
        runId,
        userId: user.userId,
        agentId: null,
      },
    });

    assert.match(capturedPrompt, /Persistent run goal: Fix the WhatsApp reliability issue\./);
    assert.match(capturedPrompt, /A progress update must never count as completion\./);
    assert.match(capturedPrompt, /completion_confidence_required=high/);
  });

  test('task_complete judge accepts a finished candidate', async () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine);

    engine.requestStructuredJson = async () => ({
      value: {
        status: 'complete',
        reason: 'The finished answer is now ready.',
      },
      usage: 9,
    });

    const result = await engine.evaluateTaskCompleteSignal({
      provider: {},
      providerName: 'test',
      model: 'test-model',
      messages: [],
      analysis: { goal: 'Fix the requested issue.' },
      plan: {},
      tools: [],
      toolExecutions: [],
      finalMessage: 'Here is the finished answer.',
      confidence: 'high',
      triggerSource: 'messaging',
      messagingSent: false,
      iteration: 2,
      maxIterations: 8,
      options: {
        source: 'whatsapp',
        runId,
        userId: user.userId,
        agentId: null,
      },
    });

    assert.equal(result.decision.status, 'complete');
    assert.equal(result.usage, 9);
  });

  test('task_complete still uses the judge at the iteration limit', async () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const { runId } = seedMessagingRun(engine);
    let judgeCalls = 0;

    engine.requestStructuredJson = async () => {
      judgeCalls += 1;
      return {
        value: {
          status: 'continue',
          reason: 'More work is still possible in this run.',
        },
        usage: 4,
      };
    };

    const result = await engine.evaluateTaskCompleteSignal({
      provider: {},
      providerName: 'test',
      model: 'test-model',
      messages: [],
      analysis: { goal: 'Fix the requested issue.' },
      plan: {},
      tools: [],
      toolExecutions: [],
      finalMessage: 'Let me investigate that properly first.',
      confidence: 'high',
      triggerSource: 'messaging',
      messagingSent: false,
      iteration: 8,
      maxIterations: 8,
      options: {
        source: 'whatsapp',
        runId,
        userId: user.userId,
        agentId: null,
      },
    });

    assert.equal(judgeCalls, 1);
    assert.equal(result.decision.status, 'continue');
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

  test('tool-bound messaging run sends a heartbeat after 60 seconds and respects the 90 second cadence', async (t) => {
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

    t.mock.timers.setTime(60_001);
    await engine.tickMessagingProgressSupervisor(runId);
    assert.equal(messagingManager.sent.length, 1);
    assert.match(messagingManager.sent[0].content, /Still working on execute_command/);

    t.mock.timers.setTime(149_000);
    await engine.tickMessagingProgressSupervisor(runId);
    assert.equal(messagingManager.sent.length, 1);

    t.mock.timers.setTime(150_001);
    await engine.tickMessagingProgressSupervisor(runId);
    assert.equal(messagingManager.sent.length, 2);
    assert.equal(engine.getRunMeta(runId).progressLedger.heartbeatCount, 2);
  });

  test('runtime heartbeat includes overall run age even when the current tool just started', async (t) => {
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
    assert.match(messagingManager.sent[0].content, /Run active 2m/);
    assert.match(messagingManager.sent[0].content, /current step 1s/);
  });

  test('blocked model calls receive factual runtime heartbeats', async (t) => {
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
    assert.match(messagingManager.sent[0].content, /Still working on this/);
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

  test('failed runtime heartbeat is not recorded as visible progress', async (t) => {
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
    await assert.rejects(
      engine.tickMessagingProgressSupervisor(runId),
      (error) => error.code === 'MESSAGING_DELIVERY_FAILED',
    );

    const runMeta = engine.getRunMeta(runId);
    assert.equal(Number(runMeta.progressLedger.heartbeatCount || 0), 0);
    assert.equal(runMeta.progressLedger.lastUserVisibleUpdateAt || null, null);
    assert.equal(runMeta.interimMessages.length, 0);
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
    assert.match(messagingManager.sent[messagingManager.sent.length - 1].content, /no verified progress/);
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

    const artifacts = await extractArtifactsFromResult('execute_command', {
      stdout: '/tmp/neoagent-missing-artifact.txt',
    });

    assert.equal(artifacts.length, 0);
  });
});
