'use strict';

const { spawnSync } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const http = require('http');
const net = require('net');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');
const { sanitizeWorkspaceKey } = require('../workspace/manager');
const { GuestImageBuilder, dockerAvailable } = require('./guest_image');

const CONTAINER_LABEL = 'neoagent.managed=1';
// The per-user host workspace is bind-mounted here so the shell (execute_command)
// and the workspace file tools (read_file/write_file/list_directory/search_files)
// operate on the SAME files. The guest agent's shell defaults its cwd to this path.
const GUEST_WORKSPACE = '/workspace';
// Where the guest agent keeps its own runtime files (screenshots, uploads) inside
// the container — separate from the user workspace bind mount.
const GUEST_RUNTIME_HOME = '/opt/neoagent/.runtime';

const IS_LINUX = process.platform === 'linux';

// Host path of a user's workspace — must match WorkspaceManager's layout exactly
// (AGENT_DATA_DIR/workspaces/<sanitized key>) so both sides see one directory.
function hostWorkspaceDir(key) {
  return path.join(AGENT_DATA_DIR, 'workspaces', sanitizeWorkspaceKey(key));
}

// Workspace bind mount. On SELinux-enforcing Linux hosts (Fedora/RHEL/Rocky) the
// `:Z` suffix relabels the directory to a container-private context so the guest
// can read/write it; it is a no-op elsewhere. On macOS, Docker Desktop maps file
// ownership automatically, so no suffix is needed.
function workspaceMount(hostDir) {
  return IS_LINUX ? `${hostDir}:${GUEST_WORKSPACE}:Z` : `${hostDir}:${GUEST_WORKSPACE}`;
}

// On Linux the container shares the host kernel, so files the guest creates in the
// bind mount would be owned by the container user. Run as the host uid:gid so the
// NeoAgent process (and its file tools) can read and modify them. On macOS the
// Docker Desktop VM virtualizes ownership, so the default container user is fine.
function hostUserArgs() {
  if (IS_LINUX && typeof process.getuid === 'function') {
    return ['--user', `${process.getuid()}:${process.getgid()}`];
  }
  return [];
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function findAvailablePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.listen(0, '127.0.0.1', () => { const { port } = srv.address(); srv.close(() => resolve(port)); });
    srv.on('error', reject);
  });
}

function docker(args, opts = {}) {
  const result = spawnSync('docker', args, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: opts.timeout || 30000, ...opts });
  if (result.error) throw new Error(`Docker unavailable: ${result.error.message}`);
  if (result.status !== 0) {
    const msg = (result.stderr || result.stdout || '').trim();
    throw new Error(`docker ${args[0]} failed: ${msg || `exit ${result.status}`}`);
  }
  return (result.stdout || '').trim();
}

function isContainerRunning(containerId) {
  try { return docker(['inspect', '--format={{.State.Running}}', containerId]) === 'true'; }
  catch { return false; }
}

function containerLogs(containerId, tailLines = 20) {
  try { return docker(['logs', '--tail', String(tailLines), containerId], { timeout: 5000 }); }
  catch { return ''; }
}

// Resolve once the guest agent's HTTP server is accepting connections. Any HTTP
// response (including 401 when a guest token is required) proves the process is
// listening; the authenticated health probe happens in the execution backend.
function waitForAgent(port, timeoutMs) {
  return new Promise((resolve, reject) => {
    const deadline = Date.now() + (timeoutMs || 120000);
    function attempt() {
      if (Date.now() > deadline) return reject(new Error(`Agent on port ${port} not ready within ${Math.round((timeoutMs || 120000) / 1000)}s`));
      const req = http.get(`http://localhost:${port}/health`, (res) => {
        res.resume();
        return resolve();
      });
      req.on('error', () => setTimeout(attempt, 1000));
      req.setTimeout(2000, () => { req.destroy(); setTimeout(attempt, 1000); });
    }
    attempt();
  });
}

// ─── DockerVMManager ─────────────────────────────────────────────────────────

class DockerVMManager {
  /** @type {Map<string, {baseUrl:string, guestToken:string|null, process:{pid:number}, getLastError:()=>(string|null), containerId:string}>} */
  instances = new Map();
  #pending = new Map();
  #readiness = null;
  #readinessAt = 0;

