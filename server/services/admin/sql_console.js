'use strict';

const db = require('../../db/database');
const { httpError } = require('../../utils/http_error');

const MAX_ROWS = 500;
const BLOCKED_KEYWORDS = /\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|ATTACH|DETACH|TRUNCATE|VACUUM|REINDEX|REPLACE|UPSERT|PRAGMA)\b/i;

function assertReadOnly(query) {
  if (!query || typeof query !== 'string') throw httpError(400, 'No query provided');
  const sql = query.trim();
  if (!/^(SELECT|WITH)\b/i.test(sql)) throw httpError(400, 'Only SELECT (or WITH …) queries are allowed');
  if (BLOCKED_KEYWORDS.test(sql)) throw httpError(400, 'Query contains a blocked SQL keyword');
  return sql;
}

/** Runs one read-only query, returning at most MAX_ROWS rows. */
function runReadOnlyQuery(query) {
  const sql = assertReadOnly(query);
  const rows = [];
  try {
    for (const row of db.prepare(sql).iterate()) {
      rows.push(row);
      if (rows.length > MAX_ROWS) break;
    }
  } catch (err) {
    // SQLite's message (syntax error, unknown column, ...) is what the admin needs.
    throw httpError(400, String(err.message || err));
  }
  const truncated = rows.length > MAX_ROWS;
  if (truncated) rows.pop();
  return {
    rows,
    columns: rows.length ? Object.keys(rows[0]) : [],
    truncated,
    total: truncated ? null : rows.length,
  };
}

module.exports = { runReadOnlyQuery };
