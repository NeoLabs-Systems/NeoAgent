const fs = require('fs');
const crypto = require('crypto');
const http = require('http');
const https = require('https');
const net = require('net');
const path = require('path');
const { StringDecoder } = require('string_decoder');
const { spawn, spawnSync } = require('child_process');
const { DATA_DIR } = require('../../../runtime/paths');
const { ensureGuestBootstrapSeed } = require('./guest_bootstrap');

const REPO_ROOT = path.resolve(__dirname, '../../..');
const VM_ROOT = path.join(DATA_DIR, 'runtime-vms');
fs.mkdirSync(VM_ROOT, { recursive: true });

const DEFAULT_UBUNTU_BASE_IMAGE_URLS = Object.freeze({
  x64: 'https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img',
  arm64: 'https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img',
});

const QEMU_SHARE_ROOT_CANDIDATES = [
  path.resolve(process.execPath, '..', '..', 'share', 'qemu'),
  path.resolve(process.execPath, '..', '..', '..', 'share', 'qemu'),
  '/opt/homebrew/share/qemu',
  '/usr/local/share/qemu',
  '/usr/share/qemu',
];

function guestArchForHost() {
  return process.arch === 'arm64' ? 'arm64' : 'x64';
}

function resolveQemuBinary({ arch = guestArchForHost(), platform = process.platform } = {}) {
  if (platform === 'win32') {
    return arch === 'arm64' ? 'qemu-system-aarch64.exe' : 'qemu-system-x86_64.exe';
  }
  return arch === 'arm64' ? 'qemu-system-aarch64' : 'qemu-system-x86_64';
}

function defaultBaseImageUrlForArch(arch = guestArchForHost()) {
  return DEFAULT_UBUNTU_BASE_IMAGE_URLS[arch] || DEFAULT_UBUNTU_BASE_IMAGE_URLS.x64;
}

function normalizeBaseImageUrlForArch(baseImageUrl, arch = guestArchForHost()) {
  const candidate = String(baseImageUrl || '').trim();
  if (!candidate) {
    return defaultBaseImageUrlForArch(arch);
  }
  if (arch === 'x64' && /arm64|aarch64/i.test(candidate)) {
    return defaultBaseImageUrlForArch('x64');
  }
  if (arch === 'arm64' && /amd64|x86_64/i.test(candidate)) {
    return defaultBaseImageUrlForArch('arm64');
  }
  return candidate;
}

function isHttpUrl(value) {
  const candidate = String(value || '').trim();
  return /^https?:\/\//i.test(candidate);
}

function generateGuestToken() {
  return crypto.randomBytes(32).toString('hex');
}

function computeRuntimeTemplateSignature(guestArch, runtimeProfile = 'browser_cli') {
  const hash = crypto.createHash('sha256');
  const normalizedProfile = runtimeProfile === 'android' ? 'android' : 'browser_cli';
  const trackedFiles = normalizedProfile === 'android'
    ? [
      'server/guest-agent.android.package.json',
      'server/guest_agent.js',
      'server/services/android/controller.js',
      'server/services/cli/executor.js',
      'server/services/runtime/guest_bootstrap.js',
      'runtime/env.js',
      'runtime/paths.js',
    ]
    : [
      'server/guest-agent.browser.package.json',
      'server/guest_agent.js',
      'server/services/browser/controller.js',
      'server/services/cli/executor.js',
      'server/services/runtime/guest_bootstrap.js',
      'runtime/env.js',
      'runtime/paths.js',
    ];

  hash.update(String(guestArch || 'x64'));
  hash.update('\0');
  hash.update(normalizedProfile);
  for (const relativePath of trackedFiles) {
    const filePath = path.join(REPO_ROOT, relativePath);
    hash.update('\0');
    hash.update(relativePath);
    hash.update('\0');
    try {
      hash.update(fs.readFileSync(filePath));
    } catch (error) {
      hash.update(`missing:${error?.code || 'unknown'}`);
    }
  }

  return hash.digest('hex');
}

function resolveGuestToken(userRoot) {
  const tokenPath = path.join(userRoot, 'guest-token.txt');
  try {
    const existing = String(fs.readFileSync(tokenPath, 'utf8') || '').trim();
    if (existing.length >= 32) {
      return existing;
    }
  } catch {}

  const candidate = String(process.env.NEOAGENT_VM_GUEST_TOKEN || '').trim();
  const token = candidate.length >= 32 ? candidate : generateGuestToken();
  fs.mkdirSync(path.dirname(tokenPath), { recursive: true });
  fs.writeFileSync(tokenPath, `${token}\n`, { mode: 0o600 });
  return token;
}

