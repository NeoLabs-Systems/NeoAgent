'use strict';

const { randomUUID } = require('crypto');
const { resolveAgent } = require('../agents/manager');
const { createServiceLogger } = require('../../utils/logger');

const DEFAULT_RING_TIMEOUT_MS = 30_000;
// How long a call back waits for an app to come back. Placing the call that
// triggers it sends the app to the background, where a phone may suspend it.
const DEFAULT_APP_WAIT_MS = 2 * 60 * 1000;

const logger = createServiceLogger('AgentCalls');

function describeClient(socket) {
  return String(socket?.handshake?.headers?.['user-agent'] || 'unknown').slice(0, 40);
}

class AgentCallCoordinator {
  constructor({
    io,
    agentEngine,
    voiceRuntimeManager,
    ringTimeoutMs = DEFAULT_RING_TIMEOUT_MS,
    appWaitMs = DEFAULT_APP_WAIT_MS,
  }) {
    this.io = io;
    this.agentEngine = agentEngine;
    this.voiceRuntimeManager = voiceRuntimeManager;
    this.ringTimeoutMs = ringTimeoutMs;
    this.appWaitMs = appWaitMs;
    this.pendingById = new Map();
    this.pendingByUser = new Map();
    this.shuttingDown = false;
  }

  /** Rings the phone back after a call on a platform that cannot carry voice was declined. */
  async callBack({ userId, agentId, platform, callerId }) {
    const result = await this.callUser({
      userId,
      agentId,
      waitForApp: true,
      openingMessage: `${callerId} just tried to call you on ${platform}, which cannot carry a voice call,`
        + ' so you are calling back in the app. Greet them and ask what they need.',
    });
    logger.info(`Call back after a ${platform} call: ${result.status}${result.reason ? ` (${result.reason})` : ''}.`);
    return result;
  }

