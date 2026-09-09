'use strict';

const fs = require('fs');
const path = require('path');
const { APP_DIR, RUNTIME_HOME } = require('../runtime/paths');

function executableName(name) {
  return process.platform === 'win32' ? `${name}.exe` : name;
}

function systemBinaryName(architecture = process.arch === 'arm64' ? 'arm64' : 'x64') {
  return architecture === 'arm64' ? 'qemu-system-aarch64' : 'qemu-system-x86_64';
}

function isRunnableFile(candidate) {
  try {
    const resolved = fs.realpathSync.native(candidate);
    fs.accessSync(resolved, fs.constants.F_OK | fs.constants.X_OK);
    return fs.statSync(resolved).isFile();
  } catch {
    return false;
  }
}

function readActivatedRuntimeVersion(runtimeHome = RUNTIME_HOME) {
  try {
    const version = String(
      JSON.parse(fs.readFileSync(path.join(runtimeHome, 'app', 'current.json'), 'utf8')).version || '',
    ).trim();
    if (!version || version.includes('..') || /[\\/]/.test(version)) return null;
    return version;
  } catch {
    return null;
  }
}

function stagedQemuRuntimeDirectory(runtimeHome = RUNTIME_HOME) {
  return path.join(runtimeHome, 'computer-runtime', 'qemu');
}

function packagedQemuRuntimeDirectory(runtimeHome = RUNTIME_HOME) {
  const version = readActivatedRuntimeVersion(runtimeHome);
  if (!version) return null;
  return path.join(
    runtimeHome,
    'app',
    'versions',
    version,
    'app',
    'computer-runtime',
    'qemu',
  );
}

function isCompleteQemuRuntime(directory, architecture) {
  if (!directory) return false;
  return [
    path.join(directory, 'bin', executableName(systemBinaryName(architecture))),
    path.join(directory, 'bin', executableName('qemu-img')),
  ].every((candidate) => isRunnableFile(candidate));
}

function packagedQemuExecutableCandidates(name, runtimeHome = RUNTIME_HOME) {
  const directory = packagedQemuRuntimeDirectory(runtimeHome);
  return directory ? [path.join(directory, 'bin', executableName(name))] : [];
}

function qemuInstallPath(envPath = process.env.PATH || '') {
  const extras = process.platform === 'win32'
    ? [path.join(process.env.ProgramFiles || 'C:\\Program Files', 'qemu')]
    : ['/opt/homebrew/bin', '/opt/homebrew/sbin', '/usr/local/bin'];
  return [...extras, envPath].filter(Boolean).join(path.delimiter);
}

function hostQemuInstallPlan(platform, architecture = process.arch === 'arm64' ? 'arm64' : 'x64') {
  if (platform === 'macos') {
    return {
      command: 'brew',
      args: ['install', 'qemu'],
      missingCommand: 'Homebrew is required to install the QEMU computer runtime. Install Homebrew, then run `neoagent repair`.',
    };
  }
  if (platform === 'linux') {
    const systemPackage = architecture === 'arm64' ? 'qemu-system-arm' : 'qemu-system-x86';
    const packages = [systemPackage, 'qemu-utils', 'ovmf'];
    const root = typeof process.getuid === 'function' && process.getuid() === 0;
    return {
      command: root ? 'apt-get' : 'sudo',
      args: root
        ? ['install', '-y', '--no-install-recommends', ...packages]
        : ['apt-get', 'install', '-y', '--no-install-recommends', ...packages],
      missingCommand: 'apt-get is required to install the QEMU computer runtime. Install QEMU with your package manager, then run `neoagent repair`.',
    };
  }
  if (platform === 'windows') {
    return {
      command: 'choco',
      args: ['install', 'qemu', '--yes', '--no-progress'],
      missingCommand: 'Chocolatey is required to install the QEMU computer runtime. Install QEMU, then run `neoagent repair`.',
    };
  }
  return null;
}

function installHostQemu({
  platform,
  architecture,
  commandExists,
  runOrThrow,
  logInfo = () => {},
} = {}) {
  const plan = hostQemuInstallPlan(platform, architecture);
  if (!plan) {
    throw new Error('This platform cannot install the QEMU computer runtime automatically.');
  }
  if (typeof commandExists === 'function' && !commandExists(plan.command)) {
    throw new Error(plan.missingCommand);
  }
  if (plan.command === 'sudo' && typeof commandExists === 'function' && !commandExists('apt-get')) {
    throw new Error(plan.missingCommand);
  }
  logInfo(`Installing QEMU with ${plan.command} ${plan.args.join(' ')}…`);
  runOrThrow(plan.command, plan.args, {
    env: { ...process.env, PATH: qemuInstallPath() },
  });
}

function copyQemuRuntime(source, destination) {
  const resolvedSource = path.resolve(source);
  const resolvedDestination = path.resolve(destination);
  if (resolvedSource === resolvedDestination) return resolvedDestination;
  fs.rmSync(resolvedDestination, { recursive: true, force: true });
  fs.mkdirSync(path.dirname(resolvedDestination), { recursive: true, mode: 0o700 });
  fs.cpSync(resolvedSource, resolvedDestination, { recursive: true, force: true });
  return resolvedDestination;
}

function stageHostQemuRuntime(destination, { runOrThrow } = {}) {
  const script = path.join(APP_DIR, 'scripts', 'stage_qemu_runtime.js');
  runOrThrow(process.execPath, [script, '--output', destination], {
    env: { ...process.env, PATH: qemuInstallPath() },
  });
  return destination;
}

function restoreQemuComputerRuntime(options = {}) {
  const architecture = options.architecture || (process.arch === 'arm64' ? 'arm64' : 'x64');
  const runtimeHome = options.runtimeHome || RUNTIME_HOME;
  const destination = stagedQemuRuntimeDirectory(runtimeHome);
  if (isCompleteQemuRuntime(destination, architecture)) {
    return { action: 'kept', directory: destination };
  }

  const packaged = packagedQemuRuntimeDirectory(runtimeHome);
  if (isCompleteQemuRuntime(packaged, architecture)) {
    copyQemuRuntime(packaged, destination);
    return { action: 'copied', directory: destination, source: packaged };
  }

  installHostQemu(options);
  stageHostQemuRuntime(destination, options);
  if (!isCompleteQemuRuntime(destination, architecture)) {
    throw new Error('QEMU was installed but the computer runtime is still incomplete.');
  }
  return { action: 'staged', directory: destination };
}

module.exports = {
  hostQemuInstallPlan,
  isCompleteQemuRuntime,
  packagedQemuExecutableCandidates,
  packagedQemuRuntimeDirectory,
  qemuInstallPath,
  restoreQemuComputerRuntime,
  stagedQemuRuntimeDirectory,
  systemBinaryName,
};
