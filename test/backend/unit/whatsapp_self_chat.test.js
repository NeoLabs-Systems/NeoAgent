'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { WhatsAppPlatform } = require('../../../server/services/messaging/whatsapp');

const OWN_JID = '49123456789@s.whatsapp.net';

const CONNECTED_AT = 1_700_000_000;

function selfChatPlatform() {
  const platform = new WhatsAppPlatform({ selfChatMode: true });
  platform.sock = { user: { id: '49123456789:21@s.whatsapp.net' } };
  platform._connectedAt = CONNECTED_AT;
  return platform;
}

function message({
  remoteJid,
  fromMe,
  id = 'message-1',
  participant,
  messageTimestamp = CONNECTED_AT + 5,
}) {
  return { key: { remoteJid, fromMe, id, participant }, messageTimestamp };
}

test('WhatsApp bot mode keeps ignoring messages sent by the linked account', () => {
  const platform = new WhatsAppPlatform();

  assert.equal(platform.selfChatMode, false);
  assert.equal(platform.supportsGroups, true);
  assert.equal(
    platform._shouldProcessInbound(
      message({ remoteJid: OWN_JID, fromMe: true }),
      'notify'
    ),
    false
  );
  assert.equal(
    platform._shouldProcessInbound(
      message({ remoteJid: '49987654321@s.whatsapp.net', fromMe: false }),
      'notify'
    ),
    true
  );
});

test('WhatsApp self-chat mode only accepts notes from the account self-chat', () => {
  const platform = selfChatPlatform();

  assert.equal(platform.supportsGroups, false);
  assert.equal(
    platform._shouldProcessInbound(
      message({ remoteJid: OWN_JID, fromMe: true }),
      'notify'
    ),
    true
  );
  assert.equal(
    platform._shouldProcessInbound(
      message({ remoteJid: '49987654321@s.whatsapp.net', fromMe: false }),
      'notify'
    ),
    false
  );
  assert.equal(
    platform._shouldProcessInbound(
      message({
        remoteJid: '120363123456789012@g.us',
        fromMe: false,
        participant: '49987654321@s.whatsapp.net',
      }),
      'notify'
    ),
    false
  );
});

test('WhatsApp self-chat mode never reads back what the agent wrote', () => {
  const platform = selfChatPlatform();
  const agentReply = message({
    remoteJid: OWN_JID,
    fromMe: true,
    id: 'agent-reply-1',
  });

  // The recorded send id is what rules the agent's own reply out, whichever
  // upsert kind it arrives as.
  platform._rememberSentMessage('agent-reply-1');
  assert.equal(platform._shouldProcessInbound(agentReply, 'notify'), false);
  assert.equal(platform._shouldProcessInbound(agentReply, 'append'), false);

  // A note typed on the user's phone still gets through.
  assert.equal(
    platform._shouldProcessInbound(
      message({ remoteJid: OWN_JID, fromMe: true, id: 'note-from-phone' }),
      'notify'
    ),
    true
  );
});

test('WhatsApp self-chat mode answers notes typed on the phone, which arrive as appends', () => {
  const platform = selfChatPlatform();

  // WhatsApp syncs what the user writes on their own phone to this linked
  // device as an 'append'. Dropping those left self-chat mode answering
  // nothing while the connection looked perfectly healthy.
  assert.equal(
    platform._shouldProcessInbound(
      message({ remoteJid: OWN_JID, fromMe: true, id: 'note-from-phone' }),
      'append'
    ),
    true
  );
});

test('WhatsApp self-chat mode leaves the history replayed after linking alone', () => {
  const platform = selfChatPlatform();

  assert.equal(
    platform._shouldProcessInbound(
      message({
        remoteJid: OWN_JID,
        fromMe: true,
        id: 'old-note',
        messageTimestamp: CONNECTED_AT - 60,
      }),
      'append'
    ),
    false
  );

  // Before the socket ever opens there is no cutoff, so nothing is answered.
  const fresh = new WhatsAppPlatform({ selfChatMode: true });
  fresh.sock = { user: { id: '49123456789:21@s.whatsapp.net' } };
  assert.equal(
    fresh._shouldProcessInbound(
      message({ remoteJid: OWN_JID, fromMe: true }),
      'append'
    ),
    false
  );
});

