'use strict';

const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const https = require('https');
const net = require('net');
const os = require('os');
const path = require('path');
const { spawn, spawnSync } = require('child_process');
const {
  APP_DIR,
  DATA_DIR,
  RUNTIME_HOME,
  ensurePrivateDirectory,
  ensurePrivateFile,
} = require('../../../runtime/paths');
const { createServiceLogger } = require('../../utils/logger');
const {
  COMPUTER_DISPLAY_HEIGHT,
  COMPUTER_DISPLAY_WIDTH,
} = require('./computer_display');
const { ensureGuestBootstrapSeed } = require('./guest_bootstrap');
const {
  allocateComputerResources,
  chooseDataDiskGiB,
  getComputerResourceProfile,
  getStorageHeadroomBytes,
} = require('./resource_profile');

const logger = createServiceLogger('CloudComputer');
const COMPUTER_ROOT = path.join(DATA_DIR, 'computers');
const IMAGE_ROOT = path.join(COMPUTER_ROOT, 'images');
const INSTANCE_ROOT = path.join(COMPUTER_ROOT, 'instances');
const PINNED_DEBIAN_BUILD = '20260810-2566';
const MAX_BOOT_ASSET_BYTES = 128 * 1024 * 1024;
const PINNED_IMAGES = Object.freeze({
  x64: Object.freeze({
    filename: `debian-13-${PINNED_DEBIAN_BUILD}-amd64.qcow2`,
    url: `https://cloud.debian.org/images/cloud/trixie/${PINNED_DEBIAN_BUILD}/debian-13-genericcloud-amd64-${PINNED_DEBIAN_BUILD}.qcow2`,
    sha512: '0ce1f1d675733027d3e17a4665cb95e1d7173bdf67fb8a87ff822ff5ee025bc2a90ecb270465ef395755e41c868b40072eb9ac493810196d9cf68f941afb93dc',
  }),
  arm64: Object.freeze({
    filename: `debian-13-${PINNED_DEBIAN_BUILD}-arm64.qcow2`,
    url: `https://cloud.debian.org/images/cloud/trixie/${PINNED_DEBIAN_BUILD}/debian-13-genericcloud-arm64-${PINNED_DEBIAN_BUILD}.qcow2`,
    sha512: '7a0eeb424f4a0e9fe35a4c04dee92cdded59aa4b056655488caf606cad4711b08c88af69a3d7de8af6837b082609872017e009a845837bde371c17b8fc27cd76',
  }),
});

function normalizeArchitecture(value = os.arch()) {
  return ['arm64', 'aarch64'].includes(String(value).toLowerCase()) ? 'arm64' : 'x64';
}

function commandExists(command) {
  const probe = spawnSync(
    process.platform === 'win32' ? 'where' : 'sh',
    process.platform === 'win32' ? [command] : ['-c', 'command -v "$1"', 'sh', command],
    { stdio: 'ignore', windowsHide: true },
  );
  return probe.status === 0;
}

function bundledExecutableCandidates(name) {
  const suffix = process.platform === 'win32' ? '.exe' : '';
  return [
    path.join(APP_DIR, 'computer-runtime', 'qemu', 'bin', `${name}${suffix}`),
    path.join(RUNTIME_HOME, 'computer-runtime', 'qemu', 'bin', `${name}${suffix}`),
    path.join(RUNTIME_HOME, 'runtime', 'qemu', 'bin', `${name}${suffix}`),
  ];
}

function resolveExecutable(name, explicit = '') {
  const candidates = [String(explicit || '').trim(), ...bundledExecutableCandidates(name)]
    .filter(Boolean);
  const bundled = candidates.find((candidate) => fs.existsSync(candidate));
  if (bundled) return bundled;
  return commandExists(name) ? name : null;
}

function resolveQemuSystemBinary(architecture = normalizeArchitecture()) {
  const name = architecture === 'arm64' ? 'qemu-system-aarch64' : 'qemu-system-x86_64';
  return resolveExecutable(name, process.env.NEOAGENT_QEMU_SYSTEM_BINARY);
}

function resolveQemuImgBinary() {
  return resolveExecutable('qemu-img', process.env.NEOAGENT_QEMU_IMG_BINARY);
}

function resolveQemuDataDirectory(qemuBinary) {
  const explicit = String(process.env.NEOAGENT_QEMU_DATA_DIR || '').trim();
  const executable = String(qemuBinary || '').trim();
  const candidates = [
    explicit,
    executable && path.resolve(path.dirname(executable), '..', 'share', 'qemu'),
    path.join(APP_DIR, 'computer-runtime', 'qemu', 'share', 'qemu'),
    path.join(RUNTIME_HOME, 'computer-runtime', 'qemu', 'share', 'qemu'),
  ].filter(Boolean);
  return candidates.find((candidate) => fs.existsSync(candidate)) || null;
}

