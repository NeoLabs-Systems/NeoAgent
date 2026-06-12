'use strict';

const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');

function parseDelimited(text, delimiter) {
  const rows = [];
  let row = [];
  let value = '';
  let quoted = false;
  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    if (char === '"') {
      if (quoted && text[index + 1] === '"') {
        value += '"';
        index += 1;
      } else {
        quoted = !quoted;
      }
    } else if (char === delimiter && !quoted) {
      row.push(value);
      value = '';
    } else if ((char === '\n' || char === '\r') && !quoted) {
      if (char === '\r' && text[index + 1] === '\n') index += 1;
      row.push(value);
      if (row.some((cell) => cell !== '')) rows.push(row);
      row = [];
      value = '';
    } else {
      value += char;
    }
  }
  row.push(value);
  if (row.some((cell) => cell !== '')) rows.push(row);
  const headers = rows.shift() || [];
  return rows.map((cells) => Object.fromEntries(headers.map((header, index) => [header, cells[index] ?? ''])));
}

class StructuredDataService {
  constructor(options = {}) {
    this.workspaceManager = options.workspaceManager;
  }

  query(userId, options = {}) {
    const filePath = this.workspaceManager.resolvePath(userId, options.path || '', 'path');
    const extension = path.extname(filePath).toLowerCase();
    const limit = Math.min(Math.max(Number(options.limit || 100), 1), 1000);
    if (extension === '.sqlite' || extension === '.db' || extension === '.sqlite3') {
      const sql = String(options.sql || '').trim();
      if (!sql) throw new Error('sql is required for SQLite data.');
      const database = new Database(filePath, { readonly: true, fileMustExist: true });
      try {
        const statement = database.prepare(sql);
        if (!statement.reader || !statement.readonly) throw new Error('Only read-only queries are allowed.');
        return {
          format: 'sqlite',
          columns: statement.columns().map((column) => column.name),
          rows: statement.all(options.parameters || {}).slice(0, limit),
        };
      } finally {
        database.close();
      }
    }
    let rows;
    if (extension === '.json') {
      const parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      rows = Array.isArray(parsed) ? parsed : [parsed];
    } else if (extension === '.csv' || extension === '.tsv') {
      rows = parseDelimited(fs.readFileSync(filePath, 'utf8'), extension === '.tsv' ? '\t' : ',');
    } else {
      throw new Error('Supported structured-data formats are CSV, TSV, JSON, and SQLite.');
    }
    const selectedColumns = Array.isArray(options.columns) ? options.columns.map(String) : null;
    const filtered = rows.filter((row) => {
      if (!options.equals || typeof options.equals !== 'object') return true;
      return Object.entries(options.equals).every(([key, value]) => row?.[key] === value);
    }).slice(0, limit).map((row) => {
      if (!selectedColumns) return row;
      return Object.fromEntries(selectedColumns.map((column) => [column, row?.[column]]));
    });
    return {
      format: extension.slice(1),
      columns: filtered[0] && typeof filtered[0] === 'object' ? Object.keys(filtered[0]) : [],
      rows: filtered,
    };
  }
}

module.exports = {
  StructuredDataService,
  parseDelimited,
};
