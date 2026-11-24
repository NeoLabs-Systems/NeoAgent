'use strict';

const assert = require('node:assert/strict');
const EventEmitter = require('node:events');
const { afterEach, beforeEach, test } = require('node:test');

const {
  createTestRuntime,
  createTestUser,
  teardownTestRuntime,
} = require('../../helpers/db');

const TOKEN = '123456:abcdefghijklmnopqrstuvwxyz';

class FakeAdapter extends EventEmitter {
  constructor(config = {}) {
    super();
    this.config = config;
    this.status = 'disconnected';
    this.sent = [];
    this.reactions = [];
    FakeAdapter.last = this;
  }

  async connect() {
    this.status = 'connected';
    this.emit('connected');
  }

  async disconnect() { this.status = 'disconnected'; }
  getStatus() { return this.status; }
  getAuthInfo() { return { username: 'shared_bot', id: 1, qrCode: 'SECRET-QR', number: '491700000000' }; }

  async sendMessage(to, content) {
    this.sent.push({ to, content });
    return { success: true, messageId: `sent-${this.sent.length}` };
  }

  async sendReaction(chatId, messageId, emoji) {
    this.reactions.push({ chatId, messageId, emoji });
  }

  // What a real adapter does on inbound: ask the gate, then emit if allowed.
  receive({ senderId, text, isDirect = true, chatId = `dm_${senderId}`, messageId = 'm1', senderName = 'Sender' }) {
    const access = this.config.accessGate({
      platform: 'telegram', senderId, chatId, isDirect, isShared: !isDirect, text, messageId, senderName,
    });
    if (access.allowed) {
      this.emit('message', {
        platform: 'telegram', chatId, sender: senderId, senderName, content: text, isGroup: !isDirect, messageId,
      });
    }
    return access;
  }
}

let ctx;
let alice;
let bob;
let manager;
let store;
let handled;
let emitted;

async function flush() {
  await new Promise((resolve) => setImmediate(resolve));
  await new Promise((resolve) => setImmediate(resolve));
}

async function setUpSharedTelegram(input = {}) {
  store.configureConnection('telegram', { botToken: TOKEN, ...input });
  await manager.shared.reconcile();
  return FakeAdapter.last;
}

function agentOf(user) {
  return manager._agentId(user.userId, {});
}

async function link(adapter, user, senderId) {
  const { code } = manager.shared.startLink(user.userId, agentOf(user), 'telegram');
  adapter.receive({ senderId, text: `/start ${code}` });
  await flush();
}

beforeEach(async () => {
  ctx = createTestRuntime();
  alice = await createTestUser(ctx.db);
  bob = await createTestUser(ctx.db);
  const { MessagingManager } = require('../../../server/services/messaging/manager');
  store = require('../../../server/services/messaging/shared_store');
  emitted = [];
  manager = new MessagingManager({
    to(room) {
      return { emit(event, payload) { emitted.push({ room, event, payload }); } };
    },
  });
  manager.platformTypes.telegram = FakeAdapter;
  handled = [];
  manager.registerHandler(async (userId, msg) => {
    handled.push({ userId, msg });
    return {};
  });
});

afterEach(async () => {
  await manager.shared.stop();
  teardownTestRuntime(ctx);
});

test('an unlinked sender reaches nothing: no job, no message row, no reply', async () => {
  const adapter = await setUpSharedTelegram();
  const access = adapter.receive({ senderId: '900', text: 'hello' });
  await flush();

  assert.equal(access.allowed, false);
  assert.equal(handled.length, 0);
  assert.equal(adapter.sent.length, 0);
  assert.equal(ctx.db.prepare('SELECT COUNT(*) AS n FROM messaging_inbound_jobs').get().n, 0);
  assert.equal(ctx.db.prepare('SELECT COUNT(*) AS n FROM messages').get().n, 0);
});