function runChecked(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: options.timeoutMs || 120000,
    windowsHide: true,
  });
  if (result.error || result.status !== 0) {
    const detail = String(result.stderr || result.stdout || result.error?.message || '').trim();
    throw new Error(`${path.basename(command)} ${args[0] || ''} failed: ${detail || `exit ${result.status}`}`);
  }
  return String(result.stdout || '').trim();
}

function findAvailablePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.unref();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      server.close(() => resolve(address.port));
    });
  });
}

async function findVncDisplay() {
  for (let display = 10; display < 100; display += 1) {
    const port = 5900 + display;
    const available = await new Promise((resolve) => {
      const server = net.createServer();
      server.unref();
      server.once('error', () => resolve(false));
      server.listen(port, '127.0.0.1', () => server.close(() => resolve(true)));
    });
    if (available) return { display, port };
  }
  throw new Error('No loopback VNC display is available.');
}

function userDirectoryKey(userId) {
  return crypto.createHash('sha256').update(String(userId)).digest('hex').slice(0, 24);
}

function hashFile(filePath, algorithm = 'sha512') {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash(algorithm);
    const input = fs.createReadStream(filePath);
    input.once('error', reject);
    input.on('data', (chunk) => hash.update(chunk));
    input.once('end', () => resolve(hash.digest('hex')));
  });
}

function downloadFile(url, destination, redirectsRemaining = 5) {
  return new Promise((resolve, reject) => {
    const transport = String(url).startsWith('https:') ? https : http;
    const request = transport.get(url, { headers: { 'user-agent': 'NeoAgent-Computer-Runtime/1' } }, (response) => {
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        response.resume();
        if (redirectsRemaining <= 0) {
          reject(new Error('Too many redirects while downloading the guest image.'));
          return;
        }
        const redirectedUrl = new URL(response.headers.location, url).toString();
        downloadFile(redirectedUrl, destination, redirectsRemaining - 1).then(resolve, reject);
        return;
      }
      if (response.statusCode !== 200) {
        response.resume();
        reject(new Error(`Guest image download returned HTTP ${response.statusCode}.`));
        return;
      }
      const output = fs.createWriteStream(destination, { mode: 0o600 });
      response.pipe(output);
      output.once('error', reject);
      output.once('finish', () => output.close(resolve));
    });
    request.once('error', reject);
    request.setTimeout(30_000, () => request.destroy(new Error('Guest image download timed out.')));
  });
}

function getDiskCapacity(directory) {
  try {
    const stats = fs.statfsSync(directory);
    return {
      availableBytes: Number(stats.bavail) * Number(stats.bsize),
      totalBytes: Number(stats.blocks) * Number(stats.bsize),
    };
  } catch {
    return { availableBytes: 0, totalBytes: 0 };
  }
}

function walkVirtualDisks(directory) {
  if (!fs.existsSync(directory)) return [];
  const files = [];
  const pending = [directory];
  while (pending.length > 0) {
    const current = pending.pop();
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const target = path.join(current, entry.name);
      if (entry.isDirectory()) pending.push(target);
      else if (entry.isFile() && entry.name.endsWith('.qcow2')) files.push(target);
    }
  }
  return files;
}

function getSparseDiskLiabilityBytes(qemuImgBinary, directory) {
  return walkVirtualDisks(directory).reduce((total, diskPath) => {
    try {
      const info = JSON.parse(runChecked(qemuImgBinary, ['info', '--output=json', diskPath]));
      const virtualSize = Math.max(0, Number(info['virtual-size'] || 0));
      const actualSize = Math.max(0, Number(info['actual-size'] || 0));
      return total + Math.max(0, virtualSize - actualSize);
    } catch {
      return total;
    }
  }, 0);
}

function loadStoredResourceOptions() {
  const profilePath = path.join(RUNTIME_HOME, 'computer-runtime', 'profile.json');
  try {
    const stored = JSON.parse(fs.readFileSync(profilePath, 'utf8'));
    const definitions = [
      ['reservePercent', 'NEOAGENT_COMPUTER_HOST_MEMORY_RESERVE_PERCENT'],
      ['minimumReserveMb', 'NEOAGENT_COMPUTER_HOST_MEMORY_RESERVE_MB'],
      ['minimumGuestMemoryMb', 'NEOAGENT_COMPUTER_MIN_MEMORY_MB'],
      ['maximumGuestMemoryMb', 'NEOAGENT_COMPUTER_MAX_MEMORY_MB'],
      ['maximumGuestCpus', 'NEOAGENT_COMPUTER_MAX_CPUS'],
      ['minimumDiskGiB', 'NEOAGENT_COMPUTER_MIN_DISK_GIB'],
      ['maximumDiskGiB', 'NEOAGENT_COMPUTER_MAX_DISK_GIB'],
      ['storageReservePercent', 'NEOAGENT_COMPUTER_STORAGE_RESERVE_PERCENT'],
    ];
    return Object.fromEntries(definitions
      .filter(([key, envName]) => process.env[envName] == null && Number.isFinite(Number(stored?.[key])))
      .map(([key]) => [key, Number(stored[key])]));
  } catch {
    return {};
  }
}

