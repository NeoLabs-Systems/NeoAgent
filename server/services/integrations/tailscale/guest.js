'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const { GUEST_TAILSCALED, GUEST_TIMEOUT, GUEST_VOLATILE_DIR } = require('../../runtime/guest_paths');
const { spawn } = require('node:child_process');
const { setTimeout: delay } = require('node:timers/promises');
const { localRequest } = require('./guest_api');
const { requestPeer } = require('./guest_network');
const { authorizeRequest } = require('./policy');

const MAX_STATE_BYTES = 1024 * 1024;
const OUTBOUND_PREFS = Object.freeze({
  WantRunning: true, ShieldsUp: true, RouteAll: false, CorpDNS: false,
  RunSSH: false, AdvertiseRoutes: [], AdvertiseTags: [], ExitNodeID: '', ExitNodeIP: '',
});

const terminatedClients = new WeakSet();
function terminateClient(child, signal) {
  if (!child.pid || terminatedClients.has(child)) return;
  try { process.kill(-child.pid, signal); }
  catch (error) { if (error.code !== 'ESRCH') throw error; }
  if (signal === 'SIGKILL') terminatedClients.add(child);
}

function validateOperation(input) {
  if (!input || !['login', 'list', 'request', 'ping', 'logout'].includes(input.action)) throw new Error('Invalid Tailscale operation.');
  if (!/^[a-f0-9]{48}$/.test(input.operationId || '')) throw new Error('Invalid operation ID.');
  if (input.action === 'login') {
    if (input.authKey || input.state || input.nodeId) throw new Error('Interactive login must create a new node.');
  } else {
    if (input.authKey || typeof input.nodeId !== 'string' || !input.nodeId
      || typeof input.state !== 'string' || !input.state || input.state.length > MAX_STATE_BYTES * 1.4) throw new Error('Node credentials are missing.');
  }
  if (input.action === 'request' || input.action === 'ping') {
    // Enforce the operation policy here as well as on the application server.
    const normalized = authorizeRequest({ metadata_json: JSON.stringify({ services: input.grants }) }, input.action, input.args || {});
    return { ...input, ...normalized };
  }
  return input;
}

class GuestTailscale {
  constructor({ spawnClient = spawn, callApi = localRequest, callPeer = requestPeer, temporaryRoot = GUEST_VOLATILE_DIR } = {}) {
    this.spawnClient = spawnClient;
    this.callApi = callApi;
    this.callPeer = callPeer;
    this.temporaryRoot = temporaryRoot;
    this.active = new Map();
    this.queue = Promise.resolve();
    this.loginResults = new Map();
  }

  async run(input, { signal, onLoginUrl } = {}) {
    const operation = validateOperation(input);
    if (this.active.has(operation.operationId)) throw new Error('Tailscale operation already running.');
    const controller = new AbortController();
    const timeout = AbortSignal.timeout(operation.action === 'login' ? 300000 : 45000);
    const combined = signal ? AbortSignal.any([signal, controller.signal, timeout]) : AbortSignal.any([controller.signal, timeout]);
    const record = { controller, done: null, started: false };
    this.active.set(operation.operationId, record);
    // One short-lived client per VM, even when different agent connections
    // execute concurrently. No idle client or per-connection image is retained.
    record.done = this.queue.then(() => {
      combined.throwIfAborted();
      record.started = true;
      return this.runClient(operation, combined, onLoginUrl);
    });
    this.queue = record.done.catch(() => {});
    try { return await record.done; }
    finally { this.active.delete(operation.operationId); }
  }

