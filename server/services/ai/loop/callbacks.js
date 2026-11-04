'use strict';

const db = require('../../../db/database');
const {
  buildInterimMetadata,
  buildInterimSignature,
  normalizeInterimKind,
} = require('../interim');
const { normalizeInterimText } = require('../messagingFallback');
const { requireSuccessfulMessagingDelivery } = require('./messaging_delivery');
const { commitDelivery, requestProgressDelivery, slotForContent } = require('../runtime/delivery/delivery_worker');
const { loadRun } = require('../runtime/run_state_machine');
const { MESSAGE_KINDS } = require('../runtime/constants');

async function publishInterimUpdate(engine, {
  userId,
  runId,
  agentId = null,
  triggerSource = 'web',
  conversationId = null,
  platform = null,
  chatId = null,
  content,
  kind,
  expectsReply = false,
  deferFollowUp = false,
} = {}) {
  const runMeta = engine.getRunMeta(runId);
  if (!runMeta || runMeta.aborted) {
    return { sent: false, skipped: true, reason: 'Run is no longer active.' };
  }

  const normalizedKind = normalizeInterimKind(kind);
  const normalizedContent = normalizeInterimText(
    content,
    triggerSource === 'messaging' ? platform : null
  );
  if (!normalizedContent || normalizedContent.toUpperCase() === '[NO RESPONSE]') {
    return { sent: false, skipped: true, reason: 'Interim content must be non-empty.' };
  }

  const signature = buildInterimSignature({
    content: normalizedContent,
    kind: normalizedKind,
    expectsReply,
    platform: triggerSource === 'messaging' ? platform : 'web',
  });
  const slot = slotForContent(signature);

  const metadata = buildInterimMetadata({
    kind: normalizedKind,
    expectsReply,
  });
  if (deferFollowUp === true) {
    metadata.defer_follow_up = true;
  }
  const createdAt = new Date().toISOString();

  if (triggerSource === 'voice_live') {
    const voiceSessionId = runMeta.voiceSessionId || null;
    if (!voiceSessionId) {
      return { sent: false, skipped: true, reason: 'Voice session context is not available.' };
    }
    const delivery = await requestProgressDelivery({
      engine,
      runId,
      scopeId: runMeta.deliveryScopeId,
      content: normalizedContent,
      channel: 'voice_live',
      recipient: voiceSessionId,
      messageKind: MESSAGE_KINDS.INTERIM,
      slot,
      metadata: {
        kind: normalizedKind,
        expectsReply: expectsReply === true,
        ...(runMeta.sessionBinding || {}),
      },
    });
    if (delivery.duplicate) return { sent: false, skipped: true, duplicate: true };
    if (!delivery.ok) return { sent: false, skipped: true, reason: delivery.reason };
  } else {
    if (triggerSource === 'messaging' && (!platform || !chatId || !engine.messagingManager)) {
      return { sent: false, skipped: true, reason: 'Messaging context is not available.' };
    }
    const run = loadRun(runId);
    const delivery = await commitDelivery({
      run,
      scopeId: runMeta.deliveryScopeId,
      channel: triggerSource === 'messaging' ? 'messaging' : 'web',
      recipient: triggerSource === 'messaging' ? chatId : null,
      purpose: 'interim',
      slot,
      content: normalizedContent,
      metadata: { kind: normalizedKind, expectsReply: expectsReply === true },
      dedupeContent: false,
      transmit: async () => {
        if (triggerSource === 'messaging') {
          const deliveryResult = await engine.messagingManager.sendMessage(userId, platform, chatId, normalizedContent, {
            agentId,
            runId,
            persistConversation: true,
            metadata,
            deliveryKind: 'interim',
            signal: runMeta.abortController?.signal || null,
          });
          requireSuccessfulMessagingDelivery(deliveryResult, 'Interim messaging delivery');
          return { ok: true };
        }
        db.prepare(
          `INSERT INTO conversation_history (
            user_id, agent_id, agent_run_id, conversation_id, role, content, metadata
          ) VALUES (?, ?, ?, ?, ?, ?, ?)`
        ).run(
          userId,
          agentId,
          runId,
          conversationId || null,
          'assistant',
          normalizedContent,
          JSON.stringify(metadata),
        );
        if (conversationId) {
          db.prepare(
            `INSERT INTO conversation_messages (
              conversation_id, run_id, agent_id, role, content, metadata_json
            ) VALUES (?, ?, ?, 'assistant', ?, ?)`,
          ).run(conversationId, runId, agentId, normalizedContent, JSON.stringify(metadata));
        }
        return { ok: true };
      },
    });
    if (delivery.duplicate) return { sent: false, skipped: true, duplicate: true };
    if (!delivery.ok) {
      if (delivery.thrown) throw delivery.thrown;
      return { sent: false, skipped: true, reason: delivery.reason };
    }
  }

  engine.markRunVisibleProgress(runId, createdAt);

  if (triggerSource !== 'voice_live') {
    engine.emit(userId, 'run:assistant_interim', {
      runId,
      conversationId: conversationId || null,
      content: normalizedContent,
      kind: normalizedKind,
      expectsReply: expectsReply === true,
      deferFollowUp: deferFollowUp === true,
      triggerSource,
      platform: triggerSource === 'messaging' ? platform : 'web',
    });
  }

  const terminalInterim = expectsReply === true;
  if (terminalInterim && runMeta.delivery) {
    runMeta.delivery.awaitingReply = {
      kind: normalizedKind,
      content: normalizedContent,
      createdAt,
    };
  }
  engine.persistRunMetadata(runId, {
    latestInterim: {
      kind: normalizedKind,
      expectsReply: expectsReply === true,
      deferFollowUp: deferFollowUp === true,
      content: normalizedContent,
      createdAt,
    },
    terminalInterim: terminalInterim
      ? { kind: normalizedKind, content: normalizedContent, createdAt }
      : null,
  });

  return {
    sent: true,
    kind: normalizedKind,
    expectsReply: expectsReply === true,
    deferFollowUp: deferFollowUp === true,
    content: normalizedContent,
    terminal: terminalInterim,
  };
}

module.exports = {
  publishInterimUpdate,
};
