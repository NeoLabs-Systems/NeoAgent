'use strict';

const db = require('../../../../db/database');
const { normalizeOutgoingMessageForPlatform } = require('../../../messaging/formatting_guides');
const { normalizeInterimKind } = require('../../interim');
const { normalizeWhatsAppId } = require('../../../../utils/whatsapp');
const { getRunState } = require('../tool_context');
const { commitDelivery, slotForContent } = require('../../runtime/delivery/delivery_worker');
const { markSent } = require('../../runtime/delivery/run_delivery');
const { loadRun } = require('../../runtime/run_state_machine');

function normalizeSendMessagePurpose(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'final_result' || normalized === 'blocker' || normalized === 'no_response') {
    return normalized;
  }
  return '';
}

function validateProactiveSendMessageArgs({ purpose, normalizedMessage }) {
  const normalizedPurpose = normalizeSendMessagePurpose(purpose);
  if (!normalizedPurpose) {
    return {
      ok: false,
      error: 'Background send_message requires purpose=final_result, blocker, or no_response.',
      reason: 'Background send_message requires purpose=final_result, blocker, or no_response.',
    };
  }

  if (normalizedPurpose === 'no_response') {
    if (normalizedMessage && normalizedMessage !== '[NO RESPONSE]') {
      return {
        ok: false,
        error: 'purpose=no_response requires content "[NO RESPONSE]".',
        reason: 'purpose=no_response requires content "[NO RESPONSE]".',
      };
    }
    return {
      ok: false,
      skipped: true,
      suppressed: true,
      reason: 'no_response',
    };
  }

  if (normalizedMessage === '[NO RESPONSE]') {
    return {
      ok: false,
      error: `purpose=${normalizedPurpose} cannot use content "[NO RESPONSE]".`,
      reason: `purpose=${normalizedPurpose} cannot use content "[NO RESPONSE]".`,
    };
  }

  return {
    ok: true,
    purpose: normalizedPurpose,
  };
}

function hasAlreadySentProactiveMessage({ taskId, delivery, allowMultipleProactiveMessages }) {
  if (!taskId || allowMultipleProactiveMessages) return false;
  return Boolean(delivery?.sent?.length || delivery?.staged);
}

function canonicalMessagingAddress(platform, value) {
  const normalizedPlatform = String(platform || '').trim().toLowerCase();
  const raw = String(value || '').trim();
  if (!normalizedPlatform || !raw) return '';
  if (normalizedPlatform !== 'whatsapp') return raw;

  const lower = raw.toLowerCase();
  const normalizedId = normalizeWhatsAppId(lower);
  if (!normalizedId) return '';
  if (lower.includes('@g.us')) return `group:${normalizedId}`;
  if (lower.includes('@lid')) return `lid:${normalizedId}`;
  return `direct:${normalizedId}`;
}

function isOriginMessagingDelivery({ triggerSource, source, chatId, platform, to }) {
  if (triggerSource !== 'messaging') return true;
  const originPlatform = String(source || '').trim().toLowerCase();
  const targetPlatform = String(platform || '').trim().toLowerCase();
  if (!originPlatform || !targetPlatform || originPlatform !== targetPlatform) return false;

  const originAddress = canonicalMessagingAddress(originPlatform, chatId);
  const targetAddress = canonicalMessagingAddress(targetPlatform, to);
  return Boolean(originAddress && targetAddress && originAddress === targetAddress);
}

function inboundMessagingMessage(context, runState) {
  return runState?.messagingContext?.behavior?.message
    || context?.inboundMessage
    || null;
}

function inboundMessagingIsGroup(context, runState) {
  const behavior = runState?.messagingContext?.behavior;
  return behavior?.isGroup === true
    || behavior?.message?.isGroup === true
    || context?.isGroup === true
    || context?.inboundMessage?.isGroup === true;
}

function inboundMessagingSenderId(context, runState) {
  const message = inboundMessagingMessage(context, runState);
  return String(message?.sender || context?.senderId || '').trim();
}

function isSenderDirectTarget({ platform, to, senderId }) {
  const target = String(to || '').trim();
  const sender = String(senderId || '').trim();
  if (!target || !sender) return false;
  if (target === sender || target === `dm_${sender}`) return true;
  const normalizedPlatform = String(platform || '').trim().toLowerCase();
  if (normalizedPlatform !== 'whatsapp') return false;
  const targetAddress = canonicalMessagingAddress('whatsapp', target);
  const senderAddress = canonicalMessagingAddress('whatsapp', sender);
  return Boolean(
    targetAddress
    && senderAddress
    && targetAddress === senderAddress
    && targetAddress.startsWith('direct:')
  );
}