test('WhatsApp bot mode still ignores appends entirely', () => {
  const platform = new WhatsAppPlatform();
  platform.sock = { user: { id: '49123456789:21@s.whatsapp.net' } };
  platform._connectedAt = CONNECTED_AT;

  assert.equal(
    platform._shouldProcessInbound(
      message({ remoteJid: '49987654321@s.whatsapp.net', fromMe: false }),
      'append'
    ),
    false
  );
});

test('WhatsApp reads the message timestamp in each shape Baileys reports it', () => {
  const platform = selfChatPlatform();
  const note = (messageTimestamp) => message({
    remoteJid: OWN_JID,
    fromMe: true,
    id: 'note',
    messageTimestamp,
  });

  // Plain number, numeric string, and protobuf Long all have to resolve, or a
  // live note gets mistaken for history and silently dropped.
  assert.equal(platform._shouldProcessInbound(note(CONNECTED_AT + 5), 'append'), true);
  assert.equal(platform._shouldProcessInbound(note(String(CONNECTED_AT + 5)), 'append'), true);
  assert.equal(
    platform._shouldProcessInbound(
      note({ low: CONNECTED_AT + 5, high: 0, unsigned: true }),
      'append'
    ),
    true
  );
  assert.equal(
    platform._shouldProcessInbound(
      note({ toNumber: () => CONNECTED_AT + 5 }),
      'append'
    ),
    true
  );
  // A message carrying no timestamp at all cannot be placed after the
  // connection, so it is treated as history rather than answered blindly.
  assert.equal(
    platform._shouldProcessInbound(
      { key: { remoteJid: OWN_JID, fromMe: true, id: 'note' } },
      'append'
    ),
    false
  );
});

test('WhatsApp sends record their message id so the reply cannot loop back', async () => {
  const platform = selfChatPlatform();
  platform.status = 'connected';
  platform.sock.sendMessage = async () => ({ key: { id: 'sent-1' } });

  await platform.sendMessage(OWN_JID, 'on it');

  assert.equal(
    platform._shouldProcessInbound(
      message({ remoteJid: OWN_JID, fromMe: true, id: 'sent-1' }),
      'notify'
    ),
    false
  );
});

test('WhatsApp sent message memory stays bounded', () => {
  const platform = selfChatPlatform();
  for (let index = 0; index < 250; index += 1) {
    platform._rememberSentMessage(`sent-${index}`);
  }

  assert.equal(platform._sentMessageIds.size, 200);
  assert.equal(platform._sentMessageIds.has('sent-249'), true);
  assert.equal(platform._sentMessageIds.has('sent-0'), false);
});

test('WhatsApp self-chat replies carry the agent name so the user can tell them apart', async () => {
  const platform = selfChatPlatform();
  platform.resolveAgentName = () => 'NeoAgent';
  platform.status = 'connected';
  const payloads = [];
  platform.sock.sendMessage = async (jid, payload) => {
    payloads.push(payload);
    return { key: { id: `sent-${payloads.length}` } };
  };

  await platform.sendMessage(OWN_JID, 'on it');

  assert.deepEqual(payloads, [{ text: '(NeoAgent): on it' }]);
});

test('WhatsApp bot mode sends replies unlabeled', async () => {
  const platform = new WhatsAppPlatform({ resolveAgentName: () => 'NeoAgent' });
  platform.sock = { user: { id: '49123456789:21@s.whatsapp.net' } };
  platform.status = 'connected';
  const payloads = [];
  platform.sock.sendMessage = async (jid, payload) => {
    payloads.push(payload);
    return { key: { id: 'sent-1' } };
  };

  await platform.sendMessage('49987654321', 'on it');

  assert.deepEqual(payloads, [{ text: 'on it' }]);
});

test('WhatsApp self-chat mode skips the allowlist for the account owner', () => {
  const platform = selfChatPlatform();
  const blocked = [];
  platform.on('blocked_sender', (event) => blocked.push(event));

  const decision = platform._checkMessageAccess(
    message({ remoteJid: OWN_JID, fromMe: true }),
    { chatId: OWN_JID, isGroup: false, sender: OWN_JID, pushName: 'Neo' }
  );

  assert.equal(decision.allowed, true);
  assert.equal(blocked.length, 0);
});