function ensureVirtualDiskSize(qemuImgBinary, diskPath, minimumGiB) {
  let currentBytes = 0;
  try {
    const info = JSON.parse(runChecked(qemuImgBinary, ['info', '--output=json', diskPath]));
    currentBytes = Number(info['virtual-size'] || 0);
  } catch {}
  if (currentBytes < minimumGiB * 1024 ** 3) {
    runChecked(qemuImgBinary, ['resize', diskPath, `${minimumGiB}G`]);
  }
}

function parseAccelerators(output) {
  return String(output || '')
    .split(/\r?\n/)
    .map((line) => line.trim().split(/\s+/)[0])
    .filter((name) => name && !name.includes(':'));
}

function selectAccelerators(qemuBinary) {
  let available = [];
  try {
    available = parseAccelerators(runChecked(qemuBinary, ['-accel', 'help'], { timeoutMs: 10000 }));
  } catch {}
  const preferred = process.platform === 'darwin'
    ? 'hvf'
    : process.platform === 'win32'
      ? 'whpx'
      : 'kvm';
  const preferredUsable = available.includes(preferred)
    && (
      process.platform !== 'linux'
      || (() => {
        try {
          fs.accessSync('/dev/kvm', fs.constants.R_OK | fs.constants.W_OK);
          return true;
        } catch {
          return false;
        }
      })()
    );
  if (preferredUsable) return [preferred];
  return available.includes('tcg') ? ['tcg'] : [];
}

function resolveArmFirmwareCode() {
  const explicit = String(process.env.NEOAGENT_QEMU_EFI_FIRMWARE || '').trim();
  const candidates = [
    explicit,
    path.join(APP_DIR, 'computer-runtime', 'qemu', 'share', 'qemu', 'edk2-aarch64-code.fd'),
    path.join(RUNTIME_HOME, 'computer-runtime', 'qemu', 'share', 'qemu', 'edk2-aarch64-code.fd'),
    '/opt/homebrew/share/qemu/edk2-aarch64-code.fd',
    '/usr/local/share/qemu/edk2-aarch64-code.fd',
    '/usr/share/AAVMF/AAVMF_CODE.fd',
    '/usr/share/qemu-efi-aarch64/QEMU_EFI.fd',
  ].filter(Boolean);
  return candidates.find((candidate) => fs.existsSync(candidate)) || null;
}

function resolveArmFirmwareVariablesTemplate() {
  const explicit = String(process.env.NEOAGENT_QEMU_EFI_VARIABLES || '').trim();
  const candidates = [
    explicit,
    path.join(APP_DIR, 'computer-runtime', 'qemu', 'share', 'qemu', 'edk2-arm-vars.fd'),
    path.join(RUNTIME_HOME, 'computer-runtime', 'qemu', 'share', 'qemu', 'edk2-arm-vars.fd'),
    '/opt/homebrew/share/qemu/edk2-arm-vars.fd',
    '/usr/local/share/qemu/edk2-arm-vars.fd',
    '/usr/share/AAVMF/AAVMF_VARS.fd',
    '/usr/share/qemu-efi-aarch64/QEMU_VARS.fd',
  ].filter(Boolean);
  return candidates.find((candidate) => fs.existsSync(candidate)) || null;
}

