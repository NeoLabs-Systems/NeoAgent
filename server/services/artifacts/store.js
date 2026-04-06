const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const db = require('../../db/database');
const { DATA_DIR } = require('../../../runtime/paths');

const ARTIFACTS_ROOT = path.join(DATA_DIR, 'artifacts');
fs.mkdirSync(ARTIFACTS_ROOT, { recursive: true });

function sanitizeSegment(value, fallback = 'artifact') {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/\.+/g, '-')
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '');
  if (!normalized || normalized === '.' || normalized === '..') {
    return fallback;
  }
  return normalized;
}

function normalizeMetadata(metadata) {
  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
    return {};
  }
  return metadata;
}

class ArtifactStore {
  constructor(options = {}) {
    this.rootDir = path.resolve(options.rootDir || ARTIFACTS_ROOT);
    fs.mkdirSync(this.rootDir, { recursive: true });
  }

  #assertInsideRoot(candidatePath, label = 'artifact path') {
    const resolvedRoot = path.resolve(this.rootDir);
    const resolvedCandidate = path.resolve(candidatePath);
    const relativePath = path.relative(resolvedRoot, resolvedCandidate);
    if (
      relativePath.startsWith('..')
      || path.isAbsolute(relativePath)
      || relativePath === ''
    ) {
      throw new Error(`${label} escapes the artifact root.`);
    }
    return resolvedCandidate;
  }

  #userDir(userId) {
    return this.#assertInsideRoot(
      path.join(this.rootDir, sanitizeSegment(userId, 'anonymous')),
      'artifact user directory',
    );
  }

  buildArtifactUrl(id) {
    return `/api/artifacts/${encodeURIComponent(String(id || '').trim())}/content`;
  }

  allocateFile(userId, options = {}) {
    const artifactId = uuidv4();
    const extension = String(options.extension || '').trim().replace(/^[.]/, '');
    const suffix = extension ? `.${extension}` : '';
    const filenameBase = sanitizeSegment(options.filenameBase || options.kind || 'artifact');
    const dir = this.#userDir(userId);
    fs.mkdirSync(dir, { recursive: true });
    const storagePath = path.join(dir, `${artifactId}-${filenameBase}${suffix}`);
    const contentType = typeof options.contentType === 'string' ? options.contentType : null;
    const originalFilename = typeof options.originalFilename === 'string' ? options.originalFilename : path.basename(storagePath);
    const metadata = normalizeMetadata(options.metadata);

    db.prepare(`
      INSERT INTO artifacts (id, user_id, kind, backend, content_type, storage_path, original_filename, byte_size, metadata_json)
      VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)
    `).run(
      artifactId,
      userId,
      String(options.kind || 'artifact'),
      String(options.backend || 'host'),
      contentType,
      storagePath,
      originalFilename,
      JSON.stringify(metadata),
    );

    return {
      artifactId,
      storagePath,
      contentType,
      url: this.buildArtifactUrl(artifactId),
    };
  }

  finalizeFile(artifactId, filePath) {
    const resolved = this.#assertInsideRoot(String(filePath || ''), 'artifact file');
    let byteSize;
    try {
      byteSize = fs.statSync(resolved).size;
    } catch (err) {
      throw new Error(`Failed to stat artifact file: ${err.message}`);
    }
    db.prepare('UPDATE artifacts SET byte_size = ? WHERE id = ?').run(byteSize, artifactId);
    return {
      artifactId,
      filePath: resolved,
      byteSize,
      url: this.buildArtifactUrl(artifactId),
    };
  }

  createTextArtifact(userId, options = {}) {
    const allocation = this.allocateFile(userId, {
      ...options,
      extension: options.extension || 'txt',
    });
    fs.writeFileSync(allocation.storagePath, String(options.content || ''), 'utf8');
    return {
      ...allocation,
      ...this.finalizeFile(allocation.artifactId, allocation.storagePath),
    };
  }

  getArtifactForUser(userId, artifactId) {
    const row = db.prepare(`
      SELECT id, user_id, kind, backend, content_type, storage_path, original_filename, byte_size, metadata_json, created_at
      FROM artifacts
      WHERE id = ? AND user_id = ?
    `).get(artifactId, userId);

    if (!row) return null;
    let metadata = {};
    try {
      metadata = JSON.parse(row.metadata_json || '{}');
    } catch {}
    return {
      ...row,
      metadata,
      url: this.buildArtifactUrl(row.id),
    };
  }
}

module.exports = {
  ArtifactStore,
  ARTIFACTS_ROOT,
};
