'use strict';

const assert = require('node:assert/strict');
const { after, before, beforeEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

let ctx;
let userId;
let manager;
let taskStore;
let agentTasks;
let creation;
let restrictions;
let AgentEngine;
let main;
let scout;
let dev;

before(async () => {
  ctx = createTestRuntime();
  userId = (await createTestUser(ctx.db, { username: 'agent_tasks_user' })).userId;
  manager = require('../../../server/services/agents/manager');
  taskStore = require('../../../server/services/agents/tasks');
  agentTasks = require('../../../server/services/ai/loop/agent_tasks');
  creation = require('../../../server/services/agents/creation');
  restrictions = require('../../../server/services/agents/tool_restrictions');
  ({ AgentEngine } = require('../../../server/services/ai/loop/agent_engine_core'));
});

after(() => teardownTestRuntime(ctx));

beforeEach(() => {
  ctx.db.prepare('DELETE FROM agent_delegations').run();
  ctx.db.prepare("DELETE FROM agents WHERE user_id = ?").run(userId);
  main = manager.ensureMainAgent(userId);
  scout = manager.createAgent(userId, { displayName: 'Scout', responsibilities: 'Tracks competitors.' });
  dev = manager.createAgent(userId, { displayName: 'Dev', responsibilities: 'Owns the repository.', canDelegate: true });
});

const flush = () => new Promise((resolve) => setImmediate(resolve));

async function settle() {
  for (let i = 0; i < 10; i += 1) await flush();
}

// An engine whose model runs are scripted: `reply(message, options)` decides
// what each run returns. Every run it was asked for is recorded.
function scriptedEngine(reply = () => ({ status: 'completed', content: 'Done.' })) {
  const engine = new AgentEngine(null, {});
  engine.emit = () => {};
  engine.runs = [];
  engine.runWithModel = async (runUserId, message, options) => {
    engine.runs.push({ message, options });
    const result = await reply(message, options);
    return { runId: options.runId || 'report-run', ...result };
  };
  return engine;
}

function requesterRun(engine, runId, agentId = main.id) {
  engine.activeRuns.set(runId, { userId, agentId, status: 'running', aborted: false, systemSteeringQueue: [] });
  ctx.db.prepare(
    `INSERT INTO agent_runs (id, user_id, agent_id, title, status, trigger_type, trigger_source, metadata_json)
     VALUES (?, ?, ?, 'Ask', 'running', 'user', 'web', ?)`,
  ).run(runId, userId, agentId, JSON.stringify({
    resume: { message: 'hi', options: { triggerType: 'user', triggerSource: 'web', agentId, conversationId: null } },
  }));
}

function endRun(engine, runId, status = 'completed') {
  const meta = engine.activeRuns.get(runId);
  meta.status = status;
  engine.activeRuns.delete(runId);
  agentTasks.onRunEnded(engine, runId, meta);
}

test('delegating returns at once, and the result reaches a requester that already ended in a new run', async () => {
  let release;
  const gate = new Promise((resolve) => { release = resolve; });
  const engine = scriptedEngine(async (message, options) => {
    if (options.triggerSource === 'agent_delegation') {
      await gate;
      return { status: 'completed', content: 'Three competitors changed prices.' };
    }
    return { status: 'completed', content: 'Told the user.' };
  });
  requesterRun(engine, 'run-a');

  const started = agentTasks.delegateTask(engine, { userId, agentId: main.id, runId: 'run-a' }, {
    agent: 'scout', task: 'Check competitor prices', expected_output: 'A short list',
  });
  assert.equal(started.mode, 'delegate');
  assert.equal(started.status, 'working');
  const ownerRun = engine.runs[0];
  assert.equal(ownerRun.options.agentId, scout.id);
  assert.equal(ownerRun.options.skipConversationHistory, true);
  assert.match(ownerRun.message, /Check competitor prices/);
  assert.match(ownerRun.message, /A short list/);

  endRun(engine, 'run-a');
  release();
  await settle();

  const task = taskStore.getTaskById(started.task_id);
  assert.equal(task.status, 'completed');
  assert.equal(task.report_pending, 0);
  const report = engine.runs.find((run) => run.options.triggerSource === 'web');
  assert.ok(report, 'a report run was started on the requester surface');
  assert.equal(report.options.agentId, main.id);
  assert.match(report.message, /Three competitors changed prices/);
});

test('a requester still running hears about the result in its own run, not through a second run', async () => {
  const engine = scriptedEngine(() => ({ status: 'completed', content: 'Prices checked.' }));
  requesterRun(engine, 'run-b');
  const started = agentTasks.delegateTask(engine, { userId, agentId: main.id, runId: 'run-b' }, {
    agent: scout.id, task: 'Check prices',
  });
  await settle();
  const queue = engine.activeRuns.get('run-b').systemSteeringQueue;
  assert.equal(queue.length, 1);
  assert.match(queue[0].content, /Prices checked/);
  assert.equal(taskStore.getTaskById(started.task_id).report_pending, 0);

  // The run read the note before it ended: nothing more is sent.
  queue.length = 0;
  endRun(engine, 'run-b');
  await settle();
  assert.equal(engine.runs.filter((run) => run.options.triggerSource === 'web').length, 0);
});

test('a note the requester never read is delivered after it ends', async () => {
  const engine = scriptedEngine(() => ({ status: 'completed', content: 'Late result.' }));
  requesterRun(engine, 'run-c');
  agentTasks.delegateTask(engine, { userId, agentId: main.id, runId: 'run-c' }, { agent: 'scout', task: 'Look' });
  await settle();
  endRun(engine, 'run-c');
  await settle();
  const reports = engine.runs.filter((run) => run.options.triggerSource === 'web');
  assert.equal(reports.length, 1);
  assert.match(reports[0].message, /Late result/);
});

test('a handoff makes the target the owner and the update tells the requester only to relay it', async () => {
  const engine = scriptedEngine(() => ({ status: 'completed', content: 'Fixed the bug.' }));
  requesterRun(engine, 'run-d');
  const started = agentTasks.delegateTask(engine, { userId, agentId: main.id, runId: 'run-d' }, {
    agent: 'dev', task: 'Fix the login bug', handoff: true,
  });
  assert.equal(started.mode, 'handoff');
  const task = taskStore.getTaskById(started.task_id);
  assert.equal(task.target_agent_id, dev.id);
  endRun(engine, 'run-d');
  await settle();
  const report = engine.runs.find((run) => run.options.triggerSource === 'web');
  assert.match(report.message, /took this request over/);
  const chat = ctx.db.prepare(
    "SELECT content, metadata FROM conversation_history WHERE agent_id = ? AND role = 'assistant'",
  ).get(dev.id);
  assert.equal(chat.content, 'Fixed the bug.');
  assert.equal(JSON.parse(chat.metadata).agentTask.mode, 'handoff');
});

test('an owner can hand its task on, but never back up the chain', async () => {
  manager.updateAgent(userId, scout.id, { canDelegate: true });
  const engine = scriptedEngine(() => new Promise(() => {}));
  requesterRun(engine, 'run-e');
  const started = agentTasks.delegateTask(engine, { userId, agentId: main.id, runId: 'run-e' }, { agent: 'scout', task: 'Research' });
  const ownerRunId = taskStore.getTaskById(started.task_id).child_run_id;

  const back = await agentTasks.taskAction(engine, { userId, agentId: scout.id, runId: ownerRunId }, {
    action: 'handoff', task_id: started.task_id, agent: 'main',
  });
  assert.match(back.error, /may not hand work|already part/);

  const moved = await agentTasks.taskAction(engine, { userId, agentId: scout.id, runId: ownerRunId }, {
    action: 'handoff', task_id: started.task_id, agent: 'dev', message: 'Needs code access.',
  });
  assert.equal(moved.handed_off, true);
  const task = taskStore.getTaskById(started.task_id);
  assert.equal(task.target_agent_id, dev.id);
  assert.equal(task.status, 'working');
  assert.match(engine.runs.at(-1).message, /Needs code access/);

  manager.updateAgent(userId, dev.id, { canDelegate: true });
  const pingPong = await agentTasks.taskAction(engine, { userId, agentId: dev.id, runId: task.child_run_id }, {
    action: 'handoff', task_id: started.task_id, agent: 'scout',
  });
  assert.match(pingPong.error, /already part of this task/);
});

test('an owner question makes the task wait, and the answer resumes it', async () => {
  let ownerRuns = 0;
  const engine = scriptedEngine(async (message, options) => {
    if (options.triggerSource !== 'agent_delegation') return { status: 'completed', content: 'ok' };
    ownerRuns += 1;
    if (ownerRuns === 1) {
      const task = taskStore.getTaskForRun(options.runId);
      await agentTasks.taskAction(engine, { userId, agentId: scout.id, runId: options.runId }, {
        action: 'message', task_id: task.id, message: 'Which region?',
      });
      return { status: 'completed', content: 'Waiting for the region.' };
    }
    return { status: 'completed', content: 'EU prices are up.' };
  });
  requesterRun(engine, 'run-f');
  const started = agentTasks.delegateTask(engine, { userId, agentId: main.id, runId: 'run-f' }, { agent: 'scout', task: 'Prices' });
  await settle();
  let task = taskStore.getTaskById(started.task_id);
  assert.equal(task.status, 'waiting');
  assert.equal(task.awaiting_reply, 1);
  assert.match(engine.activeRuns.get('run-f').systemSteeringQueue[0].content, /Which region\?/);

  await agentTasks.taskAction(engine, { userId, agentId: main.id, runId: 'run-f' }, {
    action: 'message', task_id: started.task_id, message: 'The EU.',
  });
  await settle();
  task = taskStore.getTaskById(started.task_id);
  assert.equal(task.status, 'completed');
  assert.equal(task.result_summary, 'EU prices are up.');
  const secondBrief = engine.runs.filter((run) => run.options.triggerSource === 'agent_delegation')[1].message;
  assert.match(secondBrief, /The EU\./);
  assert.match(secondBrief, /Waiting for the region\./);
});

test('a failed owner run fails the task and reports it, and a stopped requester cancels its delegated work', async () => {
  const failing = scriptedEngine(async (message, options) => {
    if (options.triggerSource === 'agent_delegation') throw new Error('provider down');
    return { status: 'completed', content: 'ok' };
  });
  requesterRun(failing, 'run-g');
  const failed = agentTasks.delegateTask(failing, { userId, agentId: main.id, runId: 'run-g' }, { agent: 'scout', task: 'X' });
  await settle();
  assert.equal(taskStore.getTaskById(failed.task_id).status, 'failed');
  assert.match(failing.activeRuns.get('run-g').systemSteeringQueue[0].content, /failed: provider down/);

  const stopped = [];
  const hanging = scriptedEngine(() => new Promise(() => {}));
  hanging.stopRun = (runId) => stopped.push(runId);
  requesterRun(hanging, 'run-h');
  const open = agentTasks.delegateTask(hanging, { userId, agentId: main.id, runId: 'run-h' }, { agent: 'scout', task: 'Y' });
  endRun(hanging, 'run-h', 'stopped');
  const task = taskStore.getTaskById(open.task_id);
  assert.equal(task.status, 'cancelled');
  assert.deepEqual(stopped, [task.child_run_id]);
});

test('work interrupted by a restart is picked up again by the next server', async () => {
  const before = scriptedEngine(() => new Promise(() => {}));
  requesterRun(before, 'run-i');
  const started = agentTasks.delegateTask(before, { userId, agentId: main.id, runId: 'run-i' }, { agent: 'scout', task: 'Survive' });
  assert.equal(taskStore.getTaskById(started.task_id).status, 'working');

  const afterRestart = scriptedEngine(() => ({ status: 'completed', content: 'Survived.' }));
  agentTasks.resumeAgentTasks(afterRestart);
  await settle();
  const task = taskStore.getTaskById(started.task_id);
  assert.equal(task.status, 'completed');
  assert.equal(task.attempts, 2);
  // The asking run is gone too, so the result arrives in a new run on its surface.
  assert.ok(afterRestart.runs.some((run) => run.options.triggerSource === 'web' && /Survived\./.test(run.message)));
});

test('delegation is bounded: per-run count, depth and agents the user does not allow', async () => {
  const engine = scriptedEngine(() => new Promise(() => {}));
  requesterRun(engine, 'run-j');
  for (let i = 0; i < taskStore.LIMITS.tasksPerRun; i += 1) {
    assert.ok(agentTasks.delegateTask(engine, { userId, agentId: main.id, runId: 'run-j' }, { agent: 'scout', task: `Part ${i}` }).task_id);
  }
  const fourth = agentTasks.delegateTask(engine, { userId, agentId: main.id, runId: 'run-j' }, { agent: 'scout', task: 'One more' });
  assert.match(fourth.error, /at most 3/);

  // Scout may not delegate at all.
  const ownerRunId = taskStore.tasksRequestedByRun('run-j')[0].child_run_id;
  const nested = agentTasks.delegateTask(engine, { userId, agentId: scout.id, runId: ownerRunId }, { agent: 'dev', task: 'Code it' });
  assert.match(nested.error, /may not hand work/);
});

test('a created agent never gets more permissions than its creator', () => {
  manager.updateAgent(userId, dev.id, { toolRestrictions: { shell: 'deny', file_write: 'require_approval' } });
  const created = creation.createAgentForRun({ userId, agentId: dev.id, runId: 'run-k' }, {
    name: 'Docs', responsibility: 'Keeps the docs current.', reason: 'Docs drift every release.',
    ask_first: ['shell', 'network_write'], not_allowed: ['user_contact'],
  });
  assert.equal(created.createdByAgentId, dev.id);
  assert.equal(created.creationReason, 'Docs drift every release.');
  assert.equal(created.canDelegate, false);
  assert.deepEqual(created.toolRestrictions, {
    shell: 'deny',
    file_write: 'require_approval',
    network_write: 'require_approval',
    user_contact: 'deny',
  });
  assert.equal(restrictions.restrictionForRun({ userId, agentId: created.id, runId: null, category: 'shell' }), 'deny');

  const again = creation.createAgentForRun({ userId, agentId: dev.id, runId: 'run-k', alreadyCreatedInRun: true }, {
    name: 'Docs 2', responsibility: 'x', reason: 'y',
  });
  assert.match(again.error, /one agent/);
});

test('an agent working a task cannot create agents, and its run inherits the asking agent\'s limits', async () => {
  manager.updateAgent(userId, main.id, { toolRestrictions: { shell: 'deny' } });
  const engine = scriptedEngine(() => new Promise(() => {}));
  requesterRun(engine, 'run-l');
  const started = agentTasks.delegateTask(engine, { userId, agentId: main.id, runId: 'run-l' }, { agent: 'scout', task: 'Z' });
  const ownerRunId = taskStore.getTaskById(started.task_id).child_run_id;
  assert.equal(restrictions.restrictionForRun({ userId, agentId: scout.id, runId: ownerRunId, category: 'shell' }), 'deny');
  assert.equal(restrictions.restrictionForRun({ userId, agentId: scout.id, runId: 'other-run', category: 'shell' }), null);

  const refused = creation.createAgentForRun({ userId, agentId: scout.id, runId: ownerRunId }, {
    name: 'Helper', responsibility: 'Helps.', reason: 'Because.',
  });
  assert.match(refused.error, /cannot create agents/);
});

test('agents made by hand keep working as before', () => {
  const plain = manager.createAgent(userId, { displayName: 'Plain', responsibilities: 'Plain work.' });
  assert.equal(plain.createdByAgentId, null);
  assert.deepEqual(plain.toolRestrictions, {});
  assert.equal(plain.canBeDelegatedTo, true);
  assert.equal(restrictions.restrictionForRun({ userId, agentId: plain.id, runId: null, category: 'shell' }), null);
  assert.throws(() => manager.createAgent(userId, { displayName: 'Plain' }), /already exists/);
});

test('an agent restriction holds even when the account allows everything', async () => {
  const { globalHooks } = require('../../../server/services/ai/hooks');
  const { registerToolSecurityHooks } = require('../../../server/services/security/tool_security_hook');
  const asked = [];
  registerToolSecurityHooks(
    { getSecurityMode: () => 'allow_all', getPolicy: () => 'allow' },
    {
      hasSessionGrant: () => false,
      requestApproval: async (hookUserId, runId, toolName) => {
        asked.push(toolName);
        return 'approved';
      },
    },
  );
  manager.updateAgent(userId, scout.id, { toolRestrictions: { shell: 'deny', file_write: 'require_approval' } });

  const shell = await globalHooks.run('before_tool_call', {
    toolName: 'execute_command', toolArgs: { command: 'ls' }, userId, agentId: scout.id, runId: 'r-shell',
  });
  assert.equal(shell.blocked_by, 'agent_restriction');

  const write = await globalHooks.run('before_tool_call', {
    toolName: 'write_file', toolArgs: { path: 'a.txt' }, userId, agentId: scout.id, runId: 'r-write',
  });
  assert.equal(write.approved, true);
  assert.deepEqual(asked, ['write_file']);

  const unrestricted = await globalHooks.run('before_tool_call', {
    toolName: 'execute_command', toolArgs: { command: 'ls' }, userId, agentId: dev.id, runId: 'r-dev',
  });
  assert.equal(unrestricted.block, undefined);
  assert.deepEqual(asked, ['write_file']);
});

test('agent tools are only offered where they can do something', () => {
  const { getAvailableTools } = require('../../../server/services/ai/tools');
  let policy = 'require_approval';
  const app = { locals: { toolPolicyService: { getPolicy: () => policy } } };
  const names = (options) => getAvailableTools(app, { userId, ...options }).map((tool) => tool.name);

  const forMain = names({ agentId: main.id, triggerSource: 'web' });
  assert.ok(forMain.includes('delegate_to_agent'));
  assert.ok(forMain.includes('agent_task'));
  assert.ok(forMain.includes('create_agent'));

  // Scout has nobody to hand work to and nothing in flight.
  const forScout = names({ agentId: scout.id, triggerSource: 'web' });
  assert.ok(!forScout.includes('delegate_to_agent'));
  assert.ok(!forScout.includes('agent_task'));

  const inTask = names({ agentId: scout.id, triggerSource: 'agent_delegation' });
  assert.ok(inTask.includes('agent_task'));
  assert.ok(!inTask.includes('create_agent'));

  policy = 'deny';
  assert.ok(!names({ agentId: main.id, triggerSource: 'web' }).includes('create_agent'));
});
