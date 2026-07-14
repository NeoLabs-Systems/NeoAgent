'use strict';

// Complete, schema-driven erasure and export of a single user's data.
//
// Both the admin "GDPR: delete all user data" action and the self-service
// account-deletion endpoint go through eraseUserData() so the two can never
// drift apart. Rather than hand-maintain a list of tables (which previously
// missed billing, 2FA, embeddings and other user-scoped tables), we discover
// every table that has a `user_id` column at runtime via PRAGMA table_info and
// clear all of them. Child tables that are keyed by a parent id instead of
// user_id are cleared explicitly below.

const fs = require('fs');
const path = require('path');
const db = require('../../db/database');
const sessionsDb = require('../../db/sessions_db');
const { DATA_DIR, AGENT_DATA_DIR } = require('../../../runtime/paths');
const { sanitizeWorkspaceKey } = require('../workspace/manager');

// Tables that carry a `user_id` column but are global/shared configuration and
// must never be deleted as part of erasing one user.
const GLOBAL_TABLES = new Set(['billing_plans']);

// Column names whose values are credentials/secrets and must be redacted from a
// portability export (the user already controls these; echoing them back adds
// risk without adding portability value).
const SENSITIVE_COLUMN = /pass|secret|token|hash|cipher|encrypt|_iv$|nonce|totp|recovery|priv(ate)?_?key|api_?key|credential/i;

function userScopedTables() {
  const rows = db
    .prepare("SELECT name FROM sqlite_master WHERE type = 'table'")
    .all();
  const tables = [];
  for (const { name } of rows) {
    if (name === 'users' || GLOBAL_TABLES.has(name) || name.startsWith('admin_')) {
      continue;
    }
    if (name.startsWith('sqlite_')) {
      continue;
    }
    let columns;
    try {
      columns = db.prepare(`PRAGMA table_info(${name})`).all();
    } catch {
      continue;
    }
    if (columns.some((column) => column.name === 'user_id')) {
      tables.push(name);
    }
  }
  return tables;
}

// Child tables keyed by a parent id rather than user_id. Foreign keys are
// declared ON DELETE CASCADE, so with PRAGMA foreign_keys = ON these are removed
// automatically when the parent row goes — but we delete them explicitly first
// so erasure is correct even if foreign keys are ever disabled.
function deleteChildRows(uid) {
  const childDeletes = [
    'DELETE FROM conversation_messages WHERE conversation_id IN (SELECT id FROM conversations WHERE user_id = ?)',
    'DELETE FROM agent_steps WHERE run_id IN (SELECT id FROM agent_runs WHERE user_id = ?)',
    'DELETE FROM ai_widget_snapshots WHERE widget_id IN (SELECT id FROM ai_widgets WHERE user_id = ?)',
    'DELETE FROM memory_source_links WHERE memory_id IN (SELECT id FROM memories WHERE user_id = ?)',
  ];
  for (const sql of childDeletes) {
    try {
      db.prepare(sql).run(uid);
    } catch {
      // Table may not exist on older schema versions — ignore.
    }
  }
}

function collectArtifactPaths(uid) {
  try {
    return db
      .prepare('SELECT storage_path FROM artifacts WHERE user_id = ?')
      .all(uid)
      .map((row) => row.storage_path)
      .filter(Boolean);
  } catch {
    return [];
  }
}

function removeArtifactFiles(uid, storagePaths) {
  const artifactsRoot = path.resolve(path.join(DATA_DIR, 'artifacts'));
  for (const storagePath of storagePaths) {
    try {
      const abs = path.resolve(
        path.isAbsolute(storagePath) ? storagePath : path.join(DATA_DIR, storagePath),
      );
      if (abs.startsWith(artifactsRoot + path.sep)) {
        fs.rmSync(abs, { force: true });
      }
    } catch {
      /* best effort */
    }
  }
  const userArtifactDir = path.resolve(path.join(DATA_DIR, 'artifacts', String(uid)));
  if (userArtifactDir.startsWith(artifactsRoot + path.sep)) {
    try {
      fs.rmSync(userArtifactDir, { recursive: true, force: true });
    } catch {
      /* best effort */
    }
  }
}

function removeWorkspaceDir(uid) {
  const workspacesRoot = path.resolve(path.join(AGENT_DATA_DIR, 'workspaces'));
  const workspaceDir = path.resolve(
    path.join(workspacesRoot, sanitizeWorkspaceKey(uid)),
  );
  if (workspaceDir.startsWith(workspacesRoot + path.sep)) {
    try {
      fs.rmSync(workspaceDir, { recursive: true, force: true });
    } catch {
      /* best effort */
    }
  }
}

