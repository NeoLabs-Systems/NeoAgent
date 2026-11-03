'use strict';

// A shared Telegram bot or WhatsApp number must only ever reach the person it is
// linked to, however an agent asks. These drive the real adapters with their
// transport stubbed, so what is asserted is what would actually leave the server.
// A personal connection sends as its owner and stays unrestricted.

const assert = require('node:assert/strict');
const { afterEach, beforeEach, describe, test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../helpers/db');

const TOKEN = '123456:abcdefghijklmnopqrstuvwxyz';
const OWN_NUMBER = '491700000001';
const STRANGER_NUMBER = '491799999999';

let ctx;
let alice;
let bob;
let manager;
let store;
let wire;

function agentOf(user) {
  return manager._agentId(user.userId, {});
}

function installRealAdapters() {
  const { TelegramPlatform } = require('../../server/services/messaging/telegram');
  const { WhatsAppPlatform } = require('../../server/services/messaging/whatsapp');

  class WiredTelegram extends TelegramPlatform {
    async connect() {
      const record = (kind) => async (chatId) => {
        wire.push({ kind, platform: 'telegram', to: String(chatId), via: this.botToken });
        return { message_id: wire.length };
      };
      this._bot = {
        stop() {},
        telegram: {
          sendMessage: record('message'),
          sendChatAction: record('typing'),
          setMessageReaction: record('reaction'),
        },
      };
      this._botUser = { id: 42, username: 'shared_bot' };
      this.status = 'connected';
      this.emit('connected');
      return { status: 'connected' };
    }
  }

  class WiredWhatsApp extends WhatsAppPlatform {
    async connect() {
      const authDir = this.authDir;
      this.sock = {
        user: { id: '491700000000:1@s.whatsapp.net' },
        ev: { removeAllListeners() {} },
        end() {},
        async readMessages() {},
        async sendPresenceUpdate(_presence, jid) {
          wire.push({ kind: 'typing', platform: 'whatsapp', to: jid, via: authDir });
        },
        async sendMessage(jid, payload) {
          wire.push({
            kind: payload.react ? 'reaction' : 'message',
            platform: 'whatsapp',
            to: jid,
            via: authDir,
          });
          return { key: { id: `sent-${wire.length}` } };
        },
      };
      this.status = 'connected';
      this.emit('connected');
      return { status: this.status };
    }
  }

  manager.platformTypes.telegram = WiredTelegram;
  manager.platformTypes.whatsapp = WiredWhatsApp;
}

async function sharedAdapter(platform) {
  store.configureConnection(platform, platform === 'telegram' ? { botToken: TOKEN } : {});
  await manager.shared.reconcile();
  return manager.shared.adapters.get(platform).adapter;
}

async function linkOnTelegram(user, senderId) {
  const adapter = await sharedAdapter('telegram');
  const { code } = store.createLinkCode('telegram', user.userId, agentOf(user));
  await adapter._handleMessage({
    message: {
      message_id: 1,
      date: 1,
      text: `/start ${code}`,
      from: { id: Number(senderId), first_name: 'Linked' },
      chat: { id: Number(senderId), type: 'private' },
    },
  });
  await settle();
  wire.length = 0;
  return adapter;
}

function whatsappMessage({ remoteJid, remoteJidAlt, text, id = 'wa-1' }) {
  return { key: { id, remoteJid, remoteJidAlt }, message: { conversation: text } };
}

function whatsappGate(adapter, { remoteJid, remoteJidAlt, text = 'hello' }) {
  const isGroup = remoteJid.endsWith('@g.us');
  return adapter.evaluateAccess(adapter._accessContext(
    whatsappMessage({ remoteJid, remoteJidAlt, text }),
    { chatId: remoteJid, isGroup, sender: remoteJid, content: text, pushName: 'Linked' },
  ));
}

async function linkOnWhatsApp(user, number = OWN_NUMBER) {
  const adapter = await sharedAdapter('whatsapp');
  const { code } = store.createLinkCode('whatsapp', user.userId, agentOf(user));
  whatsappGate(adapter, { remoteJid: `${number}@s.whatsapp.net`, text: code });
  await settle();
  wire.length = 0;
  return adapter;
}

async function settle() {
  await new Promise((resolve) => setImmediate(resolve));
  await new Promise((resolve) => setImmediate(resolve));
}

function sendAs(user, platform, to) {
  return manager.sendMessage(user.userId, platform, to, 'hello', { agentId: agentOf(user) });
}

beforeEach(async () => {
  ctx = createTestRuntime();
  alice = await createTestUser(ctx.db);
  bob = await createTestUser(ctx.db);
  const { MessagingManager } = require('../../server/services/messaging/manager');
  store = require('../../server/services/messaging/shared_store');
  manager = new MessagingManager({ to() { return { emit() {} }; } });
  wire = [];
  installRealAdapters();
});

afterEach(async () => {
  await manager.shared.stop();
  teardownTestRuntime(ctx);
});

describe('a shared Telegram bot', () => {
  const hostile = ['dm_777', '777', '-1001234567', '@durov', 'dm_555x', 'dm_dm_555', '555 ', '', ' '];

  test('reaches the linked person, in any form of their own chat id', async () => {
    await linkOnTelegram(alice, '555');
    await sendAs(alice, 'telegram', 'dm_555');
    await sendAs(alice, 'telegram', '555');
    assert.deepEqual(wire.map((call) => call.to), ['555', '555']);
  });

  for (const to of hostile) {
    test(`refuses ${JSON.stringify(to)}`, async () => {
      await linkOnTelegram(alice, '555');
      const attempt = to.trim() === '555'
        // Whitespace around one's own id still resolves to one's own chat.
        ? sendAs(alice, 'telegram', to).then(() => null)
        : assert.rejects(sendAs(alice, 'telegram', to));
      await attempt;
      assert.ok(wire.every((call) => call.to === '555'), JSON.stringify(wire));
    });
  }

  test('typing, read receipts and reactions cannot reach anyone else either', async () => {
    await linkOnTelegram(alice, '555');
    const options = { agentId: agentOf(alice) };
    await assert.rejects(manager.sendTyping(alice.userId, 'telegram', 'dm_777', true, options));
    await assert.rejects(manager.sendReaction(alice.userId, 'telegram', 'dm_777', '1', '👍', options));
    await assert.rejects(manager.markRead(alice.userId, 'telegram', 'dm_777', '1', options));
    assert.deepEqual(wire, []);
  });

  test('one linked person cannot message another linked person', async () => {
    await linkOnTelegram(alice, '555');
    await linkOnTelegram(bob, '666');
    await assert.rejects(sendAs(alice, 'telegram', 'dm_666'));
    await assert.rejects(sendAs(bob, 'telegram', 'dm_555'));
    assert.deepEqual(wire, []);
  });

  test('an agent with no link has no way to send through it', async () => {
    await linkOnTelegram(alice, '555');
    await assert.rejects(sendAs(bob, 'telegram', 'dm_555'), /not connected/);
    assert.deepEqual(wire, []);
  });

  test('a message from a group cannot redirect replies there', async () => {
    const adapter = await linkOnTelegram(alice, '555');
    await adapter._handleMessage({
      message: {
        message_id: 2,
        date: 1,
        text: '@shared_bot hello',
        from: { id: 555, first_name: 'Linked' },
        chat: { id: -900, type: 'group', title: 'G' },
      },
    });
    await settle();
    assert.equal(store.findLinkForUser('telegram', alice.userId).chat_id, 'dm_555');
    assert.deepEqual(wire, []);
  });
});

describe('a shared WhatsApp number', () => {
  const ownJid = `${OWN_NUMBER}@s.whatsapp.net`;

  test('reaches the linked person, in any form of their own number', async () => {
    await linkOnWhatsApp(alice);
    await sendAs(alice, 'whatsapp', ownJid);
    await sendAs(alice, 'whatsapp', OWN_NUMBER);
    await sendAs(alice, 'whatsapp', `+${OWN_NUMBER}`);
    assert.deepEqual(wire.map((call) => call.to), [ownJid, ownJid, ownJid]);
  });

  for (const to of [
    STRANGER_NUMBER,
    `${STRANGER_NUMBER}@s.whatsapp.net`,
    `+${STRANGER_NUMBER}`,
    '999@lid',
    '120363000000000000@g.us',
    'status@broadcast',
    '1234567@broadcast',
    '',
  ]) {
    test(`refuses ${JSON.stringify(to)}`, async () => {
      await linkOnWhatsApp(alice);
      await assert.rejects(sendAs(alice, 'whatsapp', to));
      assert.deepEqual(wire, []);
    });
  }

  for (const remoteJid of ['status@broadcast', `${STRANGER_NUMBER}@broadcast`, '123@newsletter']) {
    test(`a linked person posting via ${remoteJid} cannot redirect replies`, async () => {
      const adapter = await linkOnWhatsApp(alice);
      const access = whatsappGate(adapter, { remoteJid, remoteJidAlt: ownJid });
      assert.equal(access.allowed, false);
      assert.equal(store.findLinkForUser('whatsapp', alice.userId).chat_id, ownJid);
      await sendAs(alice, 'whatsapp', OWN_NUMBER);
      assert.deepEqual(wire.map((call) => call.to), [ownJid]);
    });
  }

  test('a code sent from a broadcast cannot create a link', async () => {
    const adapter = await sharedAdapter('whatsapp');
    const { code } = store.createLinkCode('whatsapp', alice.userId, agentOf(alice));
    whatsappGate(adapter, { remoteJid: `${STRANGER_NUMBER}@broadcast`, remoteJidAlt: ownJid, text: code });
    await settle();
    assert.equal(store.findLinkForUser('whatsapp', alice.userId), null);
  });

  test('a phone chat belonging to someone else cannot become the link\'s chat', async () => {
    const adapter = await linkOnWhatsApp(alice);
    const access = whatsappGate(adapter, {
      remoteJid: `${STRANGER_NUMBER}@s.whatsapp.net`,
      remoteJidAlt: ownJid,
    });
    assert.equal(access.allowed, false);
    assert.equal(store.findLinkForUser('whatsapp', alice.userId).chat_id, ownJid);
  });

  test('moving to a LID address keeps replies with the same person', async () => {
    const adapter = await linkOnWhatsApp(alice);
    const access = whatsappGate(adapter, { remoteJid: '888@lid', remoteJidAlt: ownJid });
    assert.equal(access.allowed, true);
    await sendAs(alice, 'whatsapp', '888@lid');
    assert.deepEqual(wire.map((call) => call.to), ['888@lid']);
    await assert.rejects(sendAs(alice, 'whatsapp', '999@lid'));
  });

  test('a stored chat that is not the person\'s own is never delivered to', async () => {
    await linkOnWhatsApp(alice);
    ctx.db.prepare('UPDATE messaging_identity_links SET chat_id = ? WHERE user_id = ?')
      .run(`${STRANGER_NUMBER}@broadcast`, alice.userId);
    await assert.rejects(sendAs(alice, 'whatsapp', `${STRANGER_NUMBER}@broadcast`));
    assert.deepEqual(wire, []);
  });
});

describe('the agent\'s send_message tool', () => {
  async function runTool(user, args) {
    const { executeTool } = require('../../server/services/ai/tools');
    return executeTool('send_message', { content: 'hello', ...args }, {
      userId: user.userId,
      agentId: agentOf(user),
      runId: `run-${wire.length}-${Date.now()}`,
      app: { locals: { messagingManager: manager } },
      messagingManager: manager,
    }, { messagingManager: manager, activeRuns: new Map(), getRunMeta: () => null });
  }

  test('a shared account delivers to the owner and nobody else', async () => {
    await linkOnTelegram(alice, '555');
    await runTool(alice, { platform: 'telegram', to: 'dm_555' });
    assert.deepEqual(wire.map((call) => call.to), ['555']);

    wire.length = 0;
    const refused = await runTool(alice, { platform: 'telegram', to: 'dm_777' }).catch((error) => ({
      error: error.message,
    }));
    assert.deepEqual(wire, []);
    assert.match(JSON.stringify(refused), /own linked chat/);
  });

  test('a personal bot can still write to anyone', async () => {
    const agentId = agentOf(alice);
    await manager.connectPlatform(alice.userId, 'telegram', { botToken: 'alice-own-token' }, {
      agentId,
      userInitiated: true,
    });
    await runTool(alice, { platform: 'telegram', to: 'dm_777' });
    assert.deepEqual(wire.map((call) => call.to), ['777']);
  });
});

describe('personal connections', () => {
  test('a personal bot sends to anyone, even with a shared bot on the server', async () => {
    await linkOnTelegram(bob, '666');
    const agentId = agentOf(alice);
    await manager.connectPlatform(alice.userId, 'telegram', { botToken: 'alice-own-token' }, {
      agentId,
      userInitiated: true,
    });
    for (const to of ['dm_777', '777', '-1001234567', 'dm_666']) await sendAs(alice, 'telegram', to);
    assert.deepEqual(wire.map((call) => call.to), ['777', '777', '-1001234567', '666']);
    assert.ok(wire.every((call) => call.via === 'alice-own-token'), 'sent as her own bot');
  });

  test('a personal number sends to anyone, even with a shared number on the server', async () => {
    await linkOnWhatsApp(bob, '491700000002');
    const agentId = agentOf(alice);
    await manager.connectPlatform(alice.userId, 'whatsapp', {}, { agentId, userInitiated: true });
    await sendAs(alice, 'whatsapp', STRANGER_NUMBER);
    await sendAs(alice, 'whatsapp', '120363000000000000@g.us');
    assert.deepEqual(wire.map((call) => call.to), [
      `${STRANGER_NUMBER}@s.whatsapp.net`,
      '120363000000000000@g.us',
    ]);
    const sharedDir = manager.shared.adapters.get('whatsapp').adapter.authDir;
    assert.ok(wire.every((call) => call.via !== sharedDir), 'sent as her own number');
  });

  test('leaving the shared account for your own restores free sending, as you', async () => {
    await linkOnTelegram(alice, '555');
    await assert.rejects(sendAs(alice, 'telegram', 'dm_777'));
    await manager.connectPlatform(alice.userId, 'telegram', { botToken: 'alice-own-token' }, {
      agentId: agentOf(alice),
      userInitiated: true,
    });
    await sendAs(alice, 'telegram', 'dm_777');
    assert.deepEqual(wire, [{ kind: 'message', platform: 'telegram', to: '777', via: 'alice-own-token' }]);
  });

  test('returning to the shared account takes that freedom away again', async () => {
    const agentId = agentOf(alice);
    await manager.connectPlatform(alice.userId, 'telegram', { botToken: 'alice-own-token' }, {
      agentId,
      userInitiated: true,
    });
    await linkOnTelegram(alice, '555');
    await assert.rejects(sendAs(alice, 'telegram', 'dm_777'));
    assert.deepEqual(wire, []);
  });
});
