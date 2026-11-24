'use strict';

const crypto = require('node:crypto');
const db = require('../../../db/database');
const { encryptValue, decryptValue } = require('../secrets');
const { getConnectionAccessMode } = require('../access');
const { authorizeRequest, servicesFor } = require('./policy');

function assertNodeCredentials(credentials) {
  if (typeof credentials?.nodeId !== 'string' || !credentials.nodeId
    || typeof credentials?.state !== 'string' || !credentials.state || credentials.state.length > 1500000) {
    throw new Error('Tailscale node credentials are missing. Reconnect this integration account.');
  }
}

function connectionScope(connection) {
  return `${connection.user_id}:${connection.agent_id}:${connection.id}`;
}

class TailscaleRuntime {
  constructor(getRuntimeManager) {
    this.getRuntimeManager = getRuntimeManager;
    this.active = new Map();
    this.stopping = false;
  }

  requireRuntime() {
    const runtime = this.getRuntimeManager();
    if (!runtime?.computerBackend?.vmManager) throw new Error('Tailscale requires an isolated per-user QEMU or Docker computer runtime. Host and local computer modes are not supported.');
    return runtime;
  }

  async call(userId, scope, payload, signal, operationId = crypto.randomBytes(24).toString('hex')) {
    if (this.stopping) throw new Error('Tailscale integration is stopping.');
    const runtime = this.requireRuntime();
    signal?.throwIfAborted();
    const controller = new AbortController();
    const combined = signal ? AbortSignal.any([signal, controller.signal]) : controller.signal;
    const record = { userId, scope, controller, done: null };
    this.active.set(operationId, record);
    record.done = Promise.resolve().then(() => runtime.requestComputer(userId, 'POST', '/integrations/tailscale', {
      ...payload, operationId,
    }, { deviceTarget: 'cloud', signal: combined, timeoutMs: 60000, retryCount: 0, maxResponseBytes: 3 * 1024 * 1024 }));
    try {
      const response = await record.done;
      if (!response || typeof response !== 'object') throw new Error('Invalid Tailscale runtime response.');
      return response;
    } finally {
      if (combined.aborted) {
        // Cancellation uses a fresh signal so aborting the original call cannot
        // skip termination of the client inside the user's VM.
        await runtime.requestComputer(userId, 'POST', `/integrations/tailscale/${operationId}/cancel`, {}, {
          deviceTarget: 'cloud', timeoutMs: 10000, retryCount: 0,
        });
      }
      this.active.delete(operationId);
    }
  }

  loginStatus(userId, operationId) {
    return this.requireRuntime().requestComputer(userId, 'GET', `/integrations/tailscale/${operationId}/login-status`, undefined,
      { deviceTarget: 'cloud', timeoutMs: 10000, retryCount: 0, maxResponseBytes: 2 * 1024 * 1024 });
  }

  async cancelLogin(userId, operationId) {
    await this.requireRuntime().requestComputer(userId, 'POST', `/integrations/tailscale/${operationId}/cancel`, {},
      { deviceTarget: 'cloud', timeoutMs: 10000, retryCount: 0 });
  }

  async execute(connection, action, args = {}, signal = null) {
    // Re-read after any execution queue: disconnects and policy changes must
    // apply to queued calls as well as to newly selected connections.
    const current = db.prepare(`SELECT * FROM integration_connections
      WHERE id = ? AND user_id = ? AND agent_id = ? AND provider_key = 'tailscale' AND status = 'connected'`)
      .get(connection.id, connection.user_id, connection.agent_id);
    if (!current) throw new Error('Tailscale connection is no longer available.');
    if (action === 'request' && getConnectionAccessMode(current) === 'read_only') throw new Error('Tailscale HTTP operations require read/write access.');
    const credentials = JSON.parse(decryptValue(current.credentials_json));
    assertNodeCredentials(credentials);
    const operation = action === 'list' ? {} : authorizeRequest(current, action, args);
    const response = await this.call(current.user_id, connectionScope(current), {
      action, state: credentials.state, nodeId: credentials.nodeId,
      args, grants: operation.grants || [],
    }, signal);
    assertNodeCredentials(response);
    if (response.nodeId !== credentials.nodeId) throw new Error('Tailscale node identity changed.');
    db.prepare(`UPDATE integration_connections SET credentials_json = ?, updated_at = datetime('now')
      WHERE id = ? AND user_id = ? AND agent_id = ? AND status = 'connected'`)
      .run(encryptValue(JSON.stringify({ nodeId: response.nodeId, state: response.state })), current.id, current.user_id, current.agent_id);
    if (response.error) throw new Error(response.error);
    if (action === 'list') return { ...response.result, services: servicesFor(current) };
    return response.result;
  }

  async stop(scope) {
    const matching = [...this.active.entries()].filter(([, record]) => record.scope === scope);
    for (const [, record] of matching) record.controller.abort(new Error('Tailscale connection was disconnected.'));
    await Promise.allSettled(matching.map(([, record]) => record.done));
    const runtime = this.getRuntimeManager();
    for (const [operationId, record] of matching) {
      await runtime.requestComputer(record.userId, 'POST', `/integrations/tailscale/${operationId}/cancel`, {}, {
        deviceTarget: 'cloud', timeoutMs: 10000, retryCount: 0,
      });
      this.active.delete(operationId);
    }
  }

  async shutdown() {
    this.stopping = true;
    await Promise.all([...new Set([...this.active.values()].map((record) => record.scope))].map((scope) => this.stop(scope)));
  }
}

module.exports = { TailscaleRuntime, assertNodeCredentials, connectionScope };
