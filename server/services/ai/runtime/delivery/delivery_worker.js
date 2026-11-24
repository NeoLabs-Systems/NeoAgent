'use strict';

const { createHash } = require('crypto');
const outbox = require('./outbox_repository');
const { claimFinalDelivery, loadRun, transition } = require('../run_state_machine');
const { RUNTIME_STATES, MESSAGE_KINDS } = require('../constants');
const { EVENT_TYPES } = require('../events/event_types');
const { recordEventSafe } = require('../events/run_event_store');
const { isSafeMessagingDeliveryRetry } = require('../../loop/messaging_delivery');
const { buildInterimMetadata } = require('../../interim');
const { isRawToolCall } = require('../../outputSanitizer');

// Which outbox kind a purpose is stored as.
const KIND_BY_PURPOSE = Object.freeze({
  final: MESSAGE_KINDS.FINAL,
  progress: MESSAGE_KINDS.PROGRESS,
  interim: MESSAGE_KINDS.INTERIM,
  reply: MESSAGE_KINDS.INTERIM,
  message: MESSAGE_KINDS.INTERIM,
  notify: MESSAGE_KINDS.INTERIM,
});

function recipientDigest(recipient) {
  return recipient
    ? createHash('sha256').update(String(recipient)).digest('hex').slice(0, 16)
    : null;
}

function record(run, eventType, entry, extra = {}) {
  recordEventSafe({
    runId: run.id,
    userId: run.userId,
    agentId: run.agentId,
    eventType,
    payload: {
      outbox_id: entry?.id || null,
      channel: entry?.channel || null,
      purpose: entry?.purpose || null,
      slot: entry?.slot || null,
      recipient_digest: recipientDigest(entry?.recipient),
      ...extra,
    },
  });
}

function slotForContent(content) {
  return outbox.contentHash(content).slice(0, 32);
}

/**
 * The single commit point for anything a run shows a user. Every path (final
 * answer, send_message, interim update, progress heartbeat, task result) reserves
 * its slot here before transmitting, so "the same answer twice" is a state the
 * outbox cannot enter rather than something each caller has to remember to check.
 *
 * `transmit` returns { ok, ambiguous, error, skippedTransmission, platformMessageId }.
 * A send that may have reached the platform is never retried.
 */
