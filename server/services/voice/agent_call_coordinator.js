'use strict';

const { randomUUID } = require('crypto');
const db = require('../../db/database');
const { resolveAgent } = require('../agents/manager');
const { createServiceLogger } = require('../../utils/logger');

const DEFAULT_RING_TIMEOUT_MS = 30_000;

const logger = createServiceLogger('AgentCalls');

class AgentCallCoordinator {
  constructor({ io, agentEngine, voiceRuntimeManager, ringTimeoutMs = DEFAULT_RING_TIMEOUT_MS }) {
    this.io = io;
    this.agentEngine = agentEngine;
    this.voiceRuntimeManager = voiceRuntimeManager;
    this.ringTimeoutMs = ringTimeoutMs;
    this.pendingById = new Map();
    this.pendingByUser = new Map();
    this.shuttingDown = false;
  }

  async callUser({ userId, agentId, runId, conversationId = null, openingMessage, signal = null }) {
    const content = String(openingMessage || '').trim();
    if (!content) return { status: 'unavailable', reason: 'opening_message is required' };
    if (this.shuttingDown || signal?.aborted) return { status: 'cancelled' };
    if (this.pendingByUser.has(String(userId))) return { status: 'busy' };
    if (this.voiceRuntimeManager.hasActiveSessionForUser(userId)) return { status: 'busy' };

    const sockets = await this.io.in(`user:${userId}`).fetchSockets();
    const recipients = new Set(sockets.map((socket) => socket.id));
    if (recipients.size === 0) return { status: 'unavailable' };

    const agent = resolveAgent(userId, agentId);
    const callId = randomUUID();
    const expiresAt = new Date(Date.now() + this.ringTimeoutMs).toISOString();

    return new Promise((resolve) => {
      const invitation = {
        callId,
        userId,
        agentId: agent?.id || agentId || null,
        agentName: String(agent?.display_name || 'NeoAgent').trim() || 'NeoAgent',
        runId: String(runId || '').trim() || null,
        conversationId: String(conversationId || '').trim() || null,
        openingMessage: content,
        expiresAt,
        recipients,
        resolve,
        signal,
        abortHandler: null,
        timer: null,
        settled: false,
      };
      invitation.timer = setTimeout(() => this.#finish(invitation, 'missed'), this.ringTimeoutMs);
      invitation.timer.unref?.();
      if (signal) {
        invitation.abortHandler = () => this.#finish(invitation, 'cancelled');
        signal.addEventListener('abort', invitation.abortHandler, { once: true });
      }
      this.pendingById.set(callId, invitation);
      this.pendingByUser.set(String(userId), callId);
      this.io.to(`user:${userId}`).emit('voice:incoming_call', {
        callId,
        agentId: invitation.agentId,
        agentName: invitation.agentName,
        expiresAt,
      });
    });
  }

  async accept(callId, userId, socket) {
    const invitation = this.#ownedInvitation(callId, userId);
    if (!invitation || invitation.settled) return { accepted: false, status: 'unavailable' };
    if (!invitation.recipients.has(socket.id)) return { accepted: false, status: 'unavailable' };
    if (this.voiceRuntimeManager.hasActiveSessionForUser(userId)) {
      this.#finish(invitation, 'busy');
      return { accepted: false, status: 'busy' };
    }

    invitation.settled = true;
    this.#remove(invitation);
    socket.to(`user:${userId}`).emit('voice:call_cancelled', {
      callId: invitation.callId,
      reason: 'answered_elsewhere',
    });

    try {
      const session = await this.voiceRuntimeManager.openFlutterSession({
        userId,
        agentId: invitation.agentId,
        socket,
        sessionId: invitation.callId,
        originRunId: invitation.runId,
        originConversationId: invitation.conversationId,
        agentInitiated: true,
      });
      if (!socket.data.voiceSessionIds) socket.data.voiceSessionIds = new Set();
      socket.data.voiceSessionIds.add(session.id);
      this.#recordOpening(invitation);
      await this.voiceRuntimeManager.deliveryPresenter.present(session, {
        content: invitation.openingMessage,
        kind: 'opening',
        messageId: randomUUID(),
        runId: invitation.runId,
      });
      invitation.resolve({ status: 'accepted', callId: invitation.callId, sessionId: session.id });
      return { accepted: true, status: 'accepted', sessionId: session.id };
    } catch (error) {
      logger.warn('Failed to accept agent call', error?.message || error);
      this.io.to(`user:${userId}`).emit('voice:call_ended', {
        callId: invitation.callId,
        reason: 'unavailable',
      });
      invitation.resolve({ status: 'unavailable' });
      return { accepted: false, status: 'unavailable' };
    }
  }

  decline(callId, userId, socket) {
    const invitation = this.#ownedInvitation(callId, userId);
    if (!invitation || invitation.settled) return { declined: false, status: 'unavailable' };
    invitation.recipients.delete(socket.id);
    socket.emit('voice:call_ended', { callId: invitation.callId, reason: 'declined' });
    if (invitation.recipients.size === 0) this.#finish(invitation, 'declined');
    return { declined: true, status: 'declined' };
  }

  handleDisconnect(socketId, userId) {
    const callId = this.pendingByUser.get(String(userId));
    const invitation = callId ? this.pendingById.get(callId) : null;
    if (!invitation) return;
    invitation.recipients.delete(socketId);
    if (invitation.recipients.size === 0) this.#finish(invitation, 'unavailable');
  }

  notifySessionClosed(session, reason = 'closed') {
    if (!session?.agentInitiated) return;
    this.io.to(`user:${session.userId}`).emit('voice:call_ended', {
      callId: session.id,
      reason,
    });
  }

  shutdown() {
    this.shuttingDown = true;
    for (const invitation of Array.from(this.pendingById.values())) {
      this.#finish(invitation, 'cancelled');
    }
  }

  #ownedInvitation(callId, userId) {
    const invitation = this.pendingById.get(String(callId || '').trim());
    if (!invitation || String(invitation.userId) !== String(userId)) return null;
    return invitation;
  }

  #recordOpening(invitation) {
    const metadata = JSON.stringify({
      platform: 'voice_live',
      callId: invitation.callId,
      kind: 'opening',
      agentInitiated: true,
    });
    db.prepare(
      `INSERT INTO conversation_history
        (user_id, agent_id, agent_run_id, role, content, metadata)
       VALUES (?, ?, ?, 'assistant', ?, ?)`,
    ).run(
      invitation.userId,
      invitation.agentId,
      invitation.runId,
      invitation.openingMessage,
      metadata,
    );
    if (invitation.conversationId) {
      db.prepare(
        `INSERT INTO conversation_messages (conversation_id, role, content)
         VALUES (?, 'assistant', ?)`,
      ).run(invitation.conversationId, invitation.openingMessage);
    }
  }

  #finish(invitation, status) {
    if (!invitation || invitation.settled) return;
    invitation.settled = true;
    this.#remove(invitation);
    this.io.to(`user:${invitation.userId}`).emit('voice:call_ended', {
      callId: invitation.callId,
      reason: status,
    });
    invitation.resolve({ status, callId: invitation.callId });
  }

  #remove(invitation) {
    clearTimeout(invitation.timer);
    if (invitation.signal && invitation.abortHandler) {
      invitation.signal.removeEventListener('abort', invitation.abortHandler);
    }
    this.pendingById.delete(invitation.callId);
    if (this.pendingByUser.get(String(invitation.userId)) === invitation.callId) {
      this.pendingByUser.delete(String(invitation.userId));
    }
  }
}

module.exports = {
  AgentCallCoordinator,
  DEFAULT_RING_TIMEOUT_MS,
};
