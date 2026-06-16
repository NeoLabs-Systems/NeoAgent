'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

const root = path.resolve(__dirname, '../../..');

test('AI engine entrypoint is a thin compatibility facade', () => {
  const enginePath = path.join(root, 'server/services/ai/engine.js');
  const source = fs.readFileSync(enginePath, 'utf8');

  assert.ok(source.includes("require('./loop/agent_engine_core')"));
  assert.ok(source.split('\n').length <= 12);
  assert.equal(/class\s+AgentEngine/.test(source), false);
  assert.equal(/async\s+runWithModel/.test(source), false);
});

test('loop implementation is owned by loop modules', () => {
  const corePath = path.join(root, 'server/services/ai/loop/agent_engine_core.js');
  const conversationLoopPath = path.join(root, 'server/services/ai/loop/conversation_loop.js');
  const progressPath = path.join(root, 'server/services/ai/loop/progress_monitor.js');
  const deliveryPath = path.join(root, 'server/services/ai/loop/delivery_state.js');
  const messagingDeliveryPath = path.join(root, 'server/services/ai/loop/messaging_delivery.js');
  const runStatePath = path.join(root, 'server/services/ai/loop/run_state.js');
  const modelIoPath = path.join(root, 'server/services/ai/loop/model_io.js');
  const callbacksPath = path.join(root, 'server/services/ai/loop/callbacks.js');
  const toolDispatchPath = path.join(root, 'server/services/ai/loop/tool_dispatch.js');
  const budgetPath = path.join(root, 'server/services/ai/loop/iteration_budget.js');
  const completionJudgePath = path.join(root, 'server/services/ai/loop/completion_judge.js');
  const errorRecoveryPath = path.join(root, 'server/services/ai/loop/error_recovery.js');

  for (const filePath of [corePath, conversationLoopPath, progressPath, deliveryPath, messagingDeliveryPath, runStatePath, modelIoPath, callbacksPath, toolDispatchPath, budgetPath, completionJudgePath, errorRecoveryPath]) {
    assert.equal(fs.existsSync(filePath), true, `${filePath} should exist`);
  }

  const core = fs.readFileSync(corePath, 'utf8');
  const conversationLoop = fs.readFileSync(conversationLoopPath, 'utf8');
  const completionJudge = fs.readFileSync(completionJudgePath, 'utf8');
  const messagingDelivery = fs.readFileSync(messagingDeliveryPath, 'utf8');
  const runState = fs.readFileSync(runStatePath, 'utf8');
  const modelIo = fs.readFileSync(modelIoPath, 'utf8');
  const callbacks = fs.readFileSync(callbacksPath, 'utf8');
  const toolDispatch = fs.readFileSync(toolDispatchPath, 'utf8');
  const progressMonitor = fs.readFileSync(progressPath, 'utf8');
  const errorRecovery = fs.readFileSync(errorRecoveryPath, 'utf8');
  assert.ok(core.includes('class AgentEngine'));
  assert.ok(core.split('\n').length < 2200, 'agent_engine_core should stay a compatibility core, not regain the full loop');
  assert.ok(core.includes('async _runWithModelInternal'));
  assert.ok(core.includes('return runConversation(this, userId, userMessage, options, _modelOverride);'));
  assert.ok(core.includes('decideLoopState'));
  assert.ok(core.includes('evaluateTaskCompleteSignal'));
  assert.ok(core.includes("require('./completion_judge')"));
  assert.ok(core.includes("require('./messaging_delivery')"));
  assert.ok(core.includes("require('./run_state')"));
  assert.ok(core.includes("require('./model_io')"));
  assert.ok(core.includes("require('./callbacks')"));
  assert.ok(core.includes("require('./tool_dispatch')"));
  assert.equal(/function\s+buildCompletionDecisionPrompt/.test(core), false);
  assert.equal(/function\s+normalizeGoalContract/.test(core), false);
  assert.equal(/function\s+requireSuccessfulMessagingDelivery/.test(core), false);
  assert.equal(/function\s+buildInitialProgressLedger/.test(core), false);
  assert.equal(/function\s+persistRunMetadata/.test(core), false);
  assert.equal(/function\s+enqueueSystemSteering/.test(core), false);
  assert.equal(/function\s+resolveModelCallTimeoutMs/.test(core), false);
  assert.equal(/const\s+attemptModelCall\s*=/.test(core), false);
  assert.equal(/function\s+publishInterimUpdate/.test(core), false);
  assert.equal(/deliveryKind:\s*'interim'/.test(core), false);
  assert.equal(/function\s+executeReadOnlyBatch/.test(core), false);
  assert.equal(/const\s+readOnly\s*=\s*new Set/.test(core), false);
  assert.equal(/const\s+triggerType\s*=\s*options\.triggerType/.test(core), false);
  assert.equal(/while\s*\([^)]*iterationBudget\.consume/.test(core), false);
  assert.equal(/messaging_fallback chunks=/.test(core), false);
  assert.ok(conversationLoop.includes('async function runConversation'));
  assert.ok(conversationLoop.includes('const triggerType = options.triggerType'));
  assert.ok(conversationLoop.includes('while (!directAnswerEligible && iterationBudget.consume())'));
  assert.ok(conversationLoop.includes('await engine.requestModelResponse'));
  assert.ok(conversationLoop.includes('await engine.deliverMessagingFinalFallback'));
  assert.ok(conversationLoop.includes('shouldRetryMessagingRun'));
  assert.ok(conversationLoop.includes('shouldSendMessagingErrorFallback'));
  assert.equal(/runMeta\?\.messagingSent\s*!==\s*true/.test(conversationLoop), false);
  assert.ok(completionJudge.includes('function buildCompletionDecisionPrompt'));
  assert.ok(completionJudge.includes('function normalizeGoalContract'));
  assert.ok(messagingDelivery.includes('function requireSuccessfulMessagingDelivery'));
  assert.ok(messagingDelivery.includes('async function deliverMessagingFinalFallback'));
  assert.ok(messagingDelivery.includes('async function tickMessagingProgressSupervisor'));
  assert.ok(runState.includes('function persistRunMetadata'));
  assert.ok(runState.includes('function enqueueSystemSteering'));
  assert.ok(runState.includes('function markRunFinalDelivery'));
  assert.ok(modelIo.includes('function resolveModelCallTimeoutMs'));
  assert.ok(modelIo.includes('async function requestModelResponse'));
  assert.ok(modelIo.includes('async function requestStructuredJson'));
  assert.ok(callbacks.includes('async function publishInterimUpdate'));
  assert.ok(callbacks.includes("deliveryKind: 'interim'"));
  assert.ok(toolDispatch.includes('async function executeReadOnlyBatch'));
  assert.ok(toolDispatch.includes('const readOnly = new Set'));
  assert.ok(progressMonitor.includes('function buildInitialProgressLedger'));
  assert.ok(errorRecovery.includes('function shouldRetryMessagingRun'));
  assert.ok(errorRecovery.includes('function shouldSendMessagingErrorFallback'));
  assert.ok(errorRecovery.includes('function hasTerminalMessagingDelivery'));
});