test('a code binds the platform sender and routes only that person to the owner', async () => {
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  await link(adapter, bob, '200');
  handled.length = 0;

  adapter.receive({ senderId: '100', text: 'from alice', messageId: 'a1' });
  adapter.receive({ senderId: '200', text: 'from bob', messageId: 'b1' });
  await flush();

  assert.deepEqual(
    handled.map(({ userId, msg }) => [userId, msg.agentId, msg.content]).sort((a, b) => a[0] - b[0]),
    [[alice.userId, agentOf(alice), 'from alice'], [bob.userId, agentOf(bob), 'from bob']]
      .sort((a, b) => a[0] - b[0]),
  );
  assert.equal(ctx.db.prepare('SELECT COUNT(*) AS n FROM messaging_inbound_jobs WHERE user_id = ?').get(alice.userId).n, 1);
  assert.deepEqual(
    emitted.filter((e) => e.event === 'messaging:linked').map((e) => e.room).sort(),
    [`user:${alice.userId}`, `user:${bob.userId}`].sort(),
  );
  assert.equal(adapter.reactions.length, 2, 'linking is confirmed by reaction, not canned text');
  assert.equal(adapter.sent.length, 0);
});

test('codes are hashed at rest, single use, and expire', async () => {
  const adapter = await setUpSharedTelegram();
  const { code } = store.createLinkCode('telegram', alice.userId, agentOf(alice));
  const stored = ctx.db.prepare('SELECT code_hash FROM messaging_link_codes').get();
  assert.ok(!stored.code_hash.includes(code.slice(4)));

  adapter.receive({ senderId: '100', text: code });
  await flush();
  adapter.receive({ senderId: '300', text: code });
  await flush();
  assert.equal(store.findLinkByExternalId('telegram', '300'), null);

  const stale = store.createLinkCode('telegram', bob.userId, agentOf(bob), Date.now() - 11 * 60 * 1000);
  adapter.receive({ senderId: '400', text: stale.code });
  await flush();
  assert.equal(store.findLinkByExternalId('telegram', '400'), null);
});

test('asking for a new code retires the previous one', async () => {
  await setUpSharedTelegram();
  const first = store.createLinkCode('telegram', alice.userId, agentOf(alice));
  store.createLinkCode('telegram', alice.userId, agentOf(alice));
  const result = store.redeemLinkCode('telegram', first.code, { externalId: '100', chatId: 'dm_100' });
  assert.deepEqual(result, { linked: false, reason: 'invalid_code' });
});

test('guessing codes is throttled per sender, even for a valid code', async () => {
  const adapter = await setUpSharedTelegram();
  for (let i = 0; i < 5; i += 1) {
    adapter.receive({ senderId: '666', text: 'NeoAgent-AAAAAAAAAA' });
  }
  const { code } = store.createLinkCode('telegram', alice.userId, agentOf(alice));
  adapter.receive({ senderId: '666', text: code });
  await flush();
  assert.equal(store.findLinkByExternalId('telegram', '666'), null);
});

test('an identity linked to one user cannot be taken over with another user\'s code', async () => {
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  await link(adapter, bob, '100');

  assert.equal(store.findLinkByExternalId('telegram', '100').user_id, alice.userId);
  assert.equal(store.findLinkForUser('telegram', bob.userId), null);
  assert.ok(emitted.some((e) => e.event === 'messaging:link_failed' && e.room === `user:${bob.userId}`));
});

test('a new identity replaces the user\'s old one, which stops working at once', async () => {
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  await link(adapter, alice, '101');
  handled.length = 0;

  adapter.receive({ senderId: '100', text: 'old identity', messageId: 'o1' });
  adapter.receive({ senderId: '101', text: 'new identity', messageId: 'n1' });
  await flush();
  assert.deepEqual(handled.map(({ msg }) => msg.content), ['new identity']);
});

test('groups never reach an agent on a shared account, even from a linked sender', async () => {
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  handled.length = 0;

  const access = adapter.receive({ senderId: '100', text: 'hi', isDirect: false, chatId: '-500' });
  await flush();
  assert.equal(access.allowed, false);
  assert.equal(handled.length, 0);
});

