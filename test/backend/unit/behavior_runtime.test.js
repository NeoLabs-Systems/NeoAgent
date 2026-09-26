'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

let ctx;
let user;
let agentId;
let behavior;

function groupMessage(content = 'room update', overrides = {}) {
  return {
    agentId,
    platform: 'telegram',
    chatId: 'group-1',
    messageId: `message-${content}`,
    sender: 'participant-1',
    senderName: 'Participant',
    content,
    isGroup: true,
    timestamp: new Date().toISOString(),
    ...overrides,
  };
}

function directMessage(content = 'direct update', overrides = {}) {
  return groupMessage(content, {
    chatId: 'direct-1',
    isGroup: false,
    ...overrides,
  });
}

beforeEach(async () => {
  ctx = createTestRuntime();
  user = await createTestUser(ctx.db);
  const { ensureMainAgent } = require('../../../server/services/agents/manager');
  agentId = ensureMainAgent(user.userId).id;
  behavior = require('../../../server/services/behavior');
});

afterEach(() => {
  require('../../../server/services/behavior/state').clearThreadStates();
  require('../../../server/services/behavior/gate/decision_log').clearDecisionLogs();
  teardownTestRuntime(ctx);
});

test('behavior overrides remain sparse and resolve agent, platform, then room', () => {
  behavior.setBehaviorConfig(user.userId, agentId, {
    minimumNeedScore: 0.7,
    platformOverrides: {
      telegram: { minimumNeedScore: 0.8 },
    },
    roomOverrides: {
      'telegram::group-1': { deliveryStyle: 'single' },
    },
  });

  const stored = behavior.getBehaviorConfig(user.userId, agentId);
  assert.deepEqual(stored.platformOverrides.telegram, { minimumNeedScore: 0.8 });
  assert.deepEqual(stored.roomOverrides['telegram::group-1'], { deliveryStyle: 'single' });

  const effective = behavior.resolveBehaviorConfig(user.userId, agentId, {
    platform: 'telegram',
    chatId: 'group-1',
    isGroup: true,
  });
  assert.equal(effective.minimumNeedScore, 0.8);
  assert.equal(effective.deliveryStyle, 'single');
});

test('prompt composer rejects duplicate contribution keys', async () => {
  const registry = behavior.createBehaviorRegistry([
    {
      id: 'one',
      composeContext() {
        return { key: 'same', content: 'one' };
      },
    },
    {
      id: 'two',
      composeContext() {
        return { key: 'same', content: 'two' };
      },
    },
  ]);

  await assert.rejects(
    registry.composeContext({ isModuleEnabled: () => true }),
    /Duplicate behavior prompt contribution: same/,
  );
});

test('low need score holds back without full run or memory work', async () => {
  let inferenceCalls = 0;
  let recallCalls = 0;
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured() {
        inferenceCalls += 1;
        return {
          parsed: {
            decision: 'speak',
            needScore: 0,
            confidence: 0.99,
            reasonCodes: ['could_comment'],
            urgency: 'low',
            rationale: 'A reply is possible but unnecessary.',
          },
          modelSelectionId: 'fast-model',
          usage: 42,
        };
      },
      trackBackgroundTask() {
        return Promise.resolve();
      },
    },
    memoryManager: {
      async recallMemory() {
        recallCalls += 1;
        return [];
      },
    },
  });
  const msg = groupMessage();
  pipeline.noteInbound({ userId: user.userId, agentId, msg });

  const result = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg,
  });

  assert.equal(result.engage, false);
  assert.equal(result.decision.decision, 'stay_silent');
  assert.equal(result.decision.confidence, 0.99);
  assert.equal(result.decision.needScore, 0);
  assert.equal(result.decision.usage, 42);
  assert.equal(inferenceCalls, 1);
  assert.equal(recallCalls, 0);
  assert.equal(
    ctx.db.prepare(
      "SELECT COUNT(*) AS count FROM agent_settings WHERE key LIKE 'behavior_state_%'",
    ).get().count,
    0,
  );
});

test('a zero need threshold is honored without truthy-default coercion', async () => {
  behavior.setBehaviorConfig(user.userId, agentId, {
    minimumNeedScore: 0,
  });
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured() {
        return {
          parsed: {
            decision: 'speak',
            needScore: 0,
            confidence: 1,
            reasonCodes: ['configured_threshold'],
            urgency: 'low',
            rationale: 'The configured threshold permits this response.',
          },
        };
      },
      trackBackgroundTask() {
        return Promise.resolve();
      },
    },
  });
  const msg = groupMessage();
  pipeline.noteInbound({ userId: user.userId, agentId, msg });

  const result = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg,
  });

  assert.equal(result.engage, true);
  assert.equal(result.decision.needScore, 0);
});

