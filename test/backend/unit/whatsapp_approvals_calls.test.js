'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { afterEach, test } = require('node:test');

const { WhatsAppPlatform } = require('../../../server/services/messaging/whatsapp');
const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');
const { toWhatsAppJid } = require('../../../server/utils/whatsapp');

let runtime = null;
afterEach(() => {
  if (runtime) teardownTestRuntime(runtime);
  runtime = null;
});

const OWN_PN = '4915100000001@s.whatsapp.net';
const OWN_LID = '111111@lid';
const LISTED_PN = '4915100000002@s.whatsapp.net';
const LISTED_LID = '222222@lid';
const OPTIONS = [{ id: 'allow', label: 'Allow' }, { id: 'always', label: 'Allow always' }, { id: 'deny', label: 'Disallow' }];

function hmac(data, key) {
  return crypto.createHmac('sha256', key).update(data).digest();
}

// What a phone sends when it votes, mirroring WhatsApp's scheme so the real
// decryptPollVote in Baileys has to accept it.
function encryptVote({ secret, pollId, creator, voter, label }) {
  const { proto } = require('baileys');
  const hash = crypto.createHash('sha256').update(label).digest();
  const plain = proto.Message.PollVoteMessage.encode({ selectedOptions: label ? [hash] : [] }).finish();
  const key0 = hmac(secret, new Uint8Array(32));
  const sign = Buffer.concat([
    Buffer.from(pollId), Buffer.from(creator), Buffer.from(voter), Buffer.from('Poll Vote'), Buffer.from([1]),
  ]);
  const decKey = hmac(sign, key0);
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', decKey, iv);
  cipher.setAAD(Buffer.from(`${pollId}\u0000${voter}`));
  const encrypted = Buffer.concat([cipher.update(plain), cipher.final(), cipher.getAuthTag()]);
  return { encPayload: encrypted, encIv: iv };
}

function connected(config = {}) {
  const platform = new WhatsAppPlatform({ userId: 1, authDir: '/tmp/wa-test', ...config });
  platform.status = 'connected';
  const sends = [];
  const rejected = [];
  platform.sock = {
    user: { id: `${OWN_PN.split('@')[0]}:12@s.whatsapp.net`, lid: `${OWN_LID.split('@')[0]}:12@lid` },
    sendMessage: async (jid, payload) => {
      sends.push({ jid, payload });
      return {
        key: { id: `sent-${sends.length}`, remoteJid: jid, fromMe: true },
        message: { messageContextInfo: { messageSecret: SECRET } },
      };
    },
    rejectCall: async (id, from) => { rejected.push({ id, from }); },
  };
  return { platform, sends, rejected };
}

const SECRET = crypto.randomBytes(32);

function responses(platform) {
  const seen = [];
  platform.on('approval_response', (response) => seen.push(response));
  return seen;
}

async function poll(platform, chatId = LISTED_LID) {
  const { promptId } = await platform.sendApprovalPrompt(chatId, { text: 'Allow x?', options: OPTIONS });
  return promptId;
}

function voteMessage(promptId, { chat = LISTED_LID, alt = LISTED_PN, participant, participantAlt, fromMe = false, creator = OWN_LID, voter = LISTED_LID, label = 'Allow' }) {
  return {
    key: { id: 'vote-1', remoteJid: chat, remoteJidAlt: alt, participant, participantAlt, fromMe },
    pushName: 'Listed',
    message: {
      pollUpdateMessage: {
        pollCreationMessageKey: { id: promptId },
        vote: encryptVote({ secret: SECRET, pollId: promptId, creator, voter, label }),
      },
    },
  };
}

test('the poll offers the options, and a vote under LIDs decrypts to the choice and the number', async () => {
  const { platform, sends } = connected();
  const seen = responses(platform);
  const promptId = await poll(platform);
  assert.deepEqual(sends[0].payload.poll, { name: 'Allow x?', values: ['Allow', 'Allow always', 'Disallow'], selectableCount: 1 });

  platform._handlePollVote(voteMessage(promptId, { label: 'Allow always' }));
  assert.equal(seen.length, 1);
  assert.equal(seen[0].choiceId, 'always');
  assert.equal(seen[0].chatId, LISTED_LID);
  assert.equal(seen[0].actor.sender, LISTED_PN);
  assert.equal(seen[0].actor.phoneNumber, '4915100000002');
  assert.equal(seen[0].actor.isAccountHolder, false);
});

