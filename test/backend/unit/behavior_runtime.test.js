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

test('direct messaging uses the run model for one lightweight interaction-voice pass', async () => {
  const calls = [];
  const pipeline = behavior.createBehaviorPipeline({
    agentEngine: {
      getRunMeta(runId) {
        assert.equal(runId, 'run-voice');
        return { modelSelectionId: 'provider::main-model' };
      },
      async inferStructured(request) {
        calls.push(request);
        return {
          parsed: {
            action: 'revise',
            revisedContent: 'natural final text',
            reasonCodes: ['removed_assistant_framing'],
            rationale: 'The draft had a generic service preamble.',
          },
          modelSelectionId: request.modelId,
          usage: 51,
        };
      },
    },
  });
  const msg = directMessage('can you make this sound normal');
  const config = behavior.resolveBehaviorConfig(user.userId, agentId, {
    platform: msg.platform,
    chatId: msg.chatId,
    isGroup: false,
  });

  const result = await pipeline.refineAndMaybeDeliver({
    userId: user.userId,
    agentId,
    msg,
    config,
    draft: 'Here is a polished response. Let me know if you need anything else.',
    runId: 'run-voice',
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].modelId, 'provider::main-model');
  assert.equal(calls[0].purpose, 'general');
  assert.equal(result.content, 'natural final text');
  assert.equal(result.personaAction, 'revise');
  assert.deepEqual(result.reasonCodes, [
    'removed_assistant_framing',
    'tom_disabled_or_direct',
  ]);
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

  assert.equal(prompt.match(/MESSAGING VOICE — USER-FACING OUTPUT CONTRACT/g)?.length, 1);
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

  assert.doesNotMatch(prompt, /MESSAGING VOICE — USER-FACING OUTPUT CONTRACT/);
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

  assert.doesNotMatch(`${quiet.stable}\n${quiet.dynamic}`, /MESSAGING VOICE — USER-FACING OUTPUT CONTRACT/);
  assert.match(`${normal.stable}\n${normal.dynamic}`, /MESSAGING VOICE — USER-FACING OUTPUT CONTRACT/);
});