test('mention-only rooms make zero model calls', async () => {
  behavior.setBehaviorConfig(user.userId, agentId, {
    participationMode: 'mention_only',
  });
  let inferenceCalls = 0;
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured() {
        inferenceCalls += 1;
        throw new Error('should not run');
      },
      trackBackgroundTask() {
        return Promise.resolve();
      },
    },
  });

  const silentMsg = groupMessage('humans talking');
  pipeline.noteInbound({ userId: user.userId, agentId, msg: silentMsg });
  const silent = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg: silentMsg,
  });
  assert.equal(silent.engage, false);
  assert.equal(silent.decision.tokenPath, 'gate_skip');

  const mentionedMsg = groupMessage('direct question', { wasMentioned: true });
  pipeline.noteInbound({ userId: user.userId, agentId, msg: mentionedMsg });
  const mentioned = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg: mentionedMsg,
  });
  assert.equal(mentioned.engage, true);
  assert.equal(mentioned.decision.tokenPath, 'gate_skip');
  assert.equal(inferenceCalls, 0);
});

test('group decisions are logged newest first per platform', async () => {
  behavior.setBehaviorConfig(user.userId, agentId, {
    participationMode: 'mention_only',
  });
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      trackBackgroundTask() {
        return Promise.resolve();
      },
    },
  });

  await pipeline.handleInbound({ userId: user.userId, agentId, msg: groupMessage('humans talking') });
  await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg: groupMessage('direct question', { wasMentioned: true }),
  });

  const entries = pipeline.listDecisions(user.userId, agentId, 'telegram');
  assert.deepEqual(entries.map((entry) => entry.decision), ['speak', 'stay_silent']);
  assert.equal(entries[0].preview, 'direct question');
  assert.equal(entries[0].wasMentioned, true);
  assert.deepEqual(entries[1].reasonCodes, ['mention_only']);
  assert.deepEqual(pipeline.listDecisions(user.userId, agentId, 'discord'), []);
});

test('platform context turns by the agent reach the gate as the assistant', () => {
  const { buildDecisionPacket } = require('../../../server/services/behavior/signals');
  const packet = buildDecisionPacket({
    msg: groupMessage('what do you think of it', {
      channelContext: [
        { author: '[bot] NeoLabs (NeoLabs#4821)', content: 'posted the changelog', mine: true },
        { author: 'Neo (neo)', content: 'what do you think of it', mine: false },
      ],
    }),
    config: {},
    threadState: {},
  });
  assert.deepEqual(packet.room.recentMessages.map((item) => item.sender), ['assistant', 'Neo (neo)']);
});

test('plain name address engages without a mention tag', async () => {
  let inferenceCalls = 0;
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured() {
        inferenceCalls += 1;
        throw new Error('should not run');
      },
      trackBackgroundTask() {
        return Promise.resolve();
      },
    },
  });
  const msg = groupMessage('NeoLabs, stimmt doch oder?', {
    botUsername: 'NeoLabs',
    botDisplayName: 'NeoLabs',
  });
  pipeline.noteInbound({ userId: user.userId, agentId, msg });

  const result = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg,
  });

  assert.equal(result.engage, true);
  assert.equal(result.decision.tokenPath, 'gate_skip');
  assert.deepEqual(result.decision.reasonCodes, ['addressed_by_name']);
  assert.equal(inferenceCalls, 0);
});

test('name address does not bypass mention-only rooms', async () => {
  behavior.setBehaviorConfig(user.userId, agentId, {
    participationMode: 'mention_only',
  });
  let inferenceCalls = 0;
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured() {
        inferenceCalls += 1;
        throw new Error('should not run');
      },
      trackBackgroundTask() {
        return Promise.resolve();
      },
    },
  });
  const msg = groupMessage('NeoLabs antworte bitte', {
    botUsername: 'NeoLabs',
  });
  pipeline.noteInbound({ userId: user.userId, agentId, msg });
  const result = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg,
  });
  assert.equal(result.engage, false);
  assert.deepEqual(result.decision.reasonCodes, ['mention_only']);
  assert.equal(inferenceCalls, 0);
});

test('legacy 0.72 need scores migrate to the slightly more open default', () => {
  const migrated = behavior.normalizeStoredConfig({
    schemaVersion: 1,
    minimumNeedScore: 0.72,
  });
  assert.equal(migrated.schemaVersion, 2);
  assert.equal(migrated.minimumNeedScore, 0.58);

  const custom = behavior.normalizeStoredConfig({
    schemaVersion: 1,
    minimumNeedScore: 0.8,
  });
  assert.equal(custom.minimumNeedScore, 0.8);
});

test('name tokens do not match inside longer words', () => {
  assert.equal(behavior.contentAddressesAgent('the neon lights', ['Neo']), false);
  assert.equal(behavior.contentAddressesAgent('NeoLabs hab dich lieb', ['NeoLabs']), true);
  assert.equal(behavior.resolveAddressing({
    userId: user.userId,
    agentId,
    msg: { content: 'the main issue' },
  }).addressedByName, false);
});

test('a recent follow-up uses a slightly lower need threshold', async () => {
  behavior.markSpoke(user.userId, agentId, 'telegram', 'group-1');
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured() {
        return {
          parsed: {
            decision: 'speak',
            needScore: 0.5,
            confidence: 0.8,
            reasonCodes: ['follow_up'],
            urgency: 'medium',
            rationale: 'The room is waiting on a reply.',
          },
        };
      },
      trackBackgroundTask() {
        return Promise.resolve();
      },
    },
  });
  const msg = groupMessage('Okay dann antworte auf diese Nachricht');
  pipeline.noteInbound({ userId: user.userId, agentId, msg });
  const result = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg,
  });
  assert.equal(result.engage, true);
  assert.equal(result.decision.needScore, 0.5);
});

