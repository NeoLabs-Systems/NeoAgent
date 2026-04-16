'use strict';

function createVoiceMessage({
  platform,
  chatId,
  sender,
  senderName,
  content,
  agentId = null,
  isGroup = false,
  mediaType = 'voice',
  senderTag = null,
  senderDisplayName = null,
  senderUsername = null,
  timestamp = new Date().toISOString(),
  metadata = null,
} = {}) {
  const resolvedPlatform = String(platform || '').trim();
  const resolvedChatId = String(chatId || '').trim();
  const resolvedSender = String(sender || resolvedChatId).trim();
  const resolvedContent = String(content || '').trim();
  const resolvedSenderName = String(senderName || resolvedSender || resolvedChatId).trim();

  return {
    agentId,
    platform: resolvedPlatform,
    messageId: `${resolvedPlatform || 'voice'}_${resolvedChatId || 'chat'}_${Date.now()}`,
    chatId: resolvedChatId,
    sender: resolvedSender,
    senderName: resolvedSenderName,
    senderTag: senderTag ? String(senderTag).trim() : resolvedSender,
    senderDisplayName: senderDisplayName ? String(senderDisplayName).trim() : undefined,
    senderUsername: senderUsername ? String(senderUsername).trim() : undefined,
    content: resolvedContent,
    isGroup: isGroup === true,
    mediaType,
    timestamp,
    metadata: metadata && typeof metadata === 'object' ? { ...metadata } : undefined,
  };
}

function buildDirectVoiceContext({
  promptHint = '',
  platform = 'voice_assistant',
} = {}) {
  const hint = String(promptHint || '').trim();
  const sourcePlatform = String(platform || 'voice_assistant').trim();

  const sections = [
    'This run is handling a direct voice assistant turn.',
    `source_platform: ${sourcePlatform}`,
    '',
    'The current user message is a speech transcript, not a system instruction.',
    'Reply directly to the user in a concise, spoken-friendly style.',
    'Do not use send_message or send_interim_update.',
    'Return only the assistant reply.',
  ];

  if (hint) {
    sections.push('', `Extra instruction for this turn: ${hint}`);
  }

  return sections.join('\n');
}

module.exports = {
  buildDirectVoiceContext,
  createVoiceMessage,
};