test('a linked agent can only message its own chat through the shared account', async () => {
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');

  await manager.sendMessage(alice.userId, 'telegram', 'dm_100', 'hello', { agentId: agentOf(alice) });
  await manager.sendMessage(alice.userId, 'telegram', '100', 'same chat', { agentId: agentOf(alice) });
  assert.deepEqual(adapter.sent.map((m) => m.to), ['dm_100', 'dm_100']);

  await assert.rejects(
    manager.sendMessage(alice.userId, 'telegram', 'dm_200', 'spam', { agentId: agentOf(alice) }),
    (error) => error.code === 'SHARED_RECIPIENT_NOT_ALLOWED',
  );
  await assert.rejects(
    manager.sendMessage(alice.userId, 'telegram', '-500', 'group', { agentId: agentOf(alice) }),
    (error) => error.code === 'SHARED_RECIPIENT_NOT_ALLOWED',
  );
  assert.equal(adapter.sent.length, 2);
});

test('outbound through a shared account is rate limited per user', async () => {
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  const route = manager.platforms.get(manager._key(alice.userId, agentOf(alice), 'telegram'));
  for (let i = 0; i < 60; i += 1) await route.sendMessage('dm_100', 'x');
  await assert.rejects(route.sendMessage('dm_100', 'x'), (error) => error.code === 'SHARED_RATE_LIMITED');
});

test('disconnecting unlinks immediately and leaves the shared account running', async () => {
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  await link(adapter, bob, '200');
  handled.length = 0;

  const result = await manager.disconnectPlatform(alice.userId, 'telegram', { agentId: agentOf(alice) });
  assert.equal(result.status, 'disconnected');
  assert.equal(adapter.getStatus(), 'connected');

  adapter.receive({ senderId: '100', text: 'after unlink', messageId: 'u1' });
  adapter.receive({ senderId: '200', text: 'still fine', messageId: 'u2' });
  await flush();
  assert.deepEqual(handled.map(({ msg }) => msg.content), ['still fine']);
  await assert.rejects(manager.sendMessage(alice.userId, 'telegram', 'dm_100', 'x', { agentId: agentOf(alice) }));
});

test('a queued message replayed after an unlink is refused, not answered by a personal policy', async () => {
  const { isAllowedMessagingSender } = require('../../../server/services/messaging/automation');
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  const msg = {
    platform: 'telegram',
    agentId: agentOf(alice),
    chatId: 'dm_100',
    sender: '100',
    isGroup: false,
    metadata: { sharedConnection: true },
  };
  const io = { to() { return { emit() {} }; } };

  assert.equal(await isAllowedMessagingSender({ io, userId: alice.userId, msg }), true);
  assert.equal(msg.ownerTrusted, true);

  manager.shared.unlink(alice.userId, 'telegram');
  manager.setAccessPolicy(alice.userId, 'telegram', { directPolicy: 'open' }, { agentId: agentOf(alice) });
  const replay = { ...msg, ownerTrusted: undefined };
  assert.equal(await isAllowedMessagingSender({ io, userId: alice.userId, msg: replay }), false);
});

test('another user sending as a linked chat is not trusted', async () => {
  const { isAllowedMessagingSender } = require('../../../server/services/messaging/automation');
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  const msg = {
    platform: 'telegram',
    agentId: agentOf(bob),
    chatId: 'dm_100',
    sender: '100',
    isGroup: false,
    metadata: { sharedConnection: true },
  };
  const io = { to() { return { emit() {} }; } };
  assert.equal(await isAllowedMessagingSender({ io, userId: bob.userId, msg }), false);
});

test('switching off availability stops linked users without touching their links', async () => {
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  handled.length = 0;

  store.configureConnection('telegram', { available: false });
  const access = adapter.receive({ senderId: '100', text: 'hi', messageId: 'v1' });
  await flush();
  assert.equal(access.reason, 'unavailable');
  assert.equal(handled.length, 0);
  assert.equal(manager.shared.listOptions(alice.userId).length, 0);
  assert.ok(store.findLinkForUser('telegram', alice.userId));
  assert.throws(() => manager.shared.startLink(bob.userId, agentOf(bob), 'telegram'), (error) => error.status === 409);
});