test('mentions always engage without a social decision call in automatic mode', async () => {
  let inferenceCalls = 0;
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured() {
        inferenceCalls += 1;
        throw new Error('should not run');
      },
      trackBackgroundTask() {
        return Promise.resolve();
      },
    },
  });
  const msg = groupMessage('direct question', { wasMentioned: true });
  pipeline.noteInbound({ userId: user.userId, agentId, msg });

  const result = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg,
  });

  assert.equal(result.engage, true);
  assert.equal(result.decision.tokenPath, 'gate_skip');
  assert.deepEqual(result.decision.reasonCodes, ['addressed']);
  assert.equal(inferenceCalls, 0);
});

test('per-group untagged policy is a hard gate before social intelligence', async () => {
  let inferenceCalls = 0;
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured() {
        inferenceCalls += 1;
        return {
          parsed: {
            decision: 'speak',
            needScore: 1,
            confidence: 1,
            reasonCodes: ['worthwhile'],
            urgency: 'medium',
            rationale: 'The message warrants a response.',
          },
        };
      },
      trackBackgroundTask() {
        return Promise.resolve();
      },
    },
  });

  behavior.setBehaviorConfig(user.userId, agentId, { enabled: false });
  const taggedOnly = groupMessage('ordinary room message', {
    accessPolicyAllowUntagged: false,
  });
  const silent = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg: taggedOnly,
  });
  assert.equal(silent.engage, false);
  assert.equal(inferenceCalls, 0);

  const tagged = groupMessage('@neo answer this', {
    accessPolicyAllowUntagged: false,
    wasMentioned: true,
  });
  const taggedResult = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg: tagged,
  });
  assert.equal(taggedResult.engage, true);
  assert.equal(inferenceCalls, 0);

  behavior.setBehaviorConfig(user.userId, agentId, {
    enabled: true,
    participationMode: 'automatic',
  });
  const sociallyEvaluated = groupMessage('another room message', {
    accessPolicyAllowUntagged: true,
  });
  const engaged = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg: sociallyEvaluated,
  });
  assert.equal(engaged.engage, true);
  assert.equal(inferenceCalls, 1);
});

test('disabling behavior or turn-taking uses the standard path without gate calls', async () => {
  let inferenceCalls = 0;
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured() {
        inferenceCalls += 1;
        throw new Error('should not run');
      },
      trackBackgroundTask() {
        return Promise.resolve();
      },
    },
  });
  for (const config of [
    { enabled: false },
    { modules: { turn_taking: { enabled: false } } },
  ]) {
    behavior.setBehaviorConfig(user.userId, agentId, config);
    const msg = groupMessage(`disabled-${JSON.stringify(config)}`);
    pipeline.noteInbound({ userId: user.userId, agentId, msg });
    const result = await pipeline.handleInbound({
      userId: user.userId,
      agentId,
      msg,
    });
    assert.equal(result.engage, true);
    assert.equal(result.decision.tokenPath, 'gate_skip');
  }
  assert.equal(inferenceCalls, 0);
});

test('group batching merges rapid messages from different participants', async () => {
  const { processInboundQueue } = require('../../../server/services/messaging/inbound_queue');
  const userQueues = Object.create(null);
  const executed = [];
  const first = groupMessage('first', {
    sender: 'participant-1',
    senderName: 'One',
  });
  const second = groupMessage('second', {
    sender: 'participant-2',
    senderName: 'Two',
  });
  const processing = processInboundQueue({
    userQueues,
    userId: user.userId,
    msg: first,
    batchWindowMs: 30,
    async executeMessage(message) {
      executed.push(message);
      return { result: { ok: true }, error: null };
    },
  });
  await new Promise((resolve) => setTimeout(resolve, 5));
  const queued = await processInboundQueue({
    userQueues,
    userId: user.userId,
    msg: second,
    batchWindowMs: 30,
    async executeMessage(message) {
      executed.push(message);
      return { result: { ok: true }, error: null };
    },
  });
  assert.equal(queued.queued, true);
  await processing;
  await queued.completion;

  assert.equal(executed.length, 1);
  assert.equal(executed[0].messageBatch.length, 2);
  assert.match(executed[0].content, /\[One\]: first/);
  assert.match(executed[0].content, /\[Two\]: second/);
});

