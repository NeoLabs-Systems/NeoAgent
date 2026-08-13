'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { LocalVmExecutionBackend } = require('./backends/local-vm');
const { QemuVMManager } = require('./qemu_vm_manager');
const { ComputerDesktopProvider } = require('./computer_desktop_provider');
const db = require('../../db/database');
const { AndroidController } = require('../android/controller');

const DISPLAY_SESSION_TTL_MS = 5 * 60 * 1000;
const CONTROL_LEASE_TTL_MS = 35 * 60 * 1000;

function createWorkspaceArchive(sourceRoot, destination) {
  return new Promise((resolve, reject) => {
    const child = spawn('tar', ['-czf', destination, '-C', sourceRoot, '.'], {
      stdio: ['ignore', 'ignore', 'pipe'],
      windowsHide: true,
    });
    let stderr = '';
    child.stderr.on('data', (chunk) => {
      if (stderr.length < 64 * 1024) stderr += chunk.toString();
    });
    child.once('error', reject);
    child.once('exit', (code) => {
      if (code === 0) resolve();
      else reject(new Error(stderr.trim() || `Workspace archive failed with exit ${code}.`));
    });
  });
}

function sha256File(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash('sha256');
    const input = fs.createReadStream(filePath);
    input.once('error', reject);
    input.on('data', (chunk) => hash.update(chunk));
    input.once('end', () => resolve(hash.digest('hex')));
  });
}

class RuntimeManager {
  constructor(options = {}) {
    this.shellWorkerPool = options.shellWorkerPool || null;
    this.artifactStore = options.artifactStore || null;
    this.workspaceManager = options.workspaceManager || null;
    this.androidControllers = new Map();
    this.displaySessions = new Map();
    this.controlLeases = new Map();
    this.io = options.io || null;
    this.providerModes = new Map();

    const vmManager = options.computerVmManager
      || (options.computerBackend ? null : new QemuVMManager());
    this.computerBackend = options.computerBackend || new LocalVmExecutionBackend({
      runtimeProfile: 'browser_cli',
      vmManager,
      artifactStore: this.artifactStore,
    });
    this.computerBackend.isIdleProtected = (userId) => Boolean(this.getControlLease(userId));
    this.localComputerBackend = options.localComputerBackend || null;
    this.createAndroidController = options.createAndroidController
      || ((userId) => new AndroidController({
        userId,
        artifactStore: this.artifactStore,
      }));
  }

  getSettings() {
    return {
      runtime_profile: 'cloud-computer',
      runtime_backend: 'qemu',
      computer_backend: 'unified',
      android_backend: 'host',
      mcp_backend: 'host-remote',
    };
  }

  getComputerProvider(userId) {
    const key = String(userId || '').trim();
    if (this.providerModes?.has(key)) return this.providerModes.get(key);
    let provider = 'cloud';
    try {
      const stored = db.prepare(
        'SELECT value FROM user_settings WHERE user_id = ? AND key = ?',
      ).get(userId, 'computer_provider')?.value;
      if (stored === 'local' && this.localComputerBackend) provider = 'local';
    } catch {}
    this.providerModes?.set(key, provider);
    return provider;
  }

  setComputerProvider(userId, provider) {
    const normalized = String(provider || '').trim().toLowerCase();
    if (!['cloud', 'local'].includes(normalized)) {
      const error = new Error('Computer provider must be cloud or local.');
      error.status = 400;
      throw error;
    }
    if (normalized === 'local' && !this.localComputerBackend) {
      const error = new Error('Local computer control is unavailable on this server.');
      error.code = 'LOCAL_COMPUTER_UNAVAILABLE';
      error.status = 503;
      throw error;
    }
    const lease = this.getControlLease(userId);
    if (lease && ['agent', 'teach'].includes(lease.ownerType)) {
      const error = new Error(`Cannot switch computers while ${lease.ownerType} control is active.`);
      error.code = 'COMPUTER_PROVIDER_IN_USE';
      error.status = 409;
      throw error;
    }
    db.prepare(
      `INSERT INTO user_settings (user_id, key, value) VALUES (?, 'computer_provider', ?)
       ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value`,
    ).run(userId, normalized);
    this.providerModes.set(String(userId), normalized);
    this.releaseControl(userId);
    this.revokeDisplaySessions(userId);
    this._emitStatus(userId);
    return this.getComputerStatus(userId);
  }