test('choosing a personal account replaces the shared link; a reconnect never does', async () => {
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  const agentId = agentOf(alice);

  const skipped = await manager.connectPlatform(alice.userId, 'telegram', {}, { agentId });
  assert.equal(skipped.status, 'skipped');
  assert.ok(store.findLinkForUser('telegram', alice.userId));

  await manager.connectPlatform(alice.userId, 'telegram', { botToken: 'mine' }, { agentId, userInitiated: true });
  assert.equal(store.findLinkForUser('telegram', alice.userId), null);
  const personal = manager.platforms.get(manager._key(alice.userId, agentId, 'telegram'));
  assert.notEqual(personal.isSharedRoute, true);
  assert.notEqual(personal, adapter);

  // The old identity is refused rather than falling through to the personal slot.
  assert.equal(adapter.receive({ senderId: '100', text: 'hi' }).allowed, false);
});

test('linking retires a personal connection on that agent instead of running both', async () => {
  const adapter = await setUpSharedTelegram();
  const agentId = agentOf(alice);
  const personalAdapter = await manager.connectPlatform(alice.userId, 'telegram', { botToken: 'mine' }, { agentId, userInitiated: true })
    .then(() => manager.platforms.get(manager._key(alice.userId, agentId, 'telegram')));

  await link(adapter, alice, '100');

  assert.equal(personalAdapter.getStatus(), 'disconnected');
  const row = ctx.db.prepare('SELECT status, config FROM platform_connections WHERE user_id = ? AND platform = ?').get(alice.userId, 'telegram');
  assert.equal(row.status, 'disconnected');
  assert.equal(manager._decodeStoredConfig(row.config).autoConnect, false);
  assert.equal(manager.platforms.get(manager._key(alice.userId, agentId, 'telegram')).isSharedRoute, true);
});

test('admins can restrict personal accounts for others without disturbing other platforms', async () => {
  await setUpSharedTelegram({ allowPersonal: false });
  const admin = ctx.db.prepare('SELECT is_admin FROM users WHERE id = ?').get(alice.userId);
  const member = admin.is_admin === 1 ? bob : alice;

  await assert.rejects(
    manager.connectPlatform(member.userId, 'telegram', { botToken: 'mine' }, { agentId: agentOf(member), userInitiated: true }),
    (error) => error.status === 403 && error.code === 'PERSONAL_NOT_ALLOWED',
  );
  assert.equal(manager.shared.listOptions(member.userId)[0].personalAllowed, false);
  manager.shared.beforePersonalConnect(member.userId, agentOf(member), 'discord');
});

test('without a shared account nothing changes for personal connections', async () => {
  const agentId = agentOf(alice);
  manager.shared.beforePersonalConnect(alice.userId, agentId, 'telegram');
  await manager.connectPlatform(alice.userId, 'telegram', { botToken: 'mine' }, { agentId, userInitiated: true });
  const status = manager.getAllStatuses(alice.userId, { agentId });
  assert.equal(status.telegram.status, 'connected');
  assert.deepEqual(manager.shared.listOptions(alice.userId), []);
});

test('credentials and the login QR never reach a user', async () => {
  const { adminOverview } = require('../../../server/services/messaging/shared_connections');
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');

  const row = store.getConnection('telegram');
  assert.ok(!row.config.includes(TOKEN), 'token is encrypted at rest');
  assert.ok(!JSON.stringify(adminOverview()).includes(TOKEN));

  const userView = JSON.stringify([
    manager.shared.listOptions(alice.userId),
    manager.getAllStatuses(alice.userId, { agentId: agentOf(alice) }),
    manager.getPlatformStatus(alice.userId, 'telegram', { agentId: agentOf(alice) }),
  ]);
  assert.ok(!userView.includes(TOKEN));
  assert.ok(!userView.includes('SECRET-QR'));
  assert.ok(userView.includes('@shared_bot'));
});

test('the admin overview counts people without naming them', async () => {
  const { adminOverview } = require('../../../server/services/messaging/shared_connections');
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  const telegram = adminOverview().find((item) => item.platform === 'telegram');
  assert.equal(telegram.linkedUsers, 1);
  assert.equal(telegram.status, 'connected');
  assert.ok(!JSON.stringify(telegram).includes('Sender'));
});

