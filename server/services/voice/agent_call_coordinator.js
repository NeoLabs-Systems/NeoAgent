'use strict';

const { randomUUID } = require('crypto');
const { resolveAgent } = require('../agents/manager');
const { createServiceLogger } = require('../../utils/logger');

const DEFAULT_RING_TIMEOUT_MS = 30_000;
// How long a call that needs a phone waits for one to come back. Placing the call
// that triggers it sends the app to the background, where a phone may suspend it.
const DEFAULT_MOBILE_WAIT_MS = 2 * 60 * 1000;
// Lets the declined call clear off the phone before this one rings.
const DEFAULT_CALL_BACK_DELAY_MS = 5000;

const logger = createServiceLogger('AgentCalls');

const DESKTOP_CLIENTS = new Set(['macos', 'windows', 'linux', 'fuchsia']);
const MOBILE_USER_AGENT = /\b(iPhone|iPad|Android)\b/;
const DESKTOP_USER_AGENT = /\b(Macintosh|Windows NT|X11|CrOS|Linux)\b/;

// Clients say what they run on when they connect. An older one is judged by its
// user agent, where only a recognisable desktop rules it out: a missed call back
// costs more than a laptop ringing as well.
function isMobileAppHandshake(handshake) {
  const client = handshake?.query?.client;
  if (client) return !DESKTOP_CLIENTS.has(client);
  const userAgent = String(handshake?.headers?.['user-agent'] || '');
  return MOBILE_USER_AGENT.test(userAgent) || !DESKTOP_USER_AGENT.test(userAgent);
}

function describeClient(socket) {
  const handshake = socket?.handshake;
  const kind = handshake?.query?.client || String(handshake?.headers?.['user-agent'] || 'unknown').slice(0, 40);
  return `${kind}${socket?.data?.mobileApp === true ? ' (phone)' : ''}`;
}

class AgentCallCoordinator {
  constructor({
    io,
    agentEngine,
    voiceRuntimeManager,
    ringTimeoutMs = DEFAULT_RING_TIMEOUT_MS,
    mobileWaitMs = DEFAULT_MOBILE_WAIT_MS,
    callBackDelayMs = DEFAULT_CALL_BACK_DELAY_MS,
  }) {
    this.io = io;
    this.agentEngine = agentEngine;
    this.voiceRuntimeManager = voiceRuntimeManager;
    this.ringTimeoutMs = ringTimeoutMs;
    this.mobileWaitMs = mobileWaitMs;
    this.callBackDelayMs = callBackDelayMs;
    this.pendingById = new Map();
    this.pendingByUser = new Map();
    this.shuttingDown = false;
  }

  /** Rings the phone back after a call on a platform that cannot carry voice was declined. */
  async callBack({ userId, agentId, platform, callerId }) {
    await new Promise((resolve) => { setTimeout(resolve, this.callBackDelayMs); });
    const result = await this.callUser({
      userId,
      agentId,
      requireMobileApp: true,
      openingMessage: `${callerId} just tried to call you on ${platform}, which cannot carry a voice call,`
        + ' so you are calling back in the app. Greet them and ask what they need.',
    });
    logger.info(`Call back after a ${platform} call: ${result.status}${result.reason ? ` (${result.reason})` : ''}.`);
    return result;
  }

  async callUser({ userId, agentId, runId, conversationId = null, openingMessage, signal = null, requireMobileApp = false }) {
    const content = String(openingMessage || '').trim();
    if (!content) return { status: 'unavailable', reason: 'opening_message is required' };
    if (this.shuttingDown || signal?.aborted) return { status: 'cancelled' };
    // A call still waiting for a phone has rung nobody, so a real one goes first.
    const pending = this.#pendingForUser(userId);
    if (pending?.waitingForMobile && !requireMobileApp) this.#finish(pending, 'superseded');
    if (this.pendingByUser.has(String(userId))) return { status: 'busy' };
    if (this.voiceRuntimeManager.hasActiveSessionForUser(userId)) return { status: 'busy' };

    const sockets = await this.io.in(`user:${userId}`).fetchSockets();
    const waitingForMobile = requireMobileApp && !sockets.some((socket) => socket.data?.mobileApp === true);
    const recipients = new Set(waitingForMobile ? [] : sockets.map((socket) => socket.id));
    if (recipients.size === 0 && !waitingForMobile) {
      return {
        status: 'unavailable',
        reason: 'no_connected_app',
        message: 'The call_user tool is available, but the app is not currently connected to receive the call.',
      };
    }

    const agent = resolveAgent(userId, agentId);
    const callId = randomUUID();
    const waitMs = waitingForMobile ? this.mobileWaitMs : this.ringTimeoutMs;
    const expiresAt = new Date(Date.now() + waitMs).toISOString();
    if (waitingForMobile) {
      const connected = sockets.map(describeClient).join(', ') || 'nothing';
      logger.info(`No phone is connected (${connected}); waiting up to ${Math.round(waitMs / 1000)}s for one to ring.`);
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
        waitingForMobile,
      };
      invitation.timer = setTimeout(() => this.#finish(invitation, 'missed'), waitMs);
      invitation.timer.unref?.();
      if (signal) {
        invitation.abortHandler = () => this.#finish(invitation, 'cancelled');
        signal.addEventListener('abort', invitation.abortHandler, { once: true });
      }
      this.pendingById.set(callId, invitation);
      this.pendingByUser.set(String(userId), callId);
      if (waitingForMobile) return;
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
    if (invitation.waitingForMobile) {
      if (socket.data?.mobileApp !== true) return false;
      // The phone is back, so now it rings for the usual time.
      invitation.waitingForMobile = false;
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
  isMobileAppHandshake,
};