test('a vote made under phone numbers decrypts too', async () => {
  const { platform } = connected();
  const seen = responses(platform);
  const promptId = await poll(platform);
  platform._handlePollVote(voteMessage(promptId, { chat: LISTED_PN, alt: LISTED_LID, creator: OWN_PN, voter: LISTED_PN, label: 'Disallow' }));
  assert.equal(seen[0].choiceId, 'deny');
});

test('in a group the voter is the participant, not the group', async () => {
  const { platform } = connected();
  const seen = responses(platform);
  const group = '120363000@g.us';
  const promptId = await poll(platform, group);
  platform._handlePollVote(voteMessage(promptId, {
    chat: group, alt: undefined, participant: LISTED_LID, participantAlt: LISTED_PN, label: 'Allow',
  }));
  assert.equal(seen[0].actor.sender, LISTED_PN);
  assert.equal(seen[0].actor.isGroup, true);
  assert.equal(seen[0].actor.groupId, group);
});

test('forged votes, withdrawn votes and unknown polls are ignored', async () => {
  const { platform } = connected();
  const seen = responses(platform);
  const promptId = await poll(platform);

  // Claims to be from the listed contact but encrypted as someone else.
  platform._handlePollVote(voteMessage(promptId, { voter: '999999@lid' }));
  platform._handlePollVote(voteMessage(promptId, { label: '' }));
  platform._handlePollVote(voteMessage('not-a-poll', {}));
  assert.deepEqual(seen, []);
});

test('the account holder counts on their own account, but not on a shared one or outside self chat', async () => {
  const own = connected();
  const seen = responses(own.platform);
  let promptId = await poll(own.platform);
  own.platform._handlePollVote(voteMessage(promptId, { fromMe: true, voter: OWN_LID }));
  assert.equal(seen[0].actor.isAccountHolder, true);

  const shared = connected({ accessGate: () => ({ allowed: true, ownerUserId: 2 }) });
  const sharedSeen = responses(shared.platform);
  promptId = await poll(shared.platform);
  shared.platform._handlePollVote(voteMessage(promptId, { fromMe: true, voter: OWN_LID }));
  assert.deepEqual(sharedSeen, []);

  const selfChat = connected({ selfChatMode: true });
  const selfSeen = responses(selfChat.platform);
  promptId = await poll(selfChat.platform, OWN_LID);
  selfChat.platform._handlePollVote(voteMessage(promptId, { chat: OWN_LID, alt: OWN_PN, fromMe: true, voter: OWN_LID }));
  assert.deepEqual(selfSeen[0].actor.metadata, { selfChat: true });
  const otherPoll = await poll(selfChat.platform);
  selfChat.platform._handlePollVote(voteMessage(otherPoll, {}));
  assert.equal(selfSeen.length, 1);
});

test('answering deletes the poll for everyone, once', async () => {
  const { platform, sends } = connected();
  const promptId = await poll(platform);
  await platform.deleteApprovalPrompt(LISTED_LID, promptId);
  assert.equal(sends[1].payload.delete.id, promptId);
  await platform.deleteApprovalPrompt(LISTED_LID, promptId);
  assert.equal(sends.length, 2);
});

test('a contact under a LID is checked by number, from the key or the mapping', async () => {
  const { platform } = connected();
  assert.equal(platform._senderAddresses({ remoteJid: LISTED_LID, remoteJidAlt: LISTED_PN }).sender, LISTED_PN);
  assert.equal(platform._senderAddresses({ remoteJid: LISTED_PN, remoteJidAlt: LISTED_LID }).sender, LISTED_PN);
  assert.equal(platform._senderAddresses({ remoteJid: LISTED_LID }).sender, LISTED_LID);

  const context = platform._accessContext({ key: { remoteJid: LISTED_LID, remoteJidAlt: LISTED_PN } }, {
    chatId: LISTED_LID, isGroup: false, sender: platform._senderAddresses({ remoteJid: LISTED_LID, remoteJidAlt: LISTED_PN }).sender,
  });
  assert.equal(context.phoneNumber, '4915100000002');
  assert.equal(context.stableSenderId, '4915100000002');
  assert.equal(context.chatId, LISTED_LID);

  platform.sock.signalRepository = { lidMapping: { getPNForLID: async () => LISTED_PN } };
  const key = { remoteJid: LISTED_LID };
  await platform._learnPhoneNumber(key);
  assert.equal(key.remoteJidAlt, LISTED_PN);
});

