'use strict';

const crypto = require('crypto');
const path = require('path');
const { spawn } = require('child_process');
const { DATA_DIR, ensurePrivateDirectory } = require('../../../runtime/paths');
const { createServiceLogger } = require('../../utils/logger');
const { GUEST_HOME } = require('./guest_paths');
const {
  GuestImageBuilder,
  docker,
  dockerOutput,
  runDockerCommand,
} = require('./guest_image');
const {
  allocateComputerResources,
  getComputerResourceProfile,
} = require('./resource_profile');
const {
  VmStartTracker,
  findAvailablePort,
  isProcessAlive,
  userDirectoryKey,
} = require('./vm_session');

const logger = createServiceLogger('Computer');
const CONTAINER_ROOT = path.join(DATA_DIR, 'runtime-containers');
const INSTANCE_ROOT = path.join(CONTAINER_ROOT, 'instances');
const MANAGED_LABEL = 'neoagent.managed=1';
const GUEST_AGENT_PORT = 8421;
const STOP_TIMEOUT_SECONDS = 10;
const REMOVE_TIMEOUT_MS = 30_000;
// Docker gives back no more than the tail of the container log, which is all the
// guest agent writes anyway; a longer tail only repeats the npm start banner.
const LOG_TAIL_LINES = 40;

function containerName(key) {
  return `neoagent-guest-${userDirectoryKey(key)}`;
}

// The guest's home lives in a named volume so a user's workspace, browser
// profile, and agent state survive the container being replaced — the same
// promise the per-user QEMU data disk makes.
function homeVolumeName(key) {
  return `neoagent-home-${userDirectoryKey(key)}`;
}

function containerLogTail(name) {
  const result = docker(['logs', '--tail', String(LOG_TAIL_LINES), name], { timeout: 5000 });
  return String(result.stdout || '').trim() || String(result.stderr || '').trim() || '';
}

// Containers share the host kernel, so a file the guest writes into its volume
// keeps the container user's ownership. Running as the host uid:gid keeps that
// state readable by the server process on Linux; Docker Desktop virtualizes
// ownership on macOS and Windows, where the image's own user is correct.
function hostUserArgs() {
  if (process.platform !== 'linux' || typeof process.getuid !== 'function') return [];
  return ['--user', `${process.getuid()}:${process.getgid()}`];
}

// Per-user computers as Docker containers. Interchangeable with QemuVMManager:
// the execution backend only ever sees a guest agent reachable over loopback.
class DockerVMManager {
  instances = new Map();
  #starts = new VmStartTracker();

  constructor(options = {}) {
    this.runtimeProfile = String(options.runtimeProfile || 'browser_cli').trim() || 'browser_cli';
    this.imageBuilder = options.imageBuilder
      || new GuestImageBuilder({ runtimeProfile: this.runtimeProfile });
    this.resourceProfile = options.resourceProfile || getComputerResourceProfile();
    this.bootTimeoutMs = Number(options.bootTimeoutMs || process.env.NEOAGENT_VM_BOOT_TIMEOUT_MS || 5 * 60 * 1000);
    this.pidsLimit = Number(options.pidsLimit || process.env.NEOAGENT_VM_PIDS_LIMIT || 512);
    this.guestHostAddress = 'host.docker.internal';
    this.orphansRemoved = false;
    ensurePrivateDirectory(CONTAINER_ROOT);
    ensurePrivateDirectory(INSTANCE_ROOT);
  }

