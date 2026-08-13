#!/usr/bin/env node
'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  const value = index >= 0 ? process.argv[index + 1] : '';
  if (!value || value.startsWith('--')) throw new Error(`--${name} is required.`);
  return path.resolve(value);
}

function commandOutput(command, args) {
  const result = spawnSync(command, args, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true,
  });
  if (result.error || result.status !== 0) {
    throw new Error(String(result.stderr || result.stdout || result.error?.message || `${command} failed`).trim());
  }
  return String(result.stdout || '').trim();
}

function resolveCommand(name) {
  const output = commandOutput(
    process.platform === 'win32' ? 'where.exe' : 'sh',
    process.platform === 'win32' ? [name] : ['-c', 'command -v "$1"', 'sh', name],
  ).split(/\r?\n/)[0];
  return fs.realpathSync.native(output.trim());
}

function hashFile(filePath) {
  return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

function createUniqueCopier() {
  const sourceByDestination = new Map();
  return function copyUnique(source, destinationDirectory) {
    const resolvedSource = fs.realpathSync.native(source);
    const destination = path.join(destinationDirectory, path.basename(resolvedSource));
    fs.mkdirSync(destinationDirectory, { recursive: true });
    const previousSource = sourceByDestination.get(destination);
    if (previousSource) {
      if (
        previousSource !== resolvedSource
        && hashFile(previousSource) !== hashFile(resolvedSource)
      ) {
        throw new Error(`Portable QEMU dependency name collision: ${path.basename(resolvedSource)}`);
      }
      return destination;
    }
    if (fs.existsSync(destination) && hashFile(resolvedSource) !== hashFile(destination)) {
      throw new Error(`Portable QEMU dependency name collision: ${path.basename(resolvedSource)}`);
    }
    sourceByDestination.set(destination, resolvedSource);
    if (!fs.existsSync(destination)) fs.copyFileSync(resolvedSource, destination);
    if (process.platform !== 'win32') fs.chmodSync(destination, 0o755);
    return destination;
  };
}

const copyUnique = createUniqueCopier();

function findDataDirectory(systemBinary) {
  const prefix = path.dirname(path.dirname(systemBinary));
  const candidates = [
    path.join(prefix, 'share', 'qemu'),
    path.join(path.dirname(systemBinary), 'share', 'qemu'),
    path.join(path.dirname(systemBinary), '..', 'share', 'qemu'),
    '/usr/share/qemu',
    '/usr/local/share/qemu',
    '/opt/homebrew/share/qemu',
  ];
  return candidates.map((candidate) => path.resolve(candidate)).find((candidate) => fs.existsSync(candidate)) || null;
}

function linuxDependencies(binary) {
  const output = commandOutput('ldd', [binary]);
  return output.split(/\r?\n/).flatMap((line) => {
    const match = line.match(/=>\s+(\/[^\s]+)|^\s*(\/[^\s]+)/);
    return match ? [match[1] || match[2]] : [];
  }).filter((dependency) => {
    const name = path.basename(dependency);
    return !/^(?:ld-linux|libc\.so|libm\.so|libpthread\.so|librt\.so|libdl\.so)/.test(name);
  });
}

function collectLinuxDependencies(binaries, outputDirectory) {
  const libraryDirectory = path.join(outputDirectory, 'lib');
  const pending = [...binaries];
  const visited = new Set();
  while (pending.length > 0) {
    const binary = pending.pop();
    const resolved = fs.realpathSync.native(binary);
    if (visited.has(resolved)) continue;
    visited.add(resolved);
    for (const dependency of linuxDependencies(resolved)) {
      const target = copyUnique(fs.realpathSync.native(dependency), libraryDirectory);
      if (!visited.has(fs.realpathSync.native(dependency))) pending.push(dependency);
      commandOutput('patchelf', ['--set-rpath', '$ORIGIN', target]);
    }
  }
  for (const binary of binaries) commandOutput('patchelf', ['--set-rpath', '$ORIGIN/../lib', binary]);
}

function macDependencies(binary) {
  return commandOutput('otool', ['-L', binary]).split(/\r?\n/).slice(1).flatMap((line) => {
    const dependency = line.trim().split(/\s+\(/)[0];
    return dependency.startsWith('/') && !dependency.startsWith('/usr/lib/') && !dependency.startsWith('/System/')
      ? [dependency]
      : [];
  });
}

function collectMacDependencies(binaries, outputDirectory) {
  const libraryDirectory = path.join(outputDirectory, 'lib');
  const dependencyMap = new Map();
  const pending = [...binaries];
  const visited = new Set();
  while (pending.length > 0) {
    const binary = pending.pop();
    const resolved = fs.realpathSync.native(binary);
    if (visited.has(resolved)) continue;
    visited.add(resolved);
    for (const dependency of macDependencies(resolved)) {
      const realDependency = fs.realpathSync.native(dependency);
      const target = copyUnique(realDependency, libraryDirectory);
      dependencyMap.set(dependency, target);
      pending.push(realDependency);
    }
  }
  const targets = [...binaries, ...new Set(dependencyMap.values())];
  for (const target of targets) {
    const inLibraryDirectory = path.dirname(target) === libraryDirectory;
    for (const dependency of macDependencies(target)) {
      if (!dependencyMap.has(dependency)) continue;
      const replacement = inLibraryDirectory
        ? `@loader_path/${path.basename(dependencyMap.get(dependency))}`
        : `@loader_path/../lib/${path.basename(dependencyMap.get(dependency))}`;
      commandOutput('install_name_tool', ['-change', dependency, replacement, target]);
    }
    if (inLibraryDirectory) {
      commandOutput('install_name_tool', ['-id', `@loader_path/${path.basename(target)}`, target]);
    }
    commandOutput('codesign', ['--force', '--sign', '-', target]);
  }
}

function stageWindowsRuntime(systemBinary, imageBinary, outputDirectory) {
  const sourceDirectory = path.dirname(systemBinary);
  const binaryDirectory = path.join(outputDirectory, 'bin');
  fs.mkdirSync(binaryDirectory, { recursive: true });
  for (const entry of fs.readdirSync(sourceDirectory, { withFileTypes: true })) {
    if (!entry.isFile()) continue;
    const lower = entry.name.toLowerCase();
    if (lower.endsWith('.dll') || [path.basename(systemBinary).toLowerCase(), path.basename(imageBinary).toLowerCase()].includes(lower)) {
      fs.copyFileSync(path.join(sourceDirectory, entry.name), path.join(binaryDirectory, entry.name));
    }
  }
}

function main() {
  const outputDirectory = argument('output');
  const systemName = process.arch === 'arm64' ? 'qemu-system-aarch64' : 'qemu-system-x86_64';
  const systemBinary = resolveCommand(systemName);
  const imageBinary = resolveCommand('qemu-img');
  const dataDirectory = findDataDirectory(systemBinary);
  if (!dataDirectory) throw new Error('QEMU firmware/data directory was not found.');

  fs.rmSync(outputDirectory, { recursive: true, force: true });
  fs.mkdirSync(outputDirectory, { recursive: true });
  let stagedBinaries;
  if (process.platform === 'win32') {
    stageWindowsRuntime(systemBinary, imageBinary, outputDirectory);
    stagedBinaries = [
      path.join(outputDirectory, 'bin', path.basename(systemBinary)),
      path.join(outputDirectory, 'bin', path.basename(imageBinary)),
    ];
  } else {
    const binaryDirectory = path.join(outputDirectory, 'bin');
    stagedBinaries = [
      copyUnique(systemBinary, binaryDirectory),
      copyUnique(imageBinary, binaryDirectory),
    ];
    if (process.platform === 'darwin') collectMacDependencies(stagedBinaries, outputDirectory);
    else collectLinuxDependencies(stagedBinaries, outputDirectory);
  }
  fs.cpSync(dataDirectory, path.join(outputDirectory, 'share', 'qemu'), { recursive: true, force: true });

  const version = commandOutput(systemBinary, ['--version']).split(/\r?\n/)[0];
  const manifest = {
    schemaVersion: 1,
    platform: process.platform,
    architecture: process.arch,
    version,
    files: stagedBinaries.map((filePath) => ({
      path: path.relative(outputDirectory, filePath).split(path.sep).join('/'),
      sha256: hashFile(filePath),
    })),
  };
  fs.writeFileSync(path.join(outputDirectory, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
}

if (require.main === module) main();

module.exports = { createUniqueCopier };