function allowlisted(numbers) {
  return {
    accessPolicy: {
      directPolicy: 'allowlist',
      directRules: numbers.map((value) => ({ scope: 'phone_number', value })),
    },
  };
}

test('a call is rejected, and a listed caller asks for a call back', async () => {
  const { platform, rejected } = connected(allowlisted(['4915100000002']));
  const calls = [];
  platform.on('incoming_call', (call) => calls.push(call));
  await platform._handleCalls([{ id: 'c1', from: LISTED_LID, callerPn: LISTED_PN, status: 'offer' }]);
  assert.deepEqual(rejected, [{ id: 'c1', from: LISTED_LID }]);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].callerId, '4915100000002');
});

test('a caller who only shows a LID is matched by the mapping', async () => {
  const { platform } = connected(allowlisted(['4915100000002']));
  platform.sock.signalRepository = { lidMapping: { getPNForLID: async () => LISTED_PN } };
  const calls = [];
  platform.on('incoming_call', (call) => calls.push(call));
  await platform._handleCalls([{ id: 'c1', from: LISTED_LID, status: 'offer' }]);
  assert.equal(calls[0].callerId, '4915100000002');
});

test('a stranger is rejected and rings nobody, even under an open policy', async () => {
  const listed = connected(allowlisted(['4915100000002']));
  const listedCalls = [];
  listed.platform.on('incoming_call', (call) => listedCalls.push(call));
  await listed.platform._handleCalls([{ id: 'c1', from: '4915199999999@s.whatsapp.net', status: 'offer' }]);
  assert.equal(listed.rejected.length, 1);
  assert.deepEqual(listedCalls, []);

  const open = connected({ accessPolicy: { directPolicy: 'open' } });
  const openCalls = [];
  open.platform.on('incoming_call', (call) => openCalls.push(call));
  await open.platform._handleCalls([{ id: 'c2', from: '4915199999999@s.whatsapp.net', status: 'offer' }]);
  assert.equal(open.rejected.length, 1);
  assert.deepEqual(openCalls, []);
});

test('only live one-to-one offers ring; other call states are left alone', async () => {
  const { platform, rejected } = connected(allowlisted(['4915100000002']));
  const calls = [];
  platform.on('incoming_call', (call) => calls.push(call));
  await platform._handleCalls([
    { id: 'c1', from: LISTED_PN, status: 'timeout' },
    { id: 'c2', from: LISTED_PN, status: 'offer', offline: true },
    { id: 'c3', from: LISTED_PN, status: 'offer', isGroup: true },
  ]);
  assert.deepEqual(rejected.map((call) => call.id), ['c2', 'c3']);
  assert.deepEqual(calls, []);
});

test('self-chat mode leaves calls to the owner\'s phone alone', async () => {
  const { platform, rejected } = connected({ selfChatMode: true });
  await platform._handleCalls([{ id: 'c1', from: LISTED_PN, status: 'offer' }]);
  assert.deepEqual(rejected, []);
});

function coordinator(sockets, options = {}) {
  // Loaded after the test runtime so it binds to the test database.
  const { AgentCallCoordinator } = require('../../../server/services/voice/agent_call_coordinator');
  const emitted = [];
  return {
    emitted,
    calls: new AgentCallCoordinator({
      io: {
        in: () => ({ fetchSockets: async () => sockets }),
        to: () => ({ emit: (...args) => emitted.push(args) }),
      },
      agentEngine: {},
      voiceRuntimeManager: { hasActiveSessionForUser: () => false },
      ringTimeoutMs: 5,
      mobileWaitMs: 40,
      ...options,
    }),
  };
}

function fakeSocket(id, mobileApp) {
  const emitted = [];
  return { id, data: { mobileApp }, emitted, emit: (...args) => emitted.push(args) };
}

const tick = (ms = 0) => new Promise((resolve) => { setTimeout(resolve, ms); });

