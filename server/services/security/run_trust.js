'use strict';

const { stripFencedSpans } = require('../../utils/untrusted_text');

// Per-run record of who the run acts for and whether content the owner did not
// write has reached its context. trust_policy.js decides from it; tool_turn
// feeds it every tool result. One object per root run: subagents and
// delegations share their parent's, so taint flows both ways.
//
// audience:
//   'owner'  — the owner started it (app, CLI, their own schedule, an allowed DM)
//   'shared' — a group chat or an unvetted sender; others speak in it
//   'public' — a public thread; the public_audience allowlist already confines it

// Trigger sources whose opening prompt comes from the owner. Event-triggered
// tasks (email received, webhook, …) carry a third-party payload and start
// tainted.
const OWNER_TRIGGER_SOURCES = new Set([
  'web',
  'cowork',
  'cli',
  'manual',
  'schedule',
  'tasks',
  'voice_live',
  'wearable',
  'messaging',
]);

// Tools whose results the harness writes itself, so reading them adds no
// outside content. Every other tool result counts as untrusted.
const HARNESS_OUTPUT_TOOLS = new Set([
  'think',
  'search_tools',
  'activate_tools',
  'send_interim_update',
  'send_message',
  'react_to_message',
  'notify_user',
  'call_user',
  'get_date_time',
  'request_user_input',
  'create_task',
  'update_task',
  'delete_task',
  'list_tasks',
  'get_task',
  'memory_save',
  'memory_update_core',
  'write_file',
  'edit_file',
  'replace_file_range',
  'generate_table',
  'generate_graph',
  'spawn_subagent',
  'list_subagents',
  'cancel_subagent',
]);

const PHONE_LIKE_RE = /\+?\d[\d\s().-]{4,}\d/g;

function digitsOf(text) {
  return String(text || '').replace(/\D/g, '');
}

function addTrustedText(trust, text) {
  const value = String(text || '').trim();
  if (!trust || !value) return;
  trust.trustedText += `\n${value.toLowerCase()}`;
  for (const match of value.match(PHONE_LIKE_RE) || []) {
    const digits = digitsOf(match);
    if (digits.length >= 6) trust.trustedNumbers.add(digits);
  }
}

function messageText(message) {
  if (typeof message?.content === 'string') return message.content;
  if (!Array.isArray(message?.content)) return '';
  return message.content
    .map((part) => (typeof part?.text === 'string' ? part.text : ''))
    .join('\n');
}

/**
 * @param {object} input
 * @param {'owner'|'shared'|'public'} input.audience
 * @param {string} input.triggerSource
 * @param {Array} input.messages   opening transcript (system, history, request)
 * @param {{platform: string, chatId: string, senderId?: string}|null} input.origin
 *   chat the run answers, and who wrote the message that started it
 * @param {string[]} input.mediaPaths  files that arrived with the inbound message
 */
function createRunTrust({ audience = 'owner', triggerSource, messages = [], origin = null, mediaPaths = [] }) {
  const trust = {
    audience,
    origin: origin?.chatId
      ? {
        platform: String(origin.platform || ''),
        chatId: String(origin.chatId),
        senderId: String(origin.senderId || ''),
      }
      : null,
    mediaPaths: new Set(mediaPaths.filter(Boolean).map(String)),
    taintSources: new Set(),
    trustedText: '',
    trustedNumbers: new Set(),
  };
  if (audience !== 'owner') trust.taintSources.add(`${audience} conversation`);
  if (!OWNER_TRIGGER_SOURCES.has(triggerSource)) trust.taintSources.add(`${triggerSource || 'unknown'} trigger`);

  // Owner-authored text is what may name a recipient or host. When the run
  // opens on third-party content, the fenced spans holding it are left out.
  const startsTainted = trust.taintSources.size > 0;
  for (const message of messages) {
    if (message?.role !== 'system' && message?.role !== 'user') continue;
    const text = messageText(message);
    addTrustedText(trust, startsTainted ? stripFencedSpans(text) : text);
  }
  return trust;
}

function recordToolOutput(trust, toolName) {
  if (trust && !HARNESS_OUTPUT_TOOLS.has(toolName)) trust.taintSources.add(toolName);
}

function isTainted(trust) {
  return Boolean(trust && trust.taintSources.size > 0);
}

function describeTaint(trust) {
  const sources = Array.from(trust?.taintSources || []);
  if (sources.length <= 3) return sources.join(', ');
  return `${sources.slice(0, 3).join(', ')} and ${sources.length - 3} more`;
}

// True when a message target is the chat the run answers. A reply addressed
// to the sender's DM counts: the send path routes it back into that chat.
function isOriginTarget(trust, rawValue) {
  const value = String(rawValue || '').trim().toLowerCase();
  if (!trust?.origin || !value) return false;
  const { chatId, senderId } = trust.origin;
  if (value === chatId.toLowerCase()) return true;
  return Boolean(senderId) && (value === senderId.toLowerCase() || value === `dm_${senderId}`.toLowerCase());
}

// True when a recipient or host was named by the owner (or is the chat the run
// answers), rather than picked up from content the run read.
function isOwnerNamed(trust, rawValue) {
  const value = String(rawValue || '').trim().toLowerCase();
  if (!value) return true;
  if (isOriginTarget(trust, value)) return true;
  if (trust.trustedText.includes(value)) return true;

  // Phone numbers and WhatsApp JIDs are written many ways; compare digits,
  // ignoring a leading country or trunk prefix.
  const localPart = value.split('@')[0];
  if (!/^\+?[\d\s().-]+$/.test(localPart)) return false;
  const digits = digitsOf(localPart);
  if (digits.length < 6) return false;
  for (const known of trust.trustedNumbers) {
    if (known === digits) return true;
    if (known.length >= 9 && digits.length >= 9 && known.slice(-9) === digits.slice(-9)) return true;
  }
  return false;
}

module.exports = {
  addTrustedText,
  createRunTrust,
  describeTaint,
  isOriginTarget,
  isOwnerNamed,
  isTainted,
  recordToolOutput,
};
