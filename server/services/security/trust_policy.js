'use strict';

const { describeTaint, isOriginTarget, isOwnerNamed, isTainted } = require('./run_trust');

// Deterministic checks on a tool call against the run's trust record. They
// hold regardless of what the model was talked into, so they are the boundary;
// the prompt wording about untrusted content is only a first line.
//
// Two kinds of review, both answered by asking the owner:
//   'audience' — someone other than the owner is steering the run. Holds even
//                in allow_all mode: that mode is the owner's choice for their
//                own requests, not for a group chat's.
//   'taint'    — the run has read outside content and the call would carry
//                data somewhere new or plant an instruction for later runs
//                (the "lethal trifecta" / Rule of Two). allow_all skips it.

// What a shared conversation may do without the owner: talk in its own chat,
// search the web, and work on the media that came with the message. Anything
// that reads the owner's data, acts as the owner, or changes something asks.
const SHARED_AUDIENCE_TOOLS = new Set([
  'think',
  'search_tools',
  'activate_tools',
  'send_interim_update',
  'send_message',
  'react_to_message',
  'request_user_input',
  'web_search',
  'social_video_extract',
  'generate_image',
  'generate_table',
  'generate_graph',
  'analyze_image',
  'transcribe_audio',
  'ocr_extract',
]);
const MEDIA_PATH_ARGS = ['image_path', 'audio_path'];

// Calls whose effect outlives the run: a task or core-memory entry written
// from injected text runs again later with the owner's authority.
const PERSISTENCE_TOOLS = new Set([
  'create_task',
  'update_task',
  'memory_update_core',
  'create_skill',
  'update_skill',
  'mcp_add_server',
]);

const RECIPIENT_ARGS = ['to', 'cc', 'bcc', 'recipient', 'recipients'];
const READ_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

// Tools that can carry an argument off the machine.
const EGRESS_TOOLS = new Set([
  'send_message',
  'http_request',
  'web_search',
  'browser_navigate',
  'browser_type',
  'browser_act',
  'social_video_extract',
]);

// High-precision credential shapes. A match in an outbound argument of a
// tainted run is almost always exfiltration, not a user request.
const SECRET_PATTERNS = [
  /\bsk-(?:proj-|ant-)?[A-Za-z0-9_-]{20,}/,
  /\bnvapi-[A-Za-z0-9_-]{30,}/,
  /\bgh[pousr]_[A-Za-z0-9]{36,}/,
  /\bgithub_pat_[A-Za-z0-9_]{40,}/,
  /\bxox[abprs]-[A-Za-z0-9-]{10,}/,
  /\bAKIA[0-9A-Z]{16}\b/,
  /\bAIza[0-9A-Za-z_-]{35}\b/,
  /\b[rs]k_live_[0-9A-Za-z]{20,}/,
  /\b\d{8,10}:AA[A-Za-z0-9_-]{33}\b/,
  /\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/,
  /-----BEGIN [A-Z ]*PRIVATE KEY-----/,
];
const SECRET_ENV_KEY_RE = /(SECRET|TOKEN|PASSWORD|API_KEY|PRIVATE_KEY)/i;

let serverSecrets = null;
function getServerSecrets() {
  if (!serverSecrets) {
    serverSecrets = Object.entries(process.env)
      .filter(([key, value]) => SECRET_ENV_KEY_RE.test(key) && typeof value === 'string' && value.length >= 16)
      .map(([, value]) => value);
  }
  return serverSecrets;
}

function listValues(value) {
  if (Array.isArray(value)) return value.flatMap(listValues);
  if (typeof value !== 'string') return [];
  return value.split(/[,;]/).map((item) => item.replace(/^.*<([^>]+)>\s*$/, '$1').trim()).filter(Boolean);
}

function hostOf(url) {
  try {
    return new URL(String(url)).hostname.toLowerCase().replace(/^www\./, '');
  } catch {
    return '';
  }
}

function reviewSharedAudienceCall(toolName, toolArgs, trust) {
  const where = trust.origin ? `${trust.origin.platform} chat ${trust.origin.chatId}` : 'a shared conversation';
  if (!SHARED_AUDIENCE_TOOLS.has(toolName)) {
    return `Someone in ${where} other than you asked for ${toolName}.`;
  }
  if (toolName === 'send_message' && toolArgs.to && !isOriginTarget(trust, toolArgs.to)) {
    return `A run started from ${where} wants to message ${toolArgs.to}.`;
  }
  for (const key of MEDIA_PATH_ARGS) {
    if (toolArgs[key] && !trust.mediaPaths.has(String(toolArgs[key]))) {
      return `A run started from ${where} wants to open ${toolArgs[key]}, which did not come with the message.`;
    }
  }
  return null;
}

function reviewTaintedCall(toolName, toolArgs, category, trust) {
  const read = `this run has read content from ${describeTaint(trust)}`;

  if (PERSISTENCE_TOOLS.has(toolName)) {
    return `${toolName} would outlast this run, and ${read}.`;
  }

  const recipientKeys = toolName === 'send_message' ? ['to'] : RECIPIENT_ARGS;
  for (const key of recipientKeys) {
    for (const recipient of listValues(toolArgs[key])) {
      if (!isOwnerNamed(trust, recipient)) {
        return `You did not name ${recipient} as a recipient, and ${read}.`;
      }
    }
  }

  if (toolName === 'http_request') {
    const method = String(toolArgs.method || 'GET').trim().toUpperCase();
    const host = hostOf(toolArgs.url);
    if (!READ_METHODS.has(method) && host && !isOwnerNamed(trust, host)) {
      return `${method} to ${host}, a host you did not name, and ${read}.`;
    }
  }

  const outbound = EGRESS_TOOLS.has(toolName)
    || category === 'external'
    || RECIPIENT_ARGS.some((key) => toolArgs[key] != null);
  if (outbound) {
    const serialized = JSON.stringify(toolArgs);
    const leaks = SECRET_PATTERNS.some((pattern) => pattern.test(serialized))
      || getServerSecrets().some((secret) => serialized.includes(secret));
    if (leaks) {
      return `${toolName} would send what looks like a credential, and ${read}.`;
    }
  }
  return null;
}

/**
 * @returns {{kind: 'audience'|'taint', reason: string}|null}
 */
function reviewToolCall({ toolName, toolArgs = {}, category = null, trust = null }) {
  if (!trust) return null;
  const args = toolArgs && typeof toolArgs === 'object' ? toolArgs : {};
  if (trust.audience === 'shared') {
    const reason = reviewSharedAudienceCall(toolName, args, trust);
    if (reason) return { kind: 'audience', reason };
  }
  if (!isTainted(trust)) return null;
  const reason = reviewTaintedCall(toolName, args, category, trust);
  return reason ? { kind: 'taint', reason } : null;
}

module.exports = {
  reviewToolCall,
};
