'use strict';

const fs = require('fs');
const path = require('path');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');

function sanitizeWorkspaceKey(value) {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return normalized.slice(0, 64) || 'default';
}

function escapeRegExp(value) {
  return String(value || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function globToRegExp(pattern) {
  const text = String(pattern || '').trim();
  if (!text) {
    return null;
  }
  const escaped = escapeRegExp(text)
    .replace(/\\\*/g, '.*')
    .replace(/\\\?/g, '.');
  return new RegExp(`^${escaped}$`, 'i');
}

class WorkspaceManager {
  constructor(options = {}) {
    this.rootDir = path.resolve(options.rootDir || path.join(AGENT_DATA_DIR, 'workspaces'));
    try {
      fs.mkdirSync(this.rootDir, { recursive: true });
    } catch (err) {
      throw new Error(`Failed to create workspace dir ${this.rootDir}: ${err.message}`);
    }
  }

  _ensureWorkspaceRootSync(userId) {
    const key = sanitizeWorkspaceKey(userId);
    const root = path.join(this.rootDir, key);
    try {
      fs.mkdirSync(root, { recursive: true });
    } catch (err) {
      throw new Error(`Failed to create workspace dir for user ${String(userId || 'default')}: ${err.message}`);
    }
    return root;
  }

  async getWorkspaceRoot(userId) {
    const key = sanitizeWorkspaceKey(userId);
    const root = path.join(this.rootDir, key);
    try {
      await fs.promises.mkdir(root, { recursive: true });
    } catch (err) {
      throw new Error(`Failed to create workspace dir for user ${String(userId || 'default')}: ${err.message}`);
    }
    return root;
  }

  async getToolingRoot(userId, toolName) {
    const workspaceRoot = await this.getWorkspaceRoot(userId);
    const toolRoot = path.join(workspaceRoot, '.tooling', sanitizeWorkspaceKey(toolName));
    try {
      await fs.promises.mkdir(toolRoot, { recursive: true });
    } catch (err) {
      throw new Error(`Failed to create tooling dir for user ${String(userId || 'default')} and tool ${String(toolName || 'tool')}: ${err.message}`);
    }
    return toolRoot;
  }

  resolvePath(userId, candidatePath, label = 'path') {
    const root = this._ensureWorkspaceRootSync(userId);
    const absolute = path.isAbsolute(candidatePath)
      ? path.resolve(candidatePath)
      : path.resolve(root, candidatePath || '.');
    const relative = path.relative(root, absolute);
    if (relative.startsWith('..') || path.isAbsolute(relative)) {
      throw new Error(`${label} is outside the per-user workspace.`);
    }
    return absolute;
  }

  readFile(userId, options = {}) {
    let filePath;
    try {
      filePath = this.resolvePath(userId, options.path || '', 'path');
      const encoding = String(options.encoding || 'utf8').toLowerCase();
      const raw = fs.readFileSync(filePath);
      const hasRange = options.start_line != null || options.end_line != null;
      if (hasRange) {
        const start = options.start_line != null ? Number(options.start_line) : 1;
        const end = options.end_line != null ? Number(options.end_line) : null;
        if (!Number.isInteger(start) || start < 1) {
          return { error: 'start_line must be a positive integer', path: filePath };
        }
        if (end != null && (!Number.isInteger(end) || end < 1)) {
          return { error: 'end_line must be a positive integer', path: filePath };
        }
        if (end != null && start > end) {
          return { error: 'start_line must be less than or equal to end_line', path: filePath };
        }
        const content = raw.toString(encoding);
        const lines = content.split('\n');
        const startClamped = Math.max(1, start);
        const endClamped = Math.min(end != null ? end : lines.length, lines.length);
        const sliced = lines.slice(startClamped - 1, endClamped).join('\n');
        return {
          path: filePath,
          content: sliced.length > 20000 ? `${sliced.slice(0, 20000)}\n...[truncated]` : sliced,
          totalLines: lines.length,
          rangeShown: [startClamped, endClamped],
        };
      }
      const content = encoding === 'base64' ? raw.toString('base64') : raw.toString(encoding);
      return {
        path: filePath,
        content: content.length > 20000 ? `${content.slice(0, 20000)}\n...[truncated]` : content,
        byteSize: raw.length,
      };
    } catch (err) {
      return {
        error: `Failed to read file for user ${String(userId || 'unknown')}: ${err.message}`,
        path: filePath || null,
      };
    }
  }

  writeFile(userId, options = {}) {
    const filePath = this.resolvePath(userId, options.path || '', 'path');
    try {
      fs.mkdirSync(path.dirname(filePath), { recursive: true });
      const content = String(options.content ?? '');
      if (String(options.mode || '').toLowerCase() === 'append') {
        fs.appendFileSync(filePath, content);
      } else {
        fs.writeFileSync(filePath, content, 'utf8');
      }
      return { success: true, path: filePath };
    } catch (err) {
      return { success: false, path: filePath, error: err.message };
    }
  }

  editFile(userId, options = {}) {
    let filePath;
    try {
      filePath = this.resolvePath(userId, options.path || '', 'path');
      if (!fs.existsSync(filePath)) {
        return { error: `File not found: ${filePath}` };
      }
      let content = fs.readFileSync(filePath, 'utf8');
      let modified = false;
      const report = [];
      for (const edit of Array.isArray(options.edits) ? options.edits : []) {
        if (typeof edit?.oldText !== 'string') {
          report.push({ success: false, error: 'oldText is required' });
          continue;
        }
        if (content.includes(edit.oldText)) {
          const replacement = String(edit.newText || '');
          const pattern = edit.oldText.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
          content = content.replace(new RegExp(pattern, 'g'), replacement);
          modified = true;
          report.push({ success: true, edit: `${edit.oldText.slice(0, 50)}...` });
        } else {
          report.push({ success: false, error: 'Target text not found', edit: `${edit.oldText.slice(0, 50)}...` });
        }
      }
      if (modified) {
        fs.writeFileSync(filePath, content, 'utf8');
      }
      return { success: modified, report, path: filePath };
    } catch (err) {
      return { success: false, path: filePath || null, error: err.message };
    }
  }

  listDirectory(userId, options = {}) {
    const dirPath = this.resolvePath(userId, options.path || '.', 'path');
    const depthValue = options.depth != null ? Number(options.depth) : (options.recursive ? 3 : 1);
    const maxDepth = Number.isFinite(depthValue) ? Math.min(Math.max(1, Math.floor(depthValue)), 5) : 1;

    const walk = (dir, currentDepth = 1) => {
      let entries;
      try {
        entries = fs.readdirSync(dir, { withFileTypes: true });
      } catch {
        return [];
      }
      const result = [];
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        let stats;
        try {
          stats = fs.statSync(fullPath);
        } catch {
          continue;
        }
        result.push({
          name: entry.name,
          type: entry.isDirectory() ? 'directory' : 'file',
          path: fullPath,
          size: stats.size,
          mtime: stats.mtime.toISOString(),
        });
        if (entry.isDirectory() && currentDepth < maxDepth && !entry.name.startsWith('.') && entry.name !== 'node_modules') {
          result.push(...walk(fullPath, currentDepth + 1));
        }
      }
      return result;
    };

    return { path: dirPath, entries: walk(dirPath) };
  }

  searchFiles(userId, options = {}) {
    const rootPath = this.resolvePath(userId, options.path || '.', 'path');
    const query = String(options.query || '').trim();
    if (!query) {
      return { results: [], message: 'query is required' };
    }
    const includePattern = globToRegExp(options.include || '');
    const depthValue = options.maxDepth != null ? Number(options.maxDepth) : 5;
    const sizeValue = options.maxFileSize != null ? Number(options.maxFileSize) : 1024 * 1024;
    const maxDepth = Number.isFinite(depthValue) ? Math.min(Math.max(0, Math.floor(depthValue)), 10) : 5;
    const maxFileSize = Number.isFinite(sizeValue) ? Math.max(0, Math.floor(sizeValue)) : 1024 * 1024;
    const matches = [];
    const regex = new RegExp(escapeRegExp(query), 'i');
    const walk = (dir, depth = 0) => {
      if (depth >= maxDepth) {
        return;
      }
      let entries;
      try {
        entries = fs.readdirSync(dir, { withFileTypes: true });
      } catch {
        return;
      }
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        let stats;
        try {
          stats = fs.lstatSync(fullPath);
        } catch {
          continue;
        }
        if (stats.isSymbolicLink()) {
          continue;
        }
        if (stats.isDirectory()) {
          if (!entry.name.startsWith('.') && entry.name !== 'node_modules') {
            walk(fullPath, depth + 1);
          }
          continue;
        }
        if (!stats.isFile()) {
          continue;
        }
        if (includePattern && !includePattern.test(entry.name)) {
          continue;
        }
        try {
          if (stats.size > maxFileSize) {
            continue;
          }
        } catch {
          continue;
        }
        let content = '';
        try {
          content = fs.readFileSync(fullPath, 'utf8');
        } catch {
          continue;
        }
        const lines = content.split('\n');
        for (let i = 0; i < lines.length; i += 1) {
          if (!regex.test(lines[i])) {
            continue;
          }
          matches.push({
            file: fullPath,
            line: i + 1,
            content: lines[i].trim(),
          });
          if (matches.length >= 100) {
            return;
          }
        }
      }
    };
    walk(rootPath);
    return { matches, count: matches.length };
  }
}

module.exports = {
  WorkspaceManager,
};