async function commitDelivery({
  run,
  scopeId = null,
  channel,
  recipient = null,
  purpose,
  slot,
  content,
  metadata = {},
  dedupeContent = true,
  allowEmptyContent = false,
  transmit,
  beforeSend = null,
}) {
  const startedAt = Date.now();
  const text = String(content || '').trim();
  if (isRawToolCall(text)) return { ok: false, reason: 'raw_tool_call' };
  if (!text && !allowEmptyContent) return { ok: false, reason: 'empty_content' };

  const { entry, fresh } = outbox.reserve({
    runId: run.id,
    scopeId: scopeId || run.id,
    channel,
    recipient,
    messageKind: KIND_BY_PURPOSE[purpose] || MESSAGE_KINDS.INTERIM,
    purpose,
    slot,
    payload: { content: text, metadata },
  });
  if (!fresh) {
    record(run, EVENT_TYPES.DELIVERY_SUPPRESSED, entry, { reason: `slot_${entry.status}` });
    return {
      ok: entry.status === 'delivered' || entry.status === 'suppressed',
      duplicate: true,
      reason: entry.status === 'ambiguous' || entry.status === 'pending' ? 'ambiguous' : 'duplicate_slot',
      status: entry.status,
      outboxId: entry.id,
      content: text,
    };
  }
  record(run, EVENT_TYPES.DELIVERY_RESERVED, entry);

  const previous = dedupeContent ? outbox.findDeliveredContent(entry.scopeId, recipient, text, entry.id) : null;
  if (previous?.status === 'ambiguous') {
    outbox.markFailed(entry.id, { ambiguous: true });
    record(run, EVENT_TYPES.DELIVERY_FAILED, entry, { ambiguous: true });
    return { ok: false, reason: 'ambiguous', outboxId: entry.id };
  }
  if (previous) {
    outbox.markSuppressed(entry.id);
    record(run, EVENT_TYPES.DELIVERY_SUPPRESSED, entry, { reason: 'same_content' });
    return { ok: true, duplicate: true, reason: 'same_content', outboxId: entry.id, content: text };
  }

  if (beforeSend) {
    const gate = beforeSend(entry);
    if (gate && !gate.ok) {
      outbox.markFailed(entry.id);
      return { ok: false, reason: gate.reason, claim: gate, outboxId: entry.id };
    }
  }

  let delivery;
  try {
    delivery = await transmit(entry);
  } catch (error) {
    // Only a failure that provably happened before the platform took the message
    // reopens the slot. A timeout, an abort, or a dropped connection may have
    // landed, and sending again is how the same answer arrives twice.
    delivery = {
      ok: false,
      ambiguous: !isSafeMessagingDeliveryRetry(error),
      error: error?.message || String(error),
      thrown: error,
    };
  }

  if (delivery.ok && delivery.skippedTransmission) {
    outbox.markSuppressed(entry.id);
    record(run, EVENT_TYPES.DELIVERY_SUPPRESSED, entry, { reason: delivery.reason || 'not_transmitted' });
    return { ok: true, duplicate: true, reason: delivery.reason || 'not_transmitted', outboxId: entry.id, content: text };
  }

  if (delivery.ok) {
    outbox.markDelivered(entry.id, { platformMessageId: delivery.platformMessageId || null });
    outbox.recordAttempt(entry.id, { status: 'delivered', platformMessageId: delivery.platformMessageId || null });
    record(run, EVENT_TYPES.DELIVERY_SENT, entry, { duration_ms: Date.now() - startedAt });
    return {
      ok: true,
      outboxId: entry.id,
      content: text,
      platformMessageId: delivery.platformMessageId || null,
      result: delivery.result,
    };
  }

  outbox.markFailed(entry.id, { ambiguous: delivery.ambiguous === true });
  outbox.recordAttempt(entry.id, {
    status: delivery.ambiguous ? 'ambiguous' : 'failed',
    error: delivery.error,
  });
  record(run, EVENT_TYPES.DELIVERY_FAILED, entry, {
    duration_ms: Date.now() - startedAt,
    ambiguous: delivery.ambiguous === true,
  });
  return {
    ok: false,
    reason: delivery.ambiguous ? 'ambiguous' : 'delivery_failed',
    outboxId: entry.id,
    error: delivery.error,
    thrown: delivery.thrown,
  };
}

/**
 * The run's final answer: at most one per run, committed by compare-and-swap on
 * the run row before anything is sent.
 */
async function requestFinalDelivery({
  engine,
  runId,
  scopeId = null,
  content,
  channel = 'web',
  recipient = null,
  workerId = null,
  eventBus = null,
  metadata = {},
}) {
  const run = loadRun(runId);
  if (!run) return { ok: false, reason: 'not_found' };
  if (run.finalDeliveryId) {
    const entry = outbox.listForRun(runId).find((item) => item.id === run.finalDeliveryId);
    const confirmed = entry?.status === 'delivered' || entry?.status === 'suppressed';
    const uncertain = entry?.status === 'pending' || entry?.status === 'ambiguous';
    return { ok: false, reason: confirmed ? 'already_committed' : uncertain ? 'ambiguous' : 'delivery_failed', finalDeliveryId: run.finalDeliveryId };
  }
  const text = String(content || '').trim();

  const finish = () => {
    transition({
      runId,
      toState: RUNTIME_STATES.COMPLETED,
      reason: 'final_delivery_confirmed',
      workerId,
      eventBus,
      patch: { finalResponse: text, totalTokens: metadata.totalTokens },
    });
    engine?.markRunFinalDelivery?.(runId, text);
  };

  const result = await commitDelivery({
    run,
    scopeId,
    channel,
    recipient,
    purpose: 'final',
    slot: 'final',
    content: text,
    metadata,
    beforeSend: (entry) => claimFinalDelivery({
      runId,
      deliveryId: entry.id,
      expectedVersion: run.version,
      workerId,
    }),
    transmit: (entry) => transmit(engine, entry, run),
  });

  if (result.ok && result.duplicate && result.reason !== 'not_transmitted' && !loadRun(runId)?.finalDeliveryId) {
    // The answer already reached this chat under another slot. The run still
    // has to commit and close; web clients still need their one run:complete.
    claimFinalDelivery({ runId, deliveryId: result.outboxId, expectedVersion: run.version, workerId });
    if (channel === 'web') engine?.emit?.(run.userId, 'run:complete', { runId, content: text, outboxId: result.outboxId });
  }
  if (result.ok) {
    finish();
    return { ...result, content: text };
  }
  return result;
}