test('a newer room turn suppresses stale delivery before Theory of Mind or send', async () => {
  let inferenceCalls = 0;
  let sendCalls = 0;
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured() {
        inferenceCalls += 1;
        return { parsed: { action: 'send' } };
      },
    },
  });
  const original = groupMessage('@neo first', { wasMentioned: true });
  const engaged = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg: original,
  });
  assert.equal(engaged.engage, true);
  const originalEpoch = engaged.decision.turnEpoch;

  // Silent room traffic should observe without invalidating the active speak turn.
  const silent = groupMessage('side chatter', {
    accessPolicyAllowUntagged: false,
  });
  pipeline.noteInbound({
    userId: user.userId,
    agentId,
    msg: silent,
  });
  const silentDecision = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg: silent,
  });
  assert.equal(silentDecision.engage, false);

  const stillCurrent = await pipeline.refineAndMaybeDeliver({
    userId: user.userId,
    agentId,
    msg: original,
    config: behavior.resolveBehaviorConfig(user.userId, agentId, {
      platform: original.platform,
      chatId: original.chatId,
      isGroup: true,
    }),
    draft: 'active reply',
    messagingManager: {
      async sendMessage() {
        sendCalls += 1;
        return { success: true };
      },
    },
    turnEpoch: originalEpoch,
    deliver: true,
  });
  assert.equal(stillCurrent.suppressed, false);
  assert.equal(sendCalls, 1);

  // A later engaged turn should supersede the older speak epoch.
  const newer = groupMessage('@neo newer', { wasMentioned: true });
  const next = await pipeline.handleInbound({
    userId: user.userId,
    agentId,
    msg: newer,
  });
  assert.equal(next.engage, true);

  const result = await pipeline.refineAndMaybeDeliver({
    userId: user.userId,
    agentId,
    msg: original,
    config: behavior.resolveBehaviorConfig(user.userId, agentId, {
      platform: original.platform,
      chatId: original.chatId,
      isGroup: true,
    }),
    draft: 'obsolete reply',
    messagingManager: {
      async sendMessage() {
        sendCalls += 1;
        return { success: true };
      },
    },
    turnEpoch: originalEpoch,
    deliver: true,
  });

  assert.equal(result.suppressed, true);
  assert.deepEqual(result.reasonCodes, ['stale_turn']);
  assert.equal(sendCalls, 1);
});

function writerEngine(calls, message, runModel = 'provider::main-model') {
  return {
    getRunMeta() {
      return { modelSelectionId: runModel };
    },
    async inferStructured(request) {
      calls.push(request);
      return {
        parsed: { message },
        modelSelectionId: request.modelId,
        usage: 40,
      };
    },
  };
}

function directConfig(msg) {
  return behavior.resolveBehaviorConfig(user.userId, agentId, {
    platform: msg.platform,
    chatId: msg.chatId,
    isGroup: false,
  });
}

function storeChat(msg, rows) {
  const insert = ctx.db.prepare(
    `INSERT INTO messages (user_id, agent_id, role, content, platform, platform_chat_id, created_at)
     VALUES (?, ?, ?, ?, ?, ?, datetime('now', ?))`,
  );
  rows.forEach(([role, content], index) => {
    insert.run(user.userId, agentId, role, content, msg.platform, msg.chatId, `-${rows.length - index} minutes`);
  });
}

test('direct messaging writes the final text from the chat, not from a chat-only draft', async () => {
  const calls = [];
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: writerEngine(calls, 'haha fair'),
  });
  const msg = directMessage('that was a joke btw');
  storeChat(msg, [
    ['user', 'working from home tomorrow, zero plans'],
    ['assistant', 'sounds relaxed'],
  ]);

  const result = await pipeline.refineAndMaybeDeliver({
    userId: user.userId,
    agentId,
    msg,
    config: directConfig(msg),
    draft: 'Understood! Let me know if you need anything else.',
    runId: 'run-chat',
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].modelId, 'provider::main-model');
  assert.equal(calls[0].purpose, 'general');
  assert.match(calls[0].system, /you're texting with Participant/);
  assert.match(calls[0].system, /working from home tomorrow, zero plans/);
  assert.match(calls[0].prompt, /you: sounds relaxed/);
  assert.match(calls[0].prompt, /Participant: that was a joke btw/);
  assert.doesNotMatch(calls[0].prompt, /Let me know if you need anything else/);
  assert.equal(result.content, 'haha fair');
  assert.equal(result.personaAction, 'revise');
  assert.deepEqual(result.reasonCodes, ['persona_writer', 'tom_disabled_or_direct']);
});

test('the writer receives the draft as results when the run did real work, on the voice model', async () => {
  ctx.db.prepare('INSERT INTO agent_runs (id, user_id, agent_id) VALUES (?, ?, ?)').run('run-work', user.userId, agentId);
  const insertStep = ctx.db.prepare(
    `INSERT INTO agent_steps (id, run_id, step_index, type, tool_name)
     VALUES (?, 'run-work', ?, ?, ?)`,
  );
  insertStep.run('step-1', 0, 'tool', 'web_search');
  insertStep.run('step-2', 1, 'messaging', 'send_message');
  behavior.setBehaviorConfig(user.userId, agentId, { voiceModelId: 'provider::voice-model' });
  const calls = [];
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: writerEngine(calls, 'last s3 at 00:47, platform 1'),
  });
  const msg = directMessage('when is the last train');

  const result = await pipeline.refineAndMaybeDeliver({
    userId: user.userId,
    agentId,
    msg,
    config: directConfig(msg),
    draft: 'The last S3 departs at 00:47 from platform 1.',
    runId: 'run-work',
  });

  assert.equal(calls[0].modelId, 'provider::voice-model');
  assert.match(calls[0].prompt, /your results from this turn[^\n]*\nThe last S3 departs at 00:47 from platform 1\./);
  assert.equal(result.content, 'last s3 at 00:47, platform 1');
});