function resolveInboundMessagingSendTarget({
  triggerSource,
  source,
  chatId,
  platform,
  to,
  isGroup,
  senderId,
}) {
  const resolvedPlatform = String(platform || source || '').trim();
  const resolvedTo = String(to || '').trim();
  const originChatId = String(chatId || '').trim();
  const originPlatform = String(source || resolvedPlatform).trim();
  if (
    triggerSource === 'messaging'
    && isGroup
    && originChatId
    && isSenderDirectTarget({ platform: resolvedPlatform, to: resolvedTo, senderId })
    && !isOriginMessagingDelivery({
      triggerSource,
      source: originPlatform,
      chatId: originChatId,
      platform: resolvedPlatform,
      to: resolvedTo,
    })
  ) {
    return {
      platform: originPlatform,
      to: originChatId,
      redirectedFromDirect: true,
    };
  }
  return {
    platform: resolvedPlatform,
    to: resolvedTo,
    redirectedFromDirect: false,
  };
}

const handlers = {
  async list_chats(args, ctx) {
    const { userId } = ctx;
    const listPlatform = typeof args.platform === 'string' ? args.platform.trim().toLowerCase() : null;

    let listQuery = `SELECT platform, platform_chat_id, metadata
                FROM messages
                WHERE user_id = ? AND platform_chat_id IS NOT NULL AND platform != 'web'`;
    const listParams = [userId];

    if (listPlatform) { listQuery += ' AND platform = ?'; listParams.push(listPlatform); }
    listQuery += ' ORDER BY id DESC LIMIT 2000';

    const listRows = db.prepare(listQuery).all(...listParams);

    const chatMap = new Map();
    for (const row of listRows) {
    const key = `${row.platform}:${row.platform_chat_id}`;
    if (chatMap.has(key)) continue;
    let meta = {};
    try { meta = row.metadata ? JSON.parse(row.metadata) : {}; } catch {}
    const isGroup = String(meta.isGroup || '').match(/^(true|1)$/i) != null && String(meta.isGroup || '') !== '';
    const name = (meta.groupName || meta.group_name || meta.guildName || meta.guild_name || meta.chatName || meta.chat_name || '').trim()
      || (meta.senderName || meta.sender_name || '').trim()
      || null;
    chatMap.set(key, {
      platform: row.platform,
      chat_id: row.platform_chat_id,
      name,
      type: isGroup ? 'group' : 'dm',
    });
    }

    const chats = Array.from(chatMap.values());
    return {
    count: chats.length,
    chats,
    };
  },

  async read_messages(args, ctx) {
    const { userId } = ctx;
    const msgLimit = Math.max(1, Math.min(Number(args.limit) || 20, 100));
    const msgPlatform = typeof args.platform === 'string' ? args.platform.trim().toLowerCase() : null;
    const msgChatId = typeof args.chat_id === 'string' ? args.chat_id.trim() : null;
    const msgGroupName = typeof args.group_name === 'string' ? args.group_name.trim().toLowerCase() : null;
    const msgSearch = typeof args.search === 'string' ? args.search.trim() : null;

    let msgQuery = "SELECT role, content, platform, platform_chat_id, metadata, created_at FROM messages WHERE user_id = ? AND role = 'user'";
    const msgParams = [userId];

    if (msgPlatform) { msgQuery += ' AND platform = ?'; msgParams.push(msgPlatform); }
    if (msgChatId) { msgQuery += ' AND platform_chat_id = ?'; msgParams.push(msgChatId); }
    if (msgSearch) { msgQuery += ' AND content LIKE ?'; msgParams.push(`%${msgSearch}%`); }

    msgQuery += ' ORDER BY created_at DESC LIMIT ?';
    msgParams.push(msgGroupName ? Math.min(msgLimit * 10, 500) : msgLimit);

    const msgRows = db.prepare(msgQuery).all(...msgParams);

    let filteredRows = msgRows;
    if (msgGroupName) {
    filteredRows = msgRows.filter((row) => {
      try {
        const meta = row.metadata ? JSON.parse(row.metadata) : {};
        const name = (meta.groupName || meta.group_name || meta.guildName || meta.guild_name || meta.chatName || meta.chat_name || row.platform_chat_id || '').toLowerCase();
        return name.includes(msgGroupName);
      } catch { return false; }
    }).slice(0, msgLimit);
    }

    return {
    count: filteredRows.length,
    messages: filteredRows.reverse().map((row) => {
      let meta = {};
      try { meta = row.metadata ? JSON.parse(row.metadata) : {}; } catch {}
      return {
        platform: row.platform,
        chat_id: row.platform_chat_id,
        group_name: meta.groupName || meta.group_name || meta.guildName || meta.guild_name || null,
        sender: meta.senderName || meta.sender_name || null,
        content: row.content,
        timestamp: row.created_at,
      };
    }),
    };
  },

  async send_interim_update(args, ctx) {
    const { agentId, context, engine, runId, triggerSource, userId } = ctx;
    if (triggerSource === 'agent_delegation' || triggerSource === 'agent' || context.triggerType === 'subagent') {
    return { error: 'Interim user-facing updates are not allowed from delegated or sub-agent runs.' };
    }
    if (!engine || !runId) {
    return { error: 'Interim updates require an active run.' };
    }
    if (engine.getRunMeta(runId)?.messagingContext?.behavior?.isGroup === true) {
    return {
      sent: false,
      skipped: true,
      reason: 'Interim progress updates are suppressed in shared rooms.',
    };
    }
    const interimContent = typeof args.content === 'string' ? args.content : '';
    const expectsReply = args.expects_reply === true;
    const deferFollowUp = args.defer_follow_up === true;
    return engine.publishInterimUpdate({
    userId,
    runId,
    agentId,
    triggerSource,
    conversationId: context.conversationId || null,
    platform: context.source || null,
    chatId: context.chatId || null,
    content: interimContent,
    kind: normalizeInterimKind(args.kind),
    expectsReply,
    deferFollowUp,
    });
  },

  async react_to_message(args, ctx) {
    const { agentId, context, msg, runId, signal, triggerSource, userId } = ctx;
    const inbound = context.inboundMessage;
    if (triggerSource !== 'messaging' || !inbound?.messageId) {
    return { error: 'This run has no incoming chat message to react to.' };
    }
    const manager = msg();
    if (!manager?.supportsReactions?.(userId, inbound.platform, { agentId })) {
    return { error: `${inbound.platform} does not support reactions.` };
    }
    const emoji = String(args.emoji || '').trim();
    if (!emoji || emoji.length > 16 || !/\p{Extended_Pictographic}/u.test(emoji) || /[\p{L}\p{N}\s]/u.test(emoji)) {
    return { error: 'emoji must be a single emoji.' };
    }
    await manager.sendReaction(userId, inbound.platform, inbound.chatId, inbound.messageId, emoji, {
    agentId,
    runId,
    signal,
    });
    return { success: true, reacted: emoji };
  },

  async send_message(args, ctx) {
    const { agentId, allowMultipleProactiveMessages, app, context, delivery, engine, msg, runId, signal, taskId, triggerSource, userId } = ctx;
    if (triggerSource === 'agent_delegation' && context.allowExternalSideEffects !== true) {
      return { error: 'Delegated agents cannot send external messages unless external side effects were explicitly allowed.' };
    }
    const manager = msg();
    if (!manager) return { error: 'Messaging not available' };
    const runState = getRunState(engine, runId);
    // "owner" asks for the owner's own chat, which only a verified link or the
    // connection itself can name; finding it by reading other chats exposed them.
    // A missing recipient is a mistake, not a request to pick one.
    let to = String(args.to || '').trim();
    if (!to) return { error: 'send_message needs "to": a chat ID, or "owner" for the owner\'s own chat on that platform.' };
    if (to.toLowerCase() === 'owner') {
      to = manager.ownerDestination?.(userId, agentId, args.platform) || '';
      if (!to) {
        return { error: `There is no verified chat with the owner on ${args.platform || 'that platform'}. Name the chat, or ask the owner where to send it.` };
      }
    }
    const sendTarget = resolveInboundMessagingSendTarget({
      triggerSource,
      source: context.source,
      chatId: context.chatId,
      platform: args.platform,
      to,
      isGroup: inboundMessagingIsGroup(context, runState),
      senderId: inboundMessagingSenderId(context, runState),
    });
    const message = typeof args.content === 'string' ? args.content : '';
    const normalizedMessage = normalizeOutgoingMessageForPlatform(sendTarget.platform, message, {
      stripNoResponseMarker: false
    });
    const suppressReply = normalizedMessage === '[NO RESPONSE]';
    const originDelivery = isOriginMessagingDelivery({
      triggerSource,
      source: context.source,
      chatId: context.chatId,
      platform: sendTarget.platform,
      to: sendTarget.to,
    });
    const chooseSilence = () => {
      if (delivery) delivery.noResponse = true;
    };
    if (taskId) {
      const proactiveValidation = validateProactiveSendMessageArgs({
        purpose: args.purpose,
        normalizedMessage,
      });
      if (!proactiveValidation.ok) {
        if (proactiveValidation.error) {
          return {
            error: proactiveValidation.error,
          };
        }
        if (proactiveValidation.reason === 'no_response') chooseSilence();
        return {
          sent: false,
          suppressed: proactiveValidation.suppressed === true,
          skipped: proactiveValidation.skipped === true,
          reason: proactiveValidation.reason,
        };
      }
    }
    if (suppressReply) chooseSilence();
    if (!suppressReply && hasAlreadySentProactiveMessage({
      taskId,
      delivery,
      allowMultipleProactiveMessages
    })) {
      return {
        sent: false,
        skipped: true,
        reason: 'A proactive message was already sent in this task run; duplicate send_message was suppressed.'
      };
    }

    if (taskId && context.stageProactiveMessages === true && !suppressReply) {
      // A task reports to the target the run resolved, whatever the
      // model named, and the result tells it where the message went.
      const platform = delivery?.notifyTarget?.platform || args.platform;
      const to = delivery?.notifyTarget?.to || args.to;
      if (delivery) {
        delivery.staged = {
          platform: String(platform || '').trim(),
          to: String(to || '').trim(),
          content: String(normalizedMessage || '').trim(),
          purpose: String(args.purpose || '').trim().toLowerCase(),
          mediaPath: args.media_path || null,
          stagedAt: new Date().toISOString(),
        };
      }
      return {
        success: true,
        staged: true,
        purpose: normalizeSendMessagePurpose(args.purpose),
        platform,
        to,
        content: normalizedMessage,
      };
    }

    const behavior = runState?.messagingContext?.behavior;
    const behaviorPipeline = app?.locals?.behaviorPipeline;
    let sendResult;
    const transmit = async () => {
      if (
        originDelivery
        && behavior
        && behavior.enabled !== false
        && behaviorPipeline
        && typeof behaviorPipeline.deliverReply === 'function'
      ) {
        const behaviorResult = await behaviorPipeline.deliverReply({
          userId,
          agentId,
          msg: behavior.message,
          config: behavior.config,
          content: normalizedMessage,
          messagingManager: manager,
          runId,
          signal,
          mediaPath: args.media_path,
          turnEpoch: behavior.turnEpoch,
        });
        if (behaviorResult.delivered) {
          sendResult = { success: true, behavior: true, result: behaviorResult.delivery };
        } else if (behaviorResult.suppressed) {
          chooseSilence();
          sendResult = {
            success: true,
            sent: false,
            suppressed: true,
            reason: behaviorResult.reason,
          };
        } else {
          sendResult = {
            success: false,
            error: behaviorResult.reason || 'Behavior delivery was not confirmed.',
            // Some bubbles of the reply already reached the chat.
            deliveryAmbiguous: Number(behaviorResult.delivery?.deliveredBubbles || 0) > 0,
          };
        }
      } else {
        sendResult = await manager.sendMessage(userId, sendTarget.platform, sendTarget.to, args.content, {
          agentId,
          mediaPath: args.media_path,
          runId,
          persistConversation: Boolean(taskId),
          signal,
        });
      }
      if (sendResult?.suppressed === true) return { ok: true, skippedTransmission: true, reason: sendResult.reason || 'suppressed' };
      if (sendResult?.success === true) return { ok: true, platformMessageId: sendResult.result?.messageId || null };
      return { ok: false, ambiguous: sendResult?.deliveryAmbiguous === true, error: sendResult?.error || sendResult?.reason || 'send failed' };
    };

    // No run row means the tool is running outside a run, so there is no ledger
    // to reserve in. Silence is a decision, not a message.
    const run = runId && !suppressReply ? loadRun(runId) : null;
    if (run) {
      const commit = await commitDelivery({
        run,
        scopeId: runState?.deliveryScopeId,
        channel: 'messaging',
        // A reply in the run's own chat shares the final answer's recipient, so
        // the same text can never reach that chat twice, whichever path sent it.
        recipient: originDelivery && triggerSource === 'messaging' && context.chatId
          ? context.chatId
          : `${sendTarget.platform}:${sendTarget.to}`,
        purpose: originDelivery ? 'reply' : 'message',
        slot: slotForContent(`${normalizedMessage}\n${args.media_path || ''}`),
        content: normalizedMessage,
        metadata: { platform: sendTarget.platform, purpose: normalizeSendMessagePurpose(args.purpose) || null },
        // A caption says nothing about which file goes with it; the slot tells
        // attachments apart, and an attachment needs no text at all.
        dedupeContent: !args.media_path,
        allowEmptyContent: Boolean(args.media_path),
        transmit,
      });
      if (commit.duplicate && !sendResult) {
        // Telling the model it arrived is only true when it is known to have.
        sendResult = commit.ok
          ? {
            success: true,
            sent: false,
            duplicate: true,
            note: 'This exact message already reached this recipient in this run, so it was not sent again.',
          }
          : {
            success: false,
            sent: false,
            duplicate: true,
            error: 'An earlier attempt to send exactly this may or may not have arrived, so it was not sent again. Do not retry it; tell the user it may not have gone through.',
          };
      }
      if (!commit.ok && !sendResult) {
        if (commit.thrown) throw commit.thrown;
        sendResult = { success: false, error: commit.error || commit.reason };
      }
    } else {
      await transmit();
    }
    if (
      !suppressReply
      && sendResult?.success === true
      && sendResult?.suppressed !== true
      && originDelivery
    ) {
      if (runState && triggerSource === 'messaging') {
        // A reply in the chat the run answers is not the run's end:
        // the run may keep working, and its final answer is still
        // owed unless this reply stays its last word. It does not
        // move the run to the background; send_interim_update does.
        if (delivery) delivery.lastWordSent = true;
        engine?.markRunVisibleReply?.(runId);
      } else if (delivery) {
        delivery.finalDelivered = true;
      }
    }
    if (!suppressReply && sendResult?.success === true && sendResult?.suppressed !== true && sendResult?.duplicate !== true) {
      markSent(delivery, normalizedMessage);
    }
    return {
      ...sendResult,
      originDelivery,
      redirectedFromDirect: sendTarget.redirectedFromDirect === true,
      platform: sendTarget.platform,
      to: sendTarget.to,
    };
  },

  async call_user(args, ctx) {
    const { agentCalls, agentId, context, runId, signal, userId } = ctx;
    const coordinator = agentCalls();
    if (!coordinator) {
    return {
      status: 'unavailable',
      reason: 'call_service_not_initialized',
      message: 'The call_user tool is available, but the in-app call service is not initialized on this server.',
    };
    }
    const openingMessage = typeof args.opening_message === 'string'
    ? args.opening_message.trim()
    : '';
    if (!openingMessage) return { error: 'opening_message is required' };
    if (openingMessage.length > 4000) {
    return { error: 'opening_message must be 4000 characters or fewer' };
    }
    return coordinator.callUser({
    userId,
    agentId,
    runId,
    conversationId: context.conversationId || null,
    openingMessage,
    signal,
    });
  },

  async notify_user(args, ctx) {
    const { agentId, allowMultipleProactiveMessages, delivery, engine, msg, runId, signal, taskId, userId } = ctx;
    const message = typeof args.message === 'string' ? args.message.trim() : '';
    if (!message) return { error: 'message is required' };

    if (taskId) {
      const manager = msg();
      if (!manager) {
        throw new Error('Messaging manager not available');
      }

      if (hasAlreadySentProactiveMessage({
        taskId,
        delivery,
        allowMultipleProactiveMessages
      })) {
        return {
          sent: false,
          skipped: true,
          reason: 'A notification was already sent in this run; duplicate task message was suppressed.'
        };
      }

      const target = delivery?.notifyTarget;
      if (!target) {
        throw new Error('No messaging target is configured for this task run. Connect a platform and send at least one message on this server, or recreate the task after reconnecting.');
      }
      const status = typeof manager.getPlatformStatus === 'function'
        ? manager.getPlatformStatus(userId, target.platform, { agentId })
        : null;
      if (!status || status.status !== 'connected') {
        throw new Error(`Platform ${target.platform} is not connected on this server.`);
      }
      const send = () => manager.sendMessage(userId, target.platform, target.to, message, {
        agentId,
        runId,
        persistConversation: true,
        signal,
      });
      let sendResult;
      const run = runId ? loadRun(runId) : null;
      if (run) {
        const commit = await commitDelivery({
          run,
          channel: 'messaging',
          recipient: `${target.platform}:${target.to}`,
          purpose: 'notify',
          slot: slotForContent(message),
          content: message,
          metadata: { platform: target.platform },
          transmit: async () => {
            sendResult = await send();
            return { ok: true, platformMessageId: sendResult?.result?.messageId || null };
          },
        });
        if (!commit.ok && commit.thrown) throw commit.thrown;
      } else {
        sendResult = await send();
      }
      markSent(delivery, message);
      if (delivery) delivery.finalDelivered = true;
      return {
        sent: true,
        via: 'messaging',
        platform: target.platform,
        to: target.to,
        result: sendResult
      };
    }

    engine.emit(userId, 'run:interim', { runId, message });
    return { sent: true, via: 'interim' };
  },
};

module.exports = {
  handlers,
  validateProactiveSendMessageArgs,
};