  // Containers outliving the server that started them hold the home volume, so
  // the next start for that user would fail on it. Runs once, before the first
  // start, rather than in the constructor: building a manager to report status
  // must never tear a running computer down.
  async #removeOrphanedContainers() {
    if (this.orphansRemoved) return;
    this.orphansRemoved = true;
    try {
      const ids = dockerOutput([
        'container', 'ls', '--all', '--quiet',
        '--filter', `label=${MANAGED_LABEL}`,
      ]).split('\n').filter(Boolean);
      if (ids.length === 0) return;
      await runDockerCommand(['container', 'rm', '--force', ...ids], 60_000, 'ignore');
      logger.info(`Removed ${ids.length} orphaned computer container(s).`);
    } catch (error) {
      // Docker may not be running yet; readiness reports that separately.
      logger.warn(`Could not clean up orphaned computer containers: ${error.message}`);
    }
  }

  #runtimeUnavailableError() {
    const error = new Error(
      'Docker computer runtime is unavailable: the Docker daemon did not respond. '
      + 'Start Docker, then run neoagent repair.',
    );
    error.code = 'COMPUTER_RUNTIME_UNAVAILABLE';
    error.status = 503;
    return error;
  }

  getReadiness() {
    const state = this.imageBuilder.getState();
    return {
      ready: state.dockerAvailable,
      dockerAvailable: state.dockerAvailable,
      // The guest image builds itself on first start, so readiness does not wait
      // on it — but the status surface still reports whether it is already built.
      imageReady: state.imageBuilt,
      image: state.image,
      runtimeProfile: this.runtimeProfile,
      missing: state.dockerAvailable ? [] : ['docker'],
      resources: this.resourceProfile,
    };
  }

  async prepareRuntime(options = {}) {
    const readiness = this.getReadiness();
    if (!readiness.ready) throw this.#runtimeUnavailableError();
    if (options.downloadImage === false) return readiness;
    await this.imageBuilder.ensure();
    return this.getReadiness();
  }

  hasVm(userId) {
    return isProcessAlive(this.instances.get(String(userId || '').trim())?.process);
  }

  hasTrackedVm(userId) {
    return this.instances.has(String(userId || '').trim());
  }

  getStatus(userId) {
    const key = String(userId || '').trim();
    const capabilities = ['browser', 'shell', 'files'];
    const session = this.instances.get(key);
    if (!session) {
      return {
        ...(this.#starts.status(key) || { state: 'stopped' }),
        capabilities,
        readiness: this.getReadiness(),
      };
    }
    return {
      state: isProcessAlive(session.process) ? session.state : 'error',
      capabilities,
      resources: session.resources,
      startedAt: session.startedAt,
      startup: {
        targetMs: 10_000,
        measuredMs: session.startupDurationMs,
        met: session.startupDurationMs == null ? null : session.startupDurationMs < 10_000,
        mode: 'container',
      },
      lastError: session.lastError || null,
      error: session.lastError || null,
      desktop: session.desktop || null,
      readiness: this.getReadiness(),
    };
  }

  #activeAllocations() {
    return Array.from(this.instances.values())
      .filter((session) => isProcessAlive(session.process))
      .map((session) => session.resources);
  }

  async ensureVm(userId) {
    const key = String(userId || '').trim();
    if (!key) throw new Error('Cloud computer requires a user ID.');
    const existing = this.instances.get(key);
    if (existing && isProcessAlive(existing.process)) return existing;
    if (existing) this.instances.delete(key);
    return this.#starts.begin(key, () => this.#startContainer(key));
  }

  async #startContainer(key) {
    if (!this.getReadiness().ready) {
      const error = this.#runtimeUnavailableError();
      logger.error(error.message);
      throw error;
    }
    await this.#removeOrphanedContainers();
    const resources = allocateComputerResources(this.resourceProfile, this.#activeAllocations());
    const image = await this.imageBuilder.ensure();
    const name = containerName(key);
    // A container from an earlier start still holds the name and the volume.
    await runDockerCommand(['container', 'rm', '--force', name], REMOVE_TIMEOUT_MS, 'ignore');

    const instanceDir = path.join(INSTANCE_ROOT, userDirectoryKey(key));
    ensurePrivateDirectory(instanceDir);
    const hostAgentPort = await findAvailablePort();
    const guestToken = crypto.randomBytes(32).toString('hex');

    // Run in the foreground so the `docker run` process tracks the container's
    // lifetime: the session then exposes a live process handle exactly like the
    // QEMU backend, and the shared liveness and idle-reaper paths need no change.
    const child = spawn('docker', [
      'run',
      '--name', name,
      '--memory', `${resources.memoryMb}m`,
      '--cpus', String(resources.cpus),
      '--pids-limit', String(this.pidsLimit),
      '--shm-size', '1g',
      ...hostUserArgs(),
      '--publish', `127.0.0.1:${hostAgentPort}:${GUEST_AGENT_PORT}`,
      '--add-host', 'host.docker.internal:host-gateway',
      '--volume', `${homeVolumeName(key)}:${GUEST_HOME}`,
      '--env', `NEOAGENT_GUEST_AGENT_PORT=${GUEST_AGENT_PORT}`,
      '--env', `NEOAGENT_VM_GUEST_TOKEN=${guestToken}`,
      '--env', `NEOAGENT_GUEST_PROFILE=${this.runtimeProfile}`,
      '--env', `HOME=${GUEST_HOME}`,
      '--security-opt', 'no-new-privileges',
      // Capabilities the sandbox never needs. Dropping NET_RAW and NET_ADMIN also
      // stops it crafting raw packets or rewriting its own routing.
      '--cap-drop', 'NET_RAW',
      '--cap-drop', 'NET_ADMIN',
      '--cap-drop', 'SYS_ADMIN',
      '--cap-drop', 'SYS_MODULE',
      '--cap-drop', 'SYS_PTRACE',
      '--label', MANAGED_LABEL,
      '--label', `neoagent.profile=${this.runtimeProfile}`,
      image,
    ], { stdio: ['ignore', 'ignore', 'pipe'], windowsHide: true });

    let spawnError = '';
    child.stderr.on('data', (chunk) => {
      spawnError = `${spawnError}${chunk}`.slice(-4096);
    });

    const session = {
      instanceDir,
      baseUrl: `http://127.0.0.1:${hostAgentPort}`,
      guestToken,
      containerName: name,
      process: child,
      state: 'starting',
      resources,
      startedAt: new Date().toISOString(),
      // Nothing is provisioned at start: the image already carries the guest
      // agent and its dependencies, so the warm-start health budget applies.
      directBoot: true,
      startupDurationMs: null,
      lastError: null,
      getLastError: () => {
        const log = containerLogTail(name) || spawnError.trim();
        if (log && session.lastError && !log.includes(session.lastError)) {
          return `${session.lastError}\n${log}`;
        }
        return log || session.lastError;
      },
    };
    this.instances.set(key, session);

    child.once('error', (error) => {
      session.state = 'error';
      session.lastError = `Docker failed to start the computer: ${error.message}`;
      logger.error(`Computer failed to spawn for user ${key}: ${session.lastError}`);
    });
    child.once('exit', (code, signal) => {
      if (session.state !== 'stopping') {
        session.state = 'error';
        session.lastError = `Computer container exited (${code ?? signal ?? 'unknown'}). ${spawnError.trim()}`.trim();
        logger.error(`Computer process ended for user ${key}: ${session.lastError}`);
      }
      this.onVmStopped?.(key);
    });

    logger.info(`Started computer for user ${key} with ${resources.memoryMb} MiB and ${resources.cpus} vCPU.`);
    return session;
  }

  async killVm(userId) {
    const key = String(userId || '').trim();
    this.#starts.clear(key);
    const session = this.instances.get(key);
    this.instances.delete(key);
    if (!session) return;
    session.state = 'stopping';
    const exited = new Promise((resolve) => session.process.once('exit', resolve));
    // `docker stop` signals the guest agent so it can flush before it is killed;
    // the attached `docker run` then exits on its own.
    await runDockerCommand(
      ['stop', '--time', String(STOP_TIMEOUT_SECONDS), session.containerName],
      (STOP_TIMEOUT_SECONDS + 5) * 1000,
      'ignore',
    ).catch(() => {});
    await Promise.race([exited, new Promise((resolve) => setTimeout(resolve, 5000))]);
    // The container is kept after exit so its log stays readable; removing it
    // here is what finally releases the name and the published port.
    await runDockerCommand(
      ['container', 'rm', '--force', session.containerName],
      REMOVE_TIMEOUT_MS,
      'ignore',
    ).catch(() => {});
    if (isProcessAlive(session.process)) {
      try { session.process.kill('SIGKILL'); } catch {}
      await Promise.race([exited, new Promise((resolve) => setTimeout(resolve, 2000))]);
    }
  }

  async failVm(userId, error) {
    const key = String(userId || '').trim();
    await this.killVm(key);
    this.#starts.fail(key, error);
  }

  async sleepVm(userId) {
    const key = String(userId || '').trim();
    await this.killVm(key);
    this.#starts.sleep(key);
  }

  async shutdown() {
    await this.#starts.settled();
    await Promise.allSettled(Array.from(this.instances.keys(), (userId) => this.killVm(userId)));
    this.#starts.clearAll();
  }
}

module.exports = {
  DockerVMManager,
  containerName,
  homeVolumeName,
};
