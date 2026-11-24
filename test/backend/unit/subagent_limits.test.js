'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { AgentEngine } = require('../../../server/services/ai/loop/agent_engine_core');

test('spawnSubagent enforces the per-run subagent cap', async () => {
  const userId = 0;
  const engine = new AgentEngine(null, {
    memoryManager: {
      recallMemory: async () => [],
    },
  });

  engine.activeRuns.set('parent-run', {
    userId,
    agentId: null,
    subagentDepth: 0,
    status: 'running',
  });

  for (let i = 0; i < 10; i += 1) {
    engine.subagents.set(`existing-${i}`, {
      handle: `existing-${i}`,
      parentRunId: 'parent-run',
      status: i % 2 === 0 ? 'running' : 'completed',
    });
  }

  const result = await engine.spawnSubagent(userId, 'parent-run', 'Investigate the issue');

  assert.match(result.error || '', /limit for one run is 10/i);
  assert.equal(engine.subagents.size, 10);
});

test('spawnSubagent blocks recursive child spawning', async () => {
  const userId = 0;
  const engine = new AgentEngine(null, {
    memoryManager: {
      recallMemory: async () => [],
    },
  });

  engine.activeRuns.set('child-run', {
    userId,
    agentId: null,
    subagentDepth: 1,
    status: 'running',
  });

  const result = await engine.spawnSubagent(userId, 'child-run', 'Try to spawn again');

  assert.match(result.error || '', /cannot spawn additional sub-agents/i);
  assert.equal(engine.subagents.size, 0);
});

test('a failed child settles its record without an unhandled rejection', async (t) => {
  const originalRunWithModel = AgentEngine.prototype.runWithModel;
  AgentEngine.prototype.runWithModel = async () => {
    throw new Error('child provider failed');
  };
  t.after(() => {
    AgentEngine.prototype.runWithModel = originalRunWithModel;
  });

  const userId = 0;
  const engine = new AgentEngine(null, {
    memoryManager: {
      recallMemory: async () => [],
    },
  });
  engine.emit = () => {};
  engine.activeRuns.set('parent-run', {
    userId,
    agentId: null,
    subagentDepth: 0,
    status: 'running',
    aborted: false,
    abortController: new AbortController(),
  });

  const started = await engine.spawnSubagent(userId, 'parent-run', 'Investigate failure');
  const record = engine.subagents.get(started.handle);
  const settled = await record.promise;

  assert.equal(settled, record);
  assert.equal(record.status, 'failed');
  assert.equal(record.error, 'child provider failed');
  assert.equal(record.settled, true);
});

function engineWithParent(meta = {}) {
  const engine = new AgentEngine(null, { memoryManager: { recallMemory: async () => [] } });
  engine.emit = () => {};
  engine.activeRuns.set('parent-run', {
    userId: 0,
    agentId: null,
    subagentDepth: 0,
    status: 'running',
    aborted: false,
    abortController: new AbortController(),
    ...meta,
  });
  return engine;
}

test('a child stopped by its parent settles as failed, so nobody waits on it forever', async (t) => {
  const originalRunWithModel = AgentEngine.prototype.runWithModel;
  let engine = null;
  AgentEngine.prototype.runWithModel = async () => {
    engine.activeRuns.get('parent-run').abortController.abort(new Error('stopped by the owner'));
    return { status: 'completed', content: 'pretends to be done' };
  };
  t.after(() => {
    AgentEngine.prototype.runWithModel = originalRunWithModel;
  });
  engine = engineWithParent();
  const started = await engine.spawnSubagent(0, 'parent-run', 'Work');
  const record = await engine.subagents.get(started.handle).promise;
  assert.equal(record.status, 'failed');
  assert.match(record.error, /stopped by the owner/);
});

test('a child works where its parent works, and cannot reach unlimited agents', async (t) => {
  const originalRunWithModel = AgentEngine.prototype.runWithModel;
  const seen = [];
  AgentEngine.prototype.runWithModel = async (...args) => {
    seen.push(args.find((arg) => arg && arg.disallowedToolNames));
    return { status: 'completed', content: '{}' };
  };
  t.after(() => {
    AgentEngine.prototype.runWithModel = originalRunWithModel;
  });
  const engine = engineWithParent({ deviceTarget: 'local', workspaceRoot: '/work/project' });
  const started = await engine.spawnSubagent(0, 'parent-run', 'Work');
  await engine.subagents.get(started.handle).promise;
  assert.equal(seen[0].deviceTarget, 'local');
  assert.equal(seen[0].workspaceRoot, '/work/project');
  assert.deepEqual(seen[0].disallowedToolNames, ['spawn_subagent', 'delegate_to_agent', 'agent_task', 'create_agent']);
});