  async callUser({ userId, agentId, runId, conversationId = null, openingMessage, signal = null, waitForApp = false }) {
    const content = String(openingMessage || '').trim();
    if (!content) return { status: 'unavailable', reason: 'opening_message is required' };
    if (this.shuttingDown || signal?.aborted) return { status: 'cancelled' };
    // A call still waiting for an app has rung nobody, so a real one goes first.
    const pending = this.#pendingForUser(userId);
    if (pending?.waitingForApp && !waitForApp) this.#finish(pending, 'superseded');
    if (this.pendingByUser.has(String(userId))) return { status: 'busy' };
    if (this.voiceRuntimeManager.hasActiveSessionForUser(userId)) return { status: 'busy' };

    const sockets = await this.io.in(`user:${userId}`).fetchSockets();
    const recipients = new Set(sockets.map((socket) => socket.id));
    const waitingForApp = waitForApp && recipients.size === 0;
    if (recipients.size === 0 && !waitingForApp) {
      return {
        status: 'unavailable',
        reason: 'no_connected_app',
        message: 'The call_user tool is available, but the app is not currently connected to receive the call.',
      };
    }

    const agent = resolveAgent(userId, agentId);
    const callId = randomUUID();
    const waitMs = waitingForApp ? this.appWaitMs : this.ringTimeoutMs;
    const expiresAt = new Date(Date.now() + waitMs).toISOString();
    if (waitingForApp) {
      logger.info(`No app is connected; waiting up to ${Math.round(waitMs / 1000)}s for one to ring.`);
    } else {
      logger.info(`Ringing ${sockets.map(describeClient).join(', ')}.`);
    }

    return new Promise((resolve) => {
      const invitation = {
        callId,
        userId,
        agentId: agent?.id || agentId || null,
        agentName: String(agent?.display_name || agent?.displayName || '').trim() || 'NeoAgent',
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
        waitingForApp,
      };
      invitation.timer = setTimeout(() => this.#finish(invitation, 'missed'), waitMs);
      invitation.timer.unref?.();
      if (signal) {
        invitation.abortHandler = () => this.#finish(invitation, 'cancelled');
        signal.addEventListener('abort', invitation.abortHandler, { once: true });
      }
      this.pendingById.set(callId, invitation);
      this.pendingByUser.set(String(userId), callId);
      if (waitingForApp) return;
      this.io.to(`user:${userId}`).emit('voice:incoming_call', {
        callId,
        agentId: invitation.agentId,
        agentName: invitation.agentName,
        expiresAt,
      });
    });
  }

  offerPendingCall(socket, userId) {
    const invitation = this.#pendingForUser(userId);
    if (!invitation || !socket?.id) return false;
    if (invitation.waitingForApp) {
      logger.info(`An app came back; ringing ${describeClient(socket)}.`);
      // Now it rings for the usual time.
      invitation.waitingForApp = false;
      invitation.expiresAt = new Date(Date.now() + this.ringTimeoutMs).toISOString();
      clearTimeout(invitation.timer);
      invitation.timer = setTimeout(() => this.#finish(invitation, 'missed'), this.ringTimeoutMs);
      invitation.timer.unref?.();
    }
    invitation.recipients.add(socket.id);
    socket.emit('voice:incoming_call', {
      callId: invitation.callId,
      agentId: invitation.agentId,
      agentName: invitation.agentName,
      expiresAt: invitation.expiresAt,
    });
    return true;
  }

  async accept(callId, userId, socket) {
    const invitation = this.#ownedInvitation(callId, userId);
    if (!invitation || invitation.settled) return { accepted: false, status: 'unavailable' };
    if (this.voiceRuntimeManager.hasActiveSessionForUser(userId)) {
      this.#finish(invitation, 'busy');
      return { accepted: false, status: 'busy' };
    }

    invitation.settled = true;
    invitation.recipients.add(socket.id);
    this.#remove(invitation);
    socket.to(`user:${userId}`).emit('voice:call_cancelled', {
      callId: invitation.callId,
      reason: 'answered_elsewhere',
    });

    let session = null;
    try {
      session = await this.voiceRuntimeManager.openFlutterSession({
        userId,
        agentId: invitation.agentId,
        socket,
        sessionId: invitation.callId,
        originConversationId: invitation.conversationId,
        agentInitiated: true,
      });
      if (!socket.data.voiceSessionIds) socket.data.voiceSessionIds = new Set();
      socket.data.voiceSessionIds.add(session.id);
      // The live model opens the call in its own voice from the run's message.
      session.say(invitation.openingMessage);
      invitation.resolve({ status: 'accepted', callId: invitation.callId, sessionId: session.id });
      return { accepted: true, status: 'accepted', sessionId: session.id };
    } catch (error) {
      logger.warn('Failed to accept agent call', error?.message || error);
      if (session) {
        // The session opened but the greeting failed: release it so the next
        // call is not reported busy.
        socket.data.voiceSessionIds?.delete(session.id);
        await this.voiceRuntimeManager
          .closeSession(session.id, 'open_failed', userId)
          .catch((closeError) => logger.warn('Failed to close agent call session', closeError?.message || closeError));
      }
      this.io.to(`user:${userId}`).emit('voice:call_ended', {
        callId: invitation.callId,
        reason: 'unavailable',
      });
      invitation.resolve({ status: 'unavailable' });
      return { accepted: false, status: 'unavailable' };
    }
  }

  // `later` means the user asked to be called back: that ends the ringing on
  // every device, and the agent hears it as its own outcome.
  decline(callId, userId, socket, { later = false } = {}) {
    const invitation = this.#ownedInvitation(callId, userId);
    if (!invitation || invitation.settled) return { declined: false, status: 'unavailable' };
    if (later) {
      this.#finish(invitation, 'call_later');
      return { declined: true, status: 'call_later' };
    }
    invitation.recipients.delete(socket.id);
    socket.emit('voice:call_ended', { callId: invitation.callId, reason: 'declined' });
    if (invitation.recipients.size === 0) this.#finish(invitation, 'declined');
    return { declined: true, status: 'declined' };
  }

  handleDisconnect(socketId, userId) {
    const invitation = this.#pendingForUser(userId);
    if (!invitation) return;
    invitation.recipients.delete(socketId);
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

  #pendingForUser(userId) {
    const callId = this.pendingByUser.get(String(userId));
    const invitation = callId ? this.pendingById.get(callId) : null;
    if (!invitation || invitation.settled) return null;
    return invitation;
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
