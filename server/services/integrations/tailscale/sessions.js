'use strict';

const crypto = require('node:crypto');
const { upsertAccountApp } = require('../connection_store');
const { assertNodeCredentials } = require('./runtime');

const SESSION_TTL_MS = 5 * 60 * 1000;

class TailscaleSessions {
  constructor(runtime) {
    this.runtime = runtime;
    this.sessions = new Map();
    this.stopping = false;
  }

  async begin({ userId, agentId, appKey, signal }) {
    if (this.stopping) throw new Error('Tailscale integration is stopping.');
    if (appKey !== 'tailnet') throw new Error('Unknown Tailscale app.');
    const id = crypto.randomBytes(24).toString('hex');
    const session = { id, userId, agentId, appId: appKey, status: 'connecting', loginUrl: null, connectionId: null, accountEmail: null };
    this.sessions.set(id, session);
    session.timer = setTimeout(() => {
      this.sessions.delete(id);
      if (session.status === 'connecting') void this.runtime.cancelLogin(userId, id).catch(() => {});
    }, SESSION_TTL_MS).unref();
    try {
      for (const previous of this.sessions.values()) {
        if (previous !== session && previous.userId === userId && previous.agentId === agentId && previous.status === 'connecting') {
          previous.status = 'failed';
          await this.runtime.cancelLogin(userId, previous.id);
        }
      }
      if (session.status !== 'connecting') throw new Error('Tailscale sign-in was replaced by a new request.');
      const started = await this.runtime.call(userId, `${userId}:${agentId}:login`, { action: 'login' }, signal, id);
      if (session.status !== 'connecting') throw new Error('Tailscale sign-in was canceled.');
      const url = new URL(started.loginUrl);
      if (url.origin !== 'https://login.tailscale.com' || url.username || url.password) throw new Error('Tailscale returned an invalid sign-in URL.');
      session.loginUrl = url.toString();
      return { status: 'interactive_connect', sessionId: id, loginUrl: session.loginUrl, url: `/api/integrations/tailscale/connect/${id}` };
    } catch (error) {
      session.status = 'failed';
      session.error = 'Could not start Tailscale sign-in. Please try again.';
      await this.runtime.cancelLogin(userId, id).catch(() => {});
      throw error;
    }
  }

  async cancel(userId, agentId, id) {
    const session = this.sessions.get(String(id));
    if (!session || session.userId !== userId || String(session.agentId) !== String(agentId)) return;
    session.status = 'failed';
    clearTimeout(session.timer);
    await this.runtime.cancelLogin(userId, session.id);
    this.sessions.delete(session.id);
  }

  async get(userId, agentId, id) {
    const session = this.sessions.get(String(id));
    if (!session || session.userId !== userId || String(session.agentId) !== String(agentId)) return null;
    if (session.status === 'connecting') {
      if (!session.polling) session.polling = this.finish(session).finally(() => { session.polling = null; });
      await session.polling;
    }
    return {
      id: session.id, provider: 'tailscale', appId: session.appId, status: session.status,
      loginUrl: session.loginUrl, connectionId: session.connectionId, accountEmail: session.accountEmail, error: session.error || null,
    };
  }

  async finish(session) {
    const result = await this.runtime.loginStatus(session.userId, session.id);
    if (session.status !== 'connecting' || this.stopping || !this.sessions.has(session.id)) return;
    if (result.status === 'connected') {
      assertNodeCredentials(result);
      const accountEmail = `tailscale:${result.tailnet}:${result.nodeId}`;
      const connection = upsertAccountApp({
        userId: session.userId, agentId: session.agentId, providerKey: 'tailscale', appKey: 'tailnet', accountEmail,
        credentials: { nodeId: result.nodeId, state: result.state },
        metadata: { nodeId: result.nodeId, tailnet: result.tailnet, services: [], access_mode: 'read_only' },
      });
      session.status = 'connected';
      session.connectionId = connection.id;
      session.accountEmail = accountEmail;
      await this.runtime.cancelLogin(session.userId, session.id);
    } else if (result.status === 'failed') {
      session.status = 'failed';
      session.error = 'Tailscale sign-in expired or was canceled. Please connect again.';
    }
  }

  async shutdown() {
    this.stopping = true;
    await Promise.allSettled([...this.sessions.values()].map(async (session) => {
      clearTimeout(session.timer);
      if (session.status === 'connecting') await this.runtime.cancelLogin(session.userId, session.id);
    }));
    this.sessions.clear();
  }
}

module.exports = { TailscaleSessions };
