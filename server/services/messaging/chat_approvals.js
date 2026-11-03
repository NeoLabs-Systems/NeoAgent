'use strict';

const { resolveSenderTrust } = require('./automation');
const { redactSecrets } = require('../security/trust_policy');
const { createServiceLogger } = require('../../utils/logger');

const log = createServiceLogger('ChatApprovals');

const OPTIONS = Object.freeze([
  Object.freeze({ id: 'allow', label: 'Allow', emoji: '✅', decision: 'approved', scope: 'once' }),
  Object.freeze({ id: 'always', label: 'Allow always', emoji: '🔁', decision: 'approved', scope: 'always' }),
  Object.freeze({ id: 'deny', label: 'Disallow', emoji: '❌', decision: 'denied', scope: 'once' }),
]);

const REPLY_WORDS = new Map([
  ['allow', 'allow'],
  ['always', 'always'],
  ['allow always', 'always'],
  ['deny', 'deny'],
  ['disallow', 'deny'],
]);
const REPLY_HINT = 'Reply "allow", "always" or "deny".';

// Public threads are read by anyone, so a call is never put up for a vote there.
const NO_PROMPT_PLATFORMS = new Set(['github']);

const SUMMARY_ARGS = ['command', 'url', 'to', 'path', 'file_path', 'query', 'name'];
const SUMMARY_LENGTH = 160;

function summarizeArgs(toolArgs = {}) {
  const key = SUMMARY_ARGS.find((name) => typeof toolArgs[name] === 'string' && toolArgs[name].trim());
  const raw = key ? toolArgs[key] : JSON.stringify(toolArgs);
  if (!raw || raw === '{}') return '';
  const text = redactSecrets(raw).replace(/\s+/g, ' ').trim();
  return text.length > SUMMARY_LENGTH ? `${text.slice(0, SUMMARY_LENGTH - 1)}…` : text;
}

// What a group sees stops at the tool's name: the details may be the owner's.
function promptText({ toolName, toolArgs, reason, isGroup }) {
  const lines = [`Allow ${toolName}?`];
  if (!isGroup) {
    if (reason) lines.push(redactSecrets(reason));
    const summary = summarizeArgs(toolArgs);
    if (summary) lines.push(summary);
  }
  return lines.join('\n');
}

// Puts approvals up in the chat a run came from and takes the answer from there.
// The app keeps getting them too, and whichever answers first decides.
class ChatApprovals {
  constructor({ manager, gate }) {
    this.manager = manager;
    this.gate = gate;
    /** approvalId → the prompt in its chat. @type {Map<string, object>} */
    this.prompts = new Map();
  }

  _platform(userId, agentId, platformName) {
    const manager = this.manager;
    return manager.platforms.get(manager._key(userId, manager._agentId(userId, { agentId }), platformName));
  }

  canOffer({ userId, agentId, trust }) {
    const origin = trust?.origin;
    if (!origin?.chatId || !origin.platform || trust.audience === 'public') return false;
    if (NO_PROMPT_PLATFORMS.has(origin.platform)) return false;
    const platform = this._platform(userId, agentId, origin.platform);
    if (platform?.getStatus?.() !== 'connected') return false;
    if (trust.audience !== 'shared') return true;
    // Someone unvetted in a DM, or a group nobody in it was listed for: no one
    // there could answer, and asking would only show them the request.
    if (!origin.isGroup) return false;
    const rules = platform.getAccessPolicy?.()?.sharedActorRules || [];
    return rules.some((rule) => rule.scope !== 'role');
  }

  async offer({ approvalId, userId, agentId, trust, toolName, toolArgs, reason }) {
    const { platform: platformName, chatId, isGroup } = trust.origin;
    const entry = {
      approvalId,
      userId,
      agentId: this.manager._agentId(userId, { agentId }),
      platformName,
      chatId,
      promptId: null,
    };
    this.prompts.set(approvalId, entry);
    const text = promptText({ toolName, toolArgs, reason, isGroup });
    try {
      const platform = this._platform(userId, agentId, platformName);
      const sent = platform.sendApprovalPrompt
        ? await platform.sendApprovalPrompt(chatId, { text, options: OPTIONS })
        : await platform.sendMessage(chatId, `${text}\n${REPLY_HINT}`);
      entry.promptId = sent?.promptId || sent?.messageId || null;
    } catch (error) {
      log.warn(`Could not ask for approval in ${platformName}: ${error?.message || error}`);
      this.prompts.delete(approvalId);
      return;
    }
    // The app can answer while the prompt is on its way.
    if (!this.gate.isPending(approvalId)) this._remove(entry);
  }

  withdraw(approvalId) {
    const entry = this.prompts.get(approvalId);
    if (!entry) return;
    this.prompts.delete(approvalId);
    if (entry.promptId) this._remove(entry);
  }

  _remove(entry) {
    this.prompts.delete(entry.approvalId);
    const platform = this._platform(entry.userId, entry.agentId, entry.platformName);
    Promise.resolve(platform?.deleteApprovalPrompt?.(entry.chatId, entry.promptId)).catch((error) => {
      log.warn(`Could not remove an approval prompt: ${error?.message || error}`);
    });
  }

  // Only someone who speaks for the owner decides. That leaves out a group's
  // other members and anyone let in by an open policy, including whoever asked
  // for the call that is being reviewed.
  _mayDecide(entry, actor) {
    if (actor.isAccountHolder === true) return true;
    const msg = { ...actor, platform: entry.platformName, chatId: entry.chatId, agentId: entry.agentId };
    if (!resolveSenderTrust({ userId: entry.userId, msg })) return false;
    return msg.ownerTrusted === true || msg.approvedSpeaker === true;
  }

  _decide(entry, choiceId, actor) {
    const option = OPTIONS.find((item) => item.id === choiceId);
    if (!option || !this._mayDecide(entry, actor)) return false;
    return Boolean(this.gate.decide(entry.approvalId, entry.userId, option.decision, option.scope));
  }

  /** An answer through a poll, a reaction or a button on a prompt. */
  handleResponse({ userId, agentId, platformName, chatId, promptId, choiceId, actor }) {
    const entry = [...this.prompts.values()].find((item) => item.platformName === platformName
      && item.chatId === chatId
      && String(item.promptId) === String(promptId)
      && item.userId === userId
      && item.agentId === agentId);
    return entry ? this._decide(entry, choiceId, actor || {}) : false;
  }

  /**
   * A typed answer, for platforms with nothing to tap. Returns true when the
   * message was that answer, so it does not also start a run.
   */
  handleInboundText(userId, agentId, platformName, msg) {
    const choiceId = REPLY_WORDS.get(String(msg?.content || '').trim().toLowerCase());
    if (!choiceId) return false;
    const entry = [...this.prompts.values()].find((item) => item.platformName === platformName
      && item.chatId === msg.chatId
      && item.userId === userId
      && item.agentId === agentId);
    return entry ? this._decide(entry, choiceId, msg) : false;
  }
}

module.exports = { ChatApprovals, OPTIONS, promptText };