test('the writer can end a direct chat without a reply', async () => {
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: writerEngine([], '[NO RESPONSE]'),
  });
  const msg = directMessage('k');
  let sendCalls = 0;

  const result = await pipeline.refineAndMaybeDeliver({
    userId: user.userId,
    agentId,
    msg,
    config: directConfig(msg),
    draft: 'Okay! Let me know if there is anything else.',
    messagingManager: {
      async sendMessage() {
        sendCalls += 1;
        return { success: true };
      },
    },
    deliver: true,
  });

  assert.equal(result.suppressed, true);
  assert.equal(sendCalls, 0);
});

test('owner agent instructions reach the writer as additions to its voice', async () => {
  ctx.db.prepare('UPDATE agents SET instructions = ? WHERE id = ?').run('You are Nova.', agentId);
  const calls = [];
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: writerEngine(calls, 'ja bin da'),
  });
  const msg = directMessage('hallo?');

  await pipeline.refineAndMaybeDeliver({
    userId: user.userId,
    agentId,
    msg,
    config: directConfig(msg),
    draft: 'Hello! How can I help?',
  });

  assert.match(calls[0].system, /## from the owner \(adds to how you text; it doesn't replace it\)\nYou are Nova\./);
});

test('the writer can answer with a reaction alone, sent before any text', async () => {
  const calls = [];
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured(request) {
        calls.push(request);
        return { parsed: { message: '[NO RESPONSE]', reaction: '❤️' } };
      },
    },
  });
  const msg = directMessage('good night');
  const reacted = [];
  let sendCalls = 0;

  const result = await pipeline.refineAndMaybeDeliver({
    userId: user.userId,
    agentId,
    msg,
    config: directConfig(msg),
    draft: 'Good night! Sleep well.',
    messagingManager: {
      supportsReactions: () => true,
      async sendReaction(_userId, platform, chatId, messageId, emoji) {
        reacted.push([platform, chatId, messageId, emoji]);
        return { success: true };
      },
      async sendMessage() {
        sendCalls += 1;
        return { success: true };
      },
    },
    deliver: true,
  });

  assert.match(calls[0].system, /react to their last message with one emoji/);
  assert.match(calls[0].prompt, /"reaction": "<one emoji, or empty>"/);
  assert.deepEqual(reacted, [['telegram', 'direct-1', msg.messageId, '❤️']]);
  assert.equal(sendCalls, 0);
  assert.equal(result.suppressed, true);
  assert.equal(result.reacted, true);
});

test('the writer is not offered reactions where the platform cannot send them', async () => {
  const calls = [];
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured(request) {
        calls.push(request);
        return { parsed: { message: 'night', reaction: '❤️' } };
      },
    },
  });
  const msg = directMessage('good night');

  const result = await pipeline.refineAndMaybeDeliver({
    userId: user.userId,
    agentId,
    msg,
    config: directConfig(msg),
    draft: 'Good night!',
    messagingManager: { supportsReactions: () => false },
  });

  assert.doesNotMatch(calls[0].system, /react to their last message/);
  assert.doesNotMatch(calls[0].prompt, /"reaction"/);
  assert.equal(result.content, 'night');
});

test('the writer sees profile facts, memories related to the message, and reactions in the chat', async () => {
  const calls = [];
  const recallQueries = [];
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: writerEngine(calls, 'lol'),
    memoryManager: {
      getCoreMemory: () => ({ name: 'Sam', active_context: 'scheduler run log' }),
      getUserProfile: () => ({ static: ['Works as a junior developer'], dynamic: ['Is shopping for a home server'] }),
      async recallMemory(_userId, query) {
        recallQueries.push(query);
        return [{ content: 'Promised to stop coding past midnight' }];
      },
    },
  });
  const msg = directMessage('who even pushes code at 2am');
  storeChat(msg, [['assistant', 'build is green']]);
  ctx.db.prepare(
    `INSERT INTO messages (user_id, agent_id, role, content, platform, platform_chat_id, metadata, created_at)
     VALUES (?, ?, 'user', '😂', ?, ?, ?, datetime('now', '-30 seconds'))`,
  ).run(user.userId, agentId, msg.platform, msg.chatId, JSON.stringify({ kind: 'reaction', targetText: 'build is green' }));

  await pipeline.refineAndMaybeDeliver({
    userId: user.userId,
    agentId,
    msg,
    config: directConfig(msg),
    draft: 'Committing late at night is common.',
  });

  assert.deepEqual(recallQueries, ['who even pushes code at 2am']);
  assert.match(calls[0].system, /- name: Sam/);
  assert.doesNotMatch(calls[0].system, /scheduler run log/);
  assert.match(calls[0].system, /- Is shopping for a home server/);
  assert.match(calls[0].system, /- Promised to stop coding past midnight/);
  assert.doesNotMatch(calls[0].system, /how they text[^#]*😂/);
  assert.match(calls[0].prompt, /Participant reacted 😂 to "build is green"/);
});

