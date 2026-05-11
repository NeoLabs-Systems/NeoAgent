const fs = require('fs');
const http = require('http');
const https = require('https');
const net = require('net');
const path = require('path');
const { StringDecoder } = require('string_decoder');
const { spawn, spawnSync } = require('child_process');
const { DATA_DIR } = require('../../../runtime/paths');

const VM_ROOT = path.join(DATA_DIR, 'runtime-vms');
const BASE_IMAGE_CACHE_ROOT = path.join(VM_ROOT, 'base-images');
fs.mkdirSync(VM_ROOT, { recursive: true });
fs.mkdirSync(BASE_IMAGE_CACHE_ROOT, { recursive: true });

const DEFAULT_UBUNTU_BASE_IMAGE_URLS = Object.freeze({
  x64: 'https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img',
  arm64: 'https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img',
});

function guestArchForHost(hostArch = process.arch) {
  return hostArch === 'arm64' ? 'arm64' : 'x64';
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

    request.setTimeout(30000, () => {
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

function resolveAcceleration({ platform = process.platform } = {}) {
  if (platform === 'linux') return 'kvm';
  if (platform === 'darwin') return 'hvf';
  if (platform === 'win32') return 'whpx';
  return 'tcg';
}

function buildQemuArgs({
  imagePath,
  sshPort,
  agentPort = 8421,
  memoryMb = 4096,
  cpus = 2,
  arch = guestArchForHost(),
  platform = process.platform,
}) {
  const accel = resolveAcceleration({ platform });
  const args = ['-display', 'none', '-m', String(memoryMb), '-smp', String(cpus)];

  if (arch === 'arm64') {
    args.push('-machine', `virt,accel=${accel}`);
    if (platform !== 'win32') {
      args.push('-cpu', 'host');
    }
  } else {
    args.push('-machine', `q35,accel=${accel}`);
    if (platform !== 'win32') {
      args.push('-cpu', 'host');
    }
  }

  args.push(
    '-drive', `if=virtio,file=${imagePath},format=qcow2`,
    '-netdev', `user,id=net0,hostfwd=tcp:127.0.0.1:${sshPort}-:22,hostfwd=tcp:127.0.0.1:${agentPort}-:8421`,
    '-device', 'virtio-net-pci,netdev=net0',
  );

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
      ['create', '-f', 'qcow2', '-F', 'qcow2', '-b', baseImagePath, diskPath],
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
    this.baseImageUrl = options.baseImageUrl || process.env.NEOAGENT_VM_BASE_IMAGE_URL || defaultBaseImageUrlForArch(options.guestArch || guestArchForHost());
    this.memoryMb = Number(options.memoryMb || process.env.NEOAGENT_VM_MEMORY_MB || 4096);
    this.cpus = Number(options.cpus || process.env.NEOAGENT_VM_CPUS || 2);
    this.guestArch = options.guestArch || guestArchForHost();
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
      acceleration: resolveAcceleration(),
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
    if (existing?.process && !existing.process.killed) {
      return existing;
    }
    const readiness = this.getReadiness();
    if (!readiness.ready) {
      throw new Error(formatReadinessIssues(readiness).join(' '));
    }

    const userRoot = path.join(this.rootDir, key);
    const baseImagePath = await this.ensureBaseImageAvailable();
    const diskPath = ensureUserVmDisk(userRoot, baseImagePath);
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
