'use strict';

const { spawnSync } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const http = require('http');
const net = require('net');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');
const { sanitizeWorkspaceKey } = require('../workspace/manager');

const CONTAINER_IMAGE = 'mcr.microsoft.com/playwright:v1.44.0-focal';
const CONTAINER_LABEL = 'neoagent.managed=1';
// The per-user host workspace is bind-mounted here so the shell (execute_command)
// and the workspace file tools (read_file/write_file/list_directory/search_files)
// operate on the SAME files. The guest agent defaults its shell cwd to this path.
const GUEST_WORKSPACE = '/workspace';

// Host path of a user's workspace — must match WorkspaceManager's layout exactly
// (AGENT_DATA_DIR/workspaces/<sanitized key>) so both sides see one directory.
function hostWorkspaceDir(key) {
  return path.join(AGENT_DATA_DIR, 'workspaces', sanitizeWorkspaceKey(key));
}

// ─── Guest agent ─────────────────────────────────────────────────────────────
// Injected into every container. Pure Node.js — only built-in modules + playwright
// (installed at /tmp/pw after container start). Served on $AGENT_PORT.
const GUEST_AGENT = `
const http = require('http');
const { spawn } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.env.AGENT_PORT || '3000', 10);
const AUTH_TOKEN = String(process.env.NEOAGENT_VM_GUEST_TOKEN || '');
const SCREENSHOTS = '/tmp/screenshots';
fs.mkdirSync(SCREENSHOTS, { recursive: true });

// Every endpoint except /health requires the shared bearer token. Without this
// any local process able to reach the (loopback-published) port could execute
// commands and read files inside another user's sandbox.
function authorized(req) {
  if (!AUTH_TOKEN) return true;
  const header = String(req.headers['authorization'] || '');
  const match = /^Bearer\\s+(.+)$/i.exec(header);
  if (!match) return false;
  const provided = Buffer.from(match[1]);
  const expected = Buffer.from(AUTH_TOKEN);
  return provided.length === expected.length && crypto.timingSafeEqual(provided, expected);
}

const procs = new Map();
let browser = null, page = null, pw = null;

function loadPlaywright() {
  if (pw) return pw;
  try { pw = require('/tmp/pw/node_modules/playwright'); return pw; } catch { return null; }
}

function chromiumExec() {
  const base = '/ms-playwright';
  if (!fs.existsSync(base)) return null;
  for (const dir of fs.readdirSync(base)) {
    if (!dir.startsWith('chromium')) continue;
    const bin = base + '/' + dir + '/chrome-linux/chrome';
    if (fs.existsSync(bin)) return bin;
  }
  return null;
}

function json(res, data, status) {
  const body = JSON.stringify(data);
  res.writeHead(status || 200, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) });
  res.end(body);
}

const MAX_BODY_BYTES = 1 * 1024 * 1024;

function body(req) {
  return new Promise((resolve, reject) => {
    let s = '', size = 0;
    req.on('data', d => {
      size += d.length;
      if (size > MAX_BODY_BYTES) { req.destroy(); reject(Object.assign(new Error('Request body too large'), { status: 413 })); return; }
      s += d;
    });
    req.on('end', () => { try { resolve(JSON.parse(s)); } catch { resolve({}); } });
    req.on('error', err => reject(err));
  });
}

async function screenshot(label) {
  if (!page) return null;
  const p = path.join(SCREENSHOTS, label + '.png');
  await page.screenshot({ path: p, fullPage: false });
  return p;
}

async function ensureBrowser() {
  if (browser) return;
  const lib = loadPlaywright();
  if (!lib) throw new Error('Playwright not ready — container still installing dependencies. Retry in a moment.');
  const exec = chromiumExec();
  browser = await lib.chromium.launch({ headless: true, executablePath: exec || undefined, args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  try {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
    page = await ctx.newPage();
  } catch (err) {
    await browser.close().catch(() => {});
    browser = null;
    page = null;
    throw err;
  }
}

const server = http.createServer(async (req, res) => {
  try {
    const url = req.url.split('?')[0];

    if (req.method === 'GET' && url === '/health') {
      return json(res, { status: 'ok' });
    }

    if (!authorized(req)) {
      return json(res, { error: 'Unauthorized' }, 401);
    }

    if (req.method === 'GET' && url === '/browser/status') {
      const info = page ? await page.evaluate(() => ({ url: location.href, title: document.title })).catch(() => ({})) : {};
      const pageInfo = page ? { url: info.url || null, title: info.title || null } : null;
      return json(res, { launched: !!browser, pageInfo, pageCount: page ? 1 : 0 });
    }

    const b = await body(req);

    // ── CLI execution ──────────────────────────────────────────────────────
    if (req.method === 'POST' && url === '/exec') {
      const timeoutMs = Math.min(Number(b.timeout) || 15 * 60 * 1000, 20 * 60 * 1000);
      const child = spawn('sh', ['-c', b.command || 'true'], {
        cwd: b.cwd || '/workspace',
        env: { ...process.env, ...b.env },
      });
      const pid = child.pid;
      let stdout = '', stderr = '', settled = false;
      procs.set(pid, child);
      child.stdout.on('data', d => { stdout += d; });
      child.stderr.on('data', d => { stderr += d; });
      const timer = setTimeout(() => {
        if (settled) return;
        settled = true;
        procs.delete(pid);
        try { child.kill('SIGKILL'); } catch {}
        json(res, { stdout, stderr, exitCode: null, code: null, pid, timedOut: true, killed: true });
      }, timeoutMs);
      child.on('close', code => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        procs.delete(pid);
        const exitCode = code ?? 1;
        json(res, { stdout, stderr, exitCode, code: exitCode, pid, timedOut: false, killed: false });
      });
      child.on('error', err => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        procs.delete(pid);
        json(res, { stdout, stderr, exitCode: 1, code: 1, pid, error: err.message, timedOut: false, killed: false });
      });
      return;
    }

    if (req.method === 'POST' && url === '/exec/kill') {
      const child = procs.get(b.pid);
      try { child?.kill('SIGKILL'); } catch {}
      return json(res, { success: true });
    }

    // ── File access ────────────────────────────────────────────────────────
    if (req.method === 'POST' && url === '/files/read') {
      try {
        const content = fs.readFileSync(b.path, 'base64');
        return json(res, { content });
      } catch (err) {
        return json(res, { error: err.message }, 404);
      }
    }

    // ── Browser ────────────────────────────────────────────────────────────
    if (req.method === 'POST' && url === '/browser/launch') {
      await ensureBrowser();
      return json(res, { success: true });
    }

    if (req.method === 'POST' && url === '/browser/close') {
      if (browser) { await browser.close().catch(() => {}); browser = null; page = null; }
      return json(res, { success: true });
    }

    if (req.method === 'POST' && url === '/browser/navigate') {
      await ensureBrowser();
      await page.goto(b.url, { waitUntil: b.waitUntil || 'domcontentloaded', timeout: b.timeout || 30000 });
      const info = await page.evaluate(() => ({ url: location.href, title: document.title }));
      const screenshotPath = b.screenshot !== false ? await screenshot('nav-' + Date.now()) : null;
      return json(res, { url: info.url, title: info.title, screenshotPath });
    }

    if (req.method === 'POST' && url === '/browser/screenshot') {
      await ensureBrowser();
      return json(res, { screenshotPath: await screenshot('ss-' + Date.now()) });
    }

    if (req.method === 'POST' && url === '/browser/click') {
      if (b.selector) await page.click(b.selector, { timeout: 10000 }).catch(() => {});
      const screenshotPath = b.screenshot !== false ? await screenshot('click-' + Date.now()) : null;
      return json(res, { screenshotPath });
    }

    if (req.method === 'POST' && url === '/browser/click-point') {
      await page.mouse.click(b.x, b.y);
      const screenshotPath = b.screenshot !== false ? await screenshot('clickpt-' + Date.now()) : null;
      return json(res, { screenshotPath });
    }

    if (req.method === 'POST' && url === '/browser/fill') {
      await page.fill(b.selector, b.value || b.text || '', { timeout: 10000 });
      const screenshotPath = b.screenshot !== false ? await screenshot('fill-' + Date.now()) : null;
      return json(res, { screenshotPath });
    }

    if (req.method === 'POST' && url === '/browser/type-text') {
      await page.keyboard.type(b.text || '');
      const screenshotPath = b.screenshot !== false ? await screenshot('type-' + Date.now()) : null;
      return json(res, { screenshotPath });
    }

    if (req.method === 'POST' && url === '/browser/press-key') {
      await page.keyboard.press(b.key || '');
      const screenshotPath = b.screenshot !== false ? await screenshot('key-' + Date.now()) : null;
      return json(res, { screenshotPath });
    }

    if (req.method === 'POST' && url === '/browser/scroll') {
      await page.evaluate(({ x, y }) => window.scrollBy(x, y), { x: b.deltaX || 0, y: b.deltaY || 0 });
      const screenshotPath = b.screenshot !== false ? await screenshot('scroll-' + Date.now()) : null;
      return json(res, { screenshotPath });
    }

    if (req.method === 'POST' && url === '/browser/extract') {
      const result = b.all
        ? await page.$$(b.selector).then(els => Promise.all(els.map(el => el.getAttribute(b.attribute).catch(() => null))))
        : await page.$(b.selector).then(el => el ? el.getAttribute(b.attribute) : null);
      return json(res, { result });
    }

    if (req.method === 'POST' && url === '/browser/execute') {
      const result = await page.evaluate(b.script || b.code || '').catch(err => ({ error: err.message }));
      return json(res, { result });
    }

    json(res, { error: 'Not found' }, 404);
  } catch (err) {
    json(res, { error: err.message }, err.status || 500);
  }
});

server.listen(PORT, '0.0.0.0', () => process.stdout.write('AGENT_READY\\n'));
`.trim();

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