function downloadFile(sourceUrl, destinationPath, redirectCount = 0) {
  return new Promise((resolve, reject) => {
    if (redirectCount > 5) {
      reject(new Error('Too many redirects while downloading VM base image.'));
      return;
    }

    const client = String(sourceUrl).startsWith('https:') ? https : http;
    let settled = false;
    let output = null;
    const tempPath = `${destinationPath}.download`;

    const cleanup = (error) => {
      if (settled) {
        return;
      }
      settled = true;
      try { output?.destroy(); } catch {}
      try { fs.rmSync(tempPath, { force: true }); } catch {}
      reject(error);
    };

    const request = client.get(sourceUrl, (response) => {
      if (response.statusCode && response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        response.resume();
        const nextUrl = new URL(response.headers.location, sourceUrl).toString();
        if (!settled) {
          settled = true;
          resolve(downloadFile(nextUrl, destinationPath, redirectCount + 1));
        }
        return;
      }

      if (response.statusCode !== 200) {
        response.resume();
        cleanup(new Error(`Failed to download VM base image: HTTP ${response.statusCode}`));
        return;
      }

      fs.mkdirSync(path.dirname(destinationPath), { recursive: true });
      output = fs.createWriteStream(tempPath);

      response.pipe(output);
      output.on('finish', () => {
        output.close(() => {
          if (settled) {
            return;
          }
          settled = true;
          try {
            fs.renameSync(tempPath, destinationPath);
            resolve(destinationPath);
          } catch (error) {
            try { fs.rmSync(tempPath, { force: true }); } catch {}
            reject(error);
          }
        });
      });
      output.on('error', (error) => {
        cleanup(error);
      });
      response.on('error', (error) => {
        cleanup(error);
      });
    });

    request.setTimeout(15 * 60 * 1000, () => {
      request.destroy(new Error('Timed out while downloading VM base image.'));
    });
    request.on('timeout', () => {
      cleanup(new Error('Timed out while downloading VM base image.'));
    });
    request.on('abort', () => {
      cleanup(new Error('VM base image download was aborted.'));
    });
    request.on('error', (error) => {
      cleanup(error);
    });
  });
}

function resolveAcceleration({ platform = process.platform, arch = guestArchForHost() } = {}) {
  if (platform === 'linux') return arch === process.arch ? 'kvm' : 'tcg';
  if (platform === 'darwin') return arch === process.arch ? 'hvf' : 'tcg';
  if (platform === 'win32') return arch === process.arch ? 'whpx' : 'tcg';
  return 'tcg';
}