  async runClient(operation, signal, onLoginUrl) {
    // Short Unix-socket paths, random private directories, no durable VM state.
    const directory = await fs.mkdtemp(path.join(this.temporaryRoot, 'neo-ts-'));
    await fs.chmod(directory, 0o700);
    const socketPath = path.join(directory, 'api.sock');
    const statePath = path.join(directory, 'state');
    let child;
    let exited;
    let failure;
    try {
      if (operation.state) {
        const state = Buffer.from(operation.state, 'base64');
        if (state.length > MAX_STATE_BYTES) throw new Error('Tailscale node state exceeds limit.');
        await fs.writeFile(statePath, state, { mode: 0o600 });
      }
      signal.throwIfAborted();
      // The guest OS also bounds lifetime if the guest agent itself crashes.
      child = this.spawnClient(GUEST_TIMEOUT, ['--signal=TERM', '--kill-after=2s', operation.action === 'login' ? '310s' : '50s', GUEST_TAILSCALED,
        '--tun=userspace-networking', '--port=0', `--socket=${socketPath}`,
        `--state=${statePath}`, `--statedir=${directory}`, '--no-logs-no-support',
      ], {
        cwd: directory, stdio: 'ignore', detached: true,
        env: { HOME: directory, TS_NO_LOGS_NO_SUPPORT: 'true' },
      });
      exited = new Promise((resolve) => {
        child.once('error', () => { failure = new Error('Tailscale client is unavailable in this VM. Update its guest runtime.'); resolve(); });
        child.once('exit', () => { failure ||= new Error('Tailscale client stopped.'); resolve(); });
      });
      const stop = () => terminateClient(child, 'SIGKILL');
      signal.addEventListener('abort', stop, { once: true });
      try {
        while (true) {
          signal.throwIfAborted();
          if (failure) throw failure;
          try { await this.callApi(socketPath, 'GET', 'status', null, signal); break; }
          catch { await delay(50, undefined, { signal }); }
        }
        await this.callApi(socketPath, 'POST', 'start', {
          UpdatePrefs: { ...OUTBOUND_PREFS, Hostname: 'neoagent' },
        }, signal);
        if (operation.action === 'login') await this.callApi(socketPath, 'POST', 'login-interactive', null, signal);
        let status;
        while (true) {
          signal.throwIfAborted();
          if (failure) throw failure;
          status = await this.callApi(socketPath, 'GET', 'status', null, signal);
          if (status.BackendState === 'Running') break;
          if (operation.action === 'login' && status.AuthURL) {
            const url = new URL(status.AuthURL);
            if (url.origin !== 'https://login.tailscale.com' || url.username || url.password) throw new Error('Tailscale returned an invalid login URL.');
            onLoginUrl?.(url.toString());
          }
          await delay(100, undefined, { signal });
        }
        if (!status.Self?.ID || !status.CurrentTailnet?.Name) throw new Error('Tailscale node identity is unavailable.');
        if (operation.action !== 'login' && status.Self.ID !== operation.nodeId) throw new Error('Node identity changed. Reconnect this integration account.');
        const prefs = await this.callApi(socketPath, 'GET', 'prefs', null, signal);
        if (!prefs.ShieldsUp || prefs.RunSSH || prefs.RouteAll || prefs.CorpDNS || prefs.ExitNodeID || prefs.ExitNodeIP) throw new Error('Tailscale outbound-only policy could not be enforced.');
        let result;
        let operationError;
        if (operation.action === 'logout') {
          await this.callApi(socketPath, 'POST', 'logout', null, signal);
          result = { disconnected: true };
        } else if (operation.action === 'login') result = { connected: true };
        else if (operation.action === 'list') {
          result = { peers: Object.values(status.Peer || {}).map((peer) => ({ id: peer.ID, name: peer.HostName, dnsName: peer.DNSName, online: peer.Online === true })) };
        } else {
          try { result = await this.callPeer(socketPath, status, operation, { signal }); }
          catch (error) {
            signal.throwIfAborted();
            operationError = error.message;
          }
        }
        terminateClient(child, 'SIGTERM');
        await Promise.race([exited, delay(2000, undefined, { ref: false })]);
        if (child.exitCode === null && child.signalCode === null) { terminateClient(child, 'SIGKILL'); await exited; }
        if (operation.action !== 'logout' && (await fs.stat(statePath)).size > MAX_STATE_BYTES) throw new Error('Tailscale node state exceeds limit.');
        const state = operation.action === 'logout' ? null : await fs.readFile(statePath);
        if (state && state.length > MAX_STATE_BYTES) throw new Error('Tailscale node state exceeds limit.');
        return { result, error: operationError, nodeId: status.Self.ID, tailnet: status.CurrentTailnet.Name, state: state?.toString('base64') || null };
      } finally { signal.removeEventListener('abort', stop); }
    } finally {
      if (child && !failure) { terminateClient(child, 'SIGKILL'); await exited; }
      await fs.rm(directory, { recursive: true, force: true });
    }
  }

  async beginLogin(input, { signal } = {}) {
    validateOperation(input);
    let ready;
    let fail;
    const started = new Promise((resolve, reject) => { ready = resolve; fail = reject; });
    const operationId = input.operationId;
    this.loginResults.set(operationId, { status: 'connecting' });
    const completion = this.run(input, { signal, onLoginUrl: (loginUrl) => ready({ status: 'connecting', loginUrl }) });
    completion.then((result) => {
      this.loginResults.set(operationId, { status: 'connected', ...result });
      ready({ status: 'connected' });
    }, () => {
      this.loginResults.set(operationId, { status: 'failed', error: 'Tailscale sign-in ended. Please connect again.' });
      fail(new Error('Tailscale sign-in could not start. Please connect again.'));
    });
    completion.finally(() => {
      setTimeout(() => this.loginResults.delete(operationId), 300000).unref();
    }).catch(() => {});
    return started;
  }

  loginStatus(operationId) {
    return this.loginResults.get(operationId) || { status: 'failed', error: 'Tailscale sign-in expired. Please connect again.' };
  }

  async cancel(operationId) {
    const record = this.active.get(operationId);
    if (record) {
      record.controller.abort(new Error('Tailscale operation canceled.'));
      if (record.started) await record.done.catch(() => {});
    }
    this.loginResults.delete(operationId);
  }

  async shutdown() {
    await Promise.all([...this.active.keys()].map((id) => this.cancel(id)));
    this.loginResults.clear();
  }
}

module.exports = { GuestTailscale, OUTBOUND_PREFS, validateOperation };