test('group replies without theory of mind bypass the direct-chat writer', async () => {
  behavior.setBehaviorConfig(user.userId, agentId, {
    modules: { theory_of_mind: { enabled: false } },
  });
  let inferenceCalls = 0;
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured() {
        inferenceCalls += 1;
        return { parsed: { message: 'unused' } };
      },
    },
  });
  const msg = groupMessage('anyone around');
  const turnEpoch = pipeline.noteInbound({ userId: user.userId, agentId, msg });

  const result = await pipeline.refineAndMaybeDeliver({
    userId: user.userId,
    agentId,
    msg,
    config: behavior.resolveBehaviorConfig(user.userId, agentId, {
      platform: msg.platform,
      chatId: msg.chatId,
      isGroup: true,
    }),
    draft: 'here',
    turnEpoch,
  });

  assert.equal(inferenceCalls, 0);
  assert.equal(result.content, 'here');
  assert.equal(result.reasonCodes[0], 'persona_writer_direct_only');
});

test('group messaging combines interaction voice and theory of mind in one model call', async () => {
  const calls = [];
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured(request) {
        calls.push(request);
        return {
          parsed: {
            action: 'revise',
            revisedContent: 'one useful room reply',
            risk: 'low',
            reasonCodes: ['kept_group_reply_brief'],
            rationale: 'The original draft was too long for the room.',
          },
          modelSelectionId: 'provider::review-model',
        };
      },
    },
  });
  const msg = groupMessage('can someone settle this');
  const turnEpoch = pipeline.noteInbound({ userId: user.userId, agentId, msg });
  const config = behavior.resolveBehaviorConfig(user.userId, agentId, {
    platform: msg.platform,
    chatId: msg.chatId,
    isGroup: true,
  });

  const result = await pipeline.refineAndMaybeDeliver({
    userId: user.userId,
    agentId,
    msg,
    config,
    draft: 'A long, assistant-like answer that should not dominate the room.',
    turnEpoch,
  });

  assert.equal(calls.length, 1);
  assert.match(calls[0].system, /Mandatory interaction-voice editing rules/);
  assert.match(calls[0].system, /multi-party chat/);
  assert.equal(result.content, 'one useful room reply');
  assert.deepEqual(result.reasonCodes, [
    'persona_refine_combined_with_tom',
    'kept_group_reply_brief',
  ]);
});

test('large messaging deliverables bypass the lightweight interaction-voice pass', async () => {
  let inferenceCalls = 0;
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      async inferStructured() {
        inferenceCalls += 1;
        throw new Error('large deliverables should not be rewritten');
      },
    },
  });
  const msg = directMessage('send the detailed report');
  const config = behavior.resolveBehaviorConfig(user.userId, agentId, {
    platform: msg.platform,
    chatId: msg.chatId,
    isGroup: false,
  });
  const draft = 'x'.repeat(2801);

  const result = await pipeline.refineAndMaybeDeliver({
    userId: user.userId,
    agentId,
    msg,
    config,
    draft,
  });

  assert.equal(inferenceCalls, 0);
  assert.equal(result.content, draft);
  assert.equal(result.personaAction, 'send');
  assert.deepEqual(result.reasonCodes, [
    'persona_refine_large_passthrough',
    'tom_disabled_or_direct',
  ]);
});

test('natural bubble delivery rechecks the room epoch after each inter-bubble gap', async () => {
  const sent = [];
  let current = true;
  const delivery = await behavior.deliverSocialReply({
    messagingManager: {
      async sendTyping() {},
      async sendMessage(_userId, _platform, _chatId, content) {
        sent.push(content);
        if (sent.length === 1) {
          setTimeout(() => {
            current = false;
          }, 5);
        }
        return { success: true };
      },
    },
    userId: user.userId,
    agentId,
    platform: 'telegram',
    chatId: 'group-1',
    content: 'First bubble.\n\nSecond bubble.',
    config: {
      deliveryStyle: 'natural_bubbles',
      maxBubbles: 4,
      bubbleGapMs: 20,
    },
    beforeBubble: () => current,
  });

  assert.equal(delivery.suppressed, true);
  assert.equal(delivery.deliveredBubbles, 1);
  assert.deepEqual(sent, ['First bubble.']);
});

test('natural bubble splitting follows intentional paragraph breaks, not sentence punctuation', () => {
  assert.deepEqual(
    behavior.splitIntoNaturalBubbles(
      'telegram',
      'Two sentences stay together. This is still one bubble.',
    ),
    ['Two sentences stay together. This is still one bubble.'],
  );
  assert.deepEqual(
    behavior.splitIntoNaturalBubbles(
      'telegram',
      'First beat.\n\nSecond beat.',
    ),
    ['First beat.', 'Second beat.'],
  );
});