async function requestProgressDelivery({
  engine,
  runId,
  scopeId = null,
  content,
  channel = 'web',
  recipient = null,
  messageKind = MESSAGE_KINDS.PROGRESS,
  slot = null,
  metadata = {},
}) {
  const run = loadRun(runId);
  if (!run) return { ok: false, reason: 'not_found' };
  const text = String(content || '').trim();
  if (!text) return { ok: false, reason: 'empty_content' };

  const result = await commitDelivery({
    run,
    scopeId,
    channel,
    recipient,
    purpose: messageKind === MESSAGE_KINDS.PROGRESS ? 'progress' : 'interim',
    slot: slot || slotForContent(text),
    content: text,
    metadata,
    transmit: (entry) => transmit(engine, entry, run),
  });
  if (result.ok && !result.duplicate) engine?.markRunVisibleProgress?.(runId);
  return result;
}

// Hands a message to the platform behind its channel.
async function transmit(engine, entry, run) {
  const content = String(entry.payload?.content || '').trim();
  const { channel, recipient } = entry;

  // A live voice call that has ended hands its result to the chat below, so a
  // task finishing after the owner hung up is still seen.
  if (channel === 'voice_live') {
    const manager = engine?.voiceRuntimeManager || engine?.app?.locals?.voiceRuntimeManager;
    const result = manager?.presentDelivery(entry);
    if (result && !result.detached) {
      return { ok: true, platformMessageId: `voice:${entry.id}` };
    }
  }

  if (channel === 'messaging') {
    const manager = engine?.messagingManager;
    if (!manager || typeof manager.sendMessage !== 'function') {
      return { ok: false, error: 'messaging_manager_unavailable' };
    }
    const platform = entry.payload?.metadata?.platform || channel;
    const chatId = recipient || entry.payload?.metadata?.chatId;

    // Platform chunking, the behavior pipeline, and safe retries live there. A
    // final answer it declines to send was already visible or was silenced.
    if (entry.messageKind === MESSAGE_KINDS.FINAL
      && typeof engine.deliverMessagingFinalFallback === 'function') {
      const sent = await engine.deliverMessagingFinalFallback({
        runId: run.id,
        userId: run.userId,
        agentId: run.agentId,
        platform,
        chatId,
        content,
      });
      return {
        ok: true,
        skippedTransmission: sent?.sent !== true,
        reason: sent?.reason || 'already_visible',
        platformMessageId: sent?.sent === true ? `messaging:${entry.id}` : null,
      };
    }

    // Marked as interim, so it stays out of what the run reports as its response.
    const result = await manager.sendMessage(run.userId, platform, chatId, content, {
      runId: run.id,
      agentId: run.agentId,
      persistConversation: true,
      metadata: buildInterimMetadata({ kind: 'progress' }),
      deliveryKind: 'interim',
      signal: engine.getRunMeta?.(run.id)?.abortController?.signal || null,
    });
    if (result?.success === true && result?.suppressed !== true) {
      return { ok: true, platformMessageId: result.platformMessageId || result.messageId || null };
    }
    if (result?.deliveryAmbiguous === true) {
      return { ok: false, ambiguous: true, error: result.error || 'ambiguous delivery' };
    }
    return { ok: false, error: result?.error || result?.reason || 'send failed' };
  }

  // Web / API / CLI: emit the content; persistence is the delivery record. An
  // acknowledgement or progress line is a real message to the user, so it goes
  // out on the assistant-interim channel rather than run:interim, which carries
  // short runtime status notes under a different field name.
  if (engine && typeof engine.emit === 'function') {
    if (entry.messageKind === MESSAGE_KINDS.FINAL) {
      engine.emit(run.userId, 'run:complete', {
        runId: run.id,
        content,
        messageKind: entry.messageKind,
        outboxId: entry.id,
      });
    } else {
      engine.emit(run.userId, 'run:assistant_interim', {
        runId: run.id,
        content,
        kind: entry.messageKind,
        platform: 'web',
        outboxId: entry.id,
      });
    }
  }
  return { ok: true, platformMessageId: `local:${entry.id}` };
}

module.exports = {
  commitDelivery,
  requestFinalDelivery,
  requestProgressDelivery,
  slotForContent,
  transmit,
};
