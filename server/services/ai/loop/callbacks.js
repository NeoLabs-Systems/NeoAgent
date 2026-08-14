'use strict';

const db = require('../../../db/database');
const {
  buildInterimMetadata,
  buildInterimSignature,
  normalizeInterimKind,
} = require('../interim');
const { normalizeInterimText } = require('../messagingFallback');
const { requireSuccessfulMessagingDelivery } = require('./messaging_delivery');
const { requestProgressDelivery } = require('../runtime/delivery/delivery_worker');
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
  if (runMeta.interimSignatures?.has(signature)) {
    return { sent: false, skipped: true, duplicate: true };
  }

  const metadata = buildInterimMetadata({
    kind: normalizedKind,
    expectsReply,
  });
  if (deferFollowUp === true) {
    metadata.defer_follow_up = true;
  }
  const createdAt = new Date().toISOString();

  if (triggerSource === 'messaging') {
    if (!platform || !chatId || !engine.messagingManager) {
      return { sent: false, skipped: true, reason: 'Messaging context is not available.' };
    }
    const deliveryResult = await engine.messagingManager.sendMessage(userId, platform, chatId, normalizedContent, {
      agentId,
      runId,
      persistConversation: true,
      metadata,
      deliveryKind: 'interim',
      signal: runMeta.abortController?.signal || null,
    });
    requireSuccessfulMessagingDelivery(deliveryResult, 'Interim messaging delivery');
  } else if (triggerSource === 'voice_live') {
    const voiceSessionId = runMeta.voiceSessionId || null;
    if (!voiceSessionId) {
      return { sent: false, skipped: true, reason: 'Voice session context is not available.' };
    }
    const delivery = await requestProgressDelivery({
      engine,
      runId,
      content: normalizedContent,
      channel: 'voice_live',
      recipient: voiceSessionId,
      messageKind: MESSAGE_KINDS.INTERIM,
      metadata: {
        kind: normalizedKind,
        expectsReply: expectsReply === true,
        ...(runMeta.sessionBinding || {}),
        idempotencyKey: `${runId}:interim:${buildInterimSignature({
          content: normalizedContent,
          kind: normalizedKind,
          expectsReply,
          platform: 'voice_live',
        })}`,
      },
    });
    if (!delivery.ok) return { sent: false, skipped: true, reason: delivery.reason };
  } else {
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
  }

  if (!runMeta.interimSignatures) runMeta.interimSignatures = new Set();
  if (!Array.isArray(runMeta.interimMessages)) runMeta.interimMessages = [];
  runMeta.interimSignatures.add(signature);
  runMeta.interimMessages.push({
    content: normalizedContent,
    kind: normalizedKind,
    expectsReply: expectsReply === true,
    deferFollowUp: deferFollowUp === true,
    createdAt,
  });
  runMeta.lastInterimMessage = normalizedContent;
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
  if (terminalInterim) {
    runMeta.terminalInterim = {
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
    progressLedger: engine.buildProgressLedgerSnapshot(runMeta),
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
