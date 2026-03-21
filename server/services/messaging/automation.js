'use strict';

const db = require('../../db/database');
const { detectPromptInjection } = require('../../utils/security');
const { normalizeWhatsAppId } = require('../../utils/whatsapp');
const { randomUUID } = require('crypto');

function registerMessagingAutomation({ app, io, messagingManager, agentEngine }) {
  const userQueues = {};
  app.locals.userQueues = userQueues;

  messagingManager.registerHandler(async (userId, msg) => {
    if (!(await isAllowedMessagingSender({ io, userId, msg }))) {
      return;
    }

    const upsertSetting = db.prepare(
      'INSERT OR REPLACE INTO user_settings (user_id, key, value) VALUES (?, ?, ?)'
    );
    upsertSetting.run(userId, 'last_platform', msg.platform);
    upsertSetting.run(userId, 'last_chat_id', msg.chatId);

    await processQueuedMessage({
      userQueues,
      messagingManager,
      agentEngine,
      userId,
      msg
    });
  });
}

async function processQueuedMessage({
  userQueues,
  messagingManager,
  agentEngine,
  userId,
  msg
}) {
  if (!userQueues[userId]) {
    userQueues[userId] = { running: false, pending: [] };
  }
  const queue = userQueues[userId];

  if (queue.running) {
    const last = queue.pending[queue.pending.length - 1];
    if (last && last.platform === msg.platform && last.chatId === msg.chatId) {
      last.content += `\n${msg.content}`;
      last.messageId = msg.messageId;
    } else {
      queue.pending.push({ ...msg });
    }
    return;
  }

  queue.running = true;
  let stopTypingKeepalive = async () => {};
  try {
    await messagingManager
      .markRead(userId, msg.platform, msg.chatId, msg.messageId)
      .catch(() => {});
    stopTypingKeepalive = startTypingKeepalive({
      messagingManager,
      userId,
      platform: msg.platform,
      chatId: msg.chatId
    });

    const prompt = buildIncomingPrompt(msg);
    const conversationId = ensureConversation(userId, msg);
    const runOptions = {
      triggerSource: 'messaging',
      conversationId,
      source: msg.platform,
      chatId: msg.chatId,
      context: { rawUserMessage: msg.content }
    };

    if (msg.localMediaPath) {
      runOptions.mediaAttachments = [
        { path: msg.localMediaPath, type: msg.mediaType }
      ];
    }

    await agentEngine.run(userId, prompt, runOptions);
  } finally {
    await stopTypingKeepalive();
    queue.running = false;
    if (queue.pending.length > 0) {
      const next = queue.pending.shift();
      await processQueuedMessage({
        userQueues,
        messagingManager,
        agentEngine,
        userId,
        msg: next
      });
    }
  }
}

function startTypingKeepalive({
  messagingManager,
  userId,
  platform,
  chatId,
  intervalMs = 4000
}) {
  let stopped = false;
  let timer = null;
  let releaseWait = null;

  const wait = () =>
    new Promise((resolve) => {
      releaseWait = resolve;
      timer = setTimeout(resolve, intervalMs);
    });

  const loop = (async () => {
    while (!stopped) {
      await messagingManager
        .sendTyping(userId, platform, chatId, true)
        .catch(() => {});

      if (stopped) break;
      await wait();
    }
  })();

  return async () => {
    stopped = true;
    if (timer) {
      clearTimeout(timer);
      timer = null;
    }
    if (releaseWait) {
      releaseWait();
      releaseWait = null;
    }
    await loop.catch(() => {});
    await messagingManager
      .sendTyping(userId, platform, chatId, false)
      .catch(() => {});
  };
}

function ensureConversation(userId, msg) {
  let conversation = db
    .prepare(
      'SELECT id FROM conversations WHERE user_id = ? AND platform = ? AND platform_chat_id = ?'
    )
    .get(userId, msg.platform, msg.chatId);

  if (conversation) {
    return conversation.id;
  }

  const conversationId = randomUUID();
  db.prepare(
    'INSERT INTO conversations (id, user_id, platform, platform_chat_id, title) VALUES (?, ?, ?, ?, ?)'
  ).run(
    conversationId,
    userId,
    msg.platform,
    msg.chatId,
    `${msg.platform} — ${msg.senderName || msg.sender || msg.chatId}`
  );

  return conversationId;
}