function buildQemuArgs({
  architecture,
  accelerators,
  memoryMb,
  cpus,
  systemDisk,
  dataDisk,
  seedImage,
  guestAgentPort,
  hostAgentPort,
  vncDisplay,
  websocketPort,
  qmpSocket,
  qemuDataDirectory,
  armFirmwareVariables = null,
  kernelImage = null,
  initrdImage = null,
}) {
  const drivePath = (value) => String(value).replaceAll(',', ',,');
  const args = [
    '-name', 'NeoAgent Computer',
    '-nodefaults',
    '-no-reboot',
    '-boot', 'order=c,menu=off,reboot-timeout=0,splash-time=0,strict=on',
  ];
  if (architecture === 'arm64') {
    args.push('-machine', 'virt,highmem=on', '-cpu', accelerators[0] === 'tcg' ? 'max' : 'host');
    const firmwareCode = resolveArmFirmwareCode();
    if (!firmwareCode || !armFirmwareVariables) {
      const error = new Error('ARM64 QEMU firmware is unavailable. Run neoagent repair to restore the computer runtime.');
      error.code = 'COMPUTER_FIRMWARE_MISSING';
      throw error;
    }
    args.push(
      '-drive', `if=pflash,unit=0,format=raw,readonly=on,file=${drivePath(firmwareCode)}`,
      '-drive', `if=pflash,unit=1,format=qcow2,file=${drivePath(armFirmwareVariables)}`,
      '-device', 'VGA',
    );
  } else {
    args.push(
      '-machine', 'q35',
      '-cpu', accelerators[0] === 'tcg' ? 'max' : 'host',
      '-device', `virtio-vga,xres=${COMPUTER_DISPLAY_WIDTH},yres=${COMPUTER_DISPLAY_HEIGHT}`,
    );
  }
  const accelerator = accelerators[0];
  if (!accelerator) {
    const error = new Error('QEMU has no usable hardware accelerator or TCG compatibility accelerator.');
    error.code = 'COMPUTER_ACCELERATOR_UNAVAILABLE';
    throw error;
  }
  args.push('-accel', accelerator);
  if (qemuDataDirectory) args.push('-L', qemuDataDirectory);
  if (kernelImage && initrdImage) {
    args.push(
      '-kernel', kernelImage,
      '-initrd', initrdImage,
      '-append', architecture === 'arm64'
        ? 'root=/dev/vda1 ro rootwait console=tty0 console=ttyAMA0'
        : 'root=/dev/vda1 ro rootwait console=tty0 console=ttyS0',
    );
  }
  args.push(
    '-m', String(memoryMb),
    '-smp', `cpus=${cpus},maxcpus=${cpus}`,
    '-device', 'virtio-balloon',
    '-device', 'virtio-rng-pci',
    '-device', 'qemu-xhci,id=xhci',
    '-device', 'usb-kbd',
    '-device', 'usb-tablet',
    '-drive', `if=none,id=systemdisk,format=qcow2,cache=writeback,discard=unmap,file=${drivePath(systemDisk)}`,
    '-device', 'virtio-blk-pci,drive=systemdisk,bootindex=1,romfile=',
    '-drive', `if=none,id=datadisk,format=qcow2,cache=writeback,discard=unmap,file=${drivePath(dataDisk)}`,
    '-device', 'virtio-blk-pci,drive=datadisk,romfile=',
    '-drive', `if=none,id=seed,format=raw,readonly=on,file=${drivePath(seedImage)}`,
    '-device', 'virtio-blk-pci,drive=seed,romfile=',
    '-netdev', `user,id=net0,hostfwd=tcp:127.0.0.1:${hostAgentPort}-:${guestAgentPort}`,
    '-device', 'virtio-net-pci,netdev=net0,romfile=',
    '-display', 'none',
    '-vnc', `127.0.0.1:${vncDisplay},websocket=127.0.0.1:${websocketPort}`,
    '-qmp', process.platform === 'win32'
      ? `tcp:127.0.0.1:${qmpSocket},server=on,wait=off`
      : `unix:${qmpSocket},server=on,wait=off`,
    '-serial', 'mon:stdio',
  );
  return args;
}

function isProcessAlive(processHandle) {
  return Boolean(processHandle && processHandle.exitCode == null && !processHandle.killed);
}

function isQueueableCapacityError(error) {
  return error?.code === 'COMPUTER_CAPACITY';
}

function requestQmpCommand(qmpSocket, execute, args = undefined, timeoutMs = 30000) {
  return new Promise((resolve, reject) => {
    const socket = typeof qmpSocket === 'number'
      ? net.createConnection({ host: '127.0.0.1', port: qmpSocket })
      : net.createConnection(qmpSocket);
    let settled = false;
    let buffer = '';
    let capabilitiesReady = false;
    const requestId = crypto.randomBytes(8).toString('hex');
    const finish = (error, result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      try { socket.destroy(); } catch {}
      if (error) reject(error);
      else resolve(result);
    };
    const timer = setTimeout(
      () => finish(new Error(`QMP ${execute} timed out.`)),
      timeoutMs,
    );
    timer.unref?.();
    socket.setEncoding('utf8');
    socket.on('data', (chunk) => {
      buffer += chunk;
      const lines = buffer.split(/\r?\n/);
      buffer = lines.pop() || '';
      for (const line of lines) {
        if (!line.trim()) continue;
        let message;
        try { message = JSON.parse(line); } catch { continue; }
        if (message.QMP && !capabilitiesReady) {
          socket.write(`${JSON.stringify({ execute: 'qmp_capabilities', id: 'capabilities' })}\r\n`);
          continue;
        }
        if (message.id === 'capabilities' && !message.error) {
          capabilitiesReady = true;
          socket.write(`${JSON.stringify({
            execute,
            ...(args === undefined ? {} : { arguments: args }),
            id: requestId,
          })}\r\n`);
          continue;
        }
        if (message.id !== requestId) continue;
        if (message.error) {
          finish(new Error(String(message.error.desc || `QMP ${execute} failed.`)));
        } else {
          finish(null, message.return);
        }
      }
    });
    socket.once('error', (error) => finish(error));
    socket.once('close', () => {
      if (!settled) finish(new Error(`QMP ${execute} connection closed unexpectedly.`));
    });
  });
}

