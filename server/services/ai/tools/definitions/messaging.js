'use strict';

// Messaging and user contact tools: schemas plus the metadata the harness reads.

const { buildSendMessageFormattingReference } = require('../../../messaging/formatting_guides');
const { INTERIM_KINDS } = require('../../interim');

module.exports = [
  {
    name: 'send_message',
    selection: 'always',
    egress: true,
    recipientArgs: ['to'],
    resultShape: 'sent_message',
    group: 'messaging', stepType: 'messaging', access: 'write', sideEffect: 'message', stateScope: 'messages', latencyClass: 'remote', untrusted: false,
    capabilities: ['message', 'chat', 'telegram', 'whatsapp', 'discord', 'notify'],
    policy: { safe: true },
    whenNotToUse: ['replying in the current chat: your final reply already reaches the user'],
    description: `Send a final message on a connected messaging platform. Use send_interim_update, not this tool, for an ongoing status reply to the originating chat. When the inbound message is a group or shared-space chat, reply in that same chat — do not switch the reply to the sender's DM. Supports WhatsApp (text/media), Discord, Telegram, Slack, Google Chat, Microsoft Teams, Matrix, Signal, iMessage/BlueBubbles, IRC, Feishu, LINE, Mattermost, Nextcloud Talk, Nostr, Synology Chat, Tlon, Twitch, Zalo, WeChat, WebChat, and configurable webhook bridges. ${buildSendMessageFormattingReference()} For WhatsApp: use media_path to attach files. Use content "[NO RESPONSE]" only when the user explicitly asked for silence/no reply, or when a background task intentionally decides no user-visible update is needed with purpose="no_response". For background task or schedule runs, set purpose to final_result, blocker, or no_response.`,
    fileArgs: ['media_path'],
    parameters: {
      type: 'object',
      properties: {
        platform: { type: 'string', description: 'Platform name, for example whatsapp, discord, telegram, slack, google_chat, teams, matrix, signal, imessage, bluebubbles, irc, line, mattermost, or webchat' },
        to: { type: 'string', description: 'Recipient/chat ID for the connected platform, such as a WhatsApp chat ID, Slack channel ID, Matrix room ID, Discord channel snowflake / "dm_<userId>", Telegram "dm_<userId>" / raw group chat ID, IRC channel, or webhook target. "owner" sends to the owner\'s own chat on that platform, when one is verified.' },
        content: { type: 'string', description: 'Message text. Write one compact natural chat reply; the runtime adapts final formatting for the destination platform.' },
        media_path: { type: 'string', description: 'WhatsApp only: a file in your workspace (as you would give it to read_file) or an owned artifact URL. Leave empty for text-only.' },
        purpose: { type: 'string', enum: ['final_result', 'blocker', 'no_response'], description: 'For background task or schedule runs, required intent for this outbound message. Use final_result for a concrete useful outcome, blocker for a real issue the user should know about, or no_response to intentionally send nothing.' }
      },
      required: ['platform', 'to', 'content']
    }
  },
  {
    name: 'call_user',
    selection: 'always',
    group: 'messaging', stepType: 'voice', access: 'write', sideEffect: 'message', stateScope: 'messages', latencyClass: 'remote', untrusted: false,
    capabilities: ['call', 'phone', 'voice'],
    policy: { category: 'user_contact' },
    description: 'Start an in-app voice call to the user when spoken interaction is materially useful. After the user approves and answers, opening_message is spoken first and the call continues with the originating conversation context. This does not dial a phone number. A call_later status means the user asked to be called back later.',
    parameters: {
      type: 'object',
      properties: {
        opening_message: { type: 'string', description: 'The complete natural opening statement to speak immediately after the user answers.' }
      },
      required: ['opening_message']
    }
  },
  {
    name: 'notify_user',
    group: 'messaging', access: 'write', sideEffect: 'message', stateScope: 'messages', latencyClass: 'remote', untrusted: false,
    capabilities: ['notify', 'message'],
    policy: { safe: true },
    description: 'Send an immediate update message to the user mid-task without waiting for completion. Keep it natural, short, and conversational (e.g., "looking into it...", "gimme a sec..."). Do NOT use robotic phrasing like "I am currently processing...".',
    parameters: {
      type: 'object',
      properties: {
        message: { type: 'string', description: 'The message to show the user right now' }
      },
      required: ['message']
    }
  },
  {
    name: 'list_chats',
    group: 'messaging', access: 'read', stateScope: 'messages', latencyClass: 'local', repeatable: true,
    capabilities: ['message', 'chat', 'contacts'],
    prerequisites: ['messaging'],
    policy: { external: true },
    description: 'List all known groups and conversations across connected messaging platforms. Use this when the user doesn\'t know the exact group name or chat ID — it returns every chat that has ever sent a message, with platform, chat ID, display name, and whether it\'s a group or DM.',
    parameters: {
      type: 'object',
      properties: {
        platform: { type: 'string', description: 'Filter to a specific platform (e.g. telegram, whatsapp, discord). Omit to list chats across all platforms.' },
      }
    }
  },
  {
    name: 'read_messages',
    group: 'messaging', access: 'read', stateScope: 'messages', latencyClass: 'local', repeatable: true,
    capabilities: ['message', 'chat', 'history'],
    prerequisites: ['messaging'],
    policy: { external: true },
    description: 'Read recent messages from a connected messaging platform group or conversation. Use this to get recaps, search history, or summarize what\'s been going on in a Telegram group, WhatsApp chat, Discord channel, Slack channel, or any other connected platform. Messages are stored locally from inbound traffic.',
    parameters: {
      type: 'object',
      properties: {
        platform: { type: 'string', description: 'Platform name (e.g. telegram, whatsapp, discord, slack, signal, teams). Omit to search across all connected platforms.' },
        chat_id: { type: 'string', description: 'Exact platform chat or group ID. Use this when known.' },
        group_name: { type: 'string', description: 'Group, channel, or chat name to find (case-insensitive partial match). Use when you don\'t know the exact chat_id.' },
        limit: { type: 'number', description: 'Max messages to return (default 20, max 100).' },
        search: { type: 'string', description: 'Optional keyword to filter messages by content.' },
      }
    }
  },
  {
    name: 'send_interim_update',
    selection: 'always',
    resultShape: 'interim',
    group: 'messaging', stepType: 'note', access: 'write', sideEffect: 'message', stateScope: 'messages', latencyClass: 'remote', untrusted: false,
    capabilities: ['message', 'progress', 'update'],
    policy: { safe: true },
    availableWhen: (options) => ['web', 'messaging', 'voice_live'].includes(options.triggerSource) && options.triggerType !== 'subagent',
    description: 'Send the user a short message while you keep working. When a request takes more than a quick lookup (research, browsing, several steps), send one first saying what you are doing, then work. After that only for real progress, a blocker, or a question you need answered. Never for internal monologue, self-checks, tool bookkeeping, or "nothing happened" status.',
    parameters: {
      type: 'object',
      properties: {
        content: { type: 'string', description: 'Natural assistant message derived from user-relevant task state, not internal reasoning or progress-supervisor bookkeeping.' },
        kind: { type: 'string', enum: Array.from(INTERIM_KINDS), description: 'ack, progress, question, or blocker' },
        expects_reply: { type: 'boolean', description: 'Set true only when the current run should pause for the user to answer.' },
        defer_follow_up: { type: 'boolean', description: 'Set true when you choose to deliver the final result later via the user\'s last connected chat target.' }
      },
      required: ['content', 'kind']
    }
  },
  {
    name: 'react_to_message',
    selection: 'always',
    group: 'messaging', access: 'write', sideEffect: 'message', stateScope: 'messages', latencyClass: 'remote', untrusted: false,
    capabilities: ['message', 'reaction', 'emoji'],
    policy: { safe: true },
    availableWhen: (options) => options.triggerSource === 'messaging' && options.triggerType === 'user',
    description: 'React to the message the user just sent with one emoji, like tapping a reaction in the chat. Use it when a reaction says it better than a text (thanks, a joke, good news), or alongside a reply. Not on every message. When the reaction is all that is needed, make your final reply exactly [NO RESPONSE]; anything that asks for an answer still gets a text.',
    parameters: {
      type: 'object',
      properties: {
        emoji: { type: 'string', description: 'One emoji.' }
      },
      required: ['emoji']
    }
  },
];