function buildIncomingPrompt(msg) {
  const mediaNote = msg.localMediaPath
    ? `\nMedia attached at: ${msg.localMediaPath} (type: ${msg.mediaType}). You can reference or forward it with send_message media_path.`
    : '';

  if (detectPromptInjection(msg.content)) {
    console.warn(
      `[Security] Possible prompt injection attempt from ${msg.sender} on ${msg.platform}: ${msg.content.slice(0, 200)}`
    );
  }

  const isVoiceCall = msg.platform === 'telnyx' && msg.mediaType === 'voice';
  const isVoiceNote = !isVoiceCall && msg.mediaType === 'audio';
  const isDiscordGuild = msg.platform === 'discord' && msg.isGroup;

  const discordContext =
    isDiscordGuild &&
    Array.isArray(msg.channelContext) &&
    msg.channelContext.length
      ? '\n\nRecent channel context (oldest → newest):\n' +
        msg.channelContext.map((item) => `[${item.author}]: ${item.content}`).join('\n')
      : '';

  const sttNote = isVoiceNote
    ? '\n[Note: This message was sent as a voice note and transcribed via speech-to-text. The transcription may not be perfectly accurate.]'
    : '';

  if (isVoiceCall) {
    return `You are on a live phone call. The caller (${msg.senderName || msg.sender}) said:\n<caller_speech>\n${msg.content}\n</caller_speech>\n\nRespond via send_message with platform="telnyx" and to="${msg.chatId}".`;
  }

  return `You received a ${msg.platform} message from ${msg.senderName || msg.sender} (chat: ${msg.chatId}):\n<external_message>\n${msg.content}\n</external_message>${mediaNote}${discordContext}${sttNote}\n\nReply via send_message with platform="${msg.platform}" and to="${msg.chatId}".`;
}

async function isAllowedMessagingSender({ io, userId, msg }) {
  if (msg.platform === 'discord' || msg.platform === 'telegram') {
    return true;
  }

  const whitelistRow = db
    .prepare('SELECT value FROM user_settings WHERE user_id = ? AND key = ?')
    .get(userId, `platform_whitelist_${msg.platform}`);

  const normalize =
    msg.platform === 'whatsapp'
      ? normalizeWhatsAppId
      : (id) => String(id || '').replace(/[^0-9+]/g, '');

  let whitelist = [];
  if (whitelistRow) {
    try {
      const parsed = JSON.parse(whitelistRow.value);
      if (Array.isArray(parsed)) whitelist = parsed;
    } catch {
      whitelist = [];
    }
  }

  const shouldCheckWhitelist = whitelist.length > 0;

  if (!shouldCheckWhitelist) {
    return true;
  }

  const senderNorm = normalize(msg.sender || msg.chatId);
  const allowed = whitelist.some((entry) => normalize(entry) === senderNorm);
  if (allowed) {
    return true;
  }

  console.log(
    `[Messaging] Blocked ${msg.platform} message from ${msg.sender} (not in whitelist)`
  );
  const suggestions = [];
  if (msg.platform === 'whatsapp') {
    const normalizedSender = normalizeWhatsAppId(msg.sender || msg.chatId);
    if (normalizedSender) {
      suggestions.push({
        label: `Add sender (${msg.senderName || normalizedSender})`,
        prefixedId: normalizedSender
      });
    }
  }
  io.to(`user:${userId}`).emit('messaging:blocked_sender', {
    platform: msg.platform,
    sender: msg.sender,
    chatId: msg.chatId,
    senderName: msg.senderName || null,
    suggestions: suggestions.length > 0 ? suggestions : null
  });
  return false;
}

module.exports = {
  registerMessagingAutomation
};
