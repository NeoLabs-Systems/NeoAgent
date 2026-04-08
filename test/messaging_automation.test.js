const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const runtimeRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'neoagent-messaging-automation-'));
process.env.NEOAGENT_HOME = path.join(runtimeRoot, 'home');
process.env.NEOAGENT_DATA_DIR = path.join(runtimeRoot, 'data');
process.env.NEOAGENT_AGENT_DATA_DIR = path.join(runtimeRoot, 'agent-data');

const db = require('../server/db/database');
const {
  buildIncomingPrompt,
  processQueuedMessage,
} = require('../server/services/messaging/automation');

function createUser(username = `user-${Date.now()}-${Math.random()}`) {
  return db
    .prepare('INSERT INTO users (username, password) VALUES (?, ?)')
    .run(username, 'test-password').lastInsertRowid;
}

function waitUntil(predicate) {
  return new Promise((resolve, reject) => {
    const started = Date.now();
    const tick = () => {
      if (predicate()) {
        resolve();
        return;
      }
      if (Date.now() - started > 1000) {
        reject(new Error('Timed out waiting for condition'));
        return;
      }
      setImmediate(tick);
    };
    tick();
  });
}

test('incoming messaging prompt includes group sender username and tag', () => {
  const prompt = buildIncomingPrompt({
    platform: 'discord',
    chatId: 'channel-123',
    channelName: 'general',
    groupName: 'Test Guild',
    sender: 'user-123',
    senderName: 'Neo in #general (Test Guild)',
    senderDisplayName: 'Neo',
    senderUsername: 'neo',
    senderTag: 'neo#1234',
    content: 'Can you check this?',
    isGroup: true,
  });

  assert.match(prompt, /sender_id: user-123/);
  assert.match(prompt, /sender_username: neo/);
  assert.match(prompt, /sender_tag: neo#1234/);
  assert.match(prompt, /channel_name: general/);
  assert.match(prompt, /do not treat the chat, channel, or group name as the speaker/);
});

test('queued group messages from different senders are not merged', async () => {
  const userId = createUser();
  const userQueues = {};
  const prompts = [];
  let releaseFirst;

  const messagingManager = {
    markRead: async () => {},
    sendTyping: async () => {},
    on: () => {},
    off: () => {},
  };
  const agentEngine = {
    run: async (_userId, prompt) => {
      prompts.push(prompt);
      if (prompts.length === 1) {
        await new Promise((resolve) => {
          releaseFirst = resolve;
        });
      }
    },
  };

  const firstRun = processQueuedMessage({
    userQueues,
    messagingManager,
    agentEngine,
    userId,
    msg: {
      platform: 'discord',
      chatId: 'channel-123',
      sender: 'alice-id',
      senderUsername: 'alice',
      content: 'first',
      isGroup: true,
      messageId: 'm1',
      timestamp: new Date().toISOString(),
    },
  });

  await waitUntil(() => prompts.length === 1);

  await processQueuedMessage({
    userQueues,
    messagingManager,
    agentEngine,
    userId,
    msg: {
      platform: 'discord',
      chatId: 'channel-123',
      sender: 'bob-id',
      senderUsername: 'bob',
      content: 'second',
      isGroup: true,
      messageId: 'm2',
      timestamp: new Date().toISOString(),
    },
  });

  const queue = userQueues[`${userId}:main`];
  assert.equal(queue.pending.length, 1);
  assert.equal(queue.pending[0].sender, 'bob-id');

  releaseFirst();
  await firstRun;

  assert.equal(prompts.length, 2);
  assert.match(prompts[0], /sender_username: alice/);
  assert.match(prompts[0], /first/);
  assert.match(prompts[1], /sender_username: bob/);
  assert.match(prompts[1], /second/);
});
