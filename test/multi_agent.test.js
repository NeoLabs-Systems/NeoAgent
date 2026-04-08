const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { randomUUID } = require('node:crypto');

const runtimeRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-multi-agent-'));
process.env.NEOAGENT_HOME = path.join(runtimeRoot, 'home');
process.env.NEOAGENT_DATA_DIR = path.join(runtimeRoot, 'data');
process.env.NEOAGENT_AGENT_DATA_DIR = path.join(runtimeRoot, 'agent-data');

const db = require('../server/db/database');
const {
  createAgent,
  ensureMainAgent,
  getAgentById,
  listAgents,
  resolveAgentId,
  updateAgent,
  agentCanDelegateTo,
} = require('../server/services/agents/manager');
const { MemoryManager } = require('../server/services/memory/manager');
const { Scheduler } = require('../server/services/scheduler/cron');
const { executeTool, getAvailableTools } = require('../server/services/ai/tools');
const { ensureDefaultAiSettings, getAiSettings } = require('../server/services/ai/settings');
const { AgentEngine } = require('../server/services/ai/engine');

function createUser(username = `user-${randomUUID()}`) {
  return db
    .prepare('INSERT INTO users (username, password) VALUES (?, ?)')
    .run(username, 'test-password').lastInsertRowid;
}

test('lazy main agent creation resolves a default profile', () => {
  const userId = createUser();

  const main = ensureMainAgent(userId);
  const agents = listAgents(userId);

  assert.equal(main.slug, 'main');
  assert.equal(resolveAgentId(userId), main.id);
  assert.equal(agents.length, 1);
  assert.equal(agents[0].isDefault, true);
});

test('memories are isolated by agent profile', () => {
  const userId = createUser();
  const main = ensureMainAgent(userId);
  const work = createAgent(userId, {
    displayName: 'Work',
    slug: 'work',
    responsibilities: 'Work platform tasks',
  });

  db.prepare(
    `INSERT INTO memories (id, user_id, agent_id, category, content, importance)
     VALUES (?, ?, ?, 'episodic', ?, 5)`,
  ).run(randomUUID(), userId, main.id, 'personal memory');
  db.prepare(
    `INSERT INTO memories (id, user_id, agent_id, category, content, importance)
     VALUES (?, ?, ?, 'episodic', ?, 5)`,
  ).run(randomUUID(), userId, work.id, 'work memory');

  const memoryManager = new MemoryManager();

  assert.deepEqual(
    memoryManager.listMemories(userId, { agentId: main.id }).map((m) => m.content),
    ['personal memory'],
  );
  assert.deepEqual(
    memoryManager.listMemories(userId, { agentId: work.id }).map((m) => m.content),
    ['work memory'],
  );
});

test('scheduler tasks persist their assigned agent', () => {
  const userId = createUser();
  ensureMainAgent(userId);
  const work = createAgent(userId, {
    displayName: 'Work',
    slug: 'scheduler-work',
  });
  const io = { to: () => ({ emit: () => {} }) };
  const scheduler = new Scheduler(io, { run: async () => ({ content: '' }) });

  const task = scheduler.createTask(userId, {
    name: 'Work digest',
    cronExpression: '*/30 * * * *',
    prompt: 'Summarize work updates',
    enabled: false,
    agentId: work.id,
  });

  assert.equal(task.agentId, work.id);
  assert.equal(scheduler.listTasks(userId)[0].agentId, work.id);
});

test('delegate_to_agent tool is available for agent orchestration', () => {
  const userId = createUser();
  const main = ensureMainAgent(userId);
  createAgent(userId, {
    displayName: 'Work',
    slug: 'delegate-work',
  });
  const tools = getAvailableTools(null, { userId, agentId: main.id });
  assert.ok(tools.some((tool) => tool.name === 'delegate_to_agent'));
});

test('direct specialist agents do not get delegation unless policy allows it', () => {
  const userId = createUser();
  ensureMainAgent(userId);
  const work = createAgent(userId, {
    displayName: 'Work',
    slug: 'isolated-work',
  });

  const isolatedTools = getAvailableTools(null, { userId, agentId: work.id });
  assert.equal(isolatedTools.some((tool) => tool.name === 'delegate_to_agent'), false);
});

test('delegated runs do not get nested delegation tools', () => {
  const userId = createUser();
  const main = ensureMainAgent(userId);
  const coding = createAgent(userId, {
    displayName: 'Coding',
    slug: 'nested-coding',
    canDelegate: true,
  });
  createAgent(userId, {
    displayName: 'Reviewer',
    slug: 'nested-reviewer',
  });

  assert.equal(
    getAvailableTools(null, { userId, agentId: main.id })
      .some((tool) => tool.name === 'delegate_to_agent'),
    true,
  );
  assert.equal(
    getAvailableTools(null, { userId, agentId: coding.id, triggerSource: 'agent_delegation' })
      .some((tool) => tool.name === 'delegate_to_agent'),
    false,
  );
});