  _computerBackendForUser(userId) {
    if (this.getComputerProvider(userId) === 'local' && this.localComputerBackend) {
      return this.localComputerBackend;
    }
    return this.computerBackend;
  }

  setIo(io) {
    this.io = io || null;
  }

  _emitStatus(userId) {
    const key = String(userId || '').trim();
    if (!key) return;
    this.io?.to(`user:${key}`).emit('computer:status', this.getComputerStatus(key));
  }

  getCapabilitySnapshot(userId) {
    const backend = this._computerBackendForUser(userId);
    const computer = backend.vmManager.getStatus(userId);
    const key = String(userId || '').trim();
    const androidController = key ? this.androidControllers.get(key) : null;
    let androidStatus = null;
    try {
      androidStatus = androidController?.getStatusSync?.() || null;
    } catch {}
    return {
      computer,
      browser: {
        activeBackend: this.getComputerProvider(userId) === 'local' ? 'local-computer' : 'cloud-computer',
        vmInitialized: backend.vmManager.hasTrackedVm(userId),
      },
      desktop: computer,
      android: {
        initialized: Boolean(androidController),
        status: androidStatus,
      },
    };
  }

  getComputerStatus(userId) {
    const provider = this.getComputerProvider(userId);
    const status = this._computerBackendForUser(userId).vmManager.getStatus(userId);
    const lease = this.getControlLease(userId);
    const controlledState = status.state === 'ready' && lease
      ? lease.ownerType === 'teach'
        ? 'teaching'
        : lease.ownerType === 'agent'
          ? 'agent_control'
          : 'user_control'
      : status.state;
    return {
      ...status,
      provider,
      providers: {
        cloud: { available: true },
        local: {
          available: Boolean(this.localComputerBackend),
          connected: Boolean(this.localComputerBackend?.isConnected?.(userId)),
        },
      },
      state: controlledState,
      control: lease
        ? { ownerType: lease.ownerType, ownerId: lease.ownerId, expiresAt: lease.expiresAt }
        : null,
    };
  }

  async startComputer(userId, options = {}) {
    this._emitStatus(userId);
    try {
      const backend = this._computerBackendForUser(userId);
      if (backend === this.localComputerBackend) await backend.pause(userId, false);
      await backend.getClientForUser(userId, options);
      if (backend === this.computerBackend) await this.#migrateWorkspace(userId, options);
      const browser = await backend.getBrowserProviderForUser(userId, options);
      await browser.launch({ signal: options.signal });
      if (backend === this.computerBackend) {
        const session = backend.vmManager.instances.get(String(userId || '').trim());
        if (session) {
          session.startupDurationMs = Date.now() - Date.parse(session.startedAt);
          if (session.directBoot && session.startupDurationMs >= 10_000) {
            console.warn(
              `[CloudComputer] Startup SLA exceeded for user ${String(userId)}: ${session.startupDurationMs}ms.`,
            );
          }
        }
      }
      return this.getComputerStatus(userId);
    } finally {
      this._emitStatus(userId);
    }
  }

