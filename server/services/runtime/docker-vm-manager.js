'use strict';

const { spawnSync } = require('child_process');
const http = require('http');
const net = require('net');

const CONTAINER_IMAGE = 'mcr.microsoft.com/playwright:v1.44.0-focal';
const CONTAINER_LABEL = 'neoagent.managed=1';

// ─── Guest agent ─────────────────────────────────────────────────────────────
// Injected into every container. Pure Node.js — only built-in modules + playwright
// (installed at /tmp/pw after container start). Served on $AGENT_PORT.
const GUEST_AGENT = `
const http = require('http');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.env.AGENT_PORT || '3000', 10);
const SCREENSHOTS = '/tmp/screenshots';
fs.mkdirSync(SCREENSHOTS, { recursive: true });

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

    if (req.method === 'GET' && url === '/browser/status') {
      const info = page ? await page.evaluate(() => ({ url: location.href, title: document.title })).catch(() => ({})) : {};
      const pageInfo = page ? { url: info.url || null, title: info.title || null } : null;
      return json(res, { launched: !!browser, pageInfo, pageCount: page ? 1 : 0 });
    }

    const b = await body(req);

    // ── CLI execution ──────────────────────────────────────────────────────
    if (req.method === 'POST' && url === '/exec') {
      const child = spawn('sh', ['-c', b.command || 'true'], {
        cwd: b.cwd || '/tmp',
        env: { ...process.env, ...b.env },
      });
      const pid = child.pid;
      let stdout = '', stderr = '';
      procs.set(pid, child);
      child.stdout.on('data', d => { stdout += d; });
      child.stderr.on('data', d => { stderr += d; });
      child.on('close', code => { procs.delete(pid); json(res, { stdout, stderr, code: code ?? 1, pid }); });
      child.on('error', err => { procs.delete(pid); json(res, { stdout, stderr, code: 1, pid, error: err.message }); });
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
    this.#cleanupOrphans();
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

    const containerId = docker([
      'run', '-d',
      '--memory', `${this.memoryMb}m`,
      '--cpus', String(this.cpus),
      '-p', `127.0.0.1:${port}:${port}`,
      '-e', `AGENT_PORT=${port}`,
      '--shm-size=2g',
      '--security-opt', 'no-new-privileges',
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
      guestToken: null,
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
