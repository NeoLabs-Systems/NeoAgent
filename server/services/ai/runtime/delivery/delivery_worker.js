'use strict';

const { randomUUID } = require('crypto');
const outbox = require('./outbox_repository');
const { claimFinalDelivery, loadRun, transition } = require('../run_state_machine');
const { RUNTIME_STATES, MESSAGE_KINDS } = require('../constants');
const { EVENT_TYPES, VISIBILITY } = require('../events/event_types');

/**
 * Single authority for external final delivery.
 * All modules request delivery; only this worker commits final CAS + send.
 */
async function requestFinalDelivery({
  engine,
  runId,
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
    return {
      ok: false,
      reason: 'already_committed',
      finalDeliveryId: run.finalDeliveryId,
    };
  }

  const payload = {
    content: String(content || '').trim(),
    metadata,
  };
  if (!payload.content) {
    return { ok: false, reason: 'empty_content' };
  }

  const entry = outbox.enqueue({
    runId,
    channel,
    recipient,
    messageKind: MESSAGE_KINDS.FINAL,
    payload,
    idempotencyKey: `${runId}:final:1`,
    sequence: 1,
  });

  const claim = claimFinalDelivery({
    runId,
    deliveryId: entry.id,
    expectedVersion: run.version,
    workerId,
  });
  if (!claim.ok) {
    return { ok: false, reason: claim.reason, claim };
  }

  if (eventBus) {
    eventBus.publish({
      runId,
      userId: run.userId,
      agentId: run.agentId,
      eventType: EVENT_TYPES.DELIVERY_COMMITTED,
      actor: workerId,
      payload: {
        outbox_id: entry.id,
        channel,
        message_kind: MESSAGE_KINDS.FINAL,
      },
      visibility: VISIBILITY.OPERATOR,
    });
  }

  const delivery = await transmit(engine, entry, run);
  if (delivery.ok) {
    outbox.markDelivered(entry.id, { platformMessageId: delivery.platformMessageId || null });
    outbox.recordAttempt(entry.id, {
      status: 'delivered',
      platformMessageId: delivery.platformMessageId || null,
    });
    if (eventBus) {
      eventBus.publish({
        runId,
        userId: run.userId,
        agentId: run.agentId,
        eventType: EVENT_TYPES.DELIVERY_CONFIRMED,
        payload: {
          outbox_id: entry.id,
          platform_message_id: delivery.platformMessageId || null,
        },
        visibility: VISIBILITY.USER,
      });
    }

    transition({
      runId,
      toState: RUNTIME_STATES.COMPLETED,
      reason: 'final_delivery_confirmed',
      workerId,
      eventBus,
      patch: {
        finalResponse: payload.content,
        totalTokens: metadata.totalTokens,
      },
    });

    if (engine?.getRunMeta?.(runId)) {
      engine.markRunFinalDelivery?.(runId, payload.content);
    }

    return {
      ok: true,
      outboxId: entry.id,
      content: payload.content,
      platformMessageId: delivery.platformMessageId || null,
    };
  }

  if (delivery.ambiguous) {
    outbox.markFailed(entry.id, { ambiguous: true, error: delivery.error });
    outbox.recordAttempt(entry.id, {
      status: 'ambiguous',
      error: delivery.error,
    });
    return {
      ok: false,
      reason: 'ambiguous',
      outboxId: entry.id,
      error: delivery.error,
    };
  }

  outbox.markFailed(entry.id, { error: delivery.error });
  outbox.recordAttempt(entry.id, {
    status: 'failed',
    error: delivery.error,
  });
  return {
    ok: false,
    reason: 'delivery_failed',
    outboxId: entry.id,
    error: delivery.error,
  };
}

async function requestProgressDelivery({
  engine,
  runId,
  content,
  channel = 'web',
  recipient = null,
  messageKind = MESSAGE_KINDS.PROGRESS,
  metadata = {},
}) {
  const run = loadRun(runId);
  if (!run) return { ok: false, reason: 'not_found' };
  const text = String(content || '').trim();
  if (!text) return { ok: false, reason: 'empty_content' };

  const entry = outbox.enqueue({
    runId,
    channel,
    recipient,
    messageKind,
    payload: { content: text, metadata },
    idempotencyKey: metadata.idempotencyKey || null,
  });

  const delivery = await transmit(engine, entry, run);
  if (delivery.ok) {
    outbox.markDelivered(entry.id, { platformMessageId: delivery.platformMessageId || null });
    if (engine?.markRunVisibleProgress) {
      engine.markRunVisibleProgress(runId);
    }
    return { ok: true, outboxId: entry.id, content: text };
  }
  if (delivery.ambiguous) {
    outbox.markFailed(entry.id, { ambiguous: true, error: delivery.error });
    return { ok: false, reason: 'ambiguous', error: delivery.error };
  }
  outbox.markFailed(entry.id, { error: delivery.error });
  return { ok: false, reason: 'delivery_failed', error: delivery.error };
}

async function transmit(engine, entry, run) {
  const content = String(entry.payload?.content || '').trim();
  const channel = entry.channel;
  const recipient = entry.recipient;

  try {
    if (channel === 'messaging' || channel === 'telegram' || channel === 'discord' || channel === 'whatsapp') {
      const manager = engine?.messagingManager;
      if (!manager || typeof manager.sendMessage !== 'function') {
        return { ok: false, error: 'messaging_manager_unavailable' };
      }
      const platform = entry.payload?.metadata?.platform || channel;
      const chatId = recipient || entry.payload?.metadata?.chatId;

      // A final result the model already published through send_message must not
      // be transmitted a second time. deliverMessagingFinalFallback owns that
      // guard plus platform chunking, the behavior pipeline, and safe retries;
      // when it skips, the content is already visible and the outbox entry only
      // records the commit.
      if (entry.messageKind === MESSAGE_KINDS.FINAL
        && typeof engine.deliverMessagingFinalFallback === 'function') {
        const fallback = await engine.deliverMessagingFinalFallback({
          runId: run.id,
          userId: run.userId,
          agentId: run.agentId,
          platform,
          chatId,
          content,
        });
        return {
          ok: true,
          skippedTransmission: fallback?.sent !== true,
          platformMessageId: fallback?.sent === true ? `messaging:${entry.id}` : null,
        };
      }

      const result = await manager.sendMessage(
        run.userId,
        platform,
        chatId,
        content,
        {
          runId: run.id,
          agentId: run.agentId,
        },
      );
      if (result?.success === true && result?.suppressed !== true) {
        return {
          ok: true,
          platformMessageId: result.platformMessageId || result.messageId || null,
        };
      }
      if (result?.deliveryAmbiguous === true) {
        return { ok: false, ambiguous: true, error: result.error || 'ambiguous delivery' };
      }
      return { ok: false, error: result?.error || result?.reason || 'send failed' };
    }

    // Web / API / CLI: emit the content; persistence is the delivery record.
    // An acknowledgement or progress line is a real message to the user, so it
    // goes out on the assistant-interim channel rather than run:interim, which
    // carries short runtime status notes under a different field name and would
    // have silently dropped this text.
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
  } catch (error) {
    const ambiguous = error?.deliveryAmbiguous === true
      || /timeout|ECONNRESET|socket hang up/i.test(String(error?.message || ''));
    return {
      ok: false,
      ambiguous,
      error: error?.message || String(error),
    };
  }
}


module.exports = {
  requestFinalDelivery,
  requestProgressDelivery,
  transmit,
};
