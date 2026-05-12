const fs = require('fs');
const http = require('http');
const https = require('https');
const net = require('net');
const path = require('path');
const { StringDecoder } = require('string_decoder');
const { spawn, spawnSync } = require('child_process');
const { DATA_DIR } = require('../../../runtime/paths');
const { ensureGuestBootstrapSeed } = require('./guest_bootstrap');

const VM_ROOT = path.join(DATA_DIR, 'runtime-vms');
const BASE_IMAGE_CACHE_ROOT = path.join(VM_ROOT, 'base-images');
const REPO_ROOT = path.resolve(__dirname, '../../../');
const HOST_SHARE_ROOT = path.join(VM_ROOT, 'host-share');
fs.mkdirSync(VM_ROOT, { recursive: true });
fs.mkdirSync(BASE_IMAGE_CACHE_ROOT, { recursive: true });

const DEFAULT_UBUNTU_BASE_IMAGE_URLS = Object.freeze({
  x64: 'https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img',
  arm64: 'https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img',
});

const HOST_SHARE_LINKS = [
  { name: 'server', source: path.join(REPO_ROOT, 'server') },
  { name: 'runtime', source: path.join(REPO_ROOT, 'runtime') },
];

const QEMU_SHARE_ROOT_CANDIDATES = [
  path.resolve(process.execPath, '..', '..', 'share', 'qemu'),
  path.resolve(process.execPath, '..', '..', '..', 'share', 'qemu'),
  '/opt/homebrew/share/qemu',
  '/usr/local/share/qemu',
  '/usr/share/qemu',
];