  async #migrateWorkspace(userId, options = {}) {
    if (!this.workspaceManager) return;
    const key = String(userId || '').trim();
    const session = this.computerBackend.vmManager.instances.get(key);
    if (!session?.instanceDir) return;
    const markerPath = path.join(session.instanceDir, 'workspace-migration.json');
    if (fs.existsSync(markerPath)) return;
    const workspaceRoot = await this.workspaceManager.getWorkspaceRoot(userId);
    const archivePath = path.join(session.instanceDir, `workspace-import-${process.pid}.tar.gz`);
    try {
      await createWorkspaceArchive(workspaceRoot, archivePath);
      const sha256 = await sha256File(archivePath);
      const imported = await this.computerBackend.importWorkspaceArchive(
        userId,
        archivePath,
        sha256,
        options,
      );
      if (imported?.sha256 !== sha256) {
        throw new Error('Workspace migration did not return the verified checksum.');
      }
      fs.writeFileSync(markerPath, `${JSON.stringify({
        migratedAt: new Date().toISOString(),
        sha256,
        entries: Number(imported.entries || 0),
      }, null, 2)}\n`, { mode: 0o600 });
    } finally {
      fs.rmSync(archivePath, { force: true });
    }
  }

  async stopComputer(userId) {
    this.releaseControl(userId);
    this.revokeDisplaySessions(userId);
    await this._computerBackendForUser(userId).vmManager.killVm(userId);
    const status = this.getComputerStatus(userId);
    this._emitStatus(userId);
    return status;
  }

  executeCommand(userId, command, options = {}) {
    return this._computerBackendForUser(userId).executeCommand(userId, command, options);
  }

  executeCliCommand(userId, command, options = {}) {
    return this.executeCommand(userId, command, options).then((result) => ({
      ...result,
      backend: this.getComputerProvider(userId) === 'local' ? 'local-computer' : 'cloud-computer',
    }));
  }

  killCommand(userId, pid, reason = 'aborted') {
    return this._computerBackendForUser(userId).killCommand(userId, pid, reason);
  }

  getCommandExecutorForUser(userId) {
    return this._computerBackendForUser(userId).getCommandExecutorForUser(userId);
  }

  getBrowserProviderForUser(userId, options = {}) {
    return this._computerBackendForUser(userId).getBrowserProviderForUser(userId, options);
  }

  getActiveBrowserBackend(userId) {
    return this.getComputerProvider(userId) === 'local' ? 'local-computer' : 'cloud-computer';
  }

  getDesktopProviderForUser(userId) {
    const backend = this._computerBackendForUser(userId);
    if (backend === this.localComputerBackend) {
      return backend.getDesktopProviderForUser(userId);
    }
    return new ComputerDesktopProvider({
      backend,
      artifactStore: this.artifactStore,
      userId,
    });
  }

  hasVmForUser(userId) {
    return this._computerBackendForUser(userId).vmManager.hasVm(userId);
  }

  isGuestAgentReadyForUser(userId, timeoutMs = 1000) {
    return this._computerBackendForUser(userId).isGuestAgentReadyForUser(userId, timeoutMs);
  }

  requestComputer(userId, method, pathname, body, options = {}) {
    return this._computerBackendForUser(userId).requestGuest(userId, method, pathname, body, options);
  }

  createDisplaySession(userId) {
    if (this.getComputerProvider(userId) === 'local') {
      if (!this.localComputerBackend?.isConnected?.(userId)) {
        const error = new Error('This device is not connected to NeoAgent.');
        error.code = 'LOCAL_COMPUTER_NOT_CONNECTED';
        error.status = 409;
        throw error;
      }
      return {
        provider: 'local',
        local: true,
        viewUrl: null,
        viewOnly: false,
      };
    }
    const key = String(userId || '').trim();
    const vm = this.computerBackend.vmManager.instances.get(key);
    if (!vm?.display?.websocketUrl) {
      const error = new Error('Cloud computer display is not running.');
      error.code = 'COMPUTER_DISPLAY_UNAVAILABLE';
      error.status = 409;
      throw error;
    }
    this.#purgeExpiredDisplaySessions();
    const token = crypto.randomBytes(32).toString('base64url');
    const expiresAt = Date.now() + DISPLAY_SESSION_TTL_MS;
    const lease = this.getControlLease(key);
    const viewOnly = !lease || lease.ownerType === 'agent';
    this.displaySessions.set(token, {
      userId: key,
      target: vm.display.websocketUrl,
      expiresAt,
      viewOnly,
    });
    return {
      token,
      expiresAt: new Date(expiresAt).toISOString(),
      viewUrl: `/api/computer/display/${encodeURIComponent(token)}`,
      websocketPath: `/api/computer/display-ws?token=${encodeURIComponent(token)}`,
      viewOnly,
    };
  }

  resolveDisplaySession(userId, token) {
    this.#purgeExpiredDisplaySessions();
    const session = this.displaySessions.get(String(token || ''));
    if (!session || session.userId !== String(userId || '').trim()) return null;
    return session;
  }

  isDisplaySessionActive(userId, token, session) {
    const current = this.displaySessions.get(String(token || ''));
    return current === session && current?.userId === String(userId || '').trim();
  }

  touchComputerActivity(userId) {
    const key = String(userId || '').trim();
    this._computerBackendForUser(userId).touchActivity?.(key);
    const lease = this.getControlLease(key);
    if (lease) lease.expiresAt = Date.now() + CONTROL_LEASE_TTL_MS;
  }

  revokeDisplaySessions(userId) {
    if (!(this.displaySessions instanceof Map)) return;
    const key = String(userId || '').trim();
    for (const [token, session] of this.displaySessions.entries()) {
      if (session.userId === key) this.displaySessions.delete(token);
    }
  }

  #purgeExpiredDisplaySessions() {
    const now = Date.now();
    for (const [token, session] of this.displaySessions.entries()) {
      if (session.expiresAt <= now) this.displaySessions.delete(token);
    }
  }

  acquireControl(userId, ownerType, ownerId) {
    const key = String(userId || '').trim();
    const existing = this.getControlLease(key);
    const normalizedOwnerType = String(ownerType || '').trim();
    const normalizedOwnerId = String(ownerId || '').trim();
    if (!['agent', 'user', 'teach'].includes(normalizedOwnerType) || !normalizedOwnerId) {
      throw new Error('A valid computer control owner is required.');
    }
    if (
      existing
      && (existing.ownerType !== normalizedOwnerType || existing.ownerId !== normalizedOwnerId)
    ) {
      const error = new Error(`Cloud computer is controlled by ${existing.ownerType}.`);
      error.code = 'COMPUTER_CONTROL_CONFLICT';
      error.status = 409;
      throw error;
    }
    const lease = {
      ownerType: normalizedOwnerType,
      ownerId: normalizedOwnerId,
      expiresAt: Date.now() + CONTROL_LEASE_TTL_MS,
    };
    if (!existing) this.revokeDisplaySessions(key);
    this.controlLeases.set(key, lease);
    this._emitStatus(key);
    return { ...lease, expiresAt: new Date(lease.expiresAt).toISOString() };
  }

  getControlLease(userId) {
    const key = String(userId || '').trim();
    const lease = this.controlLeases.get(key);
    if (!lease) return null;
    if (lease.expiresAt <= Date.now()) {
      this.controlLeases.delete(key);
      this.revokeDisplaySessions(key);
      return null;
    }
    return lease;
  }

  releaseControl(userId, ownerId = null) {
    const key = String(userId || '').trim();
    const lease = this.controlLeases.get(key);
    if (!lease) return false;
    if (ownerId != null && lease.ownerId !== String(ownerId)) return false;
    this.controlLeases.delete(key);
    this.revokeDisplaySessions(key);
    this._emitStatus(key);
    return true;
  }

  async getAndroidProviderForUser(userId) {
    const key = String(userId || '').trim();
    if (!key) throw new Error('Android provider requires a user ID.');
    if (!this.androidControllers.has(key)) {
      this.androidControllers.set(key, this.createAndroidController(key));
    }
    return this.androidControllers.get(key);
  }

  async shutdown() {
    this.displaySessions.clear();
    this.controlLeases.clear();
    const tasks = [
      this.computerBackend.shutdown(),
      this.localComputerBackend?.shutdown?.(),
      ...Array.from(this.androidControllers.values(), (controller) => controller?.close?.()),
    ];
    this.androidControllers.clear();
    if (typeof this.shellWorkerPool?.shutdown === 'function') {
      tasks.push(Promise.resolve().then(() => this.shellWorkerPool.shutdown()));
    }
    await Promise.allSettled(tasks);
  }
}

module.exports = { RuntimeManager };