test('apps and phone browsers count as mobile unless they say otherwise; desktop browsers do not', () => {
  const { isMobileAppHandshake } = require('../../../server/services/voice/agent_call_coordinator');
  const handshake = (client, agent) => ({ query: client ? { client } : {}, headers: { 'user-agent': agent } });
  assert.equal(isMobileAppHandshake(handshake('android', 'Dart/3.9 (dart:io)')), true);
  assert.equal(isMobileAppHandshake(handshake('ios', 'Dart/3.9 (dart:io)')), true);
  assert.equal(isMobileAppHandshake(handshake('macos', 'Dart/3.9 (dart:io)')), false);
  assert.equal(isMobileAppHandshake(handshake(null, 'Dart/3.9 (dart:io)')), true, 'an app from before the field');
  assert.equal(isMobileAppHandshake(handshake(null, 'Mozilla/5.0 (iPhone; CPU iPhone OS 26_0)')), true, 'the web app on a phone');
  assert.equal(isMobileAppHandshake(handshake(null, 'Mozilla/5.0 (Linux; Android 15)')), true);
  assert.equal(isMobileAppHandshake(handshake(null, 'Mozilla/5.0 (Macintosh; Intel Mac OS X)')), false);
  assert.equal(isMobileAppHandshake(null), false);
});

test('the call back rings a connected phone straight away', async () => {
  runtime = createTestRuntime();
  const { userId } = await createTestUser(runtime.db, { username: 'whatsapp_call_back_ring' });
  const mobile = coordinator([{ id: 's2', data: { mobileApp: true } }]);
  const keepAlive = setTimeout(() => {}, 1000);
  const rung = await mobile.calls.callUser({ userId, openingMessage: 'hi', requireMobileApp: true });
  clearTimeout(keepAlive);
  assert.equal(mobile.emitted[0][0], 'voice:incoming_call');
  assert.equal(rung.status, 'missed');
});

test('with no phone connected nobody rings, and the call gives up quietly', async () => {
  runtime = createTestRuntime();
  const { userId } = await createTestUser(runtime.db, { username: 'whatsapp_call_back_wait' });
  const desktopOnly = coordinator([{ id: 's1', data: { mobileApp: false } }]);
  const keepAlive = setTimeout(() => {}, 1000);
  const result = await desktopOnly.calls.callUser({ userId, openingMessage: 'hi', requireMobileApp: true });
  clearTimeout(keepAlive);
  assert.equal(result.status, 'missed');
  assert.ok(!desktopOnly.emitted.some(([event]) => event === 'voice:incoming_call'));
});

test('a phone coming back within the wait gets the ring, and a desktop does not', async () => {
  runtime = createTestRuntime();
  const { userId } = await createTestUser(runtime.db, { username: 'whatsapp_call_back_return' });
  const { calls, emitted } = coordinator([], { mobileWaitMs: 500, ringTimeoutMs: 60 });
  const keepAlive = setTimeout(() => {}, 2000);
  const pending = calls.callUser({ userId, openingMessage: 'hi', requireMobileApp: true });
  await tick();
  assert.deepEqual(emitted, []);

  const desktop = fakeSocket('desk', false);
  assert.equal(calls.offerPendingCall(desktop, userId), false);
  assert.deepEqual(desktop.emitted, []);

  const phone = fakeSocket('phone', true);
  assert.equal(calls.offerPendingCall(phone, userId), true);
  assert.equal(phone.emitted[0][0], 'voice:incoming_call');
  assert.ok(Date.parse(phone.emitted[0][1].expiresAt) - Date.now() <= 60);

  // It now rings for the usual time, not the rest of the wait.
  assert.equal((await pending).status, 'missed');
  clearTimeout(keepAlive);
});

test('an agent\'s own call takes over from one still waiting for a phone', async () => {
  runtime = createTestRuntime();
  const { userId } = await createTestUser(runtime.db, { username: 'whatsapp_call_back_superseded' });
  const { calls, emitted } = coordinator([{ id: 's1', data: { mobileApp: false } }], { mobileWaitMs: 500 });
  const keepAlive = setTimeout(() => {}, 2000);
  const waiting = calls.callUser({ userId, openingMessage: 'callback', requireMobileApp: true });
  await tick();
  const own = await calls.callUser({ userId, openingMessage: 'from the agent' });
  assert.equal((await waiting).status, 'superseded');
  assert.equal(own.status, 'missed');
  assert.ok(emitted.some(([event]) => event === 'voice:incoming_call'));
  clearTimeout(keepAlive);
});
