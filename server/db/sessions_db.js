'use strict';

const Sqlite = require('better-sqlite3');
const { DATA_DIR } = require('../../runtime/paths');

const sessionsDb = new Sqlite(`${DATA_DIR}/sessions.db`);

module.exports = sessionsDb;
