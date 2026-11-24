'use strict';

const assert = require('node:assert/strict');
const { afterEach, beforeEach, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

const LID = '212064094126255@lid';
const PN = '4915100000002@s.whatsapp.net';

let ctx;
let user;

beforeEach(async () => {
  ctx = createTestRuntime();
  user = await createTestUser(ctx.db);
});

afterEach(() => {
  teardownTestRuntime(ctx);
});

test('a WhatsApp direct chat lists its LID and its number, LID first', async () => {
  const { WhatsAppPlatform } = require('../../../server/services/messaging/whatsapp');
  const platform = new WhatsAppPlatform();
  platform.sock = {
    signalRepository: {
      lidMapping: {
        getPNForLID: async (lid) => (lid === LID ? '4915100000002:0@s.whatsapp.net' : null),
        getLIDForPN: async (pn) => (pn === PN ? '212064094126255:0@lid' : null),
      },
    },
  };
  assert.deepEqual(await platform.conversationChatIds(LID), [LID, PN]);
  assert.deepEqual(await platform.conversationChatIds(PN), [LID, PN]);
  assert.deepEqual(await platform.conversationChatIds('4915100000009@s.whatsapp.net'), ['4915100000009@s.whatsapp.net']);
  assert.deepEqual(await platform.conversationChatIds('120363123456789012@g.us'), ['120363123456789012@g.us']);
});

function managerWithAliases() {
  const { MessagingManager } = require('../../../server/services/messaging/manager');
  const manager = new MessagingManager({ to: () => ({ emit() {} }) });
  const agentId = manager._agentId(user.userId, {});
  manager.platforms.set(manager._key(user.userId, agentId, 'whatsapp'), {
    conversationChatIds: async (chatId) => ([LID, PN].includes(chatId) ? [LID, PN] : [chatId]),
    sendMessage: async () => ({ success: true, messageId: 'sent-1' }),
  });
  return { manager, agentId };
}

function addConversation(agentId, chatId) {
  const id = `conversation-${chatId}`;
  ctx.db.prepare(
    'INSERT INTO conversations (id, user_id, agent_id, platform, platform_chat_id, title) VALUES (?, ?, ?, ?, ?, ?)'
  ).run(id, user.userId, agentId, 'whatsapp', chatId, chatId);
  return id;
}

test('a task delivery to the number lands in the chat the person writes in', async () => {
  const { manager, agentId } = managerWithAliases();
  const older = addConversation(agentId, PN);
  const chat = addConversation(agentId, LID);
  ctx.db.prepare('INSERT INTO conversation_messages (conversation_id, role, content) VALUES (?, ?, ?)')
    .run(chat, 'user', 'what did the recap say?');

  assert.equal(await manager.getOrCreateConversation(user.userId, 'whatsapp', LID, { agentId }), chat);
  await manager.sendMessage(user.userId, 'whatsapp', PN, 'evening recap: ribs tomorrow', { agentId, persistConversation: true });

  const rows = (id) => ctx.db.prepare('SELECT content FROM conversation_messages WHERE conversation_id = ? ORDER BY id')
    .all(id).map((row) => row.content);
  assert.deepEqual(rows(chat), ['what did the recap say?', 'evening recap: ribs tomorrow']);
  assert.deepEqual(rows(older), []);

  // The next task run reads that same chat.
  const { buildTaskChatContext } = require('../../../server/services/tasks/run_context');
  const { priorMessages } = await buildTaskChatContext({
    messagingManager: manager,
    userId: user.userId,
    agentId,
    notifyTarget: { platform: 'whatsapp', to: PN },
  });
  assert.deepEqual(priorMessages.map((message) => message.content), ['what did the recap say?', 'evening recap: ribs tomorrow']);
});

test('a new chat is keyed by its preferred address and /clear removes every address', async () => {
  const { manager, agentId } = managerWithAliases();
  const created = await manager.getOrCreateConversation(user.userId, 'whatsapp', PN, { agentId, title: 'whatsapp — Neo' });
  const row = ctx.db.prepare('SELECT platform_chat_id, title FROM conversations WHERE id = ?').get(created);
  assert.deepEqual(row, { platform_chat_id: LID, title: 'whatsapp — Neo' });
  assert.equal(await manager.getOrCreateConversation(user.userId, 'whatsapp', LID, { agentId }), created);

  addConversation(agentId, PN);
  const { CommandRouter } = require('../../../server/services/commands/router');
  const router = new CommandRouter({ locals: { messagingManager: manager } });
  await router.handleClear(user.userId, { source: 'messaging' }, { agentId, platform: 'whatsapp', chatId: LID });
  const left = ctx.db.prepare("SELECT COUNT(*) AS count FROM conversations WHERE user_id = ? AND platform = 'whatsapp'").get(user.userId);
  assert.equal(left.count, 0);
});