function resolveQemuShareRoot() {
  for (const candidate of QEMU_SHARE_ROOT_CANDIDATES) {
    if (candidate && fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return null;
}

function resolveAarch64FirmwarePaths() {
  const shareRoot = resolveQemuShareRoot();
  if (!shareRoot) {
    return null;
  }

  const codePath = path.join(shareRoot, 'edk2-aarch64-code.fd');
  const varsTemplatePathCandidates = [
    path.join(shareRoot, 'edk2-aarch64-vars.fd'),
    path.join(shareRoot, 'edk2-arm-vars.fd'),
  ];
  const varsTemplatePath = varsTemplatePathCandidates.find((candidate) => fs.existsSync(candidate)) || null;

  if (!fs.existsSync(codePath) || !varsTemplatePath) {
    return null;
  }

  return {
    shareRoot,
    codePath,
    varsTemplatePath,
  };
}

function resolveX86_64FirmwarePaths() {
  const shareRoot = resolveQemuShareRoot();
  if (!shareRoot) {
    return null;
  }

  // edk2-x86_64-code.fd is the UEFI code ROM; edk2-i386-vars.fd is the
  // correct writable vars companion (Homebrew QEMU does not ship an
  // edk2-x86_64-vars.fd — they share the i386 vars image).
  const codePathCandidates = [
    path.join(shareRoot, 'edk2-x86_64-code.fd'),
    path.join(shareRoot, 'edk2-x86_64-secure-code.fd'),
  ];
  const codePath = codePathCandidates.find((candidate) => fs.existsSync(candidate)) || null;
  const varsTemplatePathCandidates = [
    path.join(shareRoot, 'edk2-i386-vars.fd'),
    path.join(shareRoot, 'edk2-x86_64-vars.fd'),
  ];
  const varsTemplatePath = varsTemplatePathCandidates.find((candidate) => fs.existsSync(candidate)) || null;

  if (!codePath || !varsTemplatePath) {
    return null;
  }

  return {
    shareRoot,
    codePath,
    varsTemplatePath,
  };
}

function buildQemuArgs({
  imagePath,
  sshPort,
  agentPort = 8421,
  memoryMb = 4096,
  cpus = 2,
  arch = guestArchForHost(),
  platform = process.platform,
  seedPath = null,
  seedIsRaw = false,
  consoleLogPath = null,
  firmwareCodePath = null,
  firmwareVarsPath = null,
}) {
  console.log(`[QEMU] Building args for ${arch} (MMIO 9p ENABLED)`);
  const accel = resolveAcceleration({ platform, arch });
  const args = ['-display', 'none', '-m', String(memoryMb), '-smp', String(cpus)];

  if (arch === 'arm64') {
    args.push('-machine', `virt,accel=${accel},gic-version=max`);
    if (platform !== 'win32') {
      args.push('-cpu', 'host');
    }
  } else {
    args.push('-machine', `q35,accel=${accel}`);
    if (platform !== 'win32') {
      args.push('-cpu', process.arch === arch ? 'host' : 'qemu64');
    }
  }

  const isMmio = arch === 'arm64';
  const blkDev = isMmio ? 'virtio-blk-device' : 'virtio-blk-pci';
  const netDev = isMmio ? 'virtio-net-device' : 'virtio-net-pci';
  const p9Dev = isMmio ? 'virtio-9p-device' : 'virtio-9p-pci';

  // OS disk — always first boot candidate
  args.push(
    '-drive', `if=none,id=os,file=${imagePath},format=qcow2`,
    '-device', `${blkDev},drive=os,bootindex=1`,
    '-netdev', `user,id=net0,hostfwd=tcp:127.0.0.1:${sshPort}-:22,hostfwd=tcp:127.0.0.1:${agentPort}-:8421`,
    '-device', `${netDev},netdev=net0`,
  );

  if (seedPath) {
    if (seedIsRaw) {
      // Raw FAT image — attach as a plain virtio block device
      args.push(
        '-drive', `if=none,id=cidata,file=${seedPath},format=raw,readonly=on`,
        '-device', `${blkDev},drive=cidata`,
      );
    } else if (arch === 'arm64') {
      // ARM virt machine has no IDE controller; use virtio-scsi for the seed ISO
      args.push(
        '-device', 'virtio-scsi-pci,id=scsi0',
        '-drive', `if=none,id=cidata,media=cdrom,readonly=on,file=${seedPath}`,
        '-device', 'scsi-cd,drive=cidata,bus=scsi0.0',
      );
    } else {
      // x86_64 q35 machine: plain IDE CD-ROM is the most reliably detected
      // path for cloud-init NoCloud discovery without extra guest drivers.
      args.push(
        '-drive', `if=none,id=cidata,media=cdrom,readonly=on,file=${seedPath}`,
        '-device', 'ide-cd,drive=cidata,bus=ide.0',
      );
    }
  }

  if (firmwareCodePath && firmwareVarsPath) {
    args.push(
      '-drive', `if=pflash,format=raw,readonly=on,file=${firmwareCodePath}`,
      '-drive', `if=pflash,format=raw,file=${firmwareVarsPath}`,
    );
  }

  if (consoleLogPath) {
    args.push('-serial', `file:${consoleLogPath}`);
  }

  return args;
}

function commandExists(command) {
  const probe = spawnSync(process.platform === 'win32' ? 'where' : 'bash', process.platform === 'win32' ? [command] : ['-lc', `command -v "${command}"`], {
    stdio: 'ignore',
  });
  return probe.status === 0;
}

function resolveCommandPath(command) {
  const probe = spawnSync(
    process.platform === 'win32' ? 'where' : 'bash',
    process.platform === 'win32' ? [command] : ['-lc', `command -v "${command}"`],
    {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  );
  if (probe.status !== 0) {
    return null;
  }
  const resolved = String(probe.stdout || '').trim().split('\n').find(Boolean);
  return resolved || null;
}

function allocatePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.unref();
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      const port = typeof address === 'object' && address ? address.port : null;
      server.close((err) => {
        if (err) return reject(err);
        resolve(port);
      });
    });
  });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForPath(targetPath, timeoutMs, intervalMs = 1000) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (fs.existsSync(targetPath)) {
      return true;
    }
    await sleep(intervalMs);
  }
  return fs.existsSync(targetPath);
}

function writeLockMetadata(lockDir) {
  try {
    fs.writeFileSync(
      path.join(lockDir, 'owner.json'),
      JSON.stringify({ pid: process.pid, createdAt: new Date().toISOString() }, null, 2),
      'utf8',
    );
  } catch {}
}

function readLockMetadata(lockDir) {
  try {
    return JSON.parse(fs.readFileSync(path.join(lockDir, 'owner.json'), 'utf8'));
  } catch {
    return null;
  }
}

function isPidAlive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) {
    return false;
  }
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

