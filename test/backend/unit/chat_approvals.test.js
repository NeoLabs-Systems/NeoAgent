'use strict';

const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { afterEach, beforeEach, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const PLATFORM = 'telegram';

let runtime;
let userCount = 0;
const gates = [];

beforeEach(() => {
  runtime = createTestRuntime();
});

afterEach(() => {
  for (const gate of gates.splice(0)) gate.shutdown();
  teardownTestRuntime(runtime);
  runtime = null;
});

function database() {
  return require('../../../server/db/database');
}

async function setup({ policy = { schemaVersion: 3, directPolicy: 'allowlist', directRules: [{ scope: 'user', value: 'owner' }] }, status = 'connected' } = {}) {
  const { ApprovalGateService } = require('../../../server/services/security/approval_gate_service');
  const { ChatApprovals } = require('../../../server/services/messaging/chat_approvals');
  const { accessPolicyKey } = require('../../../server/services/messaging/access_policy');
  const { resolveAgent } = require('../../../server/services/agents/manager');
  userCount += 1;
  const { userId } = await createTestUser(runtime.db, { username: `chat_approvals_${userCount}` });
  const agentId = resolveAgent(userId, null).id;
  database().prepare('INSERT OR REPLACE INTO agent_settings (user_id, agent_id, key, value) VALUES (?, ?, ?, ?)')
    .run(userId, agentId, accessPolicyKey(PLATFORM), JSON.stringify(policy));
  const sent = [];
  const removed = [];
  const platform = {
    getStatus: () => status,
    getAccessPolicy: () => policy,
    sendApprovalPrompt: async (chatId, prompt) => {
      sent.push({ chatId, ...prompt });
      return { promptId: `prompt-${sent.length}` };
    },
    deleteApprovalPrompt: async (chatId, promptId) => { removed.push({ chatId, promptId }); },
  };
  const manager = {
    platforms: new Map([[PLATFORM, platform]]),
    _key: (_user, _agent, name) => name,
    _agentId: () => agentId,
  };
  const io = { to: () => ({ emit() {} }) };
  const policies = [];
  const gate = new ApprovalGateService({
    io,
    toolPolicyService: { setPolicy: (...args) => policies.push(args) },
  });
  const approvals = new ChatApprovals({ manager, gate });
  gate.setChatDelivery(approvals);
  gates.push(gate);
  return { userId, agentId, approvals, gate, platform, manager, sent, removed, policies };
}

const ownerDm = { audience: 'owner', origin: { platform: PLATFORM, chatId: 'dm_owner', senderId: 'owner', isGroup: false } };
const groupRun = { audience: 'shared', origin: { platform: PLATFORM, chatId: '-100', senderId: 'guest', isGroup: true } };

function ask(ctx, trust = ownerDm, toolName = 'execute_command', toolArgs = { command: 'ls' }) {
  const runId = `run-${randomUUID()}`;
  database().prepare("INSERT INTO agent_runs (id, user_id, status, title) VALUES (?, ?, 'running', 'run')")
    .run(runId, ctx.userId);
  return ctx.gate.requestApproval(ctx.userId, runId, toolName, toolArgs, { agentId: ctx.agentId, trust });
}

function answer(ctx, chatId, choiceId, actor) {
  return ctx.approvals.handleResponse({
    userId: ctx.userId,
    agentId: ctx.agentId,
    platformName: PLATFORM,
    chatId,
    promptId: 'prompt-1',
    choiceId,
    actor,
  });
}

test('the owner answers in their chat, and the prompt is taken away', async () => {
  const ctx = await setup();
  const decision = ask(ctx);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(ctx.sent[0].chatId, 'dm_owner');
  assert.deepEqual(ctx.sent[0].options.map((option) => option.id), ['allow', 'always', 'deny']);

  assert.equal(answer(ctx, 'dm_owner', 'allow', { sender: 'owner', isGroup: false }), true);
  assert.equal(await decision, 'approved');
  assert.deepEqual(ctx.removed, [{ chatId: 'dm_owner', promptId: 'prompt-1' }]);
  assert.deepEqual(ctx.policies, []);
});

test('allow always also saves the policy, and disallow denies', async () => {
  const ctx = await setup();
  const always = ask(ctx);
  await new Promise((resolve) => setImmediate(resolve));
  answer(ctx, 'dm_owner', 'always', { sender: 'owner', isGroup: false });
  assert.equal(await always, 'approved');
  assert.equal(ctx.policies.length, 1);
  assert.equal(ctx.policies[0][2], 'allow');

  const other = await setup();
  const denied = ask(other);
  await new Promise((resolve) => setImmediate(resolve));
  answer(other, 'dm_owner', 'deny', { sender: 'owner', isGroup: false });
  assert.equal(await denied, 'denied');
});

test('someone not on the allowlist is not acknowledged', async () => {
  const ctx = await setup();
  const decision = ask(ctx);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(answer(ctx, 'dm_owner', 'allow', { sender: 'stranger', isGroup: false }), false);
  assert.equal(ctx.removed.length, 0);
  assert.equal(ctx.gate._pending.size, 1);
  answer(ctx, 'dm_owner', 'deny', { sender: 'owner', isGroup: false });
  assert.equal(await decision, 'denied');
});

test('in a group only a listed person decides, not the room and not whoever asked', async () => {
  const ctx = await setup({
    policy: {
      schemaVersion: 3,
      sharedPolicy: 'allowlist',
      sharedSpaceRules: [{ scope: 'group', value: '-100' }],
      sharedActorRules: [{ scope: 'user', value: 'listed' }],
    },
  });
  const decision = ask(ctx, groupRun);
  await new Promise((resolve) => setImmediate(resolve));
  const inGroup = { isGroup: true, groupId: '-100' };
  assert.equal(ctx.approvals.canOffer({ userId: ctx.userId, agentId: ctx.agentId, trust: groupRun }), true);
  assert.equal(answer(ctx, '-100', 'allow', { ...inGroup, sender: 'guest' }), false);
  assert.equal(answer(ctx, '-100', 'allow', { ...inGroup, sender: 'stranger' }), false);
  assert.equal(answer(ctx, '-100', 'allow', { ...inGroup, sender: 'listed' }), true);
  assert.equal(await decision, 'approved');
});

test('an open policy lets people talk but not approve', async () => {
  const ctx = await setup({ policy: { schemaVersion: 3, directPolicy: 'open' } });
  const decision = ask(ctx);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(answer(ctx, 'dm_owner', 'allow', { sender: 'anyone', isGroup: false }), false);
  ctx.gate.shutdown();
  assert.equal(await decision, 'expired');
});

test('a prompt only goes where someone could answer it', async () => {
  const ctx = await setup();
  const { userId, approvals } = ctx;
  const can = (trust) => approvals.canOffer({ userId, agentId: ctx.agentId, trust });
  assert.equal(can(ownerDm), true);
  assert.equal(can(null), false);
  assert.equal(can({ audience: 'owner', origin: null }), false);
  assert.equal(can({ ...ownerDm, audience: 'public' }), false);
  assert.equal(can({ audience: 'owner', origin: { ...ownerDm.origin, platform: 'github' } }), false);
  // An unvetted DM, and a group with nobody listed.
  assert.equal(can({ ...ownerDm, audience: 'shared' }), false);
  assert.equal(can(groupRun), false);

  const listed = await setup({ policy: { schemaVersion: 3, sharedActorRules: [{ scope: 'user', value: 'x' }] } });
  assert.equal(listed.approvals.canOffer({ userId: listed.userId, agentId: 'agent-1', trust: groupRun }), true);
  const roleOnly = await setup({ policy: { schemaVersion: 3, sharedActorRules: [{ scope: 'role', value: 'x' }] } });
  assert.equal(roleOnly.approvals.canOffer({ userId: roleOnly.userId, agentId: 'agent-1', trust: groupRun }), false);

  const offline = await setup({ status: 'disconnected' });
  assert.equal(offline.approvals.canOffer({ userId: offline.userId, agentId: 'agent-1', trust: ownerDm }), false);
});

test('a run with no chat keeps the short app-only wait', async () => {
  const ctx = await setup();
  const payloads = [];
  ctx.gate._io = { to: () => ({ emit: (_event, payload) => payloads.push(payload) }) };
  const before = Date.now();
  void ask(ctx, null);
  const first = payloads[0];
  assert.ok(Date.parse(first.expiresAt) - before <= 31_000);
  assert.equal(ctx.sent.length, 0);

  void ask(ctx, ownerDm);
  assert.ok(Date.parse(payloads[1].expiresAt) - before > 60_000);
});

test('typing the answer works, and only a real answer from the right person is consumed', async () => {
  const ctx = await setup();
  delete ctx.platform.sendApprovalPrompt;
  const texts = [];
  ctx.platform.sendMessage = async (chatId, content) => {
    texts.push(content);
    return { messageId: 'm1' };
  };
  const consume = (content, sender = 'owner') => ctx.approvals.handleInboundText(ctx.userId, ctx.agentId, PLATFORM, {
    chatId: 'dm_owner', sender, isGroup: false, content,
  });

  assert.equal(consume('allow'), false, 'nothing is waiting yet');
  const decision = ask(ctx);
  await new Promise((resolve) => setImmediate(resolve));
  assert.match(texts[0], /Reply "allow", "always" or "deny"/);
  assert.equal(consume('allow me to explain'), false);
  assert.equal(consume('allow', 'stranger'), false);
  assert.equal(consume(' Disallow '), true);
  assert.equal(await decision, 'denied');
  assert.equal(consume('allow'), false, 'the answer is spent');
});

test('the app answering first takes the chat prompt away', async () => {
  const ctx = await setup();
  const decision = ask(ctx);
  await new Promise((resolve) => setImmediate(resolve));
  const [approvalId] = ctx.gate._pending.keys();
  ctx.gate.decide(approvalId, ctx.userId, 'approved', 'once');
  assert.equal(await decision, 'approved');
  assert.equal(ctx.removed.length, 1);
});

test('a prompt that arrives after the answer is removed again', async () => {
  const ctx = await setup();
  let release;
  ctx.platform.sendApprovalPrompt = () => new Promise((resolve) => { release = () => resolve({ promptId: 'late' }); });
  const decision = ask(ctx);
  await new Promise((resolve) => setImmediate(resolve));
  const [approvalId] = ctx.gate._pending.keys();
  ctx.gate.decide(approvalId, ctx.userId, 'denied', 'once');
  assert.equal(await decision, 'denied');
  release();
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(ctx.removed, [{ chatId: 'dm_owner', promptId: 'late' }]);
});

test('a failed prompt leaves the app to answer', async () => {
  const ctx = await setup();
  ctx.platform.sendApprovalPrompt = async () => { throw new Error('offline'); };
  void ask(ctx);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(ctx.approvals.prompts.size, 0);
  assert.equal(ctx.gate._pending.size, 1);
});

test('prompts hide credentials, and a group sees only the tool', () => {
  const { OPTIONS, promptText } = require('../../../server/services/messaging/chat_approvals');
  const token = `ghp_${'a'.repeat(36)}`;
  const direct = promptText({ toolName: 'execute_command', toolArgs: { command: `curl -H ${token} x` }, reason: null, isGroup: false });
  assert.ok(!direct.includes(token));
  assert.match(direct, /\[hidden\]/);
  const group = promptText({ toolName: 'execute_command', toolArgs: { command: 'cat /etc/secret' }, reason: 'why', isGroup: true });
  assert.equal(group, 'Allow execute_command?');
  assert.equal(OPTIONS.length, 3);
});