test('silent automation annotates the durable message without inserting another copy', async () => {
  const { enqueueInboundMessage } = require('../../../server/services/messaging/inbound_store');
  const msg = groupMessage('no response needed');
  const queued = enqueueInboundMessage({
    userId: user.userId,
    agentId,
    platform: msg.platform,
    platformMessageId: msg.messageId,
    chatId: msg.chatId,
    content: msg.content,
    metadata: { sender: msg.sender, isGroup: true },
    createdAt: msg.timestamp,
    payload: msg,
  });
  msg.inboundJobId = queued.job.id;
  msg.inboundJobIds = [queued.job.id];
  let runCalls = 0;
  const { executeQueuedMessage } = require('../../../server/services/messaging/automation');

  const outcome = await executeQueuedMessage({
    messagingManager: {
      async markRead() {},
    },
    agentEngine: {
      async run() {
        runCalls += 1;
      },
    },
    behaviorPipeline: {
      async handleInbound() {
        return {
          engage: false,
          decision: {
            decision: 'stay_silent',
            tokenPath: 'gate_only',
            usage: 17,
          },
          config: behavior.cloneDefaults(),
        };
      },
    },
    userId: user.userId,
    msg,
  });

  assert.equal(outcome.error, null);
  assert.equal(outcome.result.silenced, true);
  assert.equal(runCalls, 0);
  const rows = ctx.db.prepare(
    "SELECT metadata FROM messages WHERE platform_msg_id = ? AND role = 'user'",
  ).all(msg.messageId);
  assert.equal(rows.length, 1);
  const metadata = JSON.parse(rows[0].metadata);
  assert.equal(metadata.socialDecision.decision, 'stay_silent');
  assert.equal(metadata.tokenPath, 'gate_only');
});

test('system prompt injects behavior notes once and excludes owner memory for shared rooms', async () => {
  const calls = [];
  const memoryManager = {
    getAssistantBehaviorNotes() {
      return 'Keep replies compact.';
    },
    getAssistantSelfState() {
      return { identity: { name: 'Neo' }, focus: { private: 'owner only' } };
    },
    async buildContext(_userId, options) {
      calls.push(options);
      return options.audience === 'shared' ? '' : '## Core Memory\nprivate owner fact';
    },
  };
  const { buildSystemPromptSections } = require('../../../server/services/ai/systemPrompt');
  const sections = await buildSystemPromptSections(user.userId, {
    agentId,
    triggerSource: 'messaging',
    source: 'telegram',
    chatId: 'group-1',
    memoryAudience: 'shared',
    additionalContext: 'room context',
  }, memoryManager);
  const prompt = `${sections.stable}\n${sections.dynamic}`;

  assert.equal(prompt.match(/MESSAGING VOICE/g)?.length, 1);
  assert.equal(prompt.match(/Keep replies compact\./g)?.length, 1);
  assert.doesNotMatch(prompt, /private owner fact/);
  assert.doesNotMatch(prompt, /owner only/);
  assert.equal(calls[0].audience, 'shared');
});

test('the persona module owns and can disable the legacy behavior prompt', async () => {
  behavior.setBehaviorConfig(user.userId, agentId, {
    modules: {
      persona: { enabled: false },
    },
  });
  const { buildSystemPromptSections } = require('../../../server/services/ai/systemPrompt');
  const sections = await buildSystemPromptSections(user.userId, {
    agentId,
    triggerSource: 'web',
    additionalContext: 'bypass prompt cache',
  }, {
    async buildContext() {
      return '';
    },
  });
  const prompt = `${sections.stable}\n${sections.dynamic}`;

  assert.doesNotMatch(prompt, /MESSAGING VOICE/);
});

test('system prompt caching keeps room-scoped behavior overrides isolated', async () => {
  behavior.setBehaviorConfig(user.userId, agentId, {
    roomOverrides: {
      'telegram::quiet-room': {
        modules: {
          persona: { enabled: false },
        },
      },
    },
  });
  const {
    buildSystemPromptSections,
    invalidateSystemPromptCache,
  } = require('../../../server/services/ai/systemPrompt');
  invalidateSystemPromptCache(user.userId, agentId);
  const memoryManager = {
    getAssistantBehaviorNotes() {
      return '';
    },
    getAssistantSelfState() {
      return { identity: {}, focus: {} };
    },
    async buildContext() {
      return '';
    },
  };
  const quiet = await buildSystemPromptSections(user.userId, {
    agentId,
    triggerSource: 'messaging',
    source: 'telegram',
    chatId: 'quiet-room',
    memoryAudience: 'shared',
  }, memoryManager);
  const normal = await buildSystemPromptSections(user.userId, {
    agentId,
    triggerSource: 'messaging',
    source: 'telegram',
    chatId: 'normal-room',
    memoryAudience: 'shared',
  }, memoryManager);

  assert.doesNotMatch(`${quiet.stable}\n${quiet.dynamic}`, /MESSAGING VOICE/);
  assert.match(`${normal.stable}\n${normal.dynamic}`, /MESSAGING VOICE/);
});