test('agent delegation policy supports explicit target allowlists', () => {
  const userId = createUser();
  const main = ensureMainAgent(userId);
  const coding = createAgent(userId, {
    displayName: 'Coding',
    slug: 'coding',
  });
  const work = createAgent(userId, {
    displayName: 'Work',
    slug: 'policy-work',
  });

  updateAgent(userId, coding.id, {
    canDelegate: true,
    delegateTargets: [main.id],
  });

  assert.equal(
    agentCanDelegateTo(getAgentById(userId, coding.id), getAgentById(userId, main.id)),
    false,
  );

  updateAgent(userId, main.id, { canBeDelegatedTo: true });

  assert.equal(
    agentCanDelegateTo(getAgentById(userId, coding.id), getAgentById(userId, main.id)),
    true,
  );
  assert.equal(
    agentCanDelegateTo(getAgentById(userId, coding.id), getAgentById(userId, work.id)),
    false,
  );
});

test('per-agent model selection settings are loaded by AI settings', () => {
  const userId = createUser();
  const work = createAgent(userId, {
    displayName: 'Work',
    slug: 'model-work',
  });
  const upsert = db.prepare(
    `INSERT INTO agent_settings (user_id, agent_id, key, value)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(user_id, agent_id, key) DO UPDATE SET value = excluded.value`,
  );
  upsert.run(userId, work.id, 'default_chat_model', JSON.stringify('gpt-5-mini'));
  upsert.run(userId, work.id, 'default_subagent_model', JSON.stringify('gpt-5-nano'));
  upsert.run(userId, work.id, 'enabled_models', JSON.stringify(['gpt-5-mini']));

  ensureDefaultAiSettings(userId, work.id);
  const settings = getAiSettings(userId, work.id);

  assert.equal(settings.default_chat_model, 'gpt-5-mini');
  assert.equal(settings.default_subagent_model, 'gpt-5-nano');
  assert.deepEqual(settings.enabled_models, ['gpt-5-mini']);
});

test('stopping a parent run stops active delegated child runs', () => {
  const userId = createUser();
  const main = ensureMainAgent(userId);
  const work = createAgent(userId, {
    displayName: 'Work',
    slug: 'stop-work',
  });
  const parentRunId = randomUUID();
  const childRunId = randomUUID();
  db.prepare(
    `INSERT INTO agent_runs (id, user_id, agent_id, title, status)
     VALUES (?, ?, ?, 'Parent', 'running'), (?, ?, ?, 'Child', 'running')`,
  ).run(parentRunId, userId, main.id, childRunId, userId, work.id);
  db.prepare(
    `INSERT INTO agent_delegations (
       id, user_id, parent_agent_id, target_agent_id, parent_run_id, child_run_id, task, status
     ) VALUES (?, ?, ?, ?, ?, ?, 'do work', 'running')`,
  ).run(randomUUID(), userId, main.id, work.id, parentRunId, childRunId);
  const engine = new AgentEngine(null);
  engine.activeRuns.set(parentRunId, {
    userId,
    status: 'running',
    aborted: false,
    toolPids: new Set(),
  });
  engine.activeRuns.set(childRunId, {
    userId,
    status: 'running',
    aborted: false,
    toolPids: new Set(),
  });

  engine.stopRun(parentRunId);

  assert.equal(db.prepare('SELECT status FROM agent_runs WHERE id = ?').get(parentRunId).status, 'stopped');
  assert.equal(db.prepare('SELECT status FROM agent_runs WHERE id = ?').get(childRunId).status, 'stopped');
  assert.equal(db.prepare('SELECT status FROM agent_delegations WHERE parent_run_id = ?').get(parentRunId).status, 'stopped');
  assert.equal(engine.activeRuns.get(childRunId).aborted, true);
});

test('built-in memory tools write to the active agent profile', async () => {
  const userId = createUser();
  const main = ensureMainAgent(userId);
  const work = createAgent(userId, {
    displayName: 'Work',
    slug: 'memory-tools-work',
  });

  await executeTool(
    'memory_update_core',
    { key: 'preferences', value: 'Work agent only' },
    { userId, agentId: work.id, app: null, runId: null, triggerSource: 'test' },
    {},
  );

  assert.equal(
    db.prepare('SELECT value FROM core_memory WHERE user_id = ? AND agent_id = ? AND key = ?')
      .get(userId, work.id, 'preferences')?.value,
    'Work agent only',
  );
  assert.equal(
    db.prepare('SELECT value FROM core_memory WHERE user_id = ? AND agent_id = ? AND key = ?')
      .get(userId, main.id, 'preferences'),
    undefined,
  );
});
