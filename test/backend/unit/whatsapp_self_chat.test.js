'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { WhatsAppPlatform } = require('../../../server/services/messaging/whatsapp');

const OWN_JID = '49123456789@s.whatsapp.net';

function selfChatPlatform() {
  const platform = new WhatsAppPlatform({ selfChatMode: true });
  platform.sock = { user: { id: '49123456789:21@s.whatsapp.net' } };
  return platform;
}

function message({ remoteJid, fromMe, id = 'message-1', participant }) {
  return { key: { remoteJid, fromMe, id, participant } };
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

  // Baileys reports this socket's own sends as an 'append' upsert.
  assert.equal(platform._shouldProcessInbound(agentReply, 'append'), false);

  // And the recorded send id holds even if the same message arrives as 'notify'.
  platform._rememberSentMessage('agent-reply-1');
  assert.equal(platform._shouldProcessInbound(agentReply, 'notify'), false);

  // A note typed on the user's phone still gets through.
  assert.equal(
    platform._shouldProcessInbound(
      message({ remoteJid: OWN_JID, fromMe: true, id: 'note-from-phone' }),
      'notify'
    ),
    true
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
