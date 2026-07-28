'use strict';

const Sqlite = require('better-sqlite3');
const {
  DATA_DIR,
  ensurePrivateFile,
  ensureRuntimeDirs,
} = require('../../runtime/paths');

ensureRuntimeDirs();
const sessionsDbPath = `${DATA_DIR}/sessions.db`;
const sessionsDb = new Sqlite(sessionsDbPath);
ensurePrivateFile(sessionsDbPath);

module.exports = sessionsDb;