async function requestQmpPowerdown(qmpSocket) {
  try {
    await requestQmpCommand(qmpSocket, 'system_powerdown', undefined, 2500);
  } catch {}
}

class QemuVMManager {
  instances = new Map();
  #pending = new Map();
  #transientStatus = new Map();

  constructor(options = {}) {
    this.architecture = normalizeArchitecture(options.architecture);
    this.qemuBinary = options.qemuBinary || resolveQemuSystemBinary(this.architecture);
    this.qemuImgBinary = options.qemuImgBinary || resolveQemuImgBinary();
    this.qemuDataDirectory = options.qemuDataDirectory || resolveQemuDataDirectory(this.qemuBinary);
    this.accelerators = this.qemuBinary ? selectAccelerators(this.qemuBinary) : [];
    this.resourceProfile = options.resourceProfile || getComputerResourceProfile({
      ...loadStoredResourceOptions(),
      accelerator: this.accelerators[0] || '',
    });
    this.bootTimeoutMs = Number(options.bootTimeoutMs || process.env.NEOAGENT_VM_BOOT_TIMEOUT_MS || 20 * 60 * 1000);
    this.guestAgentPort = Number(options.guestAgentPort || 8421);
    this.baseImagePath = String(options.baseImagePath || process.env.NEOAGENT_VM_BASE_IMAGE || '').trim() || null;
    this.baseImagePromise = null;
    ensurePrivateDirectory(COMPUTER_ROOT);
    ensurePrivateDirectory(IMAGE_ROOT);
    ensurePrivateDirectory(INSTANCE_ROOT);
  }


  getReadiness() {
    const image = this.baseImagePath || path.join(IMAGE_ROOT, PINNED_IMAGES[this.architecture].filename);
    const qemuAvailable = Boolean(this.qemuBinary && this.qemuImgBinary);
    return {
      ready: qemuAvailable,
      qemuAvailable,
      qemuBinary: this.qemuBinary,
      qemuImgBinary: this.qemuImgBinary,
      qemuDataDirectory: this.qemuDataDirectory,
      architecture: this.architecture,
      accelerator: this.accelerators[0] || null,
      compatibilityMode: this.accelerators[0] === 'tcg',
      imageReady: fs.existsSync(image),
      image,
      resources: this.resourceProfile,
    };
  }

  async prepareRuntime(options = {}) {
    const readiness = this.getReadiness();
    if (!readiness.qemuAvailable) {
      const error = new Error('The bundled QEMU computer runtime is unavailable.');
      error.code = 'COMPUTER_RUNTIME_UNAVAILABLE';
      throw error;
    }
    const image = options.downloadImage === false
      ? readiness.image
      : await this.#ensureBaseImage();
    return {
      ...this.getReadiness(),
      image,
      imageReady: fs.existsSync(image),
    };
  }

  async cacheDirectBootAssets(userId, client) {
    const key = String(userId || '').trim();
    const session = this.instances.get(key);
    if (!session?.instanceDir || !client) return false;
    const markerPath = path.join(session.instanceDir, 'direct-boot.json');
    const kernelPath = path.join(session.instanceDir, 'vmlinuz');
    const initrdPath = path.join(session.instanceDir, 'initrd.img');
    if (fs.existsSync(markerPath) && fs.existsSync(kernelPath) && fs.existsSync(initrdPath)) {
      return true;
    }
    const payload = await client.request('GET', '/system/boot-assets', undefined, {
      timeoutMs: 120000,
      maxResponseBytes: MAX_BOOT_ASSET_BYTES * 2,
      retryCount: 0,
    });
    const decodeAsset = (asset, label) => {
      const data = Buffer.from(String(asset?.content || ''), 'base64');
      if (data.length <= 0 || data.length > MAX_BOOT_ASSET_BYTES || data.length !== Number(asset?.size)) {
        throw new Error(`${label} boot asset has an invalid size.`);
      }
      const digest = crypto.createHash('sha256').update(data).digest('hex');
      if (digest !== String(asset?.sha256 || '')) {
        throw new Error(`${label} boot asset failed checksum verification.`);
      }
      return { data, digest };
    };
    const kernel = decodeAsset(payload?.kernel, 'Kernel');
    const initrd = decodeAsset(payload?.initrd, 'Initramfs');
    const writeAsset = (target, data) => {
      const temporary = `${target}.${process.pid}.${crypto.randomBytes(4).toString('hex')}.tmp`;
      fs.writeFileSync(temporary, data, { mode: 0o600 });
      fs.renameSync(temporary, target);
      ensurePrivateFile(target);
    };
    writeAsset(kernelPath, kernel.data);
    writeAsset(initrdPath, initrd.data);
    fs.writeFileSync(markerPath, `${JSON.stringify({
      version: 1,
      architecture: this.architecture,
      debianBuild: PINNED_DEBIAN_BUILD,
      release: String(payload?.release || ''),
      kernelSha256: kernel.digest,
      initrdSha256: initrd.digest,
      cachedAt: new Date().toISOString(),
    }, null, 2)}\n`, { mode: 0o600 });
    ensurePrivateFile(markerPath);
    return true;
  }

