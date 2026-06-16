'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { AgentEngine } = require('../../../server/services/ai/loop/agent_engine_core');

test('spawnSubagent enforces the per-run subagent cap', async () => {
  const engine = new AgentEngine(null, {
    memoryManager: {
      recallMemory: async () => [],
    },
  });

  engine.activeRuns.set('parent-run', {
    userId: 1,
    agentId: null,
    subagentDepth: 0,
  });

  for (let i = 0; i < 10; i += 1) {
    engine.subagents.set(`existing-${i}`, {
      handle: `existing-${i}`,
      parentRunId: 'parent-run',
      status: i % 2 === 0 ? 'running' : 'completed',
    });
  }

  const result = await engine.spawnSubagent(1, 'parent-run', 'Investigate the issue');

  assert.match(result.error || '', /limit for one run is 10/i);
  assert.equal(engine.subagents.size, 10);
});

test('spawnSubagent blocks recursive child spawning', async () => {
  const engine = new AgentEngine(null, {
    memoryManager: {
      recallMemory: async () => [],
    },
  });

  engine.activeRuns.set('child-run', {
    userId: 1,
    agentId: null,
    subagentDepth: 1,
  });

  const result = await engine.spawnSubagent(1, 'child-run', 'Try to spawn again');

  assert.match(result.error || '', /cannot spawn additional sub-agents/i);
  assert.equal(engine.subagents.size, 0);
});