  constructor(options = {}) {
    this.profile = options.runtimeProfile || 'browser_cli';
    this.memoryMb = options.memoryMb || 2048;
    this.cpus = options.cpus || 2;
    this.pidsLimit = Number(options.pidsLimit || process.env.NEOAGENT_VM_PIDS_LIMIT || 512);
    // The guest agent authenticates every request with this token. Always have
    // one — fall back to a per-process random secret if the operator didn't set
    // NEOAGENT_VM_GUEST_TOKEN so the sandbox is never left unauthenticated.
    this.guestToken = String(options.guestToken || process.env.NEOAGENT_VM_GUEST_TOKEN || '').trim()
      || crypto.randomBytes(32).toString('hex');
    this.imageBuilder = options.imageBuilder || new GuestImageBuilder({ runtimeProfile: this.profile });
    this.bootTimeoutMs = Number(options.bootTimeoutMs || process.env.NEOAGENT_VM_BOOT_TIMEOUT_MS || 120000);
    this.network = null;
    this.#cleanupOrphans();
    this.#setupNetwork();
  }

  // Put agent containers on a dedicated bridge network so their egress can be
  // firewalled away from cloud instance-metadata endpoints.
  #setupNetwork() {
    if (String(process.env.NEOAGENT_VM_EGRESS_FIREWALL ?? '1') === '0') {
      return;
    }
    const name = 'neoagent-agents';
    try {
      let subnet = '';
      try {
        subnet = docker(['network', 'inspect', '--format', '{{range .IPAM.Config}}{{.Subnet}}{{end}}', name]);
      } catch {
        docker(['network', 'create', name]);
        subnet = docker(['network', 'inspect', '--format', '{{range .IPAM.Config}}{{.Subnet}}{{end}}', name]);
      }
      this.network = name;
      if (subnet) {
        this.#applyEgressFirewall(subnet.trim());
      }
    } catch (err) {
      // Without the dedicated network we fall back to the default bridge; the
      // dropped NET_RAW/NET_ADMIN capabilities still apply as defense in depth.
      console.warn(`[DockerVM:${this.profile}] Could not set up isolated network — metadata egress not firewalled: ${err.message}`);
      this.network = null;
    }
  }

  #applyEgressFirewall(subnet) {
    // The host egress firewall is enforced with iptables, which only exists on
    // Linux hosts. On macOS/Windows the Docker daemon runs in a managed VM with
    // no cloud metadata endpoint to protect, so the dedicated network alone
    // (namespace isolation) is sufficient.
    if (!IS_LINUX) {
      return;
    }
    // Cloud instance-metadata endpoints across the major providers.
    const blockedHosts = ['169.254.169.254/32', '169.254.170.2/32', '100.100.100.200/32'];
    // Self-hosters keep LAN access by default (mirrors NEOAGENT_HTTP_ALLOW_PRIVATE);
    // cloud operators can set it to false to also cut off RFC-1918 ranges.
    const allowPrivate = String(process.env.NEOAGENT_HTTP_ALLOW_PRIVATE ?? 'true').toLowerCase() !== 'false';
    const blockedNets = allowPrivate ? [] : ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16'];
    const targets = [...blockedHosts, ...blockedNets];

    let applied = 0;
    for (const dest of targets) {
      const spec = ['DOCKER-USER', '-s', subnet, '-d', dest, '-j', 'DROP'];
      try {
        const check = spawnSync('iptables', ['-C', ...spec], { encoding: 'utf8' });
        if (check.status !== 0) {
          const insert = spawnSync('iptables', ['-I', ...spec], { encoding: 'utf8' });
          if (insert.status !== 0) {
            throw new Error((insert.stderr || `exit ${insert.status}`).trim());
          }
        }
        applied += 1;
      } catch (err) {
        console.warn(`[DockerVM:${this.profile}] Unable to install egress firewall rule for ${dest} (need root/NET_ADMIN on host): ${err.message}. Sandbox containers may be able to reach ${dest}.`);
      }
    }
    if (applied > 0) {
      console.log(`[DockerVM:${this.profile}] Egress firewall active — blocking ${applied} destination(s) from sandbox subnet ${subnet}`);
    }
  }

  // Remove containers left over from a previous server run.
  #cleanupOrphans() {
    try {
      const ids = docker(['ps', '-a', '-q', '--filter', `label=${CONTAINER_LABEL}`, '--filter', `label=neoagent.profile=${this.profile}`])
        .split('\n').filter(Boolean);
      if (ids.length > 0) {
        docker(['rm', '-f', ...ids]);
        console.log(`[DockerVM:${this.profile}] Removed ${ids.length} orphaned container(s)`);
      }
    } catch { /* Docker may not be available yet — ignore */ }
  }

  async ensureVm(userId) {
    const key = String(userId || '').trim();

    // Already running — return immediately.
    const existing = this.instances.get(key);
    if (existing && isContainerRunning(existing.containerId)) return existing;

    // Stale entry: the guest agent runs as the container's main process, so if it
    // crashed the container has stopped. Remove the dead container before starting
    // a fresh one (automatic crash recovery).
    if (existing) {
      this.instances.delete(key);
      try { docker(['rm', '-f', existing.containerId]); } catch { /* already gone */ }
    }

    // Already starting for this user — share the in-flight promise.
    const inflight = this.#pending.get(key);
    if (inflight) return inflight;

    const promise = this.#startContainer(key).finally(() => this.#pending.delete(key));
    this.#pending.set(key, promise);
    return promise;
  }

  async #startContainer(key) {
    const image = await this.imageBuilder.ensure();
    const port = await findAvailablePort();
    console.log(`[DockerVM:${this.profile}] Starting container for user ${key} on port ${port}`);

    // Bind-mount the user's host workspace so shell and file tools share one place.
    const workspaceDir = hostWorkspaceDir(key);
    try { fs.mkdirSync(workspaceDir, { recursive: true }); } catch { /* best effort */ }

    const containerId = docker([
      'run', '-d',
      '--memory', `${this.memoryMb}m`,
      '--cpus', String(this.cpus),
      '--pids-limit', String(this.pidsLimit),
      ...hostUserArgs(),
      '-p', `127.0.0.1:${port}:${port}`,
      ...(this.network ? ['--network', this.network] : []),
      '-e', `NEOAGENT_GUEST_AGENT_PORT=${port}`,
      '-e', `HOME=${GUEST_WORKSPACE}`,
      '-e', `NEOAGENT_HOME=${GUEST_RUNTIME_HOME}`,
      '-e', `NEOAGENT_VM_GUEST_TOKEN=${this.guestToken}`,
      '--shm-size=2g',
      '--security-opt', 'no-new-privileges',
      // Strip capabilities the sandbox never needs. Dropping NET_RAW/NET_ADMIN
      // also prevents the container from crafting raw packets or rewriting its
      // own routing/iptables to bypass the host egress firewall above.
      '--cap-drop', 'NET_RAW',
      '--cap-drop', 'NET_ADMIN',
      '--cap-drop', 'SYS_ADMIN',
      '--cap-drop', 'SYS_PTRACE',
      '--cap-drop', 'SYS_MODULE',
      '-v', workspaceMount(workspaceDir),
      '--label', CONTAINER_LABEL,
      '--label', `neoagent.profile=${this.profile}`,
      '--label', `neoagent.user=${key}`,
      image,
    ]);
    console.log(`[DockerVM:${this.profile}] Container ${containerId.slice(0, 12)} started (${image})`);

    const session = {
      baseUrl: `http://localhost:${port}`,
      guestToken: this.guestToken || null,
      process: { pid: process.pid }, // server PID — always alive while server runs
      getLastError: () => containerLogs(containerId) || null,
      containerId,
    };
    this.instances.set(key, session);

    console.log(`[DockerVM:${this.profile}] Waiting for guest agent on port ${port}…`);
    try {
      await waitForAgent(port, this.bootTimeoutMs);
    } catch (err) {
      const logs = containerLogs(containerId);
      this.instances.delete(key);
      try { docker(['rm', '-f', containerId]); } catch { /* best effort */ }
      throw new Error(logs ? `${err.message}\n${logs}` : err.message);
    }
    console.log(`[DockerVM:${this.profile}] Guest agent ready — ${session.baseUrl}`);
    return session;
  }

  async killVm(userId) {
    const key = String(userId || '').trim();
    const session = this.instances.get(key);
    this.instances.delete(key);
    if (!session) return;
    try {
      docker(['rm', '-f', session.containerId]);
      console.log(`[DockerVM:${this.profile}] Container ${session.containerId.slice(0, 12)} removed`);
    } catch (err) {
      console.error(`[DockerVM:${this.profile}] Failed to remove container:`, err.message);
    }
  }

  async shutdown() {
    await Promise.allSettled([...this.#pending.values()]);
    await Promise.allSettled([...this.instances.keys()].map((k) => this.killVm(k)));
  }

  hasVm(userId) {
    const key = String(userId || '').trim();
    const session = this.instances.get(key);
    return Boolean(session && isContainerRunning(session.containerId));
  }

  // Used by validation.js — cached to avoid docker calls on every status poll.
  getReadiness() {
    const now = Date.now();
    if (this.#readiness && now - this.#readinessAt < 30000) return this.#readiness;
    if (!dockerAvailable()) {
      this.#readiness = { ready: false, dockerAvailable: false, imageBuilt: false, image: null };
    } else {
      const state = this.imageBuilder.getState();
      // Docker is the hard requirement; the image is built automatically on first
      // use, so readiness does not block on it.
      this.#readiness = { ready: true, dockerAvailable: true, imageBuilt: state.imageBuilt, image: state.image };
    }
    this.#readinessAt = now;
    return this.#readiness;
  }
}

module.exports = { DockerVMManager };