function purgeSessionStore(uid) {
  // better-sqlite3-session-store keeps a `sessions` table whose `sess` column is
  // the JSON-serialised session. Remove any row belonging to this user so their
  // login is invalidated everywhere immediately.
  for (const needle of [`%"userId":${uid}%`, `%"userId":"${uid}"%`]) {
    try {
      sessionsDb.prepare('DELETE FROM sessions WHERE sess LIKE ?').run(needle);
    } catch {
      /* table/store may differ — best effort */
    }
  }
}

function killUserRuntime(uid, runtimeManager) {
  try {
    const vmManager = runtimeManager?.browserBackend?.vmManager;
    if (vmManager && typeof vmManager.killVm === 'function') {
      // Fire-and-forget: container teardown should not block the HTTP response.
      Promise.resolve(vmManager.killVm(String(uid))).catch(() => {});
    }
  } catch {
    /* best effort */
  }
}

/**
 * Permanently erase all data belonging to a user (GDPR Art. 17).
 *
 * @param {number|string} userId
 * @param {object} [opts]
 * @param {object} [opts.runtimeManager] live RuntimeManager so the user's
 *   sandbox container can be torn down as part of erasure.
 * @returns {{ ok: true, tablesCleared: number }}
 */
function eraseUserData(userId, opts = {}) {
  const uid = Number(userId);
  if (!Number.isInteger(uid) || uid <= 0) {
    const error = new Error('Invalid user id');
    error.code = 'INVALID_ID';
    throw error;
  }
  const exists = db.prepare('SELECT id FROM users WHERE id = ?').get(uid);
  if (!exists) {
    const error = new Error('User not found');
    error.code = 'NOT_FOUND';
    throw error;
  }

  const artifactPaths = collectArtifactPaths(uid);
  const tables = userScopedTables();

  const erase = db.transaction(() => {
    deleteChildRows(uid);
    for (const table of tables) {
      // `table` comes from sqlite_master introspection, never from user input.
      db.prepare(`DELETE FROM ${table} WHERE user_id = ?`).run(uid);
    }
    db.prepare('DELETE FROM users WHERE id = ?').run(uid);
  });
  erase();

  // Off-database state: files on disk, the running sandbox, and active sessions.
  removeArtifactFiles(uid, artifactPaths);
  removeWorkspaceDir(uid);
  purgeSessionStore(uid);
  killUserRuntime(uid, opts.runtimeManager);

  return { ok: true, tablesCleared: tables.length };
}

function redactRow(row) {
  const out = {};
  for (const [key, value] of Object.entries(row)) {
    out[key] = SENSITIVE_COLUMN.test(key) && value != null ? '[redacted]' : value;
  }
  return out;
}

/**
 * Build a structured, machine-readable export of a user's personal data
 * (GDPR Art. 20 data portability). Credential/secret columns are redacted.
 *
 * @param {number|string} userId
 * @returns {object}
 */
function exportUserData(userId) {
  const uid = Number(userId);
  if (!Number.isInteger(uid) || uid <= 0) {
    const error = new Error('Invalid user id');
    error.code = 'INVALID_ID';
    throw error;
  }
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(uid);
  if (!user) {
    const error = new Error('User not found');
    error.code = 'NOT_FOUND';
    throw error;
  }

  const data = { account: redactRow(user) };
  for (const table of userScopedTables()) {
    try {
      const rows = db.prepare(`SELECT * FROM ${table} WHERE user_id = ?`).all(uid);
      if (rows.length > 0) {
        data[table] = rows.map(redactRow);
      }
    } catch {
      /* skip unreadable table */
    }
  }
  // Conversation messages are keyed by conversation id, not user_id.
  try {
    const messages = db
      .prepare(
        'SELECT m.* FROM conversation_messages m JOIN conversations c ON m.conversation_id = c.id WHERE c.user_id = ?',
      )
      .all(uid);
    if (messages.length > 0) {
      data.conversation_messages = messages.map(redactRow);
    }
  } catch {
    /* best effort */
  }

  return {
    exportedAt: new Date().toISOString(),
    schema: 'neoagent.user-export.v1',
    userId: uid,
    data,
  };
}

module.exports = {
  eraseUserData,
  exportUserData,
  userScopedTables,
};