function guestArchForHost() {
  return 'x64';
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

function ensureHostShareRoot() {
  fs.mkdirSync(HOST_SHARE_ROOT, { recursive: true });

  for (const entry of HOST_SHARE_LINKS) {
    const sourcePath = path.resolve(entry.source);
    if (!fs.existsSync(sourcePath)) {
      throw new Error(`Host share source is missing: ${sourcePath}`);
    }

    const linkPath = path.join(HOST_SHARE_ROOT, entry.name);
    let needsLink = true;
    if (fs.existsSync(linkPath)) {
      try {
        const resolved = fs.realpathSync.native ? fs.realpathSync.native(linkPath) : fs.realpathSync(linkPath);
        needsLink = resolved !== sourcePath;
      } catch {
        needsLink = true;
      }
      if (needsLink) {
        fs.rmSync(linkPath, { recursive: true, force: true });
      }
    }

    if (needsLink) {
      fs.symlinkSync(sourcePath, linkPath, process.platform === 'win32' ? 'junction' : 'dir');
    }
  }

  return HOST_SHARE_ROOT;
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
  hostShareRoot = null,
  hostDataRoot = null,
  seedPath = null,
  seedIsRaw = false,
  consoleLogPath = null,
  firmwareCodePath = null,
  firmwareVarsPath = null,
}) {
  const accel = resolveAcceleration({ platform, arch });
  const args = ['-display', 'none', '-m', String(memoryMb), '-smp', String(cpus)];

  if (arch === 'arm64') {
    args.push('-machine', `virt,accel=${accel}`);
    if (platform !== 'win32') {
      args.push('-cpu', 'host');
    }
  } else {
    args.push('-machine', `q35,accel=${accel}`);
    if (platform !== 'win32') {
      args.push('-cpu', process.arch === arch ? 'host' : 'max');
    }
  }

  // OS disk — always first boot candidate
  args.push(
    '-drive', `if=none,id=os,file=${imagePath},format=qcow2`,
    '-device', 'virtio-blk-pci,drive=os,bootindex=1',
    '-netdev', `user,id=net0,hostfwd=tcp:127.0.0.1:${sshPort}-:22,hostfwd=tcp:127.0.0.1:${agentPort}-:8421`,
    '-device', 'virtio-net-pci,netdev=net0',
  );

  if (hostShareRoot) {
    args.push(
      '-virtfs',
      `local,path=${hostShareRoot},mount_tag=neoagent-host,security_model=none,readonly=on`,
    );
  }

  if (hostDataRoot) {
    args.push(
      '-virtfs',
      `local,path=${hostDataRoot},mount_tag=neoagent-data,security_model=none`,
    );
  }

  if (seedPath) {
    if (seedIsRaw) {
      // Raw FAT image — attach as a plain virtio block device
      args.push(
        '-drive', `if=none,id=cidata,file=${seedPath},format=raw,readonly=on`,
        '-device', 'virtio-blk-pci,drive=cidata',
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

class QemuVmManager {
  constructor(options = {}) {
    this.rootDir = path.resolve(options.rootDir || VM_ROOT);
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
    fs.mkdirSync(this.rootDir, { recursive: true });
  }

  getBaseImageCachePath() {
    if (!isHttpUrl(this.baseImageUrl)) {
      return null;
    }
    const parsed = new URL(this.baseImageUrl);
    const filename = path.basename(parsed.pathname || '') || `${this.guestArch}-base.img`;
    return path.join(BASE_IMAGE_CACHE_ROOT, filename);
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
    const baseImagePath = await this.ensureBaseImageAvailable();
    const diskPath = ensureUserVmDisk(userRoot, baseImagePath);
    const guestToken = String(process.env.NEOAGENT_VM_GUEST_TOKEN || '').trim();
    if (!guestToken) {
      throw new Error('NEOAGENT_VM_GUEST_TOKEN is required to bootstrap the guest runtime.');
    }
    const bootstrap = ensureGuestBootstrapSeed({
      userRoot,
      guestToken,
    });
    const guestDataRoot = path.join(userRoot, 'guest-data');
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
    fs.mkdirSync(guestDataRoot, { recursive: true });
    const agentPort = await allocatePort();
    const sshPort = await allocatePort();
    const qemuBinary = resolveQemuBinary({ arch: this.guestArch });
    const qemuBinaryPath = resolveCommandPath(qemuBinary) || qemuBinary;
    const hostShareRoot = ensureHostShareRoot();
    const args = buildQemuArgs({
      imagePath: diskPath,
      sshPort,
      agentPort,
      memoryMb: this.memoryMb,
      cpus: this.cpus,
      arch: this.guestArch,
      hostShareRoot,
      hostDataRoot: guestDataRoot,
      seedPath: bootstrap.seedImagePath || bootstrap.isoPath,
      seedIsRaw: Boolean(bootstrap.seedImagePath && bootstrap.seedImagePath.endsWith('.img')),
      consoleLogPath,
      firmwareCodePath: firmware?.codePath || null,
      firmwareVarsPath,
    });

    const child = spawn(qemuBinaryPath, args, {
      cwd: userRoot,
      detached: process.platform !== 'win32',
      stdio: ['ignore', 'ignore', 'pipe'],
    });

    let lastError = '';
    const stderrDecoder = new StringDecoder('utf8');
    child.stderr.on('data', (chunk) => {
      lastError = [...`${lastError}${stderrDecoder.write(chunk)}`].slice(-4000).join('');
    });
    child.stderr.on('close', () => {
      const remainder = stderrDecoder.end();
      if (remainder) {
        lastError = [...`${lastError}${remainder}`].slice(-4000).join('');
      }
    });
    child.on('exit', () => {
      this.instances.delete(key);
    });

    const session = {
      userId: key,
      process: child,
      qemuBinary,
      qemuArgs: args,
      guestArch: this.guestArch,
      userRoot,
      diskPath,
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
      if (process.platform === 'win32') {
        spawnSync('taskkill', ['/F', '/T', '/PID', session.process.pid]);
      } else {
        process.kill(-session.process.pid, 'SIGKILL');
      }
    } catch (err) {
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
  BASE_IMAGE_CACHE_ROOT,
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