  hasVm(userId) {
    return isProcessAlive(this.instances.get(String(userId || '').trim())?.process);
  }

  hasTrackedVm(userId) {
    return this.instances.has(String(userId || '').trim());
  }

  getStatus(userId) {
    const key = String(userId || '').trim();
    const session = this.instances.get(key);
    if (!session) {
      const transient = this.#transientStatus.get(key);
      if (transient) {
        return {
          ...transient,
          capabilities: ['desktop', 'browser', 'shell', 'files', 'teach'],
          readiness: this.getReadiness(),
        };
      }
      return {
        state: 'stopped',
        capabilities: ['desktop', 'browser', 'shell', 'files', 'teach'],
        readiness: this.getReadiness(),
      };
    }
    return {
      state: isProcessAlive(session.process) ? session.state : 'error',
      capabilities: ['desktop', 'browser', 'shell', 'files', 'teach'],
      accelerator: session.accelerator,
      compatibilityMode: session.accelerator === 'tcg',
      resources: session.resources,
      startedAt: session.startedAt,
      startup: {
        targetMs: 10_000,
        measuredMs: session.startupDurationMs,
        met: session.startupDurationMs == null ? null : session.startupDurationMs < 10_000,
        mode: session.directBoot ? 'direct' : 'provisioning',
      },
      lastError: session.lastError || null,
      desktop: session.desktop || null,
    };
  }

