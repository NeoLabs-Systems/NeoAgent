'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { APP_DIR } = require('../../../../runtime/paths');

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
  return dirPath;
}

function ensureRepoNodeModulesLink(targetDir) {
  ensureDir(targetDir);
  const sourceNodeModules = path.join(APP_DIR, 'node_modules');
  const targetNodeModules = path.join(targetDir, 'node_modules');
  if (fs.existsSync(targetNodeModules)) {
    return targetNodeModules;
  }
  fs.symlinkSync(sourceNodeModules, targetNodeModules, 'junction');
  return targetNodeModules;
}

function shellEscape(value) {
  const text = String(value ?? '');
  if (!text.length) return "''";
  return `'${text.replace(/'/g, `'\\''`)}'`;
}

function normalizeFilenameBase(value, fallback = 'artifact') {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return normalized || fallback;
}

function resolveRepoBinary(...segments) {
  const parts = [...segments];
  if (process.platform === 'win32' && parts.length > 0 && !parts[parts.length - 1].endsWith('.cmd')) {
    parts[parts.length - 1] = `${parts[parts.length - 1]}.cmd`;
  }
  return path.join(APP_DIR, 'node_modules', '.bin', ...parts);
}

function assertExistingFile(filePath, label = 'file') {
  const absolutePath = path.resolve(String(filePath || ''));
  if (!fs.existsSync(absolutePath)) {
    throw new Error(`${label} does not exist: ${absolutePath}`);
  }
  const stat = fs.statSync(absolutePath);
  if (!stat.isFile()) {
    throw new Error(`${label} is not a file: ${absolutePath}`);
  }
  return absolutePath;
}

function writeTextFile(filePath, content) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, String(content || ''), 'utf8');
  return filePath;
}

function writeJsonFile(filePath, payload) {
  writeTextFile(filePath, `${JSON.stringify(payload, null, 2)}\n`);
  return filePath;
}

function copyAssetIntoJob(sourcePath, targetDir, preferredName = 'asset', workspaceManager = null, userId = null) {
  if (!workspaceManager || userId == null) {
    throw new Error('Workspace manager is required for integrated tool assets.');
  }
  const absolutePath = workspaceManager.resolvePath(userId, sourcePath, 'asset');
  ensureDir(targetDir);
  const extension = path.extname(absolutePath).toLowerCase();
  const basename = normalizeFilenameBase(path.basename(absolutePath, extension), preferredName);
  const filename = `${basename}-${crypto.randomBytes(3).toString('hex')}${extension}`;
  const targetPath = path.join(targetDir, filename);
  fs.copyFileSync(absolutePath, targetPath);
  return {
    sourcePath: absolutePath,
    targetPath,
    relativePath: filename,
  };
}

async function runCheckedCommand(executor, command, options = {}) {
  if (!executor || typeof executor.execute !== 'function') {
    throw new Error('CLI executor is unavailable for integrated tools.');
  }
  const result = await executor.execute(command, {
    cwd: options.cwd,
    timeout: options.timeout,
    env: options.env,
  });
  if (result.exitCode !== 0) {
    const stderr = String(result.stderr || '').trim();
    const stdout = String(result.stdout || '').trim();
    const details = stderr || stdout || `Command failed: ${command}`;
    throw new Error(
      options.errorPrefix
        ? `${options.errorPrefix} ${details}`.trim()
        : details
    );
  }
  return result;
}

async function createJobDir(toolName, filenameBase, workspaceManager = null, userId = null) {
  const prefix = normalizeFilenameBase(toolName, 'tool');
  const suffix = normalizeFilenameBase(filenameBase, 'output');
  const jobId = `${Date.now()}-${crypto.randomBytes(4).toString('hex')}-${suffix}`;
  if (workspaceManager && userId != null) {
    const toolingRoot = await workspaceManager.getToolingRoot(userId, prefix);
    return ensureDir(path.join(toolingRoot, jobId));
  }
  throw new Error('Workspace manager is required for integrated tool jobs.');
}

function inferArtifactExtension(filePath) {
  return path.extname(String(filePath || '')).toLowerCase().replace(/^\./, '') || 'bin';
}

function inferContentType(filePath) {
  const extension = path.extname(String(filePath || '')).toLowerCase();
  switch (extension) {
    case '.pdf': return 'application/pdf';
    case '.ppt': return 'application/vnd.ms-powerpoint';
    case '.pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case '.md': return 'text/markdown';
    case '.png': return 'image/png';
    case '.jpg':
    case '.jpeg': return 'image/jpeg';
    case '.svg': return 'image/svg+xml';
    case '.mp4': return 'video/mp4';
    case '.mov': return 'video/quicktime';
    case '.webm': return 'video/webm';
    default: return 'application/octet-stream';
  }
}

function inferArtifactKind(filePath) {
  const extension = path.extname(String(filePath || '')).toLowerCase();
  if (['.ppt', '.pptx'].includes(extension)) return 'slides';
  if (['.pdf', '.md'].includes(extension)) return 'document';
  if (['.png', '.jpg', '.jpeg', '.svg'].includes(extension)) return 'image';
  if (['.mp4', '.mov', '.webm'].includes(extension)) return 'video';
  return 'artifact';
}

function createArtifactDescriptor(filePath, options = {}) {
  const absolutePath = assertExistingFile(filePath, 'output');
  const stat = fs.statSync(absolutePath);
  return {
    kind: options.kind || inferArtifactKind(absolutePath),
    label: options.label || path.basename(absolutePath),
    path: absolutePath,
    mimeType: options.mimeType || inferContentType(absolutePath),
    size: stat.size,
  };
}

function promoteArtifactDescriptor(descriptor, artifactStore, userId) {
  if (!artifactStore || userId == null || !descriptor?.path) {
    return descriptor;
  }
  const extension = inferArtifactExtension(descriptor.path);
  const allocation = artifactStore.allocateFile(userId, {
    kind: descriptor.kind || inferArtifactKind(descriptor.path),
    extension,
    contentType: descriptor.mimeType || inferContentType(descriptor.path),
    filenameBase: normalizeFilenameBase(descriptor.label || descriptor.kind || 'artifact', 'artifact'),
    originalFilename: path.basename(descriptor.path),
    metadata: {
      sourceTool: 'integrated-media',
      originalPath: descriptor.path,
    },
  });
  fs.copyFileSync(descriptor.path, allocation.storagePath);
  const finalized = artifactStore.finalizeFile(allocation.artifactId, allocation.storagePath);
  return {
    kind: descriptor.kind || inferArtifactKind(descriptor.path),
    label: descriptor.label || path.basename(descriptor.path),
    url: finalized.url,
    mimeType: descriptor.mimeType || inferContentType(descriptor.path),
    size: finalized.byteSize,
  };
}

module.exports = {
  copyAssetIntoJob,
  createArtifactDescriptor,
  createJobDir,
  ensureDir,
  ensureRepoNodeModulesLink,
  normalizeFilenameBase,
  promoteArtifactDescriptor,
  resolveRepoBinary,
  runCheckedCommand,
  shellEscape,
  writeJsonFile,
  writeTextFile,
};