function waitForAgent(port, timeoutMs) {
  return new Promise((resolve, reject) => {
    const deadline = Date.now() + (timeoutMs || 180000);
    function attempt() {
      if (Date.now() > deadline) return reject(new Error(`Agent on port ${port} not ready within ${Math.round((timeoutMs || 180000) / 1000)}s`));
      const req = http.get(`http://localhost:${port}/health`, res => {
        if (res.statusCode === 200) return resolve();
        setTimeout(attempt, 3000);
      });
      req.on('error', () => setTimeout(attempt, 3000));
      req.setTimeout(2000, () => { req.destroy(); setTimeout(attempt, 3000); });
    }
    attempt();
  });
}

// ─── DockerVMManager ─────────────────────────────────────────────────────────

class DockerVMManager {
  /** @type {Map<string, {baseUrl:string, guestToken:null, process:{pid:number}, getLastError:()=>null, containerId:string}>} */
  instances = new Map();
  #pending = new Map();
  #readiness = null;
  #readinessAt = 0;

  constructor(options = {}) {
    this.profile = options.runtimeProfile || 'default';
    this.image = options.image || CONTAINER_IMAGE;
    this.memoryMb = options.memoryMb || 2048;
    this.cpus = options.cpus || 2;
    // The guest agent authenticates every request with this token. Always have
    // one — fall back to a per-process random secret if the operator didn't set
    // NEOAGENT_VM_GUEST_TOKEN so the sandbox is never left unauthenticated.
    this.guestToken = String(options.guestToken || process.env.NEOAGENT_VM_GUEST_TOKEN || '').trim()
      || crypto.randomBytes(32).toString('hex');
    this.network = null;
    this.#cleanupOrphans();
    this.#setupNetwork();
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

  // Put agent containers on a dedicated bridge network so their egress can be
  // firewalled in isolation from any other containers on the host, then block
  // access to the cloud metadata service (and optionally private ranges). This
  // is the control that stops a user's shell (`curl http://169.254.169.254/...`)
  // from stealing the host's cloud IAM credentials.
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

  async ensureVm(userId) {
    const key = String(userId || '').trim();

    // Already running — return immediately.
    const existing = this.instances.get(key);
    if (existing && isContainerRunning(existing.containerId)) return existing;

    // Already starting for this user — share the in-flight promise.
    const inflight = this.#pending.get(key);
    if (inflight) return inflight;

    const promise = this.#startContainer(key).finally(() => this.#pending.delete(key));
    this.#pending.set(key, promise);
    return promise;
  }

  async #startContainer(key) {
    const port = await findAvailablePort();
    console.log(`[DockerVM:${this.profile}] Starting container for user ${key} on port ${port}`);

    // Bind-mount the user's host workspace so shell and file tools share one place.
    const workspaceDir = hostWorkspaceDir(key);
    try { fs.mkdirSync(workspaceDir, { recursive: true }); } catch { /* best effort */ }

    const containerId = docker([
      'run', '-d',
      '--memory', `${this.memoryMb}m`,
      '--cpus', String(this.cpus),
      '--pids-limit', String(Number(process.env.NEOAGENT_VM_PIDS_LIMIT || 512)),
      '-p', `127.0.0.1:${port}:${port}`,
      ...(this.network ? ['--network', this.network] : []),
      '-e', `AGENT_PORT=${port}`,
      ...(this.guestToken ? ['-e', `NEOAGENT_VM_GUEST_TOKEN=${this.guestToken}`] : []),
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
      '-v', `${workspaceDir}:${GUEST_WORKSPACE}`,
      '-w', GUEST_WORKSPACE,
      '--label', CONTAINER_LABEL,
      '--label', `neoagent.profile=${this.profile}`,
      '--label', `neoagent.user=${key}`,
      this.image,
      'sleep', 'infinity',
    ]);
    console.log(`[DockerVM:${this.profile}] Container ${containerId.slice(0, 12)} started`);

    // Inject agent source file
    spawnSync('docker', ['exec', '-i', containerId, 'sh', '-c', 'cat > /tmp/agent.js'], {
      input: GUEST_AGENT, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'],
    });

    // Install playwright then start agent (detached so npm install doesn't block)
    docker(['exec', '-d', containerId, 'sh', '-c',
      'npm install playwright --prefix /tmp/pw > /tmp/pw-install.log 2>&1 && node /tmp/agent.js',
    ]);

    const session = {
      baseUrl: `http://localhost:${port}`,
      guestToken: this.guestToken,
      process: { pid: process.pid }, // server PID — always alive while server runs
      getLastError: () => null,
      containerId,
    };
    this.instances.set(key, session);

    console.log(`[DockerVM:${this.profile}] Waiting for agent on port ${port}…`);
    try {
      await waitForAgent(port, 180000);
    } catch (err) {
      this.instances.delete(key);
      try { docker(['rm', '-f', containerId]); } catch {}
      throw err;
    }
    console.log(`[DockerVM:${this.profile}] Agent ready — ${session.baseUrl}`);
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
    await Promise.allSettled([...this.instances.keys()].map(k => this.killVm(k)));
  }

  hasVm(userId) {
    const key = String(userId || '').trim();
    const session = this.instances.get(key);
    return Boolean(session && isContainerRunning(session.containerId));
  }

  // Used by validation.js — cached to avoid a docker call on every status poll.
  getReadiness() {
    const now = Date.now();
    if (this.#readiness && now - this.#readinessAt < 30000) return this.#readiness;
    try {
      docker(['info'], { timeout: 5000 });
      this.#readiness = { ready: true, dockerAvailable: true };
    } catch {
      this.#readiness = { ready: false, dockerAvailable: false };
    }
    this.#readinessAt = now;
    return this.#readiness;
  }
}

module.exports = { DockerVMManager };
