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
    assert.match(messagingManager.sent[messagingManager.sent.length - 1].content, /not made verified progress/);
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

  test('missing artifact stat warning path is non-fatal', async () => {
    const { extractArtifactsFromResult } = require('../../../server/services/ai/deliverables/artifact_helpers');

    const artifacts = await extractArtifactsFromResult('execute_command', {
      stdout: '/tmp/neoagent-missing-artifact.txt',
    });

    assert.equal(artifacts.length, 1);
    assert.equal(artifacts[0].path, '/tmp/neoagent-missing-artifact.txt');
  });
});