async function requestGuestAgent(baseUrl, token, pathname, body, options = {}) {
  const controller = new AbortController();
  const timeoutMs = Math.max(1000, Number(options.timeoutMs || 5000));
  const timer = setTimeout(() => {
    controller.abort(new Error(`Request timed out after ${timeoutMs} ms.`));
  }, timeoutMs);
  try {
    const response = await fetch(`${String(baseUrl || '').replace(/\/+$/, '')}${pathname}`, {
      method: body === undefined ? 'GET' : 'POST',
      headers: {
        'content-type': 'application/json',
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: controller.signal,
    });
    const contentType = response.headers.get('content-type') || '';
    const payload = contentType.includes('application/json')
      ? await response.json().catch(() => ({}))
      : { text: await response.text().catch(() => '') };
    if (!response.ok) {
      const detail = payload?.error || payload?.text || `Runtime request failed: ${response.status}`;
      throw new Error(detail);
    }
    return payload;
  } finally {
    clearTimeout(timer);
  }
}

async function waitForGuestAgentHealth(baseUrl, token, options = {}) {
  const timeoutMs = Math.max(1000, Number(options.timeoutMs || 5 * 60 * 1000));
  const intervalMs = Math.max(250, Number(options.intervalMs || 1000));
  const checkLiveness = options.checkLiveness || (() => true);
  const startedAt = Date.now();
  let lastError = null;

  while (Date.now() - startedAt < timeoutMs) {
    if (!checkLiveness()) {
      throw new Error('Guest runtime process exited unexpectedly during bootstrap.');
    }
    try {
      const health = await requestGuestAgent(baseUrl, token, '/health', undefined, { timeoutMs: 2000 });
      if (health?.status === 'ok') {
        return health;
      }
      lastError = new Error('Guest agent health check returned a non-ok status.');
    } catch (error) {
      lastError = error;
    }
    await sleep(intervalMs);
  }

  throw new Error(`Timed out waiting for guest agent health: ${lastError?.message || 'unknown error'}`);
}

async function waitForGuestMarker(baseUrl, token, markerPath, options = {}) {
  const timeoutMs = Math.max(1000, Number(options.timeoutMs || 15 * 60 * 1000));
  const intervalMs = Math.max(250, Number(options.intervalMs || 2000));
  const checkLiveness = options.checkLiveness || (() => true);
  const startedAt = Date.now();
  let lastError = null;

  while (Date.now() - startedAt < timeoutMs) {
    if (!checkLiveness()) {
      throw new Error('Guest runtime process exited unexpectedly while waiting for guest marker.');
    }
    try {
      const result = await requestGuestAgent(baseUrl, token, '/exec', {
        command: `test -f ${JSON.stringify(String(markerPath || ''))} && printf ready || printf pending`,
        timeout: 15000,
      }, { timeoutMs: 20000 });
      if (String(result?.stdout || '').trim() === 'ready') {
        return true;
      }
    } catch (error) {
      lastError = error;
    }
    await sleep(intervalMs);
  }

  throw new Error(`Timed out waiting for guest marker ${markerPath}: ${lastError?.message || 'unknown error'}`);
}

function ensureUserVmDisk(userRoot, baseImagePath) {
  fs.mkdirSync(userRoot, { recursive: true });
  const diskPath = path.join(userRoot, 'disk.qcow2');
  if (fs.existsSync(diskPath)) {
    return diskPath;
  }
  if (!fs.existsSync(baseImagePath)) {
    throw new Error(`VM base image not found: ${baseImagePath}`);
  }

  const qemuImg = process.platform === 'win32' ? 'qemu-img.exe' : 'qemu-img';
  const qemuImgPath = resolveCommandPath(qemuImg);
  if (!qemuImgPath) {
    try {
      fs.copyFileSync(baseImagePath, diskPath);
      return diskPath;
    } catch (error) {
      throw new Error(`Failed to create VM disk copy: ${error.message}`);
    }
  }

  try {
    const result = spawnSync(
      qemuImgPath,
      ['create', '-f', 'qcow2', '-F', 'qcow2', '-b', baseImagePath, diskPath, '32G'],
      {
        stdio: 'pipe',
        encoding: 'utf8',
      },
    );
    if (result.status === 0 && fs.existsSync(diskPath)) {
      return diskPath;
    }

    const detail = String(
      result.stderr
      || result.stdout
      || result.error?.message
      || `exit status ${result.status ?? 'unknown'}`
    ).trim();
    fs.copyFileSync(baseImagePath, diskPath);
    return diskPath;
  } catch (error) {
    try {
      fs.copyFileSync(baseImagePath, diskPath);
      return diskPath;
    } catch (copyError) {
      const detail = String(error?.message || copyError?.message || 'unknown error').trim();
      throw new Error(`Failed to create VM overlay with qemu-img: ${detail}`);
    }
  }
}

function formatReadinessIssues(readiness) {
  if (!readiness) {
    return ['VM runtime is unavailable on this host.'];
  }
  const issues = [];
  if (!readiness.qemuAvailable) {
    issues.push(`Missing QEMU binary (${readiness.qemuBinary}).`);
  }
  if (!readiness.baseImageExists && !readiness.downloadConfigured) {
    issues.push('No VM base image is available for download or local reuse.');
  }
  return issues.length > 0 ? issues : ['VM runtime is unavailable on this host.'];
}

function readTemplateReadyMetadata(readySentinelPath) {
  try {
    const parsed = JSON.parse(fs.readFileSync(readySentinelPath, 'utf8'));
    if (parsed && typeof parsed === 'object') {
      return parsed;
    }
  } catch {}
  return null;
}

class QemuVmManager {
  constructor(options = {}) {
    this.runtimeProfile = options.runtimeProfile === 'android' ? 'android' : 'browser_cli';
    this.rootDir = path.resolve(options.rootDir || path.join(VM_ROOT, this.runtimeProfile));
    this.baseImageCacheRoot = path.resolve(options.baseImageCacheRoot || path.join(this.rootDir, 'base-images'));
    this.templateRootDir = path.resolve(options.templateRootDir || path.join(this.rootDir, 'templates'));
    this.baseImagePath = options.baseImagePath || process.env.NEOAGENT_VM_BASE_IMAGE || '';
    this.guestArch = options.guestArch || guestArchForHost();
    this.baseImageUrl = normalizeBaseImageUrlForArch(
      options.baseImageUrl || process.env.NEOAGENT_VM_BASE_IMAGE_URL || defaultBaseImageUrlForArch(this.guestArch),
      this.guestArch,
    );
    this.memoryMb = Number(options.memoryMb || process.env.NEOAGENT_VM_MEMORY_MB || 4096);
    this.cpus = Number(options.cpus || process.env.NEOAGENT_VM_CPUS || 2);
    this.instances = new Map();
    this.baseImagePromise = null;
    this.runtimeTemplatePromise = null;
    this.warmupEnabled = options.warmup === true;
    fs.mkdirSync(this.rootDir, { recursive: true });
    fs.mkdirSync(this.baseImageCacheRoot, { recursive: true });
    fs.mkdirSync(this.templateRootDir, { recursive: true });
    if (this.warmupEnabled) {
      setTimeout(() => {
        this.ensureRuntimeTemplateAvailable().catch((error) => {
          console.warn(`[VM:${this.runtimeProfile}] Background runtime template warmup failed: ${error.message}`);
        });
      }, 0);
    }
  }

  getBaseImageCachePath() {
    if (!isHttpUrl(this.baseImageUrl)) {
      return null;
    }
    const parsed = new URL(this.baseImageUrl);
    const filename = path.basename(parsed.pathname || '') || `${this.guestArch}-base.img`;
    return path.join(this.baseImageCacheRoot, filename);
  }

  resolveBaseImagePath() {
    const explicitPath = String(this.baseImagePath || '').trim();
    if (explicitPath) {
      return explicitPath;
    }
    return this.getBaseImageCachePath();
  }

  async ensureBaseImageAvailable() {
    const explicitPath = String(this.baseImagePath || '').trim();
    if (explicitPath) {
      if (!fs.existsSync(explicitPath)) {
        throw new Error(`VM base image not found: ${explicitPath}`);
      }
      return explicitPath;
    }

    if (!isHttpUrl(this.baseImageUrl)) {
      throw new Error('VM base image is not configured and no downloadable base image URL is available.');
    }

    const cachePath = this.getBaseImageCachePath();
    if (cachePath && fs.existsSync(cachePath)) {
      return cachePath;
    }

    if (!this.baseImagePromise) {
      this.baseImagePromise = downloadFile(this.baseImageUrl, cachePath)
        .finally(() => {
          this.baseImagePromise = null;
        });
    }

    return this.baseImagePromise;
  }

  getRuntimeTemplateRoot() {
    return path.join(this.templateRootDir, this.guestArch);
  }

  getRuntimeTemplateDiskPath() {
    return path.join(this.getRuntimeTemplateRoot(), 'disk.qcow2');
  }

  getRuntimeTemplateLockDir() {
    return `${this.getRuntimeTemplateRoot()}.lock`;
  }

  getRuntimeTemplateReadyMarker() {
    return this.runtimeProfile === 'android'
      ? '/var/lib/neoagent/bootstrap-complete'
      : '/var/lib/neoagent/browser-runtime-ready';
  }

  getRuntimeTemplateSignature() {
    return computeRuntimeTemplateSignature(this.guestArch, this.runtimeProfile);
  }

  async ensureRuntimeTemplateAvailable() {
    const readyDiskPath = this.getRuntimeTemplateDiskPath();
    const readySentinelPath = path.join(this.getRuntimeTemplateRoot(), '.runtime-template-ready');
    const readyMetadata = readTemplateReadyMetadata(readySentinelPath);
    if (
      fs.existsSync(readyDiskPath)
      && readyMetadata
      && readyMetadata.signature === this.getRuntimeTemplateSignature()
    ) {
      return readyDiskPath;
    }
    if (!this.runtimeTemplatePromise) {
      this.runtimeTemplatePromise = this.#ensureRuntimeTemplateAvailableWithLock().finally(() => {
        this.runtimeTemplatePromise = null;
      });
    }
    return this.runtimeTemplatePromise;
  }

  async #ensureRuntimeTemplateAvailableWithLock() {
    const readyDiskPath = this.getRuntimeTemplateDiskPath();
    const readySentinelPath = path.join(this.getRuntimeTemplateRoot(), '.runtime-template-ready');
    const lockDir = this.getRuntimeTemplateLockDir();
    const acquireStartedAt = Date.now();
    const expectedSignature = this.getRuntimeTemplateSignature();

    while (true) {
      const readyMetadata = readTemplateReadyMetadata(readySentinelPath);
      if (
        fs.existsSync(readyDiskPath)
        && readyMetadata
        && readyMetadata.signature === expectedSignature
      ) {
        return readyDiskPath;
      }

      try {
        fs.mkdirSync(lockDir, { recursive: false });
        writeLockMetadata(lockDir);
        try {
          if (fs.existsSync(readyDiskPath) && fs.existsSync(readySentinelPath)) {
            return readyDiskPath;
          }
          return await this.#buildRuntimeTemplate();
        } finally {
          fs.rmSync(lockDir, { recursive: true, force: true });
        }
      } catch (error) {
        if (error?.code !== 'EEXIST') {
          throw error;
        }
      }

      const lockStats = fs.existsSync(lockDir) ? fs.statSync(lockDir) : null;
      const lockMetadata = readLockMetadata(lockDir);
      const lockAgeMs = lockStats ? Date.now() - lockStats.mtimeMs : 0;
      const staleLock = lockAgeMs > 45 * 60 * 1000 || (lockMetadata?.pid && !isPidAlive(lockMetadata.pid));
      if (staleLock) {
        fs.rmSync(lockDir, { recursive: true, force: true });
        continue;
      }

      if (Date.now() - acquireStartedAt > 30 * 60 * 1000) {
        throw new Error('Timed out waiting for the shared runtime template build lock.');
      }

      await sleep(2000);
    }
  }

  async #buildRuntimeTemplate() {
    const templateRoot = this.getRuntimeTemplateRoot();
    const templateDiskPath = this.getRuntimeTemplateDiskPath();
    const readyMarkerPath = this.getRuntimeTemplateReadyMarker();
    const readySentinelPath = path.join(templateRoot, '.runtime-template-ready');
    const templateSignature = this.getRuntimeTemplateSignature();

    fs.mkdirSync(templateRoot, { recursive: true });

    const baseImagePath = await this.ensureBaseImageAvailable();
    const diskPath = ensureUserVmDisk(templateRoot, baseImagePath);
    const guestToken = resolveGuestToken(templateRoot);
    const bootstrap = ensureGuestBootstrapSeed({
      userRoot: templateRoot,
      guestToken,
      guestArch: this.guestArch,
      runtimeMode: 'template',
      runtimeProfile: this.runtimeProfile,
    });
    const consoleLogPath = path.join(templateRoot, 'console.log');
    const firmware = this.guestArch === 'arm64'
      ? resolveAarch64FirmwarePaths()
      : resolveX86_64FirmwarePaths();
    const firmwareVarsPath = firmware ? path.join(templateRoot, 'uefi-vars.fd') : null;
    if (firmware && !fs.existsSync(firmwareVarsPath)) {
      fs.copyFileSync(firmware.varsTemplatePath, firmwareVarsPath);
    }
    const agentPort = await allocatePort();
    const sshPort = await allocatePort();
    const qemuBinary = resolveQemuBinary({ arch: this.guestArch });
    const qemuBinaryPath = resolveCommandPath(qemuBinary) || qemuBinary;
    const args = buildQemuArgs({
      imagePath: diskPath,
      sshPort,
      agentPort,
      memoryMb: this.memoryMb,
      cpus: this.cpus,
      arch: this.guestArch,
      seedPath: bootstrap.seedImagePath || bootstrap.isoPath,
      seedIsRaw: Boolean(bootstrap.seedImagePath && bootstrap.seedImagePath.endsWith('.img')),
      consoleLogPath,
      firmwareCodePath: firmware?.codePath || null,
      firmwareVarsPath,
    });

    console.log(`[VM:${this.runtimeProfile}] Building runtime template for ${this.guestArch}: ${qemuBinaryPath} ${args.join(' ')}`);
    const child = spawn(qemuBinaryPath, args, {
      cwd: templateRoot,
      detached: process.platform !== 'win32',
      stdio: ['ignore', 'ignore', 'pipe'],
    });

    let stderrText = '';
    child.stderr.on('data', (chunk) => {
      stderrText += chunk.toString('utf8');
    });

    const baseUrl = `http://127.0.0.1:${agentPort}`;
    const checkLiveness = () => isPidAlive(child.pid);
    try {
      await waitForGuestAgentHealth(baseUrl, guestToken, {
        timeoutMs: 30 * 60 * 1000,
        intervalMs: 1000,
        checkLiveness,
      });
      await waitForGuestMarker(baseUrl, guestToken, readyMarkerPath, {
        timeoutMs: 45 * 60 * 1000,
        intervalMs: 2000,
        checkLiveness,
      });
      try {
        await requestGuestAgent(baseUrl, guestToken, '/exec', {
          command: [
            'cloud-init clean --logs --seed --machine-id || true',
            'rm -rf /var/lib/cloud/instances/* /var/lib/cloud/seed/* || true',
            'rm -f /var/lib/neoagent/bootstrap-complete /var/lib/neoagent/browser-runtime-ready || true',
            'rm -f /var/lib/systemd/random-seed || true',
            'truncate -s 0 /etc/machine-id || true',
            'sync',
          ].join('; '),
          timeout: 120000,
        }, { timeoutMs: 120000 });
      } catch (cleanupError) {
        console.warn(`[VM:${this.runtimeProfile}] Template cleanup after bootstrap failed: ${cleanupError.message}`);
      }
      fs.writeFileSync(
        readySentinelPath,
        JSON.stringify({
          signature: templateSignature,
          runtimeProfile: this.runtimeProfile,
          guestArch: this.guestArch,
          builtAt: new Date().toISOString(),
        }, null, 2),
        'utf8',
      );
    } finally {
      try {
        if (process.platform === 'win32') {
          spawnSync('taskkill', ['/F', '/T', '/PID', child.pid]);
        } else {
          process.kill(-child.pid, 'SIGKILL');
        }
      } catch {
        try {
          child.kill('SIGKILL');
        } catch {}
      }
    }

    if (!fs.existsSync(templateDiskPath)) {
      throw new Error('Runtime template disk was not created.');
    }
    return templateDiskPath;
  }

  async ensureRuntimeImageAvailable() {
    return this.ensureRuntimeTemplateAvailable();
  }

  isConfigured() {
    return this.getReadiness().ready;
  }

  getReadiness() {
    const qemuBinary = resolveQemuBinary({ arch: this.guestArch });
    const qemuImgBinary = process.platform === 'win32' ? 'qemu-img.exe' : 'qemu-img';
    const resolvedBaseImagePath = this.resolveBaseImagePath();
    const baseImageExists = Boolean(resolvedBaseImagePath && fs.existsSync(resolvedBaseImagePath));
    const downloadConfigured = !this.baseImagePath && isHttpUrl(this.baseImageUrl);
    const qemuAvailable = commandExists(qemuBinary);
    return {
      ready: qemuAvailable && (baseImageExists || downloadConfigured),
      baseImagePath: resolvedBaseImagePath || null,
      baseImageExists,
      baseImageUrl: this.baseImageUrl || null,
      downloadConfigured,
      qemuBinary,
      qemuAvailable,
      qemuImgBinary,
      qemuImgAvailable: commandExists(qemuImgBinary),
      acceleration: resolveAcceleration({ arch: this.guestArch }),
      guestArch: this.guestArch,
      platform: process.platform,
    };
  }

  async ensureVm(userId) {
    const key = String(userId || '').trim();
    if (!key) {
      throw new Error('VM runtime requires a user ID.');
    }
    const existing = this.instances.get(key);
    if (existing?.process && !existing.process.killed && existing.guestArch === this.guestArch) {
      return existing;
    }
    if (existing?.process && existing.guestArch !== this.guestArch) {
      try {
        existing.process.kill('SIGTERM');
      } catch {}
      this.instances.delete(key);
    }
    const readiness = this.getReadiness();
    if (!readiness.ready) {
      throw new Error(formatReadinessIssues(readiness).join(' '));
    }

    const userRoot = path.join(this.rootDir, key, this.guestArch);
    const baseImagePath = await this.ensureRuntimeImageAvailable();
    const diskPath = ensureUserVmDisk(userRoot, baseImagePath);
    const guestToken = resolveGuestToken(userRoot);
    const bootstrap = ensureGuestBootstrapSeed({
      userRoot,
      guestToken,
      guestArch: this.guestArch,
      runtimeMode: 'user',
      runtimeProfile: this.runtimeProfile,
    });
    const consoleLogPath = path.join(userRoot, 'console.log');
    const firmware = this.guestArch === 'arm64'
      ? resolveAarch64FirmwarePaths()
      : resolveX86_64FirmwarePaths();
    const firmwareVarsPath = firmware ? path.join(userRoot, 'uefi-vars.fd') : null;
    if (firmware && !fs.existsSync(firmwareVarsPath)) {
      if (!fs.existsSync(firmware.varsTemplatePath)) {
        throw new Error(`Firmware vars template is missing: ${firmware.varsTemplatePath}`);
      }
      try {
        fs.copyFileSync(firmware.varsTemplatePath, firmwareVarsPath);
      } catch (error) {
        const detail = error?.message || error;
        console.error('[VM] Failed to copy firmware vars template', {
          source: firmware.varsTemplatePath,
          destination: firmwareVarsPath,
          error: detail,
        });
        throw new Error(`Failed to copy firmware vars template: ${detail}`);
      }
    }
    const agentPort = await allocatePort();
    const sshPort = await allocatePort();
    const qemuBinary = resolveQemuBinary({ arch: this.guestArch });
    const qemuBinaryPath = resolveCommandPath(qemuBinary) || qemuBinary;
    const args = buildQemuArgs({
      imagePath: diskPath,
      sshPort,
      agentPort,
      memoryMb: this.memoryMb,
      cpus: this.cpus,
      arch: this.guestArch,
      seedPath: bootstrap.seedImagePath || bootstrap.isoPath,
      seedIsRaw: Boolean(bootstrap.seedImagePath && bootstrap.seedImagePath.endsWith('.img')),
      consoleLogPath,
      firmwareCodePath: firmware?.codePath || null,
      firmwareVarsPath,
    });

    console.log(`[VM:${this.runtimeProfile}] Starting QEMU for user ${key} (${this.guestArch}): ${qemuBinaryPath} ${args.join(' ')}`);
    const child = spawn(qemuBinaryPath, args, {
      cwd: userRoot,
      detached: process.platform !== 'win32',
      stdio: ['ignore', 'ignore', 'pipe'],
    });

    let lastError = '';
    const stderrDecoder = new StringDecoder('utf8');
    child.stderr.on('data', (chunk) => {
      const text = stderrDecoder.write(chunk);
      if (text.trim()) console.error(`[VM:${key}:stderr] ${text.trim()}`);
      lastError = [...`${lastError}${text}`].slice(-4000).join('');
    });

    if (consoleLogPath) {
      // Ensure file exists before reading to avoid race condition
      try {
        fs.closeSync(fs.openSync(consoleLogPath, 'a'));
      } catch (err) {
        console.warn(`[VM] Failed to pre-create console log at ${consoleLogPath}: ${err.message}`);
      }
      // Stream serial output to console for easier debugging on remote machines
      const serialStream = fs.createReadStream(consoleLogPath, { flags: 'r' });
      serialStream.on('data', (chunk) => {
        const text = chunk.toString('utf8');
        if (text.trim()) console.log(`[VM:${key}:serial] ${text.trim()}`);
      });
      child.on('exit', () => serialStream.destroy());
    }
    child.stderr.on('close', () => {
      const remainder = stderrDecoder.end();
      if (remainder) {
        lastError = [...`${lastError}${remainder}`].slice(-4000).join('');
      }
    });
    child.on('exit', () => {
      const current = this.instances.get(key);
      if (current?.process === child) {
        this.instances.delete(key);
      }
    });

    const session = {
      userId: key,
      runtimeProfile: this.runtimeProfile,
      process: child,
      qemuBinary,
      qemuArgs: args,
      guestArch: this.guestArch,
      userRoot,
      diskPath,
      guestToken,
      agentPort,
      sshPort,
      baseUrl: `http://127.0.0.1:${agentPort}`,
      getLastError: () => lastError.trim(),
    };
    this.instances.set(key, session);
    return session;
  }

  hasVm(userId) {
    const key = String(userId || '').trim();
    return Boolean(key && this.instances.has(key));
  }

  async killVm(userId) {
    const key = String(userId || '').trim();
    const session = this.instances.get(key);
    if (!session) return;

    try {
      try {
        await requestGuestAgent(session.baseUrl, session.guestToken, '/browser/close', {}, { timeoutMs: 10000 });
      } catch {}
      try {
        await requestGuestAgent(session.baseUrl, session.guestToken, '/android/stop', {}, { timeoutMs: 10000 });
      } catch {}
      try {
        await requestGuestAgent(session.baseUrl, session.guestToken, '/exec', {
          command: 'sync || true',
          timeout: 15000,
        }, { timeoutMs: 20000 });
      } catch {}

      if (process.platform === 'win32') {
        spawnSync('taskkill', ['/T', '/PID', session.process.pid]);
      } else {
        process.kill(-session.process.pid, 'SIGTERM');
      }
      const shutdownStartedAt = Date.now();
      while (isPidAlive(session.process.pid) && Date.now() - shutdownStartedAt < 10000) {
        await sleep(250);
      }
      if (isPidAlive(session.process.pid)) {
        if (process.platform === 'win32') {
          spawnSync('taskkill', ['/F', '/T', '/PID', session.process.pid]);
        } else {
          process.kill(-session.process.pid, 'SIGKILL');
        }
      }
    } catch {
      try {
        session.process.kill('SIGKILL');
      } catch {}
    }

    this.instances.delete(key);
  }

  async shutdown() {
    for (const session of this.instances.values()) {
      try {
        session.process.kill('SIGTERM');
      } catch {}
    }
    this.instances.clear();
  }
}

module.exports = {
  DEFAULT_UBUNTU_BASE_IMAGE_URLS,
  QemuVmManager,
  VM_ROOT,
  allocatePort,
  buildQemuArgs,
  defaultBaseImageUrlForArch,
  downloadFile,
  guestArchForHost,
  isHttpUrl,
  resolveAcceleration,
  resolveQemuBinary,
};