  async #ensureBaseImage() {
    if (this.baseImagePromise) return this.baseImagePromise;
    this.baseImagePromise = this.#prepareBaseImage().finally(() => {
      this.baseImagePromise = null;
    });
    return this.baseImagePromise;
  }

  async #prepareBaseImage() {
    if (this.baseImagePath) {
      if (!fs.existsSync(this.baseImagePath)) {
        throw new Error('Configured cloud computer base image does not exist.');
      }
      return this.baseImagePath;
    }
    const pinned = PINNED_IMAGES[this.architecture];
    const destination = path.join(IMAGE_ROOT, pinned.filename);
    if (fs.existsSync(destination)) {
      const digest = await hashFile(destination);
      if (digest === pinned.sha512) return destination;
      fs.rmSync(destination, { force: true });
    }
    const temporary = `${destination}.${process.pid}.${crypto.randomBytes(6).toString('hex')}.download`;
    logger.info(`Downloading digest-verified Debian guest image for ${this.architecture}.`);
    try {
      await downloadFile(pinned.url, temporary);
      const digest = await hashFile(temporary);
      if (digest !== pinned.sha512) {
        const error = new Error('Downloaded cloud computer image failed SHA-512 verification.');
        error.code = 'COMPUTER_IMAGE_HASH_MISMATCH';
        throw error;
      }
      fs.renameSync(temporary, destination);
      ensurePrivateFile(destination);
      return destination;
    } finally {
      fs.rmSync(temporary, { force: true });
    }
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
    if (this.#pending.has(key)) return this.#pending.get(key);
    this.#transientStatus.set(key, { state: 'starting', startedAt: new Date().toISOString() });
    const promise = this.#startVm(key)
      .then((session) => {
        this.#transientStatus.delete(key);
        return session;
      })
      .catch((error) => {
        this.#transientStatus.set(key, {
          state: isQueueableCapacityError(error) ? 'capacity_wait' : 'error',
          lastError: error.message,
          errorCode: error.code || null,
        });
        throw error;
      })
      .finally(() => this.#pending.delete(key));
    this.#pending.set(key, promise);
    return promise;
  }

  async #startVm(key) {
    const readiness = this.getReadiness();
    if (!readiness.ready) {
      const error = new Error('QEMU computer runtime is unavailable. Run neoagent repair.');
      error.code = 'COMPUTER_RUNTIME_UNAVAILABLE';
      error.status = 503;
      throw error;
    }
    const resources = allocateComputerResources(this.resourceProfile, this.#activeAllocations());
    const baseImage = await this.#ensureBaseImage();
    const instanceDir = path.join(INSTANCE_ROOT, userDirectoryKey(key));
    ensurePrivateDirectory(instanceDir);
    const systemDisk = path.join(instanceDir, 'system.qcow2');
    const dataDisk = path.join(instanceDir, 'data.qcow2');
    const baseBuildMarker = path.join(instanceDir, 'base-build');
    const previousBuild = fs.existsSync(baseBuildMarker)
      ? fs.readFileSync(baseBuildMarker, 'utf8').trim()
      : PINNED_DEBIAN_BUILD;
    const replaceSystemDisk = fs.existsSync(systemDisk) && previousBuild !== PINNED_DEBIAN_BUILD;
    const createsSystemDisk = !fs.existsSync(systemDisk) || replaceSystemDisk;
    const diskCapacity = getDiskCapacity(INSTANCE_ROOT);
    const sparseLiabilityBytes = getSparseDiskLiabilityBytes(this.qemuImgBinary, INSTANCE_ROOT);
    const newSystemLiabilityBytes = createsSystemDisk ? 8 * 1024 ** 3 : 0;
    const storage = {
      ...diskCapacity,
      sparseLiabilityBytes: sparseLiabilityBytes + newSystemLiabilityBytes,
    };
    if (getStorageHeadroomBytes(this.resourceProfile, storage) < 0) {
      const error = new Error('Starting this cloud computer would violate the host storage reserve.');
      error.code = 'COMPUTER_STORAGE_CAPACITY';
      error.status = 507;
      throw error;
    }
    if (replaceSystemDisk) {
      const previousSystemDisk = path.join(instanceDir, 'system.previous.qcow2');
      fs.rmSync(previousSystemDisk, { force: true });
      fs.renameSync(systemDisk, previousSystemDisk);
      fs.rmSync(path.join(instanceDir, 'direct-boot.json'), { force: true });
      fs.rmSync(path.join(instanceDir, 'vmlinuz'), { force: true });
      fs.rmSync(path.join(instanceDir, 'initrd.img'), { force: true });
    }
    if (!fs.existsSync(systemDisk)) {
      runChecked(this.qemuImgBinary, ['create', '-f', 'qcow2', '-F', 'qcow2', '-b', baseImage, systemDisk]);
    }
    ensureVirtualDiskSize(this.qemuImgBinary, systemDisk, 8);
    fs.writeFileSync(baseBuildMarker, `${PINNED_DEBIAN_BUILD}\n`, { mode: 0o600 });
    if (!fs.existsSync(dataDisk)) {
      const diskGiB = chooseDataDiskGiB(this.resourceProfile, storage);
      runChecked(this.qemuImgBinary, ['create', '-f', 'qcow2', dataDisk, `${diskGiB}G`]);
    }

    const hostAgentPort = await findAvailablePort();
    const websocketPort = await findAvailablePort();
    const vnc = await findVncDisplay();
    const qmpSocket = process.platform === 'win32'
      ? await findAvailablePort()
      : path.join(instanceDir, 'qmp.sock');
    if (typeof qmpSocket === 'string') fs.rmSync(qmpSocket, { force: true });
    const guestTokenPath = path.join(instanceDir, 'guest-token');
    let guestToken = fs.existsSync(guestTokenPath)
      ? fs.readFileSync(guestTokenPath, 'utf8').trim()
      : crypto.randomBytes(32).toString('hex');
    if (!guestToken) guestToken = crypto.randomBytes(32).toString('hex');
    if (!fs.existsSync(guestTokenPath) || fs.readFileSync(guestTokenPath, 'utf8').trim() !== guestToken) {
      fs.writeFileSync(guestTokenPath, `${guestToken}\n`, { mode: 0o600 });
    }
    const seed = ensureGuestBootstrapSeed({
      userRoot: instanceDir,
      guestToken,
      guestAgentPort: this.guestAgentPort,
      guestArch: this.architecture,
      runtimeProfile: 'browser_cli',
    });
    let kernelImage = null;
    let initrdImage = null;
    try {
      const directBoot = JSON.parse(fs.readFileSync(path.join(instanceDir, 'direct-boot.json'), 'utf8'));
      const candidateKernel = path.join(instanceDir, 'vmlinuz');
      const candidateInitrd = path.join(instanceDir, 'initrd.img');
      const metadataMatches = (
        directBoot?.version === 1
        && directBoot.architecture === this.architecture
        && directBoot.debianBuild === PINNED_DEBIAN_BUILD
        && fs.existsSync(candidateKernel)
        && fs.existsSync(candidateInitrd)
      );
      const hashesMatch = metadataMatches
        && await hashFile(candidateKernel, 'sha256') === directBoot.kernelSha256
        && await hashFile(candidateInitrd, 'sha256') === directBoot.initrdSha256;
      if (hashesMatch) {
        kernelImage = candidateKernel;
        initrdImage = candidateInitrd;
      } else if (metadataMatches) {
        fs.rmSync(path.join(instanceDir, 'direct-boot.json'), { force: true });
        fs.rmSync(candidateKernel, { force: true });
        fs.rmSync(candidateInitrd, { force: true });
        logger.warn(`Discarded invalid direct-boot cache for user ${key}.`);
      }
    } catch {}
    let armFirmwareVariables = null;
    if (this.architecture === 'arm64') {
      const variablesTemplate = resolveArmFirmwareVariablesTemplate();
      if (!variablesTemplate) {
        const error = new Error('ARM64 QEMU variable firmware is unavailable. Run neoagent repair to restore the computer runtime.');
        error.code = 'COMPUTER_FIRMWARE_MISSING';
        throw error;
      }
      armFirmwareVariables = path.join(instanceDir, 'uefi-vars.qcow2');
      const variablesMarker = path.join(instanceDir, 'uefi-vars-base.sha512');
      const templateDigest = await hashFile(variablesTemplate);
      const storedDigest = fs.existsSync(variablesMarker)
        ? fs.readFileSync(variablesMarker, 'utf8').trim()
        : '';
      if (!fs.existsSync(armFirmwareVariables) || storedDigest !== templateDigest) {
        fs.rmSync(armFirmwareVariables, { force: true });
        runChecked(this.qemuImgBinary, [
          'create', '-f', 'qcow2', '-F', 'raw', '-b', variablesTemplate, armFirmwareVariables,
        ]);
        fs.writeFileSync(variablesMarker, `${templateDigest}\n`, { mode: 0o600 });
      }
    }
    const args = buildQemuArgs({
      architecture: this.architecture,
      accelerators: this.accelerators,
      memoryMb: resources.memoryMb,
      cpus: resources.cpus,
      systemDisk,
      dataDisk,
      seedImage: seed.seedImagePath,
      guestAgentPort: this.guestAgentPort,
      hostAgentPort,
      vncDisplay: vnc.display,
      websocketPort,
      qmpSocket,
      qemuDataDirectory: this.qemuDataDirectory,
      armFirmwareVariables,
      kernelImage,
      initrdImage,
    });
    const logPath = path.join(instanceDir, 'qemu.log');
    const logDescriptor = fs.openSync(logPath, 'a', 0o600);
    const child = spawn(this.qemuBinary, args, {
      cwd: instanceDir,
      stdio: ['ignore', logDescriptor, logDescriptor],
      windowsHide: true,
    });
    fs.closeSync(logDescriptor);

    const session = {
      instanceDir,
      baseUrl: `http://127.0.0.1:${hostAgentPort}`,
      guestToken,
      process: child,
      state: 'starting',
      resources,
      accelerator: this.accelerators[0],
      display: {
        websocketUrl: `ws://127.0.0.1:${websocketPort}`,
        websocketPort,
        vncPort: vnc.port,
      },
      qmpSocket,
      startedAt: new Date().toISOString(),
      directBoot: Boolean(kernelImage && initrdImage),
      startupDurationMs: null,
      lastError: null,
      getLastError: () => {
        try {
          return fs.readFileSync(logPath, 'utf8').slice(-32 * 1024);
        } catch {
          return session.lastError;
        }
      },
    };
    this.instances.set(key, session);
    child.once('error', (error) => {
      session.state = 'error';
      session.lastError = error.message;
    });
    child.once('exit', (code, signal) => {
      if (session.state !== 'stopping') {
        session.state = 'error';
        session.lastError = `QEMU exited (${code ?? signal ?? 'unknown'}).`;
      }
    });
    logger.info(`Started computer for user ${key} with ${resources.memoryMb} MiB and ${resources.cpus} vCPU.`);
    return session;
  }

  async killVm(userId) {
    const key = String(userId || '').trim();
    this.#transientStatus.delete(key);
    const session = this.instances.get(key);
    this.instances.delete(key);
    if (!session?.process || !isProcessAlive(session.process)) return;
    session.state = 'stopping';
    const exited = new Promise((resolve) => session.process.once('exit', resolve));
    await requestQmpPowerdown(session.qmpSocket);
    await Promise.race([exited, new Promise((resolve) => setTimeout(resolve, 10000))]);
    if (isProcessAlive(session.process)) {
      try { session.process.kill('SIGTERM'); } catch {}
      await Promise.race([exited, new Promise((resolve) => setTimeout(resolve, 3000))]);
    }
    if (isProcessAlive(session.process)) {
      try { session.process.kill('SIGKILL'); } catch {}
      await Promise.race([exited, new Promise((resolve) => setTimeout(resolve, 2000))]);
    }
  }

  async failVm(userId, error) {
    const key = String(userId || '').trim();
    await this.killVm(key);
    this.#transientStatus.set(key, {
      state: isQueueableCapacityError(error) ? 'capacity_wait' : 'error',
      lastError: String(error?.message || error || 'Cloud computer failed.'),
      errorCode: error?.code || null,
    });
  }

  async sleepVm(userId) {
    const key = String(userId || '').trim();
    await this.killVm(key);
    this.#transientStatus.set(key, { state: 'sleeping' });
  }

  async shutdown() {
    await Promise.allSettled(this.#pending.values());
    await Promise.allSettled(Array.from(this.instances.keys(), (userId) => this.killVm(userId)));
    this.#transientStatus.clear();
  }
}

module.exports = {
  COMPUTER_ROOT,
  PINNED_IMAGES,
  QemuVMManager,
  buildQemuArgs,
  normalizeArchitecture,
  resolveQemuImgBinary,
  resolveQemuDataDirectory,
  resolveQemuSystemBinary,
  selectAccelerators,
};
