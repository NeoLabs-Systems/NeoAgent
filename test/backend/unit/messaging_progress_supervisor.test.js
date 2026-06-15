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
    const engine = new AgentEngine(null, { messagingManager });
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
    assert.equal(engine.getRunMeta(runId).finalDeliverySent, true);
    assert.equal(engine.getRunMeta(runId).progressLedger.lastFinalDeliveryAt != null, true);
  });

  test('final fallback only sends once even when interim history exists', async () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
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

  test('messaging completion decision keeps working after visible progress until a final answer or blocker exists', async () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const interimAt = new Date(Date.now() - 45_000).toISOString();
    const { runId } = seedMessagingRun(engine, {
      interimMessages: [{
        content: 'nope, noch nicht fertig. hatte angefangen zu recherchieren, hol ich jetzt nach.',
        kind: 'progress',
        expectsReply: false,
        deferFollowUp: false,
        createdAt: interimAt,
      }],
      progressLedger: {
        lastUserVisibleUpdateAt: interimAt,
      },
    });

    engine.requestStructuredJson = async () => ({
      value: {
        status: 'continue',
        reason: 'The draft is only a status update and more investigation is still possible.',
        final_reply: '',
      },
      usage: 17,
    });

    const messages = [{
      role: 'assistant',
      content: 'The checkout branch exists at the same commit as beta with no changes yet. Let me investigate properly.',
    }];
    const result = await engine.resolveMessagingCompletionDecision({
      provider: {},
      providerName: 'test',
      model: 'test-model',
      messages,
      analysis: { goal: 'Fix the requested issue.' },
      plan: { success_criteria: ['Confirm the bug', 'Implement the fix'] },
      tools: [],
      toolExecutions: [{ toolName: 'execute_command', error: 'owner_repo must be in format "owner/repo"' }],
      lastReply: messages[0].content,
      iteration: 3,
      maxIterations: 8,
      runId,
      conversationId: null,
      options: {
        source: 'whatsapp',
        runId,
        userId: user.userId,
        agentId: null,
      },
    });

    assert.equal(result.action, 'continue');
    assert.equal(result.content, '');
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

  test('messaging completion prompt includes the persisted run goal contract', async () => {
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
          final_reply: '',
        },
        usage: 0,
      };
    };

    await engine.decideMessagingCompletionState({
      provider: {},
      providerName: 'test',
      model: 'test-model',
      messages: [],
      analysis: {},
      plan: {},
      tools: [],
      toolExecutions: [],
      lastReply: 'Still checking this.',
      iteration: 2,
      maxIterations: 8,
      runId,
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

  test('messaging completion decision rewrites the latest assistant draft before final fallback delivery', async () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const interimAt = new Date(Date.now() - 45_000).toISOString();
    const conversationId = 'conv-1';
    ctx.db.prepare(
      `INSERT INTO conversations (id, user_id, agent_id, platform, platform_chat_id, title)
       VALUES (?, ?, ?, ?, ?, ?)`
    ).run(conversationId, user.userId, null, 'whatsapp', 'chat-1', 'Messaging test conversation');
    ctx.db.prepare(
      'INSERT INTO conversation_messages (conversation_id, role, content) VALUES (?, ?, ?)'
    ).run(conversationId, 'assistant', 'Still checking this.');

    const { runId } = seedMessagingRun(engine, {
      interimMessages: [{
        content: 'Still checking this.',
        kind: 'progress',
        expectsReply: false,
        deferFollowUp: false,
        createdAt: interimAt,
      }],
      progressLedger: {
        lastUserVisibleUpdateAt: interimAt,
      },
    });

    engine.requestStructuredJson = async () => ({
      value: {
        status: 'complete',
        reason: 'The finished answer is now ready.',
        final_reply: 'Here is the finished answer.',
      },
      usage: 9,
    });

    const messages = [{
      role: 'assistant',
      content: 'Still checking this.',
    }];
    const result = await engine.resolveMessagingCompletionDecision({
      provider: {},
      providerName: 'test',
      model: 'test-model',
      messages,
      analysis: { goal: 'Fix the requested issue.' },
      plan: {},
      tools: [],
      toolExecutions: [],
      lastReply: messages[0].content,
      iteration: 2,
      maxIterations: 8,
      runId,
      conversationId,
      options: {
        source: 'whatsapp',
        runId,
        userId: user.userId,
        agentId: null,
      },
    });

    const storedMessage = ctx.db.prepare(
      'SELECT content FROM conversation_messages WHERE conversation_id = ? ORDER BY id DESC LIMIT 1'
    ).get(conversationId);
    assert.equal(result.action, 'complete');
    assert.equal(result.content, 'Here is the finished answer.');
    assert.equal(messages[messages.length - 1].content, 'Here is the finished answer.');
    assert.equal(storedMessage.content, 'Here is the finished answer.');
  });

  test('iteration-limit messaging run does not stop on a progress-only draft after visible progress', async () => {
    const messagingManager = createMessagingManager();
    const engine = new AgentEngine(null, { messagingManager });
    const interimAt = new Date(Date.now() - 45_000).toISOString();
    const { runId } = seedMessagingRun(engine, {
      interimMessages: [{
        content: 'Still working on it',
        kind: 'progress',
        expectsReply: false,
        deferFollowUp: false,
        createdAt: interimAt,
      }],
      progressLedger: {
        lastUserVisibleUpdateAt: interimAt,
      },
    });

    engine.requestStructuredJson = async () => ({
      value: {
        status: 'continue',
        reason: 'More work is still possible in this run.',
        final_reply: '',
      },
      usage: 4,
    });

    await assert.rejects(
      engine.resolveMessagingCompletionDecision({
        provider: {},
        providerName: 'test',
        model: 'test-model',
        messages: [{
          role: 'assistant',
          content: 'Let me investigate that properly first.',
        }],
        analysis: { goal: 'Fix the requested issue.' },
        plan: {},
        tools: [],
        toolExecutions: [],
        lastReply: 'Let me investigate that properly first.',
        iteration: 8,
        maxIterations: 8,
        runId,
        conversationId: null,
        options: {
          source: 'whatsapp',
          runId,
          userId: user.userId,
          agentId: null,
        },
      }),
      /iteration limit/,
    );
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