test('changes written by another process are picked up, and removal clears everything', async () => {
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  const key = manager._key(alice.userId, agentOf(alice), 'telegram');
  assert.equal(manager.platforms.get(key).isSharedRoute, true);

  store.configureConnection('telegram', { reconnect: true });
  await manager.shared.reconcile();
  assert.notEqual(FakeAdapter.last, adapter);
  assert.equal(adapter.getStatus(), 'disconnected');

  store.removeConnection('telegram');
  await manager.shared.reconcile();
  assert.equal(manager.platforms.has(key), false);
  assert.equal(store.findLinkForUser('telegram', alice.userId), null);
  assert.equal(FakeAdapter.last.getStatus(), 'disconnected');
});

test('deleting an account removes its link and route', async () => {
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  ctx.db.prepare('DELETE FROM users WHERE id = ?').run(alice.userId);
  await manager.shared.reconcile();
  assert.equal(store.findLinkByExternalId('telegram', '100'), null);
  assert.equal(adapter.receive({ senderId: '100', text: 'hi' }).allowed, false);
  assert.equal([...manager.platforms.values()].some((platform) => platform.isSharedRoute), false);
});

test('bad tokens and unsupported platforms are refused', () => {
  assert.throws(() => store.configureConnection('telegram', { botToken: 'nope' }), (e) => e.code === 'SHARED_TOKEN_INVALID');
  assert.throws(() => store.configureConnection('telegram', {}), (e) => e.code === 'SHARED_TOKEN_REQUIRED');
  assert.throws(() => store.configureConnection('slack', {}), (e) => e.code === 'SHARED_PLATFORM_UNSUPPORTED');
  assert.throws(() => store.configureConnection('__proto__', {}), (e) => e.code === 'SHARED_PLATFORM_UNSUPPORTED');
});

test('the audit log records link events without message content or identities', async () => {
  const adapter = await setUpSharedTelegram();
  await link(adapter, alice, '100');
  manager.shared.unlink(alice.userId, 'telegram');
  const rows = ctx.db.prepare("SELECT action, detail_json FROM access_audit_log WHERE action LIKE 'messaging.%'").all();
  assert.deepEqual(
    rows.map((row) => row.action),
    ['messaging.shared_configure', 'messaging.identity_link', 'messaging.identity_unlink'],
  );
  assert.ok(!JSON.stringify(rows).includes('100'));
  assert.ok(!JSON.stringify(rows).includes(TOKEN));
});

test('real adapters ask the gate before doing anything with a message', async () => {
  const { TelegramPlatform } = require('../../../server/services/messaging/telegram');
  const seen = [];
  const telegram = new TelegramPlatform({
    botToken: TOKEN,
    accessGate: (context) => {
      seen.push(context);
      return { allowed: false, reason: 'unlinked' };
    },
  });
  telegram._botUser = { id: 1, username: 'shared_bot' };
  const emittedMessages = [];
  const blocked = [];
  telegram.on('message', (msg) => emittedMessages.push(msg));
  telegram.on('blocked_sender', (info) => blocked.push(info));

  await telegram._handleMessage({
    message: {
      message_id: 7,
      date: 1,
      text: '/start NeoAgent-ABCDEFGHJK',
      from: { id: 55, first_name: 'Sam' },
      chat: { id: 55, type: 'private' },
    },
  });

  assert.equal(seen[0].senderId, '55');
  assert.equal(seen[0].isDirect, true);
  assert.equal(seen[0].text, '/start NeoAgent-ABCDEFGHJK');
  assert.equal(emittedMessages.length, 0);
  assert.equal(blocked.length, 0, 'strangers on a shared bot raise no allowlist prompt');
  assert.equal(telegram._seenUsers.size, 0);
});

test('WhatsApp identifies a contact by phone number across LID addressing', () => {
  const { WhatsAppPlatform } = require('../../../server/services/messaging/whatsapp');
  const whatsapp = new WhatsAppPlatform({ accessGate: () => ({ allowed: false }) });
  const context = whatsapp._accessContext(
    { key: { id: 'x', remoteJid: '999@lid', remoteJidAlt: '491700000001@s.whatsapp.net' }, message: {} },
    { chatId: '999@lid', isGroup: false, sender: '999@lid', content: 'hi' },
  );
  assert.equal(context.stableSenderId, '491700000001');
  assert.equal(context.chatId, '999@lid');
});