function jevGateEngine(answers, onModelCall = () => {}) {
  return {
    async decide({ phase, questions }) {
      assert.equal(phase, 'jev_turn_taking');
      assert.deepEqual(Object.keys(questions), ['speak', 'for_someone_else', 'urgency']);
      return answers;
    },
    async inferStructured() {
      onModelCall();
      return { parsed: { decision: 'stay_silent', needScore: 0 } };
    },
    trackBackgroundTask() {
      return Promise.resolve();
    },
  };
}

function jevAnswers(speak, forSomeoneElse, urgency = 1) {
  return {
    speak: { type: 'noul', noul: speak },
    for_someone_else: { type: 'noul', noul: forSomeoneElse },
    urgency: { type: 'score', score: urgency, confidence: 0.9, probabilities: {}, legend: {} },
  };
}

test('Jev decides the group gate without a model call', async () => {
  let modelCalls = 0;
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: jevGateEngine(jevAnswers(0.78, 0.12, 1.03), () => { modelCalls += 1; }),
  });
  const msg = groupMessage('Does anyone know if the 11:40 train from Bern still runs on Sundays?');
  pipeline.noteInbound({ userId: user.userId, agentId, msg });

  const result = await pipeline.handleInbound({ userId: user.userId, agentId, msg });

  assert.equal(result.engage, true);
  assert.equal(result.decision.tokenPath, 'jev_gate');
  assert.equal(result.decision.urgency, 'medium');
  assert.ok(Math.abs(result.decision.needScore - 0.6864) < 1e-9);
  assert.equal(modelCalls, 0);
});

test('Jev scores clear a slightly lower need threshold than model scores', async () => {
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: jevGateEngine(jevAnswers(0.8, 0.35)),
  });
  const msg = groupMessage('What was that movie with the time loop again?');
  pipeline.noteInbound({ userId: user.userId, agentId, msg });

  const result = await pipeline.handleInbound({ userId: user.userId, agentId, msg });

  // 0.8 * (1 - 0.35) = 0.52: under the 0.58 room default, over Jev's 0.50.
  assert.equal(result.engage, true);
});

test('messages meant for someone else stay quiet under Jev', async () => {
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: jevGateEngine(jevAnswers(0.59, 0.41)),
  });
  const msg = groupMessage('Around 9pm, can you pick me up?');
  pipeline.noteInbound({ userId: user.userId, agentId, msg });

  const result = await pipeline.handleInbound({ userId: user.userId, agentId, msg });

  assert.equal(result.engage, false);
  assert.ok(result.decision.reasonCodes.includes('below_need_threshold'));
});

test('the model gate still decides when Jev has no answer', async () => {
  let modelCalls = 0;
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: jevGateEngine(null, () => { modelCalls += 1; }),
  });
  const msg = groupMessage();
  pipeline.noteInbound({ userId: user.userId, agentId, msg });

  const result = await pipeline.handleInbound({ userId: user.userId, agentId, msg });

  assert.equal(modelCalls, 1);
  assert.equal(result.engage, false);
  assert.notEqual(result.decision.tokenPath, 'jev_gate');
});

async function withJevOn(run) {
  const saved = { policy: process.env.NEOAGENT_JEV, key: process.env.OPENROUTER_API_KEY };
  process.env.NEOAGENT_JEV = 'on';
  process.env.OPENROUTER_API_KEY = 'sk-or-test';
  try {
    await run();
  } finally {
    for (const [name, value] of [['NEOAGENT_JEV', saved.policy], ['OPENROUTER_API_KEY', saved.key]]) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  }
}

test('with Jev on, a Jev outage holds back instead of asking the model', async () => {
  await withJevOn(async () => {
    let modelCalls = 0;
    const pipeline = behavior.createBehaviorPipeline({
      agentEngine: jevGateEngine(null, () => { modelCalls += 1; }),
    });
    const msg = groupMessage();
    pipeline.noteInbound({ userId: user.userId, agentId, msg });

    const result = await pipeline.handleInbound({ userId: user.userId, agentId, msg });

    assert.equal(modelCalls, 0);
    assert.equal(result.engage, false);
    assert.equal(result.decision.failureCode, 'jev_unavailable');
    assert.deepEqual(result.decision.reasonCodes, ['prefer_hold_back', 'jev_unavailable']);
  });
});

test('with Jev on, background analysis waits for Jev to say speak', async () => {
  await withJevOn(async () => {
    let answers = jevAnswers(0.1, 0.1);
    let backgroundTasks = 0;
    const engine = jevGateEngine(null);
    engine.decide = async () => answers;
    engine.trackBackgroundTask = () => {
      backgroundTasks += 1;
      return Promise.resolve();
    };
    const pipeline = behavior.createBehaviorPipeline({ agentEngine: engine });

    const quiet = await pipeline.handleInbound({ userId: user.userId, agentId, msg: groupMessage('side chatter') });
    assert.equal(quiet.engage, false);
    assert.equal(backgroundTasks, 0);

    answers = jevAnswers(0.9, 0.05);
    const spoke = await pipeline.handleInbound({ userId: user.userId, agentId, msg: groupMessage('can you check this?') });
    assert.equal(spoke.engage, true);
    assert.equal(backgroundTasks, 1);
  });
});
