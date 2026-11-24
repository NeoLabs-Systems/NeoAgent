'use strict';

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');

// Runs real agent runs against a scripted model, so everything between the model
// and the tools is the code that ships: the loop, the policy gate, delivery, and
// the ledger. The same cases can run against a real model with --live.

// Provider instances are cached across runs, so one instance reads whichever
// script the current case installed.
const active = { script: [], requests: [], index: 0 };

function scriptedProvider() {
  return {
    getContextWindow: () => 128000,
    // Sub-agents stream; the answer arrives as one final event.
    async* stream(messages, tools, options) {
      const response = await this.chat(messages, tools, options);
      yield { type: response.toolCalls.length ? 'tool_calls' : 'done', ...response };
    },
    async chat(messages, tools) {
      active.requests.push({ messages, tools });
      const step = active.script[Math.min(active.index, active.script.length - 1)];
      active.index += 1;
      const { index } = active;
      if (step?.throw) throw step.throw;
      const toolCalls = (step?.tools || []).map((call, position) => ({
        id: `call_${index}_${position}`,
        type: 'function',
        function: { name: call.name, arguments: JSON.stringify(call.args || {}) },
      }));
      return {
        content: step?.text || '',
        toolCalls,
        reasoningState: step?.reasoningState || undefined,
        finishReason: toolCalls.length ? 'tool_calls' : 'stop',
        usage: { promptTokens: 100, completionTokens: 10, totalTokens: 110 },
      };
    },
  };
}

function fakeMessaging({ fail = null } = {}) {
  const sent = [];
  return {
    sent,
    async sendMessage(userId, platform, to, content, options = {}) {
      // The real manager only knows platforms that are connected.
      if (platform !== 'telegram') throw new Error(`Platform ${platform} not connected`);
      if (fail) {
        const failure = fail(sent.length);
        if (failure) throw failure;
      }
      sent.push({ platform, to, content, options });
      return { success: true, result: { messageId: `m${sent.length}` } };
    },
    async sendTyping() {},
    getPlatformStatus: () => ({ status: 'connected' }),
  };
}

function createEvalRuntime() {
  const ctx = createTestRuntime();
  const models = require('../../server/services/ai/models');
  const originals = {
    getSupportedModels: models.getSupportedModels,
    createProviderInstance: models.createProviderInstance,
  };
  return {
    ctx,
    models,
    async user() {
      return createTestUser(ctx.db, { username: `eval_${Date.now()}_${Math.floor(Math.random() * 1e6)}` });
    },
    useScript(script) {
      const requests = [];
      Object.assign(active, { script, requests, index: 0 });
      models.getSupportedModels = async () => [{
        id: 'eval-model',
        name: 'Eval model',
        provider: 'eval',
        available: true,
        purpose: 'general',
        priceTier: 'free',
      }];
      models.createProviderInstance = () => scriptedProvider();
      return requests;
    },
    teardown() {
      Object.assign(models, originals);
      teardownTestRuntime(ctx);
    },
  };
}

// An engine whose tools answer from the case. Messaging keeps its real handlers,
// because what the eval checks there is the delivery path itself.
function createEvalEngine({ messaging = null, toolResults = {}, app = null } = {}) {
  const { AgentEngine } = require('../../server/services/ai/engine');
  const engine = new AgentEngine(null, { messagingManager: messaging, app });
  engine.emitted = [];
  const realEmit = engine.emit.bind(engine);
  engine.emit = (userId, event, data) => {
    engine.emitted.push({ event, data });
    realEmit(userId, event, data);
  };
  const realExecute = engine.executeTool.bind(engine);
  engine.toolCalls = [];
  engine.executeTool = async (name, args, context) => {
    engine.toolCalls.push({ name, args });
    if (Object.hasOwn(toolResults, name)) {
      const value = toolResults[name];
      return typeof value === 'function' ? value(args, context) : value;
    }
    return realExecute(name, args, context);
  };
  return engine;
}

function ledgerOf(ctx, runId) {
  return ctx.db.prepare(
    'SELECT event_type, payload_json FROM agent_run_events WHERE run_id = ? ORDER BY sequence_index',
  ).all(runId).map((row) => ({ type: row.event_type, payload: JSON.parse(row.payload_json) }));
}

function visibleFinals(engine, runId) {
  return engine.emitted.filter((entry) => entry.event === 'run:complete' && entry.data?.runId === runId);
}

module.exports = {
  createEvalEngine,
  createEvalRuntime,
  fakeMessaging,
  ledgerOf,
  visibleFinals,
};
